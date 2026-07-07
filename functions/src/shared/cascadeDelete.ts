import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import { onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Deletes documents returned by a query in batches of 400.
 * Using pagination to avoid hitting the 500-operation Firestore transaction limit.
 */
async function deleteQueryBatch(query: admin.firestore.Query): Promise<void> {
  const limit = 400;
  let hasMore = true;
  while (hasMore) {
    const snap = await query.limit(limit).get();
    if (snap.empty) {
      hasMore = false;
      break;
    }
    const batch = admin.firestore().batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    if (snap.size < limit) {
      hasMore = false;
    }
  }
}

/**
 * Extracts the storage file path from a Firebase Storage public download URL.
 */
function getStoragePathFromUrl(url: string): string | null {
  try {
    if (!url || !url.includes("firebasestorage.googleapis.com")) return null;
    const decoded = decodeURIComponent(url.split("/o/")[1].split("?")[0]);
    return decoded;
  } catch (e) {
    return null;
  }
}

/**
 * Deletes a single file from Firebase Storage.
 */
async function deleteStorageFile(filePath: string): Promise<void> {
  try {
    const bucket = admin.storage().bucket();
    const file = bucket.file(filePath);
    const [exists] = await file.exists();
    if (exists) {
      await file.delete();
      console.log(`[Storage] Deleted file: ${filePath}`);
    }
  } catch (error) {
    console.error(`[Storage] Failed to delete file ${filePath}:`, error);
  }
}

/**
 * Deletes all files in a folder/prefix in Firebase Storage.
 */
async function deleteStorageFolder(prefix: string): Promise<void> {
  try {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix });
    if (files.length === 0) return;
    
    console.log(`[Storage] Deleting ${files.length} files under prefix: ${prefix}`);
    // Process file deletions in small parallel chunks to avoid rate limiting
    const chunkSize = 10;
    for (let i = 0; i < files.length; i += chunkSize) {
      const chunk = files.slice(i, i + chunkSize);
      await Promise.all(
        chunk.map(file => file.delete().catch(err => console.error(`[Storage] Error deleting ${file.name}:`, err)))
      );
    }
  } catch (error) {
    console.error(`[Storage] Failed to delete folder prefix ${prefix}:`, error);
  }
}

// ─── User Deletion Cascade ───────────────────────────────────────────────────

/**
 * Cascade deletes everything owned by or associated with a user ID.
 */
