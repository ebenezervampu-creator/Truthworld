import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { PIPELINE_CONFIG } from "../config";
import { RichSource, VerifiedClaim } from "../types";
import { logger } from "../utils/logger";
import { hashClaimText } from "../utils/claim-normalization";
import { safeMergeExistingVideo } from "../../utils/videosCollectionGuard";

const BROKEN_REPORT_HEAL_COOLDOWN_MS = 5 * 60 * 1000;
import { AnalysisRepository, getAnalysisRepository } from "./analysisRepository";
import { ClaimReAdjudicator, StanceClassifierFn, reevaluateClaimOnEvidenceChange } from "./evidenceDrivenReevaluation";
import { ClaimVerificationService } from "./claimVerification";
import { ReportStore, gcsReportStore } from "./publishedReportStore";
import { auditCredibilityReport } from "./reportQualityAudit";
import { applyVerdictGateToReport } from "./verdictGate";
import { EvidenceRetrievalService, evidenceRetrievalService } from "./evidenceRetrievalService";
import {
  UrlVerificationService,
  enforceClosedWorldCitationFirewall,
  evidenceCandidateToRichSource,
  isGenericHomepageUrl,
  sanitizeReportPayloadForClosedWorld,
  urlVerificationService,
  validateSafeExternalUrl,
  isLiveVerificationRecord,
} from "./urlVerificationService";

export interface VideoHealingSummary {
  videoId: string;
  healed: boolean;
  claimsAudited: number;
  brokenUrlsRemoved: number;
  urlsRepaired: number;
  remainingVerifiedUrls: number;
  /** Claims whose verdict changed because their evidence changed. */
  verdictsChanged?: number;
  /** Claims re-judged by the model because new evidence was found. */
  modelRechecks?: number;
  /** Claims whose evidence changed but whose model re-reading was skipped (budget). */
  modelRechecksSkipped?: number;
}

export interface ClaimCacheAuditSummary {
  scanned: number;
  staleOrPoisoned: number;
  purged: number;
  dryRun: boolean;
}

export class SourceHealingService {
  private urlVerifier: UrlVerificationService;
  private evidenceRetrieval: EvidenceRetrievalService;
  private analysisRepository: AnalysisRepository;

  private reAdjudicator?: ClaimReAdjudicator;
  private reportStore: ReportStore;
  private classifyStances?: StanceClassifierFn;

  constructor(deps?: {
    urlVerifier?: UrlVerificationService;
    evidenceRetrieval?: EvidenceRetrievalService;
    analysisRepository?: AnalysisRepository;
    reAdjudicator?: ClaimReAdjudicator;
    reportStore?: ReportStore;
    classifyStances?: StanceClassifierFn;
  }) {
    this.urlVerifier = deps?.urlVerifier ?? urlVerificationService;
    this.evidenceRetrieval = deps?.evidenceRetrieval ?? evidenceRetrievalService;
    this.analysisRepository = deps?.analysisRepository ?? getAnalysisRepository();
    this.reAdjudicator = deps?.reAdjudicator;
    this.reportStore = deps?.reportStore ?? gcsReportStore;
    this.classifyStances = deps?.classifyStances;
  }

  private getReAdjudicator(): ClaimReAdjudicator {
    if (!this.reAdjudicator) {
      this.reAdjudicator = new ClaimVerificationService(process.env.GEMINI_API_KEY || "", 0.6);
    }
    return this.reAdjudicator;
  }

