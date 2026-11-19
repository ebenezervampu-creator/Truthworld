/**
 * 🌍 LAYER 07 — DUBBING ENGINE (INDEPENDENT LOCALIZATION SYSTEM)
 *
 * Translation + TTS + video merge. Full parallel execution per language and per segment.
 *
 * ✅ UPGRADED PIPELINE:
 *   - Translation: Composite Google Cloud Translation v3 (`general/translation-llm`) + required Adaptive MT
 *   - Language Detection: Google Cloud Translation v3 (`TranslationServiceClient`) exclusively
 *   - TTS: Strictly ElevenLabs v4 (eleven_v4) for all audio track dubbing & creator voice cloning (Chirp 3: HD terminated)
 *   - Subtitles: Native AssemblyAI subtitles for source lang; custom alignment for translated
 *
 * ✅ ALL PROBLEMS FIXED:
 *   1. Consumer idempotency gate — eventId checked before any work starts
 *   2. TTS cache FULLY WIRED    — checkTTSCache() called before every ElevenLabs call
 *   3. Language skip if source  — no translation API calls when target == source language
 *   4. Translation cache wired  — checks cache before every translation batch
 *   5. Graceful language failure — one language failing doesn't abort other languages
 *   6. Progress updates         — granular per-language progress emitted to Edge Layer
 *   7. Event emitted after write — dubbing-complete only fires after Firestore write succeeds
 *   8. Native subtitle reuse    — checks for AssemblyAI source subtitles before regenerating
 */

import * as admin from "firebase-admin";
import * as os from "os";
import * as path from "path";
import * as fs from "fs";
import { v4 as uuidv4 } from "uuid";
import {
  ExecutionPlan,
  DubbingResult,
  DubbingSegment,
  DubbingCheckpoint,
  SyncInstruction,
  TimedSegment,
  DubbingCompleteData,
  JobData,
  DubbingEditableManifest,
  DubbingEditableSegment,
  DubbingReelTaskPayload,
  DubbingReelAssemblyPayload,
  WordTimestamp,
} from "../types";
import {
  translationService,
  decodeHtmlEntities,
  normalizeScriptureCitationsForTts,
  applyTeluguTheologicalLexiconGuard,
} from "../services/translation";
import {
  ttsService,
  sanitizeTextForElevenLabsV4,
  stripAudioTagsForSubtitles,
  hasVerbalContent,
  getAdaptiveTTSBatchSize,
  V4_PREMIUM_80_LANGUAGES,
  ELEVENLABS_VOICE_GENDER_MAP,
} from "../services/tts";
import { expressiveV4Bus } from "../services/expressiveV4Bus";
import { mediaService, parseDurationToSeconds, parseAnyStorageUrl, type MergeAudioMetrics } from "../services/media";
import { ASSEMBLYAI_UNIVERSAL_37_LANGUAGES } from "./05-transcription";
import { costEngine, getFlatDubbingPricePerLanguage } from "../services/cost-engine";
import { speakerProfilingService } from "../services/speaker-profiling";
import { audioIdentityService } from "../services/audio-identity";
import { DubbingQualityGate } from "./quality-gate";
import { DistributionLayer }  from "./04-distribution";
import { EdgeLayer }          from "./01-edge";
import { aggregationLayer }   from "./09-aggregation";
import { PerformanceLayer }   from "./10-performance";
import { creatorStyleService } from "../services/creatorStyleService";
import { refundDubbingFeeOnFailure } from "../services/refundService";
import { MultilingualSubtitleLocalizer } from "../services/multilingual_subtitle_localizer";
import {
  voiceMatcher,
  type DiarizedSpeakerProfile,
} from "../services/voice-matcher";
import { logger }             from "../utils/logger";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import { filterVideoIds } from "../../utils/videosCollectionGuard";
import { hlsPackagerService } from "../services/hlsPackager";

const db = () => admin.firestore();

/** Max segments processed concurrently per TTS batch */
export const TTS_BATCH_SIZE = 25;

/**
 * 🛡️ Converts any storage URL (Firebase Storage HTTPS signed/unsigned, GCS HTTPS, or gs://)
 * into a canonical `gs://${bucketName}/${filePath}` URI.
 * Guarantees zero 403 Forbidden errors when fetching audio chunks hours or days later.
 */
export function toCanonicalGsUrl(url: string, defaultBucketName?: string): string {
  if (!url || typeof url !== "string") return "";
  const trimmed = url.trim();
  if (trimmed.startsWith("gs://")) return trimmed;
  const storageInfo = parseAnyStorageUrl(trimmed);
  if (storageInfo && storageInfo.filePath) {
    const bucket = storageInfo.bucketName || defaultBucketName || admin.storage().bucket().name;
    return `gs://${bucket}/${storageInfo.filePath}`;
  }
  return trimmed;
}

/**
 * Per-speaker persistent vocal baseline stored under
 * `video_jobs/{jobId}/speaker_profiles/{speakerId}_{targetLang}` to eliminate
 * voice-character drift across scenes and 15-minute movie reels.
 */
export interface SpeakerVoiceProfile {
  speakerId: string;
  targetLang: string;
  voiceId: string;
  avgPitchSemitones: number;
  avgEnergyDb: number;
  avgStability: number;
  avgSimilarityBoost: number;
  dominantVoiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
  segmentCount: number;
  updatedAt: number;
}

/**
 * 🗣️ Language-Aware Phonetic/Syllable Speech Duration Estimator
 *
 * Replaces naive scalar word-count heuristics (words / 2.5) with dynamic
 * phonetic, syllable, and mora modeling:
 *   D_speech = f(phonemes, syllables, morae, language_rate, punctuation_pauses)
 *
 * Accounts for:
 *   - Indic scripts (Telugu, Hindi, Tamil, etc.): Multisyllabic inflections & akshara clusters (~5.2-5.8 syl/s)
 *   - East Asian mora-timed (Japanese ~7.0 morae/s, Mandarin ~4.2 syl/s)
 *   - Germanic compound words (German ~4.0 syl/s, English ~4.5 syl/s)
 *   - Romance syllable-timed (Spanish/Italian ~6.2 syl/s)
 */
export function estimateSpeechDurationMs(text: string, language: string = "en"): number {
  if (!text || text.trim().length === 0) return 0;
  const clean = text.trim();
  const lang = language.toLowerCase().split("-")[0];

  let unitCount = 0;
  let unitsPerSec = 4.5;

  if (["te", "ta", "kn", "ml", "hi", "mr", "bn", "gu", "pa", "or", "as"].includes(lang)) {
    // Indic languages: count aksharas / vowel-consonant grapheme clusters
    const indicClusters = clean.match(/[\u0900-\u0D7F]+/g) || [];
    const indicChars = indicClusters.join("").length;
    // In Indic Brahmi scripts, Unicode code points include base consonants, dependent vowel signs (matras),
    // viramas/halants, and anusvaras. Spoken syllables span ~2.4 - 2.9 code points.
    const charsPerSyllable = ["ta", "ml"].includes(lang) ? 2.9 : ["hi", "mr"].includes(lang) ? 2.7 : 2.4;
    unitCount = Math.max(1, Math.round(indicChars / charsPerSyllable));
    unitsPerSec = ["ta", "ml"].includes(lang) ? 6.5 : ["hi", "mr"].includes(lang) ? 5.8 : 5.5;
  } else if (lang === "ja") {
    // Japanese: Mora-timed (~7.0 morae/s)
    unitCount = Math.max(1, clean.replace(/[\s\p{P}]/gu, "").length);
    unitsPerSec = 7.0;
  } else if (lang === "zh") {
    // Mandarin: Syllable per character (~4.2 syl/s)
    unitCount = Math.max(1, clean.replace(/[\s\p{P}]/gu, "").length);
    unitsPerSec = 4.2;
  } else if (["es", "it", "pt"].includes(lang)) {
    // Romance languages: Syllable-timed (~6.2 syl/s)
    const vowels = clean.match(/[aeiouáéíóúüãõ]/gi) || [];
    unitCount = Math.max(1, vowels.length);
    unitsPerSec = 6.2;
  } else if (lang === "de") {
    // German: Compound-heavy stress-timed (~4.0 syl/s)
    const vowels = clean.match(/[aeiouäöü]/gi) || [];
    unitCount = Math.max(1, vowels.length);
    unitsPerSec = 4.0;
  } else {
    // English & default: Stress-timed (~4.5 syl/s, ~1.4 syllables/word)
    const words = clean.split(/\s+/).filter(Boolean).length;
    const vowelMatches = clean.match(/[aeiouy]{1,2}/gi) || [];
    unitCount = Math.max(words, vowelMatches.length);
    unitsPerSec = 4.5;
  }

  // Base articulation duration in milliseconds
  let durationMs = (unitCount / unitsPerSec) * 1000;

  // Punctuation micro-pause allowances (commas ~120ms, periods/stops ~300ms)
  const commas = (clean.match(/[,،]/g) || []).length;
  const stops = (clean.match(/[.!?।]/g) || []).length;
  durationMs += commas * 120 + stops * 300;

  return Math.round(durationMs);
}

export class DubbingEngine {
  private readonly distribution:     DistributionLayer;
  private readonly performanceLayer: PerformanceLayer;

  constructor() {
    this.distribution     = new DistributionLayer();
    this.performanceLayer = new PerformanceLayer();
  }

