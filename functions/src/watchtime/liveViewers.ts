import * as admin from "firebase-admin";
import { onValueWritten } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";
const STALE_THRESHOLD_MS = 60_000; // 60 seconds buffer

/**
 * RTDB Trigger: Updates concurrent viewer count when a session is created or deleted.
 * Triggered on /activeViewers/{videoId}/{sessionId}
 */
export const onActiveViewerWrite = onValueWritten(
  {
    ref: "/activeViewers/{videoId}/{sessionId}",
    region: "asia-southeast1", // Must match RTDB instance region
    memory: "256MiB",
  },
  async (event) => {
    const videoId = event.params.videoId;
    const sessionId = event.params.sessionId;
    const rtdb = admin.database();

    try {
      const beforeExists = event.data.before.exists();
      const afterExists = event.data.after.exists();

      // COST & SCALE GUARD: Heartbeat updates occur every 8s per viewer.
      // If the session existed before and still exists after, viewer count is unchanged.
      // Exit immediately to prevent O(N^2) Cloud Function executions and bandwidth exhaustion.
      if (beforeExists && afterExists) {
        return;
      }

      // Check if the session data is stale on delete/cleanup
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

      // Count active sessions for this specific video only
      const viewersSnap = await rtdb.ref(`activeViewers/${videoId}`).once("value");
      const count = viewersSnap.numChildren();

      // Update per-video concurrent count
      await rtdb.ref(`liveStats/${videoId}/concurrentCount`).set(count);
    } catch (err) {
      logger.error("onActiveViewerWrite error", { videoId, sessionId, error: String(err) });
    }
  }
);

/**
 * Scheduled: Cleans up stale RTDB sessions + expired viewDedup entries.
 * Runs every 10 minutes (optimized from 1m to save 90% execution invocations).
 */
export const cleanupStaleSessions = onSchedule(
  {
    schedule: "every 10 minutes",
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

