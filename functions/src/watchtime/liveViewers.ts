import * as admin from "firebase-admin";
import { onValueWritten } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";
const STALE_THRESHOLD_MS = 15_000; // 15 seconds

/**
 * RTDB Trigger: Updates concurrent viewer count when a session is written/deleted.
 * Triggered on /activeViewers/{videoId}/{sessionId}
 */
export const onActiveViewerWrite = onValueWritten(
  {
    ref: "/activeViewers/{videoId}/{sessionId}",
    region: "us-central1", // RTDB v2 triggers often require us-central1 or match the RTDB location
    memory: "256MiB",
  },
  async (event) => {
    const videoId = event.params.videoId;
    const sessionId = event.params.sessionId;
    const rtdb = admin.database();

    try {
      // Check if the session data is stale
      const afterData = event.data.after.val();
      if (afterData && afterData.updatedAt) {
        const updatedAt = typeof afterData.updatedAt === "number" ? afterData.updatedAt : Date.now();
        if (Date.now() - updatedAt > STALE_THRESHOLD_MS) {
          // Stale session — delete it
          await rtdb.ref(`activeViewers/${videoId}/${sessionId}`).remove();
          logger.info("Removed stale session", { videoId, sessionId });
          return;
        }
      }

      // Count active sessions for this video
      const viewersSnap = await rtdb.ref(`activeViewers/${videoId}`).once("value");
      const count = viewersSnap.numChildren();

      // Update per-video concurrent count
      await rtdb.ref(`liveStats/${videoId}/concurrentCount`).set(count);

      // Update global concurrent count
      const allViewersSnap = await rtdb.ref("activeViewers").once("value");
      let globalCount = 0;
      if (allViewersSnap.exists()) {
        allViewersSnap.forEach((videoSnap) => {
          globalCount += videoSnap.numChildren();
        });
      }
      await rtdb.ref("liveStats/global/concurrentCount").set(globalCount);
    } catch (err) {
      logger.error("onActiveViewerWrite error", { videoId, sessionId, error: String(err) });
    }
  }
);

/**
 * Scheduled: Cleans up stale RTDB sessions + expired viewDedup entries.
 * Runs every 1 minute.
 */
export const cleanupStaleSessions = onSchedule(
  {
    schedule: "every 1 minutes",
    region: REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async () => {
    logger.info("cleanupStaleSessions: start");
    const rtdb = admin.database();
    const db = admin.firestore();
    const now = Date.now();
    let removedSessions = 0;

    try {
      // --- RTDB: Remove stale activeViewers ---
      const allViewersSnap = await rtdb.ref("activeViewers").once("value");
      if (allViewersSnap.exists()) {
        const updates: Record<string, null> = {};
        allViewersSnap.forEach((videoSnap) => {
          videoSnap.forEach((sessionSnap) => {
            const data = sessionSnap.val();
            if (data?.updatedAt && now - data.updatedAt > STALE_THRESHOLD_MS) {
              updates[`activeViewers/${videoSnap.key}/${sessionSnap.key}`] = null;
              removedSessions++;
            }
          });
        });

        if (Object.keys(updates).length > 0) {
          await rtdb.ref().update(updates);
        }
      }

      // --- Firestore: Cleanup expired viewDedup entries ---
      const expiredSnap = await db
        .collectionGroup("fingerprints")
        .where("expiresAt", "<", admin.firestore.Timestamp.now())
        .limit(400)
        .get();

      if (!expiredSnap.empty) {
        const batch = db.batch();
        expiredSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        logger.info(`cleanupStaleSessions: deleted ${expiredSnap.size} expired dedup entries`);
      }

      // --- Update concurrent counts after cleanup ---
      const refreshedSnap = await rtdb.ref("activeViewers").once("value");
      let globalCount = 0;
      if (refreshedSnap.exists()) {
        const countUpdates: Record<string, number> = {};
        refreshedSnap.forEach((videoSnap) => {
          const count = videoSnap.numChildren();
          countUpdates[`liveStats/${videoSnap.key}/concurrentCount`] = count;
          globalCount += count;
        });
        countUpdates["liveStats/global/concurrentCount"] = globalCount;
        await rtdb.ref().update(countUpdates);
      } else {
        await rtdb.ref("liveStats/global/concurrentCount").set(0);
      }

      logger.info(`cleanupStaleSessions: removed ${removedSessions} stale sessions`);
    } catch (err) {
      logger.error("cleanupStaleSessions error", err);
    }
  }
);

/**
 * Scheduled: Aggregates live watch-time from RTDB into Firestore.
 * Runs every 1 minute.
 */
export const aggregateLiveWatchTime = onSchedule(
  {
    schedule: "every 1 minutes",
    region: REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async () => {
    logger.info("aggregateLiveWatchTime: start");
    const rtdb = admin.database();
    const db = admin.firestore();

    try {
      const snap = await rtdb.ref("activeViewers").once("value");
      if (!snap.exists()) return;

      const batch = db.batch();
      let ops = 0;

      snap.forEach((videoSnap) => {
        const videoId = videoSnap.key;
        if (!videoId) return;

        let totalLiveSeconds = 0;
        videoSnap.forEach((sessionSnap) => {
          const data = sessionSnap.val();
          if (data?.watchedSeconds) {
            totalLiveSeconds += Number(data.watchedSeconds);
          }
        });

        if (ops < 490) {
          batch.set(
            db.collection("videos").doc(videoId),
            { stats: { liveWatchSeconds: totalLiveSeconds } },
            { merge: true }
          );
          ops++;
        }
      });

      if (ops > 0) await batch.commit();
      logger.info(`aggregateLiveWatchTime: updated ${ops} videos`);
    } catch (err) {
      logger.error("aggregateLiveWatchTime error", err);
    }
  }
);
