/**
 * 📄 COPYRIGHT CLAIMS SERVICE — Claim Creation & Management
 *
 * This service handles:
 *   1. Checking fair use dynamically using Gemini
 *   2. Auto-generating claims or holds based on confidence & policy strategy
 *   3. Creating evidence bundles containing matching transcripts, timelines, and reasons
 *   4. Resolving/updating claims and managing the dispute/appeal workflow
 */

import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import {
  CopyrightClaim,
  CopyrightMatch,
  DETECTION_THRESHOLDS,
  FairUseAnalysis,
  ClaimNoticeType,
  ClaimStatus,
  ClaimImpact,
} from "./copyrightTypes";
import { copyrightDetectionService } from "./copyrightDetection";
import { v4 as uuidv4 } from "uuid";

const db = () => admin.firestore();

// Detector Versioning metadata constants
const DETECTOR_VERSION = 2;
const EMBEDDING_MODEL = "text-embedding-005";
const GEMINI_MODEL = "gemini-2.5-flash";
const PIPELINE_VERSION = "2026-07";

export class CopyrightClaimsService {
  /**
   * Evaluates a copyright match and creates a claim or temporary hold.
   * Never auto-blocks immediately unless extreme confidence threshold is reached.
   */
  async processMatchAndCreateClaim(
    match: CopyrightMatch,
    newVideoTranscript: string,
    originalVideoTranscript: string,
    originalVideoTitle: string,
    originalSummary: string
  ): Promise<CopyrightClaim | null> {
    const t0 = Date.now();
    logger.info("[CopyrightClaims] Processing match to create claim", {
      matchId: match.matchId,
      videoId: match.matchedVideoId,
      assetId: match.assetId,
    });

    try {
      // 1. Fetch original asset configuration to check protection level & policies
      const assetSnap = await db().collection("copyright_assets").doc(match.assetId).get();
      if (!assetSnap.exists) {
        logger.error("[CopyrightClaims] Copyright asset not found", { assetId: match.assetId });
        return null;
      }
      const assetData = assetSnap.data()!;
      
      // Resolve policy strategy object (Item 8) with fallbacks for backward compatibility
      const policyConfig = assetData.policy || {
        action: assetData.claimPolicy || "track_only",
        allowFairUse: assetData.allowFairUse ?? true,
        allowCommentary: true,
        allowEducation: true,
        minMatchScore: 0.90,
        clipThresholdSeconds: 30,
      };

      const allowFairUse = policyConfig.allowFairUse;
      const claimPolicy = policyConfig.action;
      const claimantChannelName = assetData.videoTitle || "Rights Holder";

      // 2. Perform Fair Use Analysis if allowed by original owner
      let fairUse: FairUseAnalysis = {
        score: 0,
        factors: { commentary: 0, transformation: 0, lengthUsed: 0, purpose: 0, commercialIntent: 0 },
        category: "none",
        reasoning: "Fair use evaluation skipped by owner policy",
        confidence: 1.0,
      };

      if (allowFairUse && match.matchType !== "exact_md5") {
        fairUse = await copyrightDetectionService.analyzeFairUse(
          newVideoTranscript,
          originalVideoTranscript,
          match.matchedSegments
        );
      }

      // If fair use score is high, dismiss the match
      if (allowFairUse && fairUse.score >= DETECTION_THRESHOLDS.FAIR_USE_DISMISS) {
        logger.info("[CopyrightClaims] Match dismissed due to high fair use score", {
          matchId: match.matchId,
          fairUseScore: fairUse.score,
        });
        
        await db().collection("copyright_matches").doc(match.matchId).update({
          status: "dismissed",
        });
        return null;
      }

      // 3. Generate Evidence Bundle
      const newVideoChunks = match.matchedSegments.map((seg, idx) => ({
        startTime: seg.infringingStart,
        endTime: seg.infringingEnd,
        text: `Segment Match #${idx + 1}`,
      }));

      const originalVideoChunks = match.matchedSegments.map((seg, idx) => ({
        startTime: seg.originalStart,
        endTime: seg.originalEnd,
        text: `Source Match #${idx + 1}`,
      }));

      // Generate first-class evidence object containing immutable snapshot details
      const evidenceBundle = copyrightDetectionService.generateEvidenceBundle(
        newVideoChunks,
        originalVideoChunks,
        match.matchedSegments,
        match.confidenceBreakdown,
        fairUse,
        fairUse.reasoning
      );

      // 4. Map policy to notice type & claim impact
      let noticeType: ClaimNoticeType = "Content Match";
      let status: ClaimStatus = "active";
      let impact: ClaimImpact = "No Impact";
      let policyDescription = "Tracked only.";

      if (match.score >= DETECTION_THRESHOLDS.TEMPORARY_HOLD) {
        // High confidence hold/action required
        noticeType = "Takedown Request";
        status = "pending_verification";
        impact = "Action Required";
        policyDescription = "Video requires verification or dispute within 48 hours.";
      } else if (claimPolicy === "block") {
        noticeType = "Takedown Request";
        status = "active";
        impact = "Video Blocked";
        policyDescription = "Monetization blocked by claimant request.";
      } else if (claimPolicy === "monetize_shared") {
        noticeType = "Revenue Share";
        status = "active";
        impact = "Revenue Shared";
        policyDescription = "Revenue shared with copyright owner.";
      }

      const claimId = `claim_${Date.now()}_${uuidv4().substring(0, 8)}`;

      // 5. Fetch uploader & video information
      const videoSnap = await db().collection("videos").doc(match.matchedVideoId).get();
      const videoData = videoSnap.data() || {};
      const videoTitle = videoData.title || "Untitled Video";
      const uploaderId = videoData.userId || videoData.ownerId || match.matchedOwnerId;
      const channelId = videoData.channelId || match.matchedChannelId;

      const claim: CopyrightClaim = {
        claimId,
        videoId: match.matchedVideoId,
        videoTitle,
        channelId,
        uploaderId,
        originalVideoId: assetData.originalVideoId || match.assetId,
        ownerId: assetData.ownerId,
        ownerChannelId: assetData.channelId,
        claimant: claimantChannelName,
        matchId: match.matchId,
        matchType: match.matchType,
        finalConfidence: match.finalConfidence || match.score,
        matchedSegments: match.matchedSegments,
        evidenceBundle,
        fairUseAnalysis: fairUse,
        detectorVersion: DETECTOR_VERSION,
        embeddingModel: EMBEDDING_MODEL,
        geminiModel: GEMINI_MODEL,
        pipelineVersion: PIPELINE_VERSION,
        noticeType,
        policy: policyDescription,
        status,
        impact,
        description: `Copyright claim automatically generated by TruthWorld matching system. Found matched content with original video "${originalVideoTitle}".`,
        date: Date.now(),
        expiresAt: null,
        resolvedAt: null,
        updatedAt: Date.now(),
      };

      // 6. Write Claim and Update Match and Video Docs in a Batch
      const batch = db().batch();
      batch.set(db().collection("copyright_claims").doc(claimId), claim);
      batch.update(db().collection("copyright_matches").doc(match.matchId), {
        status: "claimed",
        claimId,
      });

      // Update video document with copyright status
      const copyrightCheckResult = {
        hasNoViolations: false,
        flaggedSegments: match.matchedSegments.map(
          (s) => `${s.infringingStart}-${s.infringingEnd}`
        ),
        sources: [claimantChannelName],
      };

      batch.update(db().collection("videos").doc(match.matchedVideoId), {
        copyrightStatus: status === "pending_verification" ? "hold" : "claimed",
        copyrightClaimId: claimId,
        "copyrightCheck.hasNoViolations": false,
        "copyrightCheck.flaggedSegments": copyrightCheckResult.flaggedSegments,
        "copyrightCheck.sources": copyrightCheckResult.sources,
        updatedAt: Date.now(),
      });

      await batch.commit();
      logger.info("[CopyrightClaims] Claim successfully created", {
        claimId,
        matchId: match.matchId,
        elapsedMs: Date.now() - t0,
      });

      return claim;
    } catch (error) {
      logger.error("[CopyrightClaims] Failed to create claim from match", {
        matchId: match.matchId,
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Process a dispute/appeal submitted by the creator
   */
  async submitAppeal(
    claimId: string,
    userId: string,
    reason: string,
    category: string,
    evidence: string | null
  ): Promise<boolean> {
    try {
      const claimSnap = await db().collection("copyright_claims").doc(claimId).get();
      if (!claimSnap.exists) {
        logger.warn("[CopyrightClaims] Claim not found for appeal", { claimId });
        return false;
      }
      const claimData = claimSnap.data() as CopyrightClaim;

      if (claimData.uploaderId !== userId) {
        logger.warn("[CopyrightClaims] Unauthorized appeal attempt", { claimId, userId });
        return false;
      }

      const appealId = `appeal_${Date.now()}_${uuidv4().substring(0, 8)}`;
      
      const appeal = {
        appealId,
        claimId,
        matchId: claimData.matchId,
        appellantId: userId,
        claimantId: claimData.ownerId,
        reason,
        evidence,
        category,
        stage: "creator_submitted",
        outcome: "pending",
        aiReviewResult: null,
        ownerResponse: null,
        ownerDecision: null,
        submittedAt: Date.now(),
        aiReviewedAt: null,
        ownerRespondedAt: null,
        resolvedAt: null,
        updatedAt: Date.now(),
      };

      const batch = db().batch();
      batch.set(db().collection("copyright_appeals").doc(appealId), appeal);
      batch.update(db().collection("copyright_claims").doc(claimId), {
        status: "under_appeal", // Set claim status to under_appeal (Item 7)
        updatedAt: Date.now(),
      });

      await batch.commit();

      // Trigger async AI analysis of the appeal
      this.runAIAppealReview(appealId).catch((err) => {
        logger.error("[CopyrightClaims] Async AI appeal review failed", { appealId, err });
      });

      return true;
    } catch (error) {
      logger.error("[CopyrightClaims] Error submitting appeal", { claimId, error });
      return false;
    }
  }

  /**
   * Re-evaluates the appeal details and fair use context using Gemini.
   */
  private async runAIAppealReview(appealId: string): Promise<void> {
    logger.info("[CopyrightClaims] Running AI appeal review", { appealId });
    try {
      const appealSnap = await db().collection("copyright_appeals").doc(appealId).get();
      if (!appealSnap.exists) return;
      const appealData = appealSnap.data()!;

      const claimSnap = await db().collection("copyright_claims").doc(appealData.claimId).get();
      if (!claimSnap.exists) return;
      const claimData = claimSnap.data() as CopyrightClaim;

      const newVideoSnap = await db().collection("videos").doc(claimData.videoId).get();
      const origVideoSnap = await db().collection("videos").doc(claimData.originalVideoId).get();

      const newTranscript = newVideoSnap.data()?.transcript?.text || "";
      const origTranscript = origVideoSnap.data()?.transcript?.text || "";

      // Re-run fair use analysis considering uploader's reason/appeal details
      const { VertexAI } = require("@google-cloud/vertexai");
      const vertexAI = new VertexAI({ project: "truthworld-1", location: "asia-south1" });
      const model = vertexAI.getGenerativeModel({
        model: GEMINI_MODEL,
        generationConfig: { responseMimeType: "application/json", temperature: 0.1 },
      });

      const prompt = `You are a legal advisor resolving copyright disputes. Re-evaluate this copyright claim based on the creator's appeal.

CREATOR REASON FOR APPEAL:
"${appealData.reason}"
Category: ${appealData.category}

ORIGINAL TRANSCRIPT:
${origTranscript.slice(0, 2000)}

NEW TRANSCRIPT:
${newTranscript.slice(0, 2000)}

Determine:
1. Does the creator's explanation validate fair use or licensing rights?
2. Recommended outcome: "uphold" the claim, "overturn" it, or "escalate" for human override.

Return JSON:
{
  "fairUseScore": 0-100 score,
  "recommendation": "uphold" | "overturn" | "escalate",
  "reasoning": "Detailed explanation"
}`;

      const result = await model.generateContent(prompt);
      const text = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      const parsed = JSON.parse(text);

      await db().collection("copyright_appeals").doc(appealId).update({
        stage: "owner_review", // Move to owner review once AI recommendation is ready
        aiReviewResult: {
          fairUseScore: parsed.fairUseScore || 50,
          recommendation: parsed.recommendation || "escalate",
          reasoning: parsed.reasoning || "AI assessment finished.",
        },
        aiReviewedAt: Date.now(),
        updatedAt: Date.now(),
      });

      logger.info("[CopyrightClaims] AI appeal review complete", { appealId, rec: parsed.recommendation });
    } catch (err) {
      logger.error("[CopyrightClaims] Error in runAIAppealReview", { appealId, err });
      await db().collection("copyright_appeals").doc(appealId).update({
        stage: "owner_review",
        updatedAt: Date.now(),
      });
    }
  }

  /**
   * Resolves an appeal (approved / rejected) (Admin only)
   */
  async resolveAppeal(
    appealId: string,
    resolution: "approved" | "rejected",
    notes: string
  ): Promise<boolean> {
    try {
      const appealSnap = await db().collection("copyright_appeals").doc(appealId).get();
      if (!appealSnap.exists) {
        logger.warn("[CopyrightClaims] Appeal not found", { appealId });
        return false;
      }
      const appealData = appealSnap.data()!;
      const claimId = appealData.claimId;

      const batch = db().batch();
      
      const updateAppeal: Record<string, any> = {
        outcome: resolution === "approved" ? "appeal_approved" : "appeal_rejected",
        stage: "resolved",
        ownerDecision: resolution,
        ownerResponse: notes,
        ownerRespondedAt: Date.now(),
        resolvedAt: Date.now(),
        updatedAt: Date.now(),
      };

      batch.update(db().collection("copyright_appeals").doc(appealId), updateAppeal);

      if (resolution === "approved") {
        // Appeal approved -> Dismiss/Resolve claim, restore video status
        batch.update(db().collection("copyright_claims").doc(claimId), {
          status: "resolved_appealed",
          impact: "No Impact",
          resolvedAt: Date.now(),
          updatedAt: Date.now(),
        });

        const claimSnap = await db().collection("copyright_claims").doc(claimId).get();
        if (claimSnap.exists) {
          const videoId = claimSnap.data()?.videoId;
          if (videoId) {
            batch.update(db().collection("videos").doc(videoId), {
              copyrightStatus: "clear",
              updatedAt: Date.now(),
            });
          }
        }
      } else {
        // Appeal rejected -> Claim remains active
        batch.update(db().collection("copyright_claims").doc(claimId), {
          status: "active",
          updatedAt: Date.now(),
        });
      }

      await batch.commit();
      logger.info("[CopyrightClaims] Appeal resolved", { appealId, resolution });
      return true;
    } catch (error) {
      logger.error("[CopyrightClaims] Error resolving appeal", { appealId, error });
      return false;
    }
  }
}

export const copyrightClaimsService = new CopyrightClaimsService();