export async function cascadeDeleteUser(userId: string): Promise<void> {
  console.log(`[UserCascade] Starting cleanup for user: ${userId}`);
  const db = admin.firestore();

  // 1. Delete user subcollections
  const subcollections = [
    "saved_playlists", "clips", "likedVideos", "feed_inbox", 
    "savedTopics", "likedTopics", "liked_topic_comments", 
    "liked_topic_replies", "watch_history"
  ];
  for (const sub of subcollections) {
    await deleteQueryBatch(db.collection("users").doc(userId).collection(sub));
  }

  // 2. Delete user notifications
  await deleteQueryBatch(db.collection("user_notifications").where("userId", "==", userId));
  await deleteQueryBatch(db.collection("notifications").where("userId", "==", userId));

  // 3. Delete subscriptions (where user is subscriber)
  await deleteQueryBatch(db.collection("subscriptions").where("userId", "==", userId));

  // 4. Delete comments (flat)
  await deleteQueryBatch(db.collection("comments").where("userId", "==", userId));

  // 5. Delete likes/dislikes (flat)
  await deleteQueryBatch(db.collection("likes").where("userId", "==", userId));

  // 6. Delete feedback & reports
  await deleteQueryBatch(db.collection("feedback").where("userId", "==", userId));
  await deleteQueryBatch(db.collection("reports").where("userId", "==", userId));
  await deleteQueryBatch(db.collection("reports").where("reporterId", "==", userId));

  // 7. Delete playlists owned by user
  await deleteQueryBatch(db.collection("saved_playlists").where("ownerId", "==", userId));
  await deleteQueryBatch(db.collection("playlists").where("ownerId", "==", userId));

  // 8. Delete community posts owned by user
  await deleteQueryBatch(db.collection("Community").where("ownerId", "==", userId));

  // 9. Delete legacy watch_history & signals
  await deleteQueryBatch(db.collection("watch_history").where("userId", "==", userId));
  await deleteQueryBatch(db.collection("impressions_raw").where("userId", "==", userId));
  await deleteQueryBatch(db.collection("copyrights").where("userId", "==", userId));
  await deleteQueryBatch(db.collection("copyrights").where("ownerId", "==", userId));
  await deleteQueryBatch(db.collection("content_verifications").where("userId", "==", userId));
  await deleteQueryBatch(db.collection("content_verifications").where("ownerId", "==", userId));

  // 10. Find and delete channels owned by the user (which triggers channel deletion triggers)
  const channelsSnap = await db.collection("channels").where("ownerId", "==", userId).get();
  for (const channelDoc of channelsSnap.docs) {
    await channelDoc.ref.delete().catch(err => console.error(`[UserCascade] Error deleting channel doc:`, err));
  }

  // 11. Find and delete videos uploaded/owned by the user (which triggers video deletion triggers)
  const videosSnap = await db.collection("videos").where("ownerId", "==", userId).get();
  for (const videoDoc of videosSnap.docs) {
    await videoDoc.ref.delete().catch(err => console.error(`[UserCascade] Error deleting video doc:`, err));
  }

  // 12. Find and delete topics created by the user (which triggers topic deletion triggers)
  const topicsSnap = await db.collection("topics").where("creatorId", "==", userId).get();
  for (const topicDoc of topicsSnap.docs) {
    await topicDoc.ref.delete().catch(err => console.error(`[UserCascade] Error deleting topic doc:`, err));
  }

  // 13. Delete Storage assets for the user
  await deleteStorageFolder(`channel_avatars/${userId}`);
  await deleteStorageFolder(`channel_banners/${userId}`);
  await deleteStorageFolder(`community_images/${userId}`);
  await deleteStorageFolder(`thumbnails/${userId}`);

  // 14. Finally, delete the user doc itself (if still exists)
  await db.collection("users").doc(userId).delete().catch(() => {});
  console.log(`[UserCascade] Finished cleanup for user: ${userId}`);
}

/**
 * ⚡ TRIGGER: ON USER AUTH DELETED
 * Automatically runs when a Firebase Authentication user account is deleted.
 */
export const onUserDeleted = functions.region("asia-south1").auth.user().onDelete(async (user: admin.auth.UserRecord) => {
  await cascadeDeleteUser(user.uid);
});

/**
 * ⚡ TRIGGER: ON USER DOCUMENT DELETED
 * Automatically runs when a user document is physically deleted in Firestore.
 */
export const onUserDocDeleted = onDocumentDeleted(
  {
    document: "users/{userId}",
    region: "asia-south1",
    memory: "256MiB",
  },
  async (event) => {
    const userId = event.params.userId;
    await cascadeDeleteUser(userId);
  }
);

// ─── Channel Deletion Cascade ────────────────────────────────────────────────

/**
 * ⚡ TRIGGER: ON CHANNEL DOCUMENT DELETED
 * Automatically runs when a channel document is physically deleted in Firestore.
 */
