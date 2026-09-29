/**
 * 🔧 ADMIN HTTP ENDPOINTS FOR SCHEDULED PUBLISHING
 *
 * Purpose:
 *   - Manual trigger for testing (without waiting for Cloud Scheduler)
 *   - Status checks for debugging
 *   - Admin diagnostics
 *
 * Security:
 *   - Requires Firebase Auth + admin claim
 *   - All requests are logged
 */

import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../pipeline/utils/logger";
import { requireAdmin, requireRecentAdmin } from "../utils/auth";

const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;

// ─────────────────────────────────────────────────────────────────────────────
// ENDPOINT 1: MANUAL TRIGGER
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Manually trigger scheduled publishing (for testing)
 *
 * POST /api/admin/publish/trigger
 */
export const manualTriggerPublishing = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
      if (!adminUser) return;
      const uid = adminUser.uid;

      logger.info(
        "manualTriggerPublishing",
        `Triggered by admin ${uid}`
      );

      const { PubSub } = require("@google-cloud/pubsub");
      const pubsub = new PubSub();
      const topic = pubsub.topic("scheduled-publishing");

      const messageId = await topic.publishMessage({
        json: {
          triggeredAt: new Date().toISOString(),
          triggeredBy: uid,
          manual: true,
        },
      });

      logger.info(
        "manualTriggerPublishing",
        `Message published: ${messageId}`
      );

      res.status(200).json({
        status: "success",
        message: "Scheduled publishing check triggered",
        messageId,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error("manualTriggerPublishing", `Error: ${error}`);
      res.status(500).json({
        status: "error",
        error: "Unable to trigger scheduled publishing check. Please try again.",
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// ENDPOINT 2: GET SCHEDULED VIDEOS (STATUS)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Get all videos currently scheduled for publishing
 *
 * GET /api/admin/publish/scheduled
 */
export const getScheduledVideos = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;
      const uid = adminUser.uid;

      logger.debug("getScheduledVideos", `Queried by admin ${uid}`);

      const now = Timestamp.now();

      // Get upcoming scheduled videos
      const snapshot = await db
        .collectionGroup("videos")
        .where("status", "==", "scheduled")
        .orderBy("scheduledTime", "asc")
        .limit(50)
        .get();

      const videos = snapshot.docs.map((doc) => ({
        id: doc.id,
        title: (doc.data() as any).title,
        ownerId: (doc.data() as any).ownerId,
        scheduledTime: (doc.data() as any).scheduledTime?.toDate?.()?.toISOString(),
        isDue:
          ((doc.data() as any).scheduledTime?.toMillis?.() || 0) <= now.toMillis(),
        createdAt: (doc.data() as any).uploadedAt?.toDate?.()?.toISOString(),
      }));

      const dueVideos = videos.filter((v) => v.isDue);
      const upcomingVideos = videos.filter((v) => !v.isDue);

      res.status(200).json({
        status: "success",
        summary: {
          total: videos.length,
          due: dueVideos.length,
          upcoming: upcomingVideos.length,
        },
        due: dueVideos,
        upcoming: upcomingVideos.slice(0, 10), // Show next 10 upcoming
      });
    } catch (error) {
      logger.error("getScheduledVideos", `Error: ${error}`);
      res.status(500).json({
        status: "error",
        error: "Unable to retrieve scheduled videos. Please try again.",
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// ENDPOINT 3: PUBLISH SINGLE VIDEO (DEBUG)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Manually publish a single video immediately (admin only, for testing)
 *
 * POST /api/admin/publish/video/{videoId}
 */
export const publishSingleVideo = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
      if (!adminUser) return;
      const uid = adminUser.uid;

      const videoId = req.path.split("/").pop();
      if (!videoId) {
        res.status(400).json({
          status: "error",
          error: "Video ID required in path",
        });
        return;
      }

      logger.info("publishSingleVideo", `Admin ${uid} requesting publish for ${videoId}`);

      // Find the video
      const querySnapshot = await db
        .collectionGroup("videos")
        .where("id", "==", videoId)
        .limit(1)
        .get();

      if (querySnapshot.empty) {
        res.status(404).json({
          status: "error",
          error: `Video ${videoId} not found`,
        });
        return;
      }

      const doc = querySnapshot.docs[0];
      const videoData = doc.data() as any;

      if (videoData.status !== "scheduled") {
        res.status(400).json({
          status: "error",
          error: `Video status is '${videoData.status}', not 'scheduled'`,
        });
        return;
      }

      // Publish the video
      await doc.ref.update({
        status: "published",
        publishedAt: Timestamp.now(),
        manualPublishBy: uid,
      });

      logger.info(
        "publishSingleVideo",
        `Video ${videoId} published manually by ${uid}`
      );

      res.status(200).json({
        status: "success",
        videoId,
        previousStatus: videoData.status,
        newStatus: "published",
        message: "Video published and pipeline triggered",
      });
    } catch (error) {
      logger.error("publishSingleVideo", `Error: ${error}`);
      res.status(500).json({
        status: "error",
        error: "Unable to publish video. Please try again.",
      });
    }
  }
);
