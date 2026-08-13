/**
 * 🎤 LAYER 05 — TRANSCRIPTION LAYER (Universal-3 Pro + Universal-2 Fallback)
 *
 * Audio extraction → AssemblyAI (Multi-model) → structured word/segment output → emit event.
 *
 * ✅ ALL UPGRADES:
 *   1. Model: `universal-3-pro` + `universal-2` — Auto-fallback for 99+ languages support
 *   2. Native subtitle export — SRT/VTT fetched directly from AssemblyAI (source language)
 *   3. Consumer idempotency gate — checks eventId via DistributionLayer before doing any work
 *   4. Structured storage — full JSON stored in GCS (avoids Firestore doc size limit)
 *   5. Language detection result — stored for downstream use (translation skip if same lang)
 *   6. Stage updates are async — never blocks the processing pipeline
 *   7. Webhook-based architecture — returns immediately after submission
 */

import axios from "axios";
import * as admin from "firebase-admin";
import {
  EnhancedTranscriptionResult,
  WordTimestamp,
  TimedSegment,
  SpeakerInfo,
  ExecutionPlan,
} from "../types";
import { DistributionLayer } from "./04-distribution";
import { EdgeLayer } from "./01-edge";
import { aggregationLayer } from "./09-aggregation";
import { logger } from "../utils/logger";
import { costEngine } from "../services/cost-engine";
import { reputationService } from "../services/reputationService"; // v7.3
import { PIPELINE_CONFIG } from "../config";
import { videoGatewayService } from "../services/videoGatewayService";
import { copyrightDetectionService } from "../services/copyrightDetection";
import { copyrightClaimsService } from "../services/copyrightClaims";

const ASSEMBLY_BASE = "https://api.assemblyai.com/v2";
const db = () => admin.firestore();

export class TranscriptionLayer {
  private readonly distribution: DistributionLayer;

  constructor() {
    this.distribution = new DistributionLayer();
  }

