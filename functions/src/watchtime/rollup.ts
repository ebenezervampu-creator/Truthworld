import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";

/**
 * Daily rollup: Snapshots today's stats into dailyStats subcollections.
 * Runs at midnight IST (18:30 UTC previous day).
 */
export const rollupDailyStats = onSchedule(
  {
    schedule: "30 18 * * *",  // 18:30 UTC = 00:00 IST
    region: REGION,
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async () => {
    logger.info("rollupDailyStats: start");
    const db = admin.firestore();

    // Date in IST
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istDate = new Date(now.getTime() + istOffset);
    const dateKey = istDate.toISOString().split("T")[0]; // YYYY-MM-DD (legacy)
    // Readers (Flutter client & analytics cloud functions) query by dateKey in YYYY_MM_DD format
    const dateKeyUnderscored = dateKey.replace(/-/g, "_"); // YYYY_MM_DD

    try {
      // --- Per-video rollup ---
      const videoStatsSnap = await db.collection("video_stats").get();
      let batch = db.batch();
      let ops = 0;

      const channelAcc = new Map<string, { views: number; watchSeconds: number }>();

      for (const doc of videoStatsSnap.docs) {
        const videoId = doc.id;
        const stats = doc.data();

        // Read per-video geo and retention from the videos collection
        const videoDoc = await db.collection("videos").doc(videoId).get();
        const videoData = videoDoc.data() ?? {};
        const channelId = videoData.channelId ?? null;

        const dailyData = {
          date: dateKey,
          dateKey: dateKeyUnderscored,
          views: stats.totalViews ?? 0,
          totalViews: stats.totalViews ?? 0,
          totalWatchSeconds: stats.totalWatchSeconds ?? 0,
          totalWatchTimeSeconds: stats.totalWatchSeconds ?? 0,
          uniqueUsers: stats.uniqueUsers ?? 0,
          avgWatchSeconds: stats.avgWatchSeconds ?? 0,
          completionRate: stats.completionRate ?? 0,
          retentionCurve: stats.retentionCurve ?? [],
          retention: videoData.retention ?? {},
          geo: videoData.geo ?? {},
          demographics: videoData.demographics ?? {},
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Write video daily stats
        if (ops >= 490) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }

        batch.set(
          db.collection("videos").doc(videoId).collection("dailyStats").doc(dateKey),
          dailyData
        );
        ops++;

        // Also write to video_stats_daily for backward compatibility
        batch.set(
          db.collection("video_stats_daily").doc(`${videoId}_${dateKeyUnderscored}`),
          { videoId, channelId, ...dailyData }
        );
        ops++;

        // Accumulate channel stats
        if (channelId) {
          const existing = channelAcc.get(channelId) ?? { views: 0, watchSeconds: 0 };
          existing.views += stats.totalViews ?? 0;
          existing.watchSeconds += stats.totalWatchSeconds ?? 0;
          channelAcc.set(channelId, existing);
        }
      }

      // --- Per-channel rollup ---
      for (const [channelId, acc] of channelAcc) {
        if (ops >= 490) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }

        batch.set(
          db.collection("channels").doc(channelId).collection("dailyStats").doc(dateKeyUnderscored),
          {
            date: dateKey,
            dateKey: dateKeyUnderscored,
            views: acc.views,
            totalViews: acc.views,
            totalWatchSeconds: acc.watchSeconds,
            totalWatchTimeSeconds: acc.watchSeconds,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        );
        ops++;

        // Also write to channel_stats_daily for backward compatibility
        batch.set(
          db.collection("channel_stats_daily").doc(`${channelId}_${dateKeyUnderscored}`),
          {
            channelId,
            date: dateKey,
            dateKey: dateKeyUnderscored,
            views: acc.views,
            totalViews: acc.views,
            totalWatchSeconds: acc.watchSeconds,
            totalWatchTimeSeconds: acc.watchSeconds,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        );
        ops++;
      }

      if (ops > 0) await batch.commit();

      logger.info(`rollupDailyStats: done. videos=${videoStatsSnap.size} channels=${channelAcc.size} date=${dateKey}`);
    } catch (err) {
      logger.error("rollupDailyStats error", err);
    }
  }
);
