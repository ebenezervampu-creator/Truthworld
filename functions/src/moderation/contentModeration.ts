/**
 * 🛡️ CONTENT MODERATION — Cloud Functions (v3.0 — Intent-Aware & Decoupled)
 *
 * Storage-triggered function that moderates uploaded media by sending
 * the media GCS URI directly to Gemini for Community Guidelines & decorum analysis.
 *
 * ⚖️ ARCHITECTURAL BOUNDARY:
 *   - CONTENT MODERATION evaluates DELIVERY & SAFETY (HOW it is said: profanity, gore, nudity, scams).
 *   - CREDIBILITY SYSTEM evaluates TRUTH & ACCURACY (WHAT is said: empirical claims, citations).
 *   - CONTENT MODERATION NEVER CENSORS OR REJECTS CONTENT FOR MISINFORMATION OR CONTROVERSIAL VIEWS.
 *
 * ✅ v2.0+ ARCHITECTURE (Low-Latency):
 *   1. Triggered by onObjectFinalized on videos/ prefix
 *   2. Sends GCS URI directly to Gemini (NO download, NO FFmpeg, NO re-upload)
 *   3. Gemini reads the video file from GCS natively via fileData
 *   4. Writes result to videos/{videoId}.moderation
 *   5. If REJECTED → also cancels any in-progress video_jobs
 *
 * ✅ CONFIG: memory=512MiB, timeout=180s, maxInstances=20, minInstances=0
 */

import * as admin from "firebase-admin";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { requireRecentAdmin } from "../utils/auth";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { PIPELINE_CONFIG } from "../pipeline/config";
import { notifyUser } from "../notifications/notifications";
import { contentModerationService } from "../pipeline/services/contentModerationService";
import { getBigQueryAnalyticsService } from "../analytics/bigqueryService";

const db = admin.firestore();
const REGION = "asia-south1";
const BUCKET_NAME = "truthworld-1.firebasestorage.app";

function getBucketName(): string {
  return "truthworld-1.firebasestorage.app";
}

/**
 * 🛡️ Storage Trigger — Moderate uploaded content before pipeline processing.
 *
 * Sends video GCS URI directly to Gemini Content Moderation — zero intermediate steps.
 * minInstances=0, maxInstances=20 absorbs high-concurrency burst uploads without queue drop.
 */
