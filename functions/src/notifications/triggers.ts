import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";
import { notifyUser, sendPushNotificationForUser } from "./notifications";

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
    maxInstances: 5,
  },
  async (event) => {
  const post = event.data?.data();
  if (!post) return;

  const { channelId, title, ownerId, channelName } = post;
  const channelNameStr = channelName || "Unknown Channel";
  const postId = event.params.postId;

  try {
    // 1. INDUSTRY STANDARD TOPIC BROADCAST for Community Posts
    // Instant zero-cost push delivery to all subscribed devices
    if (channelId) {
      try {
        const sanitizedChannelId = String(channelId).trim().replace(/[^a-zA-Z0-9-_.~%]/g, "_");
        const rawImage = post.image || (Array.isArray(post.images) && post.images.length > 0 ? post.images[0] : "");
        const validThumb = (typeof rawImage === "string" && rawImage.startsWith("http") && !rawImage.includes("Icon-512") && !rawImage.includes("play_icon")) ? rawImage : "";

        await admin.messaging().send({
          topic: `channel_${sanitizedChannelId}`,
          notification: {
            title: `New Post from ${channelNameStr}`,
            body: `${channelNameStr} shared a new post: ${title || "View post"}`,
            ...(validThumb ? { imageUrl: validThumb } : {}),
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: "new_community_post",
            channelId: String(channelId),
            postId: String(postId),
            actionUrl: `/channel/${channelId}`,
            thumbnailUrl: validThumb,
            avatarUrl: post.channelImage || "",
            targetApp: "app",
          },
          android: {
            priority: "high" as const,
            notification: {
              channelId: "truthworld_notifications",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              priority: "max" as const,
              visibility: "public" as const,
              icon: "ic_notification",
              color: "#14EAB2",
              ...(validThumb ? { imageUrl: validThumb } : {}),
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                "mutable-content": 1,
              },
            },
            ...(validThumb ? { fcmOptions: { imageUrl: validThumb } } : {}),
          },
          webpush: {
            headers: {
              Urgency: "high",
            },
            notification: {
              icon: "https://www.truthworld.in/icons/Icon-192.png",
              badge: "https://www.truthworld.in/icons/Icon-192.png",
              ...(validThumb ? { image: validThumb } : {}),
            },
            fcmOptions: {
              link: `/channel/${channelId}`,
            },
          },
        });
        logger.info(`[Trigger] Dispatched broadcast topic push for community post ${postId} on channel_${sanitizedChannelId}`);
      } catch (fcmErr) {
        logger.warn(`[Trigger] FCM community post broadcast topic error (non-fatal):`, fcmErr);
      }
    }

    // 2. Direct In-App Inbox & Push Fan-Out
    // Query all subscriber storage collections to guarantee complete reach across schema versions
    const BATCH_SIZE = 500;
    const MAX_FANOUT_BATCHES = 5;
    let batchCount = 0;
    let totalNotified = 0;
    const notifiedUserIds = new Set<string>();
    if (ownerId) {
      notifiedUserIds.add(ownerId);
    }

    const processPostSubscriberBatch = async (docs: FirebaseFirestore.QueryDocumentSnapshot[]) => {
      if (docs.length === 0) return 0;
      const notifications: Promise<any>[] = [];
      let batchNotified = 0;

      docs.forEach(doc => {
        const data = doc.data();
        const userId = data.userId || doc.id;
        if (!userId || notifiedUserIds.has(userId) || userId === ownerId) return;

        notifiedUserIds.add(userId);

        const notificationsEnabled = data.notificationsEnabled !== false;
        const effectiveOption = (
          data.notificationOption ||
          data.notificationPreference ||
          (!notificationsEnabled ? "none" : "personalized")
        ).toLowerCase();

        // Mute if notifications are disabled or set to none
        if (!notificationsEnabled || effectiveOption === "none") return;

        batchNotified++;
        notifications.push(
          notifyUser({
            userId,
            type: "new_community_post",
            severity: "info",
            title: `New Post from ${channelNameStr}`,
            message: `${channelNameStr} shared a new post: ${title || "View image"}`,
            actionUrl: `/channel/${channelId}`,
            skipPush: true, // Topic broadcast channel_${sanitizedChannelId} already pushed to all subscriber devices
            metadata: { 
              channelId, 
              postId,
              thumbnailUrl: post.image || (Array.isArray(post.images) && post.images.length > 0 ? post.images[0] : ""),
              avatarUrl: post.channelImage || "",
              notificationOption: effectiveOption,
            }
          })
        );
      });

      await Promise.allSettled(notifications);
      return batchNotified;
    };

    // Source 1: Channel subscribers subcollection (Primary Source of Truth)
    let lastSubDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (batchCount < MAX_FANOUT_BATCHES) {
      let query = db.collection("channels").doc(channelId).collection("subscribers").limit(BATCH_SIZE);
      if (lastSubDoc) query = query.startAfter(lastSubDoc);
      const snap = await query.get();
      if (snap.empty) break;
      batchCount++;
      totalNotified += await processPostSubscriberBatch(snap.docs);
      lastSubDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < BATCH_SIZE) break;
    }

    // Source 2: Global subscriptions collection (Legacy & Cross-System Union)
    let lastLegacyDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (batchCount < MAX_FANOUT_BATCHES) {
      let query = db.collection("subscriptions")
        .where("channelId", "==", channelId)
        .limit(BATCH_SIZE);
      if (lastLegacyDoc) query = query.startAfter(lastLegacyDoc);
      const snap = await query.get();
      if (snap.empty) break;
      batchCount++;
      totalNotified += await processPostSubscriberBatch(snap.docs);
      lastLegacyDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < BATCH_SIZE) break;
    }

    // Source 3: channelSubscribers subcollection (Backend Functions schema fallback)
    let lastChSubDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (batchCount < MAX_FANOUT_BATCHES) {
      let query = db.collection("channels").doc(channelId).collection("channelSubscribers").limit(BATCH_SIZE);
      if (lastChSubDoc) query = query.startAfter(lastChSubDoc);
      const snap = await query.get();
      if (snap.empty) break;
      batchCount++;
      totalNotified += await processPostSubscriberBatch(snap.docs);
      lastChSubDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < BATCH_SIZE) break;
    }

    logger.info(`[Trigger] Notified ${totalNotified} subscribers for community post ${postId}`);
  } catch (err) {
    logger.error("[Trigger] onCommunityPostCreated Error:", err);
  }
});

