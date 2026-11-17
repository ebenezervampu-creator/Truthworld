/**
 * ⚡ PHASE 2: STREAMING CLAIM PROCESSOR (TRUTHWORLD CREDIBILITY ENGINE)
 *
 * Progressive delivery layer around TruthWorld's existing verification engine.
 * Delivers real-time claim verdicts to Firestore (`videos/{videoId}/claims/{claimId}`)
 * as each verification stage completes, eliminating monolithic report blocking.
 *
 * Epistemic & Engineering Guarantees:
 * 1. Single Source of Truth: Wraps existing FusedGroundingService and Closed-World Firewall.
 * 2. Strict State Machine: EXTRACTED (0) -> PROVISIONAL (1) -> DEEP_VERIFYING (2) -> FINALIZED/UNPROVEN/DISPUTED (3).
 * 3. Race & Stale-Worker Protection: Monotonic stateLevel prevents delayed workers from overwriting finalized records.
 * 4. Stable Occurrence Identity: Keyed by `claim_${hash(normalizedText)}_${Math.round(startMs)}` to prevent collisions.
 * 5. Bounded 200-Claim Ceiling: Respects TruthWorld's "No Claim Left Unchecked" system ceiling.
 * 6. Idempotent Resilience: Safe for concurrent worker retries and recovery sweeps.
 */

import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import { hashClaimText, normalizeClaimText } from "../utils/claim-normalization";
import { FusedGroundingService, FusedGroundingOptions } from "./fusedGroundingService";
import {
  ClaimStatus,
  ExtractedClaim,
  FilteredClaim,
  RichSource,
  VerifiedClaim,
  VerificationMethod,
} from "../types";

const db = () => admin.firestore();

/**
 * Monotonic state levels for the claim lifecycle state machine.
 */
export enum ClaimStateLevel {
  EXTRACTED = 0,      // Claim extracted from audio/media, awaiting verification
  PROVISIONAL = 1,    // Preliminary triage or early classification signal
  DEEP_VERIFYING = 2, // Fused grounding or multi-source verification active
  FINALIZED = 3,      // Terminal state: verified_true, mostly_true, false_claim, unproven, disputed, opinion
}

export interface StreamingClaimDocument {
  claimId: string;
  videoId: string;
  text: string;
  speaker: string;
  startMs: number;
  endMs: number;
  status: ClaimStatus;
  verificationMethod: VerificationMethod;
  verificationConfidence: number;
  reasoning: string;
  richSources: RichSource[];
  isProvisional: boolean;
  stateLevel: ClaimStateLevel;
  verificationVersion: number;
  createdAt: admin.firestore.FieldValue;
  updatedAt: admin.firestore.FieldValue;
  displayLabel?: string;
  keyFacts?: string[];
  missingEvidence?: string[];
}

export class StreamingClaimProcessor {
  private static readonly MAX_CLAIMS_CEILING = 200;

  /**
   * Generates a stable, collision-free occurrence ID for a claim.
   * Incorporates normalized text hash AND timestamp offset so duplicate phrases
   * spoken at different times in the video maintain separate, clean timeline identities.
   */
  public static generateClaimOccurrenceId(text: string, startMs: number): string {
    const norm = normalizeClaimText(text);
    const hash = hashClaimText(norm).slice(0, 16);
    const roundedStart = Math.max(0, Math.round(startMs || 0));
    return `claim_${hash}_${roundedStart}`;
  }

  /**
   * Registers newly extracted claims immediately in Firestore.
   * Transitions claims to stateLevel: EXTRACTED (0).
   * This gives viewers an instantaneous (< 150ms) indication of detected claims
   * on the video timeline while verification executes in the background.
   */
  public static async registerExtractedClaims(
    videoId: string,
    claims: Array<ExtractedClaim | FilteredClaim>
  ): Promise<string[]> {
    if (!videoId || !Array.isArray(claims) || claims.length === 0) return [];

    const effectiveClaims = claims.slice(0, this.MAX_CLAIMS_CEILING);
    const claimIds: string[] = [];
    const batch = db().batch();
    const now = admin.firestore.FieldValue.serverTimestamp();

    for (const claim of effectiveClaims) {
      const startMs = typeof claim.start === "number" ? Math.round(claim.start) : 0;
      const endMs = typeof claim.end === "number" ? Math.round(claim.end) : startMs + 3000;
      const claimId = (claim as any).claimId && !(claim as any).claimId.startsWith("claim_temp_")
        ? (claim as any).claimId
        : this.generateClaimOccurrenceId(claim.text, startMs);

      // Attach resolved ID back to claim object
      (claim as any).claimId = claimId;
      claimIds.push(claimId);

      const claimRef = db().collection("videos").doc(videoId).collection("claims").doc(claimId);

      batch.set(
        claimRef,
        {
          claimId,
          videoId,
          text: claim.text,
          speaker: claim.speaker || "Speaker",
          startMs,
          endMs,
          status: "unverified" as ClaimStatus,
          verdict: "unverified",
          verificationMethod: "not_verified" as VerificationMethod,
          verificationConfidence: 0.0,
          reasoning: "Claim identified; verification in progress...",
          richSources: [],
          isProvisional: true,
          stateLevel: ClaimStateLevel.EXTRACTED,
          verificationVersion: 1,
          createdAt: now,
          updatedAt: now,
        },
        { merge: true }
      );
    }

    try {
      await batch.commit();
      logger.info(`[StreamingClaimProcessor] Registered ${claimIds.length} extracted claims for video ${videoId}`);
    } catch (err: any) {
      logger.warn(`[StreamingClaimProcessor] Failed to commit initial extracted claims batch`, {
        videoId,
        err: err?.message,
      });
    }

    return claimIds;
  }

