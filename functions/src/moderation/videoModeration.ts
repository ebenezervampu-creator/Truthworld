/**
 * 🛡️ VIDEO CONTENT MODERATION — Cloud Function (v2.0 — ZERO-FFmpeg)
 *
 * Storage-triggered function that moderates uploaded videos by sending
 * the video GCS URI directly to Gemini for Community Guidelines analysis.
 *
 * ✅ v2.0 ARCHITECTURE (Low-Latency):
 *   1. Triggered by onObjectFinalized on videos/ prefix
 *   2. Sends GCS URI directly to Gemini (NO download, NO FFmpeg, NO re-upload)
 *   3. Gemini reads the video file from GCS natively via fileData
 *   4. Writes result to videos/{videoId}.moderation
 *   5. If REJECTED → also cancels any in-progress video_jobs
 *
 * ✅ LATENCY OPTIMIZATION vs v1.0:
 *   v1.0: Download(15s) + FFmpeg(8s) + Upload(2s) + Gemini(15s) = ~40s
 *   v2.0: Gemini direct(10-20s) = ~10-20s  ← 60% FASTER
 *
 * ✅ CONFIG: memory=512MiB, timeout=60s, maxInstances=10, minInstances=1
 */

import * as admin from "firebase-admin";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin } from "../utils/auth";
import { notifyUser } from "../notifications/notifications";

const db = admin.firestore();
const REGION = "asia-south1";
const BUCKET_NAME = "truthworld-1.firebasestorage.app";

/**
 * 🛡️ Storage Trigger — Moderate uploaded videos before pipeline processing.
 *
 * v2.0: Sends video GCS URI directly to Gemini — zero intermediate steps.
 * minInstances=1 eliminates cold start for the critical moderation path.
 */
