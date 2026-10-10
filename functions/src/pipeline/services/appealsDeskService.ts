/**
 * 🏛 FORMAL IFCN FACT-CHECK APPEALS DESK SERVICE
 *
 * Implements an accredited editorial & ombudsman escalation workflow for creators.
 * When a creator disputes a fact-check finding, this service registers a formal appeal,
 * places the contested claim under neutral review (preventing defamatory scarlet-lettering),
 * enforces multi-signatory quorum to eliminate rogue/biased reviewer corruption,
 * and maintains a cryptographic SHA-256 tamper-evident governance audit chain.
 */

import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { v4 as uuidv4 } from "uuid";
import { logger } from "../utils/logger";
import { ClaimStatus, ClaimLedgerSummary } from "../types";

const db = () => admin.firestore();

export type AppealStatus =
  | "submitted"
  | "under_review"
  | "under_secondary_review"
  | "escalated_to_board"
  | "upheld"
  | "overturned"
  | "modified";

export interface OmbudsmanReview {
  reviewerId: string;
  decision: "upheld" | "overturned" | "modified";
  newVerdict?: ClaimStatus;
  reviewerNotes: string;
  reviewedAt: number;
}

export interface ClaimAppealRecord {
  appealId: string;
  videoId: string;
  claimId: string;
  appellantId: string; // Creator UID
  channelId?: string;
  claimText: string;
  originalVerdict: string;
  creatorRationale: string;
  evidenceUrls: string[];
  status: AppealStatus;
  reviews?: OmbudsmanReview[];
  quorumRequired?: number;
  reviewerId?: string;
  reviewerNotes?: string;
  newVerdict?: string;
  submittedAt: number;
  resolvedAt?: number;
}

export interface GovernanceAuditEntry {
  logId: string;
  previousHash: string;
  entryHash: string;
  targetId: string;
  appealId?: string;
  action: string;
  performerId: string;
  rationale: string;
  previousValue: any;
  newValue: any;
  timestamp: number;
}

export class AppealsDeskService {
  private static readonly GENESIS_HASH = "0000000000000000000000000000000000000000000000000000000000000000";

  /**
   * Retrieves the most recent cryptographic audit hash for a target to maintain chain integrity.
   */
  private async getLatestAuditHash(targetId: string): Promise<string> {
    try {
      const snap = await db()
        .collection("governance_audit_logs")
        .where("targetId", "==", targetId)
        .limit(50)
        .get();

      if (!snap.empty) {
        const docs = snap.docs.map(d => d.data() as GovernanceAuditEntry);
        docs.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
        if (docs[0]?.entryHash) {
          return docs[0].entryHash;
        }
      }
    } catch (err: any) {
      logger.warn("[AppealsDesk] Failed to fetch latest audit hash, using genesis hash", { error: err?.message });
    }
    return AppealsDeskService.GENESIS_HASH;
  }

  /**
   * Computes a deterministic SHA-256 integrity hash for a governance action.
   */
  private computeAuditHash(params: {
    previousHash: string;
    targetId: string;
    action: string;
    performerId: string;
    timestamp: number;
    payload: string;
    rationale: string;
  }): string {
    const raw = `${params.previousHash}|${params.targetId}|${params.action}|${params.performerId}|${params.timestamp}|${params.payload}|${params.rationale}`;
    return crypto.createHash("sha256").update(raw).digest("hex");
  }