  /**
   * Re-verifies every source URL in a claim, removes 404/Soft-404/unverified links,
   * optionally retrieves fresh verified sources, and passes the result through the
   * Closed-World Citation Firewall.
   */
  async healClaimSources(
    claim: VerifiedClaim,
    options?: { repairWithRetrieval?: boolean; domainContext?: string; allowModelRecheck?: boolean }
  ): Promise<{
    claim: VerifiedClaim;
    brokenRemoved: number;
    repairedCount: number;
    verdictChanged: boolean;
    usedModel: boolean;
    modelSkipped: boolean;
  }> {
    const rawSources: RichSource[] = Array.isArray(claim.richSources) ? [...claim.richSources] : [];
    const candidateUrls = rawSources
      .map((s) => String(s?.url || s?.directUrl || "").trim())
      .filter((u) => /^https?:\/\//i.test(u));

    const verifications = candidateUrls.length > 0
      ? await this.urlVerifier.verifyBatch(candidateUrls, { bypassCache: true })
      : new Map();

    let brokenRemoved = 0;
    const survivingSources: RichSource[] = [];
    const newlyQuarantined: RichSource[] = Array.isArray(claim.quarantinedSources)
      ? [...claim.quarantinedSources]
      : [];

    for (const src of rawSources) {
      const rawUrl = String(src?.url || src?.directUrl || "").trim();
      const uv = rawUrl ? verifications.get(rawUrl) : undefined;
      if (uv && isLiveVerificationRecord(uv) && !isGenericHomepageUrl(uv.canonicalUrl)) {
        survivingSources.push({
          ...src,
          url: uv.canonicalUrl,
          directUrl: uv.canonicalUrl,
          urlVerification: uv,
        });
      } else {
        brokenRemoved++;
        newlyQuarantined.push({
          ...src,
          urlVerification: uv ?? src.urlVerification,
        });
      }
    }

    let repairedCount = 0;
    let verifiedAcademicMetadata = claim.verifiedAcademicMetadata;

    if ((brokenRemoved > 0 || survivingSources.length === 0) && options?.repairWithRetrieval !== false && claim.text) {
      try {
        const catalog = await this.evidenceRetrieval.buildEvidenceCatalogForClaim({
          claimText: claim.text,
          domainContext: options?.domainContext || (claim as any).claimDomain || "General",
          maxVerifiedSources: 4,
          enableWebGrounding: true,
        });

        const existingUrls = new Set(survivingSources.map((s) => s.url.toLowerCase()));
        for (const cand of catalog.orderedCandidates) {
          const targetUrl = (cand.canonicalUrl || cand.url).toLowerCase();
          if (!existingUrls.has(targetUrl)) {
            existingUrls.add(targetUrl);
            repairedCount++;
            survivingSources.push(evidenceCandidateToRichSource(cand, catalog.retrievedAtUtc));
          }
        }

        if (catalog.verifiedAcademicMetadata.length > 0) {
          verifiedAcademicMetadata = catalog.verifiedAcademicMetadata;
        }
      } catch (repairErr) {
        logger.warn("[SourceHealingService] Retrieval repair failed for claim; enforcing clean missing state", {
          claimId: claim.claimId,
          err: String(repairErr),
        });
      }
    }

    const firewalled = enforceClosedWorldCitationFirewall({
      ...claim,
      richSources: survivingSources,
      quarantinedSources: newlyQuarantined,
      verifiedAcademicMetadata,
    });

    // The verdict follows the evidence: if the live source set changed, re-evaluate it
    // (model re-judgment when new sources were found; evidence rule only when sources
    // were just removed). Previously sources were swapped but the verdict stayed fixed.
    const reevaluated = await reevaluateClaimOnEvidenceChange({
      claim,
      newSources: firewalled.richSources || [],
      trigger: "source_health",
      reAdjudicator: options?.allowModelRecheck === false ? undefined : this.getReAdjudicator(),
      domainContext: options?.domainContext,
      classifyStances: this.classifyStances,
    });

    const updatedClaim = {
      ...firewalled,
      ...reevaluated.claim,
      // Keep the stance-checked evidence set (off-topic / unreadable sources removed).
      richSources: reevaluated.evidenceChanged ? reevaluated.claim.richSources : firewalled.richSources,
      quarantinedSources: firewalled.quarantinedSources,
      sourceStatus: reevaluated.evidenceChanged ? reevaluated.claim.sourceStatus : firewalled.sourceStatus,
    } as VerifiedClaim;

    return {
      claim: updatedClaim,
      brokenRemoved,
      repairedCount,
      verdictChanged: reevaluated.verdictChanged,
      usedModel: reevaluated.usedModel,
      modelSkipped: Boolean(reevaluated.modelSkipped),
    };
  }

  /**
   * Retroactively audits and heals a stored video report (`factChecks/{videoId}`),
   * replacing broken Claim #18-style URLs or switching to an honest missing-source state.
   */
  async auditAndHealVideoReport(
    videoId: string,
    options?: { repairWithRetrieval?: boolean; maxModelRechecks?: number }
  ): Promise<VideoHealingSummary> {
    // Prefer the report viewers actually see (videos/{id}.factCheckUrl); fall back to the
    // repository copy. Healing only the repository copy left viewers on stale verdicts.
    const published = await this.reportStore.load(videoId).catch((err) => {
      logger.warn("[SourceHealingService] Could not load published report; using repository copy", { videoId, err: String(err) });
      return null;
    });
    const existing = published?.report ?? (await this.analysisRepository.loadAnalysis(videoId, "factChecks"));
    if (!existing || typeof existing !== "object") {
      return {
        videoId,
        healed: false,
        claimsAudited: 0,
        brokenUrlsRemoved: 0,
        urlsRepaired: 0,
        remainingVerifiedUrls: 0,
        verdictsChanged: 0,
        modelRechecks: 0,
      };
    }

    const maxModelRechecks = options?.maxModelRechecks ?? 15;
    let verdictsChanged = 0;
    let modelRechecks = 0;
    let modelRechecksSkipped = 0;

    const claimArrays: Array<{ key: string; list: any[] }> = [];
    for (const key of ["verifiedClaims", "claims", "claimsLedger"]) {
      if (Array.isArray((existing as any)[key])) {
        claimArrays.push({ key, list: (existing as any)[key] });
      }
    }

    let claimsAudited = 0;
    let brokenUrlsRemoved = 0;
    let urlsRepaired = 0;
    let remainingVerifiedUrls = 0;
    const healedPayload: any = { ...existing };
    const healedUrlMapByClaimId = new Map<string, VerifiedClaim>();

    for (const { key, list } of claimArrays) {
      const updatedList: any[] = [];
      for (const rawClaim of list) {
        if (!rawClaim || typeof rawClaim !== "object") {
          updatedList.push(rawClaim);
          continue;
        }
        const claimId = String(rawClaim.claimId || "");
        if (claimId && healedUrlMapByClaimId.has(claimId)) {
          updatedList.push(healedUrlMapByClaimId.get(claimId)!);
          continue;
        }
        claimsAudited++;
        const { claim: healedClaim, brokenRemoved, repairedCount, verdictChanged, usedModel, modelSkipped } = await this.healClaimSources(
          rawClaim as VerifiedClaim,
          { repairWithRetrieval: options?.repairWithRetrieval, allowModelRecheck: modelRechecks < maxModelRechecks }
        );
        if (verdictChanged) verdictsChanged++;
        if (usedModel) modelRechecks++;
        if (modelSkipped) modelRechecksSkipped++;
        brokenUrlsRemoved += brokenRemoved;
        urlsRepaired += repairedCount;
        remainingVerifiedUrls += (healedClaim.richSources || []).length;
        if (claimId) {
          healedUrlMapByClaimId.set(claimId, healedClaim);
        }
        updatedList.push(healedClaim);

        // Invalidate old claim_cache entry when broken links are discovered
        if (brokenRemoved > 0 && healedClaim.text) {
          try {
            const hash = hashClaimText(healedClaim.text);
            await admin.firestore().collection("claim_cache").doc(hash).delete().catch(() => {});
          } catch {
            // Non-blocking cache invalidation
          }
        }
      }
      healedPayload[key] = updatedList;
    }

    // Re-align explainability source cards with healed verified claim sources
    if (Array.isArray(healedPayload.explainability)) {
      healedPayload.explainability = healedPayload.explainability.map((exp: any) => {
        const match = healedUrlMapByClaimId.get(String(exp?.claimId || ""));
        if (!match) return exp;
        const verifiedRefs = (match.richSources || []).map((rs) => ({
          title: rs.title,
          url: rs.url,
          domain: rs.domain,
          publisher: rs.publisher || rs.author,
          snippet: rs.snippet || "",
          relevanceScore: 0.9,
          tier: rs.tier,
          urlVerification: rs.urlVerification,
        }));
        return {
          ...exp,
          sources: verifiedRefs,
          sourceStatus: match.sourceStatus,
          verifiedAcademicMetadata: match.verifiedAcademicMetadata,
        };
      });
    }

    const sanitizedHealed: any = applyVerdictGateToReport(sanitizeReportPayloadForClosedWorld(healedPayload));
    sanitizedHealed.qualityAudit = auditCredibilityReport(sanitizedHealed);
    const changed = brokenUrlsRemoved > 0 || urlsRepaired > 0 || verdictsChanged > 0 || modelRechecks > 0;

    if (changed || existing.evidenceSchemaVersion !== PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION) {
      await this.analysisRepository.saveAnalysis(videoId, "factChecks", sanitizedHealed);
      if (published?.paths?.length) {
        await this.reportStore.save(published.paths, sanitizedHealed);
      }
      try {
        await safeMergeExistingVideo(
          videoId,
          {
            evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
            lastSourceAuditAt: Date.now(),
          },
          "[SourceHealingService]"
        );
      } catch (err) {
        logger.warn("[SourceHealingService] Failed updating video audit timestamp", { videoId, err: String(err) });
      }
    }

    return {
      videoId,
      healed: changed,
      claimsAudited,
      brokenUrlsRemoved,
      urlsRepaired,
      remainingVerifiedUrls,
      verdictsChanged,
      modelRechecks,
      modelRechecksSkipped,
    };
  }

  /**
   * Sweeps persisted `claim_cache` entries and purges pre-v2 or broken-URL records.
   */
  async auditAndHealClaimCache(options?: { limit?: number; dryRun?: boolean }): Promise<ClaimCacheAuditSummary> {
    const limit = Math.min(Math.max(options?.limit ?? 200, 1), 1000);
    const dryRun = options?.dryRun === true;
    let scanned = 0;
    let staleOrPoisoned = 0;
    let purged = 0;

    const snap = await admin.firestore().collection("claim_cache").limit(limit).get();
    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};
      const schemaVersion = data.evidenceSchemaVersion || data.claim?.evidenceSchemaVersion;
      const sources: RichSource[] = Array.isArray(data.richSources)
        ? data.richSources
        : Array.isArray(data.claim?.richSources)
        ? data.claim.richSources
        : [];

      let needsPurge =
        schemaVersion !== PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION || sources.length === 0;

      if (!needsPurge) {
        const urls = sources
          .map((s) => String(s?.url || "").trim())
          .filter((u) => /^https?:\/\//i.test(u));
        if (urls.length === 0) {
          needsPurge = true;
        } else {
          const checkMap = await this.urlVerifier.verifyBatch(urls);
          for (const url of urls) {
            const uv = checkMap.get(url);
            if (!uv || uv.status !== "VERIFIED" || uv.isSoft404) {
              needsPurge = true;
              break;
            }
          }
        }
      }

      if (needsPurge) {
        staleOrPoisoned++;
        if (!dryRun) {
          await doc.ref.delete().catch(() => {});
          purged++;
        }
      }
    }

    return { scanned, staleOrPoisoned, purged, dryRun };
  }