/**
 * 🔔 TRIGGER: ON COMMUNITY POST UPDATED
 * Notifies creator when a community post is rejected by moderation or marked blocked.
 */
export const onCommunityPostUpdated = onDocumentUpdated(
  {
    document: "Community/{postId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 5,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const postId = event.params.postId;
    if (!afterData) return;

    const wasRejected =
      beforeData?.status === "rejected" ||
      beforeData?.moderation?.status === "rejected" ||
      beforeData?.isBlocked === true;
    const isRejected =
      afterData.status === "rejected" ||
      afterData.moderation?.status === "rejected" ||
      afterData.isBlocked === true;
    const becameRejected = !wasRejected && isRejected;

    if (becameRejected) {
      const uploaderId =
        afterData.ownerId || afterData.userId || afterData.uploaderId;
      if (uploaderId) {
        const reason =
          afterData.rejectionReason ||
          afterData.moderation?.reason ||
          afterData.moderation?.policyReason ||
          "Post violates Community Guidelines";
        const title =
          afterData.title && typeof afterData.title === "string" && afterData.title.trim().length > 0
            ? afterData.title.trim()
            : "Your community post";
        await notifyUser({
          userId: uploaderId,
          type: "verification_result",
          severity: "priority",
          title: "Community Post Rejected",
          message: `Your community post "${title}" was rejected: ${reason}. Please update or replace your post to comply with guidelines.`,
          actionUrl: "/community",
          metadata: {
            postId,
            reason,
            itemType: "community_post",
          },
        }).catch((err) =>
          logger.error(
            "[Trigger] onCommunityPostUpdated rejection notification error:",
            err
          )
        );
      }
    }
  }
);

/**
 * 💬 TRIGGER: ON COMMENT CREATED
 * Notifies the video owner when someone comments on their video.
 */
export const onCommentCreated = onDocumentCreated(
  {
    document: "videos/{videoId}/comments/{commentId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
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
    const videoData = videoSnap.data();
    const videoOwnerId = videoData?.ownerId || videoData?.userId || videoData?.uploaderId;

    const commentText = (text || "").toString();

    // Notify video owner (if not commenting on own video and owner ID exists)
    if (videoOwnerId && commentAuthorId !== videoOwnerId) {
      await notifyUser({
        userId: videoOwnerId,
        type: "comment",
        severity: "info",
        title: channelName ? `New Comment from ${displayName}!` : "New Comment!",
        message: `${displayName} commented: "${commentText.slice(0, 50)}..."`,
        actionUrl: `/watch?v=${event.params.videoId}&commentId=${event.params.commentId}`,
        targetApp: "all",
        metadata: { 
          videoId: event.params.videoId, 
          videoTitle: (videoData?.title || "").trim(),
          thumbnailUrl: (videoData?.thumbnailUrl || "").trim(),
          commentId: event.params.commentId,
          commentAuthorId,
          commenterName: displayName,
          avatarUrl,
          isChannel: !!channelName,
        }
      });
    }

    // 2. Scan comment text for channel mentions
    await notifyMentions({
      text: commentText,
      senderUserId: commentAuthorId || "",
      senderName: displayName,
      actionUrl: `/watch?v=${event.params.videoId}&commentId=${event.params.commentId}`,
      title: "Mentioned in a Comment!",
      message: `${displayName} mentioned you: "${commentText.slice(0, 50)}..."`,
      metadata: {
        videoId: event.params.videoId,
        videoTitle: (videoData?.title || "").trim(),
        thumbnailUrl: (videoData?.thumbnailUrl || "").trim(),
        commentId: event.params.commentId,
        commentAuthorId,
        commenterName: displayName,
        avatarUrl,
      }
    });
  } catch (err) {
    logger.error("[Trigger] onCommentCreated Error:", err);
  }
});

