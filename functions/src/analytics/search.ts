import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";

/**
 * Periodically aggregate search terms from search_analytics
 * and update trending search statistics in trending_searches.
 * 
 * Scheduled to run every 60 minutes.
 */
export const aggregateTrendingSearches = onSchedule(
  {
    schedule: "every 60 minutes",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    logger.info("aggregateTrendingSearches: start");
    const db = admin.firestore();

    const metaRef = db.collection("system_meta").doc("trending_searches");
    const metaDoc = await metaRef.get();

    const lastProcessedAt: admin.firestore.Timestamp =
      metaDoc.exists && metaDoc.data()?.lastProcessedAt
        ? metaDoc.data()!.lastProcessedAt
        : admin.firestore.Timestamp.fromDate(new Date(0));

    const runStartedAt = admin.firestore.Timestamp.now();

    // Fetch new search analytics logs
    const snapshot = await db
      .collection("search_analytics")
      .where("timestamp", ">", lastProcessedAt)
      .orderBy("timestamp", "asc")
      .get();

    if (snapshot.empty) {
      logger.info("aggregateTrendingSearches: no new searches to process");
      await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
      return;
    }

    logger.info(`aggregateTrendingSearches: processing ${snapshot.size} new searches`);

    // Group counts by queryLowercase
    const termCounts = new Map<string, { term: string; count: number }>();
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const term = data.query;
      if (term && typeof term === "string") {
        const lowercase = data.queryLowercase || term.toLowerCase();
        const existing = termCounts.get(lowercase);
        if (existing) {
          existing.count += 1;
        } else {
          termCounts.set(lowercase, { term, count: 1 });
        }
      }
    }

    // Write aggregated counts back in batches
    let batch = db.batch();
    let ops = 0;

    for (const [lowercase, info] of termCounts.entries()) {
      if (ops >= 450) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }

      const docRef = db.collection("trending_searches").doc(lowercase);
      batch.set(
        docRef,
        {
          term: info.term,
          termLowercase: lowercase,
          searchCount: admin.firestore.FieldValue.increment(info.count),
          lastSearched: runStartedAt,
        },
        { merge: true }
      );
      ops++;
    }

    if (ops > 0) {
      await batch.commit();
    }

    // Update system progress cursor
    await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
    logger.info(`aggregateTrendingSearches: finished. Aggregated ${snapshot.size} events into ${termCounts.size} search terms.`);
  }
);

/**
 * Periodically purge raw search analytics logs older than 7 days.
 * 
 * Scheduled to run every 24 hours.
 */
export const cleanupOldSearchLogs = onSchedule(
  {
    schedule: "every 24 hours",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    logger.info("cleanupOldSearchLogs: start");
    const db = admin.firestore();

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const snapshot = await db
      .collection("search_analytics")
      .where("timestamp", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .limit(1000)
      .get();

    if (snapshot.empty) {
      logger.info("cleanupOldSearchLogs: no old search logs to purge");
      return;
    }

    logger.info(`cleanupOldSearchLogs: purging ${snapshot.size} old search logs`);

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

    logger.info(`cleanupOldSearchLogs: purged ${snapshot.size} search logs documents`);
  }
);
