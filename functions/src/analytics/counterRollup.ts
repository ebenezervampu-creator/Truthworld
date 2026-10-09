import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";

/**
 * Scheduled Cloud Function: Rolls up distributed counter shards into parent
 * video and channel documents.
 *
 * Architecture:
 * - High-velocity view writes are distributed across 20 sub-counters (`videos/{id}/shards/{0..19}`).
 * - This scheduled function consolidates shard totals into `videos/{id}.viewCount` and
 *   `channels/{id}.metrics.totalViews` once every 5 minutes in controlled batches.
 * - Guarantees fast, cost-efficient O(1) single-document reads for feed and search queries
 *   without triggering Firestore's 1 write/sec per document contention limit.
 *
 * Scheduled to run every 5 minutes.
 */
export const rollupVideoCounterShards = onSchedule(
  {
    schedule: "every 5 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    logger.info("rollupVideoCounterShards: start");
    const db = admin.firestore();

    const metaRef = db.collection("system_meta").doc("counter_shards");
    const metaDoc = await metaRef.get();

    const lastProcessedAt: admin.firestore.Timestamp =
      metaDoc.exists && metaDoc.data()?.lastProcessedAt
        ? metaDoc.data()!.lastProcessedAt
        : admin.firestore.Timestamp.fromDate(new Date(0));

    const runStartedAt = admin.firestore.Timestamp.now();

    const videoIdsToRollup = new Set<string>();
    const channelIdsToRollup = new Set<string>();
    let progressCursor = runStartedAt;

    try {
      // 1. Discover active shards updated since last run (bounded to 2,000 shards per cycle)
      const shardSnapshot = await db
        .collectionGroup("shards")
        .where("updatedAt", ">", lastProcessedAt)
        .orderBy("updatedAt", "asc")
        .limit(2000)
        .get();

      if (shardSnapshot.empty) {
        logger.info("rollupVideoCounterShards: no active shards to process");
        await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
        return;
      }

      logger.info(`rollupVideoCounterShards: discovered ${shardSnapshot.size} active shard writes`);

      for (const doc of shardSnapshot.docs) {
        const parentDoc = doc.ref.parent.parent;
        if (!parentDoc) continue;

        const grandParentCol = parentDoc.parent.id;
        if (grandParentCol === "videos") {
          videoIdsToRollup.add(parentDoc.id);
        } else if (grandParentCol === "channels") {
          channelIdsToRollup.add(parentDoc.id);
        }
      }

      const lastDoc = shardSnapshot.docs[shardSnapshot.docs.length - 1];
      const lastDocTimestamp = lastDoc.data()?.updatedAt;
      if (lastDocTimestamp instanceof admin.firestore.Timestamp) {
        progressCursor = lastDocTimestamp;
      }
    } catch (queryError) {
      logger.warn(
        "rollupVideoCounterShards: collectionGroup query warning, falling back to recent videos",
        queryError
      );
      // Fallback: check 50 recently updated videos
      const recentVideos = await db
        .collection("videos")
        .orderBy("updatedAt", "desc")
        .limit(50)
        .get();

      for (const doc of recentVideos.docs) {
        videoIdsToRollup.add(doc.id);
      }
    }

    logger.info(
      `rollupVideoCounterShards: consolidating ${videoIdsToRollup.size} videos and ${channelIdsToRollup.size} channels`
    );

    let batch = db.batch();
    let ops = 0;
    let consolidatedVideos = 0;
    let consolidatedChannels = 0;

    // 2. Consolidate video counter shards
    for (const videoId of videoIdsToRollup) {
      try {
        const shardsCollection = db
          .collection("videos")
          .doc(videoId)
          .collection("shards");

        const aggSnap = await shardsCollection.aggregate({
          totalViews: admin.firestore.AggregateField.sum("count"),
          totalQualified: admin.firestore.AggregateField.sum("qualifiedCount"),
          totalWatchTimeSeconds: admin.firestore.AggregateField.sum("watchTimeSeconds"),
        }).get();

        const aggData = aggSnap.data();
        const totalViews = aggData.totalViews ? Number(aggData.totalViews) : 0;
        const totalQualified = aggData.totalQualified
          ? Number(aggData.totalQualified)
          : 0;
        let totalWatchTimeSeconds = aggData.totalWatchTimeSeconds
          ? Number(aggData.totalWatchTimeSeconds)
          : 0;

        if (totalViews > 0 || totalWatchTimeSeconds > 0) {
          const videoRef = db.collection("videos").doc(videoId);
          let videoDuration = 0;
          try {
            const vSnap = await videoRef.get();
            if (vSnap.exists) {
              const vData = vSnap.data();
              videoDuration = Number(vData?.durationSeconds || 0) ||
                (vData?.durationMs ? Math.floor(Number(vData.durationMs) / 1000) : 0);
            }
          } catch (_) {}

          if (videoDuration > 0 && totalWatchTimeSeconds > 0) {
            const viewsCeiling = Math.max(1, totalViews);
            const maxAllowedWatchTime = viewsCeiling * videoDuration;
            if (totalWatchTimeSeconds > maxAllowedWatchTime) {
              totalWatchTimeSeconds = maxAllowedWatchTime;
            }
          }

          const updateData: Record<string, any> = {
            lastShardRollupAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          if (totalViews > 0) {
            updateData.viewCount = totalViews;
            updateData.views = totalViews;
            updateData.qualifiedViewCount = totalQualified;
          }
          if (totalWatchTimeSeconds > 0) {
            updateData.totalWatchTimeSeconds = totalWatchTimeSeconds;
          }
          batch.update(videoRef, updateData);
          ops++;
          consolidatedVideos++;

          if (ops >= 400) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
          }
        }
      } catch (videoError) {
        logger.error(`rollupVideoCounterShards: error aggregating video ${videoId}`, videoError);
      }
    }

    // 3. Consolidate channel counter shards
    for (const channelId of channelIdsToRollup) {
      try {
        const shardsCollection = db
          .collection("channels")
          .doc(channelId)
          .collection("shards");

        const aggSnap = await shardsCollection.aggregate({
          totalViews: admin.firestore.AggregateField.sum("views"),
          totalWatchTimeSeconds: admin.firestore.AggregateField.sum("watchTimeSeconds"),
          totalSubscriberDelta: admin.firestore.AggregateField.sum("subscriberDelta"),
        }).get();

        const aggData = aggSnap.data();
        const totalViews = aggData.totalViews ? Number(aggData.totalViews) : 0;
        const totalWatchTimeSeconds = aggData.totalWatchTimeSeconds
          ? Number(aggData.totalWatchTimeSeconds)
          : 0;
        const totalSubscriberDelta = aggData.totalSubscriberDelta
          ? Number(aggData.totalSubscriberDelta)
          : 0;

        if (totalViews > 0 || totalWatchTimeSeconds > 0 || totalSubscriberDelta !== 0) {
          const channelRef = db.collection("channels").doc(channelId);
          const updateData: Record<string, any> = {
            lastShardRollupAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          if (totalViews > 0) {
            updateData.viewCount = totalViews;
            updateData["metrics.totalViews"] = totalViews;
          }
          if (totalWatchTimeSeconds > 0) {
            updateData.totalWatchTimeSeconds = totalWatchTimeSeconds;
            updateData["metrics.totalWatchTimeMinutes"] = Math.floor(totalWatchTimeSeconds / 60);
          }
          if (totalSubscriberDelta !== 0) {
            updateData.shardSubscriberSyncDelta = totalSubscriberDelta;
          }
          batch.set(channelRef, updateData, { merge: true });
          ops++;
          consolidatedChannels++;

          if (ops >= 400) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
          }
        }
      } catch (channelError) {
        logger.error(
          `rollupVideoCounterShards: error aggregating channel ${channelId}`,
          channelError
        );
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    // 4. Update progress cursor
    await metaRef.set({ lastProcessedAt: progressCursor }, { merge: true });

    logger.info(
      `rollupVideoCounterShards: successfully rolled up ${consolidatedVideos} videos and ${consolidatedChannels} channels.`
    );
  }
);
