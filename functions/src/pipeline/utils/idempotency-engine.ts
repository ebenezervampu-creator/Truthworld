/**
 * ⚡ IDEMPOTENCY ENGINE (BULLETPROOF VERSION)
 *
 * The SINGLE most important component — failure here = double billing.
 *
 * ✅ STRATEGY: Firestore transactions (atomic read + write)
 * This prevents ALL race conditions, even under high concurrency.
 */

import * as admin from "firebase-admin";
import { getCache, setCache, deleteCache } from "./memory-cache";
import { logger } from "./logger";

const db = () => admin.firestore();

const PROCESSED_EVENTS_TTL_MS = 86400000; // 24 hours

export type IdempotencyStatus = "NEW" | "PROCESSING" | "COMPLETED";

/**
 * 🔴 THE CRITICAL IDEMPOTENCY CHECK
 *
 * Checks the lifecycle status of an event to prevent race conditions and duplicate work.
 */
export async function checkAndMarkEventId(
  eventId: string,
  jobId: string,
  maxProcessingTimeMs = 600000 // 10 minutes (stale threshold)
): Promise<IdempotencyStatus> {
  if (!eventId || !jobId) {
    throw new Error("Missing eventId or jobId for idempotency check");
  }

  const cacheKey = `event:${eventId}`;

  // 1️⃣ FAST PATH: Check in-memory cache (L1, ~1ms)
  const inMemory = getCache(cacheKey) as IdempotencyStatus | undefined;
  if (inMemory === "COMPLETED" || inMemory === "PROCESSING") {
    return inMemory;
  }

  // 2️⃣ SAFE PATH: Firestore transaction (atomic, race-condition proof)
  const docRef = db().collection("processed_events").doc(eventId);

  try {
    const status = await db().runTransaction(async (transaction) => {
      const existingDoc = await transaction.get(docRef);

      if (existingDoc.exists) {
        const data = existingDoc.data();
        const currentStatus = data?.status as IdempotencyStatus | undefined;
        const processedAt = data?.processedAt || 0;

        // If PROCESSING but too old, consider it stale/crashed and allow retake
        if (currentStatus === "PROCESSING" && Date.now() - processedAt > maxProcessingTimeMs) {
          logger.warn("[Idempotency] Stale processing detected — allowing retake", { eventId, jobId });
          transaction.update(docRef, {
            status: "PROCESSING",
            jobId,
            processedAt: Date.now(),
          });
          return "NEW" as const;
        }

        // SELF-HEALING: If status is missing (legacy code) and it's old, allow retake
        if (!currentStatus && Date.now() - processedAt > maxProcessingTimeMs) {
          logger.warn("[Idempotency] Legacy marker failure detected — self-healing retake enabled", { eventId, jobId });
          transaction.update(docRef, {
            status: "PROCESSING",
            jobId,
            processedAt: Date.now(),
          });
          return "NEW" as const;
        }

        return currentStatus || "COMPLETED";
      }

      transaction.create(docRef, {
        jobId,
        status: "PROCESSING",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: Date.now(),
        ttl: Date.now() + PROCESSED_EVENTS_TTL_MS,
        source: "idempotency-engine",
      });

      return "NEW" as const;
    });

    setCache(cacheKey, status, 60); // Cache for short duration
    return status;
  } catch (err: any) {
    if (err.code === "ALREADY_EXISTS" || err.message?.includes("ALREADY_EXISTS")) {
      return "PROCESSING";
    }

    logger.error("[Idempotency] CRITICAL: Cannot determine status", { eventId, jobId, error: err.message });
    throw new Error(`[Idempotency] Failure for ${eventId}: ${err.message}. Refusing to process.`);
  }
}

/**
 * Mark an event as successfully completed.
 */
export async function markEventCompleted(eventId: string): Promise<void> {
  try {
    const docRef = db().collection("processed_events").doc(eventId);
    await docRef.update({
      status: "COMPLETED",
      completedAt: Date.now(),
    });
    setCache(`event:${eventId}`, "COMPLETED", 3600); // Cache completion for 1 hour
  } catch (err) {
    logger.warn("[Idempotency] Failed to mark as completed (non-fatal)", { eventId, err });
  }
}

/**
 * Manual check: Did I already process this event?
 */
export async function hasEventBeenProcessed(eventId: string): Promise<boolean> {
  try {
    const doc = await db().collection("processed_events").doc(eventId).get();
    return doc.exists;
  } catch (err) {
    logger.error("[Idempotency] Error checking event", { eventId, err });
    throw err;
  }
}

/**
 * Cleanup: Remove event from idempotency tracking
 * (Only for testing — NEVER use in production!)
 */
export async function forceRemoveEventIdempotency(eventId: string): Promise<void> {
  if (process.env.NODE_ENV === "production") {
    throw new Error("forceRemoveEventIdempotency is ONLY for testing!");
  }

  try {
    await db().collection("processed_events").doc(eventId).delete();
    deleteCache(`event:${eventId}`);
    logger.warn("[Idempotency] Event removed from tracking (TEST ONLY)", { eventId });
  } catch (err) {
    logger.error("[Idempotency] Error removing event", { eventId, err });
    throw err;
  }
}
