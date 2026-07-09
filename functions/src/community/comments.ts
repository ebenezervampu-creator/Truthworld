import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { Comment } from "./types";
import { notifyUser } from "../notifications/notifications";

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
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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
 * Safely executes backend transaction to increment/decrement likeCount/dislikeCount using subcollections
 */
export const toggleCommentInteraction = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { videoId, commentId, interactionType, asChannel } = request.data;
    // interactionType: "like" | "dislike" | "remove"
    if (!videoId || !commentId || !interactionType) {
      throw new HttpsError("invalid-argument", "Missing parameters.");
    }

    const docRef = db().collection("videos").doc(videoId).collection("comments").doc(commentId);
    const userInteractRef = db()
      .collection("users")
      .doc(userId)
      .collection("comment_interactions")
      .doc(commentId);
    const commentInteractRef = docRef.collection("interactions").doc(userId);

    const keyUser = `${userId}_user`;
    const keyChannel = `${userId}_channel`;

    let oldType: "like" | "dislike" | null = null;
    let commentAuthorId = "";
    let commentText = "";

    try {
      await db().runTransaction(async (tx) => {
        const snap = await tx.get(docRef);
        if (!snap.exists) throw new HttpsError("not-found", "Comment not found.");

        const data = snap.data() || {};
        commentAuthorId = data.userId || "";
        commentText = data.text || "";
        const legacyLikedBy = { ...(data.likedBy || {}) };
        const legacyDislikedBy = { ...(data.dislikedBy || {}) };

        // Determine old interaction type
        let foundLegacy = false;

        if (legacyLikedBy[keyUser] || legacyLikedBy[keyChannel]) {
          oldType = "like";
          foundLegacy = true;
        } else if (legacyDislikedBy[keyUser] || legacyDislikedBy[keyChannel]) {
          oldType = "dislike";
          foundLegacy = true;
        }

        // Check subcollection
        const interactSnap = await tx.get(commentInteractRef);
        if (interactSnap.exists) {
          const interactData = interactSnap.data() || {};
          oldType = interactData.type;
          foundLegacy = false; // Subcollection overrides legacy
        }

        // Calculate count diffs
        let likeDiff = 0;
        let dislikeDiff = 0;

        if (interactionType === "remove") {
          if (oldType === "like") likeDiff = -1;
          if (oldType === "dislike") dislikeDiff = -1;
        } else if (interactionType === "like") {
          if (oldType === "dislike") {
            likeDiff = 1;
            dislikeDiff = -1;
          } else if (oldType === null) {
            likeDiff = 1;
          }
        } else if (interactionType === "dislike") {
          if (oldType === "like") {
            likeDiff = -1;
            dislikeDiff = 1;
          } else if (oldType === null) {
            dislikeDiff = 1;
          }
        }

        // Write/Delete interaction docs
        if (interactionType === "remove") {
          tx.delete(commentInteractRef);
          tx.delete(userInteractRef);
        } else {
          const interactPayload = {
            type: interactionType,
            asChannel: asChannel || false,
            videoId,
            commentId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          tx.set(commentInteractRef, interactPayload);
          tx.set(userInteractRef, interactPayload);
        }

        // Update comment document
        const updatePayload: any = {};

        // Garbage collect legacy fields if they exist to shrink document size
        if (
          foundLegacy ||
          legacyLikedBy[keyUser] !== undefined ||
          legacyLikedBy[keyChannel] !== undefined ||
          legacyDislikedBy[keyUser] !== undefined ||
          legacyDislikedBy[keyChannel] !== undefined
        ) {
          delete legacyLikedBy[keyUser];
          delete legacyLikedBy[keyChannel];
          delete legacyDislikedBy[keyUser];
          delete legacyDislikedBy[keyChannel];
          updatePayload.likedBy = legacyLikedBy;
          updatePayload.dislikedBy = legacyDislikedBy;
        }

        // Atomic increments
        updatePayload.likeCount = admin.firestore.FieldValue.increment(likeDiff);
        updatePayload.dislikeCount = admin.firestore.FieldValue.increment(dislikeDiff);

        tx.update(docRef, updatePayload);
      });

      if (interactionType === "like" && oldType !== "like" && commentAuthorId && commentAuthorId !== userId) {
        try {
          const likerSnap = await db().collection("channels").doc(userId).get();
          const likerName = likerSnap.data()?.name || "Someone";
          const truncatedText = commentText.length > 60 ? commentText.slice(0, 60) + "..." : commentText;
          await notifyUser({
            userId: commentAuthorId,
            type: "comment_like",
            severity: "info",
            title: "New Comment Like",
            message: `${likerName} liked your comment: "${truncatedText}"`,
            actionUrl: `/watch/${videoId}`,
            metadata: {
              videoId,
              commentId,
              likerId: userId,
            }
          });
        } catch (notifyErr) {
          logger.error("[toggleCommentInteraction] Failed to notify:", notifyErr);
        }
      }

      return { success: true };
    } catch (err) {
      logger.error("[toggleCommentInteraction] Error:", err);
      throw new HttpsError("internal", "Failed to update interaction.");
    }
  }
);

