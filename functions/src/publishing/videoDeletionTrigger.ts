/**
 * 🗑️ VIDEO DELETION & CASCADE PURGE ENGINE (Gen 2 Cloud Functions)
 *
 * Responsibilities:
 * 1. onVideoDeletedCascade (Firestore onDocumentDeleted trigger on `videos/{videoId}`):
 *    - Automatically cascades deletion to ALL subcollections (`media`, `shards`, `comment_shards`, `comments`, `views`, etc.)
 *      via `admin.firestore().recursiveDelete(event.data.ref)` so phantom/ghost documents can NEVER be left behind in Firestore.
 *    - Deletes search metadata from `video_search/{videoId}`.
 *    - Deletes any registered duplicate hashes in `video_hashes`.
 *    - Cleans up associated storage assets in `videos/{videoId}/`, `thumbnails/{videoId}/`, `resolutions/{videoId}/`, `storyboards/{videoId}/`.
 *    - Recalculates genuine channel videoCount.
 *
 * 2. permanentlyDeleteVideo (Callable onCall):
 *    - Validates caller authentication and authorization (owner or admin).
 *    - Safely executes deep recursive deletion across Firestore and GCS Storage.
 */

import * as admin from "firebase-admin";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "../pipeline/utils/logger";
import { isCallableAdmin } from "../utils/auth";
import { invalidateFeedGeneration } from "../shared/memory-cache";

const BUCKET_NAME = process.env.STORAGE_BUCKET || "truthworld-1.firebasestorage.app";

/**
 * 🧹 Deep cascade deletion trigger when a video document is deleted.
 */
export const onVideoDeletedCascade = onDocumentDeleted(
  {
    document: "videos/{videoId}",
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 3,
  },
  async (event) => {
    const videoId = event.params.videoId;
    if (!videoId) return;

    logger.info(`[VideoCascadePurge] Starting cascade purge for video: ${videoId}`);
    const db = admin.firestore();
    const beforeData = event.data?.data();

    try {
      // Invalidate edge/L1 public feed cache immediately upon video deletion
      try {
        invalidateFeedGeneration();
      } catch (cacheErr) {
        logger.warn(`[VideoCascadePurge] Failed to invalidate feed cache generation for ${videoId}:`, cacheErr);
      }

      // 1. Recursive delete any subcollections remaining under videos/{videoId}
      const videoRef = db.collection("videos").doc(videoId);
      await db.recursiveDelete(videoRef).catch((err) => {
        logger.warn(`[VideoCascadePurge] Subcollection recursive delete warning for ${videoId}:`, err);
      });

      // 2. Remove from video_search
      await db.collection("video_search").doc(videoId).delete().catch(() => {});

      // 3. Remove from shorts if present
      await db.collection("shorts").doc(videoId).delete().catch(() => {});

      // 4. Remove any matching video_hashes (by videoId or jobId)
      const hashQueries = [
        db.collection("video_hashes").where("jobId", "==", videoId).get().catch(() => null),
        db.collection("video_hashes").where("videoId", "==", videoId).get().catch(() => null),
      ];
      if (beforeData?.jobId) {
        hashQueries.push(
          db.collection("video_hashes").where("jobId", "==", beforeData.jobId).get().catch(() => null)
        );
      }
      const hashResults = await Promise.all(hashQueries);
      const hashBatch = db.batch();
      let hasDeletions = false;
      for (const snap of hashResults) {
        if (snap && !snap.empty) {
          snap.docs.forEach((d) => {
            hashBatch.delete(d.ref);
            hasDeletions = true;
          });
        }
      }
      if (hasDeletions) {
        await hashBatch.commit().catch(() => {});
      }

      // 4. Remove GCS Storage assets for this video
      try {
        const bucket = admin.storage().bucket(BUCKET_NAME);
        await bucket.deleteFiles({ prefix: `videos/${videoId}/` }).catch(() => {});
        await bucket.deleteFiles({ prefix: `thumbnails/${videoId}/` }).catch(() => {});
        await bucket.deleteFiles({ prefix: `resolutions/${videoId}/` }).catch(() => {});
        await bucket.deleteFiles({ prefix: `storyboards/${videoId}/` }).catch(() => {});
      } catch (storageErr) {
        logger.warn(`[VideoCascadePurge] Storage cleanup warning for ${videoId}:`, storageErr);
      }

      // 5. Reconcile Channel videoCount if channelId is known
      const channelId = beforeData?.channelId;
      if (channelId) {
        try {
          const videosSnap = await db.collection("videos")
            .where("channelId", "==", channelId)
            .get();

          let validCount = 0;
          for (const doc of videosSnap.docs) {
            const d = doc.data();
            if (
              doc.id !== videoId &&
              d.status !== "deleted" &&
              d.status !== "deletion_pending" &&
              d.status !== "trashed" &&
              d.status !== "trash" &&
              !d.isDeleted
            ) {
              validCount++;
            }
          }

          await db.collection("channels").doc(channelId).update({
            videoCount: validCount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }).catch(() => {});
          logger.info(`[VideoCascadePurge] Reconciled channel ${channelId} videoCount to ${validCount}`);
        } catch (chanErr) {
          logger.warn(`[VideoCascadePurge] Channel videoCount update error for ${channelId}:`, chanErr);
        }
      }

      logger.info(`[VideoCascadePurge] Successfully completed cascade purge for video: ${videoId}`);
    } catch (error) {
      logger.error(`[VideoCascadePurge] Failed cascade purge for video: ${videoId}`, error);
    }
  }
);