export const onContentUploadedForModeration = onObjectFinalized(
  {
    bucket: BUCKET_NAME,
    region: REGION,
    memory: "512MiB",      // No FFmpeg needed → low memory footprint
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
      console.error("[ContentModeration] Unexpected path structure:", filePath);
      return;
    }

    const videoId = pathParts[1];
    if (!videoId || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
      console.error("[ContentModeration] Invalid videoId detected:", { videoId, filePath });
      return;
    }
    console.log("[ContentModeration] Starting content moderation for media:", { videoId, filePath });

    // ─── IDEMPOTENCY: Skip if already moderated ─────────────────────────
    const videoDoc = await db.collection("videos").doc(videoId).get();
    if (!videoDoc.exists) {
      console.warn("[ContentModeration] Video document not found:", videoId);
      return;
    }

    const videoData = videoDoc.data();
    const existingModeration = videoData?.moderation;
    if (existingModeration?.status === "approved" || existingModeration?.status === "rejected") {
      console.log("[ContentModeration] Already moderated, skipping:", { videoId, status: existingModeration.status });
      return;
    }

    // ─── STEP 1: Mark as moderating ──────────────────────────────────────
    await db.collection("videos").doc(videoId).update({
      "moderation.status": "processing",
      "moderation.startedAt": Date.now(),
    });

    try {
      // ─── STEP 1.5: Check if Content Gemini AI is bypassed (Admin Only Mode) ───
      const { isVideosBypassed } = require("./moderationModes");
      const bypassed = await isVideosBypassed();
      if (bypassed) {
        console.log("[ContentModeration] Content moderation toggle is ON (Admin Only). Bypassing Gemini AI check and routing to Admin.", { videoId });
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
          "moderation.summary": "",
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

      // ─── STEP 2: Send GCS URI directly to Gemini Content Moderation ────
      const videoGcsUri = `gs://${bucket}/${filePath}`;
      console.log("[ContentModeration] Sending GCS URI directly to Gemini:", { videoId, videoGcsUri });

      let result: any = null;
      let lastErr: any = null;
      const MAX_MODERATION_ATTEMPTS = 5;

      const videoMetadata = videoDoc.data();
      const videoTitle = videoMetadata?.title || "";
      const videoDescription = videoMetadata?.description || "";
      const videoTags = Array.isArray(videoMetadata?.tags) ? videoMetadata.tags : [];

      for (let attempt = 1; attempt <= MAX_MODERATION_ATTEMPTS; attempt++) {
        try {
          result = await contentModerationService.moderate(
            videoGcsUri,
            contentType,
            { title: videoTitle, description: videoDescription, tags: videoTags }
          );
          break;
        } catch (err: any) {
          lastErr = err;
          const errMsg = String(err?.message || err);
          console.warn(`[ContentModeration] Gemini moderation attempt ${attempt}/${MAX_MODERATION_ATTEMPTS} failed for ${videoId}:`, errMsg);

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
          console.warn(`[ContentModeration] Upstream AI quota saturated for ${videoId}. Routing to review / queued retry.`);
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
            summary: "",
            processingTimeMs: 0,
          };
        } else {
          throw lastErr || new Error("Gemini content moderation failed after all attempts");
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
        "moderation.model": PIPELINE_CONFIG.GEMINI_MODELS?.moderation || "gemini-3.5-flash-lite",
        "moderation.version": "v3.0-intent-aware",
        category: (result.category && result.category !== "Other")
          ? result.category
          : (videoData?.category || result.category || "Other"),
      };

      if (result.summary && typeof result.summary === "string" && result.summary.trim().length > 15 && !/moderation timed out|video approved pending|summary unavailable/i.test(result.summary)) {
        moderationData.summary = result.summary.trim();
        moderationData.moderationSummary = result.summary.trim();
      }

      await db.collection("videos").doc(videoId).update(moderationData);

      console.log("[ContentModeration] Moderation complete", {
        videoId,
        approved: result.approved,
        reason: result.violationReason || "N/A",
        durationMs: result.processingTimeMs,
      });

      // ─── BigQuery Analytics: Content Moderation Telemetry ──────────────
      try {
        getBigQueryAnalyticsService().enqueueModerationScan({
          scan_id: `mod_scan_${videoId}_${Date.now()}`,
          timestamp: new Date().toISOString(),
          video_id: videoId,
          channel_id: videoData?.channelId || null,
          uploader_id: videoData?.userId || videoData?.ownerId || videoData?.uploaderId || null,
          moderation_status: moderationStatus,
          risk_level: result.riskLevel || null,
          confidence_score: typeof result.confidenceScore === "number" ? result.confidenceScore : null,
          policy_action: result.policyAction || null,
          violation_reason: result.violationReason || null,
          violation_categories: Array.isArray(result.violationCategories) ? result.violationCategories : null,
          detected_language: result.detectedLanguage || "en",
          model: PIPELINE_CONFIG.GEMINI_MODELS?.moderation || "gemini-3.5-flash-lite",
          processing_time_ms: typeof result.processingTimeMs === "number" ? result.processingTimeMs : null,
        });
      } catch (bqErr) {
        console.warn("[ContentModeration] Failed to enqueue moderation scan to BigQuery:", bqErr);
      }

      // ─── STEP 4: Route based on moderation decision ────────────────
      if (moderationStatus === "rejected") {
        // ─── REJECTED → cancel any in-progress pipeline ──────────────
        console.warn("[ContentModeration] Media REJECTED", {
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
          console.log("[ContentModeration] Cancelled pipeline job:", jobDoc.id);
        }

        // Notify user about rejection
        const uploaderId = videoData?.userId || videoData?.ownerId || videoData?.uploaderId;
        if (uploaderId) {
          const reason = result.policyReason || result.violationReason || "Content violates Community Guidelines";
          const title = videoData?.title && videoData?.title !== "Uploading..." ? videoData.title : "your video";
          await notifyUser({
            userId: uploaderId,
            type: "verification_result",
            severity: "priority",
            title: "Content Moderation Rejected",
            message: `Your content "${title}" was rejected: ${reason}. Please update or replace your upload to comply with guidelines.`,
            actionUrl: "/studio",
            metadata: {
              videoId,
              reason,
              itemType: "video",
            },
          }).catch(err => console.error("[ContentModeration] Failed to notify user:", err));
        }

      } else if (moderationStatus === "manual_review") {
        // ─── MANUAL REVIEW → pause pipeline, await admin decision ────
        console.warn("[ContentModeration] Media sent to MANUAL REVIEW", {
          videoId,
          topic: result.topic,
          intent: result.intent,
          riskLevel: result.riskLevel,
          confidence: result.confidenceScore,
          policyReason: result.policyReason,
        });

        const now = Date.now();

        // Set video status to pending_review — not published, not rejected
        await db.collection("videos").doc(videoId).update({
          status: "pending_review",
        });

        // Ensure in admin_review_queue so Admins can inspect and take action
        await db.collection("admin_review_queue").doc(videoId).set({
          jobId: videoData?.jobId || videoId,
          videoId,
          userId: videoData?.userId || videoData?.ownerId || videoData?.uploaderId || "unknown",
          channelId: videoData?.channelId || null,
          title: videoData?.title || "Untitled Video",
          thumbnailUrl: videoData?.thumbnailUrl || null,
          queuedAt: now,
          status: "pending_review",
          reason: result.policyReason || result.violationReason || "Flagged for manual review.",
          topic: result.topic,
          intent: result.intent,
          riskLevel: result.riskLevel,
          confidence: result.confidenceScore,
          violationCategories: result.violationCategories || [],
        }, { merge: true });

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
              flaggedAt: now,
            },
            updatedAt: now,
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
          const jobUpdates: Record<string, any> = {
            "stages.moderation": {
              status: "completed",
              progress: 100,
              completedAt: Date.now(),
              summary: result.summary,
              topic: result.topic,
              intent: result.intent,
            },
            updatedAt: Date.now(),
          };
          if (result.summary && typeof result.summary === "string" && result.summary.trim().length > 15 && !/moderation timed out|video approved pending|summary unavailable/i.test(result.summary)) {
            jobUpdates.summary = result.summary.trim();
            jobUpdates.moderationSummary = result.summary.trim();
          }
          await jobDoc.ref.update(jobUpdates);
        }
      }

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error("[ContentModeration] Failed:", { videoId, error: errorMsg });

      // Write error state with retry metadata so scheduled self-healing can recover it
      await db.collection("videos").doc(videoId).update({
        "moderation.status": "error",
        "moderation.reason": `Moderation system error: ${errorMsg}`,
        "moderation.checkedAt": Date.now(),
        "moderation.retryCount": admin.firestore.FieldValue.increment(1),
        "moderation.nextRetryAt": Date.now() + 60000, // 1 min backoff
      }).catch((updateErr) => {
        console.error("[ContentModeration] Failed to write error state:", updateErr);
      });

      throw error; // Re-throw to allow Eventarc delivery retry on transient infrastructure failures
    }
  }
);

