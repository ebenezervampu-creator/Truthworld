/**
 * 🛠️ COPYRIGHT CHECK TASK
 *
 * Runs as a pipeline stage after transcription completes:
 *   1. Updates stage status to 'running'
 *   2. Loads transcript and summary from Firestore
 *   3. Generates embeddings and splits transcript into 30s chunks
 *   4. Runs layered detection (MD5 → Embedding → Chunk comparison → Gemini)
 *   5. Processes matches and creates claims/holds
 *   6. Registers the video as a copyright_asset if no high-confidence violations are found
 *   7. Marks stage as 'completed' and triggers aggregation check
 */

import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import { EdgeLayer } from "../layers/01-edge";
import { aggregationLayer } from "../layers/09-aggregation";
import { fingerprintService } from "../services/fingerprintService";
import { copyrightDetectionService } from "../services/copyrightDetection";
import { copyrightClaimsService } from "../services/copyrightClaims";
import { DETECTION_THRESHOLDS } from "../services/copyrightTypes";

const db = () => admin.firestore();

export async function runCopyrightCheck(
  jobId: string,
  userId: string,
  eventId: string
): Promise<void> {
  const t0 = Date.now();
  logger.info("[CopyrightTask] Starting copyright check", { jobId, eventId });

  try {
    // 1. Mark stage as running
    await EdgeLayer.updateStageSync(jobId, "copyright", {
      status: "running",
      progress: 10,
      startedAt: Date.now(),
    });

    // 2. Fetch video and job details
    const [jobSnap, videoSnap, transcriptSnap] = await Promise.all([
      db().collection("video_jobs").doc(jobId).get(),
      db().collection("videos").doc(jobId).get(), // canonical videoId is usually same as jobId in our publish-gated model
      db().collection("transcripts").doc(jobId).get(),
    ]);

    if (!jobSnap.exists || !videoSnap.exists || !transcriptSnap.exists) {
      throw new Error(`Required documents missing for copyright check. Job: ${jobSnap.exists}, Video: ${videoSnap.exists}, Transcript: ${transcriptSnap.exists}`);
    }

    const jobData = jobSnap.data()!;
    const videoData = videoSnap.data()!;
    const transcriptData = transcriptSnap.data()!;

    const executionPlan = jobData.executionPlan;
    const duration = videoData.duration || jobData.duration || transcriptData.duration || 600;
    const md5Hash = videoData.videoHash || null;
    const transcript = transcriptData.text || "";
    const summary = jobData.outputs?.summary || videoData.summary || transcriptData.summary || transcript.slice(0, 2000);
    const utterances = transcriptData.utterances || [];

    await EdgeLayer.updateStageSync(jobId, "copyright", {
      status: "running",
      progress: 30,
    });

    // 3. Generate fingerprints for this video
    const fingerprints = await fingerprintService.generateFingerprints({
      transcript,
      summary,
      duration,
      md5Hash,
      utterances,
    });

    await EdgeLayer.updateStageSync(jobId, "copyright", {
      status: "running",
      progress: 60,
    });

    // 4. Run detection pipeline
    const detectionResult = await copyrightDetectionService.detectCopyright({
      videoId: jobId,
      ownerId: userId,
      channelId: jobData.channelId || "",
      md5Hash,
      transcript,
      summary,
      duration,
      utterances,
      summaryEmbedding: fingerprints.summaryEmbedding,
      transcriptHash: fingerprints.transcriptHash,
      chunks: fingerprints.chunks,
    });

    await EdgeLayer.updateStageSync(jobId, "copyright", {
      status: "running",
      progress: 80,
    });

    let highConfidenceViolation = false;

    // 5. If matches found, process them and create claims
    if (detectionResult.hasMatch && detectionResult.matches.length > 0) {
      logger.info("[CopyrightTask] Matches found — creating claims", {
        jobId,
        matchCount: detectionResult.matches.length,
      });

      for (const match of detectionResult.matches) {
        if (match.finalConfidence >= DETECTION_THRESHOLDS.AUTO_CLAIM) {
          highConfidenceViolation = true;
        }

        // Get details of original asset to retrieve its transcript for analysis
        const origAssetSnap = await db().collection("copyright_assets").doc(match.assetId).get();
        if (origAssetSnap.exists) {
          const origAsset = origAssetSnap.data()!;
          const origTranscriptSnap = await db().collection("transcripts").doc(origAsset.originalVideoId).get();
          const origTranscript = origTranscriptSnap.exists ? origTranscriptSnap.data()?.text || "" : "";

          await copyrightClaimsService.processMatchAndCreateClaim(
            match,
            transcript,
            origTranscript,
            origAsset.videoTitle || "Original Video",
            origAsset.videoTitle || ""
          );
        }
      }
    }

    // 6. Register as copyright_asset to protect it in the future
    // ONLY register if there are no high-confidence violations (we don't want to register stolen content)
    if (!highConfidenceViolation) {
      logger.info("[CopyrightTask] No high-confidence violations — registering asset", { jobId });
      await fingerprintService.registerAsset({
        videoId: jobId,
        ownerId: userId,
        channelId: jobData.channelId || "",
        videoTitle: videoData.title || "Protected Content",
        videoDuration: duration,
        md5Hash,
        transcript,
        summary,
        utterances,
        protectionLevel: "standard",
        allowFairUse: true,
        claimPolicy: "track_only",
      });
    } else {
      logger.warn("[CopyrightTask] High-confidence violations found — skipping copyright registration", { jobId });
    }

    // 7. Complete stage and trigger aggregation
    await EdgeLayer.updateStageSync(jobId, "copyright", {
      status: "completed",
      progress: 100,
      completedAt: Date.now(),
    });

    // Notify aggregation layer
    await aggregationLayer.onStageComplete(
      jobId,
      "copyright" as any,
      userId,
      executionPlan,
      eventId
    );

    logger.info("[CopyrightTask] Copyright check completed successfully", {
      jobId,
      durationMs: Date.now() - t0,
    });
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    logger.error("[CopyrightTask] Failed copyright check", { jobId, error: errorMsg });

    // Fall back to skipped/completed to ensure pipeline is non-blocking
    await EdgeLayer.updateStageSync(jobId, "copyright", {
      status: "failed",
      progress: 100,
      completedAt: Date.now(),
      error: errorMsg,
    });

    // Notify aggregation layer so the job can finish
    const jobSnap = await db().collection("video_jobs").doc(jobId).get();
    if (jobSnap.exists) {
      const executionPlan = jobSnap.data()!.executionPlan;
      await aggregationLayer.onStageComplete(
        jobId,
        "copyright" as any,
        userId,
        executionPlan,
        eventId
      );
    }
  }
}