/**
 * 🛡️ Authoritative callable endpoint to permanently delete a video and its subcollections.
 */
export const permanentlyDeleteVideo = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 3,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const { videoId } = request.data || {};
    if (!videoId || typeof videoId !== "string" || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
      throw new HttpsError("invalid-argument", "Valid videoId is required.");
    }

    const db = admin.firestore();
    const videoRef = db.collection("videos").doc(videoId);
    const videoSnap = await videoRef.get();

    if (!videoSnap.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }

    const data = videoSnap.data()!;
    const channelId = data.channelId;
    const callerUid = request.auth.uid;
    const videoOwnerId = data.ownerId || data.userId || data.uploaderId;
    let isOwner = videoOwnerId === callerUid;
    const isAdmin = isCallableAdmin(request.auth);

    if (!isOwner && !isAdmin && channelId) {
      try {
        const channelSnap = await db.collection("channels").doc(channelId).get();
        if (channelSnap.exists) {
          const cData = channelSnap.data() || {};
          if (cData.ownerId === callerUid || cData.userId === callerUid) {
            isOwner = true;
          }
        }
      } catch (cErr) {
        logger.warn(`[permanentlyDeleteVideo] Channel lookup error for ${channelId}:`, cErr);
      }
    }

    if (!isOwner && !isAdmin) {
      throw new HttpsError("permission-denied", "You do not have permission to delete this video.");
    }

    try {
      // 1. Recursive delete doc + all subcollections
      await db.recursiveDelete(videoRef);

      // 2. Delete search metadata
      await db.collection("video_search").doc(videoId).delete().catch(() => {});

      // 3. Delete from shorts if present
      await db.collection("shorts").doc(videoId).delete().catch(() => {});

      // 4. Delete hashes (by videoId or jobId)
      const hashQueries = [
        db.collection("video_hashes").where("jobId", "==", videoId).get().catch(() => null),
        db.collection("video_hashes").where("videoId", "==", videoId).get().catch(() => null),
      ];
      if (data?.jobId) {
        hashQueries.push(
          db.collection("video_hashes").where("jobId", "==", data.jobId).get().catch(() => null)
        );
      }
      const hashResults = await Promise.all(hashQueries);
      const hashBatch = db.batch();
      let hasDeletions = false;
      for (const snap of hashResults) {
        if (snap && !snap.empty) {
          snap.docs.forEach((d) => {
            hashBatch.delete(d.ref);
            hasDeletions = true;
          });
        }
      }
      if (hasDeletions) {
        await hashBatch.commit().catch(() => {});
      }

      // 4. Delete Storage assets
      const bucket = admin.storage().bucket(BUCKET_NAME);
      await bucket.deleteFiles({ prefix: `videos/${videoId}/` }).catch(() => {});
      await bucket.deleteFiles({ prefix: `thumbnails/${videoId}/` }).catch(() => {});
      await bucket.deleteFiles({ prefix: `resolutions/${videoId}/` }).catch(() => {});
      await bucket.deleteFiles({ prefix: `storyboards/${videoId}/` }).catch(() => {});

      // 5. Reconcile Channel count
      if (channelId) {
        const videosSnap = await db.collection("videos")
          .where("channelId", "==", channelId)
          .get()
          .catch(() => null);
        if (videosSnap) {
          let validCount = 0;
          for (const doc of videosSnap.docs) {
            const d = doc.data();
            if (
              doc.id !== videoId &&
              d.status !== "deleted" &&
              d.status !== "deletion_pending" &&
              d.status !== "trashed" &&
              d.status !== "trash" &&
              !d.isDeleted
            ) {
              validCount++;
            }
          }
          await db.collection("channels").doc(channelId).update({
            videoCount: validCount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }).catch(() => {});
        }
      }

      // Invalidate edge/L1 public feed cache immediately upon video deletion
      try {
        invalidateFeedGeneration();
      } catch (cacheErr) {
        logger.warn(`[permanentlyDeleteVideo] Failed to invalidate feed cache generation for ${videoId}:`, cacheErr);
      }

      logger.info(`[permanentlyDeleteVideo] Successfully deleted video and cascaded assets: ${videoId}`);
      return { success: true, message: `Video ${videoId} permanently deleted.` };
    } catch (err: any) {
      logger.error(`[permanentlyDeleteVideo] Error deleting video ${videoId}:`, err);
      throw new HttpsError("internal", "Failed to permanently delete video. Please try again.");
    }
  }
);
