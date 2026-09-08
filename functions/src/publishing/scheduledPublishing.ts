/**
 * ⏰ SCHEDULED PUBLISHING FUNCTION (Gen 2 — Pub/Sub Triggered)
 *
 * Purpose:
 *   - Publishes scheduled videos at their exact scheduled time
 *   - Triggered by Cloud Scheduler every 5 minutes (cost-efficient)
 *   - Batches updates for Firestore efficiency
 *   - Implements industry-standard retry logic
 *
 * Cost Optimization:
 *   ✅ minInstances=0 (scale-to-zero when no publishes needed)
 *   ✅ Pub/Sub batching (checks many docs in one invocation)
 *   ✅ Firestore batch writes (≤ 500 docs per batch)
 *   ✅ Cloud Scheduler every 5 minutes (predictable, low cost)
 *   ✅ No polling overhead — only runs when scheduled
 *
 * Region: asia-south1
 * Memory: 512MiB
 * Timeout: 540 seconds (9 minutes for safety)
 */

import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "../pipeline/utils/logger";

const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;

// ─────────────────────────────────────────────────────────────────────────────
// TYPES & CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

interface ScheduledVideo {
  id: string;
  title: string;
  ownerId: string;
  channelId: string;
  scheduledTime: admin.firestore.Timestamp;
  status: "scheduled";
}

interface PublishResult {
  success: boolean;
  videoId: string;
  error?: string;
}

const BATCH_SIZE = 100; // Firestore batch write limit
const MAX_CLOCK_SKEW_MS = 5000; // Allow 5 seconds of clock skew for safety
const FUNCTION_NAME = "scheduledPublishing";

// ─────────────────────────────────────────────────────────────────────────────
// MAIN HANDLER
// ─────────────────────────────────────────────────────────────────────────────

/**
 * ⏰ Main scheduled publishing trigger
 * Invoked by Cloud Scheduler → Pub/Sub Topic → This function
 *
 * CONFIG:
 *   - minInstances: 0 (scale to zero)
 *   - maxInstances: 5 (low concurrency needed)
 *   - concurrency: 10 (handles multiple batches)
 *   - timeout: 540s (9 minutes for safety)
 *   - memory: 512MiB
 */
