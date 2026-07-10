import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { VertexAI } from "@google-cloud/vertexai";

const db = () => admin.firestore();

function getGcsPathFromUrl(url: string): string | null {
  if (!url) return null;
  try {
    const decoded = decodeURIComponent(url);
    const parts = decoded.split('/o/');
    if (parts.length > 1) {
      return parts[1].split('?')[0];
    }
  } catch (e) {
    logger.error("Error parsing URL for GCS path", e);
  }
  return null;
}

function getMimeTypeFromPath(filePath: string): string {
  const ext = filePath.split('.').pop()?.toLowerCase();
  switch (ext) {
    case 'png': return 'image/png';
    case 'webp': return 'image/webp';
    case 'gif': return 'image/gif';
    case 'jpg':
    case 'jpeg':
    default: return 'image/jpeg';
  }
}

const TOPIC_MODERATION_SYSTEM_PROMPT = `You are an extremely strict, zero-tolerance content moderation system for Truthworld. Review the topic details (title, handle, description) and optional thumbnail image (if present) for violations of the Community Guidelines.

COMMUNITY GUIDELINES & POLICIES:
1. No hate speech, harassment, cyberbullying, or discrimination of any kind.
2. No sexually explicit content, nudity, pornography, or sexually suggestive/provocative material.
3. No extreme violence, gore, self-harm, suicide encouragement, or dangerous/illegal activities.
4. No deceptive practices, spam, financial scams, phishing, cryptocurrency promotions, or impersonation of known figures/brands.
5. No promotion of terrorism, hate groups, or violence.
6. NO gibberish, nonsensical, placeholder, or testing-only content (e.g. "asdf", "test", "demo", "lorem ipsum"). All topic details must look professional, legitimate, and ready for publication.
7. Topic name and description must not contain links or URLs pointing to external sites.
8. Strictly NO romantic content or romantic love stories between opposite genders (boys and girls, or men and women), even within or after marriage. Romance between opposite genders is entirely prohibited. Only clean, public-friendly forms of love, such as familial love (e.g. father's love, mother's love, sister's/brother's love) or friendship, are welcomed and permitted.
9. Profanity, vulgar language, and swearing are strictly prohibited.

DECISION RUBRIC:
- If a topic name, handle, or description contains any profanity, vulgarity, hate speech, or sexually suggestive words, set "approved" to false.
- If a topic name, handle, or description contains placeholder/gibberish text, set "approved" to false.
- If a topic mentions, promotes, or details romantic/romantic love stories between opposite genders, set "approved" to false.
- If a custom thumbnail image is provided, inspect it: if it contains any sexually explicit material, violence, gore, hate symbols, text with profanity, or other guideline violations, set "approved" to false.
- If there's any ambiguity or borderline violation, err on the side of caution and set "approved" to false.

You must respond with a JSON object matching this schema:
{
  "approved": boolean,
  "reason": "Provide a detailed, custom explanation of at least 2-3 sentences. Do NOT use generic templates. For approvals, explain specifically why the topic details are safe, constructive, and in alignment with our community guidelines. For rejections, specify exactly which guidelines or rules were violated, citing the specific offending words, phrases, or visual elements."
}`;

/**
 * 🛡️ ON TOPIC WRITTEN (Firestore Trigger)
 * Automatically moderates topic details (title, handle, description) and custom thumbnail using Gemini AI.
 */
