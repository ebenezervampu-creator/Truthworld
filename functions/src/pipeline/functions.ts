/**
 * 🚀 PIPELINE CLOUD FUNCTIONS
 *
 * Extracted from index.ts to modularize the codebase.
 */

import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { requireAuth, requireAdmin, verifyAuth } from "../utils/auth.js";
import { strictLimiter } from "../utils/rate-limiter.js";
import { enforceQuota, recordUsage } from "../utils/quota-enforcer.js";

// Pipeline imports
import { EdgeLayer } from "./layers/01-edge.js";
import { IngestionLayer } from "./layers/03-ingestion.js";
import { DistributionLayer } from "./layers/04-distribution.js";
import { TranscriptionLayer } from "./layers/05-transcription.js";
import { CredibilityEngine } from "./layers/06-credibility.js";
import { DubbingEngine } from "./layers/07-dubbing.js";
import { aggregationLayer } from "./layers/09-aggregation.js";
import {
  ExecutionPlan,
  FactCompleteData,
  DubbingCompleteData,
} from "./types/index.js";
import { logger } from "./utils/logger.js";
import { PIPELINE_CONFIG } from "./config.js";
import { FastVerificationService } from "./services/fastVerification.js";
import { costEngine } from "./services/cost-engine.js";

// Singleton instances
const edgeLayer = new EdgeLayer();
const ingestionLayer = new IngestionLayer();
const distributionLayer = new DistributionLayer();
const transcriptionLayer = new TranscriptionLayer();
const dubbingEngine = new DubbingEngine();

// ==============================================================================
// FEATURE 1: PIPELINE — Video Processing (10 Layers)
// ==============================================================================

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
    maxInstances: 10,
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
    maxInstances: 10,
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
    maxInstances: 10,
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
 * ☁️ Video upload trigger — fires when video is uploaded to Cloud Storage
 *
 * CONFIG: minInstances=0, maxInstances=10
 */