/**
 * 💬 TRIGGER: ON VIDEO COMMENT REPLY CREATED
 * Notifies the parent comment author when someone (or a creator/channel) replies to their comment.
 */
export const onVideoCommentReplyCreated = onDocumentCreated(
  {
    document: "videos/{videoId}/comments/{commentId}/replies/{replyId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const reply = event.data?.data();
    if (!reply) return;

    const { videoId, commentId, replyId } = event.params;
    const { userId: replyAuthorId, userName: replyAuthorName, text, userProfilePicUrl, channelName, channelProfilePicUrl, channelId } = reply;

    try {
      // 1. Fetch parent comment to identify who is being replied to
      const commentSnap = await db.collection("videos").doc(videoId).collection("comments").doc(commentId).get();
      if (!commentSnap.exists) return;

      const commentData = commentSnap.data();
      const parentAuthorId = commentData?.userId || commentData?.authorId;
      if (!parentAuthorId || parentAuthorId === replyAuthorId) return;

      // 2. Fetch video to check if replier is creator/channel
      const videoSnap = await db.collection("videos").doc(videoId).get();
      const videoData = videoSnap.exists ? videoSnap.data() : null;
      const videoOwnerId = videoData?.ownerId || videoData?.userId;
      const videoChannelId = videoData?.channelId;
      const videoChannelName = videoData?.channelName || "Creator";

      const isCreatorReply = (replyAuthorId && replyAuthorId === videoOwnerId) ||
        (channelId && videoChannelId && channelId === videoChannelId);

      const displayName = channelName || replyAuthorName || "Someone";
      const avatarUrl = channelProfilePicUrl || userProfilePicUrl || "";
      const replyText = (text || "").toString();

      const title = isCreatorReply
        ? `${videoChannelName} replied to your comment!`
        : (channelName ? `${channelName} replied to your comment` : `${displayName} replied to your comment`);

      const message = `${displayName}: "${replyText.slice(0, 60)}..."`;

      await notifyUser({
        userId: parentAuthorId,
        type: "comment_reply",
        severity: "info",
        title,
        message,
        actionUrl: `/watch?v=${videoId}&commentId=${commentId}&replyId=${replyId}`,
        targetApp: "all",
        metadata: {
          videoId,
          videoTitle: (videoData?.title || "").trim(),
          thumbnailUrl: (videoData?.thumbnailUrl || "").trim(),
          commentId,
          replyId,
          replierId: replyAuthorId,
          replierName: displayName,
          avatarUrl,
          isCreatorReply,
          isChannel: !!channelName || isCreatorReply,
        },
      });

      // 3. Scan reply for mentions
      await notifyMentions({
        text: replyText,
        senderUserId: replyAuthorId || "",
        senderName: displayName,
        actionUrl: `/watch?v=${videoId}&commentId=${commentId}&replyId=${replyId}`,
        title: "Mentioned in a Reply!",
        message: `${displayName} mentioned you: "${replyText.slice(0, 50)}..."`,
        metadata: {
          videoId,
          commentId,
          replyId,
          thumbnailUrl: (videoData?.thumbnailUrl || "").trim(),
          avatarUrl,
        },
      });
    } catch (err) {
      logger.error("[Trigger] onVideoCommentReplyCreated Error:", err);
    }
  }
);

/**
 * 📢 TRIGGER: ON COMMUNITY COMMENT CREATED
 * Notifies the community post owner when someone comments on their post.
 */
export const onCommunityCommentCreated = onDocumentCreated(
  {
    document: "Community/{postId}/comments/{commentId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;

    const { postId, commentId } = event.params;
    const { userId: commentAuthorId, userName, userImage, userProfilePicUrl, channelName, channelProfilePicUrl, text } = comment;
    const displayName = channelName || userName || "Someone";
    const avatarUrl = channelProfilePicUrl || userImage || userProfilePicUrl || "";

    try {
      const postSnap = await db.collection("Community").doc(postId).get();
      if (!postSnap.exists) return;

      const postData = postSnap.data();
      const postOwnerId = postData?.ownerId || postData?.userId || postData?.channelId;

      const commentText = (text || "").toString();

      if (postOwnerId && commentAuthorId !== postOwnerId) {
        const postTitle = (postData?.title || "community post").toString();
        const rawImage = postData?.image || (Array.isArray(postData?.images) && postData.images.length > 0 ? postData.images[0] : "");
        const validThumb = (typeof rawImage === "string" && rawImage.startsWith("http")) ? rawImage : "";

        await notifyUser({
          userId: postOwnerId,
          type: "comment",
          severity: "info",
          title: channelName ? `New Comment from ${channelName}!` : "New Comment on Your Post!",
          message: `${displayName} commented on "${postTitle.slice(0, 30)}": "${commentText.slice(0, 50)}..."`,
          actionUrl: `/post/${postId}?commentId=${commentId}`,
          targetApp: "all",
          metadata: {
            postId,
            commentId,
            commentAuthorId,
            commenterName: displayName,
            avatarUrl,
            thumbnailUrl: validThumb,
            isChannel: !!channelName,
          },
        });
      }

      // Scan mentions
      await notifyMentions({
        text: commentText,
        senderUserId: commentAuthorId || "",
        senderName: displayName,
        actionUrl: `/post/${postId}?commentId=${commentId}`,
        title: "Mentioned in a Community Post Comment!",
        message: `${displayName} mentioned you: "${commentText.slice(0, 50)}..."`,
        metadata: {
          postId,
          commentId,
          avatarUrl,
        },
      });
    } catch (err) {
      logger.error("[Trigger] onCommunityCommentCreated Error:", err);
    }
  }
);