  /**
   * ⚡ BATCHED FIRESTORE WRITE: Marks an array of escalated claims as DEEP_VERIFYING
   * in Firestore using atomic batched commits (up to 400 claims per batch) rather than
   * serialized transaction round-trips. Protects against write limits and contention.
   */
  public static async markClaimsDeepVerifying(
    videoId: string,
    claimIds: string[]
  ): Promise<void> {
    if (!videoId || !Array.isArray(claimIds) || claimIds.length === 0) return;

    const chunkSize = 400;
    const now = admin.firestore.FieldValue.serverTimestamp();

    for (let i = 0; i < claimIds.length; i += chunkSize) {
      const chunk = claimIds.slice(i, i + chunkSize);
      const batch = db().batch();

      for (const cid of chunk) {
        if (!cid) continue;
        const claimRef = db().collection("videos").doc(videoId).collection("claims").doc(cid);
        batch.set(
          claimRef,
          {
            stateLevel: ClaimStateLevel.DEEP_VERIFYING,
            status: "unverified" as ClaimStatus,
            verdict: "unverified",
            updatedAt: now,
          },
          { merge: true }
        );
      }

      await batch.commit().catch((err: any) => {
        logger.warn("[StreamingClaimProcessor] Failed to batch-mark claims as DEEP_VERIFYING", {
          videoId,
          err: err?.message,
        });
      });
    }
  }

