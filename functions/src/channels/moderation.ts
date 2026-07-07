import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { VertexAI } from "@google-cloud/vertexai";

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

    logger.info(`[onChannelWritten] Starting Gemini moderation for channel ${channelId}`);

    const MAX_RETRIES = 3;
    const BACKOFF_BASE_MS = 2000;

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const genAI = new VertexAI({ project: "truthworld-1", location: "asia-south1" });
        const model = genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          systemInstruction: `You are an extremely strict, zero-tolerance content moderation system for Truthworld. Review the channel registration details (name, description, tags) for violations of the Community Guidelines.

COMMUNITY GUIDELINES & POLICIES:
1. No hate speech, harassment, cyberbullying, or discrimination of any kind.
2. No sexually explicit content, nudity, pornography, or sexually suggestive/provocative material (including innuendos).
3. No extreme violence, gore, self-harm, suicide encouragement, or dangerous/illegal activities.
4. No deceptive practices, spam, financial scams, phishing, get-rich-quick schemes, cryptocurrency promotions, or impersonation of known figures, brands, or public entities.
5. No promotion of terrorism, hate groups, or violence.
6. NO gibberish, nonsensical, placeholder, or testing-only content (e.g. "asdf", "test", "demo", "lorem ipsum"). All channel details must look professional, legitimate, and ready for publication.
7. Channel name and description must not contain links or URLs pointing to external sites.
8. Strictly NO romantic content or romantic love stories between opposite genders (boys and girls, or men and women), even within or after marriage. Romance between opposite genders is entirely prohibited. Only clean, public-friendly forms of love, such as familial love (e.g. father's love, mother's love, sister's/brother's love) or friendship, are welcomed and permitted.

DECISION RUBRIC:
- If a channel name or description looks like a scam, get-rich-quick program, suspicious financial advice, or phishing attempt, set "approved" to false.
- If a channel name, description, or tags are extremely low-effort, gibberish, or placeholders like "test", "testing", "asdfasdf", set "approved" to false.
- If a channel mentions, promotes, or details romantic/romantic love stories between opposite genders (regardless of marriage status), set "approved" to false. Only allow clean, public-safe non-romantic love, such as familial love or friendship.
- If there's any ambiguity or borderline violation, err on the side of caution and set "approved" to false.

You must respond with a JSON object matching this schema:
{
  "approved": boolean,
  "reason": "Provide a detailed, custom explanation of at least 2-3 sentences. Do NOT use generic templates. For approvals, explain specifically why the channel details are safe, constructive, and in alignment with our community guidelines. For rejections, specify exactly which guidelines or rules were violated, citing the specific offending words or phrases from the channel registration details."
}`,
          generationConfig: {
            responseMimeType: "application/json",
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

        // Update channel status in Firestore
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
