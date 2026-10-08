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
import { onSchedule } from "firebase-functions/v2/scheduler";
import { requireRecentAdmin } from "../utils/auth";
import { PIPELINE_CONFIG } from "../pipeline/config";
import { notifyUser } from "../notifications/notifications";

const db = admin.firestore();
const REGION = "asia-south1";
const BUCKET_NAME = "truthworld-1.firebasestorage.app";

/**
 * 🛡️ Storage Trigger — Moderate uploaded videos before pipeline processing.
 *
 * v2.0: Sends video GCS URI directly to Gemini — zero intermediate steps.
 * minInstances=0, maxInstances=10 absorbs high-concurrency burst uploads without queue drop.
 */
export const onVideoUploadedForModeration = onObjectFinalized(
  {
    bucket: BUCKET_NAME,
    region: REGION,
    memory: "512MiB",      // No FFmpeg needed → less memory
    timeoutSeconds: 180,    // 3min — sized for videos up to 15min (Gemini internal timeout: 120s + retries)
    minInstances: 0,        // Scale-to-zero to optimize costs
    maxInstances: 20,       // Scale up to 20 instances to handle burst uploads without queue drop
    retry: true,            // Auto-retry transient delivery failures
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
    if (!videoId || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
      console.error("[VideoModeration] Invalid videoId detected:", { videoId, filePath });
      return;
    }
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
      let result: any = null;
      let lastErr: any = null;
      const MAX_MODERATION_ATTEMPTS = 5;

      for (let attempt = 1; attempt <= MAX_MODERATION_ATTEMPTS; attempt++) {
        try {
          result = await videoModerationService.moderate(videoGcsUri, contentType);
          break;
        } catch (err: any) {
          lastErr = err;
          const errMsg = String(err?.message || err);
          console.warn(`[VideoModeration] Gemini moderation attempt ${attempt}/${MAX_MODERATION_ATTEMPTS} failed for ${videoId}:`, errMsg);

          if (attempt < MAX_MODERATION_ATTEMPTS) {
            // Full jitter exponential backoff: base 1000ms * 2^(attempt - 1) + jitter [0..1000ms]
            const baseDelay = Math.min(1000 * Math.pow(2, attempt - 1), 16000);
            const jitter = Math.floor(Math.random() * 1000);
            const delay = baseDelay + jitter;
            await new Promise((res) => setTimeout(res, delay));
          }
        }
      }

      if (!result) {
        const errMsg = String(lastErr?.message || lastErr);
        const isQuotaOrRateLimit = /429|resource_exhausted|quota|overloaded|unavailable|503/i.test(errMsg);
        if (isQuotaOrRateLimit) {
          // Graceful degradation: never reject innocent creators due to upstream cloud vendor quota/rate limits
          console.warn(`[VideoModeration] Upstream AI quota saturated for ${videoId}. Routing to review / queued retry.`);
          result = {
            approved: false,
            topic: "pending_quota_recovery",
            intent: "commentary",
            policyAction: "manual_review",
            riskLevel: "medium",
            confidenceScore: 0.5,
            policyReason: "Automated scan temporarily delayed due to platform peak load. Scheduled for verification review.",
            explanation: "Vertex AI quota temporarily saturated; queued for graceful admin review or automatic background retry.",
            violationReason: "Temporarily held for review during peak traffic.",
            violationCategories: ["quota_backpressure_queued"],
            summary: "Video verification in progress. Content held safely in review queue.",
            processingTimeMs: 0,
          };
        } else {
          throw lastErr || new Error("Gemini moderation failed after all attempts");
        }
      }

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
        "moderation.detectedLanguage": result.detectedLanguage || "en",
        "moderation.processingTimeMs": result.processingTimeMs,
        "moderation.checkedAt": Date.now(),
        "moderation.model": PIPELINE_CONFIG.GEMINI_MODELS?.moderation || PIPELINE_CONFIG.GEMINI_MODELS?.synthesis || "gemini-3.1-flash-lite",
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

      // Write error state with retry metadata so scheduled self-healing can recover it
      await db.collection("videos").doc(videoId).update({
        "moderation.status": "error",
        "moderation.reason": `Moderation system error: ${errorMsg}`,
        "moderation.checkedAt": Date.now(),
        "moderation.retryCount": admin.firestore.FieldValue.increment(1),
        "moderation.nextRetryAt": Date.now() + 60000, // 1 min backoff
      }).catch((updateErr) => {
        console.error("[VideoModeration] Failed to write error state:", updateErr);
      });

      throw error; // Re-throw to allow Eventarc delivery retry on transient infrastructure failures
    }
  }
);

