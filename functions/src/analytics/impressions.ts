import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";
const MAX_BATCH_SIZE = 300; // Process up to 300 videos per run

/**
 * Scheduled Cloud Function: Aggregates pending impression counters from RTDB
 * into permanent Firestore video records.
 *
 * Concurrency & Failure Safety:
 * 1. Reads bounded pending impression counters from RTDB (/pendingImpressions).
 * 2. Increments Firestore `videos/{videoId}.impressionCount` via batch.
 * 3. Atomically decrements the exact processed delta from RTDB (`ServerValue.increment(-delta)`).
 * 4. If any Firestore batch fails, RTDB is NOT decremented (zero data loss).
 * 5. If new client impressions arrive during execution, the decrement preserves the new delta.
 *
 * Scheduled to run every 10 minutes.
 */
export const aggregateVideoImpressions = onSchedule(
  {
    schedule: "every 10 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    logger.info("aggregateVideoImpressions: start");
    const rtdb = admin.database();
    const firestore = admin.firestore();

    const pendingRef = rtdb.ref("pendingImpressions");
    const snapshot = await pendingRef.limitToFirst(MAX_BATCH_SIZE).get();

    if (!snapshot.exists()) {
      logger.info("aggregateVideoImpressions: no pending impressions to process");
      return;
    }

    const pendingData = snapshot.val();
    if (!pendingData || typeof pendingData !== "object") {
      return;
    }

    const videoDeltas = new Map<string, number>();

    for (const [videoId, val] of Object.entries(pendingData)) {
      if (val && typeof val === "object") {
        const count = (val as any).count;
        if (typeof count === "number" && count > 0) {
          videoDeltas.set(videoId, count);
        }
      }
    }

    if (videoDeltas.size === 0) {
      logger.info("aggregateVideoImpressions: all pending counts are zero");
      return;
    }

    logger.info(`aggregateVideoImpressions: processing ${videoDeltas.size} videos`);

    // 1. Commit increments to Firestore in bounded batches (max 400 ops per batch)
    let batch = firestore.batch();
    let ops = 0;
    const committedVideos: { videoId: string; delta: number }[] = [];

    for (const [videoId, delta] of videoDeltas.entries()) {
      const videoRef = firestore.collection("videos").doc(videoId);
      batch.update(videoRef, {
        impressionCount: admin.firestore.FieldValue.increment(delta),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      committedVideos.push({ videoId, delta });
      ops++;

      if (ops >= 400) {
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    // 2. Atomically decrement processed deltas in RTDB to prevent race conditions & double-counting
    const rtdbUpdates: Record<string, any> = {};
    for (const { videoId, delta } of committedVideos) {
      rtdbUpdates[`${videoId}/count`] = admin.database.ServerValue.increment(-delta);
    }

    await pendingRef.update(rtdbUpdates);

    // 3. Clean up nodes that have reached <= 0
    const cleanupPromises = committedVideos.map(async ({ videoId }) => {
      const nodeRef = pendingRef.child(videoId);
      const nodeSnap = await nodeRef.child("count").get();
      if (nodeSnap.exists() && (nodeSnap.val() as number) <= 0) {
        await nodeRef.remove();
      }
    });
    await Promise.allSettled(cleanupPromises);

    logger.info(`aggregateVideoImpressions: successfully aggregated impressions for ${committedVideos.length} videos.`);
  }
);

/**
 * Periodically aggregate raw views from views_raw collection
 * and update viewCount and qualifiedViewCount on the corresponding video documents.
 * 
 * Scheduled to run every 60 minutes.
 */
export const aggregateVideoViews = onSchedule(
  {
    schedule: "every 60 minutes",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    logger.info("aggregateVideoViews: start");
    const db = admin.firestore();

    const metaRef = db.collection("system_meta").doc("views");
    const metaDoc = await metaRef.get();

    const lastProcessedAt: admin.firestore.Timestamp =
      metaDoc.exists && metaDoc.data()?.lastProcessedAt
        ? metaDoc.data()!.lastProcessedAt
        : admin.firestore.Timestamp.fromDate(new Date(0));

    const runStartedAt = admin.firestore.Timestamp.now();

    // Fetch new raw views
    const snapshot = await db
      .collection("views_raw")
      .where("timestamp", ">", lastProcessedAt)
      .orderBy("timestamp", "asc")
      .get();

    if (snapshot.empty) {
      logger.info("aggregateVideoViews: no new views to process");
      await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
      return;
    }

    logger.info(`aggregateVideoViews: processing ${snapshot.size} new views`);

    // Group views by videoId
    const videoCounts = new Map<string, { rawViews: number; qualifiedViews: number }>();
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const videoId = data.videoId;
      const isQualified = data.isQualified === true;
      if (videoId && typeof videoId === "string") {
        const existing = videoCounts.get(videoId) || { rawViews: 0, qualifiedViews: 0 };
        existing.rawViews += 1;
        if (isQualified) {
          existing.qualifiedViews += 1;
        }
        videoCounts.set(videoId, existing);
      }
    }

    // Write counts back to video documents in batches
    let batch = db.batch();
    let ops = 0;

    for (const [videoId, counts] of videoCounts.entries()) {
      if (ops >= 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }

      const videoRef = db.collection("videos").doc(videoId);
      const updates: Record<string, any> = {
        viewCount: admin.firestore.FieldValue.increment(counts.rawViews),
        updatedAt: Date.now(),
      };
      if (counts.qualifiedViews > 0) {
        updates.qualifiedViewCount = admin.firestore.FieldValue.increment(counts.qualifiedViews);
      }

      batch.update(videoRef, updates);
      ops++;
    }

    if (ops > 0) {
      await batch.commit();
    }

    // Save progress cursor
    await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
    logger.info(`aggregateVideoViews: finished. Aggregated ${snapshot.size} views for ${videoCounts.size} videos.`);
  }
);

/**
 * Periodically purge raw views older than 7 days.
 * 
 * Scheduled to run every 24 hours.
 */
export const cleanupOldViews = onSchedule(
  {
    schedule: "every 24 hours",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    logger.info("cleanupOldViews: start");
    const db = admin.firestore();

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const snapshot = await db
      .collection("views_raw")
      .where("timestamp", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .limit(1000)
      .get();

    if (snapshot.empty) {
      logger.info("cleanupOldViews: no old raw views to purge");
      return;
    }

    logger.info(`cleanupOldViews: purging ${snapshot.size} old raw views`);

    let batch = db.batch();
    let ops = 0;

    for (const doc of snapshot.docs) {
      if (ops >= 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
      batch.delete(doc.ref);
      ops++;
    }

    if (ops > 0) {
      await batch.commit();
    }

    logger.info(`cleanupOldViews: purged ${snapshot.size} raw view documents`);
  }
);
