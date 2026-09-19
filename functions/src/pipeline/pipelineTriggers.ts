import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { requireAuth } from "../utils/auth";
import {
  ExecutionPlan,
  FactCompleteData,
  DubbingCompleteData,
} from "./types";
import { logger } from "./utils/logger";
import { PIPELINE_CONFIG } from "./config";

/**
 * 🪄 Trigger On-Demand AI Features for a Video
 *
 * Supports generating subtitles (e.g. Telugu, Hindi, English), dubbed audio tracks,
 * fact-checking report, AI summary, timestamped chapters, and advanced AI settings
 * anytime from Content Screen or Edit Video screen.
 */
export const triggerVideoAIFeatures = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: ["GEMINI_API_KEY", "ASSEMBLYAI_KEY"],
  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const {
        videoId,
        features = [],
        targetLanguages = ["te", "hi"],
        priorityMode = "accuracy",
        sensitiveTopics = [],
        autoChapters = true,
      } = req.body || {};

      if (!videoId) {
        res.status(400).json({ error: "Missing videoId" });
        return;
      }

      const userId = authUser.uid;
      const videoDocRef = admin.firestore().collection("videos").doc(videoId);
      const videoSnap = await videoDocRef.get();

      if (!videoSnap.exists) {
        res.status(404).json({ error: "Video not found" });
        return;
      }

      const videoData = videoSnap.data() || {};

      // Verify authorization: must be video owner (ownerId, userId, or uploaderId) or admin
      const videoOwnerId = videoData.ownerId || videoData.userId || videoData.uploaderId;
      const isOwner = videoOwnerId === userId;
      const isAdmin = authUser.isAdmin === true;

      if (!isOwner && !isAdmin) {
        res.status(403).json({ error: "Unauthorized: You do not own this video" });
        return;
      }

      const videoUrl = videoData.videoUrl || videoData.originalUrl || "";
      if (!videoUrl) {
        res.status(400).json({ error: "Video source URL is empty" });
        return;
      }

      const jobDocRef = admin.firestore().collection("video_jobs").doc(videoId);
      const jobSnap = await jobDocRef.get();
      const jobData = jobSnap.exists ? jobSnap.data() : null;

      const existingLanguages: string[] = jobData?.executionPlan?.languages || ["en"];
      const languagesSet = new Set([...existingLanguages, ...targetLanguages]);
      const combinedLanguages = Array.from(languagesSet);

      const wantSubtitles = features.includes("subtitles");
      const wantDubbing = features.includes("dubbing");
      const wantFactCheck = features.includes("factcheck");
      const wantSummary = features.includes("summary");
      const wantChapters = features.includes("chapters");

      const executionPlan: ExecutionPlan = {
        jobId: videoId,
        languages: combinedLanguages,
        primaryLanguage: videoData.language || "en",
        enablePath1: wantFactCheck || wantSummary || (jobData?.executionPlan?.enablePath1 ?? true),
        enablePath2: wantDubbing || wantSubtitles || (jobData?.executionPlan?.enablePath2 ?? true),
        enableTruthEngine: wantFactCheck || wantSummary || (jobData?.executionPlan?.enableTruthEngine ?? true),
        enableReachEngine: wantDubbing || wantSubtitles || (jobData?.executionPlan?.enableReachEngine ?? true),
        enableAuxiliary: true,
        dubbingMode: "standard",
        generateDubbing: wantDubbing,
        genLangSubs: wantSubtitles,
        generateSubtitles: wantSubtitles,
        autoChapters: wantChapters || autoChapters,
        priorityMode: priorityMode,
        sensitiveTopics: sensitiveTopics,
        channelType: jobData?.executionPlan?.channelType || "standard",
        maxClaims: 20,
        priority: "normal",
        skipCache: false,
      };

      const now = Date.now();
      const eventId = `ondemand_${videoId}_${now}`;

      await jobDocRef.set({
        jobId: videoId,
        videoId: videoId,
        userId: userId,
        channelId: videoData.channelId || userId,
        videoUrl: videoUrl,
        fileName: videoData.title || "video.mp4",
        status: "processing",
        executionPlan: executionPlan,
        updatedAt: now,
        createdAt: jobData?.createdAt || now,
        linkedVideoIds: admin.firestore.FieldValue.arrayUnion(videoId),
        stages: {
          ...(jobData?.stages || {}),
          onDemandAI: {
            status: "running",
            progress: 10,
            requestedFeatures: features,
            requestedLanguages: targetLanguages,
            startedAt: now,
          }
        }
      }, { merge: true });

      const isAlreadyPublished = videoData.status === "published" ||
        videoData.aiFeatures?.pipelineStage === "published" ||
        videoData.isPublished === true ||
        videoData.publishedAt != null;

      if (!isAlreadyPublished) {
        await videoDocRef.update({
          status: "processing",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const transcriptSnap = await admin.firestore().collection("transcripts").doc(videoId).get();
      const transcriptionCompleted = transcriptSnap.exists;

      const { DistributionLayer } = require("./layers/04-distribution");
      const distribution = new DistributionLayer();

      if (!transcriptionCompleted) {
        await distribution.publish("video-uploaded", {
          eventId,
          eventType: "video-uploaded",
          jobId: videoId,
          userId,
          timestamp: now,
          data: { videoUrl, executionPlan },
          retryCount: 0,
          source: "triggerVideoAIFeatures",
        });
      } else {
        const publishTasks: Promise<any>[] = [];

        if (wantFactCheck || wantSummary) {
          publishTasks.push(
            distribution.publish("fact-processing", {
              eventId: `fact_${eventId}`,
              eventType: "fact-processing",
              jobId: videoId,
              userId,
              timestamp: now,
              data: { videoUrl, executionPlan },
              retryCount: 0,
              source: "triggerVideoAIFeatures",
            })
          );
        }

        if (wantDubbing || wantSubtitles) {
          publishTasks.push(
            distribution.publish("dubbing-processing", {
              eventId: `dub_${eventId}`,
              eventType: "dubbing-processing",
              jobId: videoId,
              userId,
              timestamp: now,
              data: { videoUrl, executionPlan },
              retryCount: 0,
              source: "triggerVideoAIFeatures",
            })
          );
        }

        await Promise.all(publishTasks);
      }

      await jobDocRef.update({
        "stages.onDemandAI.status": "queued",
        "stages.onDemandAI.progress": 25,
        "stages.onDemandAI.dispatchedAt": Date.now(),
      });

      res.status(200).json({
        success: true,
        jobId: videoId,
        message: `AI features (${features.join(", ") || "all"}) requested for target languages: ${targetLanguages.join(", ")}`,
        executionPlan,
      });
    } catch (error) {
      console.error("[triggerVideoAIFeatures] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal server error",
      });
    }
  }
);