export const onVideoUploadedForModeration = onObjectFinalized(
  {
    bucket: BUCKET_NAME,
    region: REGION,
    memory: "512MiB",      // No FFmpeg needed → less memory
    timeoutSeconds: 180,    // 3min — sized for videos up to 15min (Gemini internal timeout: 120s + retries)
    minInstances: 0,        // Scale-to-zero to optimize costs
    maxInstances: 2,
  },
  async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType ?? "";
    const bucket = event.data.bucket;

    // ─── FILTER: Only process videos/ prefix ─────────────────────────────
    if (!filePath.startsWith("videos/")) {
      return;
    }

    // ─── FILTER: Only process original uploads (not resolution variants) ──
    const fileName = filePath.split("/").pop() ?? "";
    if (!fileName.startsWith("original")) {
      return; // Skip resolution variants, thumbnails, etc.
    }

    // ─── FILTER: Must be a video file ────────────────────────────────────
    if (!contentType.startsWith("video/")) {
      return;
    }

    // Extract videoId from path: videos/{videoId}/original.mp4
    const pathParts = filePath.split("/");
    if (pathParts.length < 3) {
      console.error("[VideoModeration] Unexpected path structure:", filePath);
      return;
    }

    const videoId = pathParts[1];
    console.log("[VideoModeration] Starting moderation for video:", { videoId, filePath });

    // ─── IDEMPOTENCY: Skip if already moderated ─────────────────────────
    const videoDoc = await db.collection("videos").doc(videoId).get();
    if (!videoDoc.exists) {
      console.warn("[VideoModeration] Video document not found:", videoId);
      return;
    }

    const videoData = videoDoc.data();
    const existingModeration = videoData?.moderation;
    if (existingModeration?.status === "approved" || existingModeration?.status === "rejected") {
      console.log("[VideoModeration] Already moderated, skipping:", { videoId, status: existingModeration.status });
      return;
    }

    // ─── STEP 1: Mark as moderating ──────────────────────────────────────
    await db.collection("videos").doc(videoId).update({
      "moderation.status": "processing",
      "moderation.startedAt": Date.now(),
    });

    try {
      // ─── STEP 1.5: Check if Videos Gemini AI is bypassed (Admin Only Mode) ───
      const { isVideosBypassed } = require("./moderationModes");
      const bypassed = await isVideosBypassed();
      if (bypassed) {
        console.log("[VideoModeration] Videos moderation toggle is ON (Admin Only). Bypassing Gemini AI check and routing to Admin.", { videoId });
        const now = Date.now();
        await db.collection("videos").doc(videoId).update({
          "moderation.status": "manual_review",
          "moderation.reason": "Routed to Admin for manual review (Gemini AI bypassed).",
          "moderation.topic": "pending_admin_review",
          "moderation.intent": "commentary",
          "moderation.policyAction": "manual_review",
          "moderation.riskLevel": "medium",
          "moderation.policyReason": "Routed to Admin for manual review (Gemini AI bypassed).",
          "moderation.explanation": "Automatic Gemini moderation bypassed per system settings. Held for manual admin decision.",
          "moderation.violationCategories": ["admin_manual_review_required"],
          "moderation.confidenceScore": 0,
          "moderation.summary": "Video held for Admin manual review.",
          "moderation.checkedAt": now,
          "moderation.model": "admin-manual-bypass",
          "moderation.bypassGemini": true,
          status: "pending_review",
        });

        // Add / ensure in admin_review_queue
        await db.collection("admin_review_queue").doc(videoId).set({
          jobId: videoData?.jobId || videoId,
          videoId,
          userId: videoData?.userId || videoData?.ownerId || videoData?.uploaderId || "unknown",
          queuedAt: now,
          status: "pending_review",
          reason: "Routed to Admin for manual review (Gemini AI bypassed)."
        }, { merge: true });

        // Update video_jobs moderation stage to pending_review
        const jobsSnap = await db.collection("video_jobs")
          .where("videoId", "==", videoId)
          .where("status", "in", ["accepted", "processing", "running"])
          .limit(1)
          .get();

        if (!jobsSnap.empty) {
          const jobDoc = jobsSnap.docs[0];
          await jobDoc.ref.update({
            "stages.moderation": {
              status: "pending_review",
              progress: 50,
              reason: "Routed to Admin for manual review (Gemini AI bypassed).",
              flaggedAt: now,
            },
            updatedAt: now,
          });
        }

        return;
      }

      // ─── STEP 2: Send GCS URI directly to Gemini (ZERO-FFmpeg) ─────────
      // Gemini reads the video file from GCS natively — no download needed.
      const videoGcsUri = `gs://${bucket}/${filePath}`;
      console.log("[VideoModeration] Sending GCS URI directly to Gemini:", { videoId, videoGcsUri });

      const { videoModerationService } = require("../pipeline/services/videoModerationService");
      const result = await videoModerationService.moderate(videoGcsUri, contentType);

      // ─── Determine moderation status from v3.0 policy action ──────
      const moderationStatus = result.policyAction === "manual_review"
        ? "manual_review"
        : result.approved ? "approved" : "rejected";

      const moderationData: Record<string, any> = {
        "moderation.status": moderationStatus,
        "moderation.reason": result.violationReason,
        "moderation.topic": result.topic,
        "moderation.intent": result.intent,
        "moderation.policyAction": result.policyAction,
        "moderation.riskLevel": result.riskLevel,
        "moderation.policyReason": result.policyReason,
        "moderation.explanation": result.explanation,
        "moderation.violationCategories": result.violationCategories,
        "moderation.confidenceScore": result.confidenceScore,
        "moderation.summary": result.summary,
        "moderation.processingTimeMs": result.processingTimeMs,
        "moderation.checkedAt": Date.now(),
        "moderation.model": "gemini-2.5-flash",
        "moderation.version": "v3.0-intent-aware",
        category: (result.category && result.category !== "Other")
          ? result.category
          : (videoData?.category || result.category || "Other"),
      };

      await db.collection("videos").doc(videoId).update(moderationData);

      console.log("[VideoModeration] Moderation complete", {
        videoId,
        approved: result.approved,
        reason: result.violationReason || "N/A",
        durationMs: result.processingTimeMs,
      });

      // ─── STEP 4: Route based on moderation decision ────────────────
      if (moderationStatus === "rejected") {
        // ─── REJECTED → cancel any in-progress pipeline ──────────────
        console.warn("[VideoModeration] Video REJECTED", {
          videoId,
          topic: result.topic,
          intent: result.intent,
          policyReason: result.policyReason,
        });

        // Update video status to rejected
        await db.collection("videos").doc(videoId).update({
          status: "rejected",
          rejectionReason: result.policyReason || result.violationReason,
        });

        // Cancel any in-progress video_jobs for this video
        const jobsSnap = await db.collection("video_jobs")
          .where("videoId", "==", videoId)
          .where("status", "in", ["accepted", "processing", "running"])
          .limit(1)
          .get();

        if (!jobsSnap.empty) {
          const jobDoc = jobsSnap.docs[0];
          await jobDoc.ref.update({
            status: "rejected",
            "stages.moderation": {
              status: "failed",
              reason: result.policyReason || result.violationReason,
              failedAt: Date.now(),
            },
            updatedAt: Date.now(),
          });
          console.log("[VideoModeration] Cancelled pipeline job:", jobDoc.id);
        }

        // Notify user about video rejection
        const uploaderId = videoData?.userId || videoData?.ownerId || videoData?.uploaderId;
        if (uploaderId) {
          const reason = result.policyReason || result.violationReason || "Content violates Community Guidelines";
          const title = videoData?.title && videoData?.title !== "Uploading..." ? videoData.title : "your video";
          await notifyUser({
            userId: uploaderId,
            type: "verification_result",
            severity: "priority",
            title: "Video Moderation Rejected",
            message: `Your video "${title}" was rejected: ${reason}. Please update or replace your video to comply with guidelines.`,
            actionUrl: "/studio",
            metadata: {
              videoId,
              reason,
              itemType: "video",
            },
          }).catch(err => console.error("[VideoModeration] Failed to notify user:", err));
        }

      } else if (moderationStatus === "manual_review") {
        // ─── MANUAL REVIEW → pause pipeline, await admin decision ────
        console.warn("[VideoModeration] Video sent to MANUAL REVIEW", {
          videoId,
          topic: result.topic,
          intent: result.intent,
          riskLevel: result.riskLevel,
          confidence: result.confidenceScore,
          policyReason: result.policyReason,
        });

        // Set video status to pending_review — not published, not rejected
        await db.collection("videos").doc(videoId).update({
          status: "pending_review",
        });

        // Pause the pipeline job — mark moderation stage as pending_review
        const jobsSnap = await db.collection("video_jobs")
          .where("videoId", "==", videoId)
          .where("status", "in", ["accepted", "processing", "running"])
          .limit(1)
          .get();

        if (!jobsSnap.empty) {
          const jobDoc = jobsSnap.docs[0];
          await jobDoc.ref.update({
            "stages.moderation": {
              status: "pending_review",
              progress: 50,
              reason: result.policyReason || "Flagged for manual review due to ambiguous intent.",
              topic: result.topic,
              intent: result.intent,
              riskLevel: result.riskLevel,
              confidence: result.confidenceScore,
              flaggedAt: Date.now(),
            },
            updatedAt: Date.now(),
          });
        }

      } else {
        // ─── APPROVED → update video_jobs moderation stage ───────────
        const jobsSnap = await db.collection("video_jobs")
          .where("videoId", "==", videoId)
          .limit(1)
          .get();

        if (!jobsSnap.empty) {
          const jobDoc = jobsSnap.docs[0];
          await jobDoc.ref.update({
            "stages.moderation": {
              status: "completed",
              progress: 100,
              completedAt: Date.now(),
              summary: result.summary,
              topic: result.topic,
              intent: result.intent,
            },
            updatedAt: Date.now(),
          });
        }
      }

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error("[VideoModeration] Failed:", { videoId, error: errorMsg });

      // Write error state — but DON'T reject on transient errors in v2.0
      // Instead, mark as "error" so it can be retried
      await db.collection("videos").doc(videoId).update({
        "moderation.status": "error",
        "moderation.reason": `Moderation system error: ${errorMsg}`,
        "moderation.checkedAt": Date.now(),
      }).catch((updateErr) => {
        console.error("[VideoModeration] Failed to write error state:", updateErr);
      });
    }
  }
);