/**
 * 📢 TRIGGER: ON COMMUNITY COMMENT REPLY CREATED
 * Notifies the comment author when someone replies to their community post comment.
 */
export const onCommunityCommentReplyCreated = onDocumentCreated(
  {
    document: "Community/{postId}/comments/{commentId}/replies/{replyId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const reply = event.data?.data();
    if (!reply) return;

    const { postId, commentId, replyId } = event.params;
    const { userId: replyAuthorId, userName: replyUserName, userImage, userProfilePicUrl, channelName, channelProfilePicUrl, channelId, text } = reply;

    try {
      const commentSnap = await db.collection("Community").doc(postId).collection("comments").doc(commentId).get();
      if (!commentSnap.exists) return;

      const commentData = commentSnap.data();
      const parentAuthorId = commentData?.userId;
      if (!parentAuthorId || parentAuthorId === replyAuthorId) return;

      const postSnap = await db.collection("Community").doc(postId).get();
      const postData = postSnap.exists ? postSnap.data() : null;
      const postOwnerId = postData?.ownerId || postData?.userId;
      const postChannelId = postData?.channelId;
      const postChannelName = postData?.channelName || "Channel";

      const isChannelReply = (replyAuthorId && replyAuthorId === postOwnerId) ||
        (channelId && postChannelId && channelId === postChannelId);

      const displayName = channelName || replyUserName || "Someone";
      const avatarUrl = channelProfilePicUrl || userImage || userProfilePicUrl || "";
      const replyText = (text || "").toString();

      const title = isChannelReply
        ? `${postChannelName} replied to your comment!`
        : (channelName ? `${channelName} replied to your comment` : `${displayName} replied to your comment`);

      const message = `${displayName}: "${replyText.slice(0, 60)}..."`;

      await notifyUser({
        userId: parentAuthorId,
        type: "comment_reply",
        severity: "info",
        title,
        message,
        actionUrl: `/post/${postId}?commentId=${commentId}&replyId=${replyId}`,
        targetApp: "all",
        metadata: {
          postId,
          commentId,
          replyId,
          replierId: replyAuthorId,
          replierName: displayName,
          avatarUrl,
          isCreatorReply: isChannelReply,
          isChannel: !!channelName || isChannelReply,
        },
      });

      // Mentions in community reply
      await notifyMentions({
        text: replyText,
        senderUserId: replyAuthorId || "",
        senderName: displayName,
        actionUrl: `/post/${postId}?commentId=${commentId}&replyId=${replyId}`,
        title: "Mentioned in a Reply!",
        message: `${displayName} mentioned you: "${replyText.slice(0, 50)}..."`,
        metadata: {
          postId,
          commentId,
          replyId,
          avatarUrl,
        },
      });
    } catch (err) {
      logger.error("[Trigger] onCommunityCommentReplyCreated Error:", err);
    }
  }
);

/**
 * 👍 TRIGGER: ON COMMUNITY COMMENT UPDATED (Comment Liked)
 * Notifies the comment author when someone or the channel likes their comment.
 */
