import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { Comment } from "./types";

// Safe db access function/instance
const db = () => admin.firestore();

// Sanitize text simple implementation to strip script/iframe tags
function sanitizeText(text: string): string {
  return text
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
    .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, "")
    .replace(/on\w+="[^"]*"/gi, "")
    .replace(/on\w+='[^']*'/gi, "")
    .replace(/on\w+=\w+/gi, "")
    .replace(/javascript:/gi, "javascript_blocked:")
    .trim();
}

/**
 * 💬 ADD COMMENT (Callable - Flat Collection)
 * Records a comment with the author's trust snapshot for weighted ranking.
 */
export const addComment = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { videoId, text, parentId } = request.data;
    if (!videoId || !text) throw new HttpsError("invalid-argument", "Missing data.");

    try {
      const channelSnap = await db().collection("channels").doc(userId).get();
      const channelData = channelSnap.data();
      const channelRating = channelData?.reputation?.channelRating ?? channelData?.reputation?.avgTrustIndex ?? 5.0;

      const commentId = db().collection("comments").doc().id;
      const comment: Comment = {
        id: commentId,
        videoId,
        userId,
        userName: channelData?.name || "Anonymous",
        userAvatar: channelData?.profile?.avatarUrl,
        userTrustIndex: channelRating,
        text: sanitizeText(text.slice(0, 1000)),
        likes: 0,
        dislikes: 0,
        authorRankScore: (channelRating * 0.3),
        createdAt: Date.now(),
        parentId: parentId || null
      };

      await db().collection("comments").doc(commentId).set(comment);
      
      return { success: true, commentId };
    } catch (err) {
      logger.error("[addComment] Error:", err);
      throw new HttpsError("internal", "Failed to add comment.");
    }
  }
);

/**
 * 📥 GET COMMENTS (Callable - Flat Collection)
 */
export const getComments = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const { videoId, limit = 20 } = request.data;
    if (!videoId) throw new HttpsError("invalid-argument", "Missing videoId.");

    try {
      const snap = await db().collection("comments")
        .where("videoId", "==", videoId)
        .where("parentId", "==", null)
        .orderBy("authorRankScore", "desc")
        .limit(limit)
        .get();

      const comments = snap.docs.map(doc => doc.data() as Comment);
      return { comments };
    } catch (err) {
      logger.error("[getComments] Error:", err);
      throw new HttpsError("internal", "Failed to fetch comments.");
    }
  }
);

// ============================================================================
// NESTED SCHEMA OPERATIONS (For UI streams & backwards compatibility)
// ============================================================================

/**
 * 💬 ADD COMMENT NESTED (Callable)
 * Targets: videos/{videoId}/comments
 */
export const addCommentNested = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const {
      videoId,
      userName,
      userProfilePicUrl,
      channelId,
      channelName,
      channelProfilePicUrl,
      text,
    } = request.data;

    if (!videoId || !text || typeof text !== "string") {
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    if (text.trim().length === 0 || text.length > 5000) {
      throw new HttpsError("out-of-range", "Comment length invalid.");
    }

    try {
      const sanitizedText = sanitizeText(text);
      const docRef = db().collection("videos").doc(videoId).collection("comments").doc();

      const commentData = {
        userId,
        userName: userName || "Anonymous",
        userProfilePicUrl: userProfilePicUrl || "",
        channelId: channelId || userId,
        channelName: channelName || null,
        channelProfilePicUrl: channelProfilePicUrl || null,
        text: sanitizedText,
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        hasCreatorReply: false,
        likedBy: {},
        dislikedBy: {},
      };

      await docRef.set(commentData);
      return { success: true, commentId: docRef.id };
    } catch (err) {
      logger.error("[addCommentNested] Error:", err);
      throw new HttpsError("internal", "Failed to create comment.");
    }
  }
);

/**
 * 💬 ADD REPLY NESTED (Callable)
 * Targets: videos/{videoId}/comments/{commentId}/replies
 */
