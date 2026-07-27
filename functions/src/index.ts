/**
 * 🚀 FIREBASE CLOUD FUNCTIONS — ENTRY POINT
 *
 * Unified deployment entry point for truthworld Cloud Functions.
 *
 * Features exported:
 *   - Video Processing Pipeline (Ingestion, Transcription, Credibility, Dubbing, Aggregation)
 *   - Cost Governance APIs (Dashboard & Job Cost Breakdowns)
 *   - Scheduled Publishing Scheduler
 *   - Notification Fan-Out & Habit Loops
 *
 * ✅ NO REDIS
 * ✅ minInstances: 0 (scale-to-zero) for cost optimization
 * ✅ Explicit maxInstances caps per function
 * ✅ Region: asia-south1
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK first
if (!admin.apps.length) {
  admin.initializeApp();
}
admin.firestore().settings({ ignoreUndefinedProperties: true });

import { setGlobalOptions } from "firebase-functions/v2";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onRequest } from "firebase-functions/v2/https";
import { onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { v4 as uuidv4 } from "uuid";
import { requireAuth, requireAdmin } from "./utils/auth";
import { strictLimiter } from "./utils/rate-limiter";
import { notifyUser } from "./notifications/notifications";
import { notifyMentions } from "./notifications/triggers";

// ─── Pipeline imports ────────────────────────────────────────────────────────
import {
  ExecutionPlan,
  FactCompleteData,
  DubbingCompleteData,
} from "./pipeline/types";
import { logger } from "./pipeline/utils/logger";



// ─── Global options ──────────────────────────────────────────────────────────
setGlobalOptions({
  region: "asia-south1",
  invoker: "public",
});

/**
 * Global Secrets list for all Pipeline functions.
 * Using secrets for configuration (as requested) ensures consistency, security,
 * and eliminates the need for .env files in production.
 */
import { PIPELINE_CONFIG } from "./pipeline/config";


// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 1: PIPELINE — Video Processing (10 Layers)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * ⚡ Submit video for processing — returns instantly with job ID
 *
 * CONFIG: minInstances=1 (warm), maxInstances=10, concurrency=100
 */