/**
 * 🛡️ HTTPS Endpoint — Manually moderate a video (Approve or Reject).
 * Only accessible by authenticated administrators.
 */
export const moderateVideoManual = onRequest(
  {
    cors: [
      "https://admin.truthworld.in",
      "https://admin.truthworld.app",
      "https://truthworld.in",
      "http://localhost:5173",
    ],
    region: REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (req, res) => {
    try {
      const authUser = await requireRecentAdmin(req, res, 3600);
      if (!authUser) return; // Response is already handled by requireRecentAdmin

      const { videoId, action, reason } = req.body;

      if (!videoId || typeof videoId !== "string" || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
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
      res.status(500).json({ error: "An internal error occurred. Please try again." });
    }
  }
);

/**
 * 🔄 SCHEDULED RETRY: Self-healing worker for stranded / errored video moderations
 *
 * Scans for videos stuck in 'moderation.status' == 'error' where retryCount < 5,
 * and automatically re-executes moderation to unblock them.
 */
export const scheduledVideoModerationRetry = onSchedule(
  {
    schedule: "every 2 minutes",
    region: REGION,
    memory: "512MiB",
    timeoutSeconds: 120,
    maxInstances: 1,
  },
  async () => {
    const now = Date.now();
    try {
      const erroredSnap = await db.collection("videos")
        .where("moderation.status", "==", "error")
        .limit(10)
        .get();

      if (erroredSnap.empty) {
        return;
      }

      console.log(`[VideoModerationRetry] Found ${erroredSnap.size} errored videos to re-process`);

      for (const doc of erroredSnap.docs) {
        const videoData = doc.data();
        const videoId = doc.id;
        const retryCount = Number(videoData?.moderation?.retryCount || 0);
        const nextRetryAt = Number(videoData?.moderation?.nextRetryAt || 0);

        // Respect backoff window
        if (nextRetryAt > now) {
          continue;
        }

        if (retryCount >= 5) {
          // Escalate to manual admin review after 5 failed retries
          await doc.ref.update({
            "moderation.status": "manual_review",
            "moderation.reason": "Exceeded maximum automatic retry attempts (5). Routed to Admin for manual review.",
            "moderation.policyAction": "manual_review",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        const videoPath = videoData?.storage?.videoPath || `videos/${videoId}/original.mp4`;
        const contentType = videoData?.contentType || "video/mp4";

        console.log(`[VideoModerationRetry] Retrying moderation for video ${videoId} (attempt ${retryCount + 1})`);

        await doc.ref.update({
          "moderation.status": "processing",
          "moderation.startedAt": now,
          "moderation.retryCount": admin.firestore.FieldValue.increment(1),
          "moderation.nextRetryAt": now + (retryCount + 1) * 60000,
        });

        try {
          const videoGcsUri = `gs://${BUCKET_NAME}/${videoPath}`;
          const { videoModerationService } = require("../pipeline/services/videoModerationService");
          const result = await videoModerationService.moderate(videoGcsUri, contentType);

          const moderationStatus = result.policyAction === "manual_review"
            ? "manual_review"
            : result.approved ? "approved" : "rejected";

          await doc.ref.update({
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
            "moderation.model": PIPELINE_CONFIG.GEMINI_MODELS?.moderation || PIPELINE_CONFIG.GEMINI_MODELS?.synthesis || "gemini-3.1-flash-lite",
            "moderation.version": "v3.0-intent-aware",
          });

          console.log(`[VideoModerationRetry] Successfully self-healed video: ${videoId} -> ${moderationStatus}`);
        } catch (retryErr: any) {
          console.error(`[VideoModerationRetry] Retry failed for video ${videoId}:`, retryErr?.message || retryErr);
          await doc.ref.update({
            "moderation.status": "error",
            "moderation.reason": `Auto-retry error: ${retryErr?.message || String(retryErr)}`,
            "moderation.checkedAt": Date.now(),
          });
        }
      }
    } catch (err) {
      console.error("[VideoModerationRetry] Scheduled processor error:", err);
    }
  }
);
