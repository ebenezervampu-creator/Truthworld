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

      // 5. Atomic completion & Fan-out check
      await aggregationLayer.onStageComplete(jobId, "transcription", userId, executionPlan);

      // 6. Fan-out immediately (Fact-checking only)
      // Path 2 (Dubbing) is now reactive via index.ts (onVideoPublished trigger)
      const fanoutTasks: Promise<any>[] = [];
      if (executionPlan.enablePath1) {
        fanoutTasks.push(this.distribution.publish("fact-processing", {
          eventId: `fact_${jobId}`,
          eventType: "fact-processing",
          jobId, userId,
          timestamp: Date.now(),
          data: { executionPlan },
          retryCount: 0,
          source: "transcription-polling"
        }));
      }

      // Restore Path 2 (ReachEngine) fan-out for immediate processing
      if (executionPlan.enablePath2 || executionPlan.enableReachEngine) {
        fanoutTasks.push(this.distribution.publish("dubbing-processing", {
          eventId: `dub_${jobId}`,
          eventType: "dubbing-processing",
          jobId, userId,
          timestamp: Date.now(),
          data: { videoUrl, executionPlan },
          retryCount: 0,
          source: "transcription-polling"
        }));
      }

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

      // Update job outputs doc (separate collections for scale check)
      await db().collection("job_outputs").doc(jobId).set({
        subtitles: {
          [language]: {
            srtPath: `gs://${bucket.name}/${srtPath}`,
            vttPath: `gs://${bucket.name}/${vttPath}`,
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
        "artifacts.transcription.sourceLanguage": language,
      });

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
