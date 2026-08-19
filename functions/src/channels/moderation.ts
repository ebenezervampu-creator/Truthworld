import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { getVertexAI } from "../pipeline/utils/ai-client";
import { COMMUNITY_GUIDELINES_TEXT, MODERATION_RESPONSE_SCHEMA } from "../moderation/communityGuidelinesPrompt";
import { isChannelsBypassed } from "../moderation/moderationModes";
import { requireAdmin } from "../utils/auth";

const db = () => admin.firestore();

/**
 * 🛡️ ON CHANNEL WRITTEN (Firestore Trigger)
 * Automatically moderates channel details (name, description, tags) using Gemini AI.
 */
export const onChannelWritten = onDocumentWritten(
  {
    document: "channels/{channelId}",
    region: "asia-south1",
    retry: false,
    maxInstances: 2,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    const channelId = event.params.channelId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    // If document is deleted, do nothing
    if (!afterData) return;

    // Extract names, descriptions, handles, tags
    const nameBefore = beforeData?.displayName || beforeData?.name || beforeData?.channelName || "";
    const nameAfter = afterData.displayName || afterData.name || afterData.channelName || "";
    const descBefore = beforeData?.about || beforeData?.description || "";
    const descAfter = afterData.about || afterData.description || "";
    const handleBefore = beforeData?.handle || beforeData?.customUrl || "";
    const handleAfter = afterData.handle || afterData.customUrl || "";
    const tagsBefore = Array.isArray(beforeData?.tags) ? beforeData.tags : [];
    const tagsAfter = Array.isArray(afterData.tags) ? afterData.tags : [];

    const tagsChanged = JSON.stringify(tagsBefore.slice().sort()) !== JSON.stringify(tagsAfter.slice().sort());
    const detailsChanged =
      nameBefore !== nameAfter ||
      descBefore !== descAfter ||
      handleBefore !== handleAfter ||
      tagsChanged;

    // Prevent infinite loop: if details did not change and we already moderated it
    if (!detailsChanged && (afterData.geminiApproved !== undefined || afterData.status !== "underReview")) {
      return;
    }

    // Check if Channel moderation is in Admin Only mode (Gemini bypassed)
    const bypassed = await isChannelsBypassed();
    if (bypassed) {
      logger.info(`[onChannelWritten] Channels moderation toggle is ON (Admin Only). Bypassing Gemini AI for channel ${channelId} and holding for Admin manual review.`);
      await db().collection("channels").doc(channelId).update({
        geminiApproved: false,
        status: "underReview",
        moderationReason: "Routed to Admin for manual review (Gemini AI bypassed).",
        bypassGemini: true,
        updatedAt: Date.now(),
      });
      return;
    }

    logger.info(`[onChannelWritten] Starting Gemini moderation for channel ${channelId}`);

    const MAX_RETRIES = 3;
    const BACKOFF_BASE_MS = 2000;

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const genAI = getVertexAI();
        const model = genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          systemInstruction: `You are an extremely strict, zero-tolerance content moderation system for Truthworld. Review the channel registration details (name, description, tags) for violations of the Community Guidelines.\n\n${COMMUNITY_GUIDELINES_TEXT}\n\nDECISION RUBRIC:\n- If a channel name or description looks like a scam, get-rich-quick program, suspicious financial advice, or phishing attempt, set "approved" to false.\n- If a channel name, description, or tags are extremely low-effort, gibberish, or placeholders like "test", "testing", "asdfasdf", set "approved" to false.`,
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: MODERATION_RESPONSE_SCHEMA,
          },
        });

        const prompt = `CHANNEL NAME: "${nameAfter}"\nCHANNEL DESCRIPTION: "${descAfter}"\nCHANNEL TAGS: [${tagsAfter.join(", ")}]`;

        const result = await model.generateContent(prompt);
        const responseText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

        let responseObj: { approved?: boolean; reason?: string };
        try {
          responseObj = JSON.parse(responseText);
        } catch (parseErr) {
          logger.error(`[onChannelWritten] Gemini returned non-JSON response for ${channelId}`, { responseText });
          responseObj = { approved: false, reason: "AI moderation returned an invalid response format. Channel details held for review." };
        }

        const approved = responseObj.approved === true;
        const reason = approved ? "" : (responseObj.reason || "Violated Community Guidelines");

        logger.info(`[onChannelWritten] Gemini moderation finished for ${channelId}: approved=${approved}, reason=${reason}`);

        // Update channel status in Firestore (DO NOT overwrite creator-provided categories)
        await db().collection("channels").doc(channelId).update({
          geminiApproved: approved,
          status: approved ? "active" : "verificationRejected",
          moderationReason: reason,
          updatedAt: Date.now(),
        });

        return; // Success — exit retry loop
      } catch (err) {
        logger.error(`[onChannelWritten] Attempt ${attempt + 1}/${MAX_RETRIES} failed for channel ${channelId}:`, err);

        if (attempt < MAX_RETRIES - 1) {
          const delayMs = BACKOFF_BASE_MS * Math.pow(2, attempt);
          logger.info(`[onChannelWritten] Retrying in ${delayMs}ms...`);
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
      }
    }

    // Retries exhausted
    logger.error(`[onChannelWritten] All ${MAX_RETRIES} retries exhausted for channel ${channelId}. Marking as verificationRejected.`);
    await db().collection("channels").doc(channelId).update({
      geminiApproved: false,
      status: "verificationRejected",
      moderationReason: `Moderation check failed after ${MAX_RETRIES} attempts. Channel is held for manual review.`,
      updatedAt: Date.now(),
    });
  }
);

