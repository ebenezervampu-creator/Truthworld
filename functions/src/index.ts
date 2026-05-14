/**
 * 🚀 FIREBASE CLOUD FUNCTIONS — ENTRY POINT (Updated: 2026-04-22T17:31Z)
 *
 * Exports EXACTLY 3 features:
 *   1. Pipeline  — 10-layer video processing pipeline
 *   2. Resolution — Video resolution processing (≤ 720p)
 *   3. Verification — Image verification (thumbnails, avatars, banners, community posts)
 *
 * ✅ NO REDIS
 * ✅ minInstances: 0 (scale-to-zero) except edge (minInstances: 1)
 * ✅ Explicit maxInstances caps per function
 * ✅ Region: asia-south1
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK first
if (!admin.apps.length) {
  admin.initializeApp();
}

import { setGlobalOptions } from "firebase-functions/v2";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onRequest } from "firebase-functions/v2/https";
import { onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { v4 as uuidv4 } from "uuid";

// ─── Pipeline imports ────────────────────────────────────────────────────────
import { EdgeLayer } from "./pipeline/layers/01-edge";
import { IngestionLayer } from "./pipeline/layers/03-ingestion";
import { DistributionLayer } from "./pipeline/layers/04-distribution";
import { TranscriptionLayer } from "./pipeline/layers/05-transcription";
import { CredibilityEngine } from "./pipeline/layers/06-credibility";
import { DubbingEngine } from "./pipeline/layers/07-dubbing";
import { aggregationLayer } from "./pipeline/layers/09-aggregation";
import {
  ExecutionPlan,
  FactCompleteData,
  DubbingCompleteData,
} from "./pipeline/types";
import { logger } from "./pipeline/utils/logger";



// ─── Global options ──────────────────────────────────────────────────────────
setGlobalOptions({
  region: "asia-south1",
});

/**
 * Global Secrets list for all Pipeline functions.
 * Using secrets for configuration (as requested) ensures consistency, security,
 * and eliminates the need for .env files in production.
 */
import { PIPELINE_CONFIG } from "./pipeline/config";

