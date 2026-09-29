import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { getVertexAI } from "../pipeline/utils/ai-client";
import { COMMUNITY_GUIDELINES_TEXT, MODERATION_RESPONSE_SCHEMA } from "../moderation/communityGuidelinesPrompt";
import { isAdsBypassed } from "../moderation/moderationModes";
import { requireAuth, requireRecentAdmin } from "../utils/auth";
import { AdPipelineService } from "./adPipeline";
import { costEngine } from "../pipeline/services/cost-engine";

const db = () => admin.firestore();

/**
 * 🛡️ ON AD CAMPAIGN WRITTEN (Firestore Trigger)
 * Automatically moderates advertiser campaigns using Gemini AI.
 */
export const onAdCampaignWritten = onDocumentWritten(
  {
    document: "ad_campaigns/{campaignId}",
    region: "asia-south1",
    retry: false, // We handle retries internally with backoff
    maxInstances: 2,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    const campaignId = event.params.campaignId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    // If document is deleted, do nothing
    if (!afterData) return;

    // Determine if metadata fields changed
    const titleBefore = beforeData?.title || "";
    const titleAfter = afterData.title || "";
    const descBefore = beforeData?.description || "";
    const descAfter = afterData.description || "";
    const brandBefore = beforeData?.advertiser || "";
    const brandAfter = afterData.advertiser || "";
    const imageUrlBefore = beforeData?.imageUrl || "";
    const imageUrlAfter = afterData.imageUrl || "";
    const videoUrlBefore = beforeData?.videoUrl || "";
    const videoUrlAfter = afterData.videoUrl || "";
    const ctaTextBefore = beforeData?.ctaText || "";
    const ctaTextAfter = afterData.ctaText || "";
    const ctaTargetBefore = beforeData?.ctaTarget || "";
    const ctaTargetAfter = afterData.ctaTarget || "";
    const midrollVideoUrlBefore = beforeData?.midrollVideoUrl || "";
    const midrollVideoUrlAfter = afterData.midrollVideoUrl || "";
    const pinnedCommentTextBefore = beforeData?.pinnedCommentText || "";
    const pinnedCommentTextAfter = afterData.pinnedCommentText || "";

    const detailsChanged =
      titleBefore !== titleAfter ||
      descBefore !== descAfter ||
      brandBefore !== brandAfter ||
      imageUrlBefore !== imageUrlAfter ||
      videoUrlBefore !== videoUrlAfter ||
      ctaTextBefore !== ctaTextAfter ||
      ctaTargetBefore !== ctaTargetAfter ||
      midrollVideoUrlBefore !== midrollVideoUrlAfter ||
      pinnedCommentTextBefore !== pinnedCommentTextAfter;

    // Check if AI features were directly requested via Firestore stages.ai (e.g. offline/fallback trigger)
    const aiStageBefore = beforeData?.stages?.ai?.status;
    const aiStageAfter = afterData?.stages?.ai?.status;
    const aiRequested = aiStageAfter === "running" && aiStageBefore !== "running";

    if (aiRequested) {
      const aiConfig = afterData.stages?.ai || {};
      const features = Array.isArray(aiConfig.features) ? aiConfig.features : ["subtitles"];
      const targetLanguages = Array.isArray(aiConfig.targetLanguages) ? aiConfig.targetLanguages : ["hi"];
      const voiceStyle = aiConfig.voiceStyle || "natural";
      const sourceLang = aiConfig.sourceLang || "en";

      logger.info(`[onAdCampaignWritten] Direct Firestore trigger for AI features on campaign ${campaignId}`, {
        features,
        targetLanguages,
      });

      try {
        await AdPipelineService.processAdAIFeatures({
          campaignId,
          userId: afterData.userId || "system",
          features,
          targetLanguages,
          voiceStyle,
          sourceLang,
        });
      } catch (err) {
        logger.error(`[onAdCampaignWritten] Failed processing AI features via Firestore trigger for ${campaignId}:`, err);
      }
      return;
    }

    // If details did not change and geminiApproved is already defined, exit to avoid infinite loop
    if (!detailsChanged && (afterData.geminiApproved !== undefined || (afterData.status !== "underReview" && afterData.status !== undefined))) {
      return;
    }

    // Check if Advertiser Campaigns moderation is in Admin Only mode (Gemini bypassed)
    const bypassed = await isAdsBypassed();
    if (bypassed) {
      logger.info(`[onAdCampaignWritten] Advertiser campaign moderation toggle is ON (Admin Only). Bypassing Gemini AI for campaign ${campaignId} and holding for Admin manual review.`);
      await db().collection("ad_campaigns").doc(campaignId).update({
        geminiApproved: false,
        status: "underReview",
        moderationReason: "Routed to Admin for manual review (Gemini AI bypassed).",
        bypassGemini: true,
        updatedAt: Date.now(),
      });
      return;
    }

    logger.info(`[onAdCampaignWritten] Starting/re-triggering Gemini moderation for campaign ${campaignId}`);

    const MAX_RETRIES = 3;
    const BACKOFF_BASE_MS = 2000; // 2s, 4s, 8s

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const genAI = getVertexAI();
        const model = genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          systemInstruction: `You are a strict advertisement moderation system for Truthworld. Review the advertisement details (brand name, headline, description, CTA text, CTA target, and media URLs) for violations of the Community Guidelines and Advertising Standards.\n\n${COMMUNITY_GUIDELINES_TEXT}`,
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: MODERATION_RESPONSE_SCHEMA,
          },
        });

        const prompt = `ADVERTISER / BRAND NAME: "${brandAfter}"\nCAMPAIGN HEADLINE: "${titleAfter}"\nCAMPAIGN DESCRIPTION: "${descAfter}"\nCTA TEXT: "${ctaTextAfter}"\nCTA TARGET: "${ctaTargetAfter}"\nIMAGE URL: "${imageUrlAfter}"\nVIDEO URL: "${videoUrlAfter}"\nMIDROLL VIDEO URL: "${midrollVideoUrlAfter}"\nPINNED COMMENT TEXT: "${pinnedCommentTextAfter}"`;

        // Update retry status for UI feedback
        if (attempt > 0) {
          await db().collection("ad_campaigns").doc(campaignId).update({
            moderationRetryCount: attempt,
            updatedAt: Date.now(),
          });
        }

        const result = await model.generateContent(prompt);
        const responseText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

        // ── Cost Attribution: Track Gemini AI tokens used for ad moderation ──
        const usage = (result.response as any)?.usageMetadata;
        const promptTokens = usage?.promptTokenCount ?? Math.max(1, Math.ceil(prompt.length / 4));
        const candidateTokens = usage?.candidatesTokenCount ?? Math.max(1, Math.ceil(responseText.length / 4));
        const advertiserUserId = afterData.userId || "advertiser";

        costEngine.recordGeminiCost(
          campaignId,
          advertiserUserId,
          "ad_moderation",
          "flash",
          promptTokens,
          candidateTokens
        ).catch((costErr) => {
          logger.warn(`[onAdCampaignWritten] Failed to record Gemini moderation cost for ${campaignId}:`, costErr);
        });

        // ZERO-TOLERANCE: Safe JSON parse — default to rejected on malformed response
        let responseObj: { approved?: boolean; reason?: string };
        try {
          responseObj = JSON.parse(responseText);
        } catch (parseErr) {
          logger.error(`[onAdCampaignWritten] Gemini returned non-JSON response for ${campaignId}`, { responseText });
          responseObj = { approved: false, reason: "AI moderation returned an invalid response. Campaign held for safety review." };
        }

        const approved = responseObj.approved === true;
        const reason = approved ? null : (responseObj.reason || "Violated Advertising Standards");

        logger.info(`[onAdCampaignWritten] Gemini moderation finished for ${campaignId}: approved=${approved}, reason=${reason}`);

        // If approved, transition status to active (unless paused). If rejected, transition to verification_rejected.
        const finalStatus = approved 
          ? (afterData.status === 'paused' ? 'paused' : 'active')
          : 'verification_rejected';

        await db().collection("ad_campaigns").doc(campaignId).update({
          geminiApproved: approved,
          moderationReason: reason,
          moderationRetryCount: attempt,
          status: finalStatus,
          moderationTokens: {
            promptTokens,
            candidateTokens,
            totalTokens: promptTokens + candidateTokens,
          },
          updatedAt: Date.now(),
        });

        // Automatically trigger AI dubbing & subtitles for approved video ads if not already generated
        const hasVideoAsset = !!(
          afterData.videoUrl ||
          afterData.midrollVideoUrl ||
          (afterData.resolutions && Array.isArray(afterData.resolutions) && afterData.resolutions.length > 0)
        );
        const hasSubtitles = afterData.subtitles && Object.keys(afterData.subtitles).length > 0;
        const aiStage = afterData.stages?.ai?.status;

        if (approved && hasVideoAsset && !hasSubtitles && aiStage !== "running" && aiStage !== "completed") {
          logger.info(`[onAdCampaignWritten] Auto-queueing AI dubbing and subtitles for video ad ${campaignId}`);
          AdPipelineService.processAdAIFeatures({
            campaignId,
            userId: afterData.userId || "system",
            features: ["subtitles", "dubbing"],
            targetLanguages: ["te", "hi", "ta", "es"],
            voiceStyle: "natural",
            sourceLang: "en",
          }).catch((bgErr) => {
            logger.error(`[onAdCampaignWritten] Background auto-AI error for ${campaignId}:`, bgErr);
          });
        }

        return; // Success — exit retry loop
      } catch (err) {
        logger.error(`[onAdCampaignWritten] Attempt ${attempt + 1}/${MAX_RETRIES} failed for campaign ${campaignId}:`, err);

        if (attempt < MAX_RETRIES - 1) {
          const delayMs = BACKOFF_BASE_MS * Math.pow(2, attempt);
          logger.info(`[onAdCampaignWritten] Retrying in ${delayMs}ms...`);
          await new Promise(resolve => setTimeout(resolve, delayMs));
        }
      }
    }

    // ZERO-TOLERANCE: All retries exhausted — mark as verification_rejected (NOT left in limbo)
    logger.error(`[onAdCampaignWritten] All ${MAX_RETRIES} retries exhausted for campaign ${campaignId}. Marking as verification_rejected.`);
    await db().collection("ad_campaigns").doc(campaignId).update({
      geminiApproved: false,
      moderationReason: `Moderation check failed after ${MAX_RETRIES} attempts. Campaign is held for manual review.`,
      moderationRetryCount: MAX_RETRIES,
      status: "verification_rejected",
      updatedAt: Date.now(),
    });
  }
);