export const onCommunityCommentUpdated = onDocumentUpdated(
  {
    document: "Community/{postId}/comments/{commentId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    if (!beforeData || !afterData) return;

    const beforeLikes: string[] = beforeData.likedBy || beforeData.likedby || [];
    const afterLikes: string[] = afterData.likedBy || afterData.likedby || [];

    const newLikers = afterLikes.filter((uid) => !beforeLikes.includes(uid));
    if (newLikers.length === 0) return;

    const { postId, commentId } = event.params;
    const commentAuthorId = afterData.userId;
    if (!commentAuthorId) return;

    try {
      const postSnap = await db.collection("Community").doc(postId).get();
      const postData = postSnap.exists ? postSnap.data() : null;
      const postOwnerId = postData?.ownerId || postData?.userId;
      const postChannelName = postData?.channelName || "Creator";

      const commentText = (afterData.text || "").toString();
      const truncated = commentText.length > 50 ? `${commentText.slice(0, 50)}...` : commentText;

      for (const likerId of newLikers) {
        if (likerId === commentAuthorId) continue;

        const isChannelLiking = likerId === postOwnerId;

        // Lookup liker info
        let likerName = "Someone";
        let likerAvatar = "";

        const channelSnap = await db.collection("channels").where("ownerId", "==", likerId).limit(1).get();
        if (!channelSnap.empty) {
          const cData = channelSnap.docs[0].data();
          likerName = cData.name || "Someone";
          likerAvatar = cData.avatarUrl || "";
        } else {
          const uSnap = await db.collection("users").doc(likerId).get();
          if (uSnap.exists) {
            const uData = uSnap.data();
            likerName = uData?.displayName || uData?.username || "Someone";
            likerAvatar = uData?.avatarUrl || uData?.photoURL || "";
          }
        }

        const title = isChannelLiking
          ? `${postChannelName} ❤️ liked your comment!`
          : `${likerName} liked your comment`;

        const message = isChannelLiking
          ? `${postChannelName} liked your comment: "${truncated}"`
          : `${likerName} liked your comment: "${truncated}"`;

        await notifyUser({
          userId: commentAuthorId,
          type: "comment_like",
          severity: "info",
          title,
          message,
          actionUrl: `/post/${postId}?commentId=${commentId}`,
          targetApp: "all",
          metadata: {
            postId,
            commentId,
            likerId,
            likerName,
            userAvatar: likerAvatar,
            isHeart: isChannelLiking,
            isCreator: isChannelLiking,
          },
        });
      }
    } catch (err) {
      logger.error("[Trigger] onCommunityCommentUpdated Error:", err);
    }
  }
);

/**
 * 👍 TRIGGER: ON COMMUNITY REPLY UPDATED (Reply Liked)
 * Notifies the reply author when someone or the channel likes their reply.
 */
export const onCommunityReplyUpdated = onDocumentUpdated(
  {
    document: "Community/{postId}/comments/{commentId}/replies/{replyId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    if (!beforeData || !afterData) return;

    const beforeLikes: string[] = beforeData.likedBy || beforeData.likedby || [];
    const afterLikes: string[] = afterData.likedBy || afterData.likedby || [];

    const newLikers = afterLikes.filter((uid) => !beforeLikes.includes(uid));
    if (newLikers.length === 0) return;

    const { postId, commentId, replyId } = event.params;
    const replyAuthorId = afterData.userId || afterData.channelId;
    if (!replyAuthorId) return;

    try {
      const postSnap = await db.collection("Community").doc(postId).get();
      const postData = postSnap.exists ? postSnap.data() : null;
      const postOwnerId = postData?.ownerId || postData?.userId;
      const postChannelName = postData?.channelName || "Creator";

      const replyText = (afterData.text || "").toString();
      const truncated = replyText.length > 50 ? `${replyText.slice(0, 50)}...` : replyText;

      for (const likerId of newLikers) {
        if (likerId === replyAuthorId) continue;

        const isChannelLiking = likerId === postOwnerId;

        let likerName = "Someone";
        let likerAvatar = "";

        const channelSnap = await db.collection("channels").where("ownerId", "==", likerId).limit(1).get();
        if (!channelSnap.empty) {
          const cData = channelSnap.docs[0].data();
          likerName = cData.name || "Someone";
          likerAvatar = cData.avatarUrl || "";
        } else {
          const uSnap = await db.collection("users").doc(likerId).get();
          if (uSnap.exists) {
            const uData = uSnap.data();
            likerName = uData?.displayName || uData?.username || "Someone";
            likerAvatar = uData?.avatarUrl || uData?.photoURL || "";
          }
        }

        const title = isChannelLiking
          ? `${postChannelName} liked your reply!`
          : `${likerName} liked your reply`;

        const message = `${likerName} liked your reply: "${truncated}"`;

        await notifyUser({
          userId: replyAuthorId,
          type: "comment_like",
          severity: "info",
          title,
          message,
          actionUrl: `/post/${postId}?commentId=${commentId}&replyId=${replyId}`,
          targetApp: "all",
          metadata: {
            postId,
            commentId,
            replyId,
            likerId,
            likerName,
            userAvatar: likerAvatar,
            isChannel: isChannelLiking,
          },
        });
      }
    } catch (err) {
      logger.error("[Trigger] onCommunityReplyUpdated Error:", err);
    }
  }
);

/**
 * 🏷️ TRIGGER: ON TOPIC REPLY CREATED
 * Notifies the comment author when someone replies to their topic comment.
 */
