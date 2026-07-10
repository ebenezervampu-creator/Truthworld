import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { VertexAI } from "@google-cloud/vertexai";

const db = () => admin.firestore();

/**
 * Common moderation logic shared by public and private playlists.
 */
async function moderatePlaylist(
  playlistId: string,
  playlistPath: string,
  beforeData: any,
  afterData: any,
  updateRef: admin.firestore.DocumentReference
) {
  // Extract names and descriptions
  const nameBefore = beforeData?.name || beforeData?.playlistName || "";
  const nameAfter = afterData.name || afterData.playlistName || "";
  const descBefore = beforeData?.description || "";
  const descAfter = afterData.description || "";

  const detailsChanged = nameBefore !== nameAfter || descBefore !== descAfter;

  // Prevent infinite loop: if details did not change and we already moderated it
  if (!detailsChanged && (afterData.geminiApproved !== undefined || afterData.status !== "underReview")) {
    return;
  }

  logger.info(`[moderatePlaylist] Starting Gemini moderation for playlist ${playlistId} at path ${playlistPath}`);

  const MAX_RETRIES = 3;
  const BACKOFF_BASE_MS = 2000;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const genAI = new VertexAI({ project: "truthworld-1", location: "asia-south1" });
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        systemInstruction: `You are an extremely strict, zero-tolerance content moderation system for Truthworld. Review the playlist details (name, description) for violations of the Community Guidelines.

COMMUNITY GUIDELINES & POLICIES:
1. No hate speech, harassment, cyberbullying, or discrimination of any kind.
2. No sexually explicit content, nudity, pornography, or sexually suggestive/provocative material (including innuendos).
3. No extreme violence, gore, self-harm, suicide encouragement, or dangerous/illegal activities.
4. No deceptive practices, spam, financial scams, phishing, get-rich-quick schemes, cryptocurrency promotions, or impersonation of known figures, brands, or public entities.
5. No promotion of terrorism, hate groups, or violence.
6. NO gibberish, nonsensical, placeholder, or testing-only content (e.g. "asdf", "test", "demo", "lorem ipsum"). All playlist details must look professional, legitimate, and ready for publication.
7. Playlist name and description must not contain links or URLs pointing to external sites.
8. Strictly NO romantic content or romantic love stories between opposite genders (boys and girls, or men and women), even within or after marriage. Romance between opposite genders is entirely prohibited. Only clean, public-friendly forms of love, such as familial love (e.g. father's love, mother's love, sister's/brother's love) or friendship, are welcomed and permitted.

DECISION RUBRIC:
- If a playlist name or description looks like a scam, get-rich-quick program, suspicious financial advice, or phishing attempt, set "approved" to false.
- If a playlist name or description is extremely low-effort, gibberish, or placeholders like "test", "testing", "asdfasdf", set "approved" to false.
- If a playlist mentions, promotes, or details romantic/romantic love stories between opposite genders (regardless of marriage status), set "approved" to false. Only allow clean, public-safe non-romantic love, such as familial love or friendship.
- If there's any ambiguity or borderline violation, err on the side of caution and set "approved" to false.

You must respond with a JSON object matching this schema:
{
  "approved": boolean,
  "reason": "Provide a detailed, custom explanation of at least 2-3 sentences. Do NOT use generic templates. For approvals, explain specifically why the playlist details are safe, constructive, and in alignment with our community guidelines. For rejections, specify exactly which guidelines or rules were violated, citing the specific offending words or phrases from the playlist details."
}`,
        generationConfig: {
          responseMimeType: "application/json",
        },
      });

      const prompt = `PLAYLIST NAME: "${nameAfter}"\nPLAYLIST DESCRIPTION: "${descAfter}"`;

      const result = await model.generateContent(prompt);
      const responseText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

      let responseObj: { approved?: boolean; reason?: string };
      try {
        responseObj = JSON.parse(responseText);
      } catch (parseErr) {
        logger.error(`[moderatePlaylist] Gemini returned non-JSON response for ${playlistId}`, { responseText });
        responseObj = { approved: false, reason: "AI moderation returned an invalid response format. Playlist details held for review." };
      }

      const approved = responseObj.approved === true;
      const reason = approved ? "" : (responseObj.reason || "Violated Community Guidelines");

      logger.info(`[moderatePlaylist] Gemini moderation finished for ${playlistId}: approved=${approved}, reason=${reason}`);

      // Update playlist status in Firestore
      await updateRef.update({
        geminiApproved: approved,
        status: approved ? "active" : "verificationRejected",
        moderationReason: reason,
        updatedAt: admin.firestore.Timestamp.now(),
      });

      return; // Success — exit retry loop
    } catch (err) {
      logger.error(`[moderatePlaylist] Attempt ${attempt + 1}/${MAX_RETRIES} failed for playlist ${playlistId}:`, err);

      if (attempt < MAX_RETRIES - 1) {
        const delayMs = BACKOFF_BASE_MS * Math.pow(2, attempt);
        logger.info(`[moderatePlaylist] Retrying in ${delayMs}ms...`);
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }

  // Retries exhausted
  logger.error(`[moderatePlaylist] All ${MAX_RETRIES} retries exhausted for playlist ${playlistId}. Marking as verificationRejected.`);
  await updateRef.update({
    geminiApproved: false,
    status: "verificationRejected",
    moderationReason: `Moderation check failed after ${MAX_RETRIES} attempts. Playlist is held for manual review.`,
    updatedAt: admin.firestore.Timestamp.now(),
  });
}

// 🛡️ ON PUBLIC PLAYLIST WRITTEN
export const onPublicPlaylistWritten = onDocumentWritten(
  {
    document: "public_playlists/{playlistId}",
    region: "asia-south1",
    retry: false,
    maxInstances: 2,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    const playlistId = event.params.playlistId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    // If document is deleted, do nothing
    if (!afterData) return;

    const ref = db().collection("public_playlists").doc(playlistId);
    await moderatePlaylist(playlistId, `public_playlists/${playlistId}`, beforeData, afterData, ref);
  }
);

// 🛡️ ON PRIVATE PLAYLIST WRITTEN
export const onPrivatePlaylistWritten = onDocumentWritten(
  {
    document: "users/{userId}/playlists/{playlistId}",
    region: "asia-south1",
    retry: false,
    maxInstances: 2,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    const userId = event.params.userId;
    const playlistId = event.params.playlistId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    // If document is deleted, do nothing
    if (!afterData) return;

    const ref = db().collection("users").doc(userId).collection("playlists").doc(playlistId);
    await moderatePlaylist(playlistId, `users/${userId}/playlists/${playlistId}`, beforeData, afterData, ref);
  }
);