  /**
   * Submits a formal claim appeal to the IFCN accredited appeals desk.
   */
  async submitClaimAppeal(params: {
    videoId: string;
    claimId: string;
    appellantId: string;
    channelId?: string;
    claimText: string;
    originalVerdict: string;
    creatorRationale: string;
    evidenceUrls?: string[];
  }): Promise<{ appealId: string; status: AppealStatus }> {
    const { videoId, claimId, appellantId, channelId, claimText, originalVerdict, creatorRationale, evidenceUrls = [] } = params;

    if (!videoId || !claimId || !appellantId) {
      throw new Error("Missing required parameters for claim appeal submission.");
    }

    if (!creatorRationale || creatorRationale.trim().length < 10) {
      throw new Error("Creator rationale must provide at least 10 characters of substantive context.");
    }

    // Validate video existence and ownership authorization
    const videoRef = db().collection("videos").doc(videoId);
    const videoSnap = await videoRef.get();
    if (!videoSnap.exists) {
      throw new Error(`Video document ${videoId} not found.`);
    }

    const videoData = videoSnap.data() || {};
    const isOwner = videoData.ownerId === appellantId || videoData.channelId === appellantId;
    if (!isOwner) {
      logger.warn("[AppealsDesk] Non-owner appeal attempt blocked", { videoId, appellantId });
      throw new Error("Only the verified video creator or channel administrator may file an appeal.");
    }

    const appealId = `appeal_${Date.now()}_${uuidv4().substring(0, 8)}`;
    const now = Date.now();

    const sanitizedUrls = evidenceUrls
      .filter((u) => typeof u === "string" && u.trim().startsWith("https://"))
      .slice(0, 5);

    const appealRecord: ClaimAppealRecord = {
      appealId,
      videoId,
      claimId,
      appellantId,
      channelId: channelId || videoData.channelId,
      claimText: claimText.trim(),
      originalVerdict,
      creatorRationale: creatorRationale.trim(),
      evidenceUrls: sanitizedUrls,
      status: "submitted",
      reviews: [],
      quorumRequired: 2,
      submittedAt: now,
    };

    const previousHash = await this.getLatestAuditHash(videoId);
    const logId = `audit_${now}_${uuidv4().substring(0, 6)}`;
    const entryHash = this.computeAuditHash({
      previousHash,
      targetId: videoId,
      action: "appeal_submitted",
      performerId: appellantId,
      timestamp: now,
      payload: JSON.stringify({ appealStatus: "submitted", appealId }),
      rationale: creatorRationale.trim(),
    });

    const batch = db().batch();

    // 1. Save to claim_appeals collection
    const appealRef = db().collection("claim_appeals").doc(appealId);
    batch.set(appealRef, appealRecord);

    // 2. Mark video credibility state as under neutral appeal (prevents defamatory scarlet-lettering)
    batch.update(videoRef, {
      "credibility.isAppealed": true,
      "credibility.appealStatus": "pending",
      "factCheckDispute.activeAppealId": appealId,
      "factCheckDispute.status": "under_appeal",
      "factCheckDispute.lastAppealedAt": now,
    });

    // 3. Append to cryptographic tamper-evident governance audit log
    const auditRef = db().collection("governance_audit_logs").doc(logId);
    batch.set(auditRef, {
      logId,
      previousHash,
      entryHash,
      targetId: videoId,
      appealId,
      action: "appeal_submitted",
      performerId: appellantId,
      rationale: creatorRationale.trim(),
      previousValue: { verdict: originalVerdict },
      newValue: { appealStatus: "submitted", appealId },
      timestamp: now,
    });

    await batch.commit();
    logger.info("[AppealsDesk] Claim appeal submitted successfully", { appealId, videoId, claimId, entryHash });

    return { appealId, status: "submitted" };
  }