export const onTopicReplyCreated = onDocumentCreated(
  {
    document: "topics/{topicId}/comments/{commentId}/replies/{replyId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const reply = event.data?.data();
    if (!reply) return;

    const { topicId, commentId, replyId } = event.params;
    const { userId: replyAuthorId, userName: replyUserName, userProfilePicUrl, channelName, channelProfilePicUrl, text } = reply;

    try {
      const commentSnap = await db.collection("topics").doc(topicId).collection("comments").doc(commentId).get();
      if (!commentSnap.exists) return;

      const commentData = commentSnap.data();
      const parentAuthorId = commentData?.userId;
      if (!parentAuthorId || parentAuthorId === replyAuthorId) return;

      const topicSnap = await db.collection("topics").doc(topicId).get();
      const topicTitle = (topicSnap.data()?.title || topicSnap.data()?.name || "Topic").toString();

      const displayName = channelName || replyUserName || "Someone";
      const avatarUrl = channelProfilePicUrl || userProfilePicUrl || "";
      const replyText = (text || "").toString();

      await notifyUser({
        userId: parentAuthorId,
        type: "comment_reply",
        severity: "info",
        title: channelName ? `${channelName} replied in ${topicTitle}` : `New Reply in ${topicTitle}`,
        message: `${displayName}: "${replyText.slice(0, 60)}..."`,
        actionUrl: `/topic/${topicId}?commentId=${commentId}&replyId=${replyId}`,
        targetApp: "all",
        metadata: {
          topicId,
          commentId,
          replyId,
          replierId: replyAuthorId,
          replierName: displayName,
          avatarUrl,
        },
      });

      // Scan mentions in topic reply
      await notifyMentions({
        text: replyText,
        senderUserId: replyAuthorId || "",
        senderName: displayName,
        actionUrl: `/topic/${topicId}?commentId=${commentId}&replyId=${replyId}`,
        title: "Mentioned in a Topic Reply!",
        message: `${displayName} mentioned you: "${replyText.slice(0, 50)}..."`,
        metadata: {
          topicId,
          commentId,
          replyId,
          avatarUrl,
        },
      });
    } catch (err) {
      logger.error("[Trigger] onTopicReplyCreated Error:", err);
    }
  }
);

/**
 * 👍 TRIGGER: ON TOPIC COMMENT LIKE CREATED
 * Notifies the comment author when someone likes their topic comment.
 */
export const onTopicCommentLikeCreated = onDocumentCreated(
  {
    document: "topics/{topicId}/comments/{commentId}/likes/{userId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const { topicId, commentId, userId: likerId } = event.params;

    try {
      const commentSnap = await db.collection("topics").doc(topicId).collection("comments").doc(commentId).get();
      if (!commentSnap.exists) return;

      const commentData = commentSnap.data();
      const commentAuthorId = commentData?.userId;
      if (!commentAuthorId || commentAuthorId === likerId) return;

      const topicSnap = await db.collection("topics").doc(topicId).get();
      const topicTitle = (topicSnap.data()?.title || topicSnap.data()?.name || "Topic").toString();

      let likerName = "Someone";
      let likerAvatar = "";

      const channelSnap = await db.collection("channels").where("ownerId", "==", likerId).limit(1).get();
      if (!channelSnap.empty) {
        const cData = channelSnap.docs[0].data();
        likerName = cData.name || "Someone";
        likerAvatar = cData.avatarUrl || "";
      } else {
        const uSnap = await db.collection("users").doc(likerId).get();
        if (uSnap.exists) {
          const uData = uSnap.data();
          likerName = uData?.displayName || uData?.username || "Someone";
          likerAvatar = uData?.avatarUrl || uData?.photoURL || "";
        }
      }

      const commentText = (commentData?.text || "").toString();
      const truncated = commentText.length > 50 ? `${commentText.slice(0, 50)}...` : commentText;

      await notifyUser({
        userId: commentAuthorId,
        type: "comment_like",
        severity: "info",
        title: `Comment Liked in ${topicTitle}`,
        message: `${likerName} liked your comment: "${truncated}"`,
        actionUrl: `/topic/${topicId}?commentId=${commentId}`,
        targetApp: "all",
        metadata: {
          topicId,
          commentId,
          likerId,
          likerName,
          userAvatar: likerAvatar,
        },
      });
    } catch (err) {
      logger.error("[Trigger] onTopicCommentLikeCreated Error:", err);
    }
  }
);

/**
 * 👍 TRIGGER: ON TOPIC REPLY LIKE CREATED
 * Notifies the reply author when someone likes their topic reply.
 */
export const onTopicReplyLikeCreated = onDocumentCreated(
  {
    document: "topics/{topicId}/comments/{commentId}/replies/{replyId}/likes/{userId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const { topicId, commentId, replyId, userId: likerId } = event.params;

    try {
      const replySnap = await db.collection("topics").doc(topicId).collection("comments").doc(commentId).collection("replies").doc(replyId).get();
      if (!replySnap.exists) return;

      const replyData = replySnap.data();
      const replyAuthorId = replyData?.userId;
      if (!replyAuthorId || replyAuthorId === likerId) return;

      const topicSnap = await db.collection("topics").doc(topicId).get();
      const topicTitle = (topicSnap.data()?.title || topicSnap.data()?.name || "Topic").toString();

      let likerName = "Someone";
      let likerAvatar = "";

      const channelSnap = await db.collection("channels").where("ownerId", "==", likerId).limit(1).get();
      if (!channelSnap.empty) {
        const cData = channelSnap.docs[0].data();
        likerName = cData.name || "Someone";
        likerAvatar = cData.avatarUrl || "";
      } else {
        const uSnap = await db.collection("users").doc(likerId).get();
        if (uSnap.exists) {
          const uData = uSnap.data();
          likerName = uData?.displayName || uData?.username || "Someone";
          likerAvatar = uData?.avatarUrl || uData?.photoURL || "";
        }
      }

      const replyText = (replyData?.text || "").toString();
      const truncated = replyText.length > 50 ? `${replyText.slice(0, 50)}...` : replyText;

      await notifyUser({
        userId: replyAuthorId,
        type: "comment_like",
        severity: "info",
        title: `Reply Liked in ${topicTitle}`,
        message: `${likerName} liked your reply: "${truncated}"`,
        actionUrl: `/topic/${topicId}?commentId=${commentId}&replyId=${replyId}`,
        targetApp: "all",
        metadata: {
          topicId,
          commentId,
          replyId,
          likerId,
          likerName,
          userAvatar: likerAvatar,
        },
      });
    } catch (err) {
      logger.error("[Trigger] onTopicReplyLikeCreated Error:", err);
    }
  }
);

