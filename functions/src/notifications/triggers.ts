import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import { notifyUser } from "./notifications";

const db = admin.firestore();

/**
 * 🔔 TRIGGER: ON NEW VIDEO
 * Notifies followers when a creator uploads a new video.
 */
export const onNewVideoFromFollowed = onDocumentCreated("videos/{videoId}", async (event) => {
  const video = event.data?.data();
  if (!video) return;

  const { channelId, title, creatorName } = video;
  const channelNameStr = creatorName || video.channelName || "Unknown Channel";

  try {
    // 1. Get all active subscribers from the core client schema
    const subscribersSnap = await db.collection("subscriptions")
      .where("channelId", "==", channelId)
      .get();

    // 2. Perform Fan-Out Feed Materialization + Alert Notification
    const batch = db.batch();
    const notifications: Promise<any>[] = [];

    subscribersSnap.docs.forEach(doc => {
      const { userId } = doc.data();
      if (!userId) return;

      // Materialize video reference into the user's explicit feed inbox subcollection
      const inboxRef = db.collection("users").doc(userId).collection("feed_inbox").doc(event.params.videoId);
      batch.set(inboxRef, {
        id: event.params.videoId,
        channelId: channelId || "",
        channelName: channelNameStr,
        channelImage: video.channelImage || "",
        title: title || "Untitled Video",
        thumbnailUrl: video.thumbnailUrl || "",
        uploadedAt: video.uploadedAt || video.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        views: video.views || 0,
        duration: video.duration || "0:00",
        category: video.category || "General",
        isSeen: false,
        materializedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      // Dispatch real-time system notification alert
      notifications.push(
        notifyUser({
          userId,
          type: "new_video_followed",
          severity: "info",
          title: `New Video from ${channelNameStr}`,
          message: `${channelNameStr} just uploaded: ${title}`,
          actionUrl: `/video/${event.params.videoId}`,
          metadata: { 
            channelId, 
            videoId: event.params.videoId,
            thumbnailUrl: video.thumbnailUrl 
          }
        })
      );
    });

    await batch.commit();
    await Promise.all(notifications);
    logger.info(`[Trigger] Fan-Out Materialized & Notified ${subscribersSnap.size} subscribers for video ${event.params.videoId}`);
  } catch (err) {
    logger.error("[Trigger] onNewVideoFromFollowed Error:", err);
  }
});

/**
 * 📈 TRIGGER: ON CHANNEL UPDATED
 * Notifies creator if their Tier, Trust Index, or Grace Status changes.
 */
export const onChannelStateChange = onDocumentUpdated("channels/{channelId}", async (event) => {
  const before = event.data?.before.data() as any;
  const after = event.data?.after.data() as any;
  if (!before || !after) return;

  const oldScore = before.reputation?.avgTrustIndex || 0;
  const newScore = after.reputation?.avgTrustIndex || 0;
  const userId = after.ownerId;

  // 1. Significant change check (e.g. > 0.5)
  if (Math.abs(newScore - oldScore) >= 0.5) {
    const direction = newScore > oldScore ? "rose" : "fell";
    await notifyUser({
      userId,
      type: "trust_score_change",
      severity: newScore > oldScore ? "success" : "warning",
      title: `Trust Index ${direction.toUpperCase()}`,
      message: `Your channel's Trust Index has ${direction} to ${newScore.toFixed(1)}.`,
      actionUrl: `/@${after.slug}`,
      metadata: { oldScore, newScore }
    });
  }

  // 2. Milestone detection (e.g. crossing 8.0 or 9.0)
  const milestones = [7.0, 8.0, 9.0];
  for (const m of milestones) {
    if (oldScore < m && newScore >= m) {
      await notifyUser({
        userId,
        type: "milestone_achieved",
        severity: "priority",
        title: "New Milestone Reached!",
        message: `Congratulations! Your channel has reached a Trust Index of ${m.toFixed(1)}. You've unlocked a new badge!`,
        actionUrl: `/@${after.slug}`,
        metadata: { milestone: m }
      });
    }
  }

  // 3. TIER CHANGE DETECTION
  const oldTier = before.tier || "basic";
  const newTier = after.tier || "basic";
  if (oldTier !== newTier) {
    const isPromotion = TIERS.indexOf(newTier) > TIERS.indexOf(oldTier);
    await notifyUser({
      userId,
      type: isPromotion ? "tier_promotion" : "tier_downgrade",
      severity: isPromotion ? "priority" : "warning",
      title: isPromotion ? "🎉 You've Been Promoted!" : "⚠️ Channel Tier Update",
      message: isPromotion 
        ? `Congratulations! Your channel has been promoted to the ${newTier.toUpperCase()} tier.`
        : `Your channel has moved to the ${newTier.toUpperCase()} tier. Maintain consistency to climb back up!`,
      actionUrl: `/@${after.slug}`,
      metadata: { oldTier, newTier }
    });
  }

  // 4. GRACE PERIOD WARNINGS
  const oldInactive = before.reputation?.inactiveMonths || 0;
  const newInactive = after.reputation?.inactiveMonths || 0;
  const oldWeak = before.reputation?.weakMonths || 0;
  const newWeak = after.reputation?.weakMonths || 0;

  if (newInactive === 1 && oldInactive === 0) {
    await notifyUser({
      userId,
      type: "inactivity_warning",
      severity: "warning",
      title: "⚠️ Inactivity Warning",
      message: "You haven't uploaded any videos this month. One more month of inactivity will result in a tier downgrade.",
      actionUrl: "/studio",
      metadata: { inactiveMonths: 1 }
    });
  }

  if (newWeak === 1 && oldWeak === 0) {
    await notifyUser({
      userId,
      type: "performance_warning",
      severity: "warning",
      title: "📉 Performance Warning",
      message: `Your performance fell below the requirements for ${newTier.toUpperCase()}. You have one month to recover before a downgrade.`,
      actionUrl: "/studio",
      metadata: { weakMonths: 1 }
    });
  }
});

const TIERS = ["basic", "creator", "advanced", "elite"];

/**
 * 🗓️ SCHEDULED: WEEKLY DIGEST
 * Every Sunday at 10:00 AM.
 */
export const weeklyDigest = onSchedule("every sunday 10:00", async (event) => {
  logger.info("[Schedule] Running Weekly Digest...");
  
  // In a real app, we would:
  // 1. Identify "Rising Stars" for the week.
  // 2. Send a summary notification to all active users.
  // 3. For now, we'll log the intention.
});

/**
 * ❤️ TRIGGER: ON COMMENT LIKED
 */
export const onCommentLiked = onDocumentUpdated("videos/{videoId}/comments/{commentId}", async (event) => {
  const before = event.data?.before.data() as any;
  const after = event.data?.after.data() as any;
  if (!before || !after) return;

  const oldLikes = before.likedBy || {};
  const newLikes = after.likedBy || {};

  // Find the new liker
  const newLikerKey = Object.keys(newLikes).find(key => !oldLikes[key]);
  if (!newLikerKey) return;

  const likerId = newLikerKey.split("_")[0];
  const commentAuthorId = after.userId;

  // Don't notify if user liked their own comment
  if (likerId === commentAuthorId) return;

  try {
    const likerSnap = await db.collection("users").doc(likerId).get();
    const likerName = likerSnap.data()?.username || "Someone";

    await notifyUser({
      userId: commentAuthorId,
      type: "comment_like",
      severity: "info",
      title: "New Like!",
      message: `${likerName} liked your comment: "${after.text.substring(0, 30)}..."`,
      actionUrl: `/video/${event.params.videoId}`,
      metadata: { 
        videoId: event.params.videoId, 
        commentId: event.params.commentId,
        likerId
      }
    });
  } catch (err) {
    logger.error("[Trigger] onCommentLiked Error:", err);
  }
});

/**
 * 💬 TRIGGER: ON REPLY CREATED
 */
export const onReplyCreated = onDocumentCreated("videos/{videoId}/comments/{commentId}/replies/{replyId}", async (event) => {
  const reply = event.data?.data();
  if (!reply) return;

  const { userId: replierId, userName: replierName, text } = reply;

  try {
    // 1. Get the parent comment to find the author
    const commentSnap = await db.collection("videos")
      .doc(event.params.videoId)
      .collection("comments")
      .doc(event.params.commentId)
      .get();

    if (!commentSnap.exists) return;
    const commentAuthorId = commentSnap.data()?.userId;

    // Don't notify if user replied to their own comment
    if (replierId === commentAuthorId) return;

    await notifyUser({
      userId: commentAuthorId,
      type: "comment_reply",
      severity: "info",
      title: "New Reply!",
      message: `${replierName} replied: "${text.substring(0, 30)}..."`,
      actionUrl: `/video/${event.params.videoId}`,
      metadata: { 
        videoId: event.params.videoId, 
        commentId: event.params.commentId,
        replyId: event.params.replyId,
        replierId
      }
    });
  } catch (err) {
    logger.error("[Trigger] onReplyCreated Error:", err);
  }
});

