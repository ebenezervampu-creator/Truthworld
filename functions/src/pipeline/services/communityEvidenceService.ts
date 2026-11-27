/**
 * Community Evidence Review Queue
 *
 * Lifecycle of a source submitted from the AI Check page ("Provide source"):
 *
 *   submitted ──► pending_review ──(reviewer approves)──► live link check ──► single-claim
 *                      │                                        │             re-check
 *                      └──(reviewer rejects)──► rejected        └─ fails ─► link_failed
 *
 *   Re-check outcome: `applied` (verdict/sources updated, or confirmed unchanged), or
 *   `approved_pending_rerun` (no single claim to update — used on the next full re-run).
 *
 * Design rules:
 *  - One canonical record per submission in `claim_sources/{evidenceId}` (written only by
 *    Cloud Functions). Previously the app wrote one unvalidated copy and the callable wrote
 *    another, and the pipeline read a third location, so submissions were never used.
 *  - A submission never changes a verdict by itself. A reviewer must approve it, the link
 *    must pass the same live check as every other source, and the claim is then re-judged
 *    by the model with the new source as extra evidence. The model may keep the verdict.
 *  - The submitter's note is NEVER sent to the model (prompt-injection safe); only the
 *    verified page's own title/excerpt is used.
 *  - Every verdict change is appended to the claim's `verdictHistory` and to
 *    `credibility_verdict_changes` for audit.
 */

import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";
import { logger } from "../utils/logger";
import { ClaimStatus, RichSource, UrlVerificationRecord } from "../types";
import {
  UrlVerificationService,
  urlVerificationService,
  isLiveVerificationRecord,
  resolvePublicOEmbedFallback,
  sanitizeReportPayloadForClosedWorld,
} from "./urlVerificationService";
import { hostOf, isUgcHost, sourceTrustService } from "./sourceTrustService";
import { StreamingClaimProcessor } from "./streamingClaimProcessor";
import {
  ClaimReAdjudicator,
  StanceClassifierFn,
  reevaluateClaimOnEvidenceChange,
  toDisplaySources,
} from "./evidenceDrivenReevaluation";
import { ReportStore, gcsReportStore } from "./publishedReportStore";
import { auditCredibilityReport } from "./reportQualityAudit";
import { applyVerdictGateToReport } from "./verdictGate";
import { normalizeClaimText } from "../utils/claim-normalization";
import { ClaimVerificationService } from "./claimVerification";

const db = () => admin.firestore();

export const COMMUNITY_EVIDENCE_COLLECTION = "claim_sources";
export const USER_AI_CHECK_RESTRICTIONS_COLLECTION = "user_ai_check_restrictions";
export const MAX_SUBMISSIONS_PER_USER_PER_DAY = 10;
export const MAX_URLS_PER_SUBMISSION = 5;
export const DISPUTED_NOTE_RECHECK_COOLDOWN_MS = 6 * 60 * 60 * 1000; // 6 hours per claim

const DAY_MS = 24 * 60 * 60 * 1000;

export interface AiCheckRestrictionTier {
  tier: number;
  durationMs: number;
  label: string;
}

/**
 * Progressive restriction schedule for repeated invalid/random source submissions:
 *  - Strikes 1..3: warning only (0 duration)
 *  - Strike 4..6  (> 3 times): 7 days
 *  - Strike 7..9  (+3 times): 1 month (30 days)
 *  - Strike 10..12 (+3 times): 6 months (180 days)
 *  - Strike 13+   (+3 times): 1 year (365 days)
 */
export function computeRestrictionForStrikeCount(strikes: number): AiCheckRestrictionTier {
  if (strikes <= 3) {
    return { tier: 0, durationMs: 0, label: "none" };
  }
  if (strikes <= 6) {
    return { tier: 1, durationMs: 7 * DAY_MS, label: "7 days" };
  }
  if (strikes <= 9) {
    return { tier: 2, durationMs: 30 * DAY_MS, label: "1 month" };
  }
  if (strikes <= 12) {
    return { tier: 3, durationMs: 180 * DAY_MS, label: "6 months" };
  }
  return {
    tier: Math.floor((strikes - 1) / 3),
    durationMs: 365 * DAY_MS,
    label: "1 year",
  };
}

export type EvidenceReviewStatus =
  | "pending_review"
  | "rejected"
  | "link_failed"
  | "approved_pending_rerun"
  | "applied";

export interface CommunityEvidenceRecord {
  evidenceId: string;
  videoId: string;
  claimId?: string;
  claimIndex?: number;
  claimText?: string;
  urls: string[];
  /** Kept for backward compatibility with older readers. */
  url: string;
  note: string;
  submittedBy: string;
  submittedByEmail?: string;
  submitterRole: "creator" | "viewer";
  status: EvidenceReviewStatus;
  createdAtMs: number;
  reviewedBy?: string;
  reviewedAtMs?: number;
  reviewerNotes?: string;
  outcome?: {
    previousStatus?: ClaimStatus;
    newStatus?: ClaimStatus;
    verdictChanged?: boolean;
    acceptedUrls?: string[];
    rejectedUrls?: Array<{ url: string; reason: string }>;
    message: string;
  };
}