export const submitVideo = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    concurrency: 100,
    timeoutSeconds: 30,
    memory: "256MiB",

  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const { videoUrl, fileName, config } = req.body;
      const userId = authUser.uid;

      if (!videoUrl) {
        res.status(400).json({ error: "Missing videoUrl" });
        return;
      }

      const { EdgeLayer } = require("./pipeline/layers/01-edge");
      const edgeLayer = new EdgeLayer();
      const result = await edgeLayer.submitVideo(
        userId,
        videoUrl,
        fileName || "video.mp4",
        config || {}
      );

      res.status(result.status === "accepted" ? 200 : 400).json(result);
    } catch (error) {
      console.error("[submitVideo] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

/**
 * 📊 Get progressive job status with partial results
 *
 * CONFIG: minInstances=0, maxInstances=10
 */
export const getProgressiveStatus = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: "256MiB",

  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const jobId = req.query.jobId as string;
      if (!jobId) {
        res.status(400).json({ error: "Missing jobId" });
        return;
      }

      const { EdgeLayer } = require("./pipeline/layers/01-edge");
      const edgeLayer = new EdgeLayer();
      const status = await edgeLayer.getProgressiveStatus(jobId);
      if (!status) {
        res.status(404).json({ error: "Job not found" });
        return;
      }

      res.status(200).json(status);
    } catch (error) {
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

/**
 * 📦 Get final aggregated output
 *
 * CONFIG: minInstances=0, maxInstances=10
 */
export const getFinalOutput = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: "256MiB",

  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const jobId = req.query.jobId as string;
      if (!jobId) {
        res.status(400).json({ error: "Missing jobId" });
        return;
      }

      const { aggregationLayer } = require("./pipeline/layers/09-aggregation");
      const output = await aggregationLayer.getFinalOutput(jobId);
      if (!output) {
        res.status(404).json({ error: "Output not ready" });
        return;
      }

      res.status(200).json(output);
    } catch (error) {
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

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

      // Verify authorization: owner or admin
      if (videoData.ownerId && videoData.ownerId !== userId) {
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        const isAdmin = userDoc.exists && userDoc.data()?.role === "admin";
        if (!isAdmin) {
          res.status(403).json({ error: "Unauthorized: You do not own this video" });
          return;
        }
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

      await videoDocRef.update({
        status: "processing",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const transcriptSnap = await admin.firestore().collection("transcripts").doc(videoId).get();
      const transcriptionCompleted = transcriptSnap.exists;

      // Run feature pipelines asynchronously
      (async () => {
        try {
          if (!transcriptionCompleted) {
            const { TranscriptionLayer } = require("./pipeline/layers/05-transcription");
            const transcriptionLayer = new TranscriptionLayer();
            await transcriptionLayer.submitTranscription(videoId, userId, videoUrl, executionPlan, eventId);
          } else {
            const tasks: Promise<any>[] = [];

            if (wantFactCheck || wantSummary) {
              const { CredibilityEngine } = require("./pipeline/layers/06-credibility");
              const credibilityEngine = new CredibilityEngine(PIPELINE_CONFIG.GEMINI_API_KEY);
              tasks.push(
                credibilityEngine.runCredibilityPipeline(
                  videoId,
                  userId,
                  executionPlan,
                  `fact_${eventId}`
                )
              );
            }

            if (wantDubbing || wantSubtitles) {
              const { DubbingEngine } = require("./pipeline/layers/07-dubbing");
              const dubbingEngine = new DubbingEngine();
              tasks.push(
                dubbingEngine.runDubbingPipeline(
                  videoId,
                  userId,
                  videoUrl,
                  executionPlan,
                  `dub_${eventId}`
                )
              );
            }

            await Promise.all(tasks);

            const { aggregationLayer } = require("./pipeline/layers/09-aggregation");
            await aggregationLayer.onStageComplete(videoId, "aggregation", userId, executionPlan, eventId);
          }

          await jobDocRef.update({
            "stages.onDemandAI.status": "completed",
            "stages.onDemandAI.progress": 100,
            "stages.onDemandAI.completedAt": Date.now(),
          });
        } catch (bgError) {
          console.error("[triggerVideoAIFeatures] Background task error:", bgError);
          await jobDocRef.update({
            "stages.onDemandAI.status": "failed",
            "stages.onDemandAI.error": String(bgError),
          });
        }
      })();

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
 * CONFIG: minInstances=0, maxInstances=10
 */
export const onVideoUpload = onObjectFinalized(
  {
    bucket: "truthworld-1.firebasestorage.app",
    minInstances: 0,
    maxInstances: 2,
    memory: "256MiB",
  },
  async (event) => {
    try {
      const filePath = event.data.name;
      const contentType = event.data.contentType || "";

      // COST GUARD: Skip non-video files immediately to avoid wasted compute
      if (!filePath.startsWith("videos/") || !contentType.startsWith("video/")) {
        return;
      }

      const bucket = event.data.bucket;
      console.log(`[Upload Trigger] Processing: ${filePath}`);

      const { IngestionLayer } = require("./pipeline/layers/03-ingestion");
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
 * CONFIG: minInstances=0, maxInstances=10, 512MiB, 60s timeout
 * (Note: Now returns immediately after submitting to AssemblyAI)
 */
export const handleTranscription = onMessagePublished(
  {
    topic: "video.uploaded",
    region: "asia-south1",
    timeoutSeconds: 120,
    memory: "256MiB",   // Reduced from 512MiB — only submits to AssemblyAI API (I/O bound)
    minInstances: 0,
    maxInstances: 2,    // Reduced from 10 — cost cap
    secrets: ["ASSEMBLYAI_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleTranscription] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { videoUrl, executionPlan } = parsedEvent.data as { videoUrl: string; executionPlan: ExecutionPlan };

      const { TranscriptionLayer } = require("./pipeline/layers/05-transcription");
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

// NOTE: handleTranscriptionWebhook REMOVED — was deprecated and wasting cold start costs.
// If still deployed, run: firebase functions:delete handleTranscriptionWebhook --region asia-south1


/**
 * 🧠 Handle credibility processing (Path 1)
 *
 * CONFIG: minInstances=0, maxInstances=5, 1GiB, 300s timeout
 */
export const handleCredibility = onMessagePublished(
  {
    topic: "factcheck.requested",
    region: "asia-south1",
    timeoutSeconds: 540, // v10.6: increased from 300s — Pro+grounding+retry+circuit breaker needs up to ~540s
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 2,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleCredibility] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { executionPlan } = parsedEvent.data as { executionPlan: ExecutionPlan };
      const geminiKey = PIPELINE_CONFIG.GEMINI_API_KEY;
      const { CredibilityEngine } = require("./pipeline/layers/06-credibility");
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
    maxInstances: 2,
    secrets: ["ELEVENLABS_API_KEY", "GOOGLE_TRANSLATION_API_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleDubbing] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { videoUrl, executionPlan } = parsedEvent.data as { videoUrl?: string; executionPlan: ExecutionPlan };

      // Get videoUrl from job doc if not in event
      let url = videoUrl ?? "";
      if (!url) {
        const job = await admin.firestore().collection("video_jobs").doc(parsedEvent.jobId).get();
        url = job.data()?.videoUrl ?? "";
      }

      const { DubbingEngine } = require("./pipeline/layers/07-dubbing");
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
 * CONFIG: minInstances=0, maxInstances=5, 60s timeout
 */
export const handleFactComplete = onMessagePublished(
  {
    topic: "factcheck.completed",
    region: "asia-south1",
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 2,
    memory: "256MiB",
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleFactComplete] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const jobDoc = await admin
        .firestore()
        .collection("video_jobs")
        .doc(parsedEvent.jobId)
        .get();
      const executionPlan = jobDoc.data()?.executionPlan as ExecutionPlan;

      const { aggregationLayer } = require("./pipeline/layers/09-aggregation");
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
    maxInstances: 2,
    memory: "256MiB",
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleDubbingComplete] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const jobDoc = await admin
        .firestore()
        .collection("video_jobs")
        .doc(parsedEvent.jobId)
        .get();
      const executionPlan = jobDoc.data()?.executionPlan as ExecutionPlan;

      const { aggregationLayer } = require("./pipeline/layers/09-aggregation");
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
 * CONFIG: minInstances=0, maxInstances=2, 1GiB, 540s timeout
 */
export const handleCopyrightCheck = onMessagePublished(
  {
    topic: "copyright.requested",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 2,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleCopyrightCheck] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const { runCopyrightCheck } = require("./pipeline/tasks/copyrightCheckTask");
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

/**
 * 🔧 Setup Pub/Sub topics (one-time)
 *
 * CONFIG: minInstances=0, maxInstances=1
 */
export const setupPipeline = onRequest(
  {
    cors: false,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 1,
    timeoutSeconds: 60,

  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      console.log("[Setup] Initializing pipeline topics...");
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const distributionLayer = new DistributionLayer();
      await distributionLayer.ensureTopicsExist();
      res.status(200).json({
        success: true,
        message: "Pipeline setup complete. Dot-notation topics verified/created.",
        timestamp: Date.now()
      });
    } catch (error) {
      console.error("[Setup] Pipeline setup failed:", error);
      res.status(500).json({ error: String(error) });
    }
  }
);



/**
 * ⚡ Fast credibility check — returns traffic-light signal in < 5 seconds
 * 
 * Use case: browser extensions, mobile quick-check, API embeds
 * Flash model only, no grounding, max 5 claims
 * 
 * CONFIG: minInstances=0, maxInstances=20, 512MiB, 30s timeout
 */
export const handleFastVerification = onRequest(
  {
    cors: true,
    region: "asia-south1",
    timeoutSeconds: 30,
    memory: "256MiB",   // Reduced from 512MiB — Gemini API call is I/O bound
    minInstances: 0,
    maxInstances: 2,   // Reduced from 20 — cost cap
    secrets: ["GEMINI_API_KEY"],
  },
  async (req, res) => {
    // Rate limit: 10 requests per minute per IP (expensive Gemini API call)
    if (await strictLimiter(req, res)) return;

    try {
      const { text, domain, category } = req.body;

      if (!text || typeof text !== 'string' || text.trim().length < 20) {
        res.status(400).json({ error: "Missing or too short 'text' field (minimum 20 characters)" });
        return;
      }

      const { FastVerificationService } = require("./pipeline/services/fastVerification");
      const service = new FastVerificationService(PIPELINE_CONFIG.GEMINI_API_KEY);
      const result = await service.verify(text.trim(), domain || 'General', category || 'unknown');

      res.status(200).json(result);
    } catch (error) {
      logger.error("[handleFastVerification] Error", { error: String(error) });
      res.status(500).json({
        signal: 'yellow',
        confidence: 0,
        score: 5.0,
        claimCount: 0,
        bullets: ['Service temporarily unavailable'],
        processingTimeMs: 0,
        tier: 'fast',
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 1.5: COST GOVERNANCE — Cost Dashboard APIs
// ═══════════════════════════════════════════════════════════════════════════════

import { costEngine } from "./pipeline/services/cost-engine";

/**
 * 💰 Get cost dashboard for a specific creator (monthly breakdown)
 *
 * CONFIG: minInstances=0, maxInstances=5
 */
export const getCreatorCostDashboard = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: "256MiB",

  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const userId = authUser.uid;
      const month = req.query.month as string | undefined;

      const dashboard = await costEngine.getCreatorDashboard(userId, month);

      if (!dashboard) {
        res.status(200).json({
          userId,
          month: month || new Date().toISOString().slice(0, 7),
          totalCostUsd: 0,
          jobCount: 0,
          minutesProcessed: 0,
          breakdown: { transcription: 0, translation: 0, tts: 0, storage: 0, media: 0 },
          message: "No usage data found for this period",
        });
        return;
      }

      res.status(200).json(dashboard);
    } catch (error) {
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

/**
 * 📊 Get system-wide cost overview (admin only)
 *
 * CONFIG: minInstances=0, maxInstances=2
 */
export const getSystemCostOverview = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 1,
    timeoutSeconds: 60,
    memory: "256MiB",   // Reduced from 512MiB — simple Firestore aggregation

  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const month = req.query.month as string | undefined;
      const overview = await costEngine.getSystemOverview(month);
      res.status(200).json(overview);
    } catch (error) {
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

/**
 * 🔍 Get per-job cost breakdown with line items
 *
 * CONFIG: minInstances=0, maxInstances=5
 */
export const getJobCostBreakdown = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: "256MiB",

  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const jobId = req.query.jobId as string;

      if (!jobId) {
        res.status(400).json({ error: "Missing jobId" });
        return;
      }

      const breakdown = await costEngine.getJobBreakdown(jobId);

      if (!breakdown) {
        res.status(404).json({ error: "No cost data found for this job" });
        return;
      }

      // Enforce Ownership Gate: Creator can only see their own job's cost breakdown
      const jobOwnerId = breakdown.lineItems?.[0]?.userId;
      if (jobOwnerId && jobOwnerId !== authUser.uid) {
        // Allow admins to view any job cost
        const isAdmin = authUser.isAdmin === true;
        if (!isAdmin) {
          logger.warn("[getJobCostBreakdown] Unauthorized access attempt", {
            jobId,
            requesterId: authUser.uid,
            ownerId: jobOwnerId,
          });
          res.status(403).json({ error: "Unauthorized access to job cost breakdown" });
          return;
        }
      }

      res.status(200).json(breakdown);
    } catch (error) {
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 1.6: COPYRIGHT PROTECTION — Appeals and Claim Management
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 🛡️ Submit copyright appeal
 */
export const submitCopyrightAppeal = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const { claimId, reason } = req.body;
      if (!claimId || !reason) {
        res.status(400).json({ error: "Missing claimId or reason" });
        return;
      }

      // Authorization check: User must be the respondent of the claim
      const claimSnap = await admin.firestore().collection("copyright_claims").doc(claimId).get();
      if (!claimSnap.exists) {
        res.status(404).json({ error: "Claim not found" });
        return;
      }
      const claimData = claimSnap.data()!;
      if (claimData.respondentId !== authUser.uid) {
        res.status(403).json({ error: "Only the respondent of this claim can file an appeal" });
        return;
      }

      const { copyrightClaimsService } = require("./pipeline/services/copyrightClaims");
      const appeal = await copyrightClaimsService.submitAppeal(claimId, reason);

      res.status(200).json({ success: true, appeal });
    } catch (error) {
      logger.error("[submitCopyrightAppeal] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

/**
 * 🏛️ Resolve copyright appeal (Admin only)
 */
export const resolveCopyrightAppeal = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { appealId, resolution, notes } = req.body;
      if (!appealId || !resolution) {
        res.status(400).json({ error: "Missing appealId or resolution" });
        return;
      }

      if (resolution !== "approved" && resolution !== "rejected") {
        res.status(400).json({ error: "Resolution must be 'approved' or 'rejected'" });
        return;
      }

      const { copyrightClaimsService } = require("./pipeline/services/copyrightClaims");
      await copyrightClaimsService.resolveAppeal(appealId, resolution, notes || "");

      res.status(200).json({ success: true, message: `Appeal ${appealId} resolved with status ${resolution}` });
    } catch (error) {
      logger.error("[resolveCopyrightAppeal] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

/**
 * 🛡️ Get copyright claims for the current user
 */
export const getCreatorCopyrightClaims = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const db = admin.firestore();
      
      // Get claims where user is claimant (rights holder)
      const claimantSnap = await db.collection("copyright_claims")
        .where("claimantId", "==", authUser.uid)
        .orderBy("createdAt", "desc")
        .get();

      // Get claims where user is respondent (uploader)
      const respondentSnap = await db.collection("copyright_claims")
        .where("respondentId", "==", authUser.uid)
        .orderBy("createdAt", "desc")
        .get();

      const claimantClaims = claimantSnap.docs.map(d => d.data());
      const respondentClaims = respondentSnap.docs.map(d => d.data());

      res.status(200).json({
        claimantClaims,
        respondentClaims
      });
    } catch (error) {
      logger.error("[getCreatorCopyrightClaims] Error:", error);
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 2: RESOLUTION — Video Resolution Processing (≤ 720p)
// ═══════════════════════════════════════════════════════════════════════════════

export {
  onVideoUploadedForResolution,
  getVideoResolutionStatus,
  getResolutionProfiles,
  handleResolution,
} from "./resolution/resolution";

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 4: PUBLISH-GATED PIPELINE — AI Processing After Metadata Complete
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 🚀 PRIMARY PIPELINE ENTRY POINT — Publish-Gated Job Creation
 *
 * Video jobs are ONLY created after:
 *   1. Video file is uploaded (videoUrl is present)
 *   2. Creator sets title + description (metadata complete)
 *   3. Creator clicks "Publish" (aiFeatures.pipelineStage === 'published')
 *   4. All aiFeatures are finalized (factChecking, dubbing, languages, etc.)
 *
 * This replaces the old pattern where jobs were created prematurely during
 * file upload before any metadata or AI features were configured.
 *
 * Also handles re-trigger for language changes on already-published videos.
 *
 * Mapped aiFeatures:
 *   - transcript           → always on (transcription stage)
 *   - draftTranscription   → reserved for future pre-compute
 *   - factChecking         → enablePath1 / enableTruthEngine
 *   - finalTranscription   → transcription with full accuracy
 *   - genLangSubs          → enablePath2 / enableReachEngine
 *   - generateDubbing      → dubbing mode in execution plan
 *   - translationLanguages → plan.languages
 *   - tts                  → TTS voice config
 *   - diarization          → expectedSpeakerCount routing
 *   - speakerCount         → expectedSpeakerCount
 *   - summary              → enableAuxiliary (summary generation)
 */
export const onVideoPublished = onDocumentUpdated(
  {
    document: "videos/{videoId}",
    region: "asia-south1",
    retry: true,
    memory: "256MiB",  // Reduced from 512MiB — only does Firestore writes + Pub/Sub
    maxInstances: 2,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const videoId = event.params.videoId;

    if (!afterData) return;

    const aiFeatures = afterData.aiFeatures || {};
    const beforeAiFeatures = beforeData?.aiFeatures || {};

    // ─── GATE 1: Detect if pipelineStage just became 'published' ────────────
    const becamePublished =
      beforeAiFeatures.pipelineStage !== "published" &&
      aiFeatures.pipelineStage === "published";

    // ─── GATE 2: Detect language changes on already-published video ──────────
    // translationLanguages lives INSIDE aiFeatures map, with fallback to top-level languages
    const getTranslationLangs = (data: any) => data?.aiFeatures?.translationLanguages || data?.languages || [];
    const isAlreadyPublished = aiFeatures.pipelineStage === "published";
    const languagesChanged =
      isAlreadyPublished &&
      JSON.stringify(getTranslationLangs(beforeData)) !== JSON.stringify(getTranslationLangs(afterData));

    // ─── GATE 2.5: Detect if moderation status just became approved ──────────
    const wasApproved = beforeData?.moderation?.status === "approved";
    const isApproved = afterData.moderation?.status === "approved";
    const becameApproved = !wasApproved && isApproved;
    const isPublished = aiFeatures.pipelineStage === "published";
    const notificationsNotSentYet = !afterData.notificationsSent;

    const shouldSendNotifications = isPublished && isApproved && notificationsNotSentYet && (becamePublished || becameApproved);

    // v2.0: Gate 2.5 (moderation wait) REMOVED — pipeline starts immediately.
    // Moderation runs in parallel via Storage trigger and cancels job if rejected.

    if (!becamePublished && !languagesChanged && !shouldSendNotifications) {
      return; // No relevant change — exit silently
    }

    // ─── GATE 3: Metadata completeness check ────────────────────────────────
    const title = afterData.title || "";
    const videoUrl = afterData.videoUrl || "";

    if (!title || title === "Uploading..." || !videoUrl) {
      logger.warn("[PublishGate] Incomplete metadata — skipping pipeline", {
        videoId,
        hasTitle: !!title && title !== "Uploading...",
        hasVideoUrl: !!videoUrl,
      });
      return;
    }

    const db = admin.firestore();
    const { EdgeLayer } = require("./pipeline/layers/01-edge");
    const { DistributionLayer } = require("./pipeline/layers/04-distribution");
    const distributionLayer = new DistributionLayer();

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO D: Trigger Subscriber Notifications once video is approved & published
    // ═══════════════════════════════════════════════════════════════════════════
    if (shouldSendNotifications) {
      logger.info("[PublishGate] Video approved & published. Triggering subscriber notifications.", { videoId });
      await db.collection("videos").doc(videoId).update({
        notificationsSent: true,
      });
      _fanOutSubscriberNotifications(afterData, videoId).catch(err =>
        logger.warn("[PublishGate] Subscriber notification fan-out failed (non-critical)", { videoId, err: String(err) })
      );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO A: First-time publish → Create video_job + trigger full pipeline
    // v2.0: SPECULATIVE START — pipeline begins immediately, moderation runs in
    // parallel. If moderation rejects, the Storage trigger cancels the job.
    // This saves ~25-30s of sequential moderation wait time.
    // ═══════════════════════════════════════════════════════════════════════════
    if (becamePublished && !afterData.jobId) {

      // ── IDEMPOTENCY GUARD: Prevent duplicate jobs on Firestore trigger retry ──
      const existingJobSnap = await db.collection("video_jobs")
        .where("videoId", "==", videoId)
        .limit(1)
        .get();
      if (!existingJobSnap.empty) {
        logger.info("[PublishGate] Job already exists for this video — skipping (retry idempotency)", {
          videoId,
          existingJobId: existingJobSnap.docs[0].id,
        });
        return;
      }

      // v2.0: Check if already rejected BEFORE creating job (handles case where
      // moderation completed before user clicked Publish)
      const moderationStatus = afterData.moderation?.status;
      if (moderationStatus === "rejected") {
        logger.warn("[PublishGate] Video already REJECTED by moderation — blocking pipeline", {
          videoId,
          reason: afterData.moderation?.reason,
        });
        await db.collection("videos").doc(videoId).update({
          status: "rejected",
          rejectionReason: afterData.moderation?.reason || "Content violates Community Guidelines",
        });
        return;
      }

      logger.info("[PublishGate] First publish — SPECULATIVE pipeline start (moderation runs in parallel)", {
        videoId,
        moderationStatus: moderationStatus || "pending",
        features: {
          factChecking: aiFeatures.factChecking,
          genLangSubs: aiFeatures.genLangSubs,
          generateDubbing: aiFeatures.generateDubbing,
          diarization: aiFeatures.diarization,
          summary: aiFeatures.summary,
          translationLanguages: getTranslationLangs(afterData),
          speakerCount: aiFeatures.speakerCount,
          ttsEnabled: aiFeatures.tts?.enabled,
        },
      });

      const userId = afterData.userId || afterData.ownerId;
      if (!userId) {
        logger.error("[PublishGate] No userId/ownerId on video doc", { videoId });
        return;
      }

      const jobId = `job_${Date.now()}_${uuidv4().substring(0, 8)}`;
      const eventId = uuidv4();

      // ── Map ALL aiFeatures → ExecutionPlan ──────────────────────────────────
      const requestedLanguages: string[] = getTranslationLangs(afterData);
      const enableFactChecking = aiFeatures.factChecking ?? false;
      const enableGenLangSubs = aiFeatures.genLangSubs ?? false;
      const enableDubbing = aiFeatures.generateDubbing ?? false;
      const enableSummary = aiFeatures.summary ?? false;
      const enableDiarization = aiFeatures.diarization ?? false;
      const hasTargetLanguages = requestedLanguages.length > 0;
      const enablePath2 = enableDubbing || enableGenLangSubs || hasTargetLanguages;

      // TTS config mapping
      const ttsConfig = aiFeatures.tts || {};
      const voiceType = ttsConfig.voiceType || "standard";

      // Speaker count mapping for diarization routing
      const speakerCount = aiFeatures.speakerCount || "not_sure";

      const executionPlan: ExecutionPlan = {
        jobId,
        enablePath1: enableFactChecking,
        enablePath2,
        enableTruthEngine: enableFactChecking,
        enableReachEngine: enablePath2,
        enableAuxiliary: enableSummary,
        languages: Array.from(new Set(["en", ...requestedLanguages])),
        dubbingMode: voiceType === "voice_clone" ? "voice_clone" : (enableDubbing ? "standard" : "none"),
        generateDubbing: enableDubbing,
        genLangSubs: enableGenLangSubs,
        channelType: afterData.channelType || "standard",
        autoChapters: aiFeatures.autoChapters ?? false,
        maxClaims: enableFactChecking ? (afterData.channelType === 'custom' ? 100 : 20) : 0,
        priority: afterData.channelType === 'custom' ? "high" : "normal",

        skipCache: false,

        // Creator Intelligence (v7)
        expectedSpeakerCount: speakerCount as '1' | '2-3' | '4+' | 'not_sure',
        contentFormat: enableDiarization ? "general" : "solo",

        // Translation & Localization
        translationModel: afterData.channelType === "custom" ? "dynamic" : "standard",

        toneMode: "formal",
        localeStyle: requestedLanguages.includes("hi") ? "hinglish" : "neutral",
        targetPlatform: afterData.targetPlatform || "youtube",

        // Duration from video doc metadata
        duration: afterData.duration ? parseInt(String(afterData.duration)) : undefined,
        videoCategory: afterData.category || "Other",
      };

      // ── Build pipeline stages ───────────────────────────────────────────────
      const now = Date.now();
      const shard = EdgeLayer.shardKey(userId);

      // v2.0: Determine moderation stage status from current video doc
      const modStageStatus = moderationStatus === "approved"
        ? { status: "completed", progress: 100, completedAt: now }
        : { status: "running", progress: 50, startedAt: now }; // Running in parallel

      const stages: Record<string, any> = {
        moderation: modStageStatus, // v2.0: Runs in parallel via Storage trigger
        upload: { status: "completed", progress: 100, completedAt: now },
        validation: { status: "completed", progress: 100, completedAt: now },
        queue: { status: "running", progress: 50, startedAt: now },
        transcription: { status: "pending", progress: 0 },
        copyright: { status: "pending", progress: 0 },
        credibility: enableFactChecking ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 },
        dubbing: enablePath2 ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 },
        rendering: { status: "pending", progress: 0 },
        finalizing: { status: "pending", progress: 0 },
        aggregation: { status: "pending", progress: 0 },
      };

      // Add per-language stages for localization tracking
      if (enablePath2) {
        const targetLangs = requestedLanguages.filter(l => l !== "en");
        for (const lang of targetLangs) {
          stages[`translating_${lang}`] = { status: "pending", progress: 0 };
          if (enableDubbing) {
            stages[`dubbing_${lang}`] = { status: "pending", progress: 0 };
          }
        }
      }

      // ── Create the canonical video_jobs record ──────────────────────────────
      const jobData = {
        jobId,
        videoId,
        userId,
        videoUrl,
        fileName: afterData.fileName || "video.mp4",
        filePath: afterData.storage?.videoPath || `videos/${videoId}/original.mp4`,
        status: "accepted",
        eventId,
        shard,
        executionPlan,
        config: {
          userId,
          channelType: executionPlan.channelType,

          languages: executionPlan.languages,
          dubbingMode: executionPlan.dubbingMode,
          genLangSubs: enableGenLangSubs,
          generateDubbing: enableDubbing,
          enableFactCheck: enableFactChecking,
          priority: executionPlan.priority,
        },
        channelId: afterData.channelId || null,
        linkedVideoIds: [videoId],
        linkedVideoCount: 1,
        estimatedCostUsd: 0, // Will be refined by cost engine
        stages,
        createdAt: now,
        updatedAt: now,
        version: 1,
      };

      // Atomic write: job doc + video doc link
      const batch = db.batch();
      batch.set(db.collection("video_jobs").doc(jobId), jobData);
      batch.update(db.collection("videos").doc(videoId), {
        jobId,
        status: "processing",
        updatedAt: now,
      });
      await batch.commit();

      logger.info("[PublishGate] Video job created from publish", {
        jobId,
        videoId,
        enableFactChecking,
        enableDubbing,
        enableGenLangSubs,
        enableSummary,
        enableDiarization,
        languages: executionPlan.languages,
        speakerCount,
      });

      // ── Trigger pipeline via video-uploaded event ───────────────────────────
      await distributionLayer.publish("video-uploaded", {
        eventId,
        eventType: "video-uploaded",
        jobId,
        userId,
        timestamp: now,
        data: {
          videoUrl,
          fileName: afterData.fileName || "video.mp4",
          executionPlan,
        },
        retryCount: 0,
        source: "publish-gate",
      });

      return;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO B: Already published, job exists → Re-trigger Path 2 for new languages
    // ═══════════════════════════════════════════════════════════════════════════
    if (languagesChanged && afterData.jobId) {
      const jobId = afterData.jobId;
      logger.info("[PublishGate] Language change detected on published video", {
        videoId,
        jobId,
        newLanguages: getTranslationLangs(afterData),
      });

      const jobDoc = await db.collection("video_jobs").doc(jobId).get();
      if (!jobDoc.exists) {
        logger.warn("[PublishGate] Linked video_job not found", { videoId, jobId });
        return;
      }

      const jobData = jobDoc.data()!;

      // Gate: Transcription must be complete before localization
      const stages = jobData.stages || {};
      if (stages.transcription?.status !== "completed") {
        logger.info("[PublishGate] Transcription not yet complete — deferring language trigger", { videoId, jobId });
        return;
      }

      // Idempotency: Check if this language version was already processed
      const localizationVersion = (getTranslationLangs(afterData) as string[]).sort().join(",");
      const processedVersions = jobData.processedLocalizationVersions || [];
      if (processedVersions.includes(localizationVersion)) {
        logger.info("[PublishGate] Language version already processed", { videoId, jobId, version: localizationVersion });
        return;
      }

      // Update execution plan with new languages + current aiFeatures
      const updatedPlan: ExecutionPlan = {
        ...jobData.executionPlan,
        languages: Array.from(new Set(["en", ...getTranslationLangs(afterData)])),
        generateDubbing: aiFeatures.generateDubbing ?? jobData.executionPlan.generateDubbing,
        genLangSubs: aiFeatures.genLangSubs ?? jobData.executionPlan.genLangSubs,
        enablePath2: true,
        enableReachEngine: true,
        jobId,
      };

      await distributionLayer.publish("dubbing-processing", {
        eventId: uuidv4(),
        eventType: "dubbing-processing",
        jobId,
        userId: jobData.userId,
        timestamp: Date.now(),
        data: {
          videoUrl: jobData.videoUrl,
          executionPlan: updatedPlan,
        },
        retryCount: 0,
        source: "publish-gate-relang",
      });

      // Update job doc with new plan and reset stages
      const updatePayload: Record<string, any> = {
        executionPlan: updatedPlan,
        "stages.dubbing": { status: "pending", progress: 0, startedAt: Date.now() },
        processedLocalizationVersions: admin.firestore.FieldValue.arrayUnion(localizationVersion),
        updatedAt: Date.now(),
      };

      const targetLangs = (getTranslationLangs(afterData) as string[]).filter((l: string) => l !== "en");
      for (const lang of targetLangs) {
        updatePayload[`stages.translating_${lang}`] = { status: "pending", progress: 0 };
        updatePayload[`stages.dubbing_${lang}`] = { status: "pending", progress: 0 };
      }

      await jobDoc.ref.update(updatePayload);
      return;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO C: Re-publish (job already exists) → Skip (idempotent)
    // ═══════════════════════════════════════════════════════════════════════════
    if (becamePublished && afterData.jobId) {
      logger.info("[PublishGate] Re-publish detected but job already exists — skipping", {
        videoId,
        jobId: afterData.jobId,
      });
      return;
    }
  }
);

// ─── MERGED HELPER: Subscriber Notification Fan-Out ──────────────────────────
// Previously was a SEPARATE onDocumentUpdated trigger (onNewVideoFromFollowed),
// causing DOUBLE invocations on every video document update. Now inlined as a
// fire-and-forget helper called only when status actually becomes "published".
async function _fanOutSubscriberNotifications(video: any, videoId: string): Promise<void> {
  const db = admin.firestore();
  const { channelId, title, creatorName } = video;
  const channelNameStr = creatorName || video.channelName || "Unknown Channel";
  const creatorId = video.ownerId || video.userId;

  // 1. Paginated subscriber fan-out (400 per batch = safe Firestore batch limit)
  const BATCH_SIZE = 400;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let totalNotified = 0;

  while (true) {
    let query = db.collection("subscriptions")
      .where("channelId", "==", channelId)
      .limit(BATCH_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    const notifications: Promise<any>[] = [];

    snap.docs.forEach(doc => {
      const { userId, notificationsEnabled } = doc.data();
      if (!userId || userId === creatorId) return;

      batch.set(
        db.collection("users").doc(userId).collection("feed_inbox").doc(videoId),
        {
          id: videoId,
          channelId: channelId || "",
          channelName: channelNameStr,
          channelImage: video.channelImage || "",
          title: title || "Untitled Video",
          thumbnailUrl: video.thumbnailUrl || "",
          uploadedAt: video.uploadedAt || video.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          views: video.views || 0,
          duration: video.duration || "0:00",
          category: video.category || "General",
          isSeen: false,
          materializedAt: admin.firestore.FieldValue.serverTimestamp()
        },
        { merge: true }
      );

      if (notificationsEnabled !== false) {
        notifications.push(
          notifyUser({
            userId,
            type: "new_video_followed",
            severity: "info",
            title: `New Video from ${channelNameStr}`,
            message: `${channelNameStr} just uploaded: ${title}`,
            actionUrl: `/video/${videoId}`,
            metadata: { channelId, videoId, thumbnailUrl: video.thumbnailUrl, avatarUrl: video.channelImage || "" }
          })
        );
      }
    });

    await batch.commit();
    await Promise.allSettled(notifications);
    totalNotified += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < BATCH_SIZE) break;
  }

  logger.info(`[FanOut] Notified ${totalNotified} subscribers for video ${videoId}`);

  // 2. Topic follower notifications (capped at 500)
  const topicId = video.topicId || (video.topics?.length > 0 ? video.topics[0] : null);
  if (topicId) {
    const topicSnap = await db.collection("topics").where("slug", "==", topicId).limit(1).get();
    if (!topicSnap.empty) {
      const topicDoc = topicSnap.docs[0];
      const topicTitle = topicDoc.data().title || "Followed Topic";
      const savedSnap = await db.collectionGroup("savedTopics").where("topicId", "==", topicDoc.id).limit(500).get();
      const topicNotifs = savedSnap.docs
        .filter(d => d.data()?.notificationSetting !== "none")
        .map(d => d.ref.path.split("/")[1])
        .filter(uid => uid && uid !== creatorId)
        .map(uid => notifyUser({
          userId: uid,
          type: "new_video_topic",
          severity: "info",
          title: `New Video in Topic: ${topicTitle}`,
          message: `A new video was added to ${topicTitle}: ${title}`,
          actionUrl: `/video/${videoId}`,
          metadata: { 
            topicId: topicDoc.id, 
            videoId, 
            thumbnailUrl: video.thumbnailUrl,
            avatarUrl: video.channelImage || ""
          }
        }));
      await Promise.allSettled(topicNotifs);
    }
  }

  // 3. @mention notifications
  const combinedText = `${title || ""} ${video.description || ""}`;
  await notifyMentions({
    text: combinedText,
    senderUserId: creatorId || "",
    senderName: channelNameStr,
    actionUrl: `/video/${videoId}`,
    title: "Mentioned in a Video!",
    message: `${channelNameStr} mentioned your channel in their video: "${title}"`,
    metadata: { videoId, thumbnailUrl: video.thumbnailUrl, avatarUrl: video.channelImage || "" }
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 2.5: VIDEO CONTENT MODERATION — Community Guidelines Gate
// ═══════════════════════════════════════════════════════════════════════════════

export { onVideoUploadedForModeration, moderateVideoManual } from "./moderation/videoModeration";

export {
  ingestUploadedImage,
  moderationWorkerHigh,
  moderationWorkerMedium,
  moderationWorkerLow,
  prefilterWorker,
  retryQueueProcessor,
  // retryQueueProcessorManual,
  deadLetterHandler,
  // getImageVerificationStatus,
  // cleanupVerificationRecord,
  scheduledRetryProcessor,
  moderateImageManual,
} from "./verification/verification";

/*
export {
  trackWatchEvent,
  aggregateWatchStats,
  cleanupOldEvents,
  getCreatorStats,
} from "./watchtime/watchtime";

export { createChannel, switchChannelType } from "./channels/channels";
*/
export { onChannelWritten, onImageVerificationWritten } from "./channels/moderation";
export { onTopicWritten } from "./topics/moderation";

/*
export { 
  updateChannelProfile, 
  getPublicChannelProfile, 
  migrateChannelsToV2 
} from "./channels/profile";

export {
  getLeaderboard,
  getRisingCreators
} from "./channels/discovery";

export {
  followChannel,
  unfollowChannel,
  getFollowingFeed
} from "./channels/social";

export {
  getTrustBadge
} from "./channels/embeds";
*/

export {
  getNotifications,
  markNotificationRead,
  updateTopicNotificationSettings
} from "./notifications/notifications";

export {
  onCommentCreated,
  onNewSubscription,
  onCommunityPostCreated
} from "./notifications/triggers";

export { onFactCheckCompleted } from "./channels/reputation_triggers";

/*
export {
  getHomeFeed,
  getDiscoveryModules
} from "./channels/recommendations";

export {
  trackActivity
} from "./users/signals";

export {
  getCreatorRevenue
} from "./economy/revenue";

export {
  getLeaderboards
} from "./economy/leaderboards";

export {
  requestInstitutionalVerification,
  approveVerification
} from "./channels/verification";
*/

export {
  addCommentNested,
  addReplyNested,
  toggleCommentInteraction,
  toggleReplyInteraction,
  deleteCommentNested,
  deleteReplyNested,
  reportCommentNested,
} from "./community/comments";

// ── Infrastructure: Idempotency TTL Cleanup ──────────────────────────────────
export { cleanupProcessedEvents } from "./shared/idempotency";

/*
export {
  getChannelOverview,
  getChannelViewsDetails,
  getChannelWatchtimeDetails,
  getChannelSubscribers,
  getChannelRevenueDetails,
} from "./channels/analytics";

export {
  getCachedImage
} from "./services/image-proxy";
*/

export {
  scheduledPublishing,
} from "./publishing/scheduledPublishing";

/*
export {
  manualTriggerPublishing,    // POST /api/admin/publish/trigger
  getScheduledVideos,          // GET /api/admin/publish/scheduled
  publishSingleVideo,          // POST /api/admin/publish/video/{videoId}
} from "./publishing/adminEndpoints";
*/

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 5: INFRASTRUCTURE — Unified Source of Truth Replication
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 🔄 Event-Driven Replication: Syncs Canonical Truth (video_jobs) to Shards (UI Replicas)
 * 
 * ✅ ON-WRITE: Covers Create, Update, and Delete lifecycles.
 * ✅ LOOP-FREE: Only triggers on the central collection.
 */
export const syncJobToShard = onDocumentWritten(
  {
    document: "video_jobs/{jobId}",
    region: "asia-south1",
    retry: true,
    memory: "256MiB",
    maxInstances: 2, // Reduced from 50 — was causing excessive parallel invocations
  },
  async (event: any) => {
    const jobId = event.params.jobId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    const db = admin.firestore();

    // 1. Deletion Sync
    if (!afterData) {
      if (beforeData) {
        const shard = beforeData.shard || "0";
        logger.info("[Sync] Deleting shard replica", { jobId, shard });
        await db.collection(`video_jobs_${shard}`).doc(jobId).delete();
      }
      return;
    }

    // 2. Upsert Sync (Create/Update)
    const shard = afterData.shard || "0";
    const version = afterData.version || 0;

    // Skip if version hasn't changed (reliable field-level check)
    // NOTE: Previously used JSON.stringify() which is unreliable because
    // JavaScript object key order is not guaranteed, causing the check to
    // almost never match and triggering redundant shard writes on every update.
    if (beforeData) {
      const beforeVersion = beforeData.version || 0;
      const beforeUpdatedAt = beforeData.updatedAt || 0;
      const afterUpdatedAt = afterData.updatedAt || 0;
      if (beforeVersion === version && beforeUpdatedAt === afterUpdatedAt) {
        return;
      }
    }

    logger.debug("[Sync] Replicating to shard", { jobId, shard, version });

    const replicaData = {
      ...afterData,
      replicaSyncedAt: Date.now(),
      replicatedFromVersion: version,
    };

    await db.collection(`video_jobs_${shard}`).doc(jobId).set(replicaData, { merge: true });
  }
);

// ─── SEO Server & Indexing Cloud Functions ───────────────────────────────────
export { seoServer } from "./seo/seoServer";
export { rebuildDirtySitemapsScheduler } from "./seo/sitemap/sitemapScheduler";
export { onVideoSeoWritten, onChannelSeoWritten } from "./seo/indexing/indexingTriggers";

export { onAdCampaignWritten } from "./ads/ads";

/**
 * 🔐 Temporary Admin Claim tool
 * Trigger this endpoint to make any email account an admin for the manual verification panel.
 * Example: https://asia-south1-truthworld-1.cloudfunctions.net/makeMeAdmin?email=your-email@gmail.com
 */
export const makeMeAdmin = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 1,
    memory: "256MiB",
  },
  async (req, res) => {
    const email = req.query.email as string;
    if (!email) {
      res.status(400).send("Missing 'email' query parameter.");
      return;
    }
    try {
      const user = await admin.auth().getUserByEmail(email);
      await admin.auth().setCustomUserClaims(user.uid, { admin: true });
      res.status(200).send(`Successfully set admin claim for ${email}. Please sign out and sign back in to refresh your token!`);
    } catch (error) {
      res.status(500).send(`Error: ${error}`);
    }
  }
);

// ─── Playlist Moderation triggers ─────────────────────────────────────────────
export { onPublicPlaylistWritten, onPrivatePlaylistWritten } from "./moderation/playlistModeration";

// ─── SWR Cache Refresh Task Handlers (Cloud Tasks) ───────────────────────────
const runSWRTask = async (event: any) => {
  try {
    const payload = event.data;
    if (!payload || !payload.jobId || !payload.claimIds || !payload.cacheKeys) {
      logger.error("[SWR Task] Invalid payload", { payload });
      return;
    }
    const geminiKey = PIPELINE_CONFIG.GEMINI_API_KEY;
    const { CredibilityEngine } = require("./pipeline/layers/06-credibility");
    const engine = new CredibilityEngine(geminiKey);
    await engine.refreshCacheForClaims(payload);
  } catch (error) {
    logger.error("[SWR Task] Execution failed", { error: String(error) });
    throw error;
  }
};

export const refreshHighQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
    rateLimits: { maxConcurrentDispatches: 10 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);

export const refreshMediumQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 2, minBackoffSeconds: 30 },
    rateLimits: { maxConcurrentDispatches: 5 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);

export const refreshLowQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 1, minBackoffSeconds: 60 },
    rateLimits: { maxConcurrentDispatches: 2 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);

export const refreshBackgroundQueue = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 1, minBackoffSeconds: 120 },
    rateLimits: { maxConcurrentDispatches: 1 },
    region: "asia-south1",
    secrets: ["GEMINI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  runSWRTask
);

/**
 * 📣 Creator Appeal Gateway Endpoint
 * Allows creators to appeal a REJECTED video to the Admin Manual Review queue
 */
export const submitVideoAppeal = onRequest(
  { cors: true, region: "asia-south1", memory: "256MiB", timeoutSeconds: 30 },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const { videoId, appealReason } = req.body;
      const userId = authUser.uid;

      if (!videoId || !appealReason) {
        res.status(400).json({ error: "Missing videoId or appealReason" });
        return;
      }

      const videoRef = admin.firestore().collection("videos").doc(videoId);
      const doc = await videoRef.get();

      if (!doc.exists) {
        res.status(404).json({ error: "Video not found" });
        return;
      }

      const videoData = doc.data()!;
      if (videoData.userId !== userId && videoData.creatorId !== userId) {
        res.status(403).json({ error: "Forbidden: You do not own this video" });
        return;
      }

      // Update gatewayDecision to appealed
      const updatedDecision = {
        ...(videoData.gatewayDecision || {}),
        appealed: true,
        appealedAt: Date.now(),
        appealReason,
        appealStatus: "pending"
      };

      await videoRef.set({
        gatewayDecision: updatedDecision,
        gatewayStatus: "MANUAL_REVIEW",
        updatedAt: Date.now()
      }, { merge: true });

      // Add to Admin Review Queue
      await admin.firestore().collection("admin_review_queue").doc(videoId).set({
        jobId: videoData.jobId || videoId,
        videoId,
        userId,
        appealReason,
        gatewayDecision: updatedDecision,
        queuedAt: Date.now(),
        status: "pending_appeal"
      }, { merge: true });

      logger.info("[Appeal Gateway] Video appeal submitted by creator", { videoId, userId, appealReason });

      res.status(200).json({
        success: true,
        message: "Video appeal successfully submitted and queued for Admin Manual Review.",
        appealStatus: "pending"
      });
    } catch (error) {
      logger.error("[Appeal Gateway] Failed to submit appeal", { error: String(error) });
      res.status(500).json({ error: "Internal server error submitting appeal" });
    }
  }
);

/**
 * 🛡️ Copyright Owner Action Resolution Endpoint
 * Allows original copyright owners to pick:
 * 1. YELLOW_STRIKE (Delete video & issue strike to channel)
 * 2. REDIRECT_MONETIZATION (Redirect ad revenue to original owner & resume pipeline)
 * 3. NO_OBJECTION (License video & resume pipeline)
 */
export const resolveCopyrightOwnerAction = onRequest(
  { cors: true, region: "asia-south1", memory: "256MiB", timeoutSeconds: 30 },
  async (req, res) => {
    try {
      const authUser = await requireAuth(req, res);
      if (!authUser) return;

      const { notificationId, action } = req.body;
      const ownerId = authUser.uid;

      if (!notificationId || !action) {
        res.status(400).json({ error: "Missing notificationId or action" });
        return;
      }

      if (!["YELLOW_STRIKE", "REDIRECT_MONETIZATION", "NO_OBJECTION"].includes(action)) {
        res.status(400).json({ error: "Invalid action. Must be YELLOW_STRIKE, REDIRECT_MONETIZATION, or NO_OBJECTION." });
        return;
      }

      const { copyrightClaimsService } = require("./pipeline/services/copyrightClaims");
      const { DistributionLayer } = require("./pipeline/layers/04-distribution");
      const distLayer = new DistributionLayer();

      const result = await copyrightClaimsService.resolveCopyrightOwnerAction(
        notificationId,
        ownerId,
        action,
        distLayer
      );

      if (!result.success) {
        res.status(400).json({ error: result.message });
        return;
      }

      res.status(200).json(result);
    } catch (error) {
      logger.error("[Copyright Action API] Failed to resolve copyright owner action", { error: String(error) });
      res.status(500).json({ error: "Internal server error processing copyright action" });
    }
  }
);


