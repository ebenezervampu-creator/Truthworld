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
import { getVertexAI } from "../utils/ai-client";
import {
  CopyrightClaim,
  CopyrightMatch,
  DETECTION_THRESHOLDS,
  FairUseAnalysis,
  ClaimNoticeType,
  ClaimStatus,
  ClaimImpact,
  CopyrightOwnerAction,
  CopyrightOwnerNotification,
  ChannelStrike,
} from "./copyrightTypes";
import { copyrightDetectionService } from "./copyrightDetection";
import { getBigQueryAnalyticsService } from "../../analytics/bigqueryService";
import { v4 as uuidv4 } from "uuid";
import { PIPELINE_CONFIG } from "../config";
import { extractCandidateText } from "../utils/ai-utils";
import { videoDocExists } from "../../utils/videosCollectionGuard";

const db = () => admin.firestore();

// Detector Versioning metadata constants
const DETECTOR_VERSION = 2;
const EMBEDDING_MODEL = "text-embedding-005";
const GEMINI_MODEL = PIPELINE_CONFIG.GEMINI_MODELS?.moderation || PIPELINE_CONFIG.GEMINI_MODELS?.synthesis || "gemini-3.5-flash-lite";
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
      // ── Stream Claim to BigQuery (Non-blocking) ──
      try {
        const bq = getBigQueryAnalyticsService();
        bq.enqueueCopyrightClaim({
          claim_id: claimId,
          timestamp: new Date().toISOString(),
          match_id: match.matchId,
          asset_id: match.assetId,
          original_video_id: match.assetId,
          infringing_video_id: match.matchedVideoId,
          claimant_id: claimantChannelName,
          infringing_creator_id: match.matchedOwnerId || null,
          claim_status: status,
          claim_policy: claimPolicy,
          claim_impact: impact,
          fair_use_score: fairUse.score,
          fair_use_category: fairUse.category,
          resolved_at: null,
          resolution_reason: null,
        });

        if (claimPolicy === "monetize_shared") {
          bq.enqueueMonetizationDeduction({
            deduction_id: `deduct_${claimId}`,
            timestamp: new Date().toISOString(),
            video_id: match.matchedVideoId,
            source_channel_id: channelId || match.matchedChannelId || "unknown",
            beneficiary_channel_id: assetData.channelId || "unknown",
            claim_id: claimId,
            deduction_type: "copyright_split",
            split_ratio: 0.50, // Standard 50/50 shared copyright monetization split
            gross_revenue_inr: 0,
            diverted_amount_inr: 0,
            currency: "INR",
          });
        }
      } catch (bqErr) {
        logger.warn("[CopyrightClaims] BigQuery claim streaming warning", { err: String(bqErr) });
      }

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

      // ── Stream Appeal to BigQuery (Non-blocking) ──
      try {
        const bq = getBigQueryAnalyticsService();
        bq.enqueueCopyrightAppeal({
          appeal_id: appealId,
          timestamp: new Date().toISOString(),
          claim_id: claimId,
          video_id: claimData.videoId,
          appellant_id: userId,
          claimant_id: claimData.ownerId || claimData.claimant || null,
          appeal_status: "pending",
          appellant_reason: reason,
          ai_fair_use_score: null,
          resolved_at: null,
        });
      } catch (bqErr) {
        logger.warn("[CopyrightClaims] BigQuery appeal streaming warning", { err: String(bqErr) });
      }

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
      const vertexAI = getVertexAI();
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
      const text = extractCandidateText(result.response.candidates?.[0]) || result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
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
      // ── Stream Appeal Resolution to BigQuery (Non-blocking) ──
      try {
        const bq = getBigQueryAnalyticsService();
        bq.enqueueCopyrightAppeal({
          appeal_id: appealId,
          timestamp: new Date().toISOString(),
          claim_id: claimId,
          video_id: appealData.videoId || "",
          appellant_id: appealData.uploaderId || "",
          claimant_id: null,
          appeal_status: resolution === "approved" ? "accepted" : "rejected",
          appellant_reason: appealData.reason || null,
          ai_fair_use_score: appealData.aiFairUseScore ?? null,
          resolved_at: new Date().toISOString(),
        });
      } catch (bqErr) {
        logger.warn("[CopyrightClaims] BigQuery appeal resolution streaming warning", { err: String(bqErr) });
      }

      logger.info("[CopyrightClaims] Appeal resolved", { appealId, resolution });
      return true;
    } catch (error) {
      logger.error("[CopyrightClaims] Error resolving appeal", { appealId, error });
      return false;
    }
  }

  /**
   * 🛡️ STEP 4 PARALLEL COPYRIGHT MATCH HANDLER
   * Called when a copyright match is detected in parallel with Step 4.
   * Pauses Step 4 publication and notifies the original copyright owner.
   */
  async handleStep4CopyrightMatch(
    jobId: string,
    videoId: string,
    copiedUserId: string,
    copiedChannelId: string,
    videoTitle: string,
    thumbnailUrl: string,
    match: CopyrightMatch
  ): Promise<string> {
    const notificationId = `cp_notif_${uuidv4()}`;
    logger.info("[CopyrightClaims] Handling Step 4 Copyright Match", { videoId, matchId: match.matchId });

    try {
      const assetSnap = await db().collection("copyright_assets").doc(match.assetId).get();
      const originalOwnerId = assetSnap.exists ? (assetSnap.data()?.ownerId || "unknown") : "unknown";

      const notification: CopyrightOwnerNotification = {
        notificationId,
        matchId: match.matchId,
        assetId: match.assetId,
        originalOwnerId,
        copiedVideoId: videoId,
        copiedUserId,
        copiedChannelId,
        videoTitle,
        thumbnailUrl,
        matchedSegments: match.matchedSegments || [],
        similarityScore: match.score || 0.9,
        status: "pending_owner_action",
        createdAt: Date.now()
      };
      (notification as any).escrowStatus = "holding";
      (notification as any).escrowBalance = 0;

      const batch = db().batch();
      batch.set(db().collection("copyright_owner_notifications").doc(notificationId), notification);

      // Pause Video and Job at Step 4 (copyright_hold) with Truthworld Escrow holding
      if (await videoDocExists(videoId, "[CopyrightClaims:Hold]")) {
        batch.set(db().collection("videos").doc(videoId), {
          copyrightStatus: "copyright_hold",
          escrowStatus: "holding",
          gatewayStatus: "MANUAL_REVIEW",
          status: "copyright_hold",
          isPublished: false,
          copyrightNotificationId: notificationId,
          updatedAt: Date.now()
        }, { merge: true });
      }

      batch.set(db().collection("video_jobs").doc(jobId), {
        status: "copyright_hold",
        copyrightNotificationId: notificationId,
        updatedAt: Date.now()
      }, { merge: true });

      await batch.commit();
      logger.info("[CopyrightClaims] Step 4 Copyright Hold applied & owner notified", { notificationId, originalOwnerId });
      return notificationId;
    } catch (error) {
      logger.error("[CopyrightClaims] Error handling Step 4 Copyright match", { error });
      throw error;
    }
  }

  /**
   * 🛡️ RESOLVE COPYRIGHT OWNER ACTION
   * Called when original copyright owner picks an option:
   * - YELLOW_STRIKE: Strike channel & Delete/Terminate video at Step 4
   * - REDIRECT_MONETIZATION: Redirect revenue to owner & Resume Step 4 pipeline
   * - NO_OBJECTION: License video & Resume Step 4 pipeline
   */
  async resolveCopyrightOwnerAction(
    notificationId: string,
    ownerId: string,
    action: CopyrightOwnerAction,
    distributionLayer?: any
  ): Promise<{ success: boolean; message: string }> {
    logger.info("[CopyrightClaims] Resolving Copyright Owner Action", { notificationId, ownerId, action });

    try {
      const notifRef = db().collection("copyright_owner_notifications").doc(notificationId);
      const notifSnap = await notifRef.get();

      if (!notifSnap.exists) {
        return { success: false, message: "Copyright notification not found" };
      }

      const notif = notifSnap.data() as CopyrightOwnerNotification;
      if (notif.originalOwnerId !== ownerId && ownerId !== "admin") {
        return { success: false, message: "Forbidden: You are not the original copyright owner" };
      }

      const videoId = notif.copiedVideoId;
      const jobId = notif.copiedVideoId; // Standardized fallback

      if (action === "YELLOW_STRIKE") {
        const strikeId = `strike_${uuidv4()}`;
        const strike: ChannelStrike = {
          strikeId,
          channelId: notif.copiedChannelId || "unknown",
          userId: notif.copiedUserId,
          videoId,
          strikeType: "yellow_copyright",
          reason: `Yellow Copyright Takedown Strike issued by owner of asset ${notif.assetId}`,
          assetId: notif.assetId,
          issuedAt: Date.now(),
          expiresAt: Date.now() + (90 * 24 * 60 * 60 * 1000) // 90 days TTL
        };

        const batch = db().batch();
        batch.set(db().collection("channel_strikes").doc(strikeId), strike);
        batch.update(notifRef, {
          status: "action_taken",
          selectedAction: action,
          actionTakenAt: Date.now()
        });

        // DELETE & TERMINATE VIDEO AT STEP 4
        batch.delete(db().collection("videos").doc(videoId));
        batch.set(db().collection("video_jobs").doc(jobId), {
          status: "failed",
          failureReason: "Video terminated at Step 4 due to Yellow Copyright Strike by copyright owner.",
          terminatedAt: Date.now()
        }, { merge: true });

        await batch.commit();
        logger.info("[CopyrightClaims] Yellow Strike issued & video deleted at Step 4", { videoId, strikeId });
        return { success: true, message: "Yellow Strike issued. Video deleted and pipeline terminated." };
      }

      if (action === "REDIRECT_MONETIZATION" || action === "NO_OBJECTION") {
        const isRedirect = action === "REDIRECT_MONETIZATION";
        const batch = db().batch();

        batch.update(notifRef, {
          status: "action_taken",
          selectedAction: action,
          actionTakenAt: Date.now(),
          escrowStatus: isRedirect ? "payout_to_owner" : "payout_to_creator",
          escrowPaidOutAt: Date.now()
        });

        if (await videoDocExists(videoId, "[CopyrightClaims:Resolve]")) {
          batch.set(db().collection("videos").doc(videoId), {
            copyrightStatus: isRedirect ? "claimed" : "clear",
            copyrightLicensed: !isRedirect,
            monetizationRedirectedTo: isRedirect ? notif.originalOwnerId : null,
            escrowStatus: isRedirect ? "payout_to_owner" : "payout_to_creator",
            gatewayStatus: "APPROVED",
            status: "published",
            isPublished: true,
            updatedAt: Date.now()
          }, { merge: true });
        }

        batch.set(db().collection("video_jobs").doc(jobId), {
          status: "published",
          copyrightStatus: isRedirect ? "claimed" : "clear",
          updatedAt: Date.now()
        }, { merge: true });

        await batch.commit();

        // RESUME PIPELINE: Publish enabled independent pipelines (Credibility and/or Localization)
        if (distributionLayer) {
          const { isCredibilityEnabled, isLocalizationEnabled } = require("../types");
          const resumeJobSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
          const resumePlan = resumeJobSnap?.exists && resumeJobSnap.data()?.executionPlan
            ? resumeJobSnap.data()!.executionPlan
            : {};
          const resumeVideoUrl = resumeJobSnap?.data()?.videoUrl || "";

          if (isCredibilityEnabled(resumePlan)) {
            await distributionLayer.publish("fact-processing", {
              eventId: `fact_resume_${jobId}`,
              eventType: "fact-processing",
              jobId,
              userId: notif.copiedUserId,
              timestamp: Date.now(),
              data: { videoUrl: resumeVideoUrl, executionPlan: resumePlan },
              retryCount: 0,
              source: "copyright-resume"
            });
          }

          if (isLocalizationEnabled(resumePlan)) {
            await distributionLayer.publish("dubbing-processing", {
              eventId: `dub_resume_${jobId}`,
              eventType: "dubbing-processing",
              jobId,
              userId: notif.copiedUserId,
              timestamp: Date.now(),
              data: { videoUrl: resumeVideoUrl, executionPlan: resumePlan },
              retryCount: 0,
              source: "copyright-resume"
            });
          }
        }

        logger.info(`[CopyrightClaims] Pipeline resumed post-copyright resolution (${action}) with Truthworld Escrow Payout`, { videoId });
        return {
          success: true,
          message: isRedirect
            ? "Monetization redirected to copyright owner. Ad revenue Escrow paid out to owner. Pipeline resumed from Step 4."
            : "No objection logged. Claim released and Escrow paid out to creator. Pipeline resumed from Step 4."
        };
      }

      return { success: false, message: "Invalid action type" };
    } catch (error) {
      logger.error("[CopyrightClaims] Error resolving owner action", { error });
      return { success: false, message: `Error: ${(error as any).message}` };
    }
  }
}

export const copyrightClaimsService = new CopyrightClaimsService();
