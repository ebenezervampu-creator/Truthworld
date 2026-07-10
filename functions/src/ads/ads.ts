import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { VertexAI } from "@google-cloud/vertexai";

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

    // If details did not change and geminiApproved is already defined, exit to avoid infinite loop
    if (!detailsChanged && afterData.geminiApproved !== undefined) {
      return;
    }

    logger.info(`[onAdCampaignWritten] Starting/re-triggering Gemini moderation for campaign ${campaignId}`);

    const MAX_RETRIES = 3;
    const BACKOFF_BASE_MS = 2000; // 2s, 4s, 8s

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const genAI = new VertexAI({ project: "truthworld-1", location: "asia-south1" });
        const model = genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          systemInstruction: `You are a strict advertisement moderation system for Truthworld. Review the advertisement details (brand name, headline, description, CTA text, CTA target, and media URLs) for violations of the Community Guidelines and Advertising Standards.

COMMUNITY GUIDELINES & ADVERTISING STANDARDS:
1. No hate speech, harassment, cyberbullying, or discrimination of any kind.
2. No sexually explicit content, nudity, pornography, or sexually suggestive material.
3. No extreme violence, gore, self-harm, suicide encouragement, or dangerous/illegal activities.
4. No deceptive practices, spam, financial scams, phishing, or impersonation of known figures or brands. The destination URL must look legitimate.
5. No promotion of terrorism, hate groups, or violence.
6. No offensive language or profanity in the ad copy.
7. Advertisements must not be misleading or make false claims.

You must respond with a JSON object matching this schema:
{
  "approved": boolean,
  "reason": "Explain the decision clearly. If rejected, specify exactly which guidelines were violated and why."
}`,
          generationConfig: {
            responseMimeType: "application/json",
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
          updatedAt: Date.now(),
        });

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
