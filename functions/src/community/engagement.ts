import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "../pipeline/utils/logger";

/**
 * 🚀 SCALABLE ENGAGEMENT ENGINE (v1.0)
 * 
 * Handles likes and dislikes for videos using a sharded counter pattern.
 * Optimized for high-concurrency and cost-effectiveness.
 * 
 * Industry Standard: Mutual exclusion (Like vs Dislike) is handled here.
 */

// Number of shards to use for counters to avoid contention (1/sec limit)
const SHARD_COUNT = 10;

/**
 * Triggered when a LIKE is added or removed
 */
export const onVideoLikeChange = onDocumentWritten(
  {
    document: "videos/{videoId}/likes/{userId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const { videoId, userId } = event.params;
    const db = admin.firestore();
    const videoRef = db.collection("videos").doc(videoId);

    // 1. Determine the increment value
    const isCreated = !event.data?.before.exists && event.data?.after.exists;
    const isDeleted = event.data?.before.exists && !event.data?.after.exists;

    if (!isCreated && !isDeleted) return; // No change in existence

    const increment = isCreated ? 1 : -1;

    try {
      // 2. Mutual Exclusion: If liking, ensure any dislike is removed
      if (isCreated) {
        const dislikeRef = videoRef.collection("dislikes").doc(userId);
        const dislikeDoc = await dislikeRef.get();
        if (dislikeDoc.exists) {
          await dislikeRef.delete();
          // Note: This deletion will trigger onVideoDislikeChange, 
          // which handles the dislikeCount decrement.
        }
      }

      // 3. Update Scalable Counter (Sharded approach)
      // For simplicity and cost-effectiveness in Firestore v2, 
      // we use FieldValue.increment on a random shard.
      const shardId = Math.floor(Math.random() * SHARD_COUNT).toString();
      const shardRef = videoRef.collection("counters").doc(`likes_shard_${shardId}`);
      
      await shardRef.set(
        { count: admin.firestore.FieldValue.increment(increment) },
        { merge: true }
      );

      // 4. Update the main document (Best effort for display)
      // In a high-traffic scenario, we would aggregate shards periodically.
      // For now, we update the main doc but expect contention.
      // If contention is too high, this can be moved to a scheduled aggregator.
      await videoRef.update({
        likeCount: admin.firestore.FieldValue.increment(increment)
      });

      logger.info(`[Engagement] Like ${isCreated ? 'added' : 'removed'} for video ${videoId}`);
    } catch (error) {
      logger.error("[Engagement] Error processing like change", { error: String(error), videoId, userId });
    }
  }
);

/**
 * Triggered when a DISLIKE is added or removed
 */
export const onVideoDislikeChange = onDocumentWritten(
  {
    document: "videos/{videoId}/dislikes/{userId}",
    region: "asia-south1",
    retry: true,
  },
  async (event) => {
    const { videoId, userId } = event.params;
    const db = admin.firestore();
    const videoRef = db.collection("videos").doc(videoId);

    const isCreated = !event.data?.before.exists && event.data?.after.exists;
    const isDeleted = event.data?.before.exists && !event.data?.after.exists;

    if (!isCreated && !isDeleted) return;

    const increment = isCreated ? 1 : -1;

    try {
      // Mutual Exclusion
      if (isCreated) {
        const likeRef = videoRef.collection("likes").doc(userId);
        const likeDoc = await likeRef.get();
        if (likeDoc.exists) {
          await likeRef.delete();
          // Deleting from likedVideos index too
          await db.collection("users").doc(userId).collection("likedVideos").doc(videoId).delete();
        }
      }

      const shardId = Math.floor(Math.random() * SHARD_COUNT).toString();
      const shardRef = videoRef.collection("counters").doc(`dislikes_shard_${shardId}`);
      
      await shardRef.set(
        { count: admin.firestore.FieldValue.increment(increment) },
        { merge: true }
      );

      await videoRef.update({
        dislikeCount: admin.firestore.FieldValue.increment(increment)
      });

      logger.info(`[Engagement] Dislike ${isCreated ? 'added' : 'removed'} for video ${videoId}`);
    } catch (error) {
      logger.error("[Engagement] Error processing dislike change", { error: String(error), videoId, userId });
    }
  }
);