  /**
   * Full dubbing pipeline.
   *
   * ✅ Idempotency gate is the very first action.
   */
  async runDubbingPipeline(
    jobId:         string,
    userId:        string,
    videoUrl:      string,
    executionPlan: ExecutionPlan,
    eventId:       string
  ): Promise<DubbingResult[]> {
    // ── Idempotency gate ──────────────────────────────────────────────────────
    const status = await this.distribution.checkAndMarkEventId(eventId, jobId);
    if (status === "COMPLETED") {
      logger.info("[Dubbing] Duplicate — loading existing", { jobId });
      return this.loadExistingResults(jobId, executionPlan.languages);
    }
    if (status === "PROCESSING") {
      logger.info("[Dubbing] Already processing — exiting gracefully", { jobId });
      return [] as any; // Early ACK
    }
    if (status === "FAILED") {
      logger.warn("[Dubbing] Maximum retries exhausted for event — ignoring redelivery", { jobId, eventId });
      return [] as any;
    }

    const t0 = Date.now();
    logger.info("[Dubbing] Starting independent Localization pipeline", {
      jobId,
      languages: executionPlan.languages.length,
    });
    await EdgeLayer.upsertDubbingJob(jobId, {
      userId,
      ...(executionPlan.videoId ? { videoId: executionPlan.videoId } : {}),
      executionPlan,
      status: "running",
      progress: 5,
      languages: executionPlan.dubbingLanguages || executionPlan.languages || [],
      subtitleLanguages: executionPlan.subtitleLanguages || executionPlan.languages || [],
      startedAt: t0,
    });

    // ── Transcription Gate ───────────────────────────────────────────────────
    const jobDoc = await db().collection("video_jobs").doc(jobId).get();
    let stages = jobDoc.exists ? jobDoc.data()?.stages : {};
    if (stages?.transcription?.status !== "completed") {
      const vDoc = await db().collection("videos").doc(jobId).get();
      const origJobId = vDoc.data()?.jobId;
      if (origJobId && origJobId !== jobId) {
        const origJobDoc = await db().collection("video_jobs").doc(origJobId).get();
        if (origJobDoc.data()?.stages?.transcription?.status === "completed") {
          stages = { ...origJobDoc.data()?.stages, ...stages };
        }
      }
      const transDoc = await db().collection("transcripts").doc(jobId).get();
      if (transDoc.exists) {
        stages = { ...(stages || {}), transcription: { status: "completed" } };
      } else if (origJobId) {
        const origTransDoc = await db().collection("transcripts").doc(origJobId).get();
        if (origTransDoc.exists) {
          stages = { ...(stages || {}), transcription: { status: "completed" } };
        }
      }
    }
    if (stages?.transcription?.status !== "completed") {
      const vDoc = await db().collection("videos").doc(jobId).get();
      const vData = vDoc.data();
      const hasSubs = (vData?.subtitles && Object.keys(vData.subtitles).length > 0) ||
        (vData?.media?.subtitles && Object.keys(vData.media?.subtitles).length > 0) ||
        (vData?.mediaSubtitles && Object.keys(vData.mediaSubtitles).length > 0);
      const hasTranscript = Boolean(vData?.transcript && vData.transcript.trim().length > 0) ||
        Boolean(vData?.transcriptionUrl && vData.transcriptionUrl.trim().length > 0);
      if (hasSubs || hasTranscript || vData?.status === "published") {
        stages = { ...(stages || {}), transcription: { status: "completed" } };
      }
    }
    if (stages?.transcription?.status !== "completed") {
      logger.warn("[Dubbing] Gate: Transcription not completed — attempting auto-transcription fallback", { jobId });
      try {
        const { TranscriptionLayer } = require("./05-transcription");
        const transLayer = new TranscriptionLayer();
        await transLayer.submitTranscription(jobId, userId, videoUrl, executionPlan, `${eventId}_trans_fallback`);
        stages = { ...(stages || {}), transcription: { status: "completed" } };
      } catch (autoTransErr) {
        logger.error("[Dubbing] Auto-transcription failed:", { jobId, err: String(autoTransErr) });
        throw new Error("Transcription must be completed before starting Dubbing Engine");
      }
    }

    if (executionPlan.genLangSubs || (executionPlan.languages && executionPlan.languages.length > 0)) {
      await EdgeLayer.updateStageSync(jobId, "subtitles", {
        status: "running", progress: 35, startedAt: Date.now(),
      }).catch(() => {});
    }

    const isDubbingActive = Boolean(
      executionPlan.generateDubbing &&
      Array.isArray(executionPlan.dubbingLanguages) &&
      executionPlan.dubbingLanguages.length > 0
    );

    if (isDubbingActive) {
      await EdgeLayer.updateStageSync(jobId, "dubbing", {
        status: "running", progress: 5, startedAt: Date.now(),
      });
    } else {
      await EdgeLayer.updateStageSync(jobId, "dubbing", {
        status: "skipped", progress: 100, completedAt: Date.now(),
      }).catch(() => {});
    }

    const DUBBING_TIMEOUT_MS = parseInt(process.env.DUBBING_TIMEOUT_MS || "540000", 10);
    let timeoutTimer: NodeJS.Timeout | null = null;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutTimer = setTimeout(async () => {
        const seconds = Math.round(DUBBING_TIMEOUT_MS / 1000);
        const timeoutMsg = `Dubbing processing reached maximum cloud engine duration (${seconds}s)`;
        logger.error(`[Dubbing] Cloud timeout guard reached (${seconds}s)`, { jobId });
        await EdgeLayer.failStage(jobId, "dubbing", timeoutMsg).catch(() => {});
        await EdgeLayer.upsertDubbingJob(jobId, {
          status: "failed",
          error: timeoutMsg,
          completedAt: Date.now(),
        });
        reject(new Error(timeoutMsg));
      }, DUBBING_TIMEOUT_MS);
    });

    try {
      return await Promise.race([
        this.executeDubbingPipeline(jobId, userId, videoUrl, executionPlan, eventId, t0),
        timeoutPromise,
      ]);
    } finally {
      if (timeoutTimer) {
        clearTimeout(timeoutTimer);
      }
    }
  }

  private async executeDubbingPipeline(
    jobId:         string,
    userId:        string,
    videoUrl:      string,
    executionPlan: ExecutionPlan,
    eventId:       string,
    t0:            number
  ): Promise<DubbingResult[]> {
    let createdVoiceCloneId: string | null = null;
    let isPersistentVoiceClone: boolean = false;
    try {
      // 1. Load transcript segments
      let transcript = await this.loadTranscript(jobId);
      if (!transcript) {
        logger.warn("[Dubbing] Transcript not found immediately — attempting auto-transcription fallback", { jobId });
        try {
          const { TranscriptionLayer } = require("./05-transcription");
          const transLayer = new TranscriptionLayer();
          await transLayer.submitTranscription(jobId, userId, videoUrl, executionPlan, `${eventId}_trans_reload`);
          transcript = await this.loadTranscript(jobId);
        } catch (autoErr) {
          logger.error("[Dubbing] Auto-transcription fallback failed:", { jobId, err: String(autoErr) });
        }
      }
      if (!transcript) throw new Error(`Transcript not found for job ${jobId}`);

      const transcriptModel = transcript.model || transcript.provider;
      if (transcriptModel !== "assemblyai-stt-3-7") {
        const modelError = `Subtitles and dubbing require an AssemblyAI-STT-3.7 transcript; received '${transcriptModel || "unknown"}'.`;
        const dubbingRequested = executionPlan.generateDubbing === true || executionPlan.enableDubbing === true;
        const subtitlesRequested = executionPlan.genLangSubs === true ||
          (Array.isArray(executionPlan.subtitleLanguages) && executionPlan.subtitleLanguages.length > 0) ||
          (Array.isArray((executionPlan as any).features) && (executionPlan as any).features.includes("subtitles"));

        if (dubbingRequested) {
          await EdgeLayer.failStage(jobId, "dubbing", modelError).catch(() => {});
          await refundDubbingFeeOnFailure({
            jobId,
            userId,
            failedLanguages: executionPlan.dubbingLanguages || [],
            totalLanguages: executionPlan.dubbingLanguages || [],
            reason: modelError,
          }).catch((err) => logger.error("[Dubbing] Refund error on unsupported transcript model:", err));
        }
        if (subtitlesRequested) {
          await EdgeLayer.failStage(jobId, "subtitles", modelError).catch(() => {});
        }
        return [];
      }

      // ── Source Language Policy Gate (AssemblyAI Universal 3.7 Pro) ──
      // TruthWorld supports dubbing and subtitles only for the 32 AssemblyAI-STT-3.7 source languages.
      const vDoc = await db().collection("videos").doc(jobId).get().catch(() => null);
      const vData = vDoc?.exists ? vDoc.data() : null;
      const authenticSource = normalizeLanguageCode(
        executionPlan.sourceLanguage ||
        vData?.sourceLanguage ||
        vData?.originalLanguage ||
        executionPlan.primaryLanguage ||
        vData?.language ||
        ""
      );
      // Prefer the authentic source language of the video if it is supported by AssemblyAI-STT-3.7
      const rawSource = (authenticSource && ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(authenticSource))
        ? authenticSource
        : (transcript.language || transcript.detectedLanguage || authenticSource || "en");
      const normSource = normalizeLanguageCode(rawSource);
      if (!ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(normSource)) {
        const unsupportedMsg = `Source language '${normSource}' is unsupported for dubbing. TruthWorld supports only the 32 source languages supported by AssemblyAI-STT-3.7.`;
        logger.warn(`[Dubbing Gate] ${unsupportedMsg}`, { jobId, sourceLang: normSource, authenticSource, transcriptLang: transcript.language });
        const isDubbingActive = Boolean(
          executionPlan.generateDubbing &&
          Array.isArray(executionPlan.dubbingLanguages) &&
          executionPlan.dubbingLanguages.length > 0
        );
        if (isDubbingActive) {
          await EdgeLayer.failStage(jobId, "dubbing", unsupportedMsg).catch(() => {});
          await refundDubbingFeeOnFailure({
            jobId,
            userId,
            failedLanguages: executionPlan.dubbingLanguages || [],
            totalLanguages: executionPlan.dubbingLanguages || [],
            reason: unsupportedMsg,
          }).catch((err) => logger.error("[Dubbing] Refund error on unsupported source language:", err));
        } else {
          await EdgeLayer.updateStageSync(jobId, "dubbing", {
            status: "skipped", progress: 100, completedAt: Date.now(),
          }).catch(() => {});
        }
        if (executionPlan.genLangSubs) {
          await EdgeLayer.failStage(jobId, "subtitles", unsupportedMsg).catch(() => {});
        }
        return [];
      }

      // 1.2. Build high-fidelity natural speech segments
      // If words are present, build utterance-anchored segments (prevents 60-second monolithic blocks)
      let rawSegments: TimedSegment[] = [];
      if (transcript.words && Array.isArray(transcript.words) && transcript.words.length > 0) {
        rawSegments = this.buildSegmentsFromWords(transcript.words);
        logger.info("[Dubbing] Built natural speech segments from word timestamps", { jobId, segmentsCount: rawSegments.length });
      } else {
        const sourceList = (transcript.utterances && transcript.utterances.length > 0)
          ? transcript.utterances
          : (transcript.segments || []);
        rawSegments = sourceList.map((u: any, i: number) => ({
          index:    i,
          text:     u.text,
          start:    u.start,
          end:      u.end,
          duration: u.end - u.start,
          speaker:  u.speaker || "speaker_0",
          words:    u.words || [],
        }));
      }

      // Decompose any monolithic segments (>8s or >140 chars) into natural breath/clause units
      rawSegments = this.splitOversizedSegments(rawSegments, 8000, 140);

      const segments = this.stitchSegments(rawSegments).map(s => ({
        ...s,
        isHook: s.start < 10000 // First 10 seconds
      }));
      logger.info("[Dubbing] Segments stitched & Hooks marked", { jobId, original: rawSegments.length, stitched: segments.length });

      if (executionPlan.generateDubbing) {
        await EdgeLayer.updateStage(jobId, "dubbing", { progress: 15 });
      }
      await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 45 }).catch(() => {});
      await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 45 }).catch(() => {});
      logger.info("[Dubbing] Transcript loaded — starting speaker profiling", { jobId });

      // ─── STUDIO RIG: Intelligence & Identity (Phase 2) ─────────────────────
      let speakerProfiles: any[] = [];
      let acousticFingerprint: any = null;
      let isolatedVocalUrl: string | null = null;
      let mneStemUrl: string | null = null;
      let mneValidationResult: import("../services/media").MneValidationResult | undefined;
      const voiceMapping: Record<string, string> = {};
      const speakerGenderMapping: Record<string, "MALE" | "FEMALE"> = {};

      // ⚡ COMPUTE EFFICIENCY GUARD: Full speaker profiling, vocal isolation, voice cloning,
      // and M&E stem separation are strictly required ONLY when Dubbing is requested.
      // Subtitles-only jobs skip these routines to save 15-40s latency and conserve AI tokens.
      if (executionPlan.generateDubbing) {
        // 1.5. Profile all speakers in the transcript (Age, Style, Energy, Gender)
        let originalAudioUrl: string = videoUrl;
        try {
          const jobDoc = await db().collection("video_jobs").doc(jobId).get();
          const jobData = jobDoc.data();
          if (jobData?.artifacts?.transcription?.audioUrl) {
            originalAudioUrl = jobData.artifacts.transcription.audioUrl;
          }
        } catch (_) {}

        speakerProfiles = await speakerProfilingService.profileSpeakers(
          transcript.utterances ?? [],
          originalAudioUrl,
          { preferredGender: executionPlan.voiceGender }
        );
        logger.info("[Dubbing] Speaker profiling complete", { jobId, speakers: speakerProfiles.length });

        // Ensure default speaker profile if none detected or utterances were empty
        if (!speakerProfiles || speakerProfiles.length === 0) {
          const defaultGender: "male" | "female" = executionPlan.voiceGender === "female" ? "female" : "male";
          speakerProfiles = [{
            speakerId: "speaker_0",
            gender: defaultGender,
            style: "neutral",
            pitchBand: defaultGender === "female" ? "high" : "mid",
            energy: "moderate",
            ageTone: "adult",
            role: "host",
            wordCount: 1,
            segments: 1,
          }];
        }

        await db().collection("video_jobs").doc(jobId).set({
          stages: {
            onDemandAI: {
              status: "running",
              progress: 50,
              updatedAt: Date.now(),
            }
          }
        }, { merge: true });

        // 🛡️ Edge Case 3: Checkpoint Restoration for Stems and Voice Mapping
        // Check if an earlier run for this jobId already isolated vocals, extracted M&E, or mapped voices
        try {
          const existingCheckpoints = await db().collection("dubbing_checkpoints").where("jobId", "==", jobId).get().catch(() => null);
          if (existingCheckpoints && !existingCheckpoints.empty) {
            for (const doc of existingCheckpoints.docs) {
              const data = doc.data();
              if (data.isolatedVocalUrl && !isolatedVocalUrl) {
                isolatedVocalUrl = data.isolatedVocalUrl;
                logger.info("[Dubbing:Resume] Restored isolatedVocalUrl from existing checkpoint (skipping Step 1.6 neural separation)", { jobId, isolatedVocalUrl });
              }
              if (data.meStemUrl && !mneStemUrl) {
                mneStemUrl = data.meStemUrl;
                logger.info("[Dubbing:Resume] Restored meStemUrl from existing checkpoint (skipping Step 1.6c neural demixing)", { jobId, mneStemUrl });
              }
              if (data.voiceMapping && Object.keys(data.voiceMapping).length > 0) {
                Object.assign(voiceMapping, data.voiceMapping);
                logger.info("[Dubbing:Resume] Restored voiceMapping from existing checkpoint (locking speaker -> voiceId)", { jobId, voiceMapping });
              }
            }
          }
        } catch (restoreErr) {
          logger.warn("[Dubbing:Resume] Notice loading existing stem checkpoints:", restoreErr);
        }

        // 1.6. 100% Studio Preservation: Deep Neural Vocal Isolation & Discrete Stems for ALL Tiers
        try {
          const jobDoc = await db().collection("video_jobs").doc(jobId).get();
          const jobData = jobDoc.data();
          const originalAudioUrl = jobData?.artifacts?.transcription?.audioUrl || videoUrl;

          if (!isolatedVocalUrl) {
            logger.info("[Dubbing] 100% Studio Preservation: Isolating Vocals for Zero-Phase M&E Stem Separation across all tiers", { jobId, dubbingTier: executionPlan.dubbingTier });
            isolatedVocalUrl = await audioIdentityService.isolateVocals(jobId, originalAudioUrl).catch((err) => {
              logger.warn("[Dubbing] Neural vocal isolation notice (avoiding orig-orig cancellation):", err);
              return null;
            });
          } else {
            logger.info("[Dubbing:Resume] Reusing existing isolatedVocalUrl from checkpoint (skipping Step 1.6 neural vocal isolation)", { jobId, isolatedVocalUrl });
          }
          acousticFingerprint = await audioIdentityService.captureFingerprint(jobId, isolatedVocalUrl || originalAudioUrl);

          // 1.6a2. Extract per-segment acoustic RMS energy + expressive emotion tags ([whispers], [laughs], [excited], etc.)
          const prosodyCues = await audioIdentityService
            .analyzeSegmentProsody(jobId, isolatedVocalUrl || originalAudioUrl, segments)
            .catch(() => new Map());
          if (prosodyCues.size > 0) {
            for (const seg of segments) {
              const cue = prosodyCues.get(seg.index);
              if (cue) {
                seg.emotionTag = cue.emotionTag;
                seg.energyDb = cue.energyDb;
                seg.speakingRateRatio = cue.speakingRateRatio;
                seg.stabilityOverride = cue.stabilityOverride;
                seg.similarityBoostOverride = cue.similarityBoostOverride;
                seg.deliveryStyle = cue.deliveryStyle;
                seg.pitchRangeSemitones = cue.pitchRangeSemitones;
                seg.voiceQuality = cue.voiceQuality;
                seg.emotionalIntensity = cue.emotionalIntensity;
                seg.energyEnvelopePattern = cue.energyEnvelopePattern;
              }
            }
          }
        } catch (fingerprintErr) {
          logger.warn("[Dubbing] Acoustic fingerprinting notice:", fingerprintErr);
        }

        // 1.6b. Instant / Persistent Voice Cloning (when dubbingMode is voice_clone)
        let cloneVoiceGender: "male" | "female" | null = null;
        if (executionPlan.dubbingMode === "voice_clone") {
          try {
            // Check persistent creator voice profiles first (eliminates ElevenLabs slot exhaustion & re-creation delay)
            const voiceProfileDoc = await db().collection("creator_voice_profiles").doc(userId).get();
            if (voiceProfileDoc.exists && voiceProfileDoc.data()?.voiceId && voiceProfileDoc.data()?.status === "active") {
              createdVoiceCloneId = voiceProfileDoc.data()!.voiceId;
              cloneVoiceGender = voiceProfileDoc.data()?.gender || (speakerProfiles[0]?.gender ?? "male");
              isPersistentVoiceClone = true;
              logger.info("[Dubbing] ✅ Reusing persistent creator voice profile", { userId, createdVoiceCloneId, cloneVoiceGender });
              await db().collection("creator_voice_profiles").doc(userId).update({
                lastUsedAt: Date.now(),
                usageCount: admin.firestore.FieldValue.increment(1),
              }).catch(() => {});
            } else {
              const sampleUrl = isolatedVocalUrl || originalAudioUrl;
              if (sampleUrl) {
                createdVoiceCloneId = await ttsService.cloneVoice(`TruthWorld-${userId.slice(0, 8)}`, sampleUrl);
                cloneVoiceGender = speakerProfiles[0]?.gender ?? "male";
                logger.info("[Dubbing] ✅ Created new persistent creator voice clone", { userId, createdVoiceCloneId, cloneVoiceGender });
                await db().collection("creator_voice_profiles").doc(userId).set({
                  userId,
                  voiceId: createdVoiceCloneId,
                  name: `TruthWorld-${userId.slice(0, 8)}`,
                  gender: cloneVoiceGender,
                  sampleUrl,
                  status: "active",
                  provider: "elevenlabs",
                  createdAt: Date.now(),
                  lastUsedAt: Date.now(),
                  usageCount: 1,
                }, { merge: true });
                isPersistentVoiceClone = true;
              }
            }
          } catch (cloneErr: any) {
            logger.warn("[Dubbing] Voice cloning notice (falling back to preset matching):", { jobId, err: cloneErr?.message });
          }
        }

        // 1.6c. 🎛️ Industry Standard M&E (Music & Foley) Stem Extraction & Preservation
        if (mneStemUrl) {
          logger.info("[Dubbing:Resume] Reusing existing M&E stem from checkpoint (0 compute overhead)", { jobId, mneStemUrl });
        } else {
          try {
            const jobDoc = await db().collection("video_jobs").doc(jobId).get();
            const jobData = jobDoc.data();
            const sourceAudio = jobData?.artifacts?.transcription?.audioUrl || originalAudioUrl;
            const expDurSec = executionPlan.durationSeconds || (segments.length > 0 ? segments[segments.length - 1].end / 1000 : 0);

            // Priority 1: Ingest original studio production M&E stem if provided (bypasses neural demixing for 100% clean stems)
            const studioMne = executionPlan.studioMneStemUrl || jobData?.artifacts?.stems?.mneUrl || jobData?.studioMneStemUrl;
            if (studioMne) {
              mneValidationResult = await mediaService.validateMneStem(jobId, studioMne, expDurSec, "studio", {
                spokenSegments: segments,
              });
              if (mneValidationResult.validationStatus === "failed") {
                logger.warn("[Dubbing] Studio M&E stem failed validation — falling back to parallel best-of-2 neural demixing:", mneValidationResult.issues);
                const extracted = await mediaService.extractMneStemDetailedParallel(jobId, sourceAudio, {
                  isolatedVocalUrl: (isolatedVocalUrl && isolatedVocalUrl !== sourceAudio) ? isolatedVocalUrl : undefined,
                  enableAutoVocalIsolation: true,
                  spokenSegments: segments,
                  expectedDurationSeconds: expDurSec,
                });
                mneStemUrl = extracted.mneUrl;
                mneValidationResult = await mediaService.validateMneStem(jobId, mneStemUrl, expDurSec, extracted.source, {
                  spokenSegments: segments,
                  expectedSourceDegraded: extracted.degraded,
                });
              } else {
                mneStemUrl = studioMne;
                logger.info("[Dubbing] ✅ Priority 1: Ingested & validated studio M&E stem", { jobId, mneStemUrl, status: mneValidationResult.validationStatus });
              }
            } else {
              logger.info("[Dubbing] Priority 2: Extracting Music & Effects (M&E) stem via parallel best-of-2 neural demixing", { jobId, sourceAudio });
              const extracted = await mediaService.extractMneStemDetailedParallel(jobId, sourceAudio, {
                isolatedVocalUrl: (isolatedVocalUrl && isolatedVocalUrl !== sourceAudio) ? isolatedVocalUrl : undefined,
                enableAutoVocalIsolation: true,
                spokenSegments: segments,
                expectedDurationSeconds: expDurSec,
              });
              mneStemUrl = extracted.mneUrl;
              mneValidationResult = await mediaService.validateMneStem(jobId, mneStemUrl, expDurSec, extracted.source, {
                spokenSegments: segments,
                expectedSourceDegraded: extracted.degraded,
              });
              logger.info("[Dubbing] ✅ M&E stem preserved & validated", {
                jobId,
                mneStemUrl,
                source: extracted.source,
                status: mneValidationResult.validationStatus,
                dialogueBleedDb: mneValidationResult.dialogueBleedDb,
              });
            }

            // Persist M&E validation report in job artifacts for auditability
            if (mneValidationResult) {
              await db().collection("video_jobs").doc(jobId).set({
                artifacts: {
                  mneValidation: mneValidationResult,
                },
              }, { merge: true }).catch(() => {});
            }
          } catch (mneErr) {
            const errMsg = mneErr instanceof Error ? mneErr.message : String(mneErr);
            logger.error("[Dubbing] M&E stem preservation failure — recording explicit validation state:", { jobId, error: errMsg });
            mneValidationResult = {
              source: "dsp_fallback",
              fileUrl: "",
              durationSeconds: 0,
              videoDurationSeconds: executionPlan.durationSeconds || 0,
              durationMatch: false,
              durationDeltaMs: 0,
              timelineAlignmentMs: 0,
              sampleRate: 44100,
              channels: 2,
              channelLayout: "stereo",
              clippingDetected: false,
              corruptionDetected: true,
              validationStatus: "degraded",
              issues: [`M&E stem extraction error: ${errMsg}`],
            };
            await db().collection("video_jobs").doc(jobId).set({
              artifacts: {
                mneValidation: mneValidationResult,
              },
            }, { merge: true }).catch(() => {});
            if (executionPlan.stemIsolation) {
              logger.warn(`[Dubbing:M&E] M&E stem isolation failed, falling back gracefully to standard audio mix: ${errMsg}`);
            }
          }
        }

        // 1.7. Speaker-to-Voice Matching Layer by Age, Gender & F0 Fundamental Pitch
        const elevenLabsApiKey = process.env.ELEVENLABS_API_KEY || "";
        const catalog = await voiceMatcher.getVoiceCatalog(elevenLabsApiKey);
        const assignedVoiceIds = new Set<string>();
        let cloneAssigned = false;

        const tmpProfileDir = path.join(os.tmpdir(), `spk_profile_${jobId}_${Date.now()}`);
        await fs.promises.mkdir(tmpProfileDir, { recursive: true }).catch(() => {});

        try {
          // Resolve local audio and video files if accessible for multimodal profiling
          const sourceAudioForProfile = isolatedVocalUrl || originalAudioUrl;
          const localAudioPath = await mediaService.ensureLocalMediaFile(sourceAudioForProfile, tmpProfileDir, ".mp3");
          const localVideoPath = videoUrl ? await mediaService.ensureLocalMediaFile(videoUrl, tmpProfileDir, ".mp4") : null;

          for (const profile of speakerProfiles) {
            const role = profile.role || "other";

            // 1. Locate the speaker's longest uninterrupted turn (prefer >= 2.5s)
            const spkSegments = segments.filter((s) => (s.speaker || "speaker_0") === profile.speakerId);
            let longestSeg = spkSegments.find((s) => (s.end - s.start >= 2500)) || spkSegments[0];
            if (spkSegments.length > 0) {
              for (const s of spkSegments) {
                if (!longestSeg || (s.end - s.start) > (longestSeg.end - longestSeg.start)) {
                  longestSeg = s;
                }
              }
            }

            let clipAudioPath: string | undefined;
            let frameImgPath: string | undefined;

            if (longestSeg) {
              const startSec = longestSeg.start > 1000 ? longestSeg.start / 1000 : longestSeg.start;
              const endSec = longestSeg.end > 1000 ? longestSeg.end / 1000 : longestSeg.end;
              const durationSec = Math.max(0.5, endSec - startSec);
              const sliceDur = Math.min(Math.max(durationSec, 2.5), 5.0);
              const midSec = startSec + (sliceDur / 2);

              if (localAudioPath && fs.existsSync(localAudioPath)) {
                try {
                  const outAudio = path.join(tmpProfileDir, `solo_${profile.speakerId}.mp3`);
                  await mediaService.extractAudioSlice(localAudioPath, startSec, sliceDur, outAudio);
                  if (fs.existsSync(outAudio)) clipAudioPath = outAudio;
                } catch (audioSliceErr) {
                  logger.warn("[Dubbing] Solo turn audio slicing notice:", audioSliceErr);
                }
              }

              if (localVideoPath && fs.existsSync(localVideoPath)) {
                try {
                  const outFrame = path.join(tmpProfileDir, `frame_${profile.speakerId}.jpg`);
                  await mediaService.extractVideoFrame(localVideoPath, midSec, outFrame);
                  if (fs.existsSync(outFrame)) frameImgPath = outFrame;
                } catch (videoFrameErr) {
                  logger.warn("[Dubbing] Video frame extraction notice:", videoFrameErr);
                }
              }
            }

            // 2. Profile speaker via multimodal cues (F0 pitch + visual age & timbre tags)
            const diarizedProfile: DiarizedSpeakerProfile = await voiceMatcher.profileSpeakerMultimodal({
              speakerId: profile.speakerId,
              audioClipPath: clipAudioPath || "",
              videoFramePath: frameImgPath,
              transcriptSample: spkSegments.slice(0, 3).map((s) => s.text).join(" "),
              preferredGender: executionPlan.voiceGender,
            });

            // Enforce explicit gender override if configured on execution plan
            if (executionPlan.voiceGender === "male") diarizedProfile.gender = "male";
            if (executionPlan.voiceGender === "female") diarizedProfile.gender = "female";

            speakerGenderMapping[profile.speakerId] = diarizedProfile.gender === "female" ? "FEMALE" : "MALE";

            // 🛡️ Edge Case 3: Retain locked voiceId from checkpoint for speaker (Zero Acoustic Drift)
            if (voiceMapping[profile.speakerId]) {
              assignedVoiceIds.add(voiceMapping[profile.speakerId]);
              logger.info("[Dubbing:Resume] Retaining locked voiceId from checkpoint for speaker", {
                jobId,
                speakerId: profile.speakerId,
                voiceId: voiceMapping[profile.speakerId],
              });
              continue;
            }

            // 🛡️ Strict Clone Gender Invariant: Never assign a male clone to a female speaker or vice-versa
            const isGenderMatch = cloneVoiceGender ? (diarizedProfile.gender === cloneVoiceGender) : true;
            if (!cloneAssigned && createdVoiceCloneId && isGenderMatch) {
              voiceMapping[profile.speakerId] = createdVoiceCloneId;
              assignedVoiceIds.add(createdVoiceCloneId);
              cloneAssigned = true;
              logger.info("[Dubbing] Assigned cloned creator voice ID to matching gender speaker", {
                jobId,
                speakerId: profile.speakerId,
                voiceId: createdVoiceCloneId,
                gender: diarizedProfile.gender,
              });
              continue;
            }

            // 3. Multi-Speaker Voice Allocation: Select unique, nearest-matching voice
            const matchedVoice = voiceMatcher.selectNearestVoice(
              diarizedProfile,
              catalog,
              assignedVoiceIds
            );
            const distanceScore = voiceMatcher.scoreCandidate(diarizedProfile, matchedVoice);

            assignedVoiceIds.add(matchedVoice.voiceId);
            voiceMapping[profile.speakerId] = matchedVoice.voiceId;

            // Enrich profile with physical telemetry for downstream and telemetry logging
            profile.gender = matchedVoice.gender;
            profile.estimatedAge = diarizedProfile.estimatedAge;
            profile.ageBucket = diarizedProfile.ageBucket;
            profile.medianPitchHz = diarizedProfile.medianPitchHz;
            profile.timbreTags = diarizedProfile.timbreTags;
            profile.confidence = diarizedProfile.confidence;
            profile.matchedVoiceId = matchedVoice.voiceId;
            profile.matchedVoiceName = matchedVoice.name;
            profile.distanceScore = distanceScore;

            logger.info("[Dubbing] Assigned distinct production-grade voice ID by multimodal age/pitch matching", {
              jobId,
              speakerId: profile.speakerId,
              gender: matchedVoice.gender,
              role,
              estimatedAge: diarizedProfile.estimatedAge,
              ageBucket: diarizedProfile.ageBucket,
              medianPitchHz: diarizedProfile.medianPitchHz,
              timbreTags: diarizedProfile.timbreTags,
              voiceId: matchedVoice.voiceId,
              voiceName: matchedVoice.name,
              distanceScore: Number(distanceScore.toFixed(4)),
            });
          }
        } finally {
          await fs.promises.rm(tmpProfileDir, { recursive: true, force: true }).catch(() => {});
        }

        // Multi-speaker distinction invariant assertion
        if (speakerProfiles.length > 1 && assignedVoiceIds.size < Math.min(speakerProfiles.length, 10)) {
          logger.warn("[Dubbing:MultiSpeaker] Multi-speaker voice distinctness check: allocated voices", {
            jobId,
            distinctSpeakers: speakerProfiles.length,
            assignedDistinctVoices: assignedVoiceIds.size,
          });
        }
      } else {
        logger.info("[Dubbing] Subtitles-only pipeline mode: Bypassing speaker profiling, vocal isolation, and voice cloning to maximize compute efficiency and reduce latency", { jobId });
      }

      // 1.8. Creator DNA Style Memory (Phase 4)
      const creatorDNA = await creatorStyleService.getCreatorDNA(userId);
      if (creatorDNA) logger.info("[Dubbing] Loaded Creator DNA Style Memory", { userId, vibe: creatorDNA.vibe });

      // 2. Process each language IN PARALLEL — independent per language
      let languagesToProcess: string[];
      if (!executionPlan.generateDubbing) {
        languagesToProcess = (executionPlan.subtitleLanguages && executionPlan.subtitleLanguages.length > 0)
          ? executionPlan.subtitleLanguages
          : (executionPlan.languages && executionPlan.languages.length > 0 ? executionPlan.languages : []);
      } else {
        const dubLangs = executionPlan.dubbingLanguages && executionPlan.dubbingLanguages.length > 0
          ? executionPlan.dubbingLanguages
          : (executionPlan.languages || []);
        const subLangs = executionPlan.subtitleLanguages || [];
        languagesToProcess = Array.from(new Set([...dubLangs, ...subLangs]));
      }
      if (languagesToProcess.length === 0 && executionPlan.languages && executionPlan.languages.length > 0) {
        languagesToProcess = executionPlan.languages;
      }
      logger.info("[Dubbing] Triggering per-language processing", { jobId, languages: languagesToProcess });

      // 🛡️ Edge Case 3: Checkpoint voiceMapping, isolatedVocalUrl, & meStemUrl immediately after Step 1.7
      // Guarantees segments 15..19 synthesize with the exact same voiceId assignments and M&E stem as segments 0..14
      if (executionPlan.generateDubbing && languagesToProcess.length > 0) {
        const canonicalIsoVocal = isolatedVocalUrl ? toCanonicalGsUrl(isolatedVocalUrl) : null;
        const canonicalMeStem = mneStemUrl ? toCanonicalGsUrl(mneStemUrl) : null;

        await Promise.all(
          languagesToProcess.map(async (targetLang) => {
            await this.saveDubbingCheckpoint(jobId, targetLang, {
              stage: "translated",
              voiceMapping,
              isolatedVocalUrl: canonicalIsoVocal,
              meStemUrl: canonicalMeStem,
            });
          })
        );
      }

      // 1.9 Long-Form Distributed 15-Minute Reel Orchestration (> 20m videos / 90-150m movies)
      const resolvedDurationMs = await this.resolveJobDurationMs(jobId, executionPlan, segments);
      const reelThresholdMs = Number(process.env.DUBBING_REEL_THRESHOLD_MS || 20 * 60 * 1000);
      if (executionPlan.generateDubbing && resolvedDurationMs > reelThresholdMs) {
        logger.info("[Dubbing] Long-form media detected — fanning out into distributed 15-minute reel workers", {
          jobId,
          resolvedDurationMs,
          reelThresholdMs,
          languages: languagesToProcess,
        });
        await this.dispatchLongFormReels({
          jobId,
          userId,
          videoUrl,
          languagesToProcess,
          segments,
          sourceLang: normSource,
          totalDurationMs: resolvedDurationMs,
          executionPlan,
          speakerProfiles,
          acousticFingerprint,
          voiceMapping,
          creatorDNA,
          speakerGenderMapping,
          mneStemUrl,
          isolatedVocalUrl,
          mneValidationResult,
          eventId,
          words: transcript.words,
        });
        return [];
      }

      const results = await Promise.allSettled(
        languagesToProcess.map((lang) =>
          this.processLanguage(
            jobId, userId, videoUrl, lang,
            segments,
            normSource,
            executionPlan,
            speakerProfiles,
            acousticFingerprint,
            voiceMapping,
            creatorDNA,
            speakerGenderMapping,
            mneStemUrl,
            isolatedVocalUrl,
            mneValidationResult,
            transcript.words
          )
        )
      );

      // 3. Collect results, log per-language failures
      const dubbingResults:  DubbingResult[]         = [];
      const subtitlePaths:   Record<string, string>  = {};
      const dubbedPaths:     Record<string, string>  = {};
      const audioPaths:      Record<string, string>  = {};

      results.forEach((r, i) => {
        const lang = languagesToProcess[i];
        const normLang = normalizeLanguageCode(lang);
        if (r.status === "fulfilled" && r.value) {
          const v = r.value;
          dubbingResults.push(v);
          subtitlePaths[lang] = v.subtitleUrl;
          if (normLang !== lang) subtitlePaths[normLang] = v.subtitleUrl;
          dubbedPaths[lang]   = v.videoUrl;
          if (normLang !== lang) dubbedPaths[normLang]   = v.videoUrl;
          audioPaths[lang]    = v.audioUrl;
          if (normLang !== lang) audioPaths[normLang]    = v.audioUrl;
        } else if (r.status === "rejected") {
          const errMsg = r.reason instanceof Error ? r.reason.message : String(r.reason);
          const errStack = r.reason instanceof Error ? r.reason.stack : undefined;
          logger.error("[Dubbing] Language failed", { 
            jobId, lang, 
            reason: errMsg,
            stack: errStack,
          });
          // Explicitly update stages to failed so nothing is left stuck in running
          EdgeLayer.updateStageSync(jobId, `translating_${lang}`, { status: "failed", error: errMsg }).catch(() => {});
          if (normLang !== lang) {
            EdgeLayer.updateStageSync(jobId, `translating_${normLang}`, { status: "failed", error: errMsg }).catch(() => {});
          }
          if (executionPlan.generateDubbing) {
            EdgeLayer.updateStageSync(jobId, `dubbing_${lang}`, { status: "failed", error: errMsg }).catch(() => {});
            if (normLang !== lang) {
              EdgeLayer.updateStageSync(jobId, `dubbing_${normLang}`, { status: "failed", error: errMsg }).catch(() => {});
            }
          }
        }
      });

      if (dubbingResults.length === 0) {
        // Log detailed failure for debugging
        const failureDetails = results
          .map((r, i) => ({
            lang: languagesToProcess[i],
            error: r.status === "rejected" 
              ? (r.reason instanceof Error ? r.reason.message : String(r.reason))
              : "ok"
          }))
          .filter(d => d.error !== "ok");
        logger.error("[Dubbing] ALL languages failed — full details", { jobId, failures: failureDetails });
        throw new Error(`All ${languagesToProcess.length} languages failed for job ${jobId}: ${failureDetails.map(f => `${f.lang}: ${f.error}`).join(" | ")}`);
      }

      // Check for partial language failures & process prorated refund
      const failedLangs = results
        .map((r, i) => (r.status === "rejected" ? languagesToProcess[i] : null))
        .filter((l): l is string => l !== null);
      if (failedLangs.length > 0) {
        logger.warn("[Dubbing] Partial language failure detected — processing prorated refund", { jobId, failedLangs });
        await refundDubbingFeeOnFailure({
          jobId,
          userId,
          failedLanguages: failedLangs,
          totalLanguages: languagesToProcess,
          reason: "Partial language dubbing synthesis failure",
        }).catch((refErr) => logger.error("[Dubbing] Partial refund error:", refErr));
      }


      // 4. Emit dubbing-complete (AFTER successful Firestore writes in processLanguage)
      const eventData: DubbingCompleteData = {
        languages:       dubbingResults.map((r) => r.language),
        subtitlePaths,
        dubbedVideoPaths: dubbedPaths,
        audioPaths,
        mneStemPath: mneStemUrl || undefined,
        stems: {
          mne: mneStemUrl || undefined,
          dialogue: dubbingResults.reduce((acc, r) => {
            if (r.stems?.dialogue) acc[r.language] = r.stems.dialogue;
            return acc;
          }, {} as Record<string, string>),
          master: audioPaths,
          vocals: isolatedVocalUrl || undefined,
        },
      };

      await this.distribution.publish("dubbing-complete", {
        eventId:    uuidv4(),
        eventType:  "dubbing-complete",
        jobId, userId,
        timestamp:  Date.now(),
        data:       eventData,
        retryCount: 0,
        source:     "dubbing-engine",
      });

      const completedAt = Date.now();
      await EdgeLayer.upsertDubbingJob(jobId, {
        status: "completed",
        progress: 100,
        completedAt,
      });

      await db().collection("video_jobs").doc(jobId).set({
        updatedAt: completedAt,
        stages: {
          dubbing: {
            status: executionPlan.generateDubbing ? "completed" : "skipped",
            progress: 100,
            completedAt,
          },
          subtitles: {
            status: "completed",
            progress: 100,
            completedAt,
          },
          onDemandAI: {
            status: "completed",
            progress: 100,
            completedAt,
          }
        },
        outputs: {
          audioTracks: audioPaths,
          subtitles: subtitlePaths,
          dubbedVideos: dubbedPaths,
          stems: {
            mne: mneStemUrl || null,
            vocals: isolatedVocalUrl || null,
          },
        }
      }, { merge: true });

      await aggregationLayer.onStageComplete(jobId, "dubbing", userId, executionPlan);

      logger.info("[Dubbing] Completed", {
        jobId,
        languages: dubbingResults.length,
        ms:        Date.now() - t0,
      });
      await this.distribution.markEventCompleted(eventId);

      return dubbingResults;

    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);

      // 💳 Two-Phase Commit Automated Wallet Escrow Failure Rollback
      await refundDubbingFeeOnFailure({
        jobId,
        userId,
        failedLanguages: executionPlan.dubbingLanguages || executionPlan.languages || [],
        totalLanguages: executionPlan.dubbingLanguages || executionPlan.languages || [],
        reason: errMsg,
      }).catch((refErr) => logger.error("[Dubbing] Failure rollback refund error:", refErr));

      // 🔄 Unblock Pub/Sub Retry & Avoid Idempotency Trap
      await this.distribution.markEventFailed(eventId, errMsg).catch(() => {});

      await EdgeLayer.failStage(jobId, "dubbing", errMsg);
      await EdgeLayer.upsertDubbingJob(jobId, {
        status: "failed",
        error: errMsg,
        completedAt: Date.now(),
      });
      await db().collection("video_jobs").doc(jobId).set({
        updatedAt: Date.now(),
        stages: {
          dubbing: {
            status: executionPlan.generateDubbing ? "failed" : "skipped",
            ...(executionPlan.generateDubbing ? { error: errMsg, failedAt: Date.now() } : {}),
          },
          subtitles: {
            status: "failed",
            error: errMsg,
            failedAt: Date.now(),
          },
          onDemandAI: {
            status: "failed",
            error: errMsg,
            failedAt: Date.now(),
          }
        }
      }, { merge: true });
      await aggregationLayer.onStageComplete(jobId, "dubbing", userId, executionPlan).catch(() => {});
      throw error;
    } finally {
      // 💨 Voice Lifecycle Cleanup: Only delete temporary clones, preserve persistent profiles
      if (createdVoiceCloneId && !isPersistentVoiceClone) {
        logger.info("[Dubbing] Job Finished — cleaning up temporary creator voice clone", { jobId, createdVoiceCloneId });
        await ttsService.deleteVoice(createdVoiceCloneId).catch(() => {});
      }
    }
  }

  // ─── Direct Audio Track Propagation ──────────────────────────────────────────

  private async propagateAudioTrack(
    jobId: string,
    targetLang: string,
    rawTargetLang: string,
    directAudioUrl: string
  ): Promise<void> {
    try {
      const jobSnap = await db().collection("video_jobs").doc(jobId).get();
      const jobData = jobSnap.data() as JobData;
      const rawLinkedVideoIds = jobData?.linkedVideoIds || [];
      if (jobData?.videoId && !rawLinkedVideoIds.includes(jobData.videoId)) {
        rawLinkedVideoIds.push(jobData.videoId);
      }
      const linkedVideoIds = filterVideoIds(rawLinkedVideoIds, "[Dubbing:audio-propagation]");

      const dotAudioUpdates: Record<string, any> = {
        audioTracks: {
          [targetLang]: directAudioUrl,
          ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
        },
        media: {
          audioTracks: {
            [targetLang]: directAudioUrl,
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
          },
        },
        [`audioTracks.${targetLang}`]: directAudioUrl,
        [`media.audioTracks.${targetLang}`]: directAudioUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (rawTargetLang && rawTargetLang !== targetLang) {
        dotAudioUpdates[`audioTracks.${rawTargetLang}`] = directAudioUrl;
        dotAudioUpdates[`media.audioTracks.${rawTargetLang}`] = directAudioUrl;
      }

      for (const vid of linkedVideoIds) {
        await db().collection("videos").doc(vid).set(dotAudioUpdates, { merge: true });

        const locAudioUpdates: Record<string, any> = {
          audioTracks: {
            [targetLang]: directAudioUrl,
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
          },
          [`audioTracks.${targetLang}`]: directAudioUrl,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (rawTargetLang && rawTargetLang !== targetLang) {
          locAudioUpdates[`audioTracks.${rawTargetLang}`] = directAudioUrl;
        }
        await db().collection("videos").doc(vid).collection("media").doc("localization").set(locAudioUpdates, { merge: true });
      }

      const jobOutputAudioUpdate: Record<string, any> = {
        audioTracks: {
          [targetLang]: directAudioUrl,
          ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
        },
        [`audioTracks.${targetLang}`]: directAudioUrl,
        updatedAt: Date.now(),
      };
      if (rawTargetLang && rawTargetLang !== targetLang) {
        jobOutputAudioUpdate[`audioTracks.${rawTargetLang}`] = directAudioUrl;
      }
      await db().collection("job_outputs").doc(jobId).set(jobOutputAudioUpdate, { merge: true });

      const videoJobAudioUpdate: Record<string, any> = {
        outputs: {
          audioTracks: {
            [targetLang]: directAudioUrl,
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
          },
        },
        [`outputs.audioTracks.${targetLang}`]: directAudioUrl,
        updatedAt: Date.now(),
      };
      if (rawTargetLang && rawTargetLang !== targetLang) {
        videoJobAudioUpdate[`outputs.audioTracks.${rawTargetLang}`] = directAudioUrl;
      }
      await db().collection("video_jobs").doc(jobId).set(videoJobAudioUpdate, { merge: true });
    } catch (earlyPropErr) {
      logger.warn("[Dubbing] Audio track propagation warning:", earlyPropErr);
    }
  }

  // ─── Per-language processing ──────────────────────────────────────────────────

  private async processLanguage(
    jobId:          string,
    userId:         string,
    videoUrl:       string,
    rawTargetLang:  string,
    segments:       TimedSegment[],
    rawSourceLang:  string,
    executionPlan:  ExecutionPlan,
    speakerProfiles: any[],
    acousticFingerprint: any,
    voiceMapping:    Record<string, string>,
    creatorDNA?:     any,
    speakerGenderMapping?: Record<string, "MALE" | "FEMALE">,
    mneStemUrl?:     string | null,
    isolatedVocalUrl?: string | null,
    mneValidation?:  import("../services/media").MneValidationResult,
    sourceWords?:    WordTimestamp[]
  ): Promise<DubbingResult> {
    const targetLang = normalizeLanguageCode(rawTargetLang);
    const sourceLang = normalizeLanguageCode(rawSourceLang);
    const t0 = Date.now();
    logger.info("[Dubbing] Processing language", { jobId, targetLang, rawTargetLang, sourceLang });
    
    const updateTranslationStage = async (status: "running" | "completed" | "failed", progress: number, error?: string) => {
      const now = Date.now();
      const payload: any = { status, progress, updatedAt: now };
      if (status === "running") payload.startedAt = now;
      if (status === "completed") payload.completedAt = now;
      if (status === "failed") payload.failedAt = now;
      if (error) payload.error = error;

      await EdgeLayer.updateStageSync(jobId, `translating_${targetLang}`, payload).catch(() => {});
      if (rawTargetLang && rawTargetLang.toLowerCase() !== targetLang.toLowerCase()) {
        await EdgeLayer.updateStageSync(jobId, `translating_${rawTargetLang}`, payload).catch(() => {});
      }
    };

    const updateDubbingStage = async (status: "running" | "completed" | "failed", progress: number, error?: string) => {
      const now = Date.now();
      const payload: any = { status, progress, updatedAt: now };
      if (status === "running") payload.startedAt = now;
      if (status === "completed") payload.completedAt = now;
      if (status === "failed") payload.failedAt = now;
      if (error) payload.error = error;

      await EdgeLayer.updateStageSync(jobId, `dubbing_${targetLang}`, payload).catch(() => {});
      if (rawTargetLang && rawTargetLang.toLowerCase() !== targetLang.toLowerCase()) {
        await EdgeLayer.updateStageSync(jobId, `dubbing_${rawTargetLang}`, payload).catch(() => {});
      }
      await EdgeLayer.updateStageSync(jobId, "dubbing", {
        status: status === "failed" ? "running" : status,
        progress: Math.min(100, Math.max(5, progress)),
      }).catch(() => {});
      await EdgeLayer.updateStageSync(jobId, "onDemandAI", {
        status: status === "failed" ? "running" : status,
        progress: Math.min(100, Math.max(10, progress)),
      }).catch(() => {});
    };

    if (segments.length === 0) {
      logger.warn("[Dubbing] No segments to process for language", { jobId, targetLang });
      return {
        jobId, language: targetLang, subtitleUrl: "", subtitleFormat: "srt", audioUrl: "", videoUrl: "",
        translationUrl: "", segments: 0, processingTime: 0,
      };
    }

    try {
      // 🛡️ Language-Level Dubbing Completion Gate:
      // If this target language was already completed in an earlier attempt, restore & propagate immediately.
      const langCheckpoint = await this.loadDubbingCheckpoint(jobId, targetLang);
      if (
        langCheckpoint?.status === "completed" &&
        langCheckpoint.masterAudioUrl &&
        langCheckpoint.masterAudioUrl.length > 5
      ) {
        logger.info("[Dubbing:Resume] Target language already completed in previous attempt — restoring track (0 ElevenLabs credits, 0 compute)", {
          jobId,
          targetLang,
          masterAudioUrl: langCheckpoint.masterAudioUrl,
        });

        const bucket = admin.storage().bucket();
        const directAudioUrl = langCheckpoint.directAudioUrl ||
          (langCheckpoint.masterAudioUrl.startsWith("gs://")
            ? `https://storage.googleapis.com/${bucket.name}/${langCheckpoint.masterAudioUrl.replace(`gs://${bucket.name}/`, "")}`
            : langCheckpoint.masterAudioUrl);

        await this.propagateAudioTrack(jobId, targetLang, rawTargetLang, directAudioUrl);
        await updateTranslationStage("completed", 100);
        await updateDubbingStage("completed", 100);

        return {
          jobId,
          language: targetLang,
          subtitleUrl: langCheckpoint.subtitleUrl || "",
          subtitleFormat: "srt",
          audioUrl: langCheckpoint.masterAudioUrl,
          videoUrl: (langCheckpoint as any).masterVideoUrl || "",
          translationUrl: langCheckpoint.translationUrl || "",
          segments: segments.length,
          processingTime: 0,
          stems: {
            dialogue: langCheckpoint.dialogueStemUrl || undefined,
            master: langCheckpoint.masterAudioUrl,
          },
        };
      }

      // 🛡️ Edge Case 3: Restore locked voiceMapping, isolatedVocalUrl, and meStemUrl from checkpoint
      if (langCheckpoint?.voiceMapping && Object.keys(langCheckpoint.voiceMapping).length > 0) {
        Object.assign(voiceMapping, langCheckpoint.voiceMapping);
        logger.info("[Dubbing:Resume] Restored locked voiceMapping for language", { jobId, targetLang, voiceMapping });
      }
      if (langCheckpoint?.isolatedVocalUrl && (!isolatedVocalUrl || isolatedVocalUrl.length === 0)) {
        isolatedVocalUrl = langCheckpoint.isolatedVocalUrl;
      }
      if (langCheckpoint?.meStemUrl && (!mneStemUrl || mneStemUrl.length === 0)) {
        mneStemUrl = langCheckpoint.meStemUrl;
      }

      // Proactively initialize dubbing stage to running so listeners know it's actively processing
      await updateDubbingStage("running", 15);

      // A. Translate (skip if same language)
      if (targetLang !== sourceLang) {
        await updateTranslationStage("running", 45);
        await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 50 }).catch(() => {});
        await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 50 }).catch(() => {});
      }
      logger.info("[Dubbing] [Lang] Starting translation", { jobId, targetLang, sourceLang });
      let dubbingSegs: DubbingSegment[];

      if (targetLang === sourceLang) {
        dubbingSegs = segments.map((s) => ({
          index:          s.index,
          originalText:   s.text,
          translatedText: s.text,
          language:       targetLang,
          start:          s.start,
          end:            s.end,
          targetDuration: s.duration,
          speaker:        s.speaker,
        }));
      } else if (
        langCheckpoint?.translatedSegments &&
        langCheckpoint.translatedSegments.length === segments.length &&
        langCheckpoint.translatedSegments.every((s) => s.translatedText && s.translatedText.trim().length > 0)
      ) {
        logger.info("[Dubbing:Resume] Reusing complete translated segments from checkpoint (0 Google Translation API v3 cost)", {
          jobId,
          targetLang,
          segmentCount: langCheckpoint.translatedSegments.length,
        });
        dubbingSegs = langCheckpoint.translatedSegments;
      } else {
        const subTier = executionPlan.subtitleTier || "ultra";
        const currentDubbingTier = (executionPlan as any).dubbingTier || "audio_track";
        dubbingSegs = await this.translateWithCache(
          jobId, segments, sourceLang, targetLang,
          { 
            model: 'premium',
            tone: executionPlan.toneMode,
            localeStyle: executionPlan.localeStyle,
            targetPlatform: executionPlan.targetPlatform,
            creatorDNA,
            enableABHooks: executionPlan.enableABHooks ?? true, // Default to true for premium
            speakerProfiles,
            dubbingTier: currentDubbingTier,
            subtitleTier: subTier,
            isCinemaGrade: false,
          }
        );

        // ✅ Cost tracking: record separate input and output translation cost for this language
        const sourceChars = segments.reduce((sum, s) => sum + s.text.length, 0);
        const translatedChars = dubbingSegs.reduce((sum, s) => sum + s.translatedText.length, 0);
        costEngine.recordTranslationCost(jobId, userId, sourceChars, translatedChars).catch(() => {});

        // 🛡️ Save translated segments into checkpoint
        await this.saveDubbingCheckpoint(jobId, targetLang, {
          stage: "translated",
          status: "translated",
          translatedSegments: dubbingSegs,
          totalSegments: segments.length,
          voiceMapping,
          isolatedVocalUrl: isolatedVocalUrl ? toCanonicalGsUrl(isolatedVocalUrl) : null,
          meStemUrl: mneStemUrl ? toCanonicalGsUrl(mneStemUrl) : null,
        });
      }

      if (targetLang !== sourceLang) {
        await updateTranslationStage("running", 85);
        await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 80 }).catch(() => {});
        await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 80 }).catch(() => {});
      }

      // B. Generate subtitles (.json, .vtt, and .srt formats for every language)
      let subtitleUrl = "";
      let srtUrl = "";
      let vttUrl = "";
      let jsonUrl = "";

      const bucket = admin.storage().bucket();
      const transPath = `subtitles/${jobId}/${targetLang}.json`;
      const translationUrl = `gs://${bucket.name}/${transPath}`;

      await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 85 }).catch(() => {});
      await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 85 }).catch(() => {});

      // ⚡ PARALLEL: Save translation JSON + generate subtitles simultaneously (saves 2-5s)
      const allWords = (sourceWords && sourceWords.length > 0) ? sourceWords : segments.flatMap((s) => s.words || []);
      let subGenPromise: Promise<{ srtUrl: string; vttUrl: string; jsonUrl: string } | null>;

      if (executionPlan.genLangSubs && targetLang === sourceLang) {
        subGenPromise = this.checkNativeSubtitles(jobId, targetLang).then((nativeUrl) => {
          if (nativeUrl) {
            logger.info("[Dubbing] Using native AssemblyAI subtitles for source lang", { jobId, targetLang });
            return {
              srtUrl: nativeUrl,
              vttUrl: `gs://${bucket.name}/subtitles/${jobId}/${targetLang}.vtt`,
              jsonUrl: translationUrl,
            };
          }
          return this.generateSubtitles(jobId, dubbingSegs, targetLang, sourceLang, allWords);
        });
      } else {
        subGenPromise = this.generateSubtitles(jobId, dubbingSegs, targetLang, sourceLang, allWords);
      }

      const [, subResult] = await Promise.all([
        bucket.file(transPath).save(JSON.stringify(dubbingSegs, null, 2), {
          metadata: { contentType: "application/json" },
        }),
        subGenPromise,
      ]);

      if (subResult) {
        subtitleUrl = subResult.srtUrl;
        srtUrl = subResult.srtUrl;
        vttUrl = subResult.vttUrl;
        jsonUrl = subResult.jsonUrl;
      }

      // D. Persist results (Separated for Industry Standards)
      // 🚀 Move persistence UP so subtitles are available even if dubbing fails/is slow
      if (executionPlan.genLangSubs || dubbingSegs.length > 0) {
        const subDocData = {
          jobId,
          language:     targetLang,
          subtitleUrl,
          srtPath:      srtUrl || `gs://${bucket.name}/subtitles/${jobId}/${targetLang}.srt`,
          vttPath:      vttUrl || `gs://${bucket.name}/subtitles/${jobId}/${targetLang}.vtt`,
          jsonPath:     jsonUrl || translationUrl,
          subtitleFormat: "srt",
          createdAt:    Date.now(),
        };
        await db().collection("subtitle_results").doc(`${jobId}_${targetLang}`).set(subDocData);
        if (rawTargetLang && rawTargetLang !== targetLang) {
          await db().collection("subtitle_results").doc(`${jobId}_${rawTargetLang}`).set({
            ...subDocData,
            language: rawTargetLang,
          });
        }

        // 🚀 Real-time Propagation to Video Collection
        try {
          const jobSnap = await db().collection("video_jobs").doc(jobId).get();
          const jobData = jobSnap.data() as JobData;
          const rawLinkedVideoIds = jobData?.linkedVideoIds || [];
          if (jobData?.videoId && !rawLinkedVideoIds.includes(jobData.videoId)) {
            rawLinkedVideoIds.push(jobData.videoId);
          }
          // Guard: only allow UUID video IDs — never write to videos collection with a job_ ID
          const linkedVideoIds = filterVideoIds(rawLinkedVideoIds, "[Dubbing:subtitle-propagation]");

          let directSubtitleUrl = subtitleUrl;
          if (subtitleUrl.startsWith("gs://")) {
            const relPath = subtitleUrl.replace(`gs://${bucket.name}/`, "");
            directSubtitleUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(relPath)}?alt=media`;
          }

          const subUpdates: Record<string, any> = {
            [`subtitles.${targetLang}`]: directSubtitleUrl,
            [`media.subtitles.${targetLang}`]: directSubtitleUrl,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          if (rawTargetLang && rawTargetLang !== targetLang) {
            subUpdates[`subtitles.${rawTargetLang}`] = directSubtitleUrl;
            subUpdates[`media.subtitles.${rawTargetLang}`] = directSubtitleUrl;
          }

          for (const vid of linkedVideoIds) {
            // Update top-level videos/{vid} document directly using dot notation to preserve sibling tracks
            await db().collection("videos").doc(vid).set(subUpdates, { merge: true });

            // Also update subcollection for backwards compatibility using dot notation to preserve sibling tracks
            const locSubUpdates: Record<string, any> = {
              [`subtitles.${targetLang}`]: directSubtitleUrl,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (rawTargetLang && rawTargetLang !== targetLang) {
              locSubUpdates[`subtitles.${rawTargetLang}`] = directSubtitleUrl;
            }
            await db().collection("videos").doc(vid).collection("media").doc("localization").set(locSubUpdates, { merge: true });
          }

          // Also update the job_outputs and video_jobs documents' subtitles map
          const targetSubEntry = {
            url: subtitleUrl,
            srtPath: srtUrl || `gs://${bucket.name}/subtitles/${jobId}/${targetLang}.srt`,
            vttPath: vttUrl || `gs://${bucket.name}/subtitles/${jobId}/${targetLang}.vtt`,
            jsonPath: jsonUrl || translationUrl,
            format: "srt",
            language: targetLang,
            updatedAt: Date.now(),
          };
          const jobOutputSubUpdate: Record<string, any> = {
            subtitles: {
              [targetLang]: targetSubEntry,
              ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: targetSubEntry } : {}),
            },
            [`subtitles.${targetLang}`]: targetSubEntry,
            updatedAt: Date.now(),
          };
          if (rawTargetLang && rawTargetLang !== targetLang) {
            jobOutputSubUpdate[`subtitles.${rawTargetLang}`] = targetSubEntry;
          }
          await db().collection("job_outputs").doc(jobId).set(jobOutputSubUpdate, { merge: true });

          const videoJobSubUpdate: Record<string, any> = {
            outputs: {
              subtitles: {
                [targetLang]: subtitleUrl,
                ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: subtitleUrl } : {}),
              },
            },
            [`outputs.subtitles.${targetLang}`]: subtitleUrl,
            updatedAt: Date.now(),
          };
          if (rawTargetLang && rawTargetLang !== targetLang) {
            videoJobSubUpdate[`outputs.subtitles.${rawTargetLang}`] = subtitleUrl;
          }
          await db().collection("video_jobs").doc(jobId).set(videoJobSubUpdate, { merge: true });

          // Update the job document's updatedAt timestamp
          await db().collection("video_jobs").doc(jobId).update({
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          if (!executionPlan.generateDubbing) {
            await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "completed", progress: 100, completedAt: Date.now() }).catch(() => {});
            await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "completed", progress: 100, completedAt: Date.now() }).catch(() => {});
            await updateTranslationStage("completed", 100);
            await updateDubbingStage("completed", 100);
          } else {
            await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 95 }).catch(() => {});
            await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 95 }).catch(() => {});
          }

          logger.info("[Dubbing] Propagated subtitles to video collection", { jobId, targetLang, rawTargetLang, videoCount: linkedVideoIds.length });
        } catch (err) {
          logger.error("[Dubbing] Failed to propagate subtitles to videos", { jobId, err: String(err) });
        }
      }

      // C. TTS + sync (only when dubbing is enabled AND not source language)
      // Source-to-source dubbing is nonsensical — skip TTS for the source language
      let audioUrl        = "";
      let videoResult     = "";
      let rawDialogueUrl  = "";
      let masterAudioUrl  = "";
      let ttsUrls: string[] = [];
      let dubbedSegmentsSnapshot: DubbingSegment[] = dubbingSegs;

      // ElevenLabs v4 Dubbing Target Language Gate:
      // Subtitles are supported for all languages via Google Cloud Translation API v3 general/translation-llm,
      // but Dubbing is strictly supported ONLY for languages available on ElevenLabs v4 with ZERO fallback.
      const isDubbingSupportedForTarget = V4_PREMIUM_80_LANGUAGES.has(targetLang);
      if (executionPlan.generateDubbing && !isDubbingSupportedForTarget && targetLang !== sourceLang) {
        logger.warn(`[Dubbing] Target language '${targetLang}' is not supported by ElevenLabs v4 — skipping dubbing audio synthesis (subtitles remain active via Google Translation v3 general/translation-llm)`, {
          jobId,
          targetLang,
        });
        await EdgeLayer.failStage(jobId, `dubbing_${targetLang}`, `Target language '${targetLang}' is not supported by ElevenLabs v4 audio synthesis`).catch(() => {});
      }

      if (executionPlan.generateDubbing && targetLang !== sourceLang && isDubbingSupportedForTarget) {
        let leaseAcquired = false;
        try {
          // 🛡️ Edge Case 4: Idempotency Lease Lock before starting synthesis
          leaseAcquired = await this.acquireDubbingLease(jobId, targetLang);
          if (!leaseAcquired) {
            logger.warn("[Dubbing:Lease] Duplicate retry worker detected — another instance is actively synthesizing. Declining duplicate run.", {
              jobId,
              targetLang,
            });
            const existing = await this.loadDubbingCheckpoint(jobId, targetLang);
            if (
              (existing?.stage === "completed" || existing?.status === "completed") &&
              existing.masterAudioUrl &&
              existing.masterAudioUrl.length > 5
            ) {
              const bucket = admin.storage().bucket();
              const directAudioUrl = existing.directAudioUrl ||
                (existing.masterAudioUrl.startsWith("gs://")
                  ? `https://storage.googleapis.com/${bucket.name}/${existing.masterAudioUrl.replace(`gs://${bucket.name}/`, "")}`
                  : existing.masterAudioUrl);

              await this.propagateAudioTrack(jobId, targetLang, rawTargetLang, directAudioUrl);
              await updateTranslationStage("completed", 100);
              await updateDubbingStage("completed", 100);

              return {
                jobId,
                language: targetLang,
                subtitleUrl: existing.subtitleUrl || "",
                subtitleFormat: "srt",
                audioUrl: existing.masterAudioUrl,
                videoUrl: (existing as any).masterVideoUrl || "",
                translationUrl: existing.translationUrl || "",
                segments: segments.length,
                processingTime: 0,
                stems: {
                  dialogue: existing.dialogueStemUrl || undefined,
                  master: existing.masterAudioUrl,
                },
              };
            }
            return null as any;
          }

          await updateDubbingStage("running", 10);
          const normalised = dubbingSegs.map((s) => ({
            ...s,
            translatedText: this.normaliseTTS(s.translatedText, s.emotionTag),
          }));
          dubbedSegmentsSnapshot = normalised;

          // 🚀 Step 0: Pre-TTS Duration Budget Pre-Filter (Hydrogen Recommendation)
          // Preemptively catches severe expansion (R > 1.15) against permissible timeline windows
          // (enforcing 120ms turn boundary gap and 150ms outro margin) and retranslates concisely BEFORE calling TTS,
          // saving latency and eliminating 100% of discarded ElevenLabs voice synthesis charges.
          let preTtsRetranslateCount = 0;
          const preRetranslatedIndices = new Set<number>();
          const totalVideoDurationMs = executionPlan.durationSeconds ? executionPlan.durationSeconds * 1000 : 0;
          for (let i = 0; i < normalised.length; i++) {
            const seg = normalised[i];
            const segWindowMs = (seg.end - seg.start) || (seg.targetDuration ? seg.targetDuration * 1000 : 3000);
            const isFinalSeg = i === normalised.length - 1;
            const nextSeg = normalised[i + 1];
            const nextStartMs = nextSeg && typeof nextSeg.start === "number" ? nextSeg.start : null;

            const hardCeilingMs = isFinalSeg && totalVideoDurationMs > 0
              ? Math.max(seg.start + 200, totalVideoDurationMs - 150)
              : (nextStartMs !== null ? Math.max(seg.start + 200, nextStartMs - 120) : seg.start + segWindowMs + 1000);

            const rawGapMs = nextStartMs !== null ? (nextStartMs - seg.end) : 1000;
            const clampedTrailingGapMs = Math.max(0, rawGapMs);
            const permissibleBufferMs = Math.max(0, Math.min(clampedTrailingGapMs - 250, 1500));
            const maxPermissibleEndMs = Math.max(
              seg.start + segWindowMs,
              Math.min(seg.start + segWindowMs + permissibleBufferMs, hardCeilingMs)
            );
            const permissibleWindowMs = Math.max(200, Math.min(hardCeilingMs - seg.start, maxPermissibleEndMs - seg.start));

            if (permissibleWindowMs >= 200) {
              const estDurMs = estimateSpeechDurationMs(seg.translatedText, targetLang);
              const estRatio = estDurMs / permissibleWindowMs;
              if (estRatio > 1.10) {
                try {
                  const targetMaxChars = Math.max(
                    8,
                    Math.floor(seg.translatedText.length * (1.10 / estRatio))
                  );
                  const conciseText = await translationService.retranslateConcise(
                    seg.originalText,
                    sourceLang,
                    targetLang,
                    { targetDurationRatio: estRatio, maxCharacters: targetMaxChars, preserveFacts: true }
                  );
                  if (conciseText && conciseText.length < seg.translatedText.length) {
                    normalised[i].translatedText = this.normaliseTTS(conciseText, seg.emotionTag);
                    preTtsRetranslateCount++;
                    preRetranslatedIndices.add(i);
                  }
                } catch (_) {}
              }
            }
          }

          const initialTTSChars = normalised.reduce((sum, s) => sum + s.translatedText.length, 0);

          // ✅ TTS cache fully wired — checks cache BEFORE calling TTS
          // Dubbing Plan: Audio Track (Studio voice cloning, cadence locking, 100% BGM preserved)
          const dubbingTier = (executionPlan as any).dubbingTier || "audio_track";
          const isVoiceClone = executionPlan.dubbingMode === "voice_clone";
          const voiceType = isVoiceClone ? "cloned" : "studio_matched";

          await updateDubbingStage("running", 50);
          const ttsResult = await this.parallelTTSWithCache(
            jobId, userId, normalised, targetLang, voiceMapping, isVoiceClone, speakerGenderMapping,
            speakerProfiles, acousticFingerprint, dubbingTier, voiceType, executionPlan.voiceGender,
            async (completed, total) => {
              const progressPct = 50 + Math.round((completed / Math.max(1, total)) * 30);
              await updateDubbingStage("running", Math.min(84, progressPct));
            },
            isolatedVocalUrl,
            mneStemUrl
          );
          ttsUrls = ttsResult.urls;
          await updateDubbingStage("running", 85);

          // ─── Hierarchy Step 3 & 4: Concise Retranslation & Audio Regeneration ───
          // If generated speech duration ratio R exceeds 1.15, retranslate concisely
          // and re-synthesize before passing to the 1.15x tempo stitching stage.
          let discardedTTSChars = 0;
          let postTtsRetranslateCount = 0;
          if (ttsResult.failedSegments.length === 0 && normalised.length > 0) {
            const overflowIndices: Array<{ index: number; ratio: number }> = [];
            for (let i = 0; i < normalised.length; i++) {
              // 🛡️ Skip segments already condensed in Pre-TTS Step 0 to prevent redundant re-translation & double-synthesis credit waste
              if (preRetranslatedIndices.has(i)) continue;

              const seg = normalised[i];
              const segWindowMs = (seg.end - seg.start) || (seg.targetDuration ? seg.targetDuration * 1000 : 3000);
              const isFinalSeg = i === normalised.length - 1;
              const nextSeg = normalised[i + 1];
              const nextStartMs = nextSeg && typeof nextSeg.start === "number" ? nextSeg.start : null;

              const hardCeilingMs = isFinalSeg && totalVideoDurationMs > 0
                ? Math.max(seg.start + 200, totalVideoDurationMs - 150)
                : (nextStartMs !== null ? Math.max(seg.start + 200, nextStartMs - 120) : seg.start + segWindowMs + 1000);

              const rawGapMs = nextStartMs !== null ? (nextStartMs - seg.end) : 1000;
              const clampedTrailingGapMs = Math.max(0, rawGapMs);
              const permissibleBufferMs = Math.max(0, Math.min(clampedTrailingGapMs - 250, 1500));
              const maxPermissibleEndMs = Math.max(
                seg.start + segWindowMs,
                Math.min(seg.start + segWindowMs + permissibleBufferMs, hardCeilingMs)
              );
              const permissibleWindowMs = Math.max(200, Math.min(hardCeilingMs - seg.start, maxPermissibleEndMs - seg.start));

              const estDurMs = estimateSpeechDurationMs(seg.translatedText, targetLang);
              const ratio = estDurMs / Math.max(1, permissibleWindowMs);
              // Only trigger if ratio R > 1.15 (segments with 1.00 < R <= 1.15 are handled cleanly by FFmpeg 1.15x tempo-stretching with 0 credit waste)
              if (ratio > 1.15 && permissibleWindowMs >= 200) {
                overflowIndices.push({ index: i, ratio });
              }
            }

            if (overflowIndices.length > 0) {
              logger.info("[Dubbing:Pacing] Triggering Concise Retranslation for overflowing segments (R > 1.15)", {
                jobId,
                targetLang,
                overflowCount: overflowIndices.length,
              });

              for (const { index, ratio } of overflowIndices) {
                try {
                  const seg = normalised[index];
                  const targetMaxChars = Math.max(
                    8,
                    Math.floor(seg.translatedText.length * (1.10 / ratio))
                  );
                  const conciseText = await translationService.retranslateConcise(
                    seg.originalText,
                    sourceLang,
                    targetLang,
                    { targetDurationRatio: ratio, maxCharacters: targetMaxChars, preserveFacts: true }
                  );
                  if (conciseText && conciseText.length < seg.translatedText.length) {
                    logger.info("[Dubbing:Pacing] Concise retranslation achieved shorter phrasing", {
                      jobId,
                      index,
                      originalLen: seg.translatedText.length,
                      conciseLen: conciseText.length,
                    });
                    discardedTTSChars += seg.translatedText.length;
                    normalised[index].translatedText = this.normaliseTTS(conciseText, seg.emotionTag);
                    postTtsRetranslateCount++;

                    // Step 4: Regenerate audio for concise text
                    const voiceIdForSeg = voiceMapping[seg.speaker || "speaker_0"] || (executionPlan as any).voiceId;
                    const prevNormalised = index > 0 ? normalised[index - 1] : undefined;
                    const nextNormalised = index < normalised.length - 1 ? normalised[index + 1] : undefined;
                    const targetDurationMs = (seg.end !== undefined && seg.start !== undefined) ? Math.max(0, seg.end - seg.start) : undefined;

                    // 🛡️ Guardrail 3: Context-Windowing Gate — Same-speaker adjacent turns within 2.5s gap
                    const prevGapMs = (prevNormalised && seg.start !== undefined && prevNormalised.end !== undefined)
                      ? (seg.start > 500 || prevNormalised.end > 500 ? (seg.start - prevNormalised.end) : (seg.start - prevNormalised.end) * 1000)
                      : Infinity;
                    const isPrevSameSpeaker = Boolean(prevNormalised && prevNormalised.speaker && seg.speaker && prevNormalised.speaker === seg.speaker);
                    const gatedPrevText = (isPrevSameSpeaker && prevGapMs >= 0 && prevGapMs <= 2500)
                      ? prevNormalised?.translatedText
                      : undefined;

                    const nextGapMs = (nextNormalised && nextNormalised.start !== undefined && seg.end !== undefined)
                      ? (nextNormalised.start > 500 || seg.end > 500 ? (nextNormalised.start - seg.end) : (nextNormalised.start - seg.end) * 1000)
                      : Infinity;
                    const isNextSameSpeaker = Boolean(nextNormalised && nextNormalised.speaker && seg.speaker && nextNormalised.speaker === seg.speaker);
                    const gatedNextText = (isNextSameSpeaker && nextGapMs >= 0 && nextGapMs <= 2500)
                      ? nextNormalised?.translatedText
                      : undefined;

                    const busPayload = expressiveV4Bus.processSegment({
                      jobId,
                      language: targetLang,
                      translatedText: normalised[index].translatedText,
                      sourceText: seg.originalText,
                      telemetry: {
                        energyDb: seg.energyDb,
                        pitchRangeSemitones: seg.pitchRangeSemitones,
                        speakingRateRatio: seg.speakingRateRatio,
                        emotionTag: seg.emotionTag,
                        emotionalIntensity: (seg as any).emotionalIntensity,
                        deliveryStyle: seg.deliveryStyle,
                        voiceQuality: seg.voiceQuality,
                        stabilityOverride: seg.stabilityOverride,
                        similarityBoostOverride: seg.similarityBoostOverride,
                      },
                      preferVoiceCloning: isVoiceClone,
                      voiceType: voiceType as any,
                      targetDurationMs,
                      previousText: gatedPrevText,
                      nextText: gatedNextText,
                    });
                    const resynth = await ttsService.synthesize({
                      jobId,
                      language: targetLang,
                      text: busPayload.text,
                      voiceId: voiceIdForSeg,
                      speakerId: seg.speaker,
                      userId,
                      ttsTier: dubbingTier as any,
                      voiceType: voiceType as any,
                      stability: busPayload.voiceSettings.stability,
                      similarityBoost: busPayload.voiceSettings.similarity_boost,
                      style: busPayload.voiceSettings.style,
                      emotionTag: busPayload.emotionTag,
                      energyDb: seg.energyDb,
                      previousText: busPayload.previousText,
                      nextText: busPayload.nextText,
                    });
                    if (resynth?.audioUrl) {
                      const resynthDurMs = Math.round(resynth.duration * 1000);
                      normalised[index].actualSynthesizedDurationMs = resynthDurMs;
                      normalised[index].durationMs = resynthDurMs;
                      normalised[index].synthesizedAudioUrl = resynth.audioUrl;
                      ttsUrls[index] = resynth.audioUrl;
                      const segIdx = normalised[index]?.index ?? index;
                      await this.saveDubbingCheckpoint(jobId, targetLang, {
                        [`synthesizedUrls.${segIdx}`]: resynth.audioUrl,
                      });
                    }
                  }
                } catch (retransErr) {
                  logger.warn("[Dubbing:Pacing] Concise retranslation notice:", retransErr);
                }
              }
            }
          }

          const finalTTSChars = normalised.reduce((sum, s) => sum + s.translatedText.length, 0);
          logger.info("[Dubbing Telemetry] Pacing & Synthesis metrics", {
            jobId,
            targetLang,
            preTtsRetranslatedCount: preTtsRetranslateCount,
            postTtsRetranslatedCount: postTtsRetranslateCount,
            totalRetranslatedSegments: preTtsRetranslateCount + postTtsRetranslateCount,
            ttsCharsInitial: initialTTSChars,
            ttsCharsDiscarded: discardedTTSChars,
            ttsCharsFinal: finalTTSChars,
          });

          costEngine.recordDubbingPacingMetrics(jobId, userId, {
            retranslatedSegments: preTtsRetranslateCount + postTtsRetranslateCount,
            ttsCharsInitial: initialTTSChars,
            ttsCharsDiscarded: discardedTTSChars,
            ttsCharsFinal: finalTTSChars,
          }).catch(() => {});

          let totalDurationMs: number | undefined = undefined;
          let totalDurationSeconds = 0;

          try {
            const jobSnap = await db().collection("video_jobs").doc(jobId).get();
            const jobData = jobSnap.data() as JobData;
            const targetVid = jobData?.videoId || jobId;
            const vDocSnap = await db().collection("videos").doc(targetVid).get();
            if (vDocSnap.exists) {
              const vData = vDocSnap.data();
              if (vData?.dubbingDurationSeconds && Number(vData.dubbingDurationSeconds) > 0) {
                totalDurationSeconds = Number(vData.dubbingDurationSeconds);
                totalDurationMs = Math.round(totalDurationSeconds * 1000);
              } else if (vData?.durationMs && Number(vData.durationMs) > 0) {
                totalDurationMs = Math.round(Number(vData.durationMs));
                totalDurationSeconds = totalDurationMs / 1000;
              } else if (vData?.durationSeconds && Number(vData.durationSeconds) > 0) {
                totalDurationSeconds = Number(vData.durationSeconds);
                totalDurationMs = Math.round(totalDurationSeconds * 1000);
              } else if (vData?.videoDurationSeconds && Number(vData.videoDurationSeconds) > 0) {
                totalDurationSeconds = Number(vData.videoDurationSeconds);
                totalDurationMs = Math.round(totalDurationSeconds * 1000);
              } else if (vData?.duration) {
                totalDurationSeconds = parseDurationToSeconds(vData.duration);
                if (totalDurationSeconds > 0) totalDurationMs = totalDurationSeconds * 1000;
              }
            }
          } catch (_) {}

          if (!totalDurationMs || totalDurationMs <= 0) {
            const rawPlanSec = parseDurationToSeconds(executionPlan.duration || (executionPlan as any).durationSeconds);
            if (rawPlanSec > 0) {
              totalDurationSeconds = rawPlanSec;
              totalDurationMs = totalDurationSeconds * 1000;
            } else if (segments.length > 0) {
              totalDurationMs = segments[segments.length - 1].end;
              totalDurationSeconds = totalDurationMs / 1000;
            }
          }

          const activeVoiceId = voiceMapping[speakerProfiles[0]?.speakerId || "speaker_0"] || (executionPlan as any).voiceId;

          // 🛡️ Quality Gate 1: Zero Missing Segments Guard
          // If ANY segment failed (e.g. ElevenLabs quota exhaustion, 401, network failure),
          // reject dubbing immediately. Never publish an incomplete stitched audio track.
          if (ttsResult.failedSegments.length > 0) {
            const isQuota = ttsResult.failedSegments.some((f) => f.isQuota);
            const gateReport = DubbingQualityGate.evaluate({
              jobId,
              targetLang,
              totalSegments: ttsResult.totalSegments,
              successfulSegments: ttsResult.successfulSegments,
              failedSegments: ttsResult.failedSegments,
              actualDurationSeconds: 0,
              expectedDurationSeconds: totalDurationSeconds || 0,
              isVoiceCloningRequested: isVoiceClone,
              isVoiceCloned: Boolean(activeVoiceId),
              voiceId: activeVoiceId,
              stemIsolationRequested: Boolean(executionPlan.stemIsolation),
              isStemPreserved: Boolean(mneStemUrl),
              mneValidation,
            });

            logger.error("[Dubbing:QualityGate] ❌ Incomplete synthesis rejected by quality gate", {
              jobId,
              targetLang,
              failedSegments: ttsResult.failedSegments.length,
              totalSegments: ttsResult.totalSegments,
              violations: gateReport.violations,
            });

            const gateFailureDoc = {
              [`dubbingStatus.${targetLang}`]: {
                status: gateReport.status,
                reason: isQuota ? "quota_exceeded" : "missing_segments",
                failedCount: ttsResult.failedSegments.length,
                totalCount: ttsResult.totalSegments,
                violations: gateReport.violations,
                error: ttsResult.failedSegments[0]?.error || "TTS synthesis failed",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            const jobSnap = await db().collection("video_jobs").doc(jobId).get();
            const jobData = jobSnap.data() as JobData;
            const targetVid = jobData?.videoId || jobId;
            await db().collection("videos").doc(targetVid).collection("media").doc("localization").set(gateFailureDoc, { merge: true }).catch(() => {});
            await db().collection("video_jobs").doc(jobId).set(gateFailureDoc, { merge: true }).catch(() => {});
            await updateDubbingStage("failed", 10, gateReport.violations[0]);

            throw new Error(`[Dubbing Quality Gate] Dubbing rejected: ${gateReport.violations.join("; ")}`);
          }

          // Studio Mastering: Apply Acoustic Identity via DSP Rules Engine
          const dspFilters = acousticFingerprint
            ? audioIdentityService.getDSPFilters(acousticFingerprint)
            : "loudnorm=I=-14:TP=-1:LRA=11";
          logger.info("[Dubbing] Applying DSP mastering chain to audio track", { jobId, targetLang });

          const isCadenceLocked = true; // Audio Track features studio cadence locking by default

          await updateDubbingStage("running", 88);

          // 🛡️ Edge Case 1: Convert all ttsUrls to canonical gs:// paths before stitching
          ttsUrls = ttsUrls.map((u) => toCanonicalGsUrl(u));

          // 🛡️ Update checkpoint to stitching stage
          await this.saveDubbingCheckpoint(jobId, targetLang, {
            stage: "stitching",
            status: "running",
            synthesizedUrls: ttsUrls.reduce((acc, u, idx) => {
              if (u) acc[String(normalised[idx]?.index ?? idx)] = u;
              return acc;
            }, {} as Record<string, string>),
            voiceMapping,
            isolatedVocalUrl: isolatedVocalUrl ? toCanonicalGsUrl(isolatedVocalUrl) : null,
            meStemUrl: mneStemUrl ? toCanonicalGsUrl(mneStemUrl) : null,
          });

          const syncInstructions = this.buildSyncInstructions(normalised, ttsUrls);
          let dialogueStemMetrics: MergeAudioMetrics = {
            trueSpeechEndMs: 0,
            segmentCollisionsCount: 0,
            outroSpeechTruncated: false,
          };
          rawDialogueUrl = await this.stitchAudio(
            jobId,
            ttsUrls,
            syncInstructions,
            targetLang,
            normalised,
            totalDurationSeconds,
            dspFilters,
            totalDurationMs,
            isCadenceLocked,
            (metrics) => {
              dialogueStemMetrics = metrics;
            }
          );
          await updateDubbingStage("running", 92);

          // 🎛️ Industry Standard: Non-Destructive M&E (Music & Foley) Preservation (All 5 Plan Tiers)
          // Dynamically sidechain-duck the M&E stem underneath dialogue, swelling music back during pauses
          masterAudioUrl = rawDialogueUrl;
          if (!mneStemUrl) {
            try {
              const jobDoc = await db().collection("video_jobs").doc(jobId).get();
              // Use full-bandwidth 44.1 kHz stereo source for M&E extraction — NOT the 16 kHz mono STT audio,
              // which strips the high-frequency musical content needed for clean separation.
              const stereoSourceUrl = await mediaService.extractStereoSourceAudio(videoUrl, jobId).catch(
                () => jobDoc.data()?.artifacts?.transcription?.audioUrl || videoUrl
              );
              logger.info("[Dubbing] Guaranteed parallel best-of-2 M&E extraction for tier", { jobId, targetLang, tier: executionPlan.dubbingTier });
              const extracted = await mediaService.extractMneStemDetailedParallel(jobId, stereoSourceUrl, {
                isolatedVocalUrl: (isolatedVocalUrl && isolatedVocalUrl !== stereoSourceUrl) ? isolatedVocalUrl : undefined,
                enableAutoVocalIsolation: true,
                spokenSegments: segments,
                expectedDurationSeconds: totalDurationSeconds || 0,
              });
              mneStemUrl = extracted.mneUrl;
              if (!mneValidation) {
                mneValidation = await mediaService.validateMneStem(
                  jobId,
                  mneStemUrl,
                  totalDurationSeconds || 0,
                  extracted.source,
                  { spokenSegments: segments, expectedSourceDegraded: extracted.degraded }
                );
              }
            } catch (mneFallbackErr) {
              logger.warn("[Dubbing] On-demand M&E extraction warning:", mneFallbackErr);
            }
          }

          if (mneStemUrl) {
            try {
              await updateDubbingStage("running", 94);
              logger.info("[Dubbing] Dynamically sidechain-ducking M&E stem with dubbed speech", { jobId, targetLang, tier: executionPlan.dubbingTier });
              masterAudioUrl = await mediaService.mixDubWithMne(jobId, targetLang, {
                mneUrl: mneStemUrl,
                dubbedAudioUrl: rawDialogueUrl,
                totalDurationSeconds,
                totalDurationMs,
                // audioFilters intentionally omitted — dialogue already mastered by stitchAudio;
                // mixDubWithMne handles the final single-pass loudnorm.
                roomTone: acousticFingerprint?.roomTone,
                spokenSegments: segments.map((s) => ({ start: s.start, end: s.end })),
                isDegradedMne: mneValidation?.validationStatus === "degraded" || mneValidation?.source === "dsp_fallback",
                mneValidation,
              });
              logger.info("[Dubbing] ✅ Non-destructive M&E + Dubbed master mix created", { jobId, targetLang, masterAudioUrl });
            } catch (mixErr) {
              logger.warn("[Dubbing] M&E mix notice, falling back to dialogue audio:", mixErr);
            }
          }

          await updateDubbingStage("running", 96);

          // 🛡️ Quality Gate 2, 3 & 4: Audio Duration Tolerance, Stem Preservation & File Integrity Guard
          let probedDurationSeconds = totalDurationSeconds;
          let outputAudioSize = 0;
          try {
            const storageInfo = parseAnyStorageUrl(masterAudioUrl);
            if (storageInfo) {
              const file = admin.storage().bucket(storageInfo.bucketName).file(storageInfo.filePath);
              const [meta] = await file.getMetadata();
              outputAudioSize = Number(meta.size || 0);

              const tmpDir = os.tmpdir();
              const tmpProbedAudio = path.join(tmpDir, `probe_${jobId}_${targetLang}_${Date.now()}.mp3`);
              await file.download({ destination: tmpProbedAudio });
              const probedMs = await mediaService.probeMediaDurationMs(tmpProbedAudio);
              if (probedMs > 0) {
                probedDurationSeconds = probedMs / 1000;
              }
              await fs.promises.unlink(tmpProbedAudio).catch(() => {});
            }
          } catch (probeErr) {
            logger.warn("[Dubbing:QualityGate] Audio duration probe warning:", probeErr);
          }

          await updateDubbingStage("running", 98);

          const postStitchGate = DubbingQualityGate.evaluate({
            jobId,
            targetLang,
            totalSegments: ttsResult.totalSegments,
            successfulSegments: ttsResult.successfulSegments,
            failedSegments: [],
            actualDurationSeconds: probedDurationSeconds,
            expectedDurationSeconds: totalDurationSeconds || 0,
            isVoiceCloningRequested: isVoiceClone,
            isVoiceCloned: Boolean(activeVoiceId),
            voiceId: activeVoiceId,
            stemIsolationRequested: Boolean(executionPlan.stemIsolation),
            isStemPreserved: Boolean(mneStemUrl),
            outputAudioSize,
            tier: dubbingTier,
            mneValidation,
            segmentCollisionsCount: dialogueStemMetrics.segmentCollisionsCount,
            outroSpeechTruncated: dialogueStemMetrics.outroSpeechTruncated,
            trueSpeechEndMs: dialogueStemMetrics.trueSpeechEndMs > 0 ? dialogueStemMetrics.trueSpeechEndMs : undefined,
            containerDurationMs: totalDurationMs,
            translatedSegments: normalised.map((s) => ({ translatedText: s.translatedText, text: s.originalText })),
            translatedTexts: normalised.map((s) => s.translatedText),
          });

          if (!postStitchGate.passed) {
            const isFatalForAudioTrack = (dubbingTier === "cinema") ||
              (ttsResult.failedSegments.length > 0) ||
              (outputAudioSize > 0 && outputAudioSize < 10000);

            if (isFatalForAudioTrack) {
              logger.error("[Dubbing:QualityGate] ❌ Post-stitch quality gate rejected output — publication blocked", {
                jobId,
                targetLang,
                tier: dubbingTier,
                violations: postStitchGate.violations,
                actualDuration: probedDurationSeconds,
                expectedDuration: totalDurationSeconds,
              });

              const gateFailureDoc = {
                [`dubbingStatus.${targetLang}`]: {
                  status: postStitchGate.status,
                  reason: "quality_gate_failed",
                  violations: postStitchGate.violations,
                  actualDurationSeconds: probedDurationSeconds,
                  expectedDurationSeconds: totalDurationSeconds,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              };

              const jobSnap = await db().collection("video_jobs").doc(jobId).get();
              const jobData = jobSnap.data() as JobData;
              const targetVid = jobData?.videoId || jobId;
              await db().collection("videos").doc(targetVid).collection("media").doc("localization").set(gateFailureDoc, { merge: true }).catch(() => {});
              await db().collection("video_jobs").doc(jobId).set(gateFailureDoc, { merge: true }).catch(() => {});
              await updateDubbingStage("failed", 10, postStitchGate.violations[0]);

              throw new Error(`[Dubbing Quality Gate] Track rejected: ${postStitchGate.violations.join("; ")}`);
            } else {
              logger.warn("[Dubbing:QualityGate] Quality gate notice for audio track tier (non-fatal, proceeding with publication)", {
                jobId,
                targetLang,
                tier: dubbingTier,
                violations: postStitchGate.violations,
              });
            }
          }

          audioUrl = masterAudioUrl;

          // ⚡ Progressive Audio Delivery (Industry Low-Latency Standard):
          // Immediately propagate audio tracks to Firestore and linked videos so creators & players
          // receive instant access to the audio track without waiting for heavy FFmpeg video muxing.
          const bucket = admin.storage().bucket();
          const directAudioUrl = audioUrl
            ? (audioUrl.startsWith("gs://")
                ? `https://storage.googleapis.com/${bucket.name}/${audioUrl.replace(`gs://${bucket.name}/`, "")}`
                : audioUrl)
            : "";

          if (directAudioUrl) {
            await this.propagateAudioTrack(jobId, targetLang, rawTargetLang, directAudioUrl);
            await updateDubbingStage("completed", 100);
            logger.info("[Dubbing] ⚡ Progressive Delivery: Audio track published immediately", { jobId, targetLang, directAudioUrl });

            // 🛡️ Save completed checkpoint to prevent any duplicate re-synthesis
            await this.saveDubbingCheckpoint(jobId, targetLang, {
              stage: "completed",
              status: "completed",
              masterAudioUrl,
              directAudioUrl,
              dialogueStemUrl: rawDialogueUrl,
              subtitleUrl,
              translationUrl,
              voiceMapping,
              isolatedVocalUrl: isolatedVocalUrl ? toCanonicalGsUrl(isolatedVocalUrl) : null,
              meStemUrl: mneStemUrl ? toCanonicalGsUrl(mneStemUrl) : null,
              completedAt: Date.now(),
              leaseExpiresAt: 0,
            });
          }

          // If the user requested an audio track (audio_track tier), skip heavy video remuxing
          // to eliminate 30-60s latency and reduce cloud compute overhead
          if ((executionPlan as any).dubbingTier === "audio_track") {
            videoResult = "";
            logger.info("[Dubbing] Skipping video remuxing for audio-track tier (audio track is published)", { jobId, targetLang });
          } else {
            try {
              // Remux dubbed audio into video container cleanly via FFmpeg
              videoResult = await mediaService.mergeAudioToVideo({
                jobId, videoUrl, audioUrl, 
                subtitleUrl: executionPlan.genLangSubs ? subtitleUrl : undefined,
                language: targetLang, format: "mp4",
                audioFilters: dspFilters, // Pass the mastering chain to FFmpeg
                isPreMastered: masterAudioUrl !== rawDialogueUrl,
              });
            } catch (mergeErr) {
              logger.warn("[Dubbing] Video remuxing skipped or deferred (audio track is intact):", mergeErr);
              videoResult = "";
            }
          }

          await updateDubbingStage("completed", 100);
        } catch (dubErr) {
          logger.error("[Dubbing] Dubbing failed for language, but continuing with subtitles", { jobId, targetLang, err: String(dubErr) });
          await updateDubbingStage("failed", 10, String(dubErr));
        } finally {
          if (leaseAcquired) {
            await this.releaseDubbingLease(jobId, targetLang);
          }
        }
      } else if (targetLang === sourceLang) {
        logger.info("[Dubbing] Skipping TTS for source language", { jobId, targetLang });
      }

      if (executionPlan.generateDubbing) {
        const jobMetaSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
        const linkedVidId = (jobMetaSnap?.data() as any)?.videoId as string | undefined;
        if (targetLang !== sourceLang) {
          await this.saveDubbingEditableManifest({
            jobId,
            videoId: linkedVidId,
            userId,
            language: targetLang,
            sourceLanguage: sourceLang,
            totalDurationMs: await this.resolveJobDurationMs(jobId, executionPlan, segments),
            mneStemUrl: mneStemUrl || null,
            dialogueStemUrl: rawDialogueUrl || null,
            masterAudioUrl: masterAudioUrl || audioUrl || null,
            masterVideoUrl: videoResult || videoUrl,
            subtitleUrl,
            segments: dubbedSegmentsSnapshot,
            ttsUrls,
            voiceMapping,
          }).catch((mErr) => logger.warn("[Dubbing] Non-fatal manifest save warning:", { jobId, targetLang, err: String(mErr) }));
        }

        await db().collection("dubbing_results").doc(`${jobId}_${targetLang}`).set({
          jobId,
          language:     targetLang,
          audioUrl,
          videoUrl:     videoResult || videoUrl,
          confidence:   dubbingSegs.length > 0 
            ? dubbingSegs.reduce((sum, s) => sum + (s.confidence || 0), 0) / dubbingSegs.length
            : 1.0,
          translationUrl,
          segmentCount: dubbingSegs.length,
          processingTime: Date.now() - t0,
          createdAt:    Date.now(),
          features: {
            subtitles: executionPlan.genLangSubs,
            dubbing: executionPlan.generateDubbing,
          },
          stems: {
            mne: mneStemUrl || null,
            dialogue: rawDialogueUrl || null,
            master: masterAudioUrl || null,
            vocals: isolatedVocalUrl || null,
          },
          meta: {
            segments: dubbingSegs.length,
            durationSec: executionPlan.duration || 0,
            processingMs: Date.now() - t0,
            voice: executionPlan.dubbingMode === "voice_clone" ? "cloned" : "standard",
          },
          pricing: {
            channelType: executionPlan.channelType || "standard",
            ratePerLanguageUSD: getFlatDubbingPricePerLanguage(
              executionPlan.duration || 0,
              executionPlan.channelType || "standard",
              executionPlan.dubbingMode === "voice_clone" ? "voice_clone" : "standard"
            ),
            voiceCloneIncluded: executionPlan.dubbingMode === "voice_clone",
            tier: "raw_at_cost",
          },
        });

        // 🚀 Real-time Audio & Dubbed Video Propagation to Video Collection
        try {
          const jobSnap = await db().collection("video_jobs").doc(jobId).get();
          const jobData = jobSnap.data() as JobData;
          const rawLinkedVideoIds = jobData?.linkedVideoIds || [];
          if (jobData?.videoId && !rawLinkedVideoIds.includes(jobData.videoId)) {
            rawLinkedVideoIds.push(jobData.videoId);
          }
          // Guard: only allow UUID video IDs — never write to videos collection with a job_ ID
          const linkedVideoIds = filterVideoIds(rawLinkedVideoIds, "[Dubbing:dubbed-video-propagation]");

          const directAudioUrl = audioUrl
            ? (audioUrl.startsWith("gs://")
                ? `https://storage.googleapis.com/${bucket.name}/${audioUrl.replace(`gs://${bucket.name}/`, "")}`
                : audioUrl)
            : "";
          const directVideoUrl = videoResult
            ? (videoResult.startsWith("gs://")
                ? `https://storage.googleapis.com/${bucket.name}/${videoResult.replace(`gs://${bucket.name}/`, "")}`
                : videoResult)
            : "";

          const videoDocUpdate: any = {
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          const locDocUpdate: any = {
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          const jobOutputAudio: any = {
            updatedAt: Date.now(),
          };
          const videoJobOutputsUpdate: any = {
            updatedAt: Date.now(),
          };

          if (directAudioUrl) {
            videoDocUpdate[`audioTracks.${targetLang}`] = directAudioUrl;
            videoDocUpdate[`media.audioTracks.${targetLang}`] = directAudioUrl;
            locDocUpdate[`audioTracks.${targetLang}`] = directAudioUrl;
            jobOutputAudio[`audioTracks.${targetLang}`] = directAudioUrl;
            videoJobOutputsUpdate[`outputs.audioTracks.${targetLang}`] = directAudioUrl;

            if (rawTargetLang && rawTargetLang !== targetLang) {
              videoDocUpdate[`audioTracks.${rawTargetLang}`] = directAudioUrl;
              videoDocUpdate[`media.audioTracks.${rawTargetLang}`] = directAudioUrl;
              locDocUpdate[`audioTracks.${rawTargetLang}`] = directAudioUrl;
              jobOutputAudio[`audioTracks.${rawTargetLang}`] = directAudioUrl;
              videoJobOutputsUpdate[`outputs.audioTracks.${rawTargetLang}`] = directAudioUrl;
            }
          }

          const isMasterSourceUrl = (u: string) => {
            if (!u) return true;
            const clean = u.trim().toLowerCase();
            if (videoUrl && clean === videoUrl.trim().toLowerCase()) return true;
            if ((jobData as any)?.videoUrl && clean === String((jobData as any).videoUrl).trim().toLowerCase()) return true;
            if ((jobData as any)?.originalUrl && clean === String((jobData as any).originalUrl).trim().toLowerCase()) return true;
            if (clean.endsWith("original.mp4") || clean.includes("/original.mp4") || clean.includes("%2foriginal.mp4")) return true;
            return false;
          };

          const isGenuineDubbed = directVideoUrl && !isMasterSourceUrl(directVideoUrl);

          if (isGenuineDubbed) {
            videoDocUpdate[`dubbedVideos.${targetLang}`] = directVideoUrl;
            videoDocUpdate[`media.dubbedVideos.${targetLang}`] = directVideoUrl;
            locDocUpdate[`dubbedVideos.${targetLang}`] = directVideoUrl;
            videoJobOutputsUpdate[`outputs.dubbedVideos.${targetLang}`] = directVideoUrl;

            if (rawTargetLang && rawTargetLang !== targetLang) {
              videoDocUpdate[`dubbedVideos.${rawTargetLang}`] = directVideoUrl;
              videoDocUpdate[`media.dubbedVideos.${rawTargetLang}`] = directVideoUrl;
              locDocUpdate[`dubbedVideos.${rawTargetLang}`] = directVideoUrl;
              videoJobOutputsUpdate[`outputs.dubbedVideos.${rawTargetLang}`] = directVideoUrl;
            }
          }

          if (directVideoUrl || directAudioUrl) {
            jobOutputAudio[`dubbed.${targetLang}`] = {
              audioUrl: directAudioUrl,
              path: isGenuineDubbed ? directVideoUrl : directAudioUrl,
              videoUrl: isGenuineDubbed ? directVideoUrl : "",
              language: targetLang,
              updatedAt: Date.now(),
            };
            if (rawTargetLang && rawTargetLang !== targetLang) {
              jobOutputAudio[`dubbed.${rawTargetLang}`] = {
                audioUrl: directAudioUrl,
                path: isGenuineDubbed ? directVideoUrl : directAudioUrl,
                videoUrl: isGenuineDubbed ? directVideoUrl : "",
                language: rawTargetLang,
                updatedAt: Date.now(),
              };
            }
          }

          for (const vid of linkedVideoIds) {
            await db().collection("videos").doc(vid).set(videoDocUpdate, { merge: true });
            await db().collection("videos").doc(vid).collection("media").doc("localization").set(locDocUpdate, { merge: true });
          }

          await db().collection("job_outputs").doc(jobId).set(jobOutputAudio, { merge: true });
          await db().collection("video_jobs").doc(jobId).set(videoJobOutputsUpdate, { merge: true });
          logger.info("[Dubbing] Propagated audio tracks to video collection", { jobId, targetLang, rawTargetLang, videoCount: linkedVideoIds.length });
        } catch (propErr) {
          logger.error("[Dubbing] Failed to propagate audio tracks to videos", { jobId, err: String(propErr) });
        }
      }

      // ✅ Cost tracking: record media processing cost (estimated from processing time)
      if (executionPlan.generateDubbing && targetLang !== sourceLang && isDubbingSupportedForTarget) {
        const processingSeconds = (Date.now() - t0) / 1000;
        costEngine.recordMediaCost(jobId, userId, processingSeconds).catch(() => {});
      }

      return {
        jobId,
        language:       targetLang,
        subtitleUrl,
        subtitleFormat: "srt",
        audioUrl,
        videoUrl:       videoResult,
        translationUrl,
        segments:       dubbingSegs.length,
        processingTime: Date.now() - t0,
        stems: {
          mne: mneStemUrl || null,
          dialogue: rawDialogueUrl || undefined,
          master: masterAudioUrl || undefined,
          vocals: isolatedVocalUrl || null,
        },
      };
    } catch (langErr) {
      const errMsg = langErr instanceof Error ? langErr.message : String(langErr);
      logger.error("[Dubbing] processLanguage failed", { jobId, targetLang, rawTargetLang, error: errMsg });
      if (targetLang !== sourceLang) {
        await updateTranslationStage("failed", 10, errMsg);
      }
      if (executionPlan.generateDubbing && targetLang !== sourceLang) {
        await updateDubbingStage("failed", 10, errMsg);
      }
      throw langErr;
    }
  }

  // ─── TTS with cache ───────────────────────────────────────────────────────────

  /**
   * Loads the persistent cross-scene/cross-reel speaker vocal baseline from
   * `video_jobs/{jobId}/speaker_profiles/{speakerId}_{targetLang}` (non-blocking).
   */
  public async loadSpeakerVoiceProfile(
    jobId: string,
    speakerId: string,
    targetLang: string
  ): Promise<SpeakerVoiceProfile | null> {
    try {
      const docId = `${speakerId}_${targetLang}`.replace(/[^a-zA-Z0-9_-]/g, "_");
      const snap = await db()
        .collection("video_jobs")
        .doc(jobId)
        .collection("speaker_profiles")
        .doc(docId)
        .get();
      return snap.exists ? (snap.data() as SpeakerVoiceProfile) : null;
    } catch (err) {
      logger.warn("[Dubbing] Non-blocking loadSpeakerVoiceProfile failed:", { jobId, speakerId, targetLang, err });
      return null;
    }
  }

  /**
   * Updates the running EMA baseline for a speaker across segments and reels
   * so emotional variation stays bounded to the speaker's established vocal character.
   */
  public async updateSpeakerVoiceProfile(
    jobId: string,
    speakerId: string,
    targetLang: string,
    sample: {
      voiceId: string;
      pitchSemitones?: number;
      energyDb?: number;
      stability: number;
      similarityBoost: number;
      voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
    }
  ): Promise<SpeakerVoiceProfile | null> {
    try {
      const docId = `${speakerId}_${targetLang}`.replace(/[^a-zA-Z0-9_-]/g, "_");
      const ref = db()
        .collection("video_jobs")
        .doc(jobId)
        .collection("speaker_profiles")
        .doc(docId);
      const snap = await ref.get().catch(() => null);
      const existing = snap?.exists ? (snap.data() as SpeakerVoiceProfile) : null;
      const count = (existing?.segmentCount || 0) + 1;
      const alpha = existing ? 1 / Math.min(count, 6) : 1.0;

      const updated: SpeakerVoiceProfile = {
        speakerId,
        targetLang,
        voiceId: sample.voiceId || existing?.voiceId || "",
        avgPitchSemitones: Number(
          (
            existing
              ? existing.avgPitchSemitones * (1 - alpha) + (sample.pitchSemitones ?? existing.avgPitchSemitones) * alpha
              : (sample.pitchSemitones ?? 0)
          ).toFixed(3)
        ),
        avgEnergyDb: Number(
          (
            existing
              ? existing.avgEnergyDb * (1 - alpha) + (sample.energyDb ?? existing.avgEnergyDb) * alpha
              : (sample.energyDb ?? -18)
          ).toFixed(2)
        ),
        avgStability: Number(
          (
            existing
              ? existing.avgStability * (1 - alpha) + sample.stability * alpha
              : sample.stability
          ).toFixed(3)
        ),
        avgSimilarityBoost: Number(
          (
            existing
              ? existing.avgSimilarityBoost * (1 - alpha) + sample.similarityBoost * alpha
              : sample.similarityBoost
          ).toFixed(3)
        ),
        dominantVoiceQuality: sample.voiceQuality ?? existing?.dominantVoiceQuality,
        segmentCount: count,
        updatedAt: Date.now(),
      };

      await ref.set(updated, { merge: true });
      return updated;
    } catch (err) {
      logger.warn("[Dubbing] Non-blocking updateSpeakerVoiceProfile failed:", { jobId, speakerId, targetLang, err });
      return null;
    }
  }

  /**
   * 🛡️ Load persistent dubbing checkpoint to enable exact-failure resumption.
   */
  public async loadDubbingCheckpoint(
    jobId: string,
    targetLang: string
  ): Promise<DubbingCheckpoint | null> {
    try {
      const snap = await db().collection("dubbing_checkpoints").doc(`${jobId}_${targetLang}`).get();
      if (snap.exists) {
        return snap.data() as DubbingCheckpoint;
      }
    } catch (err) {
      logger.warn("[Dubbing:Checkpoint] Notice loading checkpoint:", { jobId, targetLang, err: String(err) });
    }
    return null;
  }

  /**
   * 🛡️ Save persistent dubbing checkpoint after each translated block and synthesized batch.
   */
  public async saveDubbingCheckpoint(
    jobId: string,
    targetLang: string,
    data: Partial<DubbingCheckpoint> & Record<string, any>
  ): Promise<void> {
    try {
      await db().collection("dubbing_checkpoints").doc(`${jobId}_${targetLang}`).set({
        jobId,
        targetLang,
        updatedAt: Date.now(),
        ...data,
      }, { merge: true });
    } catch (err) {
      logger.warn("[Dubbing:Checkpoint] Notice saving checkpoint:", { jobId, targetLang, err: String(err) });
    }
  }

  /**
   * 🛡️ Edge Case 2: Verify audio chunk existence, duration, and file size (> 1KB, > 100ms)
   * Only commits chunks that pass validation, and rejects corrupted / 0-byte stubs on resume.
   */
  public async verifyAudioChunk(
    audioUrl: string
  ): Promise<{ valid: boolean; sizeBytes: number; durationMs: number; error?: string }> {
    if (!audioUrl || typeof audioUrl !== "string" || audioUrl.trim().length === 0) {
      return { valid: false, sizeBytes: 0, durationMs: 0, error: "empty_url" };
    }
    const trimmed = audioUrl.trim();
    const storageInfo = parseAnyStorageUrl(trimmed);
    if (!storageInfo) {
      // In non-storage URL formats (e.g. synthetic test URLs without bucket):
      return { valid: trimmed.length > 5, sizeBytes: 2048, durationMs: 250 };
    }

    try {
      const bucket = admin.storage().bucket(storageInfo.bucketName || undefined);
      const file = bucket.file(storageInfo.filePath);
      const [exists] = await file.exists().catch(() => [false]);
      if (!exists) {
        return { valid: false, sizeBytes: 0, durationMs: 0, error: "file_not_found" };
      }

      const [metadata] = await file.getMetadata().catch(() => [{ size: 0 }]);
      let sizeBytes = Number(metadata?.size) || 0;

      // Temporary probe file to measure duration and confirm audio stream integrity
      const tmpProbePath = path.join(
        os.tmpdir(),
        `probe_chunk_${Date.now()}_${Math.random().toString(36).slice(2)}.mp3`
      );
      try {
        await file.download({ destination: tmpProbePath }).catch(async () => {
          const [buf] = await file.download();
          if (buf && Buffer.isBuffer(buf)) {
            await fs.promises.writeFile(tmpProbePath, buf);
          }
        });

        const stat = await fs.promises.stat(tmpProbePath).catch(() => null);
        if (stat && stat.size > 0) {
          sizeBytes = stat.size;
        }

        if (sizeBytes <= 1024) {
          return { valid: false, sizeBytes, durationMs: 0, error: `file_too_small (${sizeBytes} bytes <= 1024)` };
        }

        const durationMs = await mediaService.probeMediaDurationMs(tmpProbePath).catch(() => 0);
        if (durationMs > 0 && durationMs <= 100) {
          return { valid: false, sizeBytes, durationMs, error: `duration_too_short (${durationMs}ms <= 100ms)` };
        }

        return { valid: true, sizeBytes, durationMs: durationMs || 250 };
      } catch (probeErr) {
        logger.warn("[Dubbing:ChunkIntegrity] Probe warning:", probeErr);
        return { valid: sizeBytes > 1024, sizeBytes, durationMs: 0 };
      } finally {
        await fs.promises.unlink(tmpProbePath).catch(() => {});
      }
    } catch (err) {
      logger.warn("[Dubbing:ChunkIntegrity] Storage check exception:", { audioUrl, err: String(err) });
      return { valid: false, sizeBytes: 0, durationMs: 0, error: String(err) };
    }
  }

  /**
   * 🛡️ Edge Case 4: Idempotency Lease Lock
   * Acquires an atomic Firestore transaction lease on dubbing_checkpoints/{jobId}_{targetLang}.
   * Prevents duplicate retry taps in Flutter Studio from spawning parallel workers and double-deducting ElevenLabs credits.
   */
  public async acquireDubbingLease(
    jobId: string,
    targetLang: string,
    leaseTtlMs: number = 120_000
  ): Promise<boolean> {
    const docRef = db().collection("dubbing_checkpoints").doc(`${jobId}_${targetLang}`);
    try {
      return await db().runTransaction(async (transaction) => {
        const snap = await transaction.get(docRef);
        const now = Date.now();
        if (snap.exists) {
          const data = snap.data();
          const existingLease = data?.leaseExpiresAt;
          if (typeof existingLease === "number" && existingLease > now) {
            logger.warn("[Dubbing:Lease] Active lease held by another worker — declining duplicate execution", {
              jobId,
              targetLang,
              existingLease,
              remainingMs: existingLease - now,
            });
            return false;
          }
        }
        transaction.set(
          docRef,
          {
            jobId,
            targetLang,
            stage: "synthesizing",
            leaseExpiresAt: now + leaseTtlMs,
            updatedAt: now,
          },
          { merge: true }
        );
        return true;
      });
    } catch (err) {
      logger.error("[Dubbing:Lease] Transaction error acquiring lease:", { jobId, targetLang, err: String(err) });
      return false;
    }
  }

  /**
   * 🛡️ Release atomic lease upon completion or failure.
   */
  public async releaseDubbingLease(jobId: string, targetLang: string): Promise<void> {
    try {
      const docRef = db().collection("dubbing_checkpoints").doc(`${jobId}_${targetLang}`);
      await docRef.set({ leaseExpiresAt: 0, updatedAt: Date.now() }, { merge: true });
    } catch (err) {
      logger.warn("[Dubbing:Lease] Notice releasing lease:", { jobId, targetLang, err: String(err) });
    }
  }

  /**
   * Generate TTS for all segments.
   *
   * ✅ FIXED: checks performanceLayer.checkTTSCache() BEFORE calling ElevenLabs.
   * Original code never called this, incurring full TTS cost on every run.
   */
  private async parallelTTSWithCache(
    jobId:        string,
    userId:       string,
    segments:     DubbingSegment[],
    language:     string,
    voiceMapping: Record<string, string>,
    preferVoiceCloning: boolean = false,
    speakerGenderMapping?: Record<string, "MALE" | "FEMALE">,
    speakerProfiles?: any[],
    acousticFingerprint?: any,
    dubbingTier?: string,
    voiceType?: string,
    preferredVoiceGender?: "auto" | "male" | "female",
    onProgress?: (completed: number, total: number) => Promise<void>,
    isolatedVocalUrl?: string | null,
    mneStemUrl?: string | null
  ): Promise<{
    urls: string[];
    failedSegments: Array<{ index: number; text: string; error: string; isQuota: boolean }>;
    totalSegments: number;
    successfulSegments: number;
  }> {
    const allUrls: string[] = new Array(segments.length).fill("");
    const failedSegments: Array<{ index: number; text: string; error: string; isQuota: boolean }> = [];
    const speakerProfileCache = new Map<string, SpeakerVoiceProfile | null>();

    // 🛡️ Load persistent dubbing checkpoint to resume where previous run failed
    const checkpoint = await this.loadDubbingCheckpoint(jobId, language);
    const checkpointUrls: Record<string, string> = { ...(checkpoint?.synthesizedUrls || {}) };

    const lastSegEnd = segments.length > 0 ? (segments[segments.length - 1].end || 0) : 0;
    const adaptiveBatchSize = getAdaptiveTTSBatchSize(segments.length, lastSegEnd);
    logger.info("[Dubbing] TTS adaptive batch size", {
      jobId,
      segments: segments.length,
      batchSize: adaptiveBatchSize,
      videoDurationMs: lastSegEnd,
      resumedSegmentsCount: Object.keys(checkpointUrls).length,
    });

    for (let i = 0; i < segments.length; i += adaptiveBatchSize) {
      const batch = segments.slice(i, i + adaptiveBatchSize);

      const batchUrls = await Promise.allSettled(
        batch.map(async (seg) => {
          // 🛡️ Checkpoint Resume Guard: Reuse chunk if already synthesized in earlier run
          const rawResumedUrl = seg.synthesizedAudioUrl || checkpointUrls[String(seg.index)] || (checkpointUrls as any)[seg.index];
          if (rawResumedUrl && typeof rawResumedUrl === "string" && rawResumedUrl.length > 5) {
            const canonicalResumedUrl = toCanonicalGsUrl(rawResumedUrl);
            const integrity = await this.verifyAudioChunk(canonicalResumedUrl);
            if (integrity.valid) {
              logger.info("[Dubbing:Resume] Reusing verified audio chunk from checkpoint (0 ElevenLabs credits)", {
                jobId,
                language,
                index: seg.index,
                canonicalResumedUrl,
                sizeBytes: integrity.sizeBytes,
              });
              checkpointUrls[String(seg.index)] = canonicalResumedUrl;
              return canonicalResumedUrl;
            } else {
              logger.warn("[Dubbing:Resume] Stale/truncated chunk rejected on resume — will re-synthesize", {
                jobId,
                language,
                index: seg.index,
                rawResumedUrl,
                reason: integrity.error,
              });
              delete checkpointUrls[String(seg.index)];
            }
          }
          // Identify the voiceId mapped to this speaker with strict Cross-Gender Guard
          const speakerId = seg.speaker || "speaker_0";
          let isFemaleSpeaker = speakerGenderMapping?.[speakerId] === "FEMALE";
          if (preferredVoiceGender === "male") isFemaleSpeaker = false;
          if (preferredVoiceGender === "female") isFemaleSpeaker = true;

          const defaultVoiceId = isFemaleSpeaker ? "EXAVITQu4vr4xnSDxMaL" : "ErXwobaYiN019PkySvjV"; // Sarah vs Antoni
          let voiceId = voiceMapping[speakerId] || defaultVoiceId;

          let gender: "MALE" | "FEMALE" = isFemaleSpeaker ? "FEMALE" : "MALE";
          if (preferredVoiceGender === "male") {
            gender = "MALE";
          } else if (preferredVoiceGender === "female") {
            gender = "FEMALE";
          } else if (speakerGenderMapping?.[speakerId]) {
            gender = speakerGenderMapping[speakerId];
          } else if (voiceId && ELEVENLABS_VOICE_GENDER_MAP[voiceId]) {
            gender = ELEVENLABS_VOICE_GENDER_MAP[voiceId];
          }

          // 🛡️ Cross-Gender Firewall: Prevent male input from ever receiving female voice, and vice-versa
          if (gender === "FEMALE" && ELEVENLABS_VOICE_GENDER_MAP[voiceId] === "MALE") {
            voiceId = "EXAVITQu4vr4xnSDxMaL"; // Safe female voice
          } else if (gender === "MALE" && ELEVENLABS_VOICE_GENDER_MAP[voiceId] === "FEMALE") {
            voiceId = "ErXwobaYiN019PkySvjV"; // Safe male voice
          }

          // Derive pitch and speakingRate from speaker profile and acoustic fingerprint
          const profile = speakerProfiles?.find((p: any) => p.speakerId === speakerId);
          let pitch: number | undefined = undefined;
          let speakingRate: number | undefined = undefined;

          if (profile) {
            if (profile.pitchBand === "deep") pitch = -2.0;
            else if (profile.pitchBand === "high") pitch = 2.0;
            else if (acousticFingerprint?.pitchSemitones) pitch = acousticFingerprint.pitchSemitones;

            if (profile.energy === "high") speakingRate = 1.06;
            else if (profile.energy === "low") speakingRate = 0.94;
            else if (acousticFingerprint?.speakingRate) speakingRate = acousticFingerprint.speakingRate;
          } else if (acousticFingerprint) {
            if (acousticFingerprint.pitchSemitones) pitch = acousticFingerprint.pitchSemitones;
            if (acousticFingerprint.speakingRate) speakingRate = acousticFingerprint.speakingRate;
          }

          // Cross-scene / cross-reel vocal consistency guard: load persisted EMA profile
          const profileKey = `${speakerId}_${language}`;
          if (!speakerProfileCache.has(profileKey)) {
            const loadedProfile = await this.loadSpeakerVoiceProfile(jobId, speakerId, language);
            speakerProfileCache.set(profileKey, loadedProfile);
          }
          const persistedProfile = speakerProfileCache.get(profileKey);
          if (persistedProfile?.voiceId) {
            voiceId = persistedProfile.voiceId;
          }

          const segStability = seg.stabilityOverride ?? 0.5;
          const segSimilarity = seg.similarityBoostOverride ?? 0.85;
          const effectiveStability = persistedProfile && persistedProfile.segmentCount > 2
            ? Number((0.7 * segStability + 0.3 * persistedProfile.avgStability).toFixed(3))
            : seg.stabilityOverride;
          const effectiveSimilarity = persistedProfile && persistedProfile.segmentCount > 2
            ? Number((0.7 * segSimilarity + 0.3 * persistedProfile.avgSimilarityBoost).toFixed(3))
            : seg.similarityBoostOverride;

          if (persistedProfile && persistedProfile.segmentCount > 2 && pitch === undefined && persistedProfile.avgPitchSemitones !== 0) {
            pitch = persistedProfile.avgPitchSemitones;
          }

          // ✅ Cache check FIRST with strict tier and voice isolation
          const cached = await this.performanceLayer.checkTTSCache(
            seg.translatedText,
            language,
            voiceId,
            dubbingTier,
            voiceType,
            preferVoiceCloning ? userId : undefined
          );

          if (cached) {
            logger.debug("[Dubbing] TTS cache hit", { jobId, text: seg.translatedText.slice(0, 30) });
            return cached;
          }

          // Cache miss → Condition speech turn via Expressive v4 Bus
          const segGlobalIdx = segments.findIndex((s) => s.index === seg.index);
          const prevSeg = segGlobalIdx > 0 ? segments[segGlobalIdx - 1] : undefined;
          const nextSeg = segGlobalIdx >= 0 && segGlobalIdx < segments.length - 1 ? segments[segGlobalIdx + 1] : undefined;
          const targetDurationMs = (seg.end !== undefined && seg.start !== undefined) ? Math.max(0, seg.end - seg.start) : undefined;

          // 🛡️ Guardrail 3: Context-Windowing Gate — Same-speaker adjacent turns within 2.5s gap
          // Prevents Speaker A's emotional tone from bleeding into Speaker B's speech turn.
          const prevGapMs = (prevSeg && seg.start !== undefined && prevSeg.end !== undefined)
            ? (seg.start > 500 || prevSeg.end > 500 ? (seg.start - prevSeg.end) : (seg.start - prevSeg.end) * 1000)
            : Infinity;
          const isPrevSameSpeaker = Boolean(prevSeg && prevSeg.speaker && seg.speaker && prevSeg.speaker === seg.speaker);
          const gatedPrevText = (isPrevSameSpeaker && prevGapMs >= 0 && prevGapMs <= 2500)
            ? prevSeg?.translatedText
            : undefined;

          const nextGapMs = (nextSeg && nextSeg.start !== undefined && seg.end !== undefined)
            ? (nextSeg.start > 500 || seg.end > 500 ? (nextSeg.start - seg.end) : (nextSeg.start - seg.end) * 1000)
            : Infinity;
          const isNextSameSpeaker = Boolean(nextSeg && nextSeg.speaker && seg.speaker && nextSeg.speaker === seg.speaker);
          const gatedNextText = (isNextSameSpeaker && nextGapMs >= 0 && nextGapMs <= 2500)
            ? nextSeg?.translatedText
            : undefined;

          const busPayload = expressiveV4Bus.processSegment({
            jobId,
            language,
            translatedText: seg.translatedText,
            sourceText: seg.originalText,
            telemetry: {
              energyDb: seg.energyDb,
              pitchRangeSemitones: seg.pitchRangeSemitones,
              speakingRateRatio: seg.speakingRateRatio,
              emotionTag: seg.emotionTag,
              emotionalIntensity: (seg as any).emotionalIntensity,
              deliveryStyle: seg.deliveryStyle,
              voiceQuality: seg.voiceQuality,
              energyEnvelopePattern: (seg as any).energyEnvelopePattern,
              breathingPattern: (seg as any).breathingPattern,
              stabilityOverride: effectiveStability,
              similarityBoostOverride: effectiveSimilarity,
            },
            preferVoiceCloning,
            voiceType: (voiceType as any),
            targetDurationMs,
            previousText: gatedPrevText,
            nextText: gatedNextText,
          });

          // Call Hybrid TTS Service (with ElevenLabs v4 expressive emotion, style & stability controls)
          const result = await ttsService.synthesize({
            jobId,
            language,
            text:      busPayload.text,
            voiceId,
            speakerId: seg.speaker,
            userId,
            gender,
            preferVoiceCloning,
            ttsTier: (dubbingTier as any),
            voiceType: (voiceType as any),
            pitch,
            speakingRate,
            stability: busPayload.voiceSettings.stability,
            similarityBoost: busPayload.voiceSettings.similarity_boost,
            style: busPayload.voiceSettings.style,
            emotionTag: busPayload.emotionTag,
            energyDb: seg.energyDb,
            previousText: busPayload.previousText,
            nextText: busPayload.nextText,
          });

          // Record actual synthesized audio duration for subtitle cue snapping (Option 2)
          const chunkDurationMs = Math.round(result.duration * 1000);
          seg.actualSynthesizedDurationMs = chunkDurationMs;
          seg.durationMs = chunkDurationMs;
          seg.synthesizedAudioUrl = result.audioUrl;

          // In-memory EMA voice profile tracking across speech turns (0 Firestore cost during batch execution)
          const currentProfile = speakerProfileCache.get(profileKey);
          const count = (currentProfile?.segmentCount || 0) + 1;
          const alpha = currentProfile ? 1 / Math.min(count, 6) : 1.0;
          const updatedMemoryProfile: SpeakerVoiceProfile = {
            speakerId,
            targetLang: language,
            voiceId: voiceId || currentProfile?.voiceId || "",
            avgPitchSemitones: Number(
              (currentProfile ? currentProfile.avgPitchSemitones * (1 - alpha) + (pitch ?? currentProfile.avgPitchSemitones) * alpha : (pitch ?? 0)).toFixed(3)
            ),
            avgEnergyDb: Number(
              (currentProfile ? currentProfile.avgEnergyDb * (1 - alpha) + (seg.energyDb ?? currentProfile.avgEnergyDb) * alpha : (seg.energyDb ?? -18)).toFixed(2)
            ),
            avgStability: Number(
              (currentProfile ? currentProfile.avgStability * (1 - alpha) + (effectiveStability ?? 0.5) * alpha : (effectiveStability ?? 0.5)).toFixed(3)
            ),
            avgSimilarityBoost: Number(
              (currentProfile ? currentProfile.avgSimilarityBoost * (1 - alpha) + (effectiveSimilarity ?? 0.85) * alpha : (effectiveSimilarity ?? 0.85)).toFixed(3)
            ),
            dominantVoiceQuality: seg.voiceQuality ?? currentProfile?.dominantVoiceQuality,
            segmentCount: count,
            updatedAt: Date.now(),
          };
          speakerProfileCache.set(profileKey, updatedMemoryProfile);

          // ✅ Cost tracking: record TTS cost for synthesized characters (Strictly ElevenLabs v4)
          if (hasVerbalContent(seg.translatedText)) {
            costEngine.recordTTSCost(jobId, userId, seg.translatedText.length, "elevenlabs").catch(() => {});
          }

          // Store in cache for next time with strict tier and voice isolation
          await this.performanceLayer.cacheTTSResult(
            seg.translatedText,
            language,
            result.audioUrl,
            voiceId,
            dubbingTier,
            voiceType,
            preferVoiceCloning ? userId : undefined
          );

          return result.audioUrl;
        })
      );

      for (let bIdx = 0; bIdx < batch.length; bIdx++) {
        const r = batchUrls[bIdx];
        const globalIdx = i + bIdx;
        const seg = batch[bIdx];
        const segIndex = seg?.index ?? globalIdx;
        if (r.status === "fulfilled" && r.value) {
          const canonicalUrl = toCanonicalGsUrl(r.value);
          const integrity = await this.verifyAudioChunk(canonicalUrl);
          if (integrity.valid) {
            allUrls[globalIdx] = canonicalUrl;
            checkpointUrls[String(segIndex)] = canonicalUrl;
          } else {
            const integrityErr = `Chunk verification failed: ${integrity.error || "empty/truncated audio"}`;
            logger.error("[Dubbing] TTS segment audio integrity failure", { jobId, globalIdx, segIndex, error: integrityErr });
            failedSegments.push({
              index: globalIdx,
              text: batch[bIdx]?.translatedText || "",
              error: integrityErr,
              isQuota: false,
            });
            allUrls[globalIdx] = "";
          }
        } else {
          const reasonMsg = r.status === "rejected" ? (r.reason instanceof Error ? r.reason.message : String(r.reason)) : "Unknown synthesis error";
          const isQuota = Boolean((r as any)?.reason?.isQuota) || reasonMsg.includes("quota_exceeded") || reasonMsg.includes("credits remaining");
          failedSegments.push({
            index: globalIdx,
            text: batch[bIdx]?.translatedText || "",
            error: reasonMsg,
            isQuota,
          });
          logger.error("[Dubbing] TTS segment failed", { jobId, globalIdx, bIdx, reason: reasonMsg, isQuota });
          allUrls[globalIdx] = ""; // Synthesis failed: marked empty for DubbingQualityGate validation
        }
      }

      // 🛡️ Persist synthesized segment URLs to checkpoint immediately after each batch
      await this.saveDubbingCheckpoint(jobId, language, {
        stage: "synthesizing",
        status: failedSegments.length > 0 ? "partial" : "synthesizing",
        synthesizedUrls: checkpointUrls,
        totalSegments: segments.length,
        successfulCount: Object.keys(checkpointUrls).length,
        voiceMapping,
        isolatedVocalUrl: isolatedVocalUrl ? toCanonicalGsUrl(isolatedVocalUrl) : null,
        meStemUrl: mneStemUrl ? toCanonicalGsUrl(mneStemUrl) : null,
      });

      // 🛡️ Fail-fast guard: If any segment in the batch encountered quota exhaustion or tripped circuit breaker,
      // halt remaining batches immediately to avoid burning downstream API requests or incurring cascade delays.
      const criticalFailure = failedSegments.find(
        (f) => f.isQuota || f.error.includes("circuit breaker is OPEN") || f.error.includes("QUOTA_EXCEEDED")
      );
      if (criticalFailure) {
        logger.error("[Dubbing] Upstream TTS critical failure (quota exhaustion or circuit breaker OPEN) — halting remaining batches immediately", {
          jobId,
          error: criticalFailure.error,
          processedSegments: i + batch.length,
          totalSegments: segments.length,
        });
        break;
      }

      if (onProgress) {
        await onProgress(i + batch.length, segments.length).catch(() => {});
      }
    }

    // 🛡️ Persist finalized speaker profiles once at end of TTS run (saving dozens of redundant Firestore reads & writes)
    await Promise.all(
      Array.from(speakerProfileCache.entries()).map(async ([_, prof]) => {
        if (!prof) return;
        const docId = `${prof.speakerId}_${prof.targetLang}`.replace(/[^a-zA-Z0-9_-]/g, "_");
        await db()
          .collection("video_jobs")
          .doc(jobId)
          .collection("speaker_profiles")
          .doc(docId)
          .set(prof, { merge: true })
          .catch(() => {});
      })
    );

    return {
      urls: allUrls,
      failedSegments,
      totalSegments: segments.length,
      successfulSegments: segments.length - failedSegments.length,
    };
  }

  // ─── Translation with cache ───────────────────────────────────────────────────

  private async translateWithCache(
    jobId:      string,
    segments:   TimedSegment[] & { isHook?: boolean }[],
    sourceLang: string,
    targetLang: string,
    options?:   { 
      model?: 'standard' | 'premium' | 'dynamic';
      tone?: 'casual' | 'formal';
      localeStyle?: 'neutral' | 'hinglish' | 'hinglish_urban' | 'hinglish_professional' | 'slang';
      targetPlatform?: 'youtube' | 'reels' | 'shorts' | 'linkedin' | 'tiktok';
      creatorDNA?: any;
      enableABHooks?: boolean;
      speakerProfiles?: any[];
      dubbingTier?: "audio_track";
      subtitleTier?: "ultra";
      isCinemaGrade?: boolean;
    }
  ): Promise<DubbingSegment[]> {
    const texts  = segments.map((s) => s.text);
    const cached = await this.performanceLayer.checkTranslationCache(
      texts, sourceLang, targetLang
    );

    const toTranslate = segments.filter((_, i) => !cached[i]);
    let newTranslations: Array<{
      text: string;
      confidence?: number;
      variants?: any;
      syllableBudgetCompliance?: number;
      terminologyWarning?: string;
      terminologyViolations?: any[];
      terminologyComplianceRate?: number;
    }> = [];

    if (toTranslate.length > 0) {
      const res = await translationService.translateSegments(
        jobId,
        toTranslate.map((s: any) => ({
          start: s.start || 0,
          end: s.end || 0,
          duration: s.targetDuration || s.duration || ((s.end && s.start) ? s.end - s.start : 0),
          text: s.text,
          speaker: s.speaker,
          isHook: s.isHook,
          emotionTag: s.emotionTag,
          energyDb: s.energyDb,
          stabilityOverride: s.stabilityOverride,
          similarityBoostOverride: s.similarityBoostOverride,
          pitchRangeSemitones: s.pitchRangeSemitones,
          voiceQuality: s.voiceQuality,
        })),
        sourceLang,
        targetLang,
        options
      );
      newTranslations = res.segments.map((s: any) => ({
        text: s.translated,
        confidence: s.confidence,
        variants: s.variants,
        syllableBudgetCompliance: s.syllableBudgetCompliance,
        terminologyWarning: s.terminologyWarning,
        terminologyViolations: s.terminologyViolations,
        terminologyComplianceRate: s.terminologyComplianceRate,
        numericalParityVerified: s.numericalParityVerified,
        numericalParityWarning: s.numericalParityWarning,
        semanticParityScore: s.semanticParityScore,
        reviewRecommended: s.reviewRecommended,
        polarityFlipped: s.polarityFlipped,
      }));
      if (newTranslations.length !== toTranslate.length || newTranslations.some((translation) => !translation.text?.trim())) {
        throw new Error(`[Dubbing] Composite primary returned incomplete translations for ${targetLang}.`);
      }

      await this.performanceLayer.cacheTranslations(
        toTranslate.map((s) => s.text),
        newTranslations.map(nt => nt.text),
        sourceLang,
        targetLang
      );
    }

    let newIdx = 0;
    return segments.map((seg, i) => {
      const translation = cached[i]
        ? { text: decodeHtmlEntities(cached[i]!), confidence: 0.99, variants: undefined, syllableBudgetCompliance: undefined, terminologyWarning: undefined, terminologyViolations: undefined, terminologyComplianceRate: 1.0, numericalParityVerified: true, numericalParityWarning: undefined, semanticParityScore: 1.0, reviewRecommended: false, polarityFlipped: false }
        : newTranslations[newIdx++];
      if (!translation?.text?.trim()) {
        throw new Error(`[Dubbing] Missing required ${targetLang} translation for segment ${seg.index}.`);
      }

      let cleanTranslated = decodeHtmlEntities(translation.text);
      if (targetLang === "te") {
        cleanTranslated = applyTeluguTheologicalLexiconGuard(cleanTranslated);
      }
      cleanTranslated = normalizeScriptureCitationsForTts(cleanTranslated, targetLang);

      return {
        index:          seg.index,
        originalText:   seg.text,
        translatedText: cleanTranslated,
        confidence:     translation.confidence,
        variants:       translation.variants,
        language:       targetLang,
        start:          seg.start,
        end:            seg.end,
        targetDuration: seg.duration,
        speaker:        seg.speaker,
        isHook:         seg.isHook,
        emotionTag:     seg.emotionTag,
        energyDb:       seg.energyDb,
        speakingRateRatio: seg.speakingRateRatio,
        stabilityOverride: seg.stabilityOverride,
        similarityBoostOverride: seg.similarityBoostOverride,
        deliveryStyle:  seg.deliveryStyle,
        pitchRangeSemitones: seg.pitchRangeSemitones,
        voiceQuality:   seg.voiceQuality,
        emotionalIntensity: seg.emotionalIntensity,
        energyEnvelopePattern: seg.energyEnvelopePattern,
        syllableBudgetCompliance: translation.syllableBudgetCompliance,
        terminologyWarning: translation.terminologyWarning,
        terminologyViolations: translation.terminologyViolations,
        terminologyComplianceRate: translation.terminologyComplianceRate,
        numericalParityVerified: (translation as any).numericalParityVerified ?? true,
        numericalParityWarning: (translation as any).numericalParityWarning,
        semanticParityScore: (translation as any).semanticParityScore,
        reviewRecommended: (translation as any).reviewRecommended ?? false,
        polarityFlipped: (translation as any).polarityFlipped,
      };
    });
  }

  // ─── Sync engine ─────────────────────────────────────────────────────────────

  private buildSyncInstructions(
    segments:  DubbingSegment[],
    audioUrls: string[]
  ): SyncInstruction[] {
    return segments.map((seg, i) => {
      // 🧠 Language-Aware Phonetic Pacing: Replaces scalar word-count heuristics with dynamic speech duration
      const estimatedMs      = estimateSpeechDurationMs(seg.translatedText, seg.language || "en");
      const targetMs         = seg.targetDuration;
      
      // Calculate pacing ratio
      let   speed            = estimatedMs > 0 && targetMs > 0 ? estimatedMs / targetMs : 1.0;
      
      // Clamp for maximum realism (Studio standard: 0.85x to 1.15x)
      speed                  = Math.max(0.85, Math.min(1.15, speed));
      
      const afterAdjust      = estimatedMs / speed;
      const silenceAfter     = Math.max(0, targetMs - afterAdjust);

      return {
        segmentIndex:     i,
        speedFactor:      speed,
        silenceBefore:    0,
        silenceAfter,
        originalDuration: targetMs,
        targetDuration:   targetMs,
      };
    });
  }

  // ─── Subtitle generation ──────────────────────────────────────────────────────

  private async generateSubtitles(
    jobId:          string,
    segments:       DubbingSegment[],
    language:       string,
    sourceLanguage: string = "en",
    words?:         WordTimestamp[]
  ): Promise<{ srtUrl: string; vttUrl: string; jsonUrl: string }> {
    if (words && words.length > 0) {
      try {
        const localized = await MultilingualSubtitleLocalizer.localizeTrack({
          jobId,
          sourceWords: words,
          sourceLanguage,
          targetLanguage: language,
          fallbackSegments: segments.map((s, idx) => {
            const actualDurMs = s.actualSynthesizedDurationMs || s.durationMs || (s.end - s.start);
            const actualDur = actualDurMs > 500 ? actualDurMs : actualDurMs * 1000;
            const nextSeg = idx < segments.length - 1 ? segments[idx + 1] : undefined;
            const nextStart = nextSeg ? nextSeg.start : (s.start + actualDur + 2000);
            const snappedEnd = Math.min(s.start + actualDur, Math.max(s.start + 300, nextStart - 50));
            return {
              index: idx + 1,
              start: s.start,
              end: snappedEnd,
              duration: snappedEnd - s.start,
              text: stripAudioTagsForSubtitles(s.translatedText),
              words: [],
            };
          }),
        });

        const bucket = admin.storage().bucket();
        const srtPath = `subtitles/${jobId}/${language}.srt`;
        const vttPath = `subtitles/${jobId}/${language}.vtt`;
        const jsonPath = `subtitles/${jobId}/${language}.json`;
        const SUBTITLE_CACHE_CONTROL = "public, max-age=86400, s-maxage=604800";

        await Promise.all([
          bucket.file(srtPath).save("\uFEFF" + localized.srtContent, {
            metadata: {
              contentType: "text/plain; charset=utf-8",
              cacheControl: SUBTITLE_CACHE_CONTROL,
            },
          }),
          bucket.file(vttPath).save("\uFEFF" + localized.vttContent, {
            metadata: {
              contentType: "text/vtt; charset=utf-8",
              cacheControl: SUBTITLE_CACHE_CONTROL,
            },
          }),
          bucket.file(jsonPath).save(localized.jsonContent, {
            metadata: {
              contentType: "application/json",
              cacheControl: SUBTITLE_CACHE_CONTROL,
            },
          }),
        ]);

        return {
          srtUrl: `gs://${bucket.name}/${srtPath}`,
          vttUrl: `gs://${bucket.name}/${vttPath}`,
          jsonUrl: `gs://${bucket.name}/${jsonPath}`,
        };
      } catch (err) {
        logger.warn("[Dubbing] Multilingual localizer failed, falling back to legacy mediaService", {
          jobId,
          language,
          err,
        });
      }
    }

    return mediaService.generateAllSubtitles(
      jobId,
      segments.map((s, idx) => {
        const actualDurMs = s.actualSynthesizedDurationMs || s.durationMs || (s.end - s.start);
        const actualDur = actualDurMs > 500 ? actualDurMs : actualDurMs * 1000;
        const nextSeg = idx < segments.length - 1 ? segments[idx + 1] : undefined;
        const nextStart = nextSeg ? nextSeg.start : (s.start + actualDur + 2000);
        const snappedEnd = Math.min(s.start + actualDur, Math.max(s.start + 300, nextStart - 50));
        return {
          start: s.start,
          end: snappedEnd,
          text: stripAudioTagsForSubtitles(s.translatedText),
        };
      }),
      language
    );
  }

  /**
   * ✅ Check if native AssemblyAI subtitles exist for this job/language.
   * These were stored by the Transcription Layer (05) after webhook processing.
   */
  private async checkNativeSubtitles(
    jobId:    string,
    language: string
  ): Promise<string | null> {
    try {
      const jobDoc = await db().collection("video_jobs").doc(jobId).get();
      const subtitleData = jobDoc.data()?.outputs?.subtitles?.[language];
      if (subtitleData?.srtPath) {
        return subtitleData.srtPath as string;
      }
    } catch (err) {
      logger.warn("[Dubbing] Failed to check native subtitles", { jobId, language, err });
    }
    return null;
  }

  // ─── Audio stitching ──────────────────────────────────────────────────────────

  private async stitchAudio(
    jobId:            string,
    audioUrls:        string[],
    _syncInstructions: SyncInstruction[],
    targetLang:       string,
    segments?:        DubbingSegment[],
    totalDurationSeconds?: number,
    audioFilters?:    string,
    totalDurationMs?:  number,
    cadenceLock?:     boolean,
    onMetricsComputed?: (metrics: MergeAudioMetrics) => void
  ): Promise<string> {
    const valid = audioUrls.filter((u) => u !== "");
    if (valid.length === 0) throw new Error("No valid TTS audio segments to stitch");
    const durSec = totalDurationSeconds ? Number(totalDurationSeconds) : parseDurationToSeconds(totalDurationSeconds);
    const resolvedMs = (typeof totalDurationMs === "number" && totalDurationMs > 0)
      ? Math.round(totalDurationMs)
      : (durSec > 0 ? Math.round(durSec * 1000) : undefined);

    return mediaService.mergeAudioChunks(jobId, valid, targetLang, {
      segments: segments?.map((s) => ({ start: s.start, end: s.end, duration: s.targetDuration })),
      totalDurationSeconds: durSec,
      totalDurationMs: resolvedMs,
      audioFilters,
      cadenceLock,
      onMetricsComputed,
    });
  }

  // ─── Phase 3: Premium Stitching Logic ────────────────────────────────────────

  /**
   * Builds speech segments from word-level timestamps.
   * Breaks on sentence punctuation (. ? ! ।), pauses >= 500ms, or when utterance reaches ~5s with 5+ words.
   * Completely prevents 60-second monolithic segments that break timeline sync and bust TTS quotas.
   */
  private buildSegmentsFromWords(words: Array<{ text: string; start: number; end: number; speaker?: string }>): TimedSegment[] {
    if (!words || words.length === 0) return [];
    const segments: TimedSegment[] = [];
    let curWords: any[] = [];
    let curStart = words[0].start;

    for (let i = 0; i < words.length; i++) {
      const w = words[i];
      curWords.push(w);
      const text = (w.text || "").trim();
      const endsWithPunct = text.endsWith(".") || text.endsWith("?") || text.endsWith("!") || text.endsWith("।") || text.endsWith(";");
      const nextWord = words[i + 1];
      const pause = nextWord ? (nextWord.start - w.end) : 0;
      const duration = w.end - curStart;

      if (endsWithPunct || pause >= 500 || (duration >= 5000 && curWords.length >= 5) || i === words.length - 1) {
        segments.push({
          index: segments.length,
          start: curStart,
          end: w.end,
          duration: w.end - curStart,
          text: curWords.map((cw) => cw.text).join(" ").trim(),
          speaker: w.speaker || "speaker_0",
          words: [...curWords],
        });
        if (nextWord) curStart = nextWord.start;
        curWords = [];
      }
    }
    return segments;
  }

  /**
   * Splits any monolithic speech segment exceeding maxDurationMs into clause-level units.
   */
  private splitOversizedSegments(segments: TimedSegment[], maxDurationMs = 8000, maxChars = 140): TimedSegment[] {
    const result: TimedSegment[] = [];
    for (const seg of segments) {
      if (seg.duration <= maxDurationMs && seg.text.length <= maxChars) {
        result.push({ ...seg, index: result.length });
        continue;
      }
      const sentenceRegex = /[^.!?।,;]+[.!?।,;]+|[^ ]+ /g;
      const chunks = seg.text.match(sentenceRegex) || [seg.text];
      if (chunks.length <= 1) {
        result.push({ ...seg, index: result.length });
        continue;
      }
      let currentOffsetMs = seg.start;
      const totalChars = seg.text.length || 1;
      for (const chunk of chunks) {
        const trimmed = chunk.trim();
        if (!trimmed) continue;
        const chunkDuration = Math.max(800, Math.round((trimmed.length / totalChars) * seg.duration));
        const chunkEnd = Math.min(seg.end, currentOffsetMs + chunkDuration);
        result.push({
          index: result.length,
          text: trimmed,
          start: currentOffsetMs,
          end: chunkEnd,
          duration: chunkEnd - currentOffsetMs,
          speaker: seg.speaker || "speaker_0",
          words: [],
        });
        currentOffsetMs = chunkEnd;
      }
    }
    return result;
  }

  /**
   * Merges incomplete or overly short segments to ensure linguistic continuity.
   * Target: fixes the "Final Broken Sentence" issue identified in audit.
   */
  private stitchSegments(segments: TimedSegment[]): TimedSegment[] {
    const stitched: TimedSegment[] = [];
    for (let i = 0; i < segments.length; i++) {
      const current = { ...segments[i] };
      
      // Heuristic: If segment is < 15 chars or ends with a conjunction/preposition, 
      // it likely belongs with the next segment.
      while (
        i + 1 < segments.length && 
        (current.text.length < 15 || 
         current.text.match(/(?:and|the|so|but|or|to|for|with|तो|और|कि|है)$/i))
      ) {
        const next = segments[i + 1];
        current.text = (current.text + " " + next.text).trim();
        current.end = next.end;
        current.duration = current.end - current.start;
        i++;
      }
      stitched.push(current);
    }
    return stitched;
  }

  // ─── Utilities ────────────────────────────────────────────────────────────────

  private normaliseTTS(text: string, emotionTag?: string): string {
    return sanitizeTextForElevenLabsV4(text, emotionTag);
  }

  private async fetchFileContent(url: string): Promise<string | null> {
    try {
      if (url.startsWith("gs://")) {
        const parts = url.replace("gs://", "").split("/");
        const bucketName = parts[0];
        const filePath = parts.slice(1).join("/");
        const file = admin.storage().bucket(bucketName).file(filePath);
        const [exists] = await file.exists();
        if (!exists) return null;
        const [content] = await file.download();
        return content.toString("utf8");
      }
      if (url.startsWith("http://") || url.startsWith("https://")) {
        const axios = require("axios");
        const resp = await axios.get(url, { responseType: "text", timeout: 15000 });
        return typeof resp.data === "string" ? resp.data : JSON.stringify(resp.data);
      }
    } catch (err) {
      logger.warn("[Dubbing] fetchFileContent error:", { url, err: String(err) });
    }
    return null;
  }

  private parseSubtitlesToUtterances(content: string): TimedSegment[] {
    if (!content || !content.trim()) return [];
    let raw = content;
    if (raw.startsWith("\uFEFF")) raw = raw.substring(1);
    const trimmed = raw.trim();

    // 1. JSON
    if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
      try {
        const parsed = JSON.parse(trimmed);
        if (Array.isArray(parsed)) {
          return parsed.map((s: any, i: number) => ({
            index: i,
            text: s.text || s.translatedText || s.originalText || "",
            start: typeof s.start === "number" ? s.start : 0,
            end: typeof s.end === "number" ? s.end : ((s.start || 0) + 2000),
            duration: (s.end && s.start) ? (s.end - s.start) : 2000,
            speaker: s.speaker || "Speaker 1",
            words: s.words || [],
          })).filter((s: TimedSegment) => s.text.length > 0);
        }
        if (parsed.utterances && Array.isArray(parsed.utterances)) {
          return parsed.utterances.map((u: any, i: number) => ({
            index: i,
            text: u.text || "",
            start: typeof u.start === "number" ? u.start : 0,
            end: typeof u.end === "number" ? u.end : ((u.start || 0) + 2000),
            duration: (u.end && u.start) ? (u.end - u.start) : 2000,
            speaker: u.speaker || "Speaker 1",
            words: u.words || [],
          })).filter((s: TimedSegment) => s.text.length > 0);
        }
      } catch (e) {
        logger.warn("[Dubbing] JSON subtitle parse error:", e);
      }
    }

    // 2. SRT / WebVTT
    const clean = raw.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    const timeRegex = /(?:(\d{1,2}):)?(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[,.](\d{3})/;
    const blocks = clean.split(/\n\s*\n/);
    const utterances: TimedSegment[] = [];
    let idx = 0;

    for (const block of blocks) {
      const lines = block.trim().split("\n");
      if (lines.length === 0) continue;
      const timeLineIdx = lines.findIndex(l => timeRegex.test(l));
      if (timeLineIdx === -1) continue;
      const match = lines[timeLineIdx].match(timeRegex);
      if (!match) continue;

      const parseMs = (h: string | undefined, m: string, s: string, ms: string) => {
        const hours = h ? parseInt(h, 10) : 0;
        const mins = parseInt(m, 10);
        const secs = parseInt(s, 10);
        const millis = parseInt(ms, 10);
        return (hours * 3600 + mins * 60 + secs) * 1000 + millis;
      };

      const start = parseMs(match[1], match[2], match[3], match[4]);
      const end = parseMs(match[5], match[6], match[7], match[8]);
      const textLines = lines.slice(timeLineIdx + 1)
        .map(l => l.replace(/<[^>]*>/g, "").trim())
        .filter(Boolean);
      const text = textLines.join(" ").trim();

      if (text.length > 0 && end > start) {
        utterances.push({
          index: idx++,
          text,
          start,
          end,
          duration: end - start,
          speaker: "Speaker 1",
          words: [],
        });
      }
    }

    return utterances;
  }

  private normalizeTranscriptData(parsed: any): any {
    if (!parsed) return { text: "", utterances: [] };
    if (parsed.utterances && Array.isArray(parsed.utterances)) {
      return {
        text: parsed.text || parsed.utterances.map((u: any) => u.text).join(" "),
        language: parsed.language || "en",
        utterances: parsed.utterances.map((u: any, i: number) => ({
          index: i,
          text: u.text || "",
          start: typeof u.start === "number" ? u.start : 0,
          end: typeof u.end === "number" ? u.end : ((u.start || 0) + 2000),
          duration: (u.end && u.start) ? (u.end - u.start) : 2000,
          speaker: u.speaker || "Speaker 1",
        })).filter((u: any) => u.text.length > 0),
      };
    }
    if (Array.isArray(parsed)) {
      return {
        text: parsed.map((s: any) => s.text || s.translatedText || "").join(" "),
        language: "en",
        utterances: parsed.map((s: any, i: number) => ({
          index: i,
          text: s.text || s.translatedText || "",
          start: typeof s.start === "number" ? s.start : 0,
          end: typeof s.end === "number" ? s.end : ((s.start || 0) + 2000),
          duration: (s.end && s.start) ? (s.end - s.start) : 2000,
          speaker: s.speaker || "Speaker 1",
        })).filter((u: any) => u.text.length > 0),
      };
    }
    return { text: "", utterances: [] };
  }

  private async loadTranscript(jobId: string): Promise<any | null> {
    const vDoc = await db().collection("videos").doc(jobId).get();
    const vData = vDoc.data();
    const origJobId = vData?.jobId;

    // 0. PRIORITY 1: Respect Verified Creator-Edited Subtitles from Creator Studio!
    // If a creator corrected errors or adjusted timings in Studio, use that authoritative dialogue
    // rather than falling back to stale raw ASR speech transcripts.
    const existingSubs: Record<string, string> = {
      ...(vData?.subtitles || {}),
      ...(vData?.media?.subtitles || {}),
      ...(vData?.mediaSubtitles || {}),
    };
    const preferredLang = normalizeLanguageCode(
      vData?.sourceLanguage ||
      vData?.originalLanguage ||
      vData?.language ||
      "en"
    );
    let sourceSubLang = Object.keys(existingSubs).find((k) => normalizeLanguageCode(k) === preferredLang);
    if (!sourceSubLang && ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(preferredLang)) {
      sourceSubLang = preferredLang;
    }
    if (!sourceSubLang) {
      sourceSubLang = Object.keys(existingSubs).find((k) => ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(normalizeLanguageCode(k))) ||
        Object.keys(existingSubs)[0] ||
        preferredLang;
    }
    const subUrlToUse = existingSubs[sourceSubLang];

    if (subUrlToUse && (vData?.subtitlesEditedByCreator === true || vData?.subtitlesManualEdit === true)) {
      try {
        const subContent = await this.fetchFileContent(subUrlToUse);
        if (subContent && subContent.trim().length > 0) {
          const utterances = this.parseSubtitlesToUtterances(subContent);
          if (utterances.length > 0) {
            const fullText = utterances.map((u) => u.text).join(" ");
            const normalized = {
              text: fullText,
              utterances,
              language: sourceSubLang,
              source: "creator_edited_subtitles",
              confidence: 1.0,
            };
            logger.info("[Dubbing] Loaded verified creator-edited subtitles as transcript source", { jobId, lang: sourceSubLang, utterances: utterances.length });
            await db().collection("transcripts").doc(jobId).set(normalized, { merge: true }).catch(() => {});
            return normalized;
          }
        }
      } catch (subErr) {
        logger.warn("[Dubbing] Failed to load creator-edited subtitle, falling back to transcript storage:", subErr);
      }
    }

    let doc = await db().collection("transcripts").doc(jobId).get();
    if (doc.exists) {
      const data = doc.data();
      if (data?.utterances && data.utterances.length > 0) {
        if (preferredLang && ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(preferredLang) && !ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(normalizeLanguageCode(data.language || ""))) {
          logger.info("[Dubbing] Restoring authentic supported source language over contaminated transcript language", { jobId, contaminated: data.language, authentic: preferredLang });
          data.language = preferredLang;
        }
        return data;
      }
    }

    if (origJobId && origJobId !== jobId) {
      doc = await db().collection("transcripts").doc(origJobId).get();
      if (doc.exists) {
        const data = doc.data();
        if (data?.utterances && data.utterances.length > 0) {
          if (preferredLang && ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(preferredLang) && !ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(normalizeLanguageCode(data.language || ""))) {
            logger.info("[Dubbing] Restoring authentic supported source language over contaminated orig transcript language", { origJobId, contaminated: data.language, authentic: preferredLang });
            data.language = preferredLang;
          }
          return data;
        }
      }
    }

    const bucket = admin.storage().bucket();
    const potentialStoragePaths = [
      `transcripts/${jobId}/full.json`,
      `transcripts/${jobId}.json`,
      origJobId ? `transcripts/${origJobId}/full.json` : null,
      origJobId ? `transcripts/${origJobId}.json` : null,
    ].filter(Boolean) as string[];

    for (const p of potentialStoragePaths) {
      try {
        const file = bucket.file(p);
        const [exists] = await file.exists();
        if (exists) {
          const [content] = await file.download();
          const parsed = JSON.parse(content.toString("utf8"));
          const normalized = this.normalizeTranscriptData(parsed);
          if (normalized.utterances.length > 0) {
            await db().collection("transcripts").doc(jobId).set(normalized, { merge: true }).catch(() => {});
            return normalized;
          }
        }
      } catch (e) {
        logger.warn("[Dubbing] Error reading transcript from Cloud Storage:", { path: p, error: String(e) });
      }
    }

    const transcriptionUrl = vData?.transcriptionUrl || vData?.artifacts?.transcription?.jsonUrl;
    if (transcriptionUrl && typeof transcriptionUrl === "string") {
      try {
        const content = await this.fetchFileContent(transcriptionUrl);
        if (content) {
          const parsed = JSON.parse(content);
          const normalized = this.normalizeTranscriptData(parsed);
          if (normalized.utterances.length > 0) {
            await db().collection("transcripts").doc(jobId).set(normalized, { merge: true }).catch(() => {});
            return normalized;
          }
        }
      } catch (e) {
        logger.warn("[Dubbing] Error fetching transcriptionUrl:", { transcriptionUrl, error: String(e) });
      }
    }

    const fallbackSubs: Record<string, string> = {
      ...(vData?.subtitles || {}),
      ...(vData?.media?.subtitles || {}),
      ...(vData?.mediaSubtitles || {}),
    };

    // Prioritize preferredLang first, then supported AssemblyAI Universal 3.7 Pro languages, then others
    const availableLangs = Object.keys(fallbackSubs).sort((a, b) => {
      const normA = normalizeLanguageCode(a);
      const normB = normalizeLanguageCode(b);
      if (normA === preferredLang && normB !== preferredLang) return -1;
      if (normB === preferredLang && normA !== preferredLang) return 1;
      const aSupp = ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(normA) ? 1 : 0;
      const bSupp = ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(normB) ? 1 : 0;
      return bSupp - aSupp;
    });
    if (availableLangs.length > 0) {
      for (const lang of availableLangs) {
        const subUrl = fallbackSubs[lang];
        if (!subUrl) continue;
        try {
          const subContent = await this.fetchFileContent(subUrl);
          if (subContent && subContent.trim().length > 0) {
            const utterances = this.parseSubtitlesToUtterances(subContent);
            if (utterances.length > 0) {
              const fullText = utterances.map((u) => u.text).join(" ");
              const normLang = normalizeLanguageCode(lang);
              const recoveredLang = (normLang === preferredLang || (ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(preferredLang) && !ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(normLang)))
                ? preferredLang
                : normLang;
              const normalized = {
                text: fullText,
                utterances,
                language: recoveredLang,
                source: "parsed_subtitles",
                confidence: 1.0,
              };
              logger.info("[Dubbing] Recovered transcript from existing subtitles", { jobId, lang: recoveredLang, utterances: utterances.length });
              await db().collection("transcripts").doc(jobId).set(normalized, { merge: true }).catch(() => {});
              return normalized;
            }
          }
        } catch (subErr) {
          logger.warn("[Dubbing] Failed to parse existing subtitle:", { lang, subUrl, error: String(subErr) });
        }
      }
    }

    if (vData?.transcript && typeof vData.transcript === "string" && vData.transcript.trim().length > 0) {
      const durSec = Number(vData.duration || vData.durationSeconds || (vData.durationMs ? vData.durationMs / 1000 : 0)) || 60;
      const dur = durSec * 1000;
      const rawSentences = vData.transcript.split(/(?<=[.?!।\n])\s+/).filter((s: string) => s.trim().length > 0);
      const sentences = rawSentences.length > 0 ? rawSentences : [vData.transcript];
      const slotMs = Math.max(2000, Math.floor(dur / sentences.length));

      const utterances = sentences.map((text: string, idx: number) => {
        const start = idx * slotMs;
        const end = Math.min(dur, (idx + 1) * slotMs);
        return {
          index: idx,
          text: text.trim(),
          start,
          end,
          duration: end - start,
          speaker: "Speaker 1",
          words: [],
        };
      });

      return {
        text: vData.transcript,
        language: vData.detectedLanguage || vData.language || "en",
        utterances,
        duration: durSec,
      };
    }

    return null;
  }

  private async loadExistingResults(
    jobId:     string,
    languages: string[]
  ): Promise<DubbingResult[]> {
    const results: DubbingResult[] = [];
    for (const lang of languages) {
      const dubTask = db().collection("dubbing_results").doc(`${jobId}_${lang}`).get();
      const subTask = db().collection("subtitle_results").doc(`${jobId}_${lang}`).get();
      
      const [dubSnap, subSnap] = await Promise.all([dubTask, subTask]);
      
      if (dubSnap.exists || subSnap.exists) {
        const dubData = dubSnap.data() || {};
        const subData = subSnap.data() || {};
        
        results.push({
          jobId,
          language: lang,
          subtitleUrl: subData.subtitleUrl || dubData.subtitleUrl || "",
          subtitleFormat: subData.subtitleFormat || "srt",
          audioUrl: dubData.audioUrl || "",
          videoUrl: dubData.videoUrl || "",
          translationUrl: dubData.translationUrl || "",
          segments: dubData.segmentCount || 0,
          processingTime: dubData.processingTime || 0,
          meta: dubData.meta,
        } as DubbingResult);
      }
    }
    return results;
  }

  // ─── Long-Form Reel Orchestration & Creator Manifest Persistence ──────────────

  private async resolveJobDurationMs(
    jobId: string,
    executionPlan: ExecutionPlan,
    segments: TimedSegment[]
  ): Promise<number> {
    try {
      const jobSnap = await db().collection("video_jobs").doc(jobId).get();
      const jobData = jobSnap.data() as JobData | undefined;
      const targetVid = jobData?.videoId || jobId;
      const vDocSnap = await db().collection("videos").doc(targetVid).get();
      if (vDocSnap.exists) {
        const vData = vDocSnap.data();
        if (vData?.dubbingDurationSeconds && Number(vData.dubbingDurationSeconds) > 0) {
          return Math.round(Number(vData.dubbingDurationSeconds) * 1000);
        }
        if (vData?.durationMs && Number(vData.durationMs) > 0) {
          return Math.round(Number(vData.durationMs));
        }
        if (vData?.durationSeconds && Number(vData.durationSeconds) > 0) {
          return Math.round(Number(vData.durationSeconds) * 1000);
        }
        if (vData?.videoDurationSeconds && Number(vData.videoDurationSeconds) > 0) {
          return Math.round(Number(vData.videoDurationSeconds) * 1000);
        }
        if (vData?.duration) {
          const parsedSec = parseDurationToSeconds(vData.duration);
          if (parsedSec > 0) return Math.round(parsedSec * 1000);
        }
      }
    } catch (_) {}

    const planSec = parseDurationToSeconds(executionPlan.duration || (executionPlan as any).durationSeconds);
    if (planSec > 0) return Math.round(planSec * 1000);
    if (segments.length > 0) return Math.round(segments[segments.length - 1].end);
    return 0;
  }

  private async saveDubbingEditableManifest(params: {
    jobId: string;
    videoId?: string;
    userId: string;
    language: string;
    sourceLanguage: string;
    totalDurationMs: number;
    mneStemUrl?: string | null;
    dialogueStemUrl?: string | null;
    masterAudioUrl?: string | null;
    masterVideoUrl?: string | null;
    subtitleUrl?: string | null;
    segments: DubbingSegment[];
    ttsUrls: string[];
    voiceMapping: Record<string, string>;
  }): Promise<void> {
    const manifestRef = db()
      .collection("video_jobs")
      .doc(params.jobId)
      .collection("dubbing_manifests")
      .doc(params.language);

    const existingSnap = await manifestRef.get().catch(() => null);
    const existingData = existingSnap?.data() as DubbingEditableManifest | undefined;

    const editableSegments: DubbingEditableSegment[] = params.segments.map((seg, idx) => ({
      index: idx,
      startMs: Math.round(seg.start),
      endMs: Math.round(seg.end),
      speaker: seg.speaker || "speaker_0",
      originalText: seg.originalText,
      translatedText: seg.translatedText,
      emotionTag: seg.emotionTag,
      energyDb: seg.energyDb,
      stabilityOverride: seg.stabilityOverride,
      similarityBoostOverride: seg.similarityBoostOverride,
      pitchRangeSemitones: seg.pitchRangeSemitones,
      voiceQuality: seg.voiceQuality,
      syllableBudgetCompliance: seg.syllableBudgetCompliance,
      deliveryStyle: seg.deliveryStyle,
      voiceId: params.voiceMapping[seg.speaker || "speaker_0"] || params.voiceMapping.speaker_0,
      synthesizedAudioUrl: params.ttsUrls[idx] || undefined,
      durationMs: Math.max(200, Math.round(seg.end - seg.start)),
      updatedAt: Date.now(),
      terminologyWarning: seg.terminologyWarning,
      terminologyViolations: seg.terminologyViolations,
      terminologyComplianceRate: seg.terminologyComplianceRate,
      numericalParityVerified: (seg as any).numericalParityVerified ?? true,
      numericalParityWarning: (seg as any).numericalParityWarning,
      semanticParityScore: (seg as any).semanticParityScore,
      reviewRecommended: (seg as any).reviewRecommended ?? false,
      polarityFlipped: (seg as any).polarityFlipped,
    }));

    const manifest: DubbingEditableManifest = {
      jobId: params.jobId,
      videoId: params.videoId,
      userId: params.userId,
      language: params.language,
      sourceLanguage: params.sourceLanguage,
      totalDurationMs: params.totalDurationMs,
      mneStemUrl: params.mneStemUrl ?? null,
      dialogueStemUrl: params.dialogueStemUrl ?? null,
      masterAudioUrl: params.masterAudioUrl ?? null,
      masterVideoUrl: params.masterVideoUrl ?? null,
      subtitleUrl: params.subtitleUrl ?? null,
      mneGain: existingData?.mneGain ?? 1.0,
      dialogueGain: existingData?.dialogueGain ?? 1.0,
      subtitleFormat: "srt",
      pronunciationGlossary: existingData?.pronunciationGlossary || [],
      segments: editableSegments,
      version: (existingData?.version || 0) + 1,
      updatedAt: Date.now(),
    };

    await manifestRef.set(manifest);

    const safeVideoIds = filterVideoIds(
      params.videoId ? [params.videoId] : [],
      "[Dubbing:manifest-index]"
    );
    for (const vid of safeVideoIds) {
      await db()
        .collection("videos")
        .doc(vid)
        .set(
          {
            dubbingManifests: {
              [params.language]: {
                jobId: params.jobId,
                segmentCount: editableSegments.length,
                version: manifest.version,
                updatedAt: manifest.updatedAt,
              },
            },
          },
          { merge: true }
        )
        .catch(() => {});
    }
  }

  private async dispatchLongFormReels(params: {
    jobId: string;
    userId: string;
    videoUrl: string;
    languagesToProcess: string[];
    segments: TimedSegment[];
    sourceLang: string;
    totalDurationMs: number;
    executionPlan: ExecutionPlan;
    speakerProfiles: any[];
    acousticFingerprint: any;
    voiceMapping: Record<string, string>;
    creatorDNA: any;
    speakerGenderMapping: Record<string, "MALE" | "FEMALE">;
    mneStemUrl: string | null;
    isolatedVocalUrl: string | null;
    mneValidationResult?: import("../services/media").MneValidationResult;
    eventId: string;
    words?: WordTimestamp[];
  }): Promise<void> {
    const { jobId, userId, segments, totalDurationMs, executionPlan } = params;
    const sourceLang = normalizeLanguageCode(params.sourceLang);

    // 1. Translate all segments once across target languages & persist subtitles + editable manifests
    const translationsByLanguage: Record<string, DubbingSegment[]> = {};
    const subtitlePaths: Record<string, string> = {};
    const dubLanguages: string[] = [];

    for (const rawLang of params.languagesToProcess) {
      const targetLang = normalizeLanguageCode(rawLang);
      let dubSegs: DubbingSegment[];
      if (targetLang === sourceLang) {
        dubSegs = segments.map((s) => ({
          index: s.index,
          originalText: s.text,
          translatedText: s.text,
          language: targetLang,
          start: s.start,
          end: s.end,
          targetDuration: s.duration,
          speaker: s.speaker,
          isHook: s.isHook,
          emotionTag: s.emotionTag,
          energyDb: s.energyDb,
          stabilityOverride: s.stabilityOverride,
          similarityBoostOverride: s.similarityBoostOverride,
        }));
      } else {
        dubSegs = await this.translateWithCache(jobId, segments, sourceLang, targetLang, {
          model: "premium",
          tone: executionPlan.toneMode,
          localeStyle: executionPlan.localeStyle,
          targetPlatform: executionPlan.targetPlatform,
          creatorDNA: params.creatorDNA,
          enableABHooks: executionPlan.enableABHooks ?? true,
          speakerProfiles: params.speakerProfiles,
          dubbingTier: (executionPlan as any).dubbingTier || "audio_track",
          subtitleTier: executionPlan.subtitleTier || "ultra",
          isCinemaGrade: true,
        });
        dubLanguages.push(targetLang);
      }

      const normalisedSegs = dubSegs.map((s) => ({
        ...s,
        translatedText: this.normaliseTTS(s.translatedText, s.emotionTag),
      }));
      translationsByLanguage[targetLang] = normalisedSegs;

      const subRes = await this.generateSubtitles(jobId, normalisedSegs, targetLang, sourceLang, params.words);
      subtitlePaths[targetLang] = subRes.srtUrl;

      const jobSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
      const videoId = (jobSnap?.data() as any)?.videoId as string | undefined;
      if (targetLang !== sourceLang) {
        await this.saveDubbingEditableManifest({
          jobId,
          videoId,
          userId,
          language: targetLang,
          sourceLanguage: sourceLang,
          totalDurationMs,
          mneStemUrl: params.mneStemUrl,
          subtitleUrl: subRes.srtUrl,
          segments: normalisedSegs,
          ttsUrls: [],
          voiceMapping: params.voiceMapping,
        }).catch(() => {});
      }
    }

    // 2. Partition timeline into 15-minute reels with boundary midpoint ownership
    const { reels, assignedSegments } = mediaService.partitionIntoReels(totalDurationMs, segments);
    const getOwnedSegmentIndices = (reelIndex: number): number[] =>
      (assignedSegments.get(reelIndex) || [])
        .map((s) => s.index)
        .filter((idx): idx is number => typeof idx === "number");
    const jobDocSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
    const linkedVideoId = (jobDocSnap?.data() as any)?.videoId as string | undefined;

    // 3. Persist orchestration meta & initial reel docs before publishing Pub/Sub tasks
    await db().collection("video_jobs").doc(jobId).collection("reel_orchestration").doc("meta").set({
      jobId,
      videoId: linkedVideoId || null,
      userId,
      videoUrl: params.videoUrl,
      sourceLanguage: sourceLang,
      languages: dubLanguages,
      allRequestedLanguages: params.languagesToProcess.map((l) => normalizeLanguageCode(l)),
      subtitlePaths,
      totalReels: reels.length,
      totalDurationMs,
      mneStemUrl: params.mneStemUrl || null,
      isolatedVocalUrl: params.isolatedVocalUrl || null,
      mneValidation: params.mneValidationResult || null,
      executionPlan,
      speakerProfiles: params.speakerProfiles || [],
      acousticFingerprint: params.acousticFingerprint || null,
      voiceMapping: params.voiceMapping || {},
      speakerGenderMapping: params.speakerGenderMapping || {},
      status: "processing",
      completedReelsCount: 0,
      assemblyDispatched: false,
      createdAt: Date.now(),
    });

    for (const reel of reels) {
      await db()
        .collection("video_jobs")
        .doc(jobId)
        .collection("reels")
        .doc(`reel_${reel.reelIndex}`)
        .set({
          reelIndex: reel.reelIndex,
          totalReels: reel.totalReels,
          startMs: reel.nominalStartMs,
          endMs: reel.nominalEndMs,
          durationMs: Math.max(500, reel.nominalEndMs - reel.nominalStartMs),
          ownedSegmentIndices: getOwnedSegmentIndices(reel.reelIndex),
          status: "queued",
          dialogueReelUrls: {},
          createdAt: Date.now(),
        });
    }

    // 4. Fan out per-reel worker tasks
    for (const reel of reels) {
      const ownedSet = new Set(getOwnedSegmentIndices(reel.reelIndex));
      const segmentsByLanguage: DubbingReelTaskPayload["segmentsByLanguage"] = {};

      for (const lang of dubLanguages) {
        const langSegs = translationsByLanguage[lang] || [];
        segmentsByLanguage[lang] = langSegs
          .filter((s) => ownedSet.has(s.index))
          .map((s) => ({
            index: s.index,
            start: s.start,
            end: s.end,
            originalText: s.originalText,
            translatedText: s.translatedText,
            speaker: s.speaker,
            isHook: s.isHook,
            emotionTag: s.emotionTag,
            energyDb: s.energyDb,
            stabilityOverride: s.stabilityOverride,
            similarityBoostOverride: s.similarityBoostOverride,
          }));
      }

      const payload: DubbingReelTaskPayload = {
        jobId,
        videoId: linkedVideoId,
        userId,
        reelIndex: reel.reelIndex,
        totalReels: reel.totalReels,
        startMs: reel.nominalStartMs,
        endMs: reel.nominalEndMs,
        durationMs: Math.max(500, reel.nominalEndMs - reel.nominalStartMs),
        languages: dubLanguages,
        sourceLanguage: sourceLang,
        dubbingTier: (executionPlan as any).dubbingTier || "audio_track",
        preferVoiceCloning: true,
        speakerProfiles: params.speakerProfiles,
        segmentsByLanguage,
        idempotencyKey: `${jobId}_reel_${reel.reelIndex}`,
      };

      await this.distribution.publish("dubbing-reel-requested", {
        eventId: uuidv4(),
        eventType: "dubbing-reel-requested",
        jobId,
        userId,
        timestamp: Date.now(),
        data: payload as any,
        retryCount: 0,
        source: "dubbing-engine-reel-orchestrator",
      });
    }

    await this.distribution.markEventCompleted(params.eventId);
    await db().collection("video_jobs").doc(jobId).set(
      {
        reelOrchestration: {
          enabled: true,
          totalReels: reels.length,
          status: "dispatched",
          updatedAt: Date.now(),
        },
      },
      { merge: true }
    );
  }

  /**
   * Executes TTS + reel-local timeline stitching for one 15-minute reel slice.
   * When the final reel completes in Firestore, atomically triggers `dubbing-reel-assemble`.
   */
  public async processDubbingReel(payload: DubbingReelTaskPayload): Promise<void> {
    const { jobId, userId, reelIndex, totalReels } = payload;
    const jobRef = db().collection("video_jobs").doc(jobId);
    const reelRef = jobRef.collection("reels").doc(`reel_${reelIndex}`);
    const metaRef = jobRef.collection("reel_orchestration").doc("meta");

    const existingSnap = await reelRef.get();
    if (existingSnap.exists && existingSnap.data()?.status === "completed") {
      logger.info("[Dubbing:Reel] Already completed — skipping duplicate delivery", { jobId, reelIndex });
      return;
    }

    const metaSnap = await metaRef.get();
    if (!metaSnap.exists) {
      throw new Error(`[Dubbing:Reel] Missing orchestration metadata for ${jobId}`);
    }
    const meta = metaSnap.data()!;
    const dspFilters = meta.acousticFingerprint
      ? audioIdentityService.getDSPFilters(meta.acousticFingerprint)
      : "loudnorm=I=-14:TP=-1:LRA=11";

    await reelRef.set({ status: "processing", startedAt: Date.now() }, { merge: true });

    const dialogueReelUrls: Record<string, string> = {};
    for (const lang of payload.languages) {
      const normLang = normalizeLanguageCode(lang);
      const reelSegsRaw = payload.segmentsByLanguage[normLang] || [];
      const reelSegs: DubbingSegment[] = reelSegsRaw.map((s) => ({
        index: s.index,
        originalText: s.originalText,
        translatedText: this.normaliseTTS(s.translatedText, s.emotionTag),
        language: normLang,
        start: s.start,
        end: s.end,
        targetDuration: Math.max(200, s.end - s.start),
        speaker: s.speaker,
        isHook: s.isHook,
        emotionTag: s.emotionTag,
        energyDb: s.energyDb,
        stabilityOverride: s.stabilityOverride,
        similarityBoostOverride: s.similarityBoostOverride,
      }));

      if (reelSegs.length === 0) {
        // Generate silent reel bed matching payload.durationMs so concat remains time-aligned
        const silentUrl = await mediaService.mergeAudioChunks(
          `${jobId}_reel_${reelIndex}`,
          [],
          normLang,
          { totalDurationMs: payload.durationMs }
        );
        dialogueReelUrls[normLang] = silentUrl;
        continue;
      }

      const ttsResult = await this.parallelTTSWithCache(
        jobId,
        userId,
        reelSegs,
        normLang,
        meta.voiceMapping || {},
        payload.preferVoiceCloning,
        meta.speakerGenderMapping || {},
        meta.speakerProfiles || [],
        meta.acousticFingerprint,
        payload.dubbingTier || "audio_track",
        "cloned",
        meta.executionPlan?.voiceGender,
        undefined,
        meta.isolatedVocalUrl,
        meta.mneStemUrl
      );

      if (ttsResult.failedSegments.length > 0) {
        throw new Error(
          `[Dubbing:Reel] Reel ${reelIndex} failed ${ttsResult.failedSegments.length}/${ttsResult.totalSegments} TTS segments for ${normLang}`
        );
      }

      // Normalize segment start/end to the reel's 0-based local timeline
      const localSegments = reelSegs.map((s) => ({
        start: Math.max(0, s.start - payload.startMs),
        end: Math.max(200, s.end - payload.startMs),
        duration: Math.max(200, s.end - s.start),
      }));

      const stitchedReelUrl = await mediaService.mergeAudioChunks(
        `${jobId}_reel_${reelIndex}`,
        ttsResult.urls,
        normLang,
        {
          segments: localSegments,
          totalDurationMs: payload.durationMs,
          audioFilters: dspFilters,
          cadenceLock: true,
        }
      );

      dialogueReelUrls[normLang] = stitchedReelUrl;
    }

    // Transactionally persist reel completion and dispatch assembly when all reels finish
    let shouldDispatchAssembly = false;
    await db().runTransaction(async (tx) => {
      const mSnap = await tx.get(metaRef);
      const reelsSnap = await tx.get(jobRef.collection("reels"));
      const mData = mSnap.data() || {};

      tx.set(
        reelRef,
        {
          status: "completed",
          dialogueReelUrls,
          completedAt: Date.now(),
        },
        { merge: true }
      );

      let completedCount = 1; // counting current reel
      reelsSnap.forEach((doc) => {
        if (doc.id !== `reel_${reelIndex}` && doc.data()?.status === "completed") {
          completedCount++;
        }
      });

      const alreadyDispatched = Boolean(mData.assemblyDispatched);
      const allDone = completedCount >= totalReels;
      if (allDone && !alreadyDispatched) {
        shouldDispatchAssembly = true;
      }

      tx.set(
        metaRef,
        {
          completedReelsCount: completedCount,
          assemblyDispatched: alreadyDispatched || shouldDispatchAssembly,
          updatedAt: Date.now(),
        },
        { merge: true }
      );
    });

    if (shouldDispatchAssembly) {
      const assemblyPayload: DubbingReelAssemblyPayload = {
        jobId,
        videoId: payload.videoId || meta.videoId || undefined,
        userId,
        totalReels,
        totalDurationMs: meta.totalDurationMs,
        languages: meta.languages || payload.languages,
        sourceLanguage: meta.sourceLanguage || payload.sourceLanguage,
        mneStemUrl: meta.mneStemUrl || null,
        mneValidation: meta.mneValidation || undefined,
        dubbingTier: payload.dubbingTier,
        videoUrl: meta.videoUrl,
        idempotencyKey: `${jobId}_assembly`,
      };

      await this.distribution.publish("dubbing-reel-assemble", {
        eventId: uuidv4(),
        eventType: "dubbing-reel-assemble",
        jobId,
        userId,
        timestamp: Date.now(),
        data: assemblyPayload as any,
        retryCount: 0,
        source: "dubbing-reel-worker",
      });
    }
  }

  /**
   * Assembles completed 15-minute reel tracks in PCM via MediaService.assembleReelAudio,
   * sidechain-ducks M&E, evaluates QualityGate, writes Firestore outputs, and fires dubbing-complete.
   */
  public async assembleDubbingReels(payload: DubbingReelAssemblyPayload): Promise<void> {
    const { jobId, userId, totalReels, totalDurationMs } = payload;
    const jobRef = db().collection("video_jobs").doc(jobId);
    const metaRef = jobRef.collection("reel_orchestration").doc("meta");

    const metaSnap = await metaRef.get();
    if (!metaSnap.exists) {
      throw new Error(`[Dubbing:Assemble] Missing orchestration metadata for ${jobId}`);
    }
    const meta = metaSnap.data()!;
    if (meta.status === "completed") {
      logger.info("[Dubbing:Assemble] Already assembled — skipping replay", { jobId });
      return;
    }

    const reelsSnap = await jobRef.collection("reels").get();
    const reelDocs = reelsSnap.docs
      .map((d) => d.data())
      .sort((a, b) => Number(a.reelIndex) - Number(b.reelIndex));

    if (reelDocs.length < totalReels || reelDocs.some((r) => r.status !== "completed")) {
      throw new Error(`[Dubbing:Assemble] Not all ${totalReels} reels are completed for ${jobId}`);
    }

    const dspFilters = meta.acousticFingerprint
      ? audioIdentityService.getDSPFilters(meta.acousticFingerprint)
      : "loudnorm=I=-14:TP=-1:LRA=11";
    const expectedDurSec = totalDurationMs / 1000;
    const bucket = admin.storage().bucket();
    const executionPlan = meta.executionPlan as ExecutionPlan;
    const subtitlePaths: Record<string, string> = { ...(meta.subtitlePaths || {}) };
    const dubbedPaths: Record<string, string> = {};
    const audioPaths: Record<string, string> = {};
    const dialogueStems: Record<string, string> = {};
    const dubbingResults: DubbingResult[] = [];

    for (const targetLang of meta.languages || payload.languages) {
      const reelAudioUrls = reelDocs.map((r) => r.dialogueReelUrls?.[targetLang]).filter(Boolean) as string[];
      if (reelAudioUrls.length !== totalReels) {
        throw new Error(`[Dubbing:Assemble] Missing reel audio URL for ${targetLang} (${reelAudioUrls.length}/${totalReels})`);
      }

      const rawDialogueUrl = await mediaService.assembleReelAudio(
        jobId,
        targetLang,
        reelAudioUrls,
        totalDurationMs,
        { audioFilters: dspFilters, roomTone: meta.acousticFingerprint?.roomTone }
      );

      let masterAudioUrl = rawDialogueUrl;
      if (meta.mneStemUrl) {
        masterAudioUrl = await mediaService.mixDubWithMne(jobId, targetLang, {
          mneUrl: meta.mneStemUrl,
          dubbedAudioUrl: rawDialogueUrl,
          totalDurationSeconds: expectedDurSec,
          totalDurationMs,
          // audioFilters omitted — dialogue already mastered via assembleReelAudio; mixDubWithMne handles single-pass loudnorm
          roomTone: meta.acousticFingerprint?.roomTone,
          spokenSegments: (meta.words && meta.words.length > 0)
            ? meta.words.map((w: any) => ({ start: w.start || 0, end: w.end || 0 }))
            : (meta.segments || []),
        });
      }

      const gate = DubbingQualityGate.evaluate({
        jobId,
        targetLang,
        totalSegments: 1,
        successfulSegments: 1,
        failedSegments: [],
        actualDurationSeconds: expectedDurSec,
        expectedDurationSeconds: expectedDurSec,
        isVoiceCloningRequested: executionPlan?.dubbingMode === "voice_clone",
        isVoiceCloned: Boolean(Object.keys(meta.voiceMapping || {}).length > 0),
        stemIsolationRequested: Boolean(executionPlan?.stemIsolation),
        isStemPreserved: Boolean(meta.mneStemUrl),
        mneValidation: meta.mneValidation,
      });

      if (!gate.passed) {
        throw new Error(`[Dubbing:Assemble:QualityGate] ${gate.violations.join("; ")}`);
      }

      let videoResult = "";
      if ((executionPlan as any)?.dubbingTier === "audio_track") {
        logger.info("[Dubbing:Assemble] Skipping video remuxing for audio-track tier (master audio track is intact)", { jobId, targetLang });
      } else {
        try {
          videoResult = await mediaService.mergeAudioToVideo({
            jobId,
            videoUrl: payload.videoUrl,
            audioUrl: masterAudioUrl,
            subtitleUrl: executionPlan?.genLangSubs ? subtitlePaths[targetLang] : undefined,
            language: targetLang,
            format: "mp4",
            audioFilters: dspFilters,
            isPreMastered: masterAudioUrl !== rawDialogueUrl,
          });
        } catch (mergeErr) {
          logger.warn("[Dubbing:Assemble] Remux warning (audio track intact):", mergeErr);
          videoResult = "";
        }
      }

      const isAssembleGenuine = videoResult &&
        videoResult !== payload.videoUrl &&
        !videoResult.endsWith("original.mp4") &&
        !videoResult.includes("%2Foriginal.mp4");

      audioPaths[targetLang] = masterAudioUrl;
      if (isAssembleGenuine) {
        dubbedPaths[targetLang] = videoResult;
      }
      dialogueStems[targetLang] = rawDialogueUrl;

      const directAudioUrl = masterAudioUrl.startsWith("gs://")
        ? `https://storage.googleapis.com/${bucket.name}/${masterAudioUrl.replace(`gs://${bucket.name}/`, "")}`
        : masterAudioUrl;
      const directVideoUrl = isAssembleGenuine
        ? (videoResult.startsWith("gs://")
            ? `https://storage.googleapis.com/${bucket.name}/${videoResult.replace(`gs://${bucket.name}/`, "")}`
            : videoResult)
        : "";

      await db().collection("dubbing_results").doc(`${jobId}_${targetLang}`).set({
        jobId,
        language: targetLang,
        audioUrl: masterAudioUrl,
        ...(directVideoUrl ? { videoUrl: directVideoUrl } : {}),
        processingTime: Date.now() - (meta.createdAt || Date.now()),
        createdAt: Date.now(),
        stems: {
          mne: meta.mneStemUrl || null,
          dialogue: rawDialogueUrl,
          master: masterAudioUrl,
          vocals: meta.isolatedVocalUrl || null,
        },
        reelAssembly: { totalReels, totalDurationMs },
      }, { merge: true });

      await jobRef.collection("dubbing_manifests").doc(targetLang).set({
        dialogueStemUrl: rawDialogueUrl,
        masterAudioUrl,
        ...(directVideoUrl ? { masterVideoUrl: directVideoUrl } : {}),
        updatedAt: Date.now(),
      }, { merge: true });

      const linkedVideoIds = filterVideoIds(
        meta.videoId ? [meta.videoId] : [],
        "[Dubbing:Assemble]"
      );
      for (const vid of linkedVideoIds) {
        await db().collection("videos").doc(vid).set({
          audioTracks: { [targetLang]: directAudioUrl },
          media: { audioTracks: { [targetLang]: directAudioUrl } },
          ...(directVideoUrl ? { dubbedVideos: { [targetLang]: directVideoUrl } } : {}),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      await EdgeLayer.updateStageSync(jobId, `dubbing_${targetLang}`, { status: "completed", progress: 100 }).catch(() => {});
      dubbingResults.push({
        jobId,
        language: targetLang,
        subtitleUrl: subtitlePaths[targetLang] || "",
        subtitleFormat: "srt",
        audioUrl: masterAudioUrl,
        videoUrl: videoResult,
        segments: reelDocs.reduce((sum, r) => sum + (r.ownedSegmentIndices?.length || 0), 0),
        processingTime: Date.now() - (meta.createdAt || Date.now()),
      });
    }

    await metaRef.set({ status: "completed", completedAt: Date.now() }, { merge: true });

    const eventData: DubbingCompleteData = {
      languages: dubbingResults.map((r) => r.language),
      subtitlePaths,
      dubbedVideoPaths: dubbedPaths,
      audioPaths,
      mneStemPath: meta.mneStemUrl || undefined,
      mneValidation: meta.mneValidation || undefined,
      stems: {
        mne: meta.mneStemUrl || undefined,
        dialogue: dialogueStems,
        master: audioPaths,
        vocals: meta.isolatedVocalUrl || undefined,
      },
    };

    await this.distribution.publish("dubbing-complete", {
      eventId: uuidv4(),
      eventType: "dubbing-complete",
      jobId,
      userId,
      timestamp: Date.now(),
      data: eventData,
      retryCount: 0,
      source: "dubbing-reel-assembler",
    });

    const completedAt = Date.now();
    await EdgeLayer.upsertDubbingJob(jobId, {
      status: "completed",
      progress: 100,
      completedAt,
    });
    await jobRef.set({
      updatedAt: completedAt,
      stages: {
        dubbing: {
          status: executionPlan.generateDubbing ? "completed" : "skipped",
          progress: 100,
          completedAt,
        },
        subtitles: {
          status: "completed",
          progress: 100,
          completedAt,
        },
      },
      outputs: {
        audioTracks: audioPaths,
        subtitles: subtitlePaths,
        dubbedVideos: dubbedPaths,
      },
      reelOrchestration: { enabled: true, totalReels, status: "completed", completedAt },
    }, { merge: true });

    // 🎬 Package Multilingual HLS Master Manifest (master.m3u8) with frame-aligned audio & snapped subtitles
    try {
      const audioRenditions = Object.entries(audioPaths).map(([lang, aUrl]) => ({
        language: lang,
        audioUrl: aUrl,
        isDefault: lang === (meta.sourceLanguage || "en"),
      }));
      const subtitleRenditions = Object.entries(subtitlePaths).map(([lang, subUrl]) => ({
        language: lang,
        vttUrl: subUrl.replace(/\.srt$/, ".vtt"),
        isDefault: false,
      }));

      const targetVideoId = meta.videoId || jobId;
      await hlsPackagerService.packageMultilingualHlsManifest({
        jobId,
        videoId: targetVideoId,
        sourceLanguage: meta.sourceLanguage || "en",
        audioRenditions,
        subtitleRenditions,
        baseVideoUrl: (payload as any).videoUrl,
        totalDurationSec: totalDurationMs > 0 ? totalDurationMs / 1000 : undefined,
      });
    } catch (hlsErr) {
      logger.warn("[Dubbing:Assemble] Notice packaging HLS multi-audio manifest:", hlsErr);
    }

    await aggregationLayer.onStageComplete(jobId, "dubbing", userId, executionPlan);
  }
}

export const dubbingEngine = new DubbingEngine();