export const onVideoUpload = onObjectFinalized(
  {
    bucket: "truthworld-1.firebasestorage.app",
    minInstances: 0,
    maxInstances: 10,
    memory: "1GiB",          // FFmpeg extraction needs more than default 256MB
    timeoutSeconds: 300,      // Allow 5 minutes for extraction + Gemini round-trip
    secrets: ["GEMINI_API_KEY"], // Required for Gemini safety precheck
  },
  async (event) => {
    try {
      const bucket = event.data.bucket;
      const filePath = event.data.name;
      const contentType = event.data.contentType || "";

      console.log(`[Upload Trigger] Processing: ${filePath}`);

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
export const handleTranscription = onRequest(
  {
    cors: false,
    region: "asia-south1",
    timeoutSeconds: 540, // Increased for inline polling support
    memory: "512MiB",
    minInstances: 0,
    maxInstances: 10,
    secrets: ["ASSEMBLYAI_KEY"],
  },
  async (req, res) => {
    try {
      if (!req.body) throw new Error("Missing request body");
      const event = DistributionLayer.parseMessage(req.body.message || req.body);
      logger.info("[handleTranscription] Start", { jobId: event.jobId, eventId: event.eventId });

      const { videoUrl, executionPlan } = event.data as { videoUrl: string; executionPlan: ExecutionPlan };

      await transcriptionLayer.submitTranscription(
        event.jobId,
        event.userId,
        videoUrl,
        executionPlan,
        event.eventId
      );

      res.status(200).send("OK");
    } catch (error) {
      logger.error("[handleTranscription] Processing failure", { error: String(error) });
      res.status(500).json({ error: String(error) });
    }
  }
);

/**
 * 🎯 AssemblyAI Webhook Handler
 *
 * Returns immediately and delegates result processing to prevent idle Cloud Function billing.
 */
export const handleTranscriptionWebhook = onRequest(
  { region: "asia-south1", timeoutSeconds: 120, memory: "512MiB" },
  async (req, res) => {
    try {
      const { jobId, eventId } = req.query as { jobId?: string; eventId?: string };
      const { status, transcript_id, error } = req.body as { status: string; transcript_id: string; error?: string };

      if (!jobId || !eventId) {
        logger.error("[handleTranscriptionWebhook] Missing query parameters", { jobId, eventId });
        res.status(400).send("Missing query params");
        return;
      }

      if (!status || !transcript_id) {
        logger.error("[handleTranscriptionWebhook] Missing body parameters", { status, transcript_id });
        res.status(400).send("Missing body parameters");
        return;
      }

      await transcriptionLayer.processWebhook(jobId, eventId, transcript_id, status, error);
      res.status(200).send("OK");
    } catch (err) {
      logger.error("[handleTranscriptionWebhook] Webhook handling failed", { error: String(err) });
      res.status(500).send(String(err));
    }
  }
);

/**
 * 🧠 Handle credibility processing (Path 1)
 *
 * CONFIG: minInstances=0, maxInstances=5, 1GiB, 300s timeout
 */
export const handleCredibility = onRequest(
  {
    cors: false,
    region: "asia-south1",
    timeoutSeconds: 540, // v10.6: increased from 300s — Pro+grounding+retry+circuit breaker needs up to ~540s
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 5,
    secrets: ["GEMINI_API_KEY"],
  },
  async (req, res) => {
    try {
      if (!req.body) throw new Error("Missing request body");
      const event = DistributionLayer.parseMessage(req.body.message || req.body);
      logger.info("[handleCredibility] Start", { jobId: event.jobId, eventId: event.eventId });

      const { executionPlan } = event.data as { executionPlan: ExecutionPlan };
      const geminiKey = PIPELINE_CONFIG.GEMINI_API_KEY;
      const engine = new CredibilityEngine(geminiKey);

      await engine.runCredibilityPipeline(
        event.jobId,
        event.userId,
        executionPlan,
        event.eventId,
        event.traceId
      );

      res.status(200).send("OK");
    } catch (error) {
      logger.error("[handleCredibility] Critical failure", { error: String(error), body: req.body });
      res.status(500).json({ error: String(error) });
    }
  }
);

/**
 * 🌍 Handle dubbing processing (Path 2)
 *
 * CONFIG: minInstances=0, maxInstances=5, 1GiB, 540s timeout
 */
export const handleDubbing = onRequest(
  {
    cors: false,
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 5,
    secrets: ["ELEVENLABS_API_KEY", "GOOGLE_TRANSLATION_API_KEY"],
  },
  async (req, res) => {
    try {
      if (!req.body) throw new Error("Missing request body");
      const event = DistributionLayer.parseMessage(req.body.message || req.body);
      logger.info("[handleDubbing] Start", { jobId: event.jobId, eventId: event.eventId });

      const { videoUrl, executionPlan } = event.data as { videoUrl?: string; executionPlan: ExecutionPlan };

      // Get videoUrl from job doc if not in event
      let url = videoUrl ?? "";
      if (!url) {
        const job = await admin.firestore().collection("video_jobs").doc(event.jobId).get();
        url = job.data()?.videoUrl ?? "";
      }

      await dubbingEngine.runDubbingPipeline(
        event.jobId,
        event.userId,
        url,
        executionPlan,
        event.eventId
      );

      res.status(200).send("OK");
    } catch (error) {
      logger.error("[handleDubbing] Critical failure", { error: String(error), body: req.body });
      res.status(500).json({ error: String(error) });
    }
  }
);

/**
 * ✅ Handle fact-complete event (Aggregation)
 *
 * CONFIG: minInstances=0, maxInstances=5, 60s timeout
 */
export const handleFactComplete = onRequest(
  {
    cors: false,
    region: "asia-south1",
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 5,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      if (!req.body) throw new Error("Missing request body");
      const event = DistributionLayer.parseMessage(req.body.message || req.body);
      logger.info("[handleFactComplete] Start", { jobId: event.jobId, eventId: event.eventId });

      const jobDoc = await admin
        .firestore()
        .collection("video_jobs")
        .doc(event.jobId)
        .get();
      const executionPlan = jobDoc.data()?.executionPlan as ExecutionPlan;

      await aggregationLayer.onFactComplete(
        event.jobId,
        event.userId,
        event.data as unknown as FactCompleteData,
        executionPlan,
        event.eventId
      );

      res.status(200).send("OK");
    } catch (error) {
      logger.error("[handleFactComplete] Critical failure", { error: String(error), body: req.body });
      res.status(500).json({ error: String(error) });
    }
  }
);

/**
 * ✅ Handle dubbing-complete event (Aggregation)
 *
 * CONFIG: minInstances=0, maxInstances=5, 60s timeout
 */
export const handleDubbingComplete = onRequest(
  {
    cors: false,
    region: "asia-south1",
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 5,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      if (!req.body) throw new Error("Missing request body");
      const event = DistributionLayer.parseMessage(req.body.message || req.body);
      logger.info("[handleDubbingComplete] Start", { jobId: event.jobId, eventId: event.eventId });

      const jobDoc = await admin
        .firestore()
        .collection("video_jobs")
        .doc(event.jobId)
        .get();
      const executionPlan = jobDoc.data()?.executionPlan as ExecutionPlan;

      await aggregationLayer.onDubbingComplete(
        event.jobId,
        event.userId,
        event.data as unknown as DubbingCompleteData,
        executionPlan,
        event.eventId
      );

      res.status(200).send("OK");
    } catch (error) {
      logger.error("[handleDubbingComplete] Critical failure", { error: String(error), body: req.body });
      res.status(500).json({ error: String(error) });
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
  async (_req, res) => {
    try {
      console.log("[Setup] Initializing pipeline topics...");
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

// ─── FAST TIER — Real-Time Credibility Signal (v11.0) ────────────────────────

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
    memory: "512MiB",
    minInstances: 0,
    maxInstances: 20,
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

      // Quota gating for signed-in users
      const authUser = await verifyAuth(req);
      if (authUser) {
        await enforceQuota(authUser.uid, "fastVerifications", 1);
      }

      const service = new FastVerificationService(PIPELINE_CONFIG.GEMINI_API_KEY);
      const result = await service.verify(text.trim(), domain || 'General', category || 'unknown');

      // Record quota usage for signed-in users
      if (authUser) {
        await recordUsage(authUser.uid, "fastVerifications", 1);
      }

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
    maxInstances: 5,
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
          message: "No usage data data found for this period",
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
    maxInstances: 2,
    timeoutSeconds: 60,
    memory: "512MiB",
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
    maxInstances: 5,
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

      res.status(200).json(breakdown);
    } catch (error) {
      res.status(500).json({
        error: error instanceof Error ? error.message : "Internal error",
      });
    }
  }
);