/**
 * 🛡️ HTTPS Endpoint — Manually moderate a video (Approve or Reject).
 * Only accessible by authenticated administrators.
 */
export const moderateVideoManual = onRequest(
  {
    cors: true,
    region: REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    maxInstances: 2,
  },
  async (req, res) => {
    try {
      const authUser = await requireAdmin(req, res);
      if (!authUser) return; // Response is already handled by requireAdmin

      const { videoId, action, reason } = req.body;

      if (!videoId || typeof videoId !== "string") {
        res.status(400).json({ error: "Missing or invalid videoId." });
        return;
      }

      if (action !== "approve" && action !== "reject") {
        res.status(400).json({ error: "Action must be 'approve' or 'reject'." });
        return;
      }

      console.log(`[VideoModeration] Manual ${action} request for video:`, { videoId, adminUid: authUser.uid });

      const videoRef = db.collection("videos").doc(videoId);
      const videoDoc = await videoRef.get();

      if (!videoDoc.exists) {
        res.status(404).json({ error: "Video not found." });
        return;
      }

      const now = Date.now();

      if (action === "approve") {
        // Update Video doc
        await videoRef.update({
          "moderation.status": "approved",
          "moderation.reason": reason || "Manually approved by administrator.",
          "moderation.manuallyVerified": true,
          "moderation.verifiedBy": authUser.uid,
          "moderation.checkedAt": now,
          status: "published", // Resume or set status to published
        });

        // Update Job doc
        const jobsSnap = await db.collection("video_jobs")
          .where("videoId", "==", videoId)
          .limit(1)
          .get();

        if (!jobsSnap.empty) {
          const jobDoc = jobsSnap.docs[0];
          const jobData = jobDoc.data() || {};
          const executionPlan = jobData.executionPlan || {};
          const userId = jobData.userId || authUser.uid;

          await jobDoc.ref.update({
            gatewayDecision: {
              status: "APPROVED",
              confidence: 1.0,
              evaluatedAt: now,
              reviewReason: reason || "Manually approved by administrator.",
            },
            gatewayStatus: "APPROVED",
            status: "published",
            metadataComplete: true,
            publishedAt: now,
            updatedAt: now,
            "stages.moderation": {
              status: "completed",
              progress: 100,
              completedAt: now,
              summary: reason || "Manually approved by administrator.",
            },
          });

          // Resume downstream processing (Fact-checking, Dubbing, Copyright)
          try {
            const { DistributionLayer } = require("../pipeline/layers/04-distribution");
            const { AggregationLayer } = require("../pipeline/layers/09-aggregation");
            const distribution = new DistributionLayer();
            const aggregationLayer = new AggregationLayer();

            await aggregationLayer.onStageComplete(jobDoc.id, "transcription", userId, executionPlan).catch(() => {});

            await distribution.publish("copyright-processing" as any, {
              eventId: `copy_manual_${jobDoc.id}`,
              eventType: "copyright-processing" as any,
              jobId: jobDoc.id, userId,
              timestamp: now,
              data: { videoUrl: jobData.videoUrl, executionPlan },
              retryCount: 0,
              source: "admin-manual-approval"
            }).catch(() => {});

            const shouldRunCredibility = !!(
              executionPlan.enablePath1 ||
              executionPlan.enableTruthEngine ||
              executionPlan.enableCredibility ||
              executionPlan.enableFactChecking
            );

            if (shouldRunCredibility) {
              await distribution.publish("fact-processing", {
                eventId: `fact_manual_${jobDoc.id}`,
                eventType: "fact-processing",
                jobId: jobDoc.id, userId,
                timestamp: now,
                data: { executionPlan },
                retryCount: 0,
                source: "admin-manual-approval"
              }).catch(() => {});
            }
          } catch (fanoutErr) {
            console.warn("[VideoModeration] Manual approval downstream fanout error:", fanoutErr);
          }
        }

        res.status(200).json({ success: true, message: `Video approved manually.` });
      } else {
        // action === "reject"
        // 1. Delete entire Video document from Videos collection
        await videoRef.delete();

        // 2. Update Job doc & admin_review_queue doc
        const jobsSnap = await db.collection("video_jobs")
          .where("videoId", "==", videoId)
          .limit(1)
          .get();

        if (!jobsSnap.empty) {
          const jobDoc = jobsSnap.docs[0];
          await jobDoc.ref.update({
            status: "rejected",
            "stages.moderation": {
              status: "failed",
              reason: reason || "Manually rejected by administrator.",
              failedAt: now,
            },
            updatedAt: now,
          });
        }

        await db.collection("admin_review_queue").doc(videoId).delete().catch(() => {});

        // 3. Delete files from Storage (videos/{videoId}/ and thumbnails/{videoId}/)
        const bucket = admin.storage().bucket(BUCKET_NAME);
        try {
          const [files] = await bucket.getFiles({ prefix: `videos/${videoId}/` });
          for (const file of files) {
            await file.delete().catch(() => {});
            console.log(`[VideoModeration] Deleted Storage file: ${file.name}`);
          }

          const [thumbFiles] = await bucket.getFiles({ prefix: `thumbnails/${videoId}/` });
          for (const file of thumbFiles) {
            await file.delete().catch(() => {});
            console.log(`[VideoModeration] Deleted Storage thumbnail file: ${file.name}`);
          }
        } catch (storageErr) {
          console.error(`[VideoModeration] Storage deletion error:`, storageErr);
        }

        res.status(200).json({ success: true, message: `Video document deleted from videos collection and files removed from Storage.` });
      }
    } catch (err) {
      console.error("[VideoModeration] Manual moderation failed:", err);
      res.status(500).json({ error: "Internal server error.", details: String(err) });
    }
  }
);