  /**
   * Part 1: Submit to AssemblyAI Universal-3 Pro.
   * Extracts audio if needed, then submits to AssemblyAI and polls for completion.
   */
  async submitTranscription(
    jobId: string,
    userId: string,
    videoUrl: string,
    executionPlan: ExecutionPlan,
    eventId: string
  ): Promise<{ submitted: boolean }> {
    // ── Idempotency gate ──────────────────────────────────────────────────────
    const status = await this.distribution.checkAndMarkEventId(eventId, jobId);
    if (status === "COMPLETED" || status === "PROCESSING") {
      logger.info("[Transcription] Already handled — skipping submission", { jobId, status });
      return { submitted: false };
    }

    const t0 = Date.now();
    logger.info("[Transcription] Starting polling-based processing", { jobId });

    await EdgeLayer.updateStageSync(jobId, "queue", {
      status: "completed",
      progress: 100,
      completedAt: Date.now(),
    });

    await EdgeLayer.updateStageSync(jobId, "transcription", {
      status: "running",
      progress: 10,
      startedAt: Date.now(),
    });

    try {
      const apiKey = PIPELINE_CONFIG.ASSEMBLYAI_KEY;
      if (!apiKey) throw new Error("ASSEMBLY_AI_API_KEY is missing");
      const headers = { authorization: apiKey, "content-type": "application/json" };

      // 1. Extract audio
      const audioUrl = await this.extractAudio(jobId, videoUrl);
      const accessibleUrl = await this.getAccessibleUrl(audioUrl ?? videoUrl);

      // 2. Adaptive Diarization Check
      const shouldDiarize = await this.shouldEnableDiarization(jobId, userId, executionPlan);
      logger.info("[Transcription] Diarization decision", { jobId, shouldDiarize });

      // 3. Submit to AssemblyAI (v7.2: Enhanced with Creator Intelligence)
      const isAccuracyMode = executionPlan.priorityMode === "accuracy";
      const sub = await axios.post(
        `${ASSEMBLY_BASE}/transcript`,
        {
          audio_url: accessibleUrl,
          speech_models: isAccuracyMode ? ["universal-3-pro"] : ["universal-3-pro", "universal-2"], // Prefer premium model in accuracy mode
          speaker_labels: shouldDiarize,
          language_detection: !executionPlan.primaryLanguage, // Skip if language provided
          language_code: executionPlan.primaryLanguage,      // Inject creator language
          punctuate: true,
          format_text: true,
          boost_param: isAccuracyMode ? "high" : "default",   // v7.2 Priority Mode
          entity_detection: isAccuracyMode,                  // v7.2: Depth in accuracy mode
          content_safety: (executionPlan.sensitiveTopics?.length ?? 0) > 0, // Enable safety detection if topics selected
          auto_chapters: executionPlan.autoChapters ?? false, // ✅ v7.5: Native chapter generation
        },
        { headers }
      );

      const transcriptId = sub.data.id;
      logger.info("[Transcription] Job submitted, starting polling", { jobId, transcriptId });

      // 3. INDUSTRY STANDARD: Inline Polling Loop
      // We poll every 3 seconds for up to 8 minutes
      let attempts = 0;
      const maxAttempts = 160; 
      let assemblyResult: AssemblyResult | null = null;

      while (attempts < maxAttempts) {
        attempts++;
        const poll = await axios.get(`${ASSEMBLY_BASE}/transcript/${transcriptId}`, { headers });
        const res = poll.data as AssemblyResult;

        if (res.status === "completed") {
          assemblyResult = res;
          break;
        } else if (res.status === "error") {
          throw new Error(`AssemblyAI job failed: ${res.error}`);
        }

        // Simple progress simulation (30% -> 90%)
        const progress = Math.min(30 + attempts * 2, 90);
        await EdgeLayer.updateStageSync(jobId, "transcription", { status: "running", progress });

        await new Promise(resolve => setTimeout(resolve, 3000));
      }

      if (!assemblyResult) {
        throw new Error("Transcription timed out after 8 minutes");
      }

      // 4. Transform Result
      const utterances = assemblyResult.utterances && assemblyResult.utterances.length > 0
        ? assemblyResult.utterances.map((u, idx) => ({
            index: idx,
            text: u.text,
            start: u.start,
            end: u.end,
            duration: u.end - u.start,
            speaker: u.speaker,
            words: (u.words || []).map(w => ({
              text: w.text, start: w.start, end: w.end, confidence: w.confidence
            }))
          }))
        : this.buildSegmentsFromWords(assemblyResult.words ?? []);

      // CRITICAL FALLBACK: If both methods return nothing but text exists
      if (utterances.length === 0 && assemblyResult.text) {
        logger.warn("[Transcription] No utterances/words found. Creating virtual fallback segment.", { jobId });
        utterances.push({
          index: 0,
          text: assemblyResult.text,
          start: 0,
          end: (assemblyResult.audio_duration || 0) * 1000,
          duration: (assemblyResult.audio_duration || 0) * 1000,
          speaker: "speaker_0",
          words: []
        });
      }

      const enhanced: EnhancedTranscriptionResult = {
        jobId,
        language: assemblyResult.language_code ?? "en",
        detectedLanguage: assemblyResult.language_code ?? "en",
        text: assemblyResult.text ?? "",
        confidence: assemblyResult.confidence ?? 0.95,
        speakerConfidence: this.calculateSpeakerConfidence(assemblyResult),
        words: (assemblyResult.words ?? []).map(w => ({
          text: w.text, start: w.start, end: w.end, confidence: w.confidence, speaker: w.speaker
        })),
        segments: utterances,
        speakers: this.extractSpeakersFromUtterances(assemblyResult.utterances ?? []),
        chapters: (assemblyResult.chapters ?? []).map(c => ({
          startTimeMs: c.start,
          endTimeMs: c.end,
          title: c.headline,
          summary: c.summary
        })),
        duration: assemblyResult.audio_duration ?? 0,
      };

      logger.info("[Transcription] Transformation complete", {
        jobId,
        wordCount: enhanced.words.length,
        utteranceCount: enhanced.segments.length,
        hasNativeUtterances: !!assemblyResult.utterances?.length
      });

      // 5. Store & Propagate (Atomic completion)
      await this.storeTranscript(jobId, userId, enhanced);
      
      // Native Subtitles
      await this.fetchAndStoreNativeSubtitles(jobId, transcriptId, enhanced.detectedLanguage, apiKey);

      // Cost Tracking
      costEngine.recordTranscriptionCost(jobId, userId, enhanced.duration).catch(() => {});

      // 5. Gemini Video Moderation Gateway Check
      const gatewayDecision = await videoGatewayService.evaluateVideo(
        jobId,
        enhanced.text,
        enhanced.segments,
        executionPlan
      );

      // Resolve the canonical video document ID
      const jobSnap = await db().collection("video_jobs").doc(jobId).get();
      const jobData = jobSnap.data() as any;
      const targetVideoId = executionPlan.videoId || jobData?.videoId || (jobData?.linkedVideoIds?.[0]) || jobId;

      await db().collection("video_jobs").doc(jobId).set({
        gatewayDecision,
        updatedAt: Date.now()
      }, { merge: true });

      // HALT DOWNSTREAM PROCESSING IF REJECTED
      if (gatewayDecision.status === "REJECTED") {
        logger.warn("[Transcription Gateway] VIDEO REJECTED by Gateway — halting transcoding and publishing", {
          jobId,
          targetVideoId,
          rejectionReason: gatewayDecision.rejectionReason,
          violatingPolicies: gatewayDecision.violatingPolicies
        });
        await EdgeLayer.updateStageSync(jobId, "transcription", {
          status: "failed",
          error: `Video rejected by Gateway: ${gatewayDecision.rejectionReason}`
        });
        return { submitted: true }; // HALT
      }

      // HALT DOWNSTREAM PROCESSING IF MANUAL_REVIEW
      if (gatewayDecision.status === "MANUAL_REVIEW") {
        logger.warn("[Transcription Gateway] VIDEO SENT TO MANUAL REVIEW — queueing in Admin Portal & halting transcoding", {
          jobId,
          targetVideoId,
          reviewReason: gatewayDecision.reviewReason,
          sensitiveTopics: gatewayDecision.sensitiveTopics
        });
        await db().collection("admin_review_queue").doc(jobId).set({
          jobId,
          videoId: targetVideoId,
          userId,
          videoUrl,
          transcriptText: enhanced.text,
          gatewayDecision,
          queuedAt: Date.now(),
          status: "pending"
        });
        await EdgeLayer.updateStageSync(jobId, "transcription", {
          status: "completed",
          progress: 100
        });
        return { submitted: true }; // HALT UNTIL ADMIN APPROVAL
      }

      // ── APPROVED: PUBLISH VIDEO, THUMBNAIL & ALL METADATA TO FIRESTORE FIRST ──
      // Fetch existing video document to preserve all user-supplied metadata
      const existingVideoSnap = await db().collection("videos").doc(targetVideoId).get();
      const existingVideoData = existingVideoSnap.data() || {};

      const finalThumbnailUrl = existingVideoData.thumbnailUrl || (executionPlan as any).thumbnailUrl || (executionPlan as any).thumbnail || "";
      const finalChannelId = existingVideoData.channelId || (executionPlan as any).channelId || `channel_${userId}`;
      const finalChannelName = existingVideoData.channelName || (executionPlan as any).channelName || "Truthworld Channel";
      const finalChannelAvatarUrl = existingVideoData.channelImage || existingVideoData.channelAvatarUrl || (executionPlan as any).channelAvatarUrl || "";
      const finalCategory = existingVideoData.category || existingVideoData.videoCategory || gatewayDecision.category || "General";
      const finalTags = (existingVideoData.tags && existingVideoData.tags.length > 0)
        ? existingVideoData.tags
        : (gatewayDecision.tags || []);
      const finalTopics = (existingVideoData.topics && existingVideoData.topics.length > 0)
        ? existingVideoData.topics
        : ((gatewayDecision as any).topics || (executionPlan as any).topics || []);

      // Infer clean title if missing or defaulted to 'Untitled Video'
      let inferredTitle = (existingVideoData.title && existingVideoData.title !== "Uploading..." && existingVideoData.title.trim() !== "")
        ? existingVideoData.title
        : ((executionPlan as any).title || "");
      if (!inferredTitle || inferredTitle.trim() === "" || inferredTitle.toLowerCase().startsWith("untitled")) {
        if (gatewayDecision.autoChapters && gatewayDecision.autoChapters.length > 0 && gatewayDecision.autoChapters[0].title) {
          inferredTitle = gatewayDecision.autoChapters[0].title;
        } else if (gatewayDecision.summary && gatewayDecision.summary.length > 5) {
          inferredTitle = gatewayDecision.summary.length > 60 
            ? `${gatewayDecision.summary.substring(0, 57)}...` 
            : gatewayDecision.summary;
        } else {
          inferredTitle = "Truthworld Insight Video";
        }
      }

      const finalDescription = (existingVideoData.description && existingVideoData.description.trim() !== "")
        ? existingVideoData.description
        : ((executionPlan as any).description || gatewayDecision.summary || "");

      const bucketName = admin.storage().bucket().name;
      const directTranscriptUrl = `https://storage.googleapis.com/${bucketName}/transcripts/${jobId}/full.json`;
      const isFactCheckingEnabled = !!(executionPlan.enablePath1 || executionPlan.enableTruthEngine);
      const directFactCheckUrl = isFactCheckingEnabled
        ? `https://storage.googleapis.com/${bucketName}/factchecks/${jobId}/report.json`
        : "";
      const durationMs = Math.round((enhanced.duration || existingVideoData.duration || 60) * 1000);
      const httpVideoUrl = videoUrl.startsWith("gs://")
        ? `https://storage.googleapis.com/${bucketName}/${videoUrl.replace(`gs://${bucketName}/`, "")}`
        : (videoUrl || existingVideoData.videoUrl || "");

      const defaultAdaptiveResolutions = [
        { label: "1080p", url: httpVideoUrl, width: 1920, height: 1080, bitrate: 4500000 },
        { label: "720p", url: httpVideoUrl, width: 1280, height: 720, bitrate: 2500000 },
        { label: "480p", url: httpVideoUrl, width: 854, height: 480, bitrate: 1200000 },
        { label: "360p", url: httpVideoUrl, width: 640, height: 360, bitrate: 800000 }
      ];

      const publicationData = {
        id: targetVideoId,
        jobId: jobId,
        userId: userId,
        ownerId: userId,
        channelId: finalChannelId,
        channelName: finalChannelName,
        channelAvatarUrl: finalChannelAvatarUrl,
        originalUrl: httpVideoUrl,
        videoUrl: httpVideoUrl,
        hlsUrl: httpVideoUrl,
        dashUrl: httpVideoUrl,
        thumbnailUrl: finalThumbnailUrl,
        thumbnailVariants: finalThumbnailUrl ? [finalThumbnailUrl] : (existingVideoData.thumbnailVariants || []),
        animatedPreviewUrl: existingVideoData.animatedPreviewUrl || "",
        adaptiveResolutions: existingVideoData.adaptiveResolutions || defaultAdaptiveResolutions,
        title: inferredTitle,
        description: finalDescription,
        summary: gatewayDecision.summary || existingVideoData.summary || "",
        category: finalCategory,
        tags: finalTags,
        topics: finalTopics,
        language: enhanced.detectedLanguage || existingVideoData.language || "en",
        isShort: (enhanced.duration || existingVideoData.duration || 60) <= 60,
        isKidFriendly: existingVideoData.isKidFriendly || false,
        autoChapters: gatewayDecision.autoChapters || existingVideoData.autoChapters || [],
        durationMs: durationMs,
        duration: Math.round(enhanced.duration || existingVideoData.duration || 60),
        media: {
          subtitles: existingVideoData.media?.subtitles || existingVideoData.subtitles || {},
          dubbedVideos: existingVideoData.media?.dubbedVideos || existingVideoData.dubbedVideos || {},
          audioTracks: existingVideoData.media?.audioTracks || existingVideoData.audioTracks || {},
          factCheckUrl: directFactCheckUrl,
          transcriptionUrl: directTranscriptUrl,
        },
        subtitles: existingVideoData.subtitles || existingVideoData.media?.subtitles || {},
        audioTracks: existingVideoData.audioTracks || existingVideoData.media?.audioTracks || {},
        dubbedVideos: existingVideoData.dubbedVideos || existingVideoData.media?.dubbedVideos || {},
        factCheckUrl: directFactCheckUrl,
        transcriptionUrl: directTranscriptUrl,
        gatewayDecision,
        gatewayStatus: "APPROVED",
        isFactChecked: isFactCheckingEnabled,
        isVerified: true,
        trustScore: 100,
        trustLabel: "Verified Content",
        status: "published",
        visibility: existingVideoData.visibility || (executionPlan as any).visibility || "public",
        isPublished: true,
        metadataComplete: true,
        viewCount: existingVideoData.viewCount || existingVideoData.views || 0,
        likeCount: existingVideoData.likeCount || existingVideoData.likes || 0,
        dislikeCount: existingVideoData.dislikeCount || 0,
        commentCount: existingVideoData.commentCount || 0,
        shareCount: existingVideoData.shareCount || 0,
        totalWatchTimeSeconds: existingVideoData.totalWatchTimeSeconds || 0,
        likedBy: existingVideoData.likedBy || [],
        createdAt: existingVideoData.createdAt || Date.now(),
        uploadedAt: existingVideoData.uploadedAt || Date.now(),
        publishedAt: existingVideoData.publishedAt || Date.now(),
        updatedAt: Date.now()
      };

      // ── PARALLEL COPYRIGHT DETECTION AT STEP 4 ──
      const copyrightMatchResult = await copyrightDetectionService.detectCopyright({
        videoId: targetVideoId,
        ownerId: userId,
        channelId: (executionPlan as any).channelId || "unknown",
        md5Hash: null,
        transcript: enhanced.text,
        summary: gatewayDecision.summary || "",
        duration: enhanced.duration || 60,
        summaryEmbedding: [],
        transcriptHash: "",
        chunks: []
      }).catch((err: any) => {
        logger.warn("[Transcription Gateway] Parallel copyright detection warning", { err });
        return { hasMatch: false, matches: [] };
      });

      if (copyrightMatchResult.hasMatch && copyrightMatchResult.matches.length > 0) {
        const topMatch = copyrightMatchResult.matches[0];

        // Calculate total matched duration across segments (in seconds)
        const totalMatchedSeconds = (topMatch.matchedSegments || []).reduce(
          (sum: number, s: any) => sum + Math.max(0, (s.infringingEnd || 0) - (s.infringingStart || 0)), 0
        );

        const isExactMd5 = topMatch.matchType === "exact_md5";
        
        // ── INDUSTRY STANDARD ACCEPTABLE LIMITS ──
        // 1. Clips under 15 seconds used for quotes/commentary are acceptable Fair Use
        // 2. Substantial matches (>= 15 seconds or exact MD5) trigger Step 4 Copyright Hold
        const isAcceptableFairUse = !isExactMd5 && (totalMatchedSeconds > 0 && totalMatchedSeconds <= 15);

        if (isExactMd5 || (topMatch.score >= 0.70 && !isAcceptableFairUse)) {
          logger.warn(`🛑 [Copyright Gateway] Substantial Copyright Match (score: ${topMatch.score}, duration: ${totalMatchedSeconds}s). Pausing Step 4 & notifying copyright owner.`, { topMatch });

          await copyrightClaimsService.handleStep4CopyrightMatch(
            jobId,
            targetVideoId,
            userId,
            (executionPlan as any).channelId || "unknown",
            publicationData.title,
            finalThumbnailUrl,
            topMatch
          );

          return { submitted: true }; // PAUSE PIPELINE AT STEP 4 FOR COPYRIGHT OWNER DECISION
        } else {
          logger.info(`🟢 [Copyright Gateway] Copyright match within Industry Standard Acceptable Limits (duration: ${totalMatchedSeconds}s, score: ${topMatch.score}). Auto-cleared as Fair Use.`);
        }
      }

      // Write & Await Firestore Publish Completion
      await Promise.all([
        db().collection("videos").doc(targetVideoId).set(publicationData, { merge: true }),
        db().collection("video_jobs").doc(jobId).set({
          gatewayDecision,
          status: "published",
          metadataComplete: true,
          publishedAt: Date.now(),
          updatedAt: Date.now()
        }, { merge: true })
      ]);

      // VERIFY Firestore Publication Succeeded Before Triggering Downstream Services
      const verifySnap = await db().collection("videos").doc(targetVideoId).get();
      if (!verifySnap.exists || !verifySnap.data()?.isPublished) {
        throw new Error(`[Transcription Gateway] Firestore video publishing failed for videoId: ${targetVideoId}. Downstream jobs aborted.`);
      }

      logger.info(`[Transcription Gateway] Video, thumbnail & metadata SUCCESSFULLY PUBLISHED into Firestore for videoId: ${targetVideoId}. Now initiating downstream resolutions and AI feature services.`, {
        videoId: targetVideoId,
        category: gatewayDecision.category,
        thumbnailUrl: finalThumbnailUrl
      });

      // ── NOW (AND ONLY NOW) TRIGGER DOWNSTREAM RESOLUTION TRANSCODING & AI FEATURES ──
      await aggregationLayer.onStageComplete(jobId, "transcription", userId, executionPlan);

      // Fan-out immediately (Fact-checking, Dubbing, Transcoding, and Copyright)
      const fanoutTasks: Promise<any>[] = [];
      
      // Fan-out to copyright check (always required)
      fanoutTasks.push(this.distribution.publish("copyright-processing" as any, {
        eventId: `copy_${jobId}`,
        eventType: "copyright-processing" as any,
        jobId, userId,
        timestamp: Date.now(),
        data: { videoUrl, executionPlan },
        retryCount: 0,
        source: "transcription-polling"
      }));

      // ── AFTER STEP 4: TRIGGER ONLY FEATURES REQUESTED BY THE CHANNEL ──

      // 1. Credibility Feature (Fact Checking & 3D Trust Score)
      const shouldRunCredibility = !!(
        executionPlan.enablePath1 ||
        executionPlan.enableTruthEngine ||
        (executionPlan as any).enableCredibility ||
        (executionPlan as any).enableFactChecking
      );

      if (shouldRunCredibility) {
        logger.info(`[Transcription Gateway] Channel requested CREDIBILITY feature for job ${jobId} — launching fact-processing`);
        fanoutTasks.push(this.distribution.publish("fact-processing", {
          eventId: `fact_${jobId}`,
          eventType: "fact-processing",
          jobId, userId,
          timestamp: Date.now(),
          data: { executionPlan },
          retryCount: 0,
          source: "transcription-polling"
        }));
      } else {
        logger.info(`[Transcription Gateway] Credibility feature NOT requested by channel for job ${jobId} — skipping fact-checking`);
      }

      // 2. Multi-Resolution Video Transcoding (1040p, 720p, 480p, 360p) & Reach Engine — ALWAYS REQUIRED for Approved Videos
      logger.info(`[Transcription Gateway] Video approved & published in Firestore — ALWAYS launching multi-resolution transcoding (1040p, 720p, 480p, 360p) for job ${jobId}`);
      fanoutTasks.push(this.distribution.publish("dubbing-processing", {
        eventId: `dub_${jobId}`,
        eventType: "dubbing-processing",
        jobId, userId,
        timestamp: Date.now(),
        data: { videoUrl, executionPlan },
        retryCount: 0,
        source: "transcription-polling"
      }));

      await Promise.all(fanoutTasks);
      await this.distribution.markEventCompleted(eventId);

      logger.info("[Transcription] Polling flow completed successfully", { 
        jobId, 
        duration: Date.now() - t0,
        attempts 
      });

      return { submitted: true };

    } catch (error) {
      let msg = error instanceof Error ? error.message : String(error);
      if (axios.isAxiosError(error)) {
        const details = JSON.stringify(error.response?.data);
        msg = `AssemblyAI API Error: ${details || error.message}`;
      }
      await EdgeLayer.failJob(jobId, "transcription", msg);
      throw error;
    }
  }