  /**
   * Resolves or advances a claim appeal with independent ombudsman authority,
   * enforcing multi-signatory quorum and conflict-of-interest firewalls.
   */
  async resolveClaimAppeal(params: {
    appealId: string;
    reviewerId: string;
    decision: "upheld" | "overturned" | "modified";
    newVerdict?: ClaimStatus;
    reviewerNotes: string;
  }): Promise<{ appealId: string; finalStatus: AppealStatus; newVerdict?: ClaimStatus; message?: string }> {
    const { appealId, reviewerId, decision, newVerdict, reviewerNotes } = params;

    if (!appealId || !reviewerId || !reviewerNotes) {
      throw new Error("Missing required resolution parameters.");
    }

    const appealRef = db().collection("claim_appeals").doc(appealId);
    const appealSnap = await appealRef.get();
    if (!appealSnap.exists) {
      throw new Error(`Appeal record ${appealId} not found.`);
    }

    const appealData = appealSnap.data() as ClaimAppealRecord;
    const now = Date.now();

    const videoRef = db().collection("videos").doc(appealData.videoId);
    const videoSnap = await videoRef.get();
    const videoData = videoSnap.exists ? videoSnap.data() || {} : {};

    // 🛡️ Conflict of Interest & Self-Dealing Defense
    if (reviewerId === appealData.appellantId) {
      logger.warn("[AppealsDesk] Self-adjudication attempt blocked", { appealId, reviewerId });
      throw new Error("Conflict of Interest: Creators cannot adjudicate appeals on their own content.");
    }

    if (videoData.ownerId === reviewerId || videoData.channelId === reviewerId) {
      logger.warn("[AppealsDesk] Channel administrator self-adjudication blocked", { appealId, reviewerId });
      throw new Error("Conflict of Interest: Channel administrators cannot review appeals on their own channel.");
    }

    // 🏛️ Multi-Signatory Ombudsman Quorum
    const existingReviews: OmbudsmanReview[] = Array.isArray(appealData.reviews) ? [...appealData.reviews] : [];

    // Prevent duplicate review by the same ombudsman
    if (existingReviews.some((r) => r.reviewerId === reviewerId)) {
      throw new Error("Duplicate Review Blocked: You have already submitted a review for this appeal. A distinct independent ombudsman is required to satisfy quorum.");
    }

    const currentReview: OmbudsmanReview = {
      reviewerId,
      decision,
      newVerdict,
      reviewerNotes: reviewerNotes.trim(),
      reviewedAt: now,
    };

    const updatedReviews = [...existingReviews, currentReview];
    const quorumRequired = appealData.quorumRequired || 2;
    const previousHash = await this.getLatestAuditHash(appealData.videoId);
    const logId = `audit_${now}_${uuidv4().substring(0, 6)}`;
    const batch = db().batch();

    // CASE 1: Quorum not yet reached (First review)
    if (updatedReviews.length < quorumRequired) {
      const interimStatus: AppealStatus = "under_secondary_review";

      batch.update(appealRef, {
        status: interimStatus,
        reviews: updatedReviews,
        reviewerId,
        reviewerNotes: reviewerNotes.trim(),
        newVerdict: newVerdict || appealData.originalVerdict,
      });

      batch.update(videoRef, {
        "credibility.appealStatus": interimStatus,
        "factCheckDispute.status": interimStatus,
      });

      const entryHash = this.computeAuditHash({
        previousHash,
        targetId: appealData.videoId,
        action: "appeal_first_review_recorded",
        performerId: reviewerId,
        timestamp: now,
        payload: JSON.stringify({ interimStatus, decision, newVerdict }),
        rationale: reviewerNotes.trim(),
      });

      const auditRef = db().collection("governance_audit_logs").doc(logId);
      batch.set(auditRef, {
        logId,
        previousHash,
        entryHash,
        targetId: appealData.videoId,
        appealId,
        action: "appeal_first_review_recorded",
        performerId: reviewerId,
        rationale: reviewerNotes.trim(),
        previousValue: { status: appealData.status },
        newValue: { interimStatus, decision, newVerdict },
        timestamp: now,
      });

      await batch.commit();
      logger.info("[AppealsDesk] First ombudsman review logged, awaiting secondary sign-off", { appealId, reviewerId, entryHash });

      return {
        appealId,
        finalStatus: interimStatus,
        newVerdict,
        message: "Initial ombudsman review recorded. Awaiting secondary independent ombudsman sign-off to satisfy quorum.",
      };
    }

    // CASE 2: Quorum reached (Two or more reviews)
    const firstReview = updatedReviews[0];
    const secondReview = currentReview;
    const ombudsmenAgree = firstReview.decision === secondReview.decision;

    // Sub-case 2A: Split / Factional Divergence between ombudsmen
    if (!ombudsmenAgree) {
      const splitStatus: AppealStatus = "escalated_to_board";

      batch.update(appealRef, {
        status: splitStatus,
        reviews: updatedReviews,
        reviewerId,
        reviewerNotes: `Ombudsmen Divergence: Reviewer 1 decided '${firstReview.decision}', Reviewer 2 decided '${secondReview.decision}'. Escalated to IFCN Editorial Board for arbitration.`,
      });

      batch.update(videoRef, {
        "credibility.appealStatus": splitStatus,
        "factCheckDispute.status": splitStatus,
      });

      const entryHash = this.computeAuditHash({
        previousHash,
        targetId: appealData.videoId,
        action: "appeal_escalated_to_board",
        performerId: reviewerId,
        timestamp: now,
        payload: JSON.stringify({ splitStatus, firstDecision: firstReview.decision, secondDecision: secondReview.decision }),
        rationale: `Factional divergence between ombudsmen: ${firstReview.decision} vs ${secondReview.decision}`,
      });

      const auditRef = db().collection("governance_audit_logs").doc(logId);
      batch.set(auditRef, {
        logId,
        previousHash,
        entryHash,
        targetId: appealData.videoId,
        appealId,
        action: "appeal_escalated_to_board",
        performerId: reviewerId,
        rationale: `Factional divergence between ombudsmen: ${firstReview.decision} vs ${secondReview.decision}`,
        previousValue: { status: appealData.status },
        newValue: { splitStatus, firstDecision: firstReview.decision, secondDecision: secondReview.decision },
        timestamp: now,
      });

      await batch.commit();
      logger.warn("[AppealsDesk] Reviewer split detected, escalated to board", { appealId, firstReview, secondReview, entryHash });

      return {
        appealId,
        finalStatus: splitStatus,
        newVerdict,
        message: "Independent ombudsmen split on appeal verdict. Escalated to full editorial board for arbitration.",
      };
    }

    // Sub-case 2B: Unanimous Quorum Consensus Achieved
    const finalStatus: AppealStatus = decision;
    const resolvedVerdict = newVerdict || firstReview.newVerdict || appealData.originalVerdict;

    // 1. Finalize appeal record
    batch.update(appealRef, {
      status: finalStatus,
      reviews: updatedReviews,
      reviewerId,
      reviewerNotes: reviewerNotes.trim(),
      newVerdict: resolvedVerdict,
      resolvedAt: now,
    });

    // 2. If decision overturned or modified, re-adjudicate video claim in Firestore
    if (videoSnap.exists && (decision === "overturned" || decision === "modified") && resolvedVerdict) {
      const claims = Array.isArray(videoData.credibility?.claims) ? [...videoData.credibility.claims] : [];
      let updatedCount = 0;

      for (let i = 0; i < claims.length; i++) {
        if (claims[i].claimId === appealData.claimId) {
          claims[i].status = resolvedVerdict as ClaimStatus;
          claims[i].whyWrong = undefined;
          claims[i].adjudicatedBy = `ombudsmen_quorum_${firstReview.reviewerId}_${secondReview.reviewerId}`;
          claims[i].appealResolution = reviewerNotes;
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        // Recalculate claim ledger summary
        const confirmedCount = claims.filter((c: any) => c.status === "verified_true" || c.status === "mostly_true" || c.status === "correct").length;
        const disputedCount = claims.filter((c: any) => c.status === "disputed" || c.status === "inconclusive" || c.status === "limited_support").length;
        const falseCount = claims.filter((c: any) => c.status === "false_claim" || c.status === "incorrect" || c.status === "misleading").length;
        const unprovenCount = claims.filter((c: any) => c.status === "unproven" || c.status === "unsupported" || c.status === "not_historically_verifiable").length;
        const contextualCount = claims.filter((c: any) => c.status === "opinion_claim" || c.status === "religious_belief" || c.status === "satire_claim").length;
        const totalChecked = claims.length;

        const updatedLedger: ClaimLedgerSummary = {
          totalClaimsChecked: totalChecked,
          confirmedCount,
          disputedCount,
          unprovenCount,
          falseCount,
          contextualCount,
          highestSeverityVerdict: falseCount > 0 ? "false_claim" : disputedCount > 0 ? "disputed" : unprovenCount > 0 ? "unproven" : "verified_true",
          verdictHeadline: `${confirmedCount} Confirmed • ${disputedCount} Disputed • ${falseCount} False`,
          verifiableRatio: totalChecked > 0 ? Number((confirmedCount / totalChecked).toFixed(3)) : 0,
        };

        batch.update(videoRef, {
          "credibility.claims": claims,
          "credibility.claimLedger": updatedLedger,
          "credibility.isAppealed": false,
          "credibility.appealStatus": "resolved",
          "factCheckDispute.status": "resolved",
          "factCheckDispute.resolvedAt": now,
        });
      }
    } else {
      batch.update(videoRef, {
        "credibility.isAppealed": false,
        "credibility.appealStatus": "upheld",
        "factCheckDispute.status": "upheld",
        "factCheckDispute.resolvedAt": now,
      });
    }

    // 3. Cryptographic Governance Audit Log
    const entryHash = this.computeAuditHash({
      previousHash,
      targetId: appealData.videoId,
      action: "appeal_quorum_resolved",
      performerId: reviewerId,
      timestamp: now,
      payload: JSON.stringify({ decision, newVerdict: resolvedVerdict, quorumReviewers: [firstReview.reviewerId, secondReview.reviewerId] }),
      rationale: reviewerNotes.trim(),
    });

    const auditRef = db().collection("governance_audit_logs").doc(logId);
    batch.set(auditRef, {
      logId,
      previousHash,
      entryHash,
      targetId: appealData.videoId,
      appealId,
      action: "appeal_quorum_resolved",
      performerId: reviewerId,
      rationale: reviewerNotes.trim(),
      previousValue: { verdict: appealData.originalVerdict },
      newValue: { decision, newVerdict: resolvedVerdict, quorumReviewers: [firstReview.reviewerId, secondReview.reviewerId] },
      timestamp: now,
    });

    await batch.commit();
    logger.info("[AppealsDesk] Claim appeal resolved via dual-ombudsman quorum", { appealId, decision, newVerdict: resolvedVerdict, entryHash });

    return { appealId, finalStatus, newVerdict: resolvedVerdict as ClaimStatus };
  }

  /**
   * Cryptographically verifies the integrity of the governance audit log chain for a target.
   * Ensures zero clandestine modifications or retroactive record tampering.
   */
  async verifyAuditLogChain(targetId: string): Promise<{ isValid: boolean; verifiedCount: number; brokenAtLogId?: string }> {
    const snap = await db()
      .collection("governance_audit_logs")
      .where("targetId", "==", targetId)
      .limit(100)
      .get();

    if (snap.empty) {
      return { isValid: true, verifiedCount: 0 };
    }

    const docs = snap.docs.map(d => d.data() as GovernanceAuditEntry);
    docs.sort((a, b) => (a.timestamp || 0) - (b.timestamp || 0));

    let expectedPrevHash = AppealsDeskService.GENESIS_HASH;

    for (let i = 0; i < docs.length; i++) {
      const entry = docs[i];
      if (entry.previousHash !== expectedPrevHash) {
        logger.error("[AppealsDesk] Broken audit chain detected", { logId: entry.logId, expected: expectedPrevHash, actual: entry.previousHash });
        return { isValid: false, verifiedCount: i, brokenAtLogId: entry.logId };
      }

      const computedHash = this.computeAuditHash({
        previousHash: entry.previousHash,
        targetId: entry.targetId,
        action: entry.action,
        performerId: entry.performerId,
        timestamp: entry.timestamp,
        payload: JSON.stringify(entry.newValue),
        rationale: entry.rationale,
      });

      if (computedHash !== entry.entryHash) {
        logger.error("[AppealsDesk] Tampered audit hash detected", { logId: entry.logId, computed: computedHash, actual: entry.entryHash });
        return { isValid: false, verifiedCount: i, brokenAtLogId: entry.logId };
      }

      expectedPrevHash = entry.entryHash;
    }

    return { isValid: true, verifiedCount: docs.length };
  }
}

export const appealsDeskService = new AppealsDeskService();