/**
 * 🛡️ HTTPS Endpoint — Manually moderate content (Approve or Reject).
 * Only accessible by authenticated administrators.
 */
export const moderateContentManual = onRequest(
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
    applySecurityHeaders(res);
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

      console.log(`[ContentModeration] Manual ${action} request for video:`, { videoId, adminUid: authUser.uid });

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

            const { isCredibilityEnabled, isLocalizationEnabled } = require("../pipeline/types");
            const shouldRunCredibility = isCredibilityEnabled(executionPlan);
            const shouldRunLocalization = isLocalizationEnabled(executionPlan);

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
            if (shouldRunLocalization) {
              await distribution.publish("dubbing-processing", {
                eventId: `dub_manual_${jobDoc.id}`,
                eventType: "dubbing-processing",
                jobId: jobDoc.id, userId,
                timestamp: now,
                data: { videoUrl: jobData.videoUrl || "", executionPlan },
                retryCount: 0,
                source: "admin-manual-approval"
              }).catch(() => {});
            }
          } catch (fanoutErr) {
            console.warn("[ContentModeration] Manual approval downstream fanout error:", fanoutErr);
          }
        }

        // ─── BigQuery Analytics: Moderator Action (Approve) ───────────────
        try {
          getBigQueryAnalyticsService().enqueueModeratorAction({
            action_id: `mod_act_${videoId}_${now}`,
            timestamp: new Date(now).toISOString(),
            video_id: videoId,
            channel_id: videoDoc.data()?.channelId || null,
            moderator_id: authUser.uid,
            action_type: "approve",
            justification: reason || "Manually approved by administrator.",
            statutory_legal_basis: (req.body?.statutoryLegalBasis as string) || null,
          });
        } catch (bqErr) {
          console.warn("[ContentModeration] Failed to enqueue moderator approve action to BigQuery:", bqErr);
        }

        res.status(200).json({ success: true, message: `Video approved manually.` });
      } else {
        // action === "reject"
        // ─── BigQuery Analytics: Moderator Action (Reject) ───────────────
        try {
          getBigQueryAnalyticsService().enqueueModeratorAction({
            action_id: `mod_act_${videoId}_${now}`,
            timestamp: new Date(now).toISOString(),
            video_id: videoId,
            channel_id: videoDoc.data()?.channelId || null,
            moderator_id: authUser.uid,
            action_type: "reject",
            justification: reason || "Manually rejected by administrator.",
            statutory_legal_basis: (req.body?.statutoryLegalBasis as string) || null,
          });
        } catch (bqErr) {
          console.warn("[ContentModeration] Failed to enqueue moderator reject action to BigQuery:", bqErr);
        }

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
        const bucket = admin.storage().bucket(getBucketName());
        try {
          const [files] = await bucket.getFiles({ prefix: `videos/${videoId}/` });
          for (const file of files) {
            await file.delete().catch(() => {});
            console.log(`[ContentModeration] Deleted Storage file: ${file.name}`);
          }

          const [thumbFiles] = await bucket.getFiles({ prefix: `thumbnails/${videoId}/` });
          for (const file of thumbFiles) {
            await file.delete().catch(() => {});
            console.log(`[ContentModeration] Deleted Storage thumbnail file: ${file.name}`);
          }
        } catch (storageErr) {
          console.error(`[ContentModeration] Storage deletion error:`, storageErr);
        }

        res.status(200).json({ success: true, message: `Video document deleted from videos collection and files removed from Storage.` });
      }
    } catch (err) {
      console.error("[ContentModeration] Manual moderation failed:", err);
      res.status(500).json({ error: "An internal error occurred. Please try again." });
    }
  }
);

