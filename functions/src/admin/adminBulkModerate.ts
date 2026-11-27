import { applySecurityHeaders } from "../utils/securityHeaders";
import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireRecentAdmin } from "../utils/auth";
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
    applySecurityHeaders(res);
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
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

      if (itemIds.length > 200) {
        res.status(400).json({ error: "Batch size exceeds maximum limit of 200 items per request" });
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
            return { id, success: false, error: "Failed to process item moderation." };
          }
        })
      );

      const mappedResults = results.map((r, index) => {
        if (r.status === "fulfilled") {
            return r.value;
        } else {
            return { id: itemIds[index], success: false, error: "Failed to process item moderation." };
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
      res.status(500).json({ error: "Unable to process bulk moderation request. Please try again." });
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

async function cancelSpeculativeJobsForVideo(videoId: string, jobId: string, reason: string, now: number) {
  const db = admin.firestore();
  const activeStatuses = ["pending", "accepted", "processing", "running"];
  const collections = ["video_jobs", "credibility_jobs", "dubbing_jobs"];
  const batch = db.batch();
  let hasUpdates = false;

  for (const col of collections) {
    const byVideo = await db.collection(col)
      .where("videoId", "==", videoId)
      .where("status", "in", activeStatuses)
      .get();

    for (const doc of byVideo.docs) {
      const updatePayload: Record<string, any> = {
        status: "rejected",
        rejectionReason: reason || "Rejected by Admin Bulk Review",
        updatedAt: now,
      };
      if (col === "video_jobs") {
        updatePayload["stages.moderation"] = {
          status: "failed",
          reason: reason || "Rejected by Admin Bulk Review",
          failedAt: now,
        };
      }
      batch.update(doc.ref, updatePayload);
      hasUpdates = true;
    }

    if (jobId && jobId !== videoId) {
      const byJobRef = db.collection(col).doc(jobId);
      const byJobSnap = await byJobRef.get();
      if (byJobSnap.exists && activeStatuses.includes(String(byJobSnap.data()?.status || ""))) {
        batch.update(byJobRef, {
          status: "rejected",
          rejectionReason: reason || "Rejected by Admin Bulk Review",
          updatedAt: now,
        });
        hasUpdates = true;
      }
    }
  }

  if (hasUpdates) {
    await batch.commit();
  }
}

async function processVideo(id: string, action: string, reason: string) {
  const db = admin.firestore();
  const status = action === "approve" ? "approved" : "rejected";
  const now = Date.now();

  // Resolve both jobId and videoId since callers may pass either.
  let jobId = id;
  let videoId = id;
  let jobSnap = await db.collection("video_jobs").doc(id).get();
  if (jobSnap.exists) {
    videoId = String(jobSnap.data()?.videoId || id);
  } else {
    const byVideo = await db.collection("video_jobs").where("videoId", "==", id).limit(1).get();
    if (!byVideo.empty) {
      jobSnap = byVideo.docs[0];
      jobId = jobSnap.id;
    }
  }

  const batch = db.batch();
  const videoJobRef = db.collection("video_jobs").doc(jobId);
  const videoRef = db.collection("videos").doc(videoId);
  const reviewQueueRef = db.collection("admin_review_queue").doc(videoId);

  if (action === "approve") {
    if (jobSnap.exists) {
      batch.update(videoJobRef, {
        status,
        adminReason: reason,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        gatewayStatus: "APPROVED",
        "gatewayDecision.status": "APPROVED",
        "gatewayDecision.reviewReason": reason || "Approved by Admin Bulk Review",
        "stages.moderation.status": "completed",
        "stages.moderation.progress": 100,
        "stages.moderation.completedAt": now,
        updatedAt: now,
      });
    }

    const videoSnap = await videoRef.get();
    if (videoSnap.exists) {
      const videoData = videoSnap.data() || {};
      const videoUpdates: Record<string, any> = {
        "moderation.status": "approved",
        "moderation.policyAction": "allow",
        "moderation.reason": reason || "Approved by Admin Bulk Review",
        "moderation.reviewedByAdmin": true,
        "moderation.checkedAt": now,
        isModerated: true,
        updatedAt: now,
      };
      if (videoData.status === "pending_review") {
        videoUpdates.status = jobSnap.exists && jobSnap.data()?.status === "completed" ? "published" : "processing";
      }
      batch.update(videoRef, videoUpdates);
    }

    batch.delete(reviewQueueRef);
    await batch.commit();

    try {
      const freshJobSnap = await videoJobRef.get();
      if (freshJobSnap.exists) {
        const jobData = freshJobSnap.data() || {};
        const executionPlan = jobData.executionPlan || {};
        const userId = jobData.userId || "system";
        const { DistributionLayer } = require("../pipeline/layers/04-distribution");
        const { AggregationLayer } = require("../pipeline/layers/09-aggregation");
        const distribution = new DistributionLayer();
        const aggregationLayer = new AggregationLayer();

        await aggregationLayer.onStageComplete(jobId, "transcription", userId, executionPlan).catch(() => {});

        await distribution.publish("copyright.requested" as any, {
          eventId: `copy_bulk_${jobId}`,
          eventType: "copyright.requested" as any,
          jobId,
          userId,
          timestamp: now,
          data: { videoUrl: jobData.videoUrl, executionPlan },
          retryCount: 0,
          source: "admin-bulk-approval",
        }).catch(() => {});

        const { isCredibilityEnabled, isLocalizationEnabled } = require("../pipeline/types");
        const shouldRunCredibility = isCredibilityEnabled(executionPlan);
        const shouldRunLocalization = isLocalizationEnabled(executionPlan);

        if (shouldRunCredibility) {
          await distribution.publish("factcheck.requested" as any, {
            eventId: `fact_bulk_${jobId}`,
            eventType: "factcheck.requested" as any,
            jobId,
            userId,
            timestamp: now,
            data: { videoUrl: jobData.videoUrl || "", executionPlan },
            retryCount: 0,
            source: "admin-bulk-approval",
          }).catch(() => {});
        }
        if (shouldRunLocalization) {
          await distribution.publish("dubbing.requested" as any, {
            eventId: `dub_bulk_${jobId}`,
            eventType: "dubbing.requested" as any,
            jobId,
            userId,
            timestamp: now,
            data: { videoUrl: jobData.videoUrl || "", executionPlan },
            retryCount: 0,
            source: "admin-bulk-approval",
          }).catch(() => {});
        }
      }
    } catch (err) {
      logger.warn(`[adminBulkModerate] Fanout error for job ${jobId}:`, err);
    }
  } else {
    // action === "reject"
    await cancelSpeculativeJobsForVideo(videoId, jobId, reason, now);
    if (jobSnap.exists) {
      batch.update(videoJobRef, {
        status,
        adminReason: reason,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: now,
      });
    }
    batch.delete(videoRef);
    batch.delete(reviewQueueRef);
    await batch.commit();

    // Delete files from Storage with structured async handling
    const bucket = admin.storage().bucket();
    const deleteFiles = async (prefix: string) => {
      try {
        const [files] = await bucket.getFiles({ prefix });
        await Promise.allSettled(files.map((f) => f.delete()));
      } catch (err) {
        logger.warn(`[adminBulkModerate] Storage delete error for prefix ${prefix}:`, err);
      }
    };
    await Promise.allSettled([
      deleteFiles(`videos/${videoId}/`),
      deleteFiles(`thumbnails/${videoId}/`),
    ]);
  }
}