/**
 * ☁️ Video upload trigger — fires when video is uploaded to Cloud Storage
 *
 * CONFIG: minInstances=0, maxInstances=1
 */
export const onVideoUpload = onObjectFinalized(
  {
    bucket: "truthworld-1.firebasestorage.app",
    minInstances: 0,
    maxInstances: 10,
    cpu: 0.5,
    memory: "512MiB",
    retry: true,
  },
  async (event) => {
    try {
      const filePath = event.data.name;
      const contentType = event.data.contentType || "";

      // COST GUARD: Only process original uploads under videos/ prefix to prevent loops/spurious triggers
      const fileName = filePath.split("/").pop() ?? "";
      if (!filePath.startsWith("videos/") || !fileName.startsWith("original") || !contentType.startsWith("video/")) {
        return;
      }

      const bucket = event.data.bucket;
      console.log(`[Upload Trigger] Processing: ${filePath}`);

      const { IngestionLayer } = require("./layers/03-ingestion");
      const ingestionLayer = new IngestionLayer();
      await ingestionLayer.handleVideoUpload(bucket, filePath, contentType);
    } catch (error) {
      console.error("[Upload Trigger] Error:", error);
    }
  }
);

/**
 * 🎤 Submit transcription — triggered by video-uploaded event
 *
 * CONFIG: minInstances=0, maxInstances=2, 256MiB, 120s timeout
 */
export const handleTranscription = onMessagePublished(
  {
    topic: "video.uploaded",
    region: "asia-south1",
    timeoutSeconds: 120,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 5,
    retry: true,
    secrets: ["ASSEMBLYAI_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleTranscription] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { videoUrl, executionPlan } = parsedEvent.data as { videoUrl: string; executionPlan: ExecutionPlan };

      const { TranscriptionLayer } = require("./layers/05-transcription");
      const transcriptionLayer = new TranscriptionLayer();
      await transcriptionLayer.submitTranscription(
        parsedEvent.jobId,
        parsedEvent.userId,
        videoUrl,
        executionPlan,
        parsedEvent.eventId
      );
    } catch (error) {
      logger.error("[handleTranscription] Processing failure", { error: String(error) });
      throw error;
    }
  }
);

/**
 * 🧠 Handle credibility processing (Path 1)
 *
 * CONFIG: minInstances=0, maxInstances=2, 1GiB, 540s timeout
 */