/**
 * 🏛️ TRIGGER: ON CLAIM COMMENT CREATED (Community Notes on Claims)
 * Notifies the video creator when a user adds an evidence-backed deliberation note on their video claim.
 */
export const onClaimCommentCreated = onDocumentCreated(
  {
    document: "videos/{videoId}/claim_comments/{commentId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;

    const { videoId, commentId } = event.params;
    const { userId: noteAuthorId, userName: noteAuthorName, channelName, text, stance, claimText, claimIndex } = comment;

    try {
      const videoSnap = await db.collection("videos").doc(videoId).get();
      if (!videoSnap.exists) return;

      const videoData = videoSnap.data();
      const videoOwnerId = videoData?.ownerId || videoData?.userId;
      if (!videoOwnerId || noteAuthorId === videoOwnerId) return;

      const displayName = channelName || noteAuthorName || "TruthWorld Member";
      const resolvedStance = (stance || "supports").toUpperCase();
      const snippet = (claimText || text || "").toString();
      const truncatedClaim = snippet.length > 50 ? `${snippet.slice(0, 50)}...` : snippet;

      await notifyUser({
        userId: videoOwnerId,
        type: "comment",
        severity: "info",
        title: channelName ? `New Evidence Note from ${channelName}` : "New Claim Deliberation Note",
        message: `${displayName} added a community note [${resolvedStance}] on claim #${(claimIndex ?? 0) + 1}: "${truncatedClaim}"`,
        actionUrl: `/watch?v=${videoId}&claimIndex=${claimIndex ?? 0}`,
        targetApp: "all",
        metadata: {
          videoId,
          videoTitle: (videoData?.title || "").trim(),
          thumbnailUrl: (videoData?.thumbnailUrl || "").trim(),
          claimIndex: claimIndex ?? 0,
          commentId,
          authorId: noteAuthorId,
          authorName: displayName,
          stance: resolvedStance,
        },
      });

      // Mentions in claim deliberation note
      await notifyMentions({
        text: (text || "").toString(),
        senderUserId: noteAuthorId || "",
        senderName: displayName,
        actionUrl: `/watch?v=${videoId}&claimIndex=${claimIndex ?? 0}`,
        title: "Mentioned in a Claim Note!",
        message: `${displayName} mentioned you in an evidence deliberation note: "${(text || "").toString().slice(0, 50)}..."`,
        metadata: {
          videoId,
          claimIndex: claimIndex ?? 0,
          commentId,
        },
      });
    } catch (err) {
      logger.error("[Trigger] onClaimCommentCreated Error:", err);
    }
  }
);

/**
 * ⚡ TRIGGER: ON CLAIM COMMENT UPDATED (Deliberation Note Found Helpful / Truth Credibility Boost)
 * Notifies the deliberation note author when their note receives a helpful vote from a user or channel.
 */