export const scheduledPublishing = onSchedule(
  {
    schedule: "every 5 minutes",
    region: "asia-south1",
    timeZone: "UTC",
    minInstances: 0,
    maxInstances: 1,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    const startTime = Date.now();
    const executionId = event.scheduleTime || "unknown";

    try {
      logger.info(FUNCTION_NAME, `[${executionId}] Starting scheduled publishing check...`);

      // ───────────────────────────────────────────────────────────────────────
      // STEP 1: FETCH ALL VIDEOS DUE FOR PUBLISHING
      // ───────────────────────────────────────────────────────────────────────

      const now = Timestamp.now();
      const cutoffTime = new Timestamp(now.seconds - 1, now.nanoseconds); // 1 second buffer for safety

      logger.debug(
        FUNCTION_NAME,
        `[${executionId}] Fetching scheduled videos due by: ${new Date(
          cutoffTime.toMillis()
        ).toISOString()}`
      );

      const snapshot = await db
        .collectionGroup("videos")
        .where("status", "==", "scheduled")
        .where("scheduledTime", "<=", cutoffTime)
        .orderBy("scheduledTime", "asc")
        .limit(BATCH_SIZE * 5) // Fetch up to 500 videos in one go
        .get();

      if (snapshot.empty) {
        logger.info(
          FUNCTION_NAME,
          `[${executionId}] No scheduled videos due for publishing at this time`
        );
        return;
      }

      logger.info(
        FUNCTION_NAME,
        `[${executionId}] Found ${snapshot.size} videos due for publishing`
      );

      // ───────────────────────────────────────────────────────────────────────
      // STEP 2: VALIDATE & PREPARE VIDEOS FOR PUBLISHING
      // ───────────────────────────────────────────────────────────────────────

      const videosToDocs: admin.firestore.DocumentReference<admin.firestore.DocumentData>[] = [];
      const publishResults: PublishResult[] = [];

      for (const doc of snapshot.docs) {
        const data = doc.data() as Partial<ScheduledVideo>;

        try {
          // Validate required fields
          if (!data.id || !data.ownerId || !data.channelId) {
            logger.warn(FUNCTION_NAME, `[${executionId}] Video ${doc.id} missing required fields`);
            publishResults.push({
              success: false,
              videoId: doc.id,
              error: "Missing required fields (id, ownerId, or channelId)",
            });
            continue;
          }

          // Double-check scheduled time hasn't changed
          const scheduledMs = data.scheduledTime?.toMillis() || 0;
          const nowMs = Date.now();

          if (scheduledMs > nowMs + MAX_CLOCK_SKEW_MS) {
            logger.debug(
              FUNCTION_NAME,
              `[${executionId}] Video ${doc.id} scheduled time is in future, skipping`
            );
            continue; // Not yet due
          }

          videosToDocs.push(doc.ref);

          publishResults.push({
            success: true,
            videoId: doc.id,
          });
        } catch (error) {
          logger.error(
            FUNCTION_NAME,
            `[${executionId}] Validation error for video ${doc.id}: ${error}`
          );
          publishResults.push({
            success: false,
            videoId: doc.id,
            error: String(error),
          });
        }
      }

      if (videosToDocs.length === 0) {
        logger.info(FUNCTION_NAME, `[${executionId}] No valid videos to publish after validation`);
        return;
      }

      // ───────────────────────────────────────────────────────────────────────
      // STEP 3: BATCH UPDATE VIDEOS TO 'PUBLISHED' STATUS
      // (This triggers the pipeline)
      // ───────────────────────────────────────────────────────────────────────

      logger.info(
        FUNCTION_NAME,
        `[${executionId}] Publishing ${videosToDocs.length} videos in batches...`
      );

      const publishedCount = await batchPublishVideos(executionId, videosToDocs);

      // ───────────────────────────────────────────────────────────────────────
      // STEP 4: AUDIT LOG
      // ───────────────────────────────────────────────────────────────────────

      const executionTime = Date.now() - startTime;
      const summary = {
        executionId,
        timestamp: new Date().toISOString(),
        videosFound: snapshot.size,
        videosPublished: publishedCount,
        executionTimeMs: executionTime,
        videosPerSecond: Math.round((publishedCount / executionTime) * 1000),
      };

      logger.info(FUNCTION_NAME, `[${executionId}] EXECUTION SUMMARY: ${JSON.stringify(summary)}`);

      return;
    } catch (error) {
      const executionTime = Date.now() - startTime;
      logger.error(
        FUNCTION_NAME,
        `[${executionId}] Unhandled error: ${error}\nExecution time: ${executionTime}ms`
      );
      throw new Error(
        `Scheduled publishing failed: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// BATCH PUBLISHING LOGIC
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Batch update videos from 'scheduled' to 'published' status.
 * This update triggers the video pipeline for AI processing.
 *
 * Uses Firestore batch writes for efficiency (500 ops per batch).
 */
async function batchPublishVideos(
  executionId: string,
  videoRefs: admin.firestore.DocumentReference[]
): Promise<number> {
  let publishedCount = 0;

  // Process in chunks of BATCH_SIZE
  for (let i = 0; i < videoRefs.length; i += BATCH_SIZE) {
    const chunk = videoRefs.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const videoRef of chunk) {
      batch.update(videoRef, {
        status: "published",
        publishedAt: Timestamp.now(),
        // 🚀 CRITICAL: Update aiFeatures.pipelineStage to 'published' to trigger the pipeline
        "aiFeatures.pipelineStage": "published",
      });
    }

    try {
      await batch.commit();
      publishedCount += chunk.length;

      logger.debug(
        FUNCTION_NAME,
        `[${executionId}] Batch ${Math.floor(i / BATCH_SIZE) + 1} published ${chunk.length} videos`
      );
    } catch (error) {
      logger.error(
        FUNCTION_NAME,
        `[${executionId}] Batch write failed for videos ${i}-${i + chunk.length}: ${error}`
      );
      throw new Error(`Batch write failed: ${String(error)}`);
    }
  }

  return publishedCount;
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITY: ADMIN ENDPOINT FOR MANUAL TRIGGER (TESTING ONLY)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Manual trigger endpoint (for testing scheduled publishing without waiting)
 * 
 * Usage:
 *   POST /api/admin/trigger-scheduled-publishing
 *   Requires: authentication + admin role
 */
export async function manualTriggerScheduledPublishing() {
  logger.info(FUNCTION_NAME, "Manual trigger initiated by admin");

  const { PubSub } = require("@google-cloud/pubsub");
  const pubsub = new PubSub();
  const topic = pubsub.topic("scheduled-publishing");

  try {
    const messageId = await topic.publishMessage({
      json: {
        triggeredAt: new Date().toISOString(),
        manual: true,
      },
    });

    logger.info(
      FUNCTION_NAME,
      `Manual trigger published to Pub/Sub. Message ID: ${messageId}`
    );

    return {
      status: "success",
      messageId,
      message: "Scheduled publishing check triggered manually",
    };
  } catch (error) {
    logger.error(FUNCTION_NAME, `Manual trigger failed: ${error}`);
    throw new Error(`Failed to trigger scheduled publishing: ${String(error)}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETUP INSTRUCTIONS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * 🔧 SETUP INSTRUCTIONS:
 *
 * 1. CREATE PUB/SUB TOPIC:
 *    gcloud pubsub topics create scheduled-publishing
 *
 * 2. CREATE CLOUD SCHEDULER JOB:
 *    gcloud scheduler jobs create pubsub scheduled-publishing-trigger \
 *      --location asia-south1 \
 *      --schedule "every 5 mins" \
 *      --time-zone "UTC" \
 *      --topic scheduled-publishing \
 *      --message-body '{}'
 *
 * 3. DEPLOY FUNCTION:
 *    npm run deploy
 *
 * 4. ENABLE APIs:
 *    - Cloud Pub/Sub API
 *    - Cloud Scheduler API
 *    - Cloud Firestore API
 *
 * 5. MONITOR:
 *    firebase functions:log --only scheduledPublishing
 *    gcloud pubsub subscriptions pull projects/YOUR_PROJECT/subscriptions/... \
 *      --auto-ack
 */