  // Webhook handler removed as per polling migration logic (redundant)
  async processTranscriptionResult(jobId: string, userId: string, transcriptId: string): Promise<void> {
    logger.warn("[Transcription] Webhook hit but logic migrated to polling. Ignoring.", { jobId });
  }

  async processWebhook(jobId: string, eventId: string, transcriptId: string, status: string, error?: string): Promise<void> {
    logger.warn("[Transcription] Webhook processWebhook hit but logic migrated to polling. Ignoring.", { jobId, eventId, transcriptId, status, error });
  }

  // ─── Native Subtitle Export ─────────────────────────────────────────────────

  /**
   * ✅ NEW: Fetch native SRT + VTT subtitles from AssemblyAI.
   *
   * These use the provider's own timestamps — more accurate than manual generation.
   * Stored as the SOURCE LANGUAGE subtitles.
   * Translated subtitles will use our own alignment pipeline (07-dubbing).
   */
  private async fetchAndStoreNativeSubtitles(
    jobId: string,
    transcriptId: string,
    language: string,
    apiKey: string
  ): Promise<void> {
    const headers = { authorization: apiKey };
    const bucket = admin.storage().bucket();

    try {
      // Fetch SRT
      const srtResp = await axios.get(
        `${ASSEMBLY_BASE}/transcript/${transcriptId}/srt`,
        { headers, params: { chars_per_caption: 42 } }
      );

      // Fetch VTT
      const vttResp = await axios.get(
        `${ASSEMBLY_BASE}/transcript/${transcriptId}/vtt`,
        { headers, params: { chars_per_caption: 42 } }
      );

      // Store SRT
      const srtPath = `subtitles/${jobId}/${language}.srt`;
      await bucket.file(srtPath).save("\uFEFF" + srtResp.data, {
        metadata: { contentType: "text/plain; charset=utf-8" },
      });

      // Store VTT
      const vttPath = `subtitles/${jobId}/${language}.vtt`;
      await bucket.file(vttPath).save("\uFEFF" + vttResp.data, {
        metadata: { contentType: "text/vtt; charset=utf-8" },
      });

      const jsonPath = `subtitles/${jobId}/${language}.json`;

      // Update job outputs doc (separate collections for scale check)
      await db().collection("job_outputs").doc(jobId).set({
        subtitles: {
          [language]: {
            srtPath: `gs://${bucket.name}/${srtPath}`,
            vttPath: `gs://${bucket.name}/${vttPath}`,
            jsonPath: `gs://${bucket.name}/${jsonPath}`,
            format: "native",
            provider: "assemblyai-universal-multi",
            createdAt: Date.now(),
          }
        }
      }, { merge: true });

      // Update job doc with lightweight artifact metadata
      await db().collection("video_jobs").doc(jobId).update({
        // ✅ NEW SCHEMA: Consolidated Artifact Registry
        "artifacts.transcription.srtUrl": `gs://${bucket.name}/${srtPath}`,
        "artifacts.transcription.vttUrl": `gs://${bucket.name}/${vttPath}`,
        "artifacts.transcription.jsonUrl": `gs://${bucket.name}/${jsonPath}`,
        "artifacts.transcription.sourceLanguage": language,
      });

      // Propagate native subtitles directly to linked video documents
      try {
        const directSrtUrl = `https://storage.googleapis.com/${bucket.name}/${srtPath}`;
        const jobSnap = await db().collection("video_jobs").doc(jobId).get();
        const jobData = jobSnap.data() as any;
        const linkedVideoIds: string[] = jobData?.linkedVideoIds || [];
        if (jobData?.videoId && !linkedVideoIds.includes(jobData.videoId)) {
          linkedVideoIds.push(jobData.videoId);
        }
        for (const vid of linkedVideoIds) {
          await db().collection("videos").doc(vid).set({
            subtitles: {
              [language]: directSrtUrl,
            },
            media: {
              subtitles: {
                [language]: directSrtUrl,
              }
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      } catch (propErr) {
        logger.warn("[Transcription] Failed to propagate native subtitles to video docs", { jobId, err: String(propErr) });
      }

      logger.info("[Transcription] Native SRT/VTT subtitles stored", {
        jobId,
        language,
        srtPath,
        vttPath,
      });
    } catch (error) {
      // Non-fatal: subtitles can be regenerated from transcript if needed
      logger.warn("[Transcription] Failed to fetch native subtitles — will use fallback", {
        jobId,
        error: String(error),
      });
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  private buildSegmentsFromWords(words: any[]): TimedSegment[] {
    return this.buildSegments(words.map(w => ({
      text: w.text, start: w.start, end: w.end, confidence: w.confidence, speaker: w.speaker
    })));
  }

  private extractSpeakersFromUtterances(utterances: any[]): SpeakerInfo[] {
    const map = new Map<string, { totalDuration: number; segments: number[] }>();
    utterances.forEach((u, idx) => {
      const id = u.speaker ?? "speaker_0";
      if (!map.has(id)) map.set(id, { totalDuration: 0, segments: [] });
      const info = map.get(id)!;
      info.totalDuration += (u.end - u.start);
      info.segments.push(idx);
    });
    return Array.from(map.entries()).map(([id, info]) => ({
      speakerId: id, label: id, totalDuration: info.totalDuration, segments: info.segments
    }));
  }

  // ─── Formatting Helpers ─────────────────────────────────────────────────────

  private buildSegments(words: WordTimestamp[], targetMs = 4000): TimedSegment[] {
    if (words.length === 0) return [];
    const segs: TimedSegment[] = [];
    let buf: WordTimestamp[] = [];
    let segStart = words[0].start;
    let idx = 0;

    for (const w of words) {
      buf.push(w);
      if (w.end - segStart >= targetMs) {
        segs.push({
          index: idx++,
          text: buf.map((x) => x.text).join(" "),
          start: segStart,
          end: w.end,
          duration: w.end - segStart,
          speaker: buf[0].speaker,
          words: [...buf],
        });
        buf = [];
        segStart = w.end;
      }
    }

    if (buf.length > 0) {
      const last = buf[buf.length - 1];
      segs.push({
        index: idx,
        text: buf.map((x) => x.text).join(" "),
        start: segStart,
        end: last.end,
        duration: last.end - segStart,
        speaker: buf[0].speaker,
        words: [...buf],
      });
    }

    return segs;
  }

  // ─── Storage ─────────────────────────────────────────────────────────────────

  private async storeTranscript(
    jobId: string,
    userId: string,
    result: EnhancedTranscriptionResult
  ): Promise<void> {
    // Lightweight Firestore doc (no large arrays — avoids 1MB doc limit)
    await db().collection("transcripts").doc(jobId).set({
      jobId, userId,
      text: result.text,
      language: result.detectedLanguage,
      confidence: result.confidence,
      speakerConfidence: result.speakerConfidence,
      isMultiSpeaker: result.speakers.length > 1,
      wordCount: result.words.length,
      segmentCount: result.segments.length,
      speakerCount: result.speakers.length,
      duration: result.duration,
      chapters: result.chapters || [], // ✅ Store chapters in Firestore summary
      model: "universal-3-pro, universal-2",
      createdAt: Date.now(),
      // Store compact utterance summary (not full word array)
      utterances: result.segments.map((s) => ({
        start: s.start,
        end: s.end,
        text: s.text,
        speaker: s.speaker,
      })),
    });

    // Full result in Cloud Storage (avoids Firestore 1MB doc limit)
    const bucket = admin.storage().bucket();
    const jsonPath = `transcripts/${jobId}/full.json`;
    await bucket.file(jsonPath).save(
      JSON.stringify(result),
      { metadata: { contentType: "application/json" } }
    );

    // Update job doc with transcript path (Dual-write)
    await db().collection("video_jobs").doc(jobId).update({
      "artifacts.transcription.jsonUrl": `gs://${bucket.name}/${jsonPath}`,
      "artifacts.transcription.sourceLanguage": result.detectedLanguage,
      updatedAt: Date.now(),
    });
  }

  private async extractAudio(jobId: string, videoUrl: string): Promise<string | null> {
    const url = PIPELINE_CONFIG.FFMPEG_SERVICE_URL;
    if (!url) return null;
    try {
      const resp = await axios.post(
        `${url}/extract-audio`,
        { videoUrl, outputPath: `audio/${jobId}/extracted.wav`, format: "wav" },
        { timeout: 120_000 }
      );
      return resp.data.audioUrl as string;
    } catch (err) {
      logger.warn("[Transcription] Audio extraction failed — falling back to video URL", { err });
      return null;
    }
  }

  private async getAccessibleUrl(url: string): Promise<string> {
    logger.info("[Transcription] Resolving accessible URL", { url });
    
    // 1. If it's already an HTTP(S) URL, return it
    if (url.startsWith("http")) return url;

    try {
      let bucketName = PIPELINE_CONFIG.VIDEO_BUCKET;
      let filePath = url;

      // 2. If it's a gs:// project path, parse it
      if (url.startsWith("gs://")) {
        const parts = url.replace("gs://", "").split("/");
        bucketName = parts[0];
        filePath = parts.slice(1).join("/");
      }

      const bucket = admin.storage().bucket(bucketName);
      const file = bucket.file(filePath);

      // Verify file exists
      const [exists] = await file.exists();
      if (!exists) {
        throw new Error(`File not found in bucket: ${bucketName}/${filePath}`);
      }

      // Generate a signed URL valid for 2 hours
      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 1000 * 60 * 60 * 2,
      });

      return signedUrl;
    } catch (err) {
      logger.error("[Transcription] Critical failure in URL signing", { url, error: String(err) });
      
      // Final Fallback: Try to construct a public download URL if bucket is public (risky)
      // or just re-throw so the stage fails clearly
      throw new Error(`Could not generate accessible URL for AssemblyAI: ${String(err)}`);
    }
  }

  /**
   * 🧠 ADAPTIVE DIARIZATION LOGIC
   * Rule-based selection to balance cost, accuracy, and latency.
   */
  private async shouldEnableDiarization(jobId: string, userId: string, plan: ExecutionPlan): Promise<boolean> {
    const duration = plan.duration ?? 0;
    const channelType = plan.channelType || "standard";


    // v7.3: Fetch creator reputation for metadata threshold routing
    const reputation = await reputationService.getReputation(userId);
    const reliability = reputation?.metadataReliability?.overall ?? 0.8; // Default to 0.8 for new creators
    const isHighTrust = reliability >= 0.9;

    // 0. NEW: Creator Intelligence Input (Primary Signal v7)
    if (plan.expectedSpeakerCount === "1") {
      // Trust "1" implicitly if high trust or typical duration
      if (isHighTrust || duration < 300) {
        logger.info("[Transcription] High-trust solo routing", { jobId, reliability });
        return false;
      }
    }
    
    if (["2-3", "4+"].includes(plan.expectedSpeakerCount || "")) {
      logger.info("[Transcription] Creator specified multiple speakers — enabling diarization", { jobId, count: plan.expectedSpeakerCount });
      return true;
    }

    // 0.5. Strategic Content Formats (Always ON)
    if (["podcast", "interview", "debate"].includes(plan.contentFormat || "")) {
      logger.info("[Transcription] Strategic content format detected — enabling diarization", { jobId, format: plan.contentFormat });
      return true;
    }

    // 1. Strategic Categories (Always ON)
    // We try to fetch the channel category to see if it's high-probability for multi-speaker
    try {
      const channelSnap = await db().collection("channels").where("ownerId", "==", userId).limit(1).get();
      if (!channelSnap.empty) {
        const category = channelSnap.docs[0].data()?.profile?.category?.toLowerCase() || "";
        const strategic = ["podcast", "interview", "debate", "news", "talk show", "panel"];
        if (strategic.some(s => category.includes(s))) {
          logger.info("[Transcription] Strategic category detected — enabling diarization", { jobId, category });
          return true;
        }
      }
    } catch (err) {
      logger.warn("[Transcription] Failed to fetch channel category for diarization logic", { userId });
    }

    // 2. Premium Tiers (Always ON)
    // 2. Custom Channels (Always ON)
    if (channelType === "custom") {
      return true;
    }


    // 3. Adaptive Thresholds
    if (duration < 45) {
      return false; // Shorts/Reels: OFF
    }
    
    if (duration > 90) {
      return true; // Long-form: ON
    }

    // 4. Mid-form (45s - 90s): OFF for Standard (Save cost)
    if (channelType === "standard") {
      return false;
    }

    return true;
  }

  private calculateSpeakerConfidence(res: AssemblyResult): number {
    if (!res.utterances || res.utterances.length === 0) return 0;
    
    // Average confidence across all utterances
    const sum = res.utterances.reduce((acc, u) => acc + (u.confidence || 0), 0);
    return Number((sum / res.utterances.length).toFixed(2));
  }

}

// ─── Internal type alias ──────────────────────────────────────────────────────

interface AssemblyResult {
  id: string;
  status: string;
  text?: string;
  language_code?: string;
  audio_duration?: number;
  confidence?: number;
  words?: Array<{ start: number; end: number; text: string; confidence: number; speaker?: string }>;
  utterances?: Array<{ start: number; end: number; text: string; confidence: number; speaker: string; words?: Array<{ start: number; end: number; text: string; confidence: number }> }>;
  error?: string;
  chapters?: Array<{
    start: number;
    end: number;
    headline: string;
    summary: string;
    gist: string;
  }>;
}

export const transcriptionLayer = new TranscriptionLayer();