/**
 * 🔄 SCHEDULED RETRY: Self-healing worker for stranded / errored content moderations
 *
 * Scans for videos stuck in 'moderation.status' == 'error' where retryCount < 5,
 * and automatically re-executes moderation to unblock them.
 */
export const scheduledContentModerationRetry = onSchedule(
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

      console.log(`[ContentModerationRetry] Found ${erroredSnap.size} errored videos to re-process`);

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

        console.log(`[ContentModerationRetry] Retrying moderation for video ${videoId} (attempt ${retryCount + 1})`);

        await doc.ref.update({
          "moderation.status": "processing",
          "moderation.startedAt": now,
          "moderation.retryCount": admin.firestore.FieldValue.increment(1),
          "moderation.nextRetryAt": now + (retryCount + 1) * 60000,
        });

        try {
          const videoGcsUri = `gs://${getBucketName()}/${videoPath}`;
          const retryData = doc.data();
          const retryTitle = retryData?.title || "";
          const retryDescription = retryData?.description || "";
          const retryTags = Array.isArray(retryData?.tags) ? retryData.tags : [];
          const result = await contentModerationService.moderate(
            videoGcsUri,
            contentType,
            { title: retryTitle, description: retryDescription, tags: retryTags }
          );

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
            "moderation.model": PIPELINE_CONFIG.GEMINI_MODELS?.moderation || "gemini-3.5-flash-lite",
            "moderation.version": "v3.0-intent-aware",
          });

          console.log(`[ContentModerationRetry] Successfully self-healed video: ${videoId} -> ${moderationStatus}`);

          // ─── BigQuery Analytics: Moderation Scan Telemetry ──────────────
          try {
            getBigQueryAnalyticsService().enqueueModerationScan({
              scan_id: `mod_retry_${videoId}_${Date.now()}`,
              timestamp: new Date().toISOString(),
              video_id: videoId,
              channel_id: retryData?.channelId || null,
              uploader_id: retryData?.userId || retryData?.ownerId || retryData?.uploaderId || null,
              moderation_status: moderationStatus,
              risk_level: result.riskLevel || null,
              confidence_score: typeof result.confidenceScore === "number" ? result.confidenceScore : null,
              policy_action: result.policyAction || null,
              violation_reason: result.violationReason || null,
              violation_categories: Array.isArray(result.violationCategories) ? result.violationCategories : null,
              detected_language: result.detectedLanguage || "en",
              model: PIPELINE_CONFIG.GEMINI_MODELS?.moderation || "gemini-3.5-flash-lite",
              processing_time_ms: typeof result.processingTimeMs === "number" ? result.processingTimeMs : null,
            });
          } catch (bqErr) {
            console.warn("[ContentModerationRetry] Failed to enqueue moderation scan to BigQuery:", bqErr);
          }
        } catch (retryErr: any) {
          console.error(`[ContentModerationRetry] Retry failed for video ${videoId}:`, retryErr?.message || retryErr);
          await doc.ref.update({
            "moderation.status": "error",
            "moderation.reason": `Auto-retry error: ${retryErr?.message || String(retryErr)}`,
            "moderation.checkedAt": Date.now(),
          });
        }
      }

      // ─── SELF-HEAL: Clear any leaked moderation timeout / error strings in video summary ───
      try {
        const leakedSnap = await db.collection("videos")
          .where("moderation.summary", "==", "Moderation timed out — video approved pending async review.")
          .limit(20)
          .get();

        for (const leakedDoc of leakedSnap.docs) {
          const vData = leakedDoc.data();
          const cleanSummary = (vData?.summary && !vData.summary.includes("Moderation timed out"))
            ? vData.summary
            : "";
          await leakedDoc.ref.update({
            "moderation.summary": cleanSummary,
            ...(vData?.summary && vData.summary.includes("Moderation timed out") ? { summary: cleanSummary } : {}),
            ...(vData?.moderationSummary && vData.moderationSummary.includes("Moderation timed out") ? { moderationSummary: cleanSummary } : {}),
          });
          console.log(`[ContentModerationRetry] Cleaned leaked moderation summary for video ${leakedDoc.id}`);
        }
      } catch (cleanErr) {
        console.warn("[ContentModerationRetry] Leaked summary cleaner encountered an issue:", cleanErr);
      }
    } catch (err) {
      console.error("[ContentModerationRetry] Scheduled processor error:", err);
    }
  }
);