export const onChannelDeleted = onDocumentDeleted(
  {
    document: "channels/{channelId}",
    region: "asia-south1",
    memory: "256MiB",
  },
  async (event) => {
    const channelId = event.params.channelId;
    const data = event.data?.data();
    if (!data) return;

    const ownerId = data.ownerId;
    const handle = data.handle;
    const avatarUrl = data.profile?.photoUrl || data.avatarUrl;
    const bannerUrl = data.profile?.coverUrl || data.bannerUrl;

    console.log(`[ChannelCascade] Starting cleanup for channel: ${channelId}`);
    const db = admin.firestore();

    // 1. Delete subcollections of the channel
    const subcollections = ["subscribers", "videos", "reports", "stats", "daily_stats"];
    for (const sub of subcollections) {
      await deleteQueryBatch(db.collection("channels").doc(channelId).collection(sub));
    }

    // 2. Delete from channel_slugs
    if (handle) {
      const normalizedSlug = handle.toLowerCase().startsWith("@") ? handle.toLowerCase() : `@${handle.toLowerCase()}`;
      await db.collection("channel_slugs").doc(normalizedSlug).delete().catch(() => {});
    }

    // 3. Delete subscriptions to this channel
    await deleteQueryBatch(db.collection("subscriptions").where("channelId", "==", channelId));
    await deleteQueryBatch(db.collection("subscription_events_raw").where("channelId", "==", channelId));

    // 4. Delete daily/hourly channel stats
    await deleteQueryBatch(db.collection("channel_stats_daily").where("channelId", "==", channelId));

    // 5. Delete topics associated with this channel (triggering onTopicDeleted)
    const topicsSnap = await db.collection("topics").where("channelId", "==", channelId).get();
    for (const topicDoc of topicsSnap.docs) {
      await topicDoc.ref.delete().catch(err => console.error(`[ChannelCascade] Error deleting topic:`, err));
    }

    // 6. Delete all videos belonging to the channel (triggering onVideoDeleted)
    const videosSnap = await db.collection("videos").where("channelId", "==", channelId).get();
    for (const videoDoc of videosSnap.docs) {
      await videoDoc.ref.delete().catch(err => console.error(`[ChannelCascade] Error deleting video:`, err));
    }

    // 7. Delete all community posts belonging to the channel (triggering onCommunityPostDeleted)
    const communitySnap = await db.collection("Community").where("channelId", "==", channelId).get();
    for (const doc of communitySnap.docs) {
      await doc.ref.delete().catch(err => console.error(`[ChannelCascade] Error deleting community post:`, err));
    }

    // 8. Delete all public and private playlists belonging to the channel
    await deleteQueryBatch(db.collection("playlists").where("channelId", "==", channelId));
    await deleteQueryBatch(db.collectionGroup("saved_playlists").where("channelId", "==", channelId));

    // 9. Decrement channelsCount on owner's user document
    if (ownerId) {
      await db.collection("users").doc(ownerId).update({
        channelsCount: admin.firestore.FieldValue.increment(-1)
      }).catch(err => console.error("[ChannelCascade] Error decrementing channelsCount:", err));
    }

    // 10. Delete specific storage files (avatar/banner)
    if (avatarUrl) {
      const avatarPath = getStoragePathFromUrl(avatarUrl);
      if (avatarPath) await deleteStorageFile(avatarPath);
    }
    if (bannerUrl) {
      const bannerPath = getStoragePathFromUrl(bannerUrl);
      if (bannerPath) await deleteStorageFile(bannerPath);
    }

    console.log(`[ChannelCascade] Finished cleanup for channel: ${channelId}`);
  }
);

/**
 * ⚡ TRIGGER: ON CHANNEL UPDATED (Soft Deletion check)
 * Automatically runs when a channel document is updated.
 * If status changes to 'deleted', we trigger actual document deletion to cascade.
 */
export const onChannelUpdated = onDocumentUpdated(
  {
    document: "channels/{channelId}",
    region: "asia-south1",
    memory: "256MiB",
  },
  async (event) => {
    const dataBefore = event.data?.before.data();
    const dataAfter = event.data?.after.data();
    if (!dataBefore || !dataAfter) return;

    if (dataBefore.status !== "deleted" && dataAfter.status === "deleted") {
      const channelId = event.params.channelId;
      console.log(`[ChannelCascade] Status changed to 'deleted' for ${channelId}. Executing document delete.`);
      await event.data?.after.ref.delete().catch(err => console.error("[ChannelCascade] Error deleting channel doc during soft-delete trigger:", err));
    }
  }
);

// ─── Video Deletion Cascade ──────────────────────────────────────────────────

/**
 * ⚡ TRIGGER: ON VIDEO DOCUMENT DELETED
 * Automatically runs when a video document is physically deleted in Firestore.
 */
