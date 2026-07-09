/**
 * ⚡ IDEMPOTENCY ENGINE (SHARED CORE)
 *
 * Prevents double-billing and duplicate processing across all services.
 * USES: Firestore Transactions for atomic L2 check.
 */

import * as admin from "firebase-admin";
import { getCache, setCache } from "./memory-cache";
import { logger } from "./logger";

const db = admin.firestore();
const PROCESSED_EVENTS_TTL_MS = 86400000; // 24 hours

export type IdempotencyStatus = "NEW" | "PROCESSING" | "COMPLETED";

/**
 * 🔴 THE CRITICAL IDEMPOTENCY CHECK
 */
export async function checkAndMarkEventId(
  eventId: string,
  jobId: string,
  maxProcessingTimeMs = 600000 // 10 minutes
): Promise<IdempotencyStatus> {
  if (!eventId || !jobId) throw new Error("Missing idempotency keys");

  const cacheKey = `event:${eventId}`;

  // 1️⃣ L1 Cache (Memory)
  const inMemory = getCache(cacheKey) as IdempotencyStatus | undefined;
  if (inMemory === "COMPLETED" || inMemory === "PROCESSING") return inMemory;

  // 2️⃣ L2 Check (Firestore Transaction)
  const docRef = db.collection("processed_events").doc(eventId);

  try {
    const status = await db.runTransaction(async (transaction) => {
      const existingDoc = await transaction.get(docRef);

      if (existingDoc.exists) {
        const data = existingDoc.data();
        const currentStatus = (data?.status as IdempotencyStatus) || "COMPLETED";
        const processedAt = data?.processedAt || 0;

        // Self-healing for stale tasks
        if (currentStatus === "PROCESSING" && Date.now() - processedAt > maxProcessingTimeMs) {
          logger.warn("[Idempotency] Stale task detected — resetting", { eventId, jobId });
          transaction.update(docRef, { status: "PROCESSING", jobId, processedAt: Date.now() });
          return "NEW" as const;
        }

        return currentStatus;
      }

      transaction.create(docRef, {
        jobId,
        status: "PROCESSING",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: Date.now(),
        ttl: Date.now() + PROCESSED_EVENTS_TTL_MS,
      });

      return "NEW" as const;
    });

    setCache(cacheKey, status, 60);
    return status;
  } catch (err: any) {
    if (err.code === "ALREADY_EXISTS") return "PROCESSING";
    logger.error("[Idempotency] Failed check", { eventId, jobId, error: err.message });
    throw err;
  }
}

export async function markEventCompleted(eventId: string): Promise<void> {
  try {
    await db.collection("processed_events").doc(eventId).update({
      status: "COMPLETED",
      completedAt: Date.now(),
    });
    setCache(`event:${eventId}`, "COMPLETED", 3600);
  } catch (err) {
    logger.warn("[Idempotency] Failed marking completion", { eventId, err });
  }
}

/**
 * 🧹 SCHEDULED: Cleanup expired processed_events
 *
 * The `ttl` field is set on creation but Firestore doesn't auto-delete
 * based on it (requires TTL policy setup in console). This function
 * provides a reliable fallback that runs every 24 hours.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";

export const cleanupProcessedEvents = onSchedule(
  {
    schedule: "every 24 hours",
    region: "asia-south1",
    memory: "256MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const now = Date.now();
    const cutoff = now - PROCESSED_EVENTS_TTL_MS;
    let deletedCount = 0;

    // Delete in batches of 400 to stay within Firestore limits
    let hasMore = true;
    while (hasMore) {
      const expiredSnap = await db.collection("processed_events")
        .where("processedAt", "<", cutoff)
        .limit(400)
        .get();

      if (expiredSnap.empty) {
        hasMore = false;
        break;
      }

      const batch = db.batch();
      expiredSnap.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      deletedCount += expiredSnap.size;

      if (expiredSnap.size < 400) hasMore = false;
    }

    logger.info("[Idempotency] Cleanup complete", { deletedCount });
  }
);