  /**
   * Records a broken-link report from Flutter clients and automatically quarantines
   * & heals the backing claim/report when live re-verification confirms the URL is dead.
   */
  async recordBrokenSourceReport(input: {
    url: string;
    videoId?: string;
    claimId?: string;
    reason?: string;
    reporterUid?: string;
  }): Promise<{
    accepted: boolean;
    verificationStatus: string;
    healedVideo: boolean;
  }> {
    const parsed = validateSafeExternalUrl(input.url);
    if (!parsed) {
      return {
        accepted: false,
        verificationStatus: "FETCH_FAILED",
        healedVideo: false,
      };
    }

    // Reuse url_verification_cache to avoid probing the same URL repeatedly under concurrent taps
    const verification = await this.urlVerifier.verifyUrl(parsed.toString(), { bypassCache: false });
    const urlHash = crypto.createHash("sha256").update(parsed.toString()).digest("hex").slice(0, 24);
    const reportDocId = `${input.videoId || "global"}_${urlHash}`;

    try {
      await admin.firestore().collection("broken_source_reports").doc(reportDocId).set(
        {
          url: parsed.toString(),
          canonicalUrl: verification.canonicalUrl || parsed.toString(),
          domain: parsed.hostname.toLowerCase(),
          videoId: input.videoId || null,
          claimId: input.claimId || null,
          reason: input.reason || null,
          lastReporterUid: input.reporterUid || null,
          verificationStatus: verification.status,
          httpStatus: verification.httpStatus,
          isSoft404: verification.isSoft404,
          reportCount: admin.firestore.FieldValue.increment(1),
          lastReportedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (err) {
      logger.warn("[SourceHealingService] Failed logging broken_source_reports", { err: String(err) });
    }

    let healedVideo = false;
    if (
      input.videoId &&
      verification.status !== "VERIFIED" &&
      verification.status !== "BOT_BLOCKED"
    ) {
      try {
        const videoSnap = await admin.firestore().collection("videos").doc(input.videoId).get().catch(() => null);
        const lastAuditAt = videoSnap?.exists ? videoSnap.data()?.lastSourceAuditAt : undefined;
        const onCooldown =
          typeof lastAuditAt === "number" && Date.now() - lastAuditAt < BROKEN_REPORT_HEAL_COOLDOWN_MS;

        if (videoSnap?.exists && !onCooldown) {
          const healing = await this.auditAndHealVideoReport(input.videoId, { repairWithRetrieval: true });
          healedVideo = healing.healed;
        }
      } catch (healErr) {
        logger.warn("[SourceHealingService] Auto-heal after broken link report failed", {
          videoId: input.videoId,
          err: String(healErr),
        });
      }
    }

    return {
      accepted: true,
      verificationStatus: verification.status,
      healedVideo,
    };
  }
}

export const sourceHealingService = new SourceHealingService();