export const onVideoDeleted = onDocumentDeleted(
  {
    document: "videos/{videoId}",
    region: "asia-south1",
    memory: "256MiB",
  },
  async (event) => {
    const videoId = event.params.videoId;
    const data = event.data?.data();
    if (!data) return;

    const channelId = data.channelId;
    const jobId = data.jobId;
    const videoUrl = data.videoUrl;
    const thumbnailUrl = data.thumbnailUrl;

    console.log(`[VideoCascade] Starting cleanup for video: ${videoId}`);
    const db = admin.firestore();

    // 1. Delete subcollections of the video
    const subcollections = ["views", "likes", "dislikes", "reports", "transcripts", "dailyStats"];
    for (const sub of subcollections) {
      await deleteQueryBatch(db.collection("videos").doc(videoId).collection(sub));
    }

    // 2. Delete nested comments and replies subcollections
    const commentsRef = db.collection("videos").doc(videoId).collection("comments");
    const commentsSnap = await commentsRef.get();
    for (const commentDoc of commentsSnap.docs) {
      await deleteQueryBatch(commentDoc.ref.collection("replies"));
      await deleteQueryBatch(commentDoc.ref.collection("likes"));
      await deleteQueryBatch(commentDoc.ref.collection("dislikes"));
      await commentDoc.ref.delete().catch(() => {});
    }

    // 3. Delete flat comments
    await deleteQueryBatch(db.collection("comments").where("videoId", "==", videoId));

    // 4. Delete reports
    await deleteQueryBatch(db.collection("reports").where("videoId", "==", videoId));

    // 5. Delete copyrights and content verifications
    await deleteQueryBatch(db.collection("copyrights").where("videoId", "==", videoId));
    await deleteQueryBatch(db.collection("content_verifications").where("videoId", "==", videoId));

    // 6. Delete stats / state documents
    await db.collection("video_stats").doc(videoId).delete().catch(() => {});
    const stateStatsRef = db.collection("video_state_stats").doc(videoId);
    await deleteQueryBatch(stateStatsRef.collection("states"));
    await stateStatsRef.delete().catch(() => {});

    // 7. Delete daily/hourly stats
    await deleteQueryBatch(db.collection("video_stats_daily").where("videoId", "==", videoId));
    await deleteQueryBatch(db.collection("video_stats_hourly").where("videoId", "==", videoId));

    // 8. Delete qualified views (docs matching pattern: videoId_*)
    const qualifiedViewsSnap = await db.collection("qualified_views").get();
    const qViewsToDelete = qualifiedViewsSnap.docs.filter(doc => doc.id.startsWith(`${videoId}_`));
    const qBatchSize = 400;
    for (let i = 0; i < qViewsToDelete.length; i += qBatchSize) {
      const batch = db.batch();
      qViewsToDelete.slice(i, i + qBatchSize).forEach(doc => batch.delete(doc.ref));
      await batch.commit();
    }

    // 9. Delete view dedup
    const viewDedupRef = db.collection("viewDedup").doc(videoId);
    await deleteQueryBatch(viewDedupRef.collection("ips"));
    await viewDedupRef.delete().catch(() => {});

    // 10. Delete associated video_jobs (main + sharded)
    let finalJobId = jobId;
    if (finalJobId) {
      const jobDoc = await db.collection("video_jobs").doc(finalJobId).get();
      if (jobDoc.exists) {
        const jobData = jobDoc.data();
        const shard = jobData?.shard;
        await jobDoc.ref.delete().catch(() => {});
        if (shard !== undefined) {
          await db.collection(`video_jobs_${shard}`).doc(finalJobId).delete().catch(() => {});
        }
      }
    } else {
      const jobsSnap = await db.collection("video_jobs").where("videoId", "==", videoId).get();
      for (const jobDoc of jobsSnap.docs) {
        finalJobId = jobDoc.id;
        const jobData = jobDoc.data();
        const shard = jobData?.shard;
        await jobDoc.ref.delete().catch(() => {});
        if (shard !== undefined) {
          await db.collection(`video_jobs_${shard}`).doc(finalJobId).delete().catch(() => {});
        }
      }
    }

    // 11. Decrement videoCount on channel
    if (channelId) {
      await db.collection("channels").doc(channelId).update({
        "videoCount": admin.firestore.FieldValue.increment(-1),
        "stats.videoCount": admin.firestore.FieldValue.increment(-1)
      }).catch(() => {});
    }

    // 12. Delete Storage folders and files
    await deleteStorageFolder(`videos/${videoId}`);
    await deleteStorageFolder(`thumbnails/${videoId}`);
    await deleteStorageFolder(`resolutions/${videoId}`);

    if (finalJobId) {
      await deleteStorageFolder(`transcripts/${finalJobId}`);
      await deleteStorageFolder(`translations/${finalJobId}`);
      await deleteStorageFolder(`factChecks/${finalJobId}`);
      await deleteStorageFolder(`subtitles/${finalJobId}`);
      await deleteStorageFolder(`dubbing_results/${finalJobId}`);
    }

    // Parse and delete specific media files from URL
    if (videoUrl) {
      const videoPath = getStoragePathFromUrl(videoUrl);
      if (videoPath) await deleteStorageFile(videoPath);
    }
    if (thumbnailUrl) {
      const thumbPath = getStoragePathFromUrl(thumbnailUrl);
      if (thumbPath) await deleteStorageFile(thumbPath);
    }

    // 13. Decrement videoCount on associated topics
    const topicSlug = data.topicId;
    const topicSlugs = data.topics || [];
    const allTopicSlugs = new Set<string>();
    if (topicSlug) allTopicSlugs.add(topicSlug);
    if (Array.isArray(topicSlugs)) {
      topicSlugs.forEach((slug: string) => {
        if (slug) allTopicSlugs.add(slug);
      });
    }

    for (const slug of allTopicSlugs) {
      const topicsSnap = await db.collection("topics").where("slug", "==", slug).get();
      for (const topicDoc of topicsSnap.docs) {
        await topicDoc.ref.update({
          videoCount: admin.firestore.FieldValue.increment(-1)
        }).catch(err => console.error(`[VideoCascade] Error decrementing topic videoCount (slug query):`, err));
      }
      const directTopicDoc = await db.collection("topics").doc(slug).get();
      if (directTopicDoc.exists) {
        await directTopicDoc.ref.update({
          videoCount: admin.firestore.FieldValue.increment(-1)
        }).catch(err => console.error(`[VideoCascade] Error decrementing topic videoCount (direct ID):`, err));
      }
    }

    // 14. Remove video from featuredVideoIds in all topics
    const topicsWithFeaturedSnap = await db.collection("topics").where("featuredVideoIds", "array-contains", videoId).get();
    for (const doc of topicsWithFeaturedSnap.docs) {
      const featuredVideoIds = doc.data().featuredVideoIds || [];
      const updatedFeatured = featuredVideoIds.filter((id: string) => id !== videoId);
      await doc.ref.update({
        featuredVideoIds: updatedFeatured
      }).catch(err => console.error(`[VideoCascade] Error updating featuredVideoIds in topic ${doc.id}:`, err));
    }

    // 15. Remove video from all public and private playlists
    const playlistsSnap = await db.collection("playlists").where("videoIds", "array-contains", videoId).get();
    for (const doc of playlistsSnap.docs) {
      const videoIds = doc.data().videoIds || [];
      const updatedVideoIds = videoIds.filter((id: string) => id !== videoId);
      await doc.ref.update({ videoIds: updatedVideoIds }).catch(() => {});
    }

    const savedPlaylistsSnap = await db.collectionGroup("saved_playlists").where("videoIds", "array-contains", videoId).get();
    for (const doc of savedPlaylistsSnap.docs) {
      const videoIds = doc.data().videoIds || [];
      const updatedVideoIds = videoIds.filter((id: string) => id !== videoId);
      await doc.ref.update({ videoIds: updatedVideoIds }).catch(() => {});
    }

    console.log(`[VideoCascade] Finished cleanup for video: ${videoId}`);
  }
);

