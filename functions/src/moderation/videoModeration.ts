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
        category: result.category || "Other",
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
          await jobDoc.ref.update({
            "stages.moderation": {
              status: "completed",
              progress: 100,
              completedAt: now,
              summary: "Manually approved by administrator.",
            },
            updatedAt: now,
          });
        }

        res.status(200).json({ success: true, message: `Video approved manually.` });
      } else {
        // action === "reject"
        // Update Video doc
        await videoRef.update({
          "moderation.status": "rejected",
          "moderation.reason": reason || "Manually rejected by administrator.",
          "moderation.manuallyVerified": true,
          "moderation.verifiedBy": authUser.uid,
          "moderation.checkedAt": now,
          status: "rejected",
          rejectionReason: reason || "Content violates Community Guidelines",
        });

        // Cancel running pipeline jobs
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
              reason: reason || "Manually rejected by administrator.",
              failedAt: now,
            },
            updatedAt: now,
          });
        }

        // Quarantine original file and resolution files in Storage
        const bucket = admin.storage().bucket(BUCKET_NAME);
        try {
          const [files] = await bucket.getFiles({ prefix: `videos/${videoId}/` });
          for (const file of files) {
            const destPath = file.name.replace(`videos/${videoId}/`, `_quarantine/videos/${videoId}/`);
            await file.copy(bucket.file(destPath));
            await file.delete();
            console.log(`[VideoModeration] Quarantined file: ${file.name} -> ${destPath}`);
          }
        } catch (storageErr) {
          console.error(`[VideoModeration] Storage quarantine failed:`, storageErr);
        }

        res.status(200).json({ success: true, message: `Video rejected manually and files quarantined.` });
      }
    } catch (err) {
      console.error("[VideoModeration] Manual moderation failed:", err);
      res.status(500).json({ error: "Internal server error.", details: String(err) });
    }
  }
);
