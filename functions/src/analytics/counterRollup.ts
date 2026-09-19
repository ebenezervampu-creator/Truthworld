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
        }).get();

        const aggData = aggSnap.data();
        const totalViews = aggData.totalViews ? Number(aggData.totalViews) : 0;
        const totalQualified = aggData.totalQualified
          ? Number(aggData.totalQualified)
          : 0;

        if (totalViews > 0) {
          const videoRef = db.collection("videos").doc(videoId);
          batch.update(videoRef, {
            viewCount: totalViews,
            views: totalViews,
            qualifiedViewCount: totalQualified,
            lastShardRollupAt: admin.firestore.FieldValue.serverTimestamp(),
          });
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
        }).get();

        const aggData = aggSnap.data();
        const totalViews = aggData.totalViews ? Number(aggData.totalViews) : 0;

        if (totalViews > 0) {
          const channelRef = db.collection("channels").doc(channelId);
          batch.set(
            channelRef,
            {
              metrics: { totalViews },
              viewCount: totalViews,
              lastShardRollupAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
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