export const onTopicWritten = onDocumentWritten(
  {
    document: "topics/{topicId}",
    region: "asia-south1",
    retry: false,
    maxInstances: 2,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    const topicId = event.params.topicId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    // If document is deleted, do nothing
    if (!afterData) return;

    // Extract fields
    const titleBefore = beforeData?.title || "";
    const titleAfter = afterData.title || "";
    const handleBefore = beforeData?.handle || "";
    const handleAfter = afterData.handle || "";
    const descBefore = beforeData?.description || "";
    const descAfter = afterData.description || "";
    const thumbBefore = beforeData?.thumbnailUrl || "";
    const thumbAfter = afterData.thumbnailUrl || "";

    const detailsChanged =
      titleBefore !== titleAfter ||
      handleBefore !== handleAfter ||
      descBefore !== descAfter ||
      thumbBefore !== thumbAfter;

    // Prevent infinite loop: if details did not change and we already moderated it
    if (!detailsChanged && (afterData.geminiApproved !== undefined || afterData.status !== "underReview")) {
      return;
    }

    logger.info(`[onTopicWritten] Starting Gemini moderation for topic ${topicId}`);

    // Check if the custom image has already been verified in image_verification collection
    let imageApproved = true;
    let imageReason = "";

    if (thumbAfter) {
      const gcsPath = getGcsPathFromUrl(thumbAfter);
      if (gcsPath) {
        const filename = gcsPath.split('/').pop();
        if (filename) {
          // Check image_verification doc (often created by Storage ingestUploadedImage trigger)
          const imgVerSnap = await db().collection("image_verification").doc(filename).get();
          if (imgVerSnap.exists) {
            const imgVerData = imgVerSnap.data();
            if (imgVerData?.status === "REJECTED") {
              imageApproved = false;
              imageReason = `Uploaded custom image was rejected: ${imgVerData.reason || "Violated guidelines"}`;
            } else if (imgVerData?.status === "FLAGGED") {
              imageApproved = false;
              imageReason = `Uploaded custom image was flagged for manual review: ${imgVerData.reason || "Violated guidelines"}`;
            }
          }
        }
      }
    }

    if (!imageApproved) {
      logger.info(`[onTopicWritten] Topic ${topicId} custom image rejected beforehand. Rejecting topic.`);
      await db().collection("topics").doc(topicId).update({
        geminiApproved: false,
        status: "verificationRejected",
        moderationReason: imageReason,
        updatedAt: Date.now(),
      });
      return;
    }

    const MAX_RETRIES = 3;
    const BACKOFF_BASE_MS = 2000;

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const genAI = new VertexAI({ project: "truthworld-1", location: "asia-south1" });
        const model = genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          systemInstruction: TOPIC_MODERATION_SYSTEM_PROMPT,
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1,
          },
        });

        const contents: any[] = [];
        const parts: any[] = [];

        // If topic has a custom thumbnail, send the GCS URI directly to Gemini
        if (thumbAfter) {
          const gcsPath = getGcsPathFromUrl(thumbAfter);
          if (gcsPath) {
            const mimeType = getMimeTypeFromPath(gcsPath);
            parts.push({
              fileData: {
                mimeType,
                fileUri: `gs://truthworld-1.firebasestorage.app/${gcsPath}`,
              },
            });
          }
        }

        parts.push({
          text: `TOPIC NAME: "${titleAfter}"\nTOPIC HANDLE: "${handleAfter}"\nTOPIC DESCRIPTION: "${descAfter}"`,
        });

        contents.push({
          role: "user",
          parts: parts,
        });

        const result = await model.generateContent({ contents });
        const responseText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

        let responseObj: { approved?: boolean; reason?: string };
        try {
          responseObj = JSON.parse(responseText);
        } catch (parseErr) {
          logger.error(`[onTopicWritten] Gemini returned non-JSON response for ${topicId}`, { responseText });
          responseObj = { approved: false, reason: "AI moderation returned an invalid response format. Topic details held for review." };
        }

        const approved = responseObj.approved === true;
        const reason = approved ? "" : (responseObj.reason || "Violated Community Guidelines");

        logger.info(`[onTopicWritten] Gemini moderation finished for ${topicId}: approved=${approved}, reason=${reason}`);

        // Update topic status in Firestore
        await db().collection("topics").doc(topicId).update({
          geminiApproved: approved,
          status: approved ? "active" : "verificationRejected",
          moderationReason: reason,
          updatedAt: Date.now(),
        });

        return; // Success — exit retry loop
      } catch (err) {
        logger.error(`[onTopicWritten] Attempt ${attempt + 1}/${MAX_RETRIES} failed for topic ${topicId}:`, err);

        if (attempt < MAX_RETRIES - 1) {
          const delayMs = BACKOFF_BASE_MS * Math.pow(2, attempt);
          logger.info(`[onTopicWritten] Retrying in ${delayMs}ms...`);
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
      }
    }

    // Retries exhausted
    logger.error(`[onTopicWritten] All ${MAX_RETRIES} retries exhausted for topic ${topicId}. Marking as verificationRejected.`);
    await db().collection("topics").doc(topicId).update({
      geminiApproved: false,
      status: "verificationRejected",
      moderationReason: `Moderation check failed after ${MAX_RETRIES} attempts. Topic is held for manual review.`,
      updatedAt: Date.now(),
    });
  }
);