// ─── Topic Deletion Cascade ──────────────────────────────────────────────────

/**
 * ⚡ TRIGGER: ON TOPIC DOCUMENT DELETED
 * Automatically runs when a topic document is physically deleted in Firestore.
 */
export const onTopicDeleted = onDocumentDeleted(
  {
    document: "topics/{topicId}",
    region: "asia-south1",
    memory: "256MiB",
  },
  async (event) => {
    const topicId = event.params.topicId;
    console.log(`[TopicCascade] Starting cleanup for topic: ${topicId}`);
    const db = admin.firestore();

    // 1. Delete subcollections of topic
    const subcollections = ["followers", "likes"];
    for (const sub of subcollections) {
      await deleteQueryBatch(db.collection("topics").doc(topicId).collection(sub));
    }

    // 2. Delete nested comments and replies subcollections
    const commentsRef = db.collection("topics").doc(topicId).collection("comments");
    const commentsSnap = await commentsRef.get();
    for (const commentDoc of commentsSnap.docs) {
      await deleteQueryBatch(commentDoc.ref.collection("replies"));
      await deleteQueryBatch(commentDoc.ref.collection("likes"));
      await deleteQueryBatch(commentDoc.ref.collection("dislikes"));
      await commentDoc.ref.delete().catch(() => {});
    }

    // 3. Delete top-level topic followers/likes/dislikes/reports
    await deleteQueryBatch(db.collection("topic_followers").where("topicId", "==", topicId));
    await deleteQueryBatch(db.collection("topic_likes").where("topicId", "==", topicId));
    await deleteQueryBatch(db.collection("topic_dislikes").where("topicId", "==", topicId));
    await deleteQueryBatch(db.collection("topic_reports").where("topicId", "==", topicId));

    const data = event.data?.data();
    if (data) {
      const slug = data.slug || topicId;

      // 4. Delete topic assets from Storage (only if they are custom topic_images)
      if (data.thumbnailUrl) {
        const thumbPath = getStoragePathFromUrl(data.thumbnailUrl);
        if (thumbPath && thumbPath.startsWith("topic_images/")) {
          await deleteStorageFile(thumbPath);
        }
      }
      if (data.coverImage) {
        const coverPath = getStoragePathFromUrl(data.coverImage);
        if (coverPath && coverPath.startsWith("topic_images/")) {
          await deleteStorageFile(coverPath);
        }
      }

      // 5. Clear topic references in video documents
      const videosWithTopicSnap = await db.collection("videos").where("topicId", "==", slug).get();
      for (const doc of videosWithTopicSnap.docs) {
        await doc.ref.update({
          topicId: null,
          topicTitle: null
        }).catch(err => console.error(`[TopicCascade] Error clearing topicId on video ${doc.id}:`, err));
      }
      if (topicId !== slug) {
        const videosWithTopicIdSnap = await db.collection("videos").where("topicId", "==", topicId).get();
        for (const doc of videosWithTopicIdSnap.docs) {
          await doc.ref.update({
            topicId: null,
            topicTitle: null
          }).catch(err => console.error(`[TopicCascade] Error clearing topicId on video ${doc.id}:`, err));
        }
      }

      // Clear from topics array in videos
      const videosWithTopicsArraySnap = await db.collection("videos").where("topics", "array-contains", slug).get();
      for (const doc of videosWithTopicsArraySnap.docs) {
        const topics = doc.data().topics || [];
        const updatedTopics = topics.filter((t: string) => t !== slug);
        await doc.ref.update({
          topics: updatedTopics
        }).catch(err => console.error(`[TopicCascade] Error updating topics array on video ${doc.id}:`, err));
      }
      if (topicId !== slug) {
        const videosWithTopicsArrayIdSnap = await db.collection("videos").where("topics", "array-contains", topicId).get();
        for (const doc of videosWithTopicsArrayIdSnap.docs) {
          const topics = doc.data().topics || [];
          const updatedTopics = topics.filter((t: string) => t !== topicId);
          await doc.ref.update({
            topics: updatedTopics
          }).catch(err => console.error(`[TopicCascade] Error updating topics array on video ${doc.id}:`, err));
        }
      }
    }

    console.log(`[TopicCascade] Finished cleanup for topic: ${topicId}`);
  }
);