/**
 * 🪄 Trigger AI Features (Subtitles & Dubbing) for an Advertiser Campaign
 *
 * Supports generating subtitles (e.g. Telugu, Hindi, Spanish, etc.) and
 * AI-synthesized dubbed audio tracks on demand.
 */
export const triggerAdAIFeatures = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: [
      "GEMINI_API_KEY",
      "ASSEMBLYAI_KEY",
      "ELEVENLABS_API_KEY",
      "GOOGLE_TRANSLATION_API_KEY",
    ],
  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const {
        campaignId,
        features = ["subtitles", "dubbing"],
        targetLanguages = ["hi"],
        voiceStyle = "natural",
        sourceLang = "en",
      } = req.body || {};

      if (!campaignId) {
        res.status(400).json({ error: "Missing campaignId" });
        return;
      }

      const userId = authUser.uid;
      const adDocRef = admin.firestore().collection("ad_campaigns").doc(campaignId);
      const adSnap = await adDocRef.get();

      if (!adSnap.exists) {
        res.status(404).json({ error: "Ad campaign not found" });
        return;
      }

      const adData = adSnap.data() || {};

      // Verify authorization: owner or admin
      if (adData.userId && adData.userId !== userId && !authUser.isAdmin) {
        res.status(403).json({ error: "Unauthorized: You do not own this ad campaign" });
        return;
      }

      // Process AI features to completion before responding
      await AdPipelineService.processAdAIFeatures({
        campaignId,
        userId,
        features,
        targetLanguages,
        voiceStyle,
        sourceLang,
      });

      res.status(200).json({
        success: true,
        campaignId,
        message: `AI features (${features.join(", ")}) processed successfully for target languages: ${targetLanguages.join(", ")}`,
      });
    } catch (error) {
      console.error("[triggerAdAIFeatures] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal server error",
      });
    }
  }
);