export type { ClaimReAdjudicator } from "./evidenceDrivenReevaluation";
export type { ReportStore } from "./publishedReportStore";

export function sanitizeSubmittedUrls(raw: unknown): string[] {
  const list = Array.isArray(raw) ? raw : [];
  const out: string[] = [];
  for (const item of list) {
    const s = typeof item === "string" ? item.trim() : "";
    if (!s || s.length > 512 || /[\x00-\x1f\x7f\s]/.test(s)) continue;
    try {
      const u = new URL(s);
      if (u.protocol !== "https:" && u.protocol !== "http:") continue;
      if (!out.includes(u.href)) out.push(u.href);
    } catch {
      continue;
    }
    if (out.length >= MAX_URLS_PER_SUBMISSION) break;
  }
  return out;
}

/** Finds the claim a submission targets: by id first, then claimIndex, then normalized text. */
export function findTargetClaim(
  report: any,
  claimId?: string,
  claimText?: string,
  claimIndex?: number
): { claim: any; index: number } | null {
  const claims: any[] = Array.isArray(report?.claims) ? report.claims : [];
  if (claimId) {
    const index = claims.findIndex((c) => c?.claimId === claimId);
    if (index >= 0) return { claim: claims[index], index };
  }
  if (typeof claimIndex === "number" && Number.isInteger(claimIndex) && claimIndex >= 0) {
    const byField = claims.findIndex((c) => c?.claimIndex === claimIndex);
    if (byField >= 0) return { claim: claims[byField], index: byField };
    if (claimIndex < claims.length && claims[claimIndex]) {
      return { claim: claims[claimIndex], index: claimIndex };
    }
  }
  const wanted = claimText ? normalizeClaimText(claimText) : "";
  if (wanted) {
    const index = claims.findIndex((c) => normalizeClaimText(String(c?.claim || c?.text || "")) === wanted);
    if (index >= 0) return { claim: claims[index], index };
  }
  return null;
}

export class CommunityEvidenceService {
  constructor(
    private readonly deps: {
      urlVerifier?: Pick<UrlVerificationService, "verifyUrl">;
      reAdjudicator?: ClaimReAdjudicator;
      reportStore?: ReportStore;
      classifyStances?: StanceClassifierFn;
      onReportUpdated?: (
        videoId: string,
        sanitizedReport: any,
        updatedClaim: any,
        claimIndex: number
      ) => Promise<void>;
    } = {}
  ) {}

  private get urlVerifier() {
    return this.deps.urlVerifier ?? urlVerificationService;
  }

  private get reportStore() {
    return this.deps.reportStore ?? gcsReportStore;
  }

  private async getReAdjudicator(): Promise<ClaimReAdjudicator> {
    if (this.deps.reAdjudicator) return this.deps.reAdjudicator;
    return new ClaimVerificationService(undefined, 0.6);
  }