/**
 * 👍👎 TOGGLE REPLY INTERACTION (Callable)
 * Safely executes backend transaction to increment/decrement likeCount/dislikeCount on replies using subcollections
 */
export const toggleReplyInteraction = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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

    const userInteractRef = db()
      .collection("users")
      .doc(userId)
      .collection("reply_interactions")
      .doc(replyId);
    const replyInteractRef = docRef.collection("interactions").doc(userId);

    const keyUser = `${userId}_user`;
    const keyChannel = `${userId}_channel`;

    let oldType: "like" | "dislike" | null = null;
    let replyAuthorId = "";
    let replyText = "";

    try {
      await db().runTransaction(async (tx) => {
        const snap = await tx.get(docRef);
        if (!snap.exists) throw new HttpsError("not-found", "Reply not found.");

        const data = snap.data() || {};
        replyAuthorId = data.userId || "";
        replyText = data.text || "";
        const legacyLikedBy = { ...(data.likedBy || {}) };
        const legacyDislikedBy = { ...(data.dislikedBy || {}) };

        // Determine old interaction type
        let foundLegacy = false;

        if (legacyLikedBy[keyUser] || legacyLikedBy[keyChannel]) {
          oldType = "like";
          foundLegacy = true;
        } else if (legacyDislikedBy[keyUser] || legacyDislikedBy[keyChannel]) {
          oldType = "dislike";
          foundLegacy = true;
        }

        // Check subcollection
        const interactSnap = await tx.get(replyInteractRef);
        if (interactSnap.exists) {
          const interactData = interactSnap.data() || {};
          oldType = interactData.type;
          foundLegacy = false;
        }

        // Calculate count diffs
        let likeDiff = 0;
        let dislikeDiff = 0;

        if (interactionType === "remove") {
          if (oldType === "like") likeDiff = -1;
          if (oldType === "dislike") dislikeDiff = -1;
        } else if (interactionType === "like") {
          if (oldType === "dislike") {
            likeDiff = 1;
            dislikeDiff = -1;
          } else if (oldType === null) {
            likeDiff = 1;
          }
        } else if (interactionType === "dislike") {
          if (oldType === "like") {
            likeDiff = -1;
            dislikeDiff = 1;
          } else if (oldType === null) {
            dislikeDiff = 1;
          }
        }

        // Write/Delete interaction docs
        if (interactionType === "remove") {
          tx.delete(replyInteractRef);
          tx.delete(userInteractRef);
        } else {
          const interactPayload = {
            type: interactionType,
            asChannel: asChannel || false,
            videoId,
            commentId,
            replyId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          tx.set(replyInteractRef, interactPayload);
          tx.set(userInteractRef, interactPayload);
        }

        // Update reply document
        const updatePayload: any = {};

        // Garbage collect legacy fields if they exist to shrink document size
        if (
          foundLegacy ||
          legacyLikedBy[keyUser] !== undefined ||
          legacyLikedBy[keyChannel] !== undefined ||
          legacyDislikedBy[keyUser] !== undefined ||
          legacyDislikedBy[keyChannel] !== undefined
        ) {
          delete legacyLikedBy[keyUser];
          delete legacyLikedBy[keyChannel];
          delete legacyDislikedBy[keyUser];
          delete legacyDislikedBy[keyChannel];
          updatePayload.likedBy = legacyLikedBy;
          updatePayload.dislikedBy = legacyDislikedBy;
        }

        // Atomic increments
        updatePayload.likeCount = admin.firestore.FieldValue.increment(likeDiff);
        updatePayload.dislikeCount = admin.firestore.FieldValue.increment(dislikeDiff);

        tx.update(docRef, updatePayload);
      });

      if (interactionType === "like" && oldType !== "like" && replyAuthorId && replyAuthorId !== userId) {
        try {
          const likerSnap = await db().collection("channels").doc(userId).get();
          const likerName = likerSnap.data()?.name || "Someone";
          const truncatedText = replyText.length > 60 ? replyText.slice(0, 60) + "..." : replyText;
          await notifyUser({
            userId: replyAuthorId,
            type: "comment_like",
            severity: "info",
            title: "New Reply Like",
            message: `${likerName} liked your reply: "${truncatedText}"`,
            actionUrl: `/watch/${videoId}`,
            metadata: {
              videoId,
              commentId,
              replyId,
              likerId: userId,
            }
          });
        } catch (notifyErr) {
          logger.error("[toggleReplyInteraction] Failed to notify:", notifyErr);
        }
      }

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
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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
  { region: "asia-south1", memory: "256MiB", maxInstances: 15 },
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