export const addReplyNested = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const {
      videoId,
      commentId,
      userName,
      userProfilePicUrl,
      channelId,
      channelName,
      channelProfilePicUrl,
      text,
    } = request.data;

    if (!videoId || !commentId || !text || typeof text !== "string") {
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    try {
      const sanitizedText = sanitizeText(text);
      const docRef = db()
        .collection("videos")
        .doc(videoId)
        .collection("comments")
        .doc(commentId)
        .collection("replies")
        .doc();

      const replyData = {
        commentId,
        videoId,
        userId,
        userName: userName || "Anonymous",
        userProfilePicUrl: userProfilePicUrl || "",
        channelId: channelId || userId,
        channelName: channelName || null,
        channelProfilePicUrl: channelProfilePicUrl || null,
        text: sanitizedText,
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        likedBy: {},
        dislikedBy: {},
      };

      await docRef.set(replyData);
      return { success: true, replyId: docRef.id };
    } catch (err) {
      logger.error("[addReplyNested] Error:", err);
      throw new HttpsError("internal", "Failed to create reply.");
    }
  }
);

/**
 * 👍👎 TOGGLE COMMENT INTERACTION (Callable)
 * Safely executes backend transaction to increment/decrement likeCount/dislikeCount
 */
export const toggleCommentInteraction = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { videoId, commentId, interactionType, asChannel } = request.data;
    // interactionType: "like" | "dislike" | "remove"
    if (!videoId || !commentId || !interactionType) {
      throw new HttpsError("invalid-argument", "Missing parameters.");
    }

    const docRef = db().collection("videos").doc(videoId).collection("comments").doc(commentId);
    const key = asChannel ? `${userId}_channel` : `${userId}_user`;

    try {
      await db().runTransaction(async (tx) => {
        const snap = await tx.get(docRef);
        if (!snap.exists) throw new HttpsError("not-found", "Comment not found.");

        const data = snap.data() || {};
        const likedBy = { ...(data.likedBy || {}) };
        const dislikedBy = { ...(data.dislikedBy || {}) };

        if (interactionType === "remove") {
          delete likedBy[`${userId}_user`];
          delete likedBy[`${userId}_channel`];
          delete dislikedBy[`${userId}_user`];
          delete dislikedBy[`${userId}_channel`];
        } else if (interactionType === "like") {
          delete dislikedBy[key];
          likedBy[key] = true;
        } else if (interactionType === "dislike") {
          delete likedBy[key];
          dislikedBy[key] = true;
        }

        const likeCount = Object.keys(likedBy).length;
        const dislikeCount = Object.keys(dislikedBy).length;

        tx.update(docRef, {
          likedBy,
          dislikedBy,
          likeCount,
          dislikeCount,
        });
      });

      return { success: true };
    } catch (err) {
      logger.error("[toggleCommentInteraction] Error:", err);
      throw new HttpsError("internal", "Failed to update interaction.");
    }
  }
);

/**
 * 👍👎 TOGGLE REPLY INTERACTION (Callable)
 */
export const toggleReplyInteraction = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { videoId, commentId, replyId, interactionType, asChannel } = request.data;
    if (!videoId || !commentId || !replyId || !interactionType) {
      throw new HttpsError("invalid-argument", "Missing parameters.");
    }

    const docRef = db()
      .collection("videos")
      .doc(videoId)
      .collection("comments")
      .doc(commentId)
      .collection("replies")
      .doc(replyId);

    const key = asChannel ? `${userId}_channel` : `${userId}_user`;

    try {
      await db().runTransaction(async (tx) => {
        const snap = await tx.get(docRef);
        if (!snap.exists) throw new HttpsError("not-found", "Reply not found.");

        const data = snap.data() || {};
        const likedBy = { ...(data.likedBy || {}) };
        const dislikedBy = { ...(data.dislikedBy || {}) };

        if (interactionType === "remove") {
          delete likedBy[`${userId}_user`];
          delete likedBy[`${userId}_channel`];
          delete dislikedBy[`${userId}_user`];
          delete dislikedBy[`${userId}_channel`];
        } else if (interactionType === "like") {
          delete dislikedBy[key];
          likedBy[key] = true;
        } else if (interactionType === "dislike") {
          delete likedBy[key];
          dislikedBy[key] = true;
        }

        const likeCount = Object.keys(likedBy).length;
        const dislikeCount = Object.keys(dislikedBy).length;

        tx.update(docRef, {
          likedBy,
          dislikedBy,
          likeCount,
          dislikeCount,
        });
      });

      return { success: true };
    } catch (err) {
      logger.error("[toggleReplyInteraction] Error:", err);
      throw new HttpsError("internal", "Failed to update reply interaction.");
    }
  }
);