  /** Records one submission (creator or viewer) in the review queue, with a daily limit. */
  async recordSubmission(params: {
    videoId: string;
    userId: string;
    userEmail?: string;
    isCreator: boolean;
    reason: string;
    urls: string[];
    claimId?: string;
    claimText?: string;
    evidenceId?: string;
  }): Promise<CommunityEvidenceRecord> {
    const urls = sanitizeSubmittedUrls(params.urls);
    if (urls.length === 0) {
      throw new Error("Please include at least one valid web link as evidence.");
    }

    const restriction = await this.getUserRestrictionStatus(params.userId);
    if (restriction.restricted) {
      throw new Error(
        `Your AI Check access is restricted for ${restriction.label} due to repeated invalid source submissions.`
      );
    }

    const now = Date.now();
    const day = new Date(now).toISOString().slice(0, 10);
    const limitRef = db().collection("community_evidence_limits").doc(`${params.userId}_${day}`);
    const evidenceId = params.evidenceId || `ev_${now}_${uuidv4().substring(0, 8)}`;
    const record: CommunityEvidenceRecord = {
      evidenceId,
      videoId: params.videoId,
      ...(params.claimId ? { claimId: params.claimId } : {}),
      ...(params.claimText ? { claimText: params.claimText.slice(0, 1000) } : {}),
      urls,
      url: urls[0],
      note: params.reason.trim().slice(0, 2000),
      submittedBy: params.userId,
      ...(params.userEmail ? { submittedByEmail: params.userEmail } : {}),
      submitterRole: params.isCreator ? "creator" : "viewer",
      status: "pending_review",
      createdAtMs: now,
    };

    await db().runTransaction(async (tx) => {
      const limitSnap = await tx.get(limitRef);
      const count = Number(limitSnap.data()?.count || 0);
      if (count >= MAX_SUBMISSIONS_PER_USER_PER_DAY) {
        throw new Error("You have reached today's limit for evidence submissions. Please try again tomorrow.");
      }
      tx.set(limitRef, { count: count + 1, userId: params.userId, day, updatedAt: now }, { merge: true });
      tx.set(db().collection(COMMUNITY_EVIDENCE_COLLECTION).doc(evidenceId), {
        ...record,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    logger.info("[CommunityEvidence] Submission queued for review", {
      evidenceId, videoId: params.videoId, claimId: params.claimId, role: record.submitterRole,
    });
    return record;
  }

  /** Reviewer decision. Approval runs the live link check and the single-claim re-check. */
  async review(params: {
    evidenceId: string;
    reviewerId: string;
    decision: "approve" | "reject";
    reviewerNotes?: string;
  }): Promise<CommunityEvidenceRecord> {
    const ref = db().collection(COMMUNITY_EVIDENCE_COLLECTION).doc(params.evidenceId);
    const snap = await ref.get();
    if (!snap.exists) throw new Error("Evidence submission not found.");
    const record = snap.data() as CommunityEvidenceRecord;
    if (record.status !== "pending_review") {
      throw new Error(`This submission was already reviewed (${record.status}).`);
    }
    if (record.submittedBy === params.reviewerId) {
      throw new Error("Reviewers cannot approve their own submissions.");
    }

    const reviewed = {
      reviewedBy: params.reviewerId,
      reviewedAtMs: Date.now(),
      reviewerNotes: (params.reviewerNotes || "").slice(0, 2000),
    };

    if (params.decision === "reject") {
      const rejected: CommunityEvidenceRecord = {
        ...record,
        ...reviewed,
        status: "rejected",
        outcome: { message: "Rejected by reviewer." },
      };
      await ref.set(rejected, { merge: true });
      return rejected;
    }

    const applied = await this.applyApprovedEvidence({ ...record, ...reviewed });
    if (applied.status === "link_failed" && record.submittedBy) {
      await this.recordInvalidSourceStrike({
        userId: record.submittedBy,
        videoId: record.videoId,
        urls: record.urls?.length ? record.urls : [record.url],
      }).catch(() => {});
    }
    await ref.set(applied, { merge: true });
    return applied;
  }

  /**
   * Returns true only when the claim explicitly attributes a statement, quote, video, or post
   * to a speaker/account on a named platform (e.g., "Elon Musk said on X...").
   * Avoids generic words like "video" or "claims" alone so general empirical claims never match.
   */
  public static isAttributedPrimaryPostClaim(claimText: string): boolean {
    return /\b(?:said\s+on|stated\s+on|wrote\s+on|posted\s+on|shared\s+on|uploaded\s+(?:to|on)|announced\s+on|tweeted|replied\s+on|commented\s+on|on\s+(?:x|twitter|youtube|instagram|tiktok|reddit|facebook|linkedin|threads)|(?:x|twitter|youtube|instagram|tiktok|reddit|facebook|linkedin|threads)\s+(?:post|tweet|video|thread))\b/i.test(
      String(claimText || "")
    );
  }

  /**
   * Detects parody, fan, bot, or impersonation social accounts using oEmbed/page author metadata.
   * Requires non-empty author metadata matching the attributed speaker — never skips when empty.
   */
  public static isSuspectedParodyOrImpersonation(
    claimText: string,
    uv: UrlVerificationRecord
  ): boolean {
    const author = `${uv.authorName || ""} ${uv.authorUrl || ""} ${uv.contentTitle || ""}`.toLowerCase();
    if (/\b(parody|satire|fan\s*account|unofficial|fake|impersonat|bot|backup\s*account)\b/i.test(author)) {
      return true;
    }
    const authorTokens = String(uv.authorName || "")
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((t) => t.length >= 3);
    if (authorTokens.length === 0) {
      return true;
    }
    if (claimText) {
      const claimLower = claimText.toLowerCase();
      const hasMatch = authorTokens.some((tok) => claimLower.includes(tok));
      if (!hasMatch) {
        return true;
      }
    }
    return false;
  }

  /**
   * Shared URL verification + trust-tier + attributed primary-post check.
   * Uses authoritative claim text from the stored report (never raw client text).
   */
  private async verifySubmittedSources(
    urls: string[],
    authoritativeClaimText: string,
    providerLabel: string,
    defaultStance?: "SUPPORTS" | "CONTRADICTS"
  ): Promise<{ accepted: RichSource[]; rejectedUrls: Array<{ url: string; reason: string }> }> {
    const relevanceQueries = authoritativeClaimText ? [authoritativeClaimText] : undefined;
    const isAttributed = CommunityEvidenceService.isAttributedPrimaryPostClaim(authoritativeClaimText);

    const accepted: RichSource[] = [];
    const rejectedUrls: Array<{ url: string; reason: string }> = [];

    for (const url of urls) {
      let uv = await this.urlVerifier.verifyUrl(url, { allowHomepage: false, relevanceQueries });
      if (!isLiveVerificationRecord(uv) && isAttributed && isUgcHost(hostOf(url))) {
        const oembedUv = await resolvePublicOEmbedFallback(url);
        if (oembedUv) {
          uv = oembedUv;
        }
      }
      if (!isLiveVerificationRecord(uv)) {
        rejectedUrls.push({ url, reason: uv?.errorReason || uv?.status || "FETCH_FAILED" });
        continue;
      }

      const canonical = uv.canonicalUrl || url;
      const trust = sourceTrustService.resolveSourceTrust(canonical, "General");
      let resolvedTier = trust.tier;
      let resolvedKind: RichSource["sourceKind"] | undefined;

      if ((trust.tier as string) === "E") {
        if (isAttributed && !CommunityEvidenceService.isSuspectedParodyOrImpersonation(authoritativeClaimText, uv)) {
          // Attributed primary post on a social platform is treated as an official statement.
          resolvedTier = "C";
          resolvedKind = "OFFICIAL_STATEMENT";
        } else {
          rejectedUrls.push({
            url,
            reason: isAttributed
              ? "Social account appears to be parody/unofficial or does not match the attributed speaker"
              : "Publisher is not an acceptable evidence source",
          });
          continue;
        }
      }

      accepted.push({
        title: uv.contentTitle || uv.domain || canonical,
        url: canonical,
        directUrl: canonical,
        domain: uv.domain,
        publisher: uv.authorName || uv.domain,
        tier: resolvedTier,
        ...(resolvedKind ? { sourceKind: resolvedKind } : {}),
        ...(defaultStance ? { claimStance: defaultStance } : {}),
        // Only the verified page's own text — never the submitter's note.
        snippet: uv.excerpt || "",
        retrievalMethod: "community_submitted" as any,
        retrievalProvider: providerLabel as any,
        urlVerification: uv,
        lastVerified: uv.verifiedAtUtc,
      } as RichSource);
    }

    return { accepted, rejectedUrls };
  }

  /** Live-checks the links against authoritative claim text, then re-judges the single target claim. */
  async applyApprovedEvidence(record: CommunityEvidenceRecord): Promise<CommunityEvidenceRecord> {
    const urls = sanitizeSubmittedUrls(record.urls?.length ? record.urls : [record.url]);
    const loaded = await this.reportStore.load(record.videoId);
    const target = loaded
      ? findTargetClaim(loaded.report, record.claimId, record.claimText, record.claimIndex)
      : null;
    const authoritativeClaimText = String(
      target?.claim?.text || target?.claim?.claim || record.claimText || ""
    ).trim();

    const { accepted, rejectedUrls } = await this.verifySubmittedSources(
      urls,
      authoritativeClaimText,
      "Community Evidence"
    );

    if (accepted.length === 0) {
      return {
        ...record,
        status: "link_failed",
        outcome: {
          rejectedUrls,
          message: "None of the submitted links passed the live link check, so the verdict was not re-checked.",
        },
      };
    }

    if (!loaded || !target) {
      return {
        ...record,
        status: "approved_pending_rerun",
        outcome: {
          acceptedUrls: accepted.map((s) => s.url),
          rejectedUrls,
          message: "Approved and stored with this video's evidence. It is not tied to one claim, so no verdict changed. It is offered to the fact-check when the video is fully re-checked.",
        },
      };
    }

    const { report, paths } = loaded;
    const claim = target.claim;
    const previousStatus = claim.status as ClaimStatus;
    const existingLive: RichSource[] = (Array.isArray(claim.richSources) ? claim.richSources : []).filter(
      (s: RichSource) => isLiveVerificationRecord(s?.urlVerification)
    );
    const combined = [...existingLive];
    for (const s of accepted) {
      if (!combined.some((e) => (e.url || "").toLowerCase() === s.url.toLowerCase())) combined.push(s);
    }

    const reAdjudicator = await this.getReAdjudicator();
    const result = await reevaluateClaimOnEvidenceChange({
      claim: { ...claim, richSources: existingLive },
      newSources: combined,
      trigger: "community_evidence",
      reAdjudicator,
      classifyStances: this.deps.classifyStances,
      triggerRef: record.evidenceId,
      reviewedBy: record.reviewedBy,
    });
    const nowIso = new Date().toISOString();
    const verdictChanged = result.verdictChanged;
    report.claims[target.index] = result.claim;
    const reconciled = { status: result.newStatus };
    const displaySources = toDisplaySources(combined);

    // Keep the video-level Sources list in step with the claim's new sources.
    const topSources: any[] = Array.isArray(report.sources) ? report.sources : [];
    for (const s of displaySources) {
      if (!topSources.some((t: any) => String(t?.url || "").toLowerCase() === s.url.toLowerCase())) topSources.push(s);
    }
    report.sources = topSources;
    report.richSources = topSources;

    const sanitized: any = applyVerdictGateToReport(sanitizeReportPayloadForClosedWorld(report));
    sanitized.qualityAudit = auditCredibilityReport(sanitized);
    sanitized.lastCommunityEvidenceUpdate = { evidenceId: record.evidenceId, at: nowIso, verdictChanged };
    await this.reportStore.save(paths, sanitized);

    const updatedClaim = sanitized?.claims?.[target.index] ?? result.claim;
    if (this.deps.onReportUpdated) {
      await this.deps.onReportUpdated(record.videoId, sanitized, updatedClaim, target.index);
    } else {
      await this.syncCredibilityFirestore(record.videoId, sanitized, updatedClaim, target.index);
    }

    if (verdictChanged) {
      try {
        const { invalidateChatCacheForVideo } = require("../aiCredibilityChat");
        invalidateChatCacheForVideo(record.videoId);
      } catch {
        // Non-blocking
      }
      const claimTextForHash = String(updatedClaim?.text || updatedClaim?.claim || claim?.text || "").trim();
      if (claimTextForHash) {
        try {
          const { hashClaimText } = require("../utils/claim-normalization");
          await db().collection("claim_cache").doc(hashClaimText(claimTextForHash)).delete().catch(() => {});
        } catch {
          // Non-blocking cache invalidation
        }
      }
    }

    await db().collection("credibility_verdict_changes").doc(`${record.evidenceId}`).set({
      evidenceId: record.evidenceId,
      videoId: record.videoId,
      claimId: claim.claimId,
      previousStatus,
      newStatus: reconciled.status,
      verdictChanged,
      reviewedBy: record.reviewedBy || null,
      acceptedUrls: accepted.map((s) => s.url),
      createdAt: Date.now(),
    }).catch((err) => logger.warn("[CommunityEvidence] Could not write verdict change log", { err: String(err) }));

    logger.info("[CommunityEvidence] Approved evidence applied", {
      evidenceId: record.evidenceId, videoId: record.videoId, claimId: claim.claimId, previousStatus,
      newStatus: reconciled.status, verdictChanged,
    });

    return {
      ...record,
      status: "applied",
      outcome: {
        previousStatus,
        newStatus: reconciled.status,
        verdictChanged,
        acceptedUrls: accepted.map((s) => s.url),
        rejectedUrls,
        message: verdictChanged
          ? "The claim was re-checked with the new evidence and its verdict was updated."
          : "The claim was re-checked with the new evidence; the verdict stayed the same and the source was added.",
      },
    };
  }

  /**
   * Keeps Firestore `media/credibility` in sync with the re-evaluated claim
   * so Ask AI and report readers immediately reflect community-evidence updates.
   * (Note: `videos/{id}/claims` subcollection writes remain exclusive to StreamingClaimProcessor.)
   */
  private async syncCredibilityFirestore(
    videoId: string,
    sanitizedReport: any,
    updatedClaim: any,
    claimIndex: number
  ): Promise<void> {
    try {
      const videoRef = db().collection("videos").doc(videoId);
      await videoRef.collection("media").doc("credibility").set(
        {
          claims: sanitizedReport.claims || [],
          sources: sanitizedReport.sources || [],
          richSources: sanitizedReport.richSources || [],
          qualityAudit: sanitizedReport.qualityAudit || null,
          lastCommunityEvidenceUpdate: sanitizedReport.lastCommunityEvidenceUpdate || null,
        },
        { merge: true }
      );
      await StreamingClaimProcessor.syncUpdatedClaim(videoId, updatedClaim);
    } catch (err) {
      logger.warn("[CommunityEvidence] Failed syncing Firestore credibility docs", {
        videoId,
        claimIndex,
        err: String(err),
      });
    }
  }

  /** Checks whether a user is currently restricted from AI Check / Community Notes actions. */
  async getUserRestrictionStatus(
    userId: string,
    nowMs: number = Date.now()
  ): Promise<{ restricted: boolean; restrictedUntilMs: number; strikes: number; tier: number; label: string }> {
    const uid = String(userId || "").trim();
    if (!uid) return { restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" };
    try {
      const snap = await db().collection(USER_AI_CHECK_RESTRICTIONS_COLLECTION).doc(uid).get();
      if (!snap.exists) {
        return { restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" };
      }
      const data = snap.data() || {};
      const restrictedUntilMs = Number(data.restrictedUntilMs || 0);
      const strikes = Number(data.invalidSourceStrikes || 0);
      const tierInfo = computeRestrictionForStrikeCount(strikes);
      return {
        restricted: restrictedUntilMs > nowMs,
        restrictedUntilMs,
        strikes,
        tier: tierInfo.tier,
        label: tierInfo.label,
      };
    } catch (err) {
      logger.warn("[CommunityEvidence] Failed reading user restriction status", { uid, err: String(err) });
      return { restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" };
    }
  }

  /**
   * Records an invalid/random source submission strike across any video/claim and applies
   * progressive restrictions (>3 strikes -> 7d, +3 -> 1m, +3 -> 6m, +3 -> 1y).
   */
  async recordInvalidSourceStrike(params: {
    userId: string;
    videoId: string;
    commentId?: string;
    urls: string[];
    nowMs?: number;
  }): Promise<{ strikes: number; restricted: boolean; restrictedUntilMs: number; tier: number; label: string }> {
    const uid = String(params.userId || "").trim();
    if (!uid) {
      return { strikes: 0, restricted: false, restrictedUntilMs: 0, tier: 0, label: "none" };
    }
    const now = params.nowMs ?? Date.now();
    const ref = db().collection(USER_AI_CHECK_RESTRICTIONS_COLLECTION).doc(uid);
    return db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const prev = snap.exists ? snap.data() || {} : {};
      const strikes = Number(prev.invalidSourceStrikes || 0) + 1;
      const tierInfo = computeRestrictionForStrikeCount(strikes);
      const prevUntil = Number(prev.restrictedUntilMs || 0);
      const newUntil = tierInfo.durationMs > 0 ? Math.max(prevUntil, now + tierInfo.durationMs) : prevUntil;

      tx.set(
        ref,
        {
          userId: uid,
          invalidSourceStrikes: strikes,
          restrictionTier: tierInfo.tier,
          restrictionLabel: tierInfo.label,
          restrictedUntilMs: newUntil,
          lastStrikeAtMs: now,
          lastOffenseVideoId: params.videoId,
          ...(params.commentId ? { lastOffenseCommentId: params.commentId } : {}),
          lastOffenseUrls: params.urls.slice(0, MAX_URLS_PER_SUBMISSION),
        },
        { merge: true }
      );

      return {
        strikes,
        restricted: newUntil > now,
        restrictedUntilMs: newUntil,
        tier: tierInfo.tier,
        label: tierInfo.label,
      };
    });
  }

  /**
   * Live-checks submitted `supports` URLs against authoritative claim text and appends
   * valid sources directly to the target claim's evidence list without altering the verdict.
   */
  async appendSupportSourcesToClaim(record: CommunityEvidenceRecord): Promise<CommunityEvidenceRecord> {
    const urls = sanitizeSubmittedUrls(record.urls?.length ? record.urls : [record.url]);
    const loaded = await this.reportStore.load(record.videoId);
    const target = loaded
      ? findTargetClaim(loaded.report, record.claimId, record.claimText, record.claimIndex)
      : null;
    const authoritativeClaimText = String(
      target?.claim?.text || target?.claim?.claim || record.claimText || ""
    ).trim();

    const { accepted, rejectedUrls } = await this.verifySubmittedSources(
      urls,
      authoritativeClaimText,
      "Community Support Evidence",
      "SUPPORTS"
    );

    if (accepted.length === 0) {
      return {
        ...record,
        status: "link_failed",
        outcome: {
          rejectedUrls,
          message: "None of the submitted supporting links passed live verification.",
        },
      };
    }

    if (!loaded || !target) {
      return {
        ...record,
        status: "approved_pending_rerun",
        outcome: {
          acceptedUrls: accepted.map((s) => s.url),
          rejectedUrls,
          message: "Verified supporting sources saved; target claim was not found in published report.",
        },
      };
    }

    const { report, paths } = loaded;
    const claim = target.claim;
    const existingRich: RichSource[] = Array.isArray(claim.richSources) ? [...claim.richSources] : [];
    for (const s of accepted) {
      if (!existingRich.some((e) => String(e?.url || "").toLowerCase() === s.url.toLowerCase())) {
        existingRich.push(s);
      }
    }
    const displaySources = toDisplaySources(existingRich);
    report.claims[target.index] = {
      ...claim,
      richSources: existingRich,
      sources: displaySources,
    };

    const topSources: any[] = Array.isArray(report.sources) ? [...report.sources] : [];
    for (const s of toDisplaySources(accepted)) {
      if (!topSources.some((t: any) => String(t?.url || "").toLowerCase() === s.url.toLowerCase())) {
        topSources.push(s);
      }
    }
    report.sources = topSources;
    report.richSources = topSources;

    const sanitized: any = applyVerdictGateToReport(sanitizeReportPayloadForClosedWorld(report));
    sanitized.qualityAudit = auditCredibilityReport(sanitized);
    sanitized.lastCommunityEvidenceUpdate = {
      evidenceId: record.evidenceId,
      at: new Date().toISOString(),
      verdictChanged: false,
    };
    await this.reportStore.save(paths, sanitized);

    const updatedClaim = sanitized?.claims?.[target.index] ?? report.claims[target.index];
    if (this.deps.onReportUpdated) {
      await this.deps.onReportUpdated(record.videoId, sanitized, updatedClaim, target.index);
    } else {
      await this.syncCredibilityFirestore(record.videoId, sanitized, updatedClaim, target.index);
    }

    return {
      ...record,
      status: "applied",
      outcome: {
        previousStatus: claim.status as ClaimStatus,
        newStatus: claim.status as ClaimStatus,
        verdictChanged: false,
        acceptedUrls: accepted.map((s) => s.url),
        rejectedUrls,
        message: "Verified supporting sources were added to this claim.",
      },
    };
  }

  /**
   * Evaluates a Community Note (`stance === "disputes"` or `"supports"` with `sourceUrls`).
   * - `disputes`: verifies sources, re-evaluates the single target claim, and may update verdict.
   * - `supports`: verifies sources and appends valid ones along with the claim's sources.
   * - All-invalid (`link_failed`): records a strike; >3 strikes escalates AI Check restrictions
   *   (7 days -> 1 month -> 6 months -> 1 year).
   */
  async processClaimNoteEvidence(params: {
    videoId: string;
    commentId: string;
    comment: any;
    gateCheck?: (input: { videoId: string; userId: string; claimKey: string }) => Promise<{ allowed: boolean; reason?: string }>;
    cooldownRecorder?: (input: { videoId: string; claimKey: string; commentId: string }) => Promise<void>;
    ownerCheck?: (videoId: string, userId: string) => Promise<boolean>;
    restrictionCheck?: (userId: string) => Promise<{ restricted: boolean; restrictedUntilMs: number; strikes: number; tier: number; label: string }>;
    strikeRecorder?: (input: { userId: string; videoId: string; commentId?: string; urls: string[] }) => Promise<{ strikes: number; restricted: boolean; restrictedUntilMs: number; tier: number; label: string }>;
    updateCommentStatus?: (videoId: string, commentId: string, patch: Record<string, any>) => Promise<void>;
  }): Promise<{
    status: "ignored" | "restricted" | "owner_must_use_appeals" | "rate_limited" | "cooldown_skipped" | EvidenceReviewStatus;
    verdictChanged: boolean;
    acceptedUrls: string[];
    strikeRecorded?: boolean;
    strikes?: number;
    restrictedUntilMs?: number;
  }> {
    const { videoId, commentId, comment } = params;
    const stance = String(comment?.stance || "").toLowerCase().trim();
    const urls = sanitizeSubmittedUrls(comment?.sourceUrls);

    if ((stance !== "disputes" && stance !== "supports") || urls.length === 0) {
      return { status: "ignored", verdictChanged: false, acceptedUrls: [] };
    }

    const userId = String(comment?.userId || "").trim();
    const writeOutcome = params.updateCommentStatus ?? (async (vid, cid, patch) => {
      await db().collection("videos").doc(vid).collection("claim_comments").doc(cid).set(patch, { merge: true });
    });

    if (userId) {
      const restriction = params.restrictionCheck
        ? await params.restrictionCheck(userId)
        : await this.getUserRestrictionStatus(userId);
      if (restriction.restricted) {
        await writeOutcome(videoId, commentId, {
          evidenceReviewStatus: "restricted",
          verdictChanged: false,
          restrictedUntilMs: restriction.restrictedUntilMs,
          evidenceReviewedAtMs: Date.now(),
        }).catch(() => {});
        return {
          status: "restricted",
          verdictChanged: false,
          acceptedUrls: [],
          strikes: restriction.strikes,
          restrictedUntilMs: restriction.restrictedUntilMs,
        };
      }

      // Video owners must use the formal Creator Appeals Desk (2-attempt cap + audit log),
      // not Community Notes, to alter their own video's official claims or sources.
      const isVideoOwnerUser = params.ownerCheck
        ? await params.ownerCheck(videoId, userId)
        : await (async () => {
            try {
              const vSnap = await db().collection("videos").doc(videoId).get();
              if (!vSnap.exists) return false;
              const vd = vSnap.data() || {};
              return vd.ownerId === userId || vd.userId === userId || vd.uploaderId === userId;
            } catch {
              return false;
            }
          })();
      if (isVideoOwnerUser) {
        await writeOutcome(videoId, commentId, {
          evidenceReviewStatus: "owner_must_use_appeals",
          verdictChanged: false,
          evidenceReviewedAtMs: Date.now(),
        }).catch(() => {});
        return { status: "owner_must_use_appeals", verdictChanged: false, acceptedUrls: [] };
      }
    }

    const claimIndex = typeof comment?.claimIndex === "number" ? comment.claimIndex : undefined;
    const claimId = typeof comment?.claimId === "string" ? comment.claimId : undefined;
    const claimText = typeof comment?.claimText === "string" ? comment.claimText : undefined;
    const claimKey = claimId || (typeof claimIndex === "number" ? `idx_${claimIndex}` : "unknown");

    const gateFn = params.gateCheck ?? (async ({ videoId: vid, userId: uid, claimKey: cKey }) => {
      const now = Date.now();
      const day = new Date(now).toISOString().slice(0, 10);
      const limitRef = db().collection("community_evidence_limits").doc(`${uid}_${day}`);
      const cooldownRef = db().collection("claim_recheck_cooldowns").doc(`${vid}_${cKey}`);

      return db().runTransaction(async (tx) => {
        const [limitSnap, cooldownSnap] = await Promise.all([tx.get(limitRef), tx.get(cooldownRef)]);
        const count = Number(limitSnap.data()?.count || 0);
        if (uid && count >= MAX_SUBMISSIONS_PER_USER_PER_DAY) {
          return { allowed: false, reason: "rate_limited" };
        }
        if (stance === "disputes") {
          const lastRecheckAt = Number(cooldownSnap.data()?.lastRecheckAtMs || 0);
          if (lastRecheckAt > 0 && now - lastRecheckAt < DISPUTED_NOTE_RECHECK_COOLDOWN_MS) {
            return { allowed: false, reason: "cooldown_skipped" };
          }
          // Note: cooldown timestamp is written ONLY after valid sources pass verification
          // so link_failed spam cannot DoS legitimate disputers for 6 hours.
        }
        if (uid) {
          tx.set(limitRef, { count: count + 1, userId: uid, day, updatedAt: now }, { merge: true });
        }
        return { allowed: true };
      });
    });

    const gate = await gateFn({ videoId, userId, claimKey });
    if (!gate.allowed) {
      const skipStatus = gate.reason === "rate_limited" ? "rate_limited" : "cooldown_skipped";
      await writeOutcome(videoId, commentId, {
        evidenceReviewStatus: skipStatus,
        verdictChanged: false,
        evidenceReviewedAtMs: Date.now(),
      }).catch(() => {});
      return { status: skipStatus, verdictChanged: false, acceptedUrls: [] };
    }

    const record: CommunityEvidenceRecord = {
      evidenceId: `note_${commentId}`,
      videoId,
      ...(claimId ? { claimId } : {}),
      ...(typeof claimIndex === "number" ? { claimIndex } : {}),
      ...(claimText ? { claimText: claimText.slice(0, 1000) } : {}),
      urls,
      url: urls[0],
      note: String(comment?.text || "").trim().slice(0, 2000),
      submittedBy: userId || "anonymous",
      submitterRole: "viewer",
      status: "pending_review",
      createdAtMs: Date.now(),
      reviewedBy: stance === "supports" ? "auto_support_verifier" : "auto_dispute_verifier",
      reviewedAtMs: Date.now(),
    };

    const result = stance === "supports"
      ? await this.appendSupportSourcesToClaim(record)
      : await this.applyApprovedEvidence(record);

    const verdictChanged = Boolean(result.outcome?.verdictChanged);
    const acceptedUrls = result.outcome?.acceptedUrls ?? [];
    const rejectedUrls = result.outcome?.rejectedUrls ?? [];

    // Stamp 6-hour per-claim dispute cooldown ONLY when valid evidence actually ran.
    if (stance === "disputes" && result.status === "applied" && acceptedUrls.length > 0) {
      const recordCooldown = params.cooldownRecorder ?? (async ({ videoId: vid, claimKey: cKey, commentId: cid }) => {
        await db()
          .collection("claim_recheck_cooldowns")
          .doc(`${vid}_${cKey}`)
          .set({ videoId: vid, claimKey: cKey, lastRecheckAtMs: Date.now(), commentId: cid }, { merge: true });
      });
      await recordCooldown({ videoId, claimKey, commentId }).catch(() => {});
    }

    // Record strike if ALL links failed OR if user mixed >= 2 invalid/spam links with a valid one.
    let strikeInfo: { strikes: number; restricted: boolean; restrictedUntilMs: number; tier: number; label: string } | null = null;
    if ((result.status === "link_failed" || rejectedUrls.length >= 2) && userId) {
      strikeInfo = params.strikeRecorder
        ? await params.strikeRecorder({ userId, videoId, commentId, urls: rejectedUrls.map((r) => r.url) })
        : await this.recordInvalidSourceStrike({ userId, videoId, commentId, urls: rejectedUrls.map((r) => r.url) });
    }

    await writeOutcome(videoId, commentId, {
      evidenceReviewStatus: result.status,
      verdictChanged,
      acceptedUrls,
      rejectedUrls: result.outcome?.rejectedUrls ?? [],
      previousStatus: result.outcome?.previousStatus ?? null,
      newStatus: result.outcome?.newStatus ?? null,
      evidenceMessage: result.outcome?.message ?? "",
      ...(strikeInfo
        ? {
            strikeRecorded: true,
            invalidSourceStrikes: strikeInfo.strikes,
            restrictedUntilMs: strikeInfo.restrictedUntilMs,
            restrictionLabel: strikeInfo.label,
          }
        : {}),
      evidenceReviewedAtMs: Date.now(),
    }).catch((err) => logger.warn("[CommunityEvidence] Failed updating claim_comments outcome", { videoId, commentId, err: String(err) }));

    return {
      status: result.status,
      verdictChanged,
      acceptedUrls,
      ...(strikeInfo
        ? {
            strikeRecorded: true,
            strikes: strikeInfo.strikes,
            restrictedUntilMs: strikeInfo.restrictedUntilMs,
          }
        : {}),
    };
  }

  /** Backward-compatible wrapper for disputed claim note evaluation. */
  async processDisputedClaimNote(params: Parameters<CommunityEvidenceService["processClaimNoteEvidence"]>[0]) {
    return this.processClaimNoteEvidence(params);
  }
}

export const communityEvidenceService = new CommunityEvidenceService();