/**
 * 🚀 Generate AI Features (Subtitles & Dubbing) for ALL Video Advertisements
 *
 * Scans all video advertisements across Truthworld and processes AI subtitles
 * and voice dubbing in the background.
 */
export const generateAllVideoAdsAIFeatures = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [
      "GEMINI_API_KEY",
      "ASSEMBLYAI_KEY",
      "ELEVENLABS_API_KEY",
      "GOOGLE_TRANSLATION_API_KEY",
    ],
  },
  async (req, res) => {
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
      if (!adminUser) return;

      const {
        features = ["subtitles", "dubbing"],
        targetLanguages = ["te", "hi", "ta", "es"],
        voiceStyle = "natural",
        sourceLang = "en",
        forceRegenerate = false,
      } = req.body || {};

      // Process batch synchronously within the allocated 540s container lifecycle
      const result = await AdPipelineService.processAllVideoAds({
        features,
        targetLanguages,
        voiceStyle,
        sourceLang,
        forceRegenerate,
      });

      logger.info("[generateAllVideoAdsAIFeatures] Batch processing complete", result);

      res.status(200).json({
        success: true,
        message: `Batch AI dubbing & subtitles job completed for all video ads with languages: ${targetLanguages.join(", ")}`,
        targetLanguages,
        features,
        result,
      });
    } catch (error) {
      console.error("[generateAllVideoAdsAIFeatures] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal server error",
      });
    }
  }
);


