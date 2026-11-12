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
import { CopyrightMatch, DEFAULT_CONFIDENCE_WEIGHTS, DETECTION_THRESHOLDS } from "../services/copyrightTypes";
import { PIPELINE_CONFIG } from "../config";

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
    const [jobSnap, transcriptSnap] = await Promise.all([
      db().collection("video_jobs").doc(jobId).get(),
      db().collection("transcripts").doc(jobId).get(),
    ]);

    if (!jobSnap.exists || !transcriptSnap.exists) {
      throw new Error(`Required documents missing for copyright check. Job: ${jobSnap.exists}, Transcript: ${transcriptSnap.exists}`);
    }

    const jobData = jobSnap.data()!;
    const targetVideoId = jobData.videoId || (jobData.linkedVideoIds?.[0]) || jobId;
    const videoSnap = await db().collection("videos").doc(targetVideoId).get();

    if (!videoSnap.exists) {
      throw new Error(`Required video document missing for copyright check: ${targetVideoId}`);
    }

    const videoData = videoSnap.data()!;
    const transcriptData = transcriptSnap.data()!;

    const executionPlan = jobData.executionPlan;
    const duration = videoData.duration || jobData.duration || transcriptData.duration || 600;
    const md5Hash = videoData.videoHash || null;
    const transcript = transcriptData.text || "";
    const summary = jobData.outputs?.summary || videoData.summary || transcriptData.summary || transcript.slice(0, 2000);
    const utterances = transcriptData.utterances || [];

    // ── Pre-flagged hash match detection (from ingestion layer) ────────────────
    let highConfidenceViolation = false;

    if (videoData.copyrightHashMatch) {
      logger.info("[CopyrightTask] Pre-flagged hash match detected — creating immediate claim", { jobId });

      const { originalJobId, originalUserId: _originalUserId, md5Hash: _flaggedHash } = videoData.copyrightHashMatch;

      // Look up the original job to get its channelId and linked video info
      const origJobSnap = await db().collection("video_jobs").doc(originalJobId).get();

      if (origJobSnap.exists) {
        const origJobData = origJobSnap.data()!;
        const origVideoId = origJobData.videoId || (origJobData.linkedVideoIds?.[0]) || originalJobId;
        const origVideoSnap = await db().collection("videos").doc(origVideoId).get();

        if (origVideoSnap.exists) {
          const origVideoData = origVideoSnap.data()!;

          const matchId = `match_md5_${jobId}_${Date.now()}`;
          const preFlaggedMatch: CopyrightMatch = {
            matchId,
            assetId: origVideoId,
            matchedVideoId: targetVideoId,
            matchedOwnerId: userId,
            matchedChannelId: jobData.channelId || "",
            matchType: "exact_md5",
            matchedSegments: [],
            score: 1.0,
            signals: {
              md5: 1.0,
              summaryEmbedding: null,
              chunkEmbedding: null,
              transcriptOverlap: null,
              gemini: null,
            },
            confidenceBreakdown: {
              md5Score: 1.0,
              embeddingScore: null,
              transcriptScore: null,
              semanticScore: null,
              weights: { ...DEFAULT_CONFIDENCE_WEIGHTS },
            },
            finalConfidence: 1.0,
            detectorVersion: 1,
            embeddingModel: "text-embedding-005",
            geminiModel: PIPELINE_CONFIG.GEMINI_MODELS?.moderation || "gemini-2.5-flash",
            pipelineVersion: "1.0.0",
            status: "detected",
            claimId: null,
            detectedAt: Date.now(),
          };

          // Persist the match to copyright_matches collection
          await db().collection("copyright_matches").doc(matchId).set(preFlaggedMatch);

          // Retrieve original transcript for claim processing
          const origTranscriptSnap = await db().collection("transcripts").doc(origVideoId).get();
          const origTranscript = origTranscriptSnap.exists ? origTranscriptSnap.data()?.text || "" : "";

          await copyrightClaimsService.processMatchAndCreateClaim(
            preFlaggedMatch,
            transcript,
            origTranscript,
            origVideoData.title || "Original Video",
            origVideoData.title || ""
          );

          highConfidenceViolation = true;
        } else {
          logger.warn("[CopyrightTask] Pre-flagged match: original video not found", { jobId, origVideoId });
        }
      } else {
        logger.warn("[CopyrightTask] Pre-flagged match: original job not found", { jobId, originalJobId });
      }
    }

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