export const handleCredibility = onMessagePublished(
  {
    topic: "factcheck.requested",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 5,
    retry: true,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleCredibility] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { executionPlan } = parsedEvent.data as { executionPlan: ExecutionPlan };
      const geminiKey = PIPELINE_CONFIG.GEMINI_API_KEY;
      const { CredibilityEngine } = require("./layers/06-credibility");
      const engine = new CredibilityEngine(geminiKey);

      await engine.runCredibilityPipeline(
        parsedEvent.jobId,
        parsedEvent.userId,
        executionPlan,
        parsedEvent.eventId,
        parsedEvent.traceId
      );
    } catch (error) {
      logger.error("[handleCredibility] Critical failure", { error: String(error) });
      throw error;
    }
  }
);

/**
 * 🌍 Handle dubbing processing (Path 2)
 *
 * CONFIG: minInstances=0, maxInstances=5, 1GiB, 540s timeout
 */
export const handleDubbing = onMessagePublished(
  {
    topic: "dubbing.requested",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 5,
    retry: true,
    secrets: ["ELEVENLABS_API_KEY", "GOOGLE_TRANSLATION_API_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleDubbing] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { videoUrl, executionPlan } = parsedEvent.data as { videoUrl?: string; executionPlan: ExecutionPlan };

      let url = videoUrl ?? "";
      if (!url) {
        const job = await admin.firestore().collection("video_jobs").doc(parsedEvent.jobId).get();
        url = job.data()?.videoUrl ?? "";
      }

      const { DubbingEngine } = require("./layers/07-dubbing");
      const dubbingEngine = new DubbingEngine();
      await dubbingEngine.runDubbingPipeline(
        parsedEvent.jobId,
        parsedEvent.userId,
        url,
        executionPlan,
        parsedEvent.eventId
      );
    } catch (error) {
      logger.error("[handleDubbing] Critical failure", { error: String(error) });
      throw error;
    }
  }
);

/**
 * ✅ Handle fact-complete event (Aggregation)
 *
 * CONFIG: minInstances=0, maxInstances=2, 60s timeout
 */
export const handleFactComplete = onMessagePublished(
  {
    topic: "factcheck.completed",
    region: "asia-south1",
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 5,
    retry: true,
    memory: "256MiB",
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleFactComplete] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const jobDoc = await admin
        .firestore()
        .collection("video_jobs")
        .doc(parsedEvent.jobId)
        .get();
      const executionPlan = jobDoc.data()?.executionPlan as ExecutionPlan;

      const { aggregationLayer } = require("./layers/09-aggregation");
      await aggregationLayer.onFactComplete(
        parsedEvent.jobId,
        parsedEvent.userId,
        parsedEvent.data as unknown as FactCompleteData,
        executionPlan,
        parsedEvent.eventId
      );
    } catch (error) {
      logger.error("[handleFactComplete] Critical failure", { error: String(error) });
      throw error;
    }
  }
);

/**
 * ✅ Handle dubbing-complete event (Aggregation)
 *
 * CONFIG: minInstances=0, maxInstances=5, 60s timeout
 */
export const handleDubbingComplete = onMessagePublished(
  {
    topic: "dubbing.completed",
    region: "asia-south1",
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 5,
    retry: true,
    memory: "256MiB",
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleDubbingComplete] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const jobDoc = await admin
        .firestore()
        .collection("video_jobs")
        .doc(parsedEvent.jobId)
        .get();
      const executionPlan = jobDoc.data()?.executionPlan as ExecutionPlan;

      const { aggregationLayer } = require("./layers/09-aggregation");
      await aggregationLayer.onDubbingComplete(
        parsedEvent.jobId,
        parsedEvent.userId,
        parsedEvent.data as unknown as DubbingCompleteData,
        executionPlan,
        parsedEvent.eventId
      );
    } catch (error) {
      logger.error("[handleDubbingComplete] Critical failure", { error: String(error) });
      throw error;
    }
  }
);

/**
 * 🛡️ Handle copyright checks (MD5 -> Embedding -> Transcript -> Gemini)
 *
 * CONFIG: minInstances=0, maxInstances=5, 1GiB, 540s timeout
 */
export const handleCopyrightCheck = onMessagePublished(
  {
    topic: "copyright.requested",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 5,
    retry: true,
    cpu: 0.5,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleCopyrightCheck] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { runCopyrightCheck } = require("./tasks/copyrightCheckTask");
      await runCopyrightCheck(
        parsedEvent.jobId,
        parsedEvent.userId,
        parsedEvent.eventId
      );
    } catch (error) {
      logger.error("[handleCopyrightCheck] Critical failure", { error: String(error) });
      throw error;
    }
  }
);