/**
 * 🔄 RESUBMIT VIDEO FOR MODERATION:
 * Callable Cloud Function allowing creators to resubmit a rejected video for moderation.
 * STRICT POLICY: Enforces a maximum of 2 resubmissions per video.
 */
export const resubmitVideoForModeration = onCall(
  {
    region: REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated to resubmit video.");
    }

    const { videoId } = request.data || {};
    if (!videoId || typeof videoId !== "string" || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
      throw new HttpsError("invalid-argument", "Valid videoId is required.");
    }

    const callerUid = request.auth.uid;
    const videoRef = db.collection("videos").doc(videoId);
    const videoDoc = await videoRef.get();

    if (!videoDoc.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }

    const videoData = videoDoc.data();
    const ownerId = videoData?.ownerId || videoData?.userId || videoData?.uploaderId;

    if (!ownerId || ownerId !== callerUid) {
      const token = request.auth.token;
      const isAdmin = token?.admin === true && token?.email_verified === true;
      if (!isAdmin) {
        throw new HttpsError("permission-denied", "Only the video owner can resubmit this video.");
      }
    }

    // Verify current status is rejected
    const currentStatus = String(videoData?.status || "").toLowerCase();
    const moderationStatus = String(videoData?.moderation?.status || "").toLowerCase();
    const isRejected = currentStatus === "rejected" ||
      moderationStatus === "rejected" ||
      videoData?.geminiApproved === false ||
      videoData?.isApproved === false;

    if (!isRejected) {
      throw new HttpsError("failed-precondition", "Only videos rejected by moderation can be resubmitted.");
    }

    // Strict 2-time maximum limit enforcement
    const currentResubmitCount = Number(videoData?.resubmitCount || videoData?.moderation?.resubmitCount || 0);
    if (currentResubmitCount >= 2) {
      throw new HttpsError("resource-exhausted", "This video has reached the maximum limit of 2 resubmissions.");
    }

    const nextCount = currentResubmitCount + 1;
    const now = Date.now();

    console.log(`[ContentModeration] Resubmitting video ${videoId} (Attempt ${nextCount} of 2) by user ${callerUid}`);

    // Update video document in Firestore
    await videoRef.update({
      status: "pending_review",
      resubmitCount: nextCount,
      resubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
      "moderation.status": "pending",
      "moderation.resubmitCount": nextCount,
      "moderation.resubmittedAt": now,
      "moderation.policyAction": "pending",
      "moderation.reason": admin.firestore.FieldValue.delete(),
      "moderation.policyReason": admin.firestore.FieldValue.delete(),
      rejectionReason: admin.firestore.FieldValue.delete(),
      geminiApproved: admin.firestore.FieldValue.delete(),
      isApproved: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update matching video_jobs document if present
    try {
      const resolvedJobId = videoData?.jobId || videoId;
      const jobDocRef = db.collection("video_jobs").doc(resolvedJobId);
      const jobSnap = await jobDocRef.get();
      if (jobSnap.exists) {
        await jobDocRef.update({
          status: "processing",
          "stages.moderation.status": "pending",
          "stages.moderation.progress": 0,
          "stages.moderation.startedAt": now,
          updatedAt: now,
        });
      }
    } catch (jobErr) {
      console.warn(`[ContentModeration] Failed to update video_jobs on resubmit:`, jobErr);
    }

    // Trigger async moderation pass
    try {
      const videoPath = videoData?.storage?.videoPath || `videos/${videoId}/original.mp4`;
      const contentType = videoData?.contentType || "video/mp4";
      const videoGcsUri = `gs://${getBucketName()}/${videoPath}`;
      const title = videoData?.title || "";
      const description = videoData?.description || "";
      const tags = Array.isArray(videoData?.tags) ? videoData.tags : [];

      contentModerationService.moderate(
        videoGcsUri,
        contentType,
        { title, description, tags }
      ).then(async (result) => {
        const modStatus = result.policyAction === "manual_review"
          ? "manual_review"
          : result.approved ? "approved" : "rejected";

        await videoRef.update({
          "moderation.status": modStatus,
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
          "moderation.model": PIPELINE_CONFIG.GEMINI_MODELS?.moderation || "gemini-3.5-flash-lite",
          "moderation.version": "v3.0-intent-aware",
          geminiApproved: result.approved,
          isApproved: result.approved,
          status: result.approved ? "ready" : (modStatus === "manual_review" ? "pending_review" : "rejected"),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`[ContentModeration] Async resubmit moderation finished for ${videoId}: ${modStatus}`);
      }).catch((asyncErr) => {
        console.warn(`[ContentModeration] Async resubmit moderation error:`, asyncErr);
      });
    } catch (triggerErr) {
      console.warn(`[ContentModeration] Triggering moderation pass warning:`, triggerErr);
    }

    return {
      success: true,
      resubmitCount: nextCount,
      remainingResubmissions: 2 - nextCount,
      message: `Video resubmitted for moderation review. (Attempt ${nextCount} of 2).`,
    };
  }
);

// ─── Manual Video Moderation (Caller Endpoint) ────────────────────────────────
export const moderateVideoManual = moderateContentManual;