// ─── Scheduled Delayed Deletions ─────────────────────────────────────────────

/**
 * ⚡ TRIGGER: SCHEDULED DELAYED DELETIONS
 * Runs daily to check for user accounts, channels, videos, topics, and playlists
 * that have been marked for deletion and have exceeded their safety delay periods.
 */
export const scheduledDelayedDeletions = onSchedule(
  {
    schedule: "every 24 hours",
    region: "asia-south1",
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async (event) => {
    const db = admin.firestore();
    const now = Date.now();

    // 1. User Deletions (7 days delay)
    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(now - 7 * 24 * 60 * 60 * 1000);
    const usersQuery = db.collection("users")
      .where("status", "==", "deletion_pending")
      .where("deletionRequestedAt", "<=", sevenDaysAgo);
    const usersSnap = await usersQuery.get();
    console.log(`[ScheduledDeletions] Found ${usersSnap.size} users pending deletion`);
    for (const userDoc of usersSnap.docs) {
      const userId = userDoc.id;
      await cascadeDeleteUser(userId);
      await admin.auth().deleteUser(userId).catch(err => {
        console.error(`[ScheduledDeletions] Error deleting Auth user ${userId}:`, err);
      });
    }

    // 2. Channel Deletions (30 days delay)
    const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(now - 30 * 24 * 60 * 60 * 1000);
    const channelsQuery = db.collection("channels")
      .where("status", "==", "deletion_pending")
      .where("deletionRequestedAt", "<=", thirtyDaysAgo);
    const channelsSnap = await channelsQuery.get();
    console.log(`[ScheduledDeletions] Found ${channelsSnap.size} channels pending deletion`);
    for (const channelDoc of channelsSnap.docs) {
      await channelDoc.ref.delete().catch(err => {
        console.error(`[ScheduledDeletions] Error deleting channel doc ${channelDoc.id}:`, err);
      });
    }

    // 3. Video Deletions (30 days delay)
    const videosQuery = db.collection("videos")
      .where("status", "==", "deletion_pending")
      .where("deletionRequestedAt", "<=", thirtyDaysAgo);
    const videosSnap = await videosQuery.get();
    console.log(`[ScheduledDeletions] Found ${videosSnap.size} videos pending deletion`);
    for (const videoDoc of videosSnap.docs) {
      await videoDoc.ref.delete().catch(err => {
        console.error(`[ScheduledDeletions] Error deleting video doc ${videoDoc.id}:`, err);
      });
    }

    // 4. Topic Deletions (30 days delay)
    const topicsQuery = db.collection("topics")
      .where("status", "==", "deletion_pending")
      .where("deletionRequestedAt", "<=", thirtyDaysAgo);
    const topicsSnap = await topicsQuery.get();
    console.log(`[ScheduledDeletions] Found ${topicsSnap.size} topics pending deletion`);
    for (const topicDoc of topicsSnap.docs) {
      await topicDoc.ref.delete().catch(err => {
        console.error(`[ScheduledDeletions] Error deleting topic doc ${topicDoc.id}:`, err);
      });
    }

    // 5. Public Playlist Deletions (30 days delay)
    const publicPlaylistsQuery = db.collection("playlists")
      .where("status", "==", "deletion_pending")
      .where("deletionRequestedAt", "<=", thirtyDaysAgo);
    const publicPlaylistsSnap = await publicPlaylistsQuery.get();
    console.log(`[ScheduledDeletions] Found ${publicPlaylistsSnap.size} public playlists pending deletion`);
    for (const playlistDoc of publicPlaylistsSnap.docs) {
      await playlistDoc.ref.delete().catch(err => {
        console.error(`[ScheduledDeletions] Error deleting public playlist doc ${playlistDoc.id}:`, err);
      });
    }

    // 6. Private Playlist Deletions (30 days delay)
    const privatePlaylistsQuery = db.collectionGroup("saved_playlists")
      .where("status", "==", "deletion_pending")
      .where("deletionRequestedAt", "<=", thirtyDaysAgo);
    const privatePlaylistsSnap = await privatePlaylistsQuery.get();
    console.log(`[ScheduledDeletions] Found ${privatePlaylistsSnap.size} private playlists pending deletion`);
    for (const playlistDoc of privatePlaylistsSnap.docs) {
      await playlistDoc.ref.delete().catch(err => {
        console.error(`[ScheduledDeletions] Error deleting private playlist doc ${playlistDoc.id}:`, err);
      });
    }
  }
);

// ─── Community Post Deletion Cascade ─────────────────────────────────────────

/**
 * ⚡ TRIGGER: ON COMMUNITY POST DOCUMENT DELETED
 * Automatically runs when a community post document is physically deleted in Firestore.
 */
export const onCommunityPostDeleted = onDocumentDeleted(
  {
    document: "Community/{postId}",
    region: "asia-south1",
    memory: "256MiB",
  },
  async (event) => {
    const postId = event.params.postId;
    const data = event.data?.data();
    if (!data) return;

    console.log(`[CommunityCascade] Starting cleanup for post: ${postId}`);
    const images = data.images || [];

    // Delete post images from Storage
    for (const imageUrl of images) {
      const storagePath = getStoragePathFromUrl(imageUrl);
      if (storagePath) {
        await deleteStorageFile(storagePath);
      }
    }

    // Also support single/legacy image field
    if (data.image) {
      const storagePath = getStoragePathFromUrl(data.image);
      if (storagePath) {
        await deleteStorageFile(storagePath);
      }
    }
    console.log(`[CommunityCascade] Finished cleanup for post: ${postId}`);
  }
);