// Singleton instances
const edgeLayer = new EdgeLayer();
const ingestionLayer = new IngestionLayer();
const distributionLayer = new DistributionLayer();
const transcriptionLayer = new TranscriptionLayer();
const dubbingEngine = new DubbingEngine();
// aggregationLayer is imported directly as singleton

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
    minInstances: 1,
    maxInstances: 10,
    concurrency: 100,
    timeoutSeconds: 30,
    memory: "256MiB",
    
  },
  async (req, res) => {
    try {
      const { userId, videoUrl, fileName, config } = req.body;

      if (!userId || !videoUrl) {
        res.status(400).json({ error: "Missing userId or videoUrl" });
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
 * 🎯 AssemblyAI Webhook Handler (DEPRECATED)
 *
 * Migration Note: Polling is now used instead of webhooks to bypass 
 * restricted network policies and ensure immediate fan-out.
 */
export const handleTranscriptionWebhook = onRequest(
  { region: "asia-south1" },
  async (req, res) => {
    logger.info("[Webhook] Received request on deprecated endpoint. Logic migrated to polling.");
    res.status(200).send("Migrated to polling");
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

import { FastVerificationService } from "./pipeline/services/fastVerification";

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
  },
  async (req, res) => {
    try {
      const { text, domain, category } = req.body;

      if (!text || typeof text !== 'string' || text.trim().length < 20) {
        res.status(400).json({ error: "Missing or too short 'text' field (minimum 20 characters)" });
        return;
      }

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
    maxInstances: 5,
    timeoutSeconds: 30,
    memory: "256MiB",
    
  },
  async (req, res) => {
    try {
      const userId = req.query.userId as string;
      const month = req.query.month as string | undefined;

      if (!userId) {
        res.status(400).json({ error: "Missing userId" });
        return;
      }

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
    maxInstances: 2,
    timeoutSeconds: 60,
    memory: "512MiB",
    
  },
  async (req, res) => {
    try {
      // TODO: Add admin auth check here
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
    memory: "512MiB",
    maxInstances: 10,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData  = event.data?.after.data();
    const videoId    = event.params.videoId;

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

    if (!becamePublished && !languagesChanged) {
      return; // No relevant change — exit silently
    }

    // ─── GATE 3: Metadata completeness check ────────────────────────────────
    const title    = afterData.title || "";
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

    // ═══════════════════════════════════════════════════════════════════════════
    // SCENARIO A: First-time publish → Create video_job + trigger full pipeline
    // ═══════════════════════════════════════════════════════════════════════════
    if (becamePublished && !afterData.jobId) {
      logger.info("[PublishGate] First publish detected — creating pipeline job", {
        videoId,
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

      const userId  = afterData.userId || afterData.ownerId;
      if (!userId) {
        logger.error("[PublishGate] No userId/ownerId on video doc", { videoId });
        return;
      }

      const jobId   = `job_${Date.now()}_${uuidv4().substring(0, 8)}`;
      const eventId = uuidv4();

      // ── Map ALL aiFeatures → ExecutionPlan ──────────────────────────────────
      const requestedLanguages: string[] = getTranslationLangs(afterData);
      const enableFactChecking  = aiFeatures.factChecking ?? false;
      const enableGenLangSubs   = aiFeatures.genLangSubs ?? false;
      const enableDubbing       = aiFeatures.generateDubbing ?? false;
      const enableSummary       = aiFeatures.summary ?? false;
      const enableDiarization   = aiFeatures.diarization ?? false;
      const hasTargetLanguages  = requestedLanguages.length > 0;
      const enablePath2         = enableDubbing || enableGenLangSubs || hasTargetLanguages;

      // TTS config mapping
      const ttsConfig = aiFeatures.tts || {};
      const voiceType = ttsConfig.voiceType || "standard";

      // Speaker count mapping for diarization routing
      const speakerCount = aiFeatures.speakerCount || "not_sure";

      const executionPlan: ExecutionPlan = {
        jobId,
        enablePath1:       enableFactChecking,
        enablePath2,
        enableTruthEngine: enableFactChecking,
        enableReachEngine: enablePath2,
        enableAuxiliary:   enableSummary,
        languages:         Array.from(new Set(["en", ...requestedLanguages])),
        dubbingMode:       voiceType === "voice_clone" ? "voice_clone" : (enableDubbing ? "standard" : "none"),
        generateDubbing:   enableDubbing,
        genLangSubs:       enableGenLangSubs,
        channelType:       afterData.channelType || "standard",
        autoChapters:      aiFeatures.autoChapters ?? false,
        maxClaims:         enableFactChecking ? (afterData.channelType === 'custom' ? 100 : 20) : 0,
        priority:          afterData.channelType === 'custom' ? "high" : "normal",

        skipCache:         false,

        // Creator Intelligence (v7)
        expectedSpeakerCount: speakerCount as '1' | '2-3' | '4+' | 'not_sure',
        contentFormat:        enableDiarization ? "general" : "solo",

        // Translation & Localization
        translationModel: afterData.channelType === "custom" ? "dynamic" : "standard",

        toneMode:         "formal",
        localeStyle:      requestedLanguages.includes("hi") ? "hinglish" : "neutral",
        targetPlatform:   afterData.targetPlatform || "youtube",

        // Duration from video doc metadata
        duration: afterData.duration ? parseInt(String(afterData.duration)) : undefined,
      };

      // ── Build pipeline stages ───────────────────────────────────────────────
      const now = Date.now();
      const shard = EdgeLayer.shardKey(userId);

      const stages: Record<string, any> = {
        upload:        { status: "completed", progress: 100, completedAt: now },
        validation:    { status: "completed", progress: 100, completedAt: now },
        queue:         { status: "running",   progress: 50,  startedAt: now },
        transcription: { status: "pending",   progress: 0 },
        credibility:   enableFactChecking ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 },
        dubbing:       enablePath2        ? { status: "pending", progress: 0 } : { status: "skipped", progress: 100 },
        rendering:     { status: "pending", progress: 0 },
        finalizing:    { status: "pending", progress: 0 },
        aggregation:   { status: "pending", progress: 0 },
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
        genLangSubs:     aiFeatures.genLangSubs ?? jobData.executionPlan.genLangSubs,
        enablePath2:     true,
        enableReachEngine: true,
        jobId,
      };

      await distributionLayer.publish("dubbing-processing", {
        eventId:   uuidv4(),
        eventType: "dubbing-processing",
        jobId,
        userId:    jobData.userId,
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

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 3: VERIFICATION — Image Verification
// ═══════════════════════════════════════════════════════════════════════════════

export {
  ingestUploadedImage,
  moderationWorkerHigh,
  moderationWorkerMedium,
  moderationWorkerLow,
  prefilterWorker,
  retryQueueProcessor,
  retryQueueProcessorManual,
  deadLetterHandler,
  getImageVerificationStatus,
  cleanupVerificationRecord,
  scheduledRetryProcessor,
} from "./verification/verification";

// ─── Watchtime Functions ─────────────────────────────────────────────────────
export {
  trackWatchEvent,
  aggregateWatchStats,
  cleanupOldEvents,
  getCreatorStats,
} from "./watchtime/watchtime";

// ─── Channel Management ──────────────────────────────────────────────────────
export { createChannel, switchChannelType } from "./channels/channels";

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

// ─── Notifications & Habit Loops ─────────────────────────────────────────────
export {
  getNotifications,
  markNotificationRead
} from "./notifications/notifications";

export {
  onNewVideoFromFollowed,
  onChannelStateChange,
  weeklyDigest
} from "./notifications/triggers";

export { onFactCheckCompleted } from "./channels/reputation_triggers";

// ─── Recommendations & Personalization ──────────────────────────────────────
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

export {
  addComment,
  getComments,
  addCommentNested,
  addReplyNested,
  toggleCommentInteraction,
  toggleReplyInteraction,
  deleteCommentNested,
  deleteReplyNested,
  reportCommentNested,
} from "./community/comments";

// Decommissioned: processMonthlyPromotions from "./channels/promotion";

// ─── Channel Analytics ────────────────────────────────────────────────────────
export {
  getChannelOverview,
  getChannelViewsDetails,
  getChannelWatchtimeDetails,
  getChannelSubscribers,
  getChannelRevenueDetails,
} from "./channels/analytics";

// ─── Image Caching & Proxy ──────────────────────────────────────────────────
export {
  getCachedImage
} from "./services/image-proxy";

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE 4: SCHEDULED PUBLISHING — Pub/Sub-Triggered Video Publishing
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * ⏰ Main Pub/Sub handler for scheduled video publishing
 * 
 * Triggered by Cloud Scheduler every 5 minutes
 * Publishes any videos where scheduledTime <= now
 * Cost-efficient: Only pays for actual videos published, not polling
 */
export {
  scheduledPublishing,
} from "./publishing/scheduledPublishing";

/**
 * 🔧 Admin HTTP endpoints for manual testing & diagnostics
 * 
 * All require Firebase Auth + admin claim
 */
export {
  manualTriggerPublishing,    // POST /api/admin/publish/trigger
  getScheduledVideos,          // GET /api/admin/publish/scheduled
  publishSingleVideo,          // POST /api/admin/publish/video/{videoId}
} from "./publishing/adminEndpoints";

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
    maxInstances: 50, // High concurrency for replication throughput
  },
  async (event: any) => {
    const jobId = event.params.jobId;
    const beforeData = event.data?.before.data();
    const afterData  = event.data?.after.data();

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

    // Skip if nothing changed (prevents redundant writes)
    if (beforeData && JSON.stringify(beforeData) === JSON.stringify(afterData)) {
      return;
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
