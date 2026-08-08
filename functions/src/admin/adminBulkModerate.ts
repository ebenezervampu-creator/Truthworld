import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin } from "../utils/auth";
import { logger } from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const adminBulkModerate = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { contentType, action, itemIds, reason } = req.body;
      if (!contentType || !action || !itemIds || !Array.isArray(itemIds)) {
        res.status(400).json({ error: "Missing required fields or invalid itemIds" });
        return;
      }

      if (itemIds.length === 0) {
        res.status(200).json({ results: [] });
        return;
      }

      const results = await Promise.allSettled(
        itemIds.map(async (id: string) => {
          try {
            if (contentType === "images") {
              await processImage(id, action, reason);
            } else if (contentType === "videos") {
              await processVideo(id, action, reason);
            } else {
              throw new Error("Invalid content type");
            }
            return { id, success: true };
          } catch (e: any) {
            return { id, success: false, error: e.message };
          }
        })
      );

      const mappedResults = results.map((r, index) => {
        if (r.status === "fulfilled") {
            return r.value;
        } else {
            return { id: itemIds[index], success: false, error: r.reason };
        }
      });

      // Write batch audit log
      await admin.firestore().collection("admin_actions_log").add({
        adminId: adminUser.uid,
        action: `bulk_${action}_${contentType}`,
        itemCount: itemIds.length,
        reason: reason || "Bulk action",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).json({ results: mappedResults });
    } catch (error) {
      logger.error("[adminBulkModerate] Error:", error);
      res.status(500).json({ error: error instanceof Error ? error.message : "Internal error" });
    }
  }
);

async function processImage(id: string, action: string, reason: string) {
  const status = action === "approve" ? "approved" : "rejected";
  
  const batch = admin.firestore().batch();
  
  const imgReviewRef = admin.firestore().collection("flagged_images_review").doc(id);
  batch.update(imgReviewRef, { status, adminReason: reason, reviewedAt: admin.firestore.FieldValue.serverTimestamp() });

  const imgVerifRef = admin.firestore().collection("image_verification").doc(id);
  batch.update(imgVerifRef, { status, reviewedAt: admin.firestore.FieldValue.serverTimestamp() });
  
  await batch.commit();
}

async function processVideo(id: string, action: string, reason: string) {
  const status = action === "approve" ? "approved" : "rejected";
  const now = Date.now();
  
  const batch = admin.firestore().batch();
  
  const videoJobRef = admin.firestore().collection("video_jobs").doc(id);
  batch.update(videoJobRef, { status, adminReason: reason, reviewedAt: admin.firestore.FieldValue.serverTimestamp() });

  if (action === "approve") {
    batch.update(videoJobRef, {
      gatewayStatus: "APPROVED",
      "gatewayDecision.status": "APPROVED",
      "gatewayDecision.reviewReason": reason || "Approved by Admin Bulk Review",
      "stages.moderation.status": "completed",
      "stages.moderation.progress": 100,
      "stages.moderation.completedAt": now,
      updatedAt: now,
    });
  } else {
    // action === "reject"
    // Delete video doc from videos collection
    const videoRef = admin.firestore().collection("videos").doc(id);
    batch.delete(videoRef);
    const reviewQueueRef = admin.firestore().collection("admin_review_queue").doc(id);
    batch.delete(reviewQueueRef);

    // Delete files from Storage
    const bucket = admin.storage().bucket();
    bucket.getFiles({ prefix: `videos/${id}/` }).then(([files]) => {
      files.forEach(f => f.delete().catch(() => {}));
    }).catch(() => {});
    bucket.getFiles({ prefix: `thumbnails/${id}/` }).then(([files]) => {
      files.forEach(f => f.delete().catch(() => {}));
    }).catch(() => {});
  }

  await batch.commit();

  if (action === "approve") {
    try {
      const jobSnap = await videoJobRef.get();
      if (jobSnap.exists) {
        const jobData = jobSnap.data() || {};
        const executionPlan = jobData.executionPlan || {};
        const userId = jobData.userId || "system";
        const { DistributionLayer } = require("../pipeline/layers/04-distribution");
        const { AggregationLayer } = require("../pipeline/layers/09-aggregation");
        const distribution = new DistributionLayer();
        const aggregationLayer = new AggregationLayer();

        await aggregationLayer.onStageComplete(id, "transcription", userId, executionPlan).catch(() => {});

        await distribution.publish("copyright-processing" as any, {
          eventId: `copy_bulk_${id}`,
          eventType: "copyright-processing" as any,
          jobId: id, userId,
          timestamp: now,
          data: { videoUrl: jobData.videoUrl, executionPlan },
          retryCount: 0,
          source: "admin-bulk-approval"
        }).catch(() => {});

        const shouldRunCredibility = !!(
          executionPlan.enablePath1 ||
          executionPlan.enableTruthEngine ||
          executionPlan.enableCredibility ||
          executionPlan.enableFactChecking
        );

        if (shouldRunCredibility) {
          await distribution.publish("fact-processing", {
            eventId: `fact_bulk_${id}`,
            eventType: "fact-processing",
            jobId: id, userId,
            timestamp: now,
            data: { executionPlan },
            retryCount: 0,
            source: "admin-bulk-approval"
          }).catch(() => {});
        }
      }
    } catch (err) {
      logger.warn(`[adminBulkModerate] Fanout error for job ${id}:`, err);
    }
  }
}
