import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { notifyUser } from "./notifications";

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════════
// NOTE: onNewVideoFromFollowed has been MERGED into onVideoPublished in index.ts
// to eliminate a duplicate Firestore trigger on videos/{videoId} that was 
// doubling invocation costs on every video document update.
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 🔔 TRIGGER: ON NEW COMMUNITY POST
 * Notifies subscribers when a creator uploads a new community post.
 *
 * COST-OPTIMIZED: Paginated fan-out in batches of 500.
 */
export const onCommunityPostCreated = onDocumentCreated(
  {
    document: "Community/{postId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 2,
  },
  async (event) => {
  const post = event.data?.data();
  if (!post) return;

  const { channelId, title, ownerId, channelName } = post;
  const channelNameStr = channelName || "Unknown Channel";
  const postId = event.params.postId;

  try {
    // Paginated subscriber fan-out (500 per batch)
    const BATCH_SIZE = 500;
    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    let totalNotified = 0;

    while (true) {
      let query = db.collection("subscriptions")
        .where("channelId", "==", channelId)
        .limit(BATCH_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const subscribersSnap = await query.get();
      if (subscribersSnap.empty) break;

      const notifications: Promise<any>[] = [];

      subscribersSnap.docs.forEach(doc => {
        const { userId, notificationsEnabled } = doc.data();
        if (!userId) return;

        // Mute if notifications are disabled
        if (notificationsEnabled === false) return;

        // Don't notify the creator of their own post
        if (userId === ownerId) return;

        notifications.push(
          notifyUser({
            userId,
            type: "new_community_post",
            severity: "info",
            title: `New Post from ${channelNameStr}`,
            message: `${channelNameStr} shared a new post: ${title || "View image"}`,
            actionUrl: `/channel/${channelId}`,
            metadata: { 
              channelId, 
              postId,
              thumbnailUrl: post.image || "",
              avatarUrl: post.channelImage || ""
            }
          })
        );
      });

      await Promise.allSettled(notifications);
      totalNotified += subscribersSnap.size;

      lastDoc = subscribersSnap.docs[subscribersSnap.docs.length - 1];
      if (subscribersSnap.size < BATCH_SIZE) break;
    }

    logger.info(`[Trigger] Notified ${totalNotified} subscribers for community post ${postId}`);
  } catch (err) {
    logger.error("[Trigger] onCommunityPostCreated Error:", err);
  }
});

/**
 * 💬 TRIGGER: ON COMMENT CREATED
 * Notifies the video owner when someone comments on their video.
 */
export const onCommentCreated = onDocumentCreated(
  {
    document: "videos/{videoId}/comments/{commentId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 2,
  },
  async (event) => {
  const comment = event.data?.data();
  if (!comment) return;

  const { userId: commentAuthorId, userName: commentAuthorName, text, userProfilePicUrl, channelName, channelProfilePicUrl } = comment;
  const displayName = channelName || commentAuthorName || "Someone";
  const avatarUrl = channelProfilePicUrl || userProfilePicUrl || "";

  try {
    // 1. Get the video to find the owner/creator
    const videoSnap = await db.collection("videos").doc(event.params.videoId).get();
    if (!videoSnap.exists) return;
    const videoOwnerId = videoSnap.data()?.ownerId;

    // Notify video owner (if not commenting on own video)
    if (commentAuthorId !== videoOwnerId) {
      await notifyUser({
        userId: videoOwnerId,
        type: "comment",
        severity: "info",
        title: "New Comment!",
        message: `${displayName} commented: "${text.substring(0, 30)}..."`,
        actionUrl: `/video/${event.params.videoId}`,
        metadata: { 
          videoId: event.params.videoId, 
          commentId: event.params.commentId,
          commentAuthorId,
          avatarUrl,
        }
      });
    }

    // 2. Scan comment text for channel mentions
    await notifyMentions({
      text: text || "",
      senderUserId: commentAuthorId || "",
      senderName: displayName,
      actionUrl: `/video/${event.params.videoId}`,
      title: "Mentioned in a Comment!",
      message: `${displayName} mentioned you: "${text.substring(0, 30)}..."`,
      metadata: {
        videoId: event.params.videoId,
        commentId: event.params.commentId,
        commentAuthorId,
        avatarUrl,
      }
    });
  } catch (err) {
    logger.error("[Trigger] onCommentCreated Error:", err);
  }
});

/**
 * 🤝 TRIGGER: ON NEW SUBSCRIPTION (Channel Got Liked/Followed)
 * Notifies the channel owner when someone subscribes to their channel.
 */
export const onNewSubscription = onDocumentCreated(
  {
    document: "subscriptions/{subscriptionId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 2,
  },
  async (event) => {
  const subscription = event.data?.data();
  if (!subscription) return;

  const { userId: subscriberId, channelId } = subscription;
  if (!subscriberId || !channelId) return;

  try {
    // 1. Get channel ownerId
    const channelSnap = await db.collection("channels").doc(channelId).get();
    if (!channelSnap.exists) return;
    const channelOwnerId = channelSnap.data()?.ownerId;

    // Don't notify if subscribing to own channel
    if (subscriberId === channelOwnerId) return;

    // 2. Get subscriber name and avatar
    const subscriberSnap = await db.collection("users").doc(subscriberId).get();
    const subscriberData = subscriberSnap.data();
    const subscriberName = subscriberData?.username || "Someone";
    const avatarUrl = subscriberData?.avatarUrl || subscriberData?.photoURL || "";

    await notifyUser({
      userId: channelOwnerId,
      type: "new_follower",
      severity: "info",
      title: "New Subscriber!",
      message: `${subscriberName} subscribed to your channel.`,
      actionUrl: `/channel/${channelId}`,
      metadata: { 
        channelId, 
        subscriberId,
        avatarUrl
      }
    });
  } catch (err) {
    logger.error("[Trigger] onNewSubscription Error:", err);
  }
});

/**
 * 📣 HELPER: NOTIFY CHANNEL MENTIONS
 * Parses `@channelhandle` in text and dispatches info notifications of type "mention" to matching channel owners.
 * Capped at 5 mentions per invocation to prevent abuse.
 * 
 * Exported for use by the merged onVideoPublished trigger in index.ts.
 */
export async function notifyMentions(params: {
  text: string;
  senderUserId: string;
  senderName: string;
  actionUrl: string;
  title: string;
  message: string;
  metadata?: Record<string, any>;
}) {
  try {
    if (!params.text) return;
    
    // Regex matches '@' followed by word characters, hyphens and underscores
    const matches = params.text.match(/@[\w\-]+/g) || [];
    if (matches.length === 0) return;

    // Get unique raw handles in lowercase, stripping the '@' prefix
    // Cap at 5 to prevent abuse via text with 100+ @mentions
    const rawHandles = [...new Set(matches.map(m => m.substring(1).toLowerCase()))].slice(0, 5);
    
    for (const handle of rawHandles) {
      // Find channels where handle or handleLowercase matches either 'handle' or '@handle'
      const searchHandles = [handle, `@${handle}`];
      
      const channelSnap = await db.collection("channels")
        .where("handleLowercase", "in", searchHandles)
        .limit(1)
        .get();
        
      if (!channelSnap.empty) {
        const channelDoc = channelSnap.docs[0];
        const channelData = channelDoc.data();
        const targetUserId = channelData.ownerId;
        
        // Don't notify if the user mentioned their own channel
        if (targetUserId === params.senderUserId) {
          continue;
        }

        await notifyUser({
          userId: targetUserId,
          type: "mention",
          severity: "info",
          title: params.title,
          message: params.message,
          actionUrl: params.actionUrl,
          metadata: {
            ...params.metadata,
            mentionedChannelId: channelDoc.id,
            avatarUrl: params.metadata?.avatarUrl || channelData.avatarUrl || "",
          }
        });
      }
    }
  } catch (err) {
    logger.error("[notifyMentions] Error:", err);
  }
}