export const onClaimCommentUpdated = onDocumentUpdated(
  {
    document: "videos/{videoId}/claim_comments/{commentId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 15,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    if (!beforeData || !afterData) return;

    const beforeHelpful: string[] = beforeData.helpfulUserIds || [];
    const afterHelpful: string[] = afterData.helpfulUserIds || [];

    const newVoters = afterHelpful.filter((uid) => !beforeHelpful.includes(uid));
    if (newVoters.length === 0) return;

    const { videoId, commentId } = event.params;
    const noteAuthorId = afterData.userId;
    if (!noteAuthorId) return;

    try {
      const videoSnap = await db.collection("videos").doc(videoId).get();
      const videoData = videoSnap.exists ? videoSnap.data() : null;
      const videoOwnerId = videoData?.ownerId || videoData?.userId;
      const videoChannelName = videoData?.channelName || "Creator";

      const claimText = (afterData.claimText || "").toString();
      const truncatedClaim = claimText.length > 50 ? `${claimText.slice(0, 50)}...` : claimText;
      const claimIndex = afterData.claimIndex ?? 0;

      for (const voterId of newVoters) {
        if (voterId === noteAuthorId) continue;

        const isCreatorVote = voterId === videoOwnerId;

        let voterName = "Someone";
        let voterAvatar = "";

        const channelSnap = await db.collection("channels").where("ownerId", "==", voterId).limit(1).get();
        if (!channelSnap.empty) {
          const cData = channelSnap.docs[0].data();
          voterName = cData.name || "Someone";
          voterAvatar = cData.avatarUrl || "";
        } else {
          const uSnap = await db.collection("users").doc(voterId).get();
          if (uSnap.exists) {
            const uData = uSnap.data();
            voterName = uData?.displayName || uData?.username || "Someone";
            voterAvatar = uData?.avatarUrl || uData?.photoURL || "";
          }
        }

        const title = isCreatorVote
          ? `${videoChannelName} verified your note as helpful!`
          : "Truth Intelligence: Note Found Helpful (+Credibility)";

        const message = isCreatorVote
          ? `${videoChannelName} marked your evidence note helpful on claim #${claimIndex + 1}: "${truncatedClaim}"`
          : `${voterName} found your community note helpful on claim #${claimIndex + 1}: "${truncatedClaim}"`;

        await notifyUser({
          userId: noteAuthorId,
          type: "comment_like",
          severity: "info",
          title,
          message,
          actionUrl: `/watch?v=${videoId}&claimIndex=${claimIndex}`,
          targetApp: "all",
          metadata: {
            videoId,
            claimIndex,
            commentId,
            voterId,
            voterName,
            userAvatar: voterAvatar,
            isCreator: isCreatorVote,
          },
        });
      }
    } catch (err) {
      logger.error("[Trigger] onClaimCommentUpdated Error:", err);
    }
  }
);

/**
 * 🤝 TRIGGER: ON NEW SUBSCRIPTION (Channel Got Liked/Followed)
 * Notifies the channel owner when someone subscribes to their channel.
 */
export const onNewSubscription = onDocumentCreated(
  {
    document: "subscriptions/{subscriptionId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 10,
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
      actionUrl: `/studio`,
      metadata: { 
        channelId, 
        subscriberId,
        avatarUrl,
        notificationOption: subscription.notificationOption || subscription.notificationPreference || "personalized",
      }
    });
  } catch (err) {
    logger.error("[Trigger] onNewSubscription Error:", err);
  }
});

/**
 * 🤝 TRIGGER: ON CHANNEL SUBSCRIBER WRITTEN
 * Automatically synchronizes subscriberCount and subscribers on the parent channel document
 * whenever a user subscribes or unsubscribes, guaranteeing cross-version consistency.
 */
export const onChannelSubscriberWritten = onDocumentWritten(
  {
    document: "channels/{channelId}/subscribers/{userId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 20,
  },
  async (event) => {
    const channelId = event.params.channelId;
    if (!channelId) return;

    const beforeExists = event.data?.before.exists ?? false;
    const afterExists = event.data?.after.exists ?? false;

    // No change in existence (e.g. metadata preference updates)
    if (beforeExists === afterExists) return;

    const channelRef = db.collection("channels").doc(channelId);

    try {
      // Query authentic subscriber count from the subcollection
      const subSnap = await db
        .collection("channels")
        .doc(channelId)
        .collection("subscribers")
        .count()
        .get();
      const authenticSubscribers = subSnap.data().count;

      await channelRef.set(
        {
          subscriberCount: authenticSubscribers,
          subscribers: authenticSubscribers,
          "stats.subscribersCount": authenticSubscribers,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      logger.info(
        `[Trigger] onChannelSubscriberWritten: Reconciled channel ${channelId} subscriberCount to ${authenticSubscribers}.`
      );
    } catch (err) {
      logger.error(
        `[Trigger] onChannelSubscriberWritten Error for channel ${channelId}:`,
        err
      );
    }
  }
);

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
    
    // Parallelize handle lookups to prevent sequential I/O delays
    await Promise.allSettled(
      rawHandles.map(async (handle) => {
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
          if (!targetUserId || targetUserId === params.senderUserId) {
            return;
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
      })
    );
  } catch (err) {
    logger.error("[notifyMentions] Error:", err);
  }
}

/**
 * 🔔 TRIGGER: ON USER NOTIFICATION CREATED (Universal Safety Net)
 * Ensures every single notification written to user_notifications (including direct
 * client-side writes, triggers, and external calls) receives a push notification on all user devices.
 */
export const onUserNotificationCreated = onDocumentCreated(
  {
    document: "user_notifications/{notificationId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 20,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    // Skip if already sent directly by notifyUser
    if (data.pushSent === true) return;

    const { userId, type, severity, title, message, actionUrl, metadata, targetApp } = data;
    if (!userId || userId === "guest_user" || !title) return;

    try {
      await sendPushNotificationForUser(
        {
          userId,
          type: type || "info",
          severity: severity || "info",
          title: title || "Notification",
          message: message || "",
          actionUrl: actionUrl || "",
          metadata: metadata || undefined,
          targetApp: targetApp || undefined,
        },
        event.params.notificationId
      );

      // Flag as push sent to prevent double delivery
      await event.data?.ref.update({ pushSent: true });
    } catch (err) {
      logger.error("[onUserNotificationCreated] Error sending push notification:", err);
    }
  }
);
