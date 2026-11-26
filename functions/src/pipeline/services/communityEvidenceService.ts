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
import { ClaimStatus, RichSource } from "../types";
import {
  UrlVerificationService,
  urlVerificationService,
  isLiveVerificationRecord,
  sanitizeReportPayloadForClosedWorld,
} from "./urlVerificationService";
import { sourceTrustService } from "./sourceTrustService";
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
export const MAX_SUBMISSIONS_PER_USER_PER_DAY = 10;
export const MAX_URLS_PER_SUBMISSION = 5;

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

/** Finds the claim a submission targets: by id first, then by normalized text. */
export function findTargetClaim(report: any, claimId?: string, claimText?: string): { claim: any; index: number } | null {
  const claims: any[] = Array.isArray(report?.claims) ? report.claims : [];
  if (claimId) {
    const index = claims.findIndex((c) => c?.claimId === claimId);
    if (index >= 0) return { claim: claims[index], index };
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
    return new ClaimVerificationService(process.env.GEMINI_API_KEY || "", 0.6);
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
    await ref.set(applied, { merge: true });
    return applied;
  }

  /** Live-checks the links, then re-judges the single target claim with them. */
  async applyApprovedEvidence(record: CommunityEvidenceRecord): Promise<CommunityEvidenceRecord> {
    const urls = sanitizeSubmittedUrls(record.urls?.length ? record.urls : [record.url]);
    const relevanceQueries = record.claimText ? [record.claimText] : undefined;

    const accepted: RichSource[] = [];
    const rejectedUrls: Array<{ url: string; reason: string }> = [];
    for (const url of urls) {
      const uv = await this.urlVerifier.verifyUrl(url, { allowHomepage: false, relevanceQueries });
      if (!isLiveVerificationRecord(uv)) {
        rejectedUrls.push({ url, reason: uv.errorReason || uv.status });
        continue;
      }
      const canonical = uv.canonicalUrl || url;
      const trust = sourceTrustService.resolveSourceTrust(canonical, "General");
      if ((trust.tier as string) === "E") {
        rejectedUrls.push({ url, reason: "Publisher is not an acceptable evidence source" });
        continue;
      }
      accepted.push({
        title: uv.contentTitle || uv.domain || canonical,
        url: canonical,
        directUrl: canonical,
        domain: uv.domain,
        publisher: uv.domain,
        tier: trust.tier,
        // Only the verified page's own text — never the submitter's note.
        snippet: uv.excerpt || "",
        retrievalMethod: "community_submitted" as any,
        retrievalProvider: "Community Evidence (reviewer approved)" as any,
        urlVerification: uv,
        lastVerified: uv.verifiedAtUtc,
      } as RichSource);
    }

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

    const loaded = await this.reportStore.load(record.videoId);
    const target = loaded ? findTargetClaim(loaded.report, record.claimId, record.claimText) : null;
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
}

export const communityEvidenceService = new CommunityEvidenceService();
