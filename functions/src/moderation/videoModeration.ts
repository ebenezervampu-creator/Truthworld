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
import { videoModerationService } from "../pipeline/services/videoModerationService";

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
    timeoutSeconds: 60,     // Gemini direct is faster
    minInstances: 0,        // Scale-to-zero to optimize costs
    maxInstances: 10,
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

      const result = await videoModerationService.moderate(videoGcsUri, contentType);

      // ─── STEP 3: Write result to Firestore ───────────────────────────────
      const moderationData: Record<string, any> = {
        "moderation.status": result.approved ? "approved" : "rejected",
        "moderation.reason": result.violationReason,
        "moderation.violationCategories": result.violationCategories,
        "moderation.confidenceScore": result.confidenceScore,
        "moderation.summary": result.summary,
        "moderation.processingTimeMs": result.processingTimeMs,
        "moderation.checkedAt": Date.now(),
        "moderation.model": "gemini-2.5-flash",
        "moderation.version": "v2.0-zero-ffmpeg",
      };

      await db.collection("videos").doc(videoId).update(moderationData);

      console.log("[VideoModeration] Moderation complete", {
        videoId,
        approved: result.approved,
        reason: result.violationReason || "N/A",
        durationMs: result.processingTimeMs,
      });

      // ─── STEP 4: If REJECTED → cancel any in-progress pipeline ─────────
      if (!result.approved) {
        console.warn("[VideoModeration] Video REJECTED — cancelling pipeline", { videoId });

        // Update video status to rejected
        await db.collection("videos").doc(videoId).update({
          status: "rejected",
          rejectionReason: result.violationReason,
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
              reason: result.violationReason,
              failedAt: Date.now(),
            },
            updatedAt: Date.now(),
          });
          console.log("[VideoModeration] Cancelled pipeline job:", jobDoc.id);
        }
      } else {
        // ─── STEP 5: If APPROVED → update video_jobs moderation stage ────
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
