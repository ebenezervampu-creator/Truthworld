import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { getVertexAI } from "../pipeline/utils/ai-client";
import { COMMUNITY_GUIDELINES_TEXT, MODERATION_RESPONSE_SCHEMA } from "./communityGuidelinesPrompt";

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

  const cleanName = nameAfter.trim().toLowerCase();
  if (
    !cleanName ||
    cleanName === "playlist" ||
    cleanName === "truthworld playlist" ||
    cleanName.startsWith("untitled")
  ) {
    logger.info(`[moderatePlaylist] Rejecting placeholder playlist ${playlistId}: "${nameAfter}"`);
    await updateRef.update({
      geminiApproved: false,
      status: "verificationRejected",
      moderationReason: "Playlist name is a placeholder (e.g. 'Playlist', 'Untitled') and cannot be published.",
      updatedAt: admin.firestore.Timestamp.now(),
    });
    return;
  }

  logger.info(`[moderatePlaylist] Starting Gemini moderation for playlist ${playlistId} at path ${playlistPath}`);

  const MAX_RETRIES = 3;
  const BACKOFF_BASE_MS = 2000;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const genAI = getVertexAI();
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash",
        systemInstruction: `You are an extremely strict, zero-tolerance content moderation system for Truthworld. Review the playlist details (name, description) for violations of the Community Guidelines.\n\n${COMMUNITY_GUIDELINES_TEXT}\n\nDECISION RUBRIC:\n- If a playlist name or description looks like a scam, get-rich-quick program, suspicious financial advice, or phishing attempt, set "approved" to false.\n- If a playlist name or description is extremely low-effort, gibberish, or placeholders like "test", "testing", "asdfasdf", set "approved" to false.`,
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: MODERATION_RESPONSE_SCHEMA,
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
