import * as admin from "firebase-admin";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { requireAuth } from "../utils/auth";
import {
  ExecutionPlan,
  FactCompleteData,
  DubbingCompleteData,
} from "./types";
import { logger } from "./utils/logger";
import { PIPELINE_CONFIG } from "./config";
import { normalizeLanguageCode } from "../shared/language-normalizer";

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
    maxInstances: 5,
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

      // Verify authorization: must be video owner (ownerId, userId, or uploaderId), channel owner, or admin
      const videoOwnerId = videoData.ownerId || videoData.userId || videoData.uploaderId;
      let isOwner = videoOwnerId === userId;
      const isAdmin = authUser.isAdmin === true;

      if (!isOwner && !isAdmin && videoData.channelId) {
        try {
          const channelSnap = await admin.firestore().collection("channels").doc(videoData.channelId).get();
          if (channelSnap.exists) {
            const chData = channelSnap.data() || {};
            if (chData.ownerId === userId || chData.userId === userId) {
              isOwner = true;
            }
          }
        } catch (e) {
          logger.warn("[triggerVideoAIFeatures] Error checking channel ownership:", e);
        }
      }

      if (!isOwner && !isAdmin) {
        res.status(403).json({ error: "Unauthorized: You do not own this video" });
        return;
      }

      const videoUrl = videoData.videoUrl ||
        videoData.originalUrl ||
        videoData.media?.videoUrl ||
        videoData.media?.originalUrl ||
        videoData.url ||
        videoData.hlsUrl ||
        "";
      if (!videoUrl) {
        res.status(400).json({ error: "Video source URL is empty" });
        return;
      }

      const jobDocRef = admin.firestore().collection("video_jobs").doc(videoId);
      const jobSnap = await jobDocRef.get();
      const jobData = jobSnap.exists ? jobSnap.data() : null;

      const existingLanguages: string[] = jobData?.executionPlan?.languages || [normalizeLanguageCode(videoData.language || "en")];
      const languagesSet = new Set([...existingLanguages, ...targetLanguages]);
      const combinedLanguages = Array.from(languagesSet);

      const wantSubtitles = features.includes("subtitles");
      const wantDubbing = features.includes("dubbing");
      const wantFactCheck = features.includes("factcheck");
      const wantSummary = features.includes("summary");
      const wantChapters = features.includes("chapters");
      const wantDiarization = features.includes("diarization") || features.includes("speaker_diarization") || (jobData?.executionPlan?.enableDiarization ?? false);

      const executionPlan: ExecutionPlan = {
        jobId: videoId,
        languages: combinedLanguages,
        primaryLanguage: normalizeLanguageCode(videoData.language || "en"),
        enablePath1: wantFactCheck || wantSummary || (jobData?.executionPlan?.enablePath1 ?? true),
        enablePath2: wantDubbing || wantSubtitles || (jobData?.executionPlan?.enablePath2 ?? true),
        enableTruthEngine: wantFactCheck || wantSummary || (jobData?.executionPlan?.enableTruthEngine ?? true),
        enableReachEngine: wantDubbing || wantSubtitles || (jobData?.executionPlan?.enableReachEngine ?? true),
        enableAuxiliary: true,
        enableDiarization: wantDiarization,
        diarization: wantDiarization,
        dubbingLanguages: wantDubbing ? targetLanguages : (jobData?.executionPlan?.dubbingLanguages || []),
        dubbingMode: "standard",
        generateDubbing: wantDubbing,
        genLangSubs: wantSubtitles,
        generateSubtitles: wantSubtitles,
        autoChapters: wantChapters || autoChapters,
        priorityMode: priorityMode,
        sensitiveTopics: sensitiveTopics,
        channelType: jobData?.executionPlan?.channelType || "standard",
        maxClaims: wantFactCheck ? 200 : 0,
        factCheckTier: "full_ground",
        synthesisTier: wantFactCheck ? "deep" : "standard",
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

      const targetTranscriptId = videoData.jobId || videoId;
      let transcriptSnap = await admin.firestore().collection("transcripts").doc(targetTranscriptId).get();
      if (!transcriptSnap.exists && targetTranscriptId !== videoId) {
        transcriptSnap = await admin.firestore().collection("transcripts").doc(videoId).get();
      }
      const transcriptionCompleted = transcriptSnap.exists;

      try {
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
      } catch (pubSubError) {
        logger.warn("[triggerVideoAIFeatures] Pub/Sub dispatch warning (falling back to Firestore job queue):", pubSubError);
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
    maxInstances: 20,
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
 * CONFIG: minInstances=0, maxInstances=20, 1GiB, 540s timeout
 */
export const handleTranscription = onMessagePublished(
  {
    topic: "video.uploaded",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 3,
    retry: true,
    secrets: ["ASSEMBLYAI_KEY", "GEMINI_API_KEY"],
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
 * CONFIG: minInstances=0, maxInstances=15, 2GiB, 540s timeout
 */
export const handleCredibility = onMessagePublished(
  {
    topic: "factcheck.requested",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "2GiB",
    minInstances: 0,
    maxInstances: 2,
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
 * 🧪 Handle credibility synthesis — runs after verification completes
 * Separated from main verification to prevent 540s timeout starvation
 *
 * CONFIG: minInstances=0, maxInstances=10, 2GiB, 540s timeout
 */
export const handleCredibilitySynthesis = onMessagePublished(
  {
    topic: "credibility.synthesis.requested",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "2GiB",
    minInstances: 0,
    maxInstances: 10,
    retry: true,
    secrets: ["GEMINI_API_KEY"],
  },
  async (event) => {
    try {
      const { DistributionLayer } = require("./layers/04-distribution");
      const parsedEvent = DistributionLayer.parseMessage(event.data.message);
      logger.info("[handleCredibilitySynthesis] Start", { jobId: parsedEvent.jobId, eventId: parsedEvent.eventId });

      const geminiKey = PIPELINE_CONFIG.GEMINI_API_KEY;
      const { CredibilityEngine } = require("./layers/06-credibility");
      const engine = new CredibilityEngine(geminiKey);
      await engine.runSynthesisPass(parsedEvent.jobId, parsedEvent.userId, parsedEvent.eventId);
    } catch (error) {
      logger.error("[handleCredibilitySynthesis] Critical failure", { error: String(error) });
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
    memory: "2GiB",
    minInstances: 0,
    maxInstances: 2,
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
    maxInstances: 2,
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
    maxInstances: 2,
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
 * CONFIG: minInstances=0, maxInstances=10, 1GiB, 540s timeout
 */
export const handleCopyrightCheck = onMessagePublished(
  {
    topic: "copyright.requested",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    minInstances: 0,
    maxInstances: 10,
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

/**
 * 🎙️ Sync dubbing results (audio tracks & dubbed video) directly to linked videos and media/localization
 */
export const onDubbingResultWritten = onDocumentWritten(
  {
    document: "dubbing_results/{resultId}",
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (event) => {
    try {
      const afterSnap = event.data?.after;
      if (!afterSnap || !afterSnap.exists) return;

      const data = afterSnap.data();
      if (!data) return;

      const jobId = data.jobId;
      const language = data.language;
      const audioUrl = data.audioUrl;
      const videoUrl = data.videoUrl;

      if (!jobId || !language || (!audioUrl && !videoUrl)) return;

      const bucketName = admin.storage().bucket().name;
      const directAudioUrl = audioUrl
        ? (audioUrl.startsWith("gs://")
            ? `https://storage.googleapis.com/${bucketName}/${audioUrl.replace(`gs://${bucketName}/`, "")}`
            : audioUrl)
        : "";
      const directVideoUrl = videoUrl
        ? (videoUrl.startsWith("gs://")
            ? `https://storage.googleapis.com/${bucketName}/${videoUrl.replace(`gs://${bucketName}/`, "")}`
            : videoUrl)
        : "";

      // Find linked video IDs
      const jobSnap = await admin.firestore().collection("video_jobs").doc(jobId).get();
      const jobData = jobSnap.data();
      const linkedVideoIds: string[] = jobData?.linkedVideoIds ? [...jobData.linkedVideoIds] : [];
      if (jobData?.videoId && !linkedVideoIds.includes(jobData.videoId)) {
        linkedVideoIds.push(jobData.videoId);
      }
      // Also check if jobId itself is a video doc
      const directVidSnap = await admin.firestore().collection("videos").doc(jobId).get();
      if (directVidSnap.exists && !linkedVideoIds.includes(jobId)) {
        linkedVideoIds.push(jobId);
      }

      if (linkedVideoIds.length === 0) return;

      const audioUpdates: Record<string, string> = {};
      if (directAudioUrl) {
        audioUpdates[language] = directAudioUrl;
      }
      const dubbedUpdates: Record<string, string> = {};
      if (directVideoUrl) {
        dubbedUpdates[language] = directVideoUrl;
      }

      for (const vid of linkedVideoIds) {
        const vDocUpdate: any = {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (directAudioUrl) {
          vDocUpdate.audioTracks = audioUpdates;
          vDocUpdate["media.audioTracks"] = audioUpdates;
        }
        if (directVideoUrl) {
          vDocUpdate.dubbedVideos = dubbedUpdates;
          vDocUpdate["media.dubbedVideos"] = dubbedUpdates;
        }

        await admin.firestore().collection("videos").doc(vid).set(vDocUpdate, { merge: true });

        await admin.firestore().collection("videos").doc(vid).collection("media").doc("localization").set({
          ...(directAudioUrl ? { audioTracks: audioUpdates } : {}),
          ...(directVideoUrl ? { dubbedVideos: dubbedUpdates } : {}),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      logger.info("[onDubbingResultWritten] Successfully synced audio/video to videos", {
        jobId, language, videoCount: linkedVideoIds.length
      });
    } catch (err) {
      logger.error("[onDubbingResultWritten] Error syncing dubbing result to video", { err: String(err) });
    }
  }
);

/**
 * 📝 Fetch or Synthesize Genuine AI Summary for a Video (onCall)
 *
 * Ensures videos never show raw verbatim transcript slices or developer errors as the AI summary.
 * If the existing video document has a valid AI summary, returns it.
 * If the summary is missing, invalid, or a verbatim transcript snippet, generates a concise,
 * engaging 2-3 sentence AI summary using Vertex AI Gemini 2.5 Flash and persists it.
 */
export const getVideoAiSummary = onCall(
  {
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: ["GEMINI_API_KEY"],
  },
  async (request) => {
    const videoId = request.data?.videoId;
    if (!videoId || typeof videoId !== "string") {
      throw new HttpsError("invalid-argument", "videoId is required.");
    }

    const videoDoc = await admin.firestore().collection("videos").doc(videoId).get();
    if (!videoDoc.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }

    const vData = videoDoc.data() || {};
    let jobData: any = null;
    if (vData.jobId) {
      try {
        const jSnap = await admin.firestore().collection("video_jobs").doc(vData.jobId).get();
        if (jSnap.exists) jobData = jSnap.data();
      } catch (e) {
        logger.warn("[getVideoAiSummary] Could not fetch video_jobs doc:", e);
      }
    }

    let currentSummary = (
      vData.moderation?.summary ||
      vData.moderationSummary ||
      jobData?.stages?.moderation?.summary ||
      jobData?.gatewayDecision?.summary ||
      vData.summary ||
      ""
    ) as string;

    // Load transcript to check for verbatim matches and for generation
    let transcriptText = "";
    const tDoc = await admin.firestore().collection("transcripts").doc(videoId).get();
    if (tDoc.exists && tDoc.data()?.text) {
      transcriptText = tDoc.data()!.text;
    }
    if (!transcriptText && vData.jobId) {
      const jobTDoc = await admin.firestore().collection("transcripts").doc(vData.jobId).get();
      if (jobTDoc.exists && jobTDoc.data()?.text) {
        transcriptText = jobTDoc.data()!.text;
      }
    }

    if (!transcriptText) {
      try {
        const bucket = admin.storage().bucket();
        const candidatePaths = [
          `transcripts/${videoId}/full.json`,
          vData.jobId ? `transcripts/${vData.jobId}/full.json` : null,
        ].filter(Boolean) as string[];

        for (const p of candidatePaths) {
          const file = bucket.file(p);
          const [exists] = await file.exists();
          if (exists) {
            const [data] = await file.download();
            const parsed = JSON.parse(data.toString("utf8"));
            transcriptText = parsed.text || parsed.transcript || (Array.isArray(parsed.words) ? parsed.words.map((w: any) => w.text || w.word).join(" ") : "");
            if (transcriptText) break;
          }
        }
      } catch (e) {
        logger.warn("[getVideoAiSummary] Storage transcript probe error:", e);
      }
    }

    const isTranscriptSnippet = (s?: string) => {
      if (!s) return true;
      const clean = s.replace(/\.{3}$/, "").trim();
      if (clean.length > 20 && transcriptText && transcriptText.trim().startsWith(clean)) {
        return true;
      }
      if (s.endsWith("...") && s.length >= 150 && (
        s.startsWith("Welcome to") ||
        s.startsWith("Hey guys") ||
        s.startsWith("Hey everyone") ||
        s.startsWith("In this video") ||
        s.startsWith("Today we")
      )) {
        return true;
      }
      return false;
    };

    const isInvalid = (s?: string) =>
      !s ||
      s.trim().length < 15 ||
      /moderation timed out|video approved pending|async review|moderation could not complete|verification in progress|summary unavailable/i.test(s) ||
      isTranscriptSnippet(s);

    if (!isInvalid(currentSummary)) {
      if (vData.summary !== currentSummary || vData.moderationSummary !== currentSummary || vData.moderation?.summary !== currentSummary) {
        await admin.firestore().collection("videos").doc(videoId).update({
          summary: currentSummary,
          moderationSummary: currentSummary,
          "moderation.summary": currentSummary,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch((err) => logger.warn("[getVideoAiSummary] Sync write failed:", err));
      }
      return { summary: currentSummary };
    }

    // Fallback transcript to description if still missing
    if (!transcriptText && vData.description && vData.description.length > 30) {
      transcriptText = vData.description;
    }

    if (!transcriptText || transcriptText.trim().length < 20) {
      return { summary: "" };
    }

    try {
      const { getVertexAI } = require("./utils/ai-client");
      const { extractCandidateText } = require("./utils/ai-utils");
      const vertex = getVertexAI();
      const model = vertex.getGenerativeModel({
        model: "gemini-2.5-flash",
        generationConfig: { maxOutputTokens: 150, temperature: 0.2 } as any,
      });
      const prompt = `Provide a concise, engaging 2-3 sentence AI summary of this video based on the transcript. Focus on the core topic, insights, and key takeaways. Do NOT quote or repeat the transcript text verbatim:\n\n${transcriptText.substring(0, 6000)}`;
      const res = await model.generateContent(prompt);
      const generated = extractCandidateText(res.response?.candidates?.[0])?.trim() || "";

      if (generated && generated.length > 20 && !isTranscriptSnippet(generated)) {
        await admin.firestore().collection("videos").doc(videoId).update({
          summary: generated,
          moderationSummary: generated,
          "moderation.summary": generated,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { summary: generated };
      }
    } catch (err) {
      logger.error("[getVideoAiSummary] Generation failed", { videoId, err });
    }

    return { summary: "" };
  }
);

/**
 * 🏛 Collect Authentic Source Avatars (onCall)
 *
 * Resolves high-resolution logos/emblems for domains, URLs, and publishers
 * supporting fact-checking citations and source verification.
 */
export const getSourceAvatars = onCall(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (request) => {
    const { SourceAvatarService } = require("./services/sourceAvatarService");
    const data = request.data || {};
    const domains: string[] = Array.isArray(data.domains) ? data.domains : [];
    const sources: Array<{ domain?: string; publisher?: string; url?: string }> =
      Array.isArray(data.sources) ? data.sources : [];

    const queryItems = [
      ...domains.map((d: string) => ({ domain: d })),
      ...sources,
    ];

    const avatars = await SourceAvatarService.resolveBatch(queryItems);
    return { avatars };
  }
);