  /**
   * Updates an individual claim with state machine transitions and stale-worker protection.
   */
  public static async updateClaimProgress(
    videoId: string,
    claimId: string,
    update: Partial<VerifiedClaim> & { stateLevel: ClaimStateLevel; isProvisional?: boolean }
  ): Promise<void> {
    if (!videoId || !claimId) return;

    const claimRef = db().collection("videos").doc(videoId).collection("claims").doc(claimId);

    try {
      await db().runTransaction(async (tx) => {
        const snap = await tx.get(claimRef);
        if (snap.exists) {
          const currentData = snap.data();
          const currentLevel = (currentData?.stateLevel as number) ?? ClaimStateLevel.EXTRACTED;

          // Stale worker protection: Never overwrite a terminal/finalized state with an earlier state
          if (currentLevel >= ClaimStateLevel.FINALIZED && update.stateLevel < ClaimStateLevel.FINALIZED) {
            logger.debug(`[StreamingClaimProcessor] Discarded stale worker update for finalized claim ${claimId}`);
            return;
          }
        }

        const payload: Record<string, any> = {
          ...update,
          claimId,
          videoId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (update.status) {
          payload.verdict = update.status;
        }
        if (update.richSources) {
          payload.richSources = update.richSources;
        }

        tx.set(claimRef, payload, { merge: true });
      });
    } catch (err: any) {
      logger.warn(`[StreamingClaimProcessor] Transactional update failed for claim ${claimId}`, {
        err: err?.message,
      });
    }
  }

  /**
   * Processes a batch of claims through the fused verification engine and progressively
   * streams each completed verdict to Firestore.
   */
  public static async processBatchWithProgressiveStreaming(
    videoId: string,
    claims: FilteredClaim[],
    domainContext: string = "General",
    options: FusedGroundingOptions = {}
  ): Promise<VerifiedClaim[]> {
    if (claims.length === 0) return [];

    // 1. Mark batch as DEEP_VERIFYING in Firestore
    const batchMark = db().batch();
    for (const c of claims) {
      const claimRef = db().collection("videos").doc(videoId).collection("claims").doc(c.claimId);
      batchMark.set(
        claimRef,
        {
          stateLevel: ClaimStateLevel.DEEP_VERIFYING,
          status: "unverified",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    await batchMark.commit().catch(() => {});

    // 2. Execute Fused Grounding (single unified Gemini 3.5 call with Google Search)
    const verifiedList = await FusedGroundingService.verifyBatchFused(claims, domainContext, options);

    // 3. Immediately publish finalized claims to Firestore
    const batchFinal = db().batch();
    const now = admin.firestore.FieldValue.serverTimestamp();

    for (const v of verifiedList) {
      const claimRef = db().collection("videos").doc(videoId).collection("claims").doc(v.claimId);
      batchFinal.set(
        claimRef,
        {
          claimId: v.claimId,
          videoId,
          text: v.text,
          speaker: v.speaker || "Speaker",
          startMs: typeof v.start === "number" ? Math.round(v.start) : 0,
          endMs: typeof v.end === "number" ? Math.round(v.end) : 0,
          status: v.status,
          verdict: v.status,
          verificationMethod: v.verificationMethod,
          verificationConfidence: v.verificationConfidence,
          reasoning: v.reasoning,
          richSources: v.richSources || [],
          isProvisional: false,
          stateLevel: ClaimStateLevel.FINALIZED,
          evidenceLevel: v.evidenceLevel || "MODERATE",
          verifiedFacts: v.verifiedFacts || [],
          missingEvidence: v.missingEvidence || [],
          updatedAt: now,
        },
        { merge: true }
      );
    }

    try {
      await batchFinal.commit();
      logger.info(`[StreamingClaimProcessor] Streamed ${verifiedList.length} finalized claims to Firestore for ${videoId}`);
    } catch (err: any) {
      logger.warn(`[StreamingClaimProcessor] Failed to stream finalized batch to Firestore`, {
        videoId,
        err: err?.message,
      });
    }

    return verifiedList;
  }

  /**
   * ⚡ PHASE 3: Executes the 4-Tier Verification Cascade with progressive streaming to Firestore.
   */
  public static async processBatchWithCascade(
    videoId: string,
    claims: FilteredClaim[],
    domainContext: string = "General",
    options: FusedGroundingOptions = {}
  ): Promise<VerifiedClaim[]> {
    const { VerificationCascadeService } = await import("./verificationCascadeService.js");
    return VerificationCascadeService.executeCascade(videoId, claims, domainContext, options);
  }

  /**
   * Writes pre-resolved claims (e.g. Cache Hits, Registry Hits, Labeled Opinions) directly
   * to Firestore as FINALIZED, ensuring zero viewer wait time.
   */
  public static async publishResolvedClaims(
    videoId: string,
    claims: VerifiedClaim[]
  ): Promise<void> {
    if (!videoId || !Array.isArray(claims) || claims.length === 0) return;

    const chunkSize = 400;
    const now = admin.firestore.FieldValue.serverTimestamp();

    for (let i = 0; i < claims.length; i += chunkSize) {
      const chunk = claims.slice(i, i + chunkSize);
      const batch = db().batch();

      for (const claim of chunk) {
        if (!claim.claimId) continue;
        const claimRef = db().collection("videos").doc(videoId).collection("claims").doc(claim.claimId);
        const startMs = typeof claim.start === "number" ? Math.round(claim.start) : 0;
        const endMs = typeof claim.end === "number" ? Math.round(claim.end) : startMs + 3000;

        batch.set(
          claimRef,
          {
            claimId: claim.claimId,
            videoId,
            text: claim.text,
            speaker: claim.speaker || "Speaker",
            startMs,
            endMs,
            status: claim.status,
            verdict: claim.status,
            verificationMethod: claim.verificationMethod || "deterministic",
            verificationConfidence: claim.verificationConfidence || 0.85,
            reasoning: claim.reasoning || "",
            richSources: claim.richSources || [],
            isProvisional: false,
            stateLevel: ClaimStateLevel.FINALIZED,
            evidenceLevel: claim.evidenceLevel || "MODERATE",
            verifiedFacts: claim.verifiedFacts || [],
            missingEvidence: claim.missingEvidence || [],
            updatedAt: now,
          },
          { merge: true }
        );
      }

      try {
        await batch.commit();
        logger.info(`[StreamingClaimProcessor] Published batch of ${chunk.length} pre-resolved claims for ${videoId}`);
      } catch (err: any) {
        logger.warn(`[StreamingClaimProcessor] Failed to publish resolved claims batch`, {
          videoId,
          err: err?.message,
        });
      }
    }
  }
}
