import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";

/**
 * Periodically aggregate raw impressions from impressions_raw collection
 * and update impressionCount on the corresponding video documents.
 * 
 * Scheduled to run every 60 minutes.
 */
export const aggregateVideoImpressions = onSchedule(
  {
    schedule: "every 60 minutes",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    logger.info("aggregateVideoImpressions: start");
    const db = admin.firestore();

    const metaRef = db.collection("system_meta").doc("impressions");
    const metaDoc = await metaRef.get();
    
    const lastProcessedAt: admin.firestore.Timestamp =
      metaDoc.exists && metaDoc.data()?.lastProcessedAt
        ? metaDoc.data()!.lastProcessedAt
        : admin.firestore.Timestamp.fromDate(new Date(0));

    const runStartedAt = admin.firestore.Timestamp.now();

    // Fetch new raw impressions
    const snapshot = await db
      .collection("impressions_raw")
      .where("timestamp", ">", lastProcessedAt)
      .orderBy("timestamp", "asc")
      .get();

    if (snapshot.empty) {
      logger.info("aggregateVideoImpressions: no new impressions to process");
      await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
      return;
    }

    logger.info(`aggregateVideoImpressions: processing ${snapshot.size} new impressions`);

    // Group impressions by videoId
    const videoCounts = new Map<string, number>();
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const videoId = data.videoId;
      if (videoId && typeof videoId === "string") {
        videoCounts.set(videoId, (videoCounts.get(videoId) || 0) + 1);
      }
    }

    // Write counts back to video documents in batches
    let batch = db.batch();
    let ops = 0;

    for (const [videoId, count] of videoCounts.entries()) {
      if (ops >= 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }

      const videoRef = db.collection("videos").doc(videoId);
      batch.update(videoRef, {
        impressionCount: admin.firestore.FieldValue.increment(count),
        updatedAt: Date.now(),
      });
      ops++;
    }

    if (ops > 0) {
      await batch.commit();
    }

    // Save progress cursor
    await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
    logger.info(`aggregateVideoImpressions: finished. Aggregated ${snapshot.size} impressions for ${videoCounts.size} videos.`);
  }
);

/**
 * Periodically purge raw impressions older than 7 days to manage storage costs.
 * 
 * Scheduled to run every 24 hours.
 */
export const cleanupOldImpressions = onSchedule(
  {
    schedule: "every 24 hours",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    logger.info("cleanupOldImpressions: start");
    const db = admin.firestore();

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const snapshot = await db
      .collection("impressions_raw")
      .where("timestamp", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .limit(1000)
      .get();

    if (snapshot.empty) {
      logger.info("cleanupOldImpressions: no old impressions to purge");
      return;
    }

    logger.info(`cleanupOldImpressions: purging ${snapshot.size} old raw impressions`);

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

    logger.info(`cleanupOldImpressions: purged ${snapshot.size} raw impression documents`);
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