/**
 * 🖼️ ON IMAGE VERIFICATION WRITTEN (Firestore Trigger)
 * Automatically syncs the status of the image verification to the corresponding channel.
 */
export const onImageVerificationWritten = onDocumentWritten(
  {
    document: "image_verification/{docId}",
    region: "asia-south1",
    retry: false,
    maxInstances: 2,
  },
  async (event) => {
    const docId = event.params.docId;
    const afterData = event.data?.after.data();

    // If document is deleted, do nothing
    if (!afterData) return;

    const status = afterData.status || "PENDING";
    const reason = afterData.reason || "";
    const category = afterData.category || "";

    if (category !== "avatar" && category !== "banner") {
      return; // Only care about avatar and banner
    }

    logger.info(`[onImageVerificationWritten] Syncing status ${status} for ${category} docId ${docId}`);

    const fieldId = category === "avatar" ? "avatarFileId" : "bannerFileId";
    const fieldStatus = category === "avatar" ? "avatarStatus" : "bannerStatus";
    const fieldReason = category === "avatar" ? "avatarStatusReason" : "bannerStatusReason";

    // Query for any channels where the avatarFileId or bannerFileId matches this docId
    const channelsSnap = await db()
      .collection("channels")
      .where(fieldId, "==", docId)
      .get();

    if (channelsSnap.empty) {
      logger.info(`[onImageVerificationWritten] No channels found with ${fieldId} = ${docId}`);
      return;
    }

    const batch = db().batch();
    channelsSnap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        [fieldStatus]: status,
        [fieldReason]: reason,
        updatedAt: Date.now(),
      });
    });

    await batch.commit();
    logger.info(`[onImageVerificationWritten] Successfully synced ${status} to ${channelsSnap.size} channels`);
  }
);

/**
 * 🛡️ HTTPS Endpoint — Manually moderate a channel (Approve or Reject).
 * Only accessible by authenticated administrators.
 */
export const moderateChannelManual = onRequest(
  {
    cors: true,
    region: "asia-south1",
    timeoutSeconds: 60,
    memory: "256MiB",
    maxInstances: 2,
  },
  async (req, res) => {
    try {
      const authUser = await requireAdmin(req, res);
      if (!authUser) return;

      const { channelId, action, reason } = req.body;

      if (!channelId || typeof channelId !== "string") {
        res.status(400).json({ error: "Missing or invalid channelId." });
        return;
      }

      if (action !== "approve" && action !== "reject") {
        res.status(400).json({ error: "Action must be 'approve' or 'reject'." });
        return;
      }

      const channelRef = db().collection("channels").doc(channelId);
      const channelDoc = await channelRef.get();

      if (!channelDoc.exists) {
        res.status(404).json({ error: "Channel not found." });
        return;
      }

      const now = Date.now();
      const approved = action === "approve";

      await channelRef.update({
        geminiApproved: approved,
        status: approved ? "active" : "verificationRejected",
        moderationReason: reason || (approved ? "Manually approved by administrator." : "Manually rejected by administrator."),
        manuallyVerified: true,
        verifiedBy: authUser.uid,
        verifiedAt: now,
        updatedAt: now,
      });

      res.status(200).json({ success: true, message: `Channel manually ${action}d.` });
    } catch (err) {
      logger.error("[moderateChannelManual] Error:", err);
      res.status(500).json({ error: "Internal server error.", details: String(err) });
    }
  }
);