/**
 * 🗑️ DELETE COMMENT NESTED (Callable)
 * Safely performs cascading deletion of all replies before removing the parent comment.
 */
export const deleteCommentNested = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { videoId, commentId } = request.data;
    if (!videoId || !commentId) {
      throw new HttpsError("invalid-argument", "Missing parameters.");
    }

    const commentRef = db().collection("videos").doc(videoId).collection("comments").doc(commentId);

    try {
      // Security check: ensure user owns the comment or video
      const snap = await commentRef.get();
      if (!snap.exists) return { success: true };

      const data = snap.data();
      // For broad robustness, allow owner or video creator to delete
      const videoSnap = await db().collection("videos").doc(videoId).get();
      const videoOwnerId = videoSnap.data()?.userId || videoSnap.data()?.ownerId;

      if (data?.userId !== userId && videoOwnerId !== userId) {
        throw new HttpsError("permission-denied", "Unauthorized to delete this comment.");
      }

      // Cascading delete replies
      const repliesSnap = await commentRef.collection("replies").get();
      const batch = db().batch();

      repliesSnap.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      batch.delete(commentRef);
      await batch.commit();

      return { success: true };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[deleteCommentNested] Error:", err);
      throw new HttpsError("internal", "Failed to delete comment.");
    }
  }
);

/**
 * 🗑️ DELETE REPLY NESTED (Callable)
 */
export const deleteReplyNested = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { videoId, commentId, replyId } = request.data;
    if (!videoId || !commentId || !replyId) {
      throw new HttpsError("invalid-argument", "Missing parameters.");
    }

    const replyRef = db()
      .collection("videos")
      .doc(videoId)
      .collection("comments")
      .doc(commentId)
      .collection("replies")
      .doc(replyId);

    try {
      const snap = await replyRef.get();
      if (!snap.exists) return { success: true };

      const data = snap.data();
      const videoSnap = await db().collection("videos").doc(videoId).get();
      const videoOwnerId = videoSnap.data()?.userId || videoSnap.data()?.ownerId;

      if (data?.userId !== userId && videoOwnerId !== userId) {
        throw new HttpsError("permission-denied", "Unauthorized to delete this reply.");
      }

      await replyRef.delete();
      return { success: true };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[deleteReplyNested] Error:", err);
      throw new HttpsError("internal", "Failed to delete reply.");
    }
  }
);

/**
 * 🚩 REPORT COMMENT NESTED (Callable)
 * Safely creates a report tracking record and increments reportCount server-side.
 */
export const reportCommentNested = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const reporterId = request.auth?.uid;
    if (!reporterId) throw new HttpsError("unauthenticated", "Auth required.");

    const {
      videoId,
      commentId,
      replyId,
      reporterName,
      reason,
      description,
    } = request.data;

    if (!videoId || !commentId || !reason) {
      throw new HttpsError("invalid-argument", "Missing required reporting parameters.");
    }

    try {
      // 1. Create tracking report document
      await db().collection("reports").add({
        commentId,
        replyId: replyId || null,
        videoId,
        reporterId,
        reporterName: reporterName || "Anonymous",
        reason,
        description: description || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isResolved: false,
      });

      // 2. Increment target document's report count securely
      const baseRef = db().collection("videos").doc(videoId).collection("comments").doc(commentId);
      const targetRef = replyId ? baseRef.collection("replies").doc(replyId) : baseRef;

      await targetRef.update({
        reportCount: admin.firestore.FieldValue.increment(1),
      });

      return { success: true };
    } catch (err) {
      logger.error("[reportCommentNested] Error:", err);
      throw new HttpsError("internal", "Failed to file report.");
    }
  }
);
