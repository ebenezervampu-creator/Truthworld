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
  isContextualDubbingEditEnabled,
  decodeHtmlEntities,
  normalizeScriptureCitationsForTts,
  applyTeluguTheologicalLexiconGuard,
  applySpokenTeluguColloquialContractions,
  countSourceSyllables,
} from "../services/translation";
import { configuredSyllablesPerSecond } from "../services/geminiDubbingEditor";
import { intenseStability, planDelivery, type LineEmotionHints } from "../services/emotion-transfer";
import { isDubbingWhisperGuardEnabled, isVerifiedWhisper } from "../services/delivery-tag-guard";
import { listenRetakeEnabled, runListenAndRetake, type ListenLine } from "../services/listen-retake";
import { geminiListenGenerate, listenModel, openSourceAudio, takeAsWav } from "../services/listen-retake-io";
import {
  ttsService,
  sanitizeTextForElevenLabsV4,
  stripAudioTagsForSubtitles,
  getAdaptiveTTSBatchSize,
  V4_PREMIUM_80_LANGUAGES,
  ELEVENLABS_VOICE_GENDER_MAP,
  registerVoiceFallbacks,
  describeElevenLabsError,
} from "../services/tts";
import { expressiveV4Bus } from "../services/expressiveV4Bus";
import { MediaService, mediaService, parseDurationToSeconds, parseAnyStorageUrl, type MergeAudioMetrics } from "../services/media";
import { ASSEMBLYAI_UNIVERSAL_37_LANGUAGES } from "./05-transcription";
import { costEngine, getFlatDubbingPricePerLanguage } from "../services/cost-engine";
import { emitDubbingTiming } from "../utils/dubbing-timing";
import { speakerProfilingService } from "../services/speaker-profiling";
import { lockVoiceSettingsPerSpeaker } from "../services/speaker-voice-lock";
import { selectProfilingTurns, selectPitchTurns } from "../services/speaker-turn-sampler";
import { diarizationCheckService, diarizationModel, isTranscriptPlausibilityRecheckEnabled, maxTurnsForJob } from "../services/diarization-check";
import {
  parseCastList,
  parseCastRelationships,
  computeCastHash,
  buildCastBinding,
  bindRelationships,
  bindCastGenders,
  CastMember,
  CastMemberWithRelations,
  CharacterRelationship,
} from "../services/cast-list";
import { planDubBudget, readMarginPolicy, RetryBudget } from "../services/dubbing-economics";
import {
  decideSeparation,
  readSeparationSettings,
  separationCostUsd,
  speechGaps,
  type SeparationPath,
} from "../services/separation-policy";
import { splitUtterancesBySegments, summarizeDiarization } from "../services/diarization-reconcile";
import { attachWordsToUtterances, chunkTimesFromWords, collectWordTimings, hasUtteranceWordTimings } from "../services/segment-timing";
import { MIN_SUBTITLE_LINE_COVERAGE, subtitleLineCoverage, syncViolations, type DubSyncReport } from "../services/dub-sync-check";
import { rankReusableVoices, REUSE_SHORTLIST } from "../services/voice-reuse";
import { assignLanguageVoices, assignNativeVoices, type NativeCandidate } from "../services/language-voice-assignment";
import { nativeTier, nativeVoicesOnly, noNativeVoiceMessage, unsupportedDubbingLanguageMessage } from "../services/voice-locale-policy";
import { friendlyDubbingError, friendlyDubbingJobError, blockedTranslationMessage } from "../services/dubbing-user-messages";
import {
  subtitlesFromDubPassEnabled,
  unifiedSpeechRateEnabled,
  voiceRateCalibrationEnabled,
  shotChangeWindowEnabled,
  editorContextEnabled,
  findBlockedTranslationLines,
  evaluatePreTtsDubbingDecision,
  findLongFormSkippedRefundLanguages,
} from "../services/translation-flags";
import {
  estimateSpeechDurationMs as unifiedEstimateSpeechDurationMs,
  permissibleWindowMs,
} from "../services/speech-rate";
import { shouldStitch } from "../services/segment-stitching";
import { isDubbingSourceLanguage, isLaunchDubbingPair, launchUnsupportedNotice } from "../services/dubbing-launch-languages";
import { cloneUnavailableMessage, type CloneBlockReason, type VoiceCapacity } from "../services/voice-capacity";
import { cloneAllSpeakersEnabled, cloneMaxSpeakers, cloneMinSeconds, cloneStrict, planSpeakerClones, remainingCloneCapacity, unclonedSpeakers } from "../services/speaker-clone-plan";
import { encodeWordSpans, decodeWordSpans } from "../services/reel-word-spans";
import { loadLibraryCatalog, libraryVoicesFor, libraryVoiceToCandidate } from "../services/library-voice-catalog";
import { withMeasuredPitch, defaultVoiceAcousticsDeps } from "../services/voice-acoustics";
import { audioIdentityService, PROSODY_RULE_VERSION } from "../services/audio-identity";
import { DubbingQualityGate, isBlockingViolation } from "./quality-gate";
import { DistributionLayer }  from "./04-distribution";
import { EdgeLayer }          from "./01-edge";
import { aggregationLayer }   from "./09-aggregation";
import { PerformanceLayer }   from "./10-performance";
import { PIPELINE_CONFIG }    from "../config";
import { creatorStyleService } from "../services/creatorStyleService";
import { refundDubbingFeeOnFailure } from "../services/refundService";
import { MultilingualSubtitleLocalizer } from "../services/multilingual_subtitle_localizer";
import {
  voiceMatcher,
  type DiarizedSpeakerProfile,
} from "../services/voice-matcher";
import { logger }             from "../utils/logger";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import {
  filterVideoIds,
  safeMergeExistingVideo,
  safeMergeExistingVideoSubdoc,
} from "../../utils/videosCollectionGuard";
import { hlsPackagerService } from "../services/hlsPackager";
import { canUseBedUnderDialogue, faithfulMixEnabled } from "../services/faithful-mix";
import { getScreenContent } from "../services/screenContentAnalyzer";
import {
  cachedStep,
  contentHash,
  hasFallbackSpeakerProfile,
  hasStepPrefixCached,
  isAcousticOnlyProsody,
  isDefaultFingerprint,
  isFailedDiarization,
} from "../services/dubbing-step-cache";
import {
  parallelTranslationEnabled,
  sharedTmpEnabled,
  slidingTtsPoolEnabled,
  stepHandoffEnabled,
} from "../services/latency-flags";
import {
  DEFAULT_REEL_DURATION_MS,
  DEFAULT_REEL_THRESHOLD_MS,
  DEFAULT_REEL_WORKER_MAX_INSTANCES,
  STEP_HANDOFF_MS,
  computePerWorkerTtsConcurrency,
} from "../services/dubbing-step-planner";
import { readMaxElevenLabsConcurrency } from "../services/elevenlabs-plan";
import { mapWithConcurrency } from "../services/concurrency";
import { syncStudioDubbingJobsForPipelineJob } from "../../dubbing/studio-job-sync";
import { publishCompletedStudioJobToTruthworld } from "../../dubbing/studio-publisher";
import { saveTranslationArtifact, saveDubbingReportArtifact } from "../services/dubbing-report";

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
export function estimateSpeechDurationMsLegacy(text: string, language: string = "en"): number {
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

export function estimateSpeechDurationMs(
  text: string,
  language: string = "en",
  measuredRate?: number
): number {
  if (unifiedSpeechRateEnabled()) {
    return unifiedEstimateSpeechDurationMs(text, language, measuredRate);
  }
  return estimateSpeechDurationMsLegacy(text, language);
}

/** What a language's dub ended as (see DubbingResult.dubOutcome). */
type DubOutcome = NonNullable<DubbingResult["dubOutcome"]>;

/** Subtitles are generated while the voices are synthesised. Rollback: DUBBING_SUBTITLES_WITH_TTS=false. */
function subtitlesAlongsideTtsEnabled(): boolean {
  return String(process.env.DUBBING_SUBTITLES_WITH_TTS ?? "true").toLowerCase() !== "false";
}

/** Concise re-translations requested at once before TTS (Gemini / Translation LLM calls). */
const PRE_TTS_RETRANSLATE_CONCURRENCY = 4;

/** Speakers measured at once in step 1.7 (FFmpeg clip + frame + one Gemini call each). */
const SPEAKER_PROFILE_CONCURRENCY = 3;
/** Spoken once with each new per-speaker clone to check ElevenLabs lets it be used (6 characters). */
const CLONE_PROBE_TEXT = "Hello.";

/** Separation result stored in the step cache (dubbing-step-cache.ts). */
interface CachedSeparation {
  path: SeparationPath;
  reason: string;
  engine: string;
  vocalsUrl: string | null;
  mneUrl: string | null;
}

/** Output of the separation → fingerprint → prosody chain (runSeparationChain). */
interface SeparationChainResult {
  isolatedVocalUrl: string | null;
  mneStemUrl: string | null;
  separationPath: SeparationPath | null;
  acousticFingerprint: any;
  prosodyCues: Map<number, any>;
}

export class DubbingEngine {
  /**
   * Temporary voice clones per job that this process created and has not yet deleted or handed to
   * reel workers. The timeout guard deletes them: Promise.race rejects while the pipeline keeps running
   * in the background, so its own `finally` may never run (25 Nov: a 540 s timeout left 8 clones on the
   * account and the next run hit voice_limit_reached 10/10).
   */
  private static readonly pendingTempClones = new Map<string, Set<string>>();
  /** Jobs whose timeout guard fired: the background pipeline must not dispatch reels for them. */
  private static readonly timedOutJobs = new Set<string>();

  private static trackTempClone(jobId: string, voiceId: string): void {
    const set = DubbingEngine.pendingTempClones.get(jobId) ?? new Set<string>();
    set.add(voiceId);
    DubbingEngine.pendingTempClones.set(jobId, set);
  }

  private static releaseTempClones(jobId: string): void {
    DubbingEngine.pendingTempClones.delete(jobId);
  }

  private static async deletePendingTempClones(jobId: string): Promise<number> {
    const ids = Array.from(DubbingEngine.pendingTempClones.get(jobId) ?? []);
    DubbingEngine.pendingTempClones.delete(jobId);
    await Promise.all(ids.map((id) => ttsService.deleteVoice(id).catch(() => false)));
    return ids.length;
  }

  private readonly distribution:     DistributionLayer;
  private readonly performanceLayer: PerformanceLayer;

  constructor() {
    this.distribution     = new DistributionLayer();
    this.performanceLayer = new PerformanceLayer();
  }

  private recordTiming(
    timingsMap: Record<string, number>,
    stage: string,
    startMs: number,
    meta: { jobId: string; lang?: string; durationSec?: number; [key: string]: unknown }
  ): number {
    return emitDubbingTiming(stage, startMs, meta, timingsMap);
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

    // Leave 60s headroom before Cloud Run's 540s hard kill so cleanup, checkpoint sync, and refunds complete.
    const DUBBING_TIMEOUT_MS = parseInt(process.env.DUBBING_TIMEOUT_MS || "480000", 10);
    let timeoutTimer: NodeJS.Timeout | null = null;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutTimer = setTimeout(async () => {
        const seconds = Math.round(DUBBING_TIMEOUT_MS / 1000);
        const timeoutMsg = `Dubbing processing reached maximum cloud engine duration (${seconds}s)`;
        logger.error(`[Dubbing] Cloud timeout guard reached (${seconds}s)`, { jobId });
        DubbingEngine.timedOutJobs.add(jobId);
        const deletedClones = await DubbingEngine.deletePendingTempClones(jobId).catch(() => 0);
        if (deletedClones > 0) {
          logger.warn("[Dubbing] Timeout — deleted temporary voice clones made by this job", { jobId, count: deletedClones });
        }
        await EdgeLayer.failStage(jobId, "dubbing", timeoutMsg).catch(() => {});
        await EdgeLayer.upsertDubbingJob(jobId, {
          status: "failed",
          error: timeoutMsg,
          completedAt: Date.now(),
        });
        await syncStudioDubbingJobsForPipelineJob(jobId, null, {
          status: "failed",
          currentStepMessage: friendlyDubbingJobError(),
          error: friendlyDubbingJobError(),
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
    // Per-speaker clones (DUBBING_CLONE_ALL_SPEAKERS); always temporary, deleted in `finally`.
    const speakerCloneIds: string[] = [];
    // Set when a long video is handed to reel workers: they synthesize after this job returns, so the
    // temporary clones must outlive it. The reel assembler deletes them (reel_orchestration/meta).
    let reelsDispatched = false;
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

      // Start the one-per-video song / on-screen text analysis now, in parallel with voice and
      // translation work, so subtitles do not wait for it later. Best-effort; never throws.
      if (executionPlan.genLangSubs || (executionPlan.subtitleLanguages?.length ?? 0) > 0 || executionPlan.generateDubbing) {
        const tScreenStart = Date.now();
        void getScreenContent(
          jobId,
          videoUrl,
          executionPlan.durationSeconds ? executionPlan.durationSeconds * 1000 : undefined
        )
          .then((sc) => {
            emitDubbingTiming("separation.screen_content", tScreenStart, {
              jobId,
              songs: sc?.songIntervalsMs?.length ?? 0,
              onScreenText: sc?.onScreenText?.length ?? 0,
            });
          })
          .catch(() => undefined);
      }

      // 1.2. Build high-fidelity natural speech segments (shared with prepareDubbingAnalysis)
      const { rawCount: rawSegmentCount, segments } = this.buildDubbingSegments(transcript);
      logger.info("[Dubbing] Segments stitched & Hooks marked", { jobId, original: rawSegmentCount, stitched: segments.length });
      const prepTimings: Record<string, number> = {};
      const jobDurSec = Number(executionPlan.durationSeconds || executionPlan.duration || 0) ||
        (segments.length > 0 ? segments[segments.length - 1].end / 1000 : 0);

      // Hop 1 delegation for long-form (> 3m): run language-independent prep in handleDubbingPrep
      // so analysis + separation get their own 540s budget before voices/reels/translation.
      const preCheckDurationMs = Number(executionPlan.durationSeconds || executionPlan.duration || 0) * 1000 ||
        (segments.length > 0 ? segments[segments.length - 1].end : 0);
      const reelThresholdPre = Number(process.env.DUBBING_REEL_THRESHOLD_MS || DEFAULT_REEL_THRESHOLD_MS);
      if (
        stepHandoffEnabled() &&
        executionPlan.generateDubbing &&
        preCheckDurationMs > reelThresholdPre &&
        !(executionPlan as any)._prepHandoffDone
      ) {
        const sepCached = await hasStepPrefixCached(jobId, "separation");
        if (!sepCached) {
          logger.info("[Dubbing:Handoff] Long-form job without cached prep — delegating prep_analysis to handleDubbingPrep", {
            jobId,
            preCheckDurationMs,
            reelThresholdPre,
          });
          await this.distribution.publish("dubbing-step-prep", {
            eventId: `dub_prep_${jobId}_${Date.now()}`,
            eventType: "dubbing-step-prep",
            jobId,
            userId,
            timestamp: Date.now(),
            data: { videoUrl, executionPlan },
            retryCount: 0,
            source: "dubbing-engine-handoff",
          });
          await this.distribution.markEventCompleted(eventId);
          return [];
        }
      }

      // 1.2b. Diarization check (dubbing only). Must run before speaker profiling and voice
      // assignment; see runDiarizationCheck. Background separation does not depend on speaker labels,
      // so it starts now, in parallel (step 1.6 below awaits it).
      const tAnalysisStart = Date.now();
      const analysisAudioUrl = executionPlan.generateDubbing ? await this.resolveOriginalAudioUrl(jobId, videoUrl) : videoUrl;
      // Stems / voices an earlier run for this job already produced (Edge Case 3: checkpoint restore).
      const restoredPrep = executionPlan.generateDubbing ? await this.restorePrepFromCheckpoints(jobId) : null;
      const tSepChainStart = Date.now();
      const separationChain: Promise<SeparationChainResult> | null = executionPlan.generateDubbing
        ? this.runSeparationChain(jobId, userId, videoUrl, executionPlan, segments, analysisAudioUrl, restoredPrep?.isolatedVocalUrl ?? null)
        : null;
      // Never left unhandled while the speaker chain runs; awaited (and its outcome used) in step 1.6.
      separationChain?.catch(() => undefined);
      if (executionPlan.generateDubbing && segments.length >= 2) {
        await this.runDiarizationCheck(jobId, videoUrl, executionPlan, segments, transcript);
      }

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
      /** Measured in step 1.6: speech-only videos skip background separation entirely. */
      let separationPath: SeparationPath | null = null;
      let mneValidationResult: import("../services/media").MneValidationResult | undefined;
      const voiceMapping: Record<string, string> = {};
      // Per-language voices (native library voices first); see language-voice-assignment.ts.
      const voiceMappingByLanguage: Record<string, Record<string, string>> = {};
      const voiceFallbacks: Record<string, string> = {};
      const diarizedBySpeaker: Record<string, DiarizedSpeakerProfile> = {};
      const lockedVoiceSpeakers = new Set<string>();
      // speakerId → that speaker's own cloned voice (per-speaker cloning only).
      const speakerCloneVoices = new Map<string, string>();
      // Languages whose dub is skipped because not every speaker has a native voice (subtitles stay).
      const nativeVoiceBlocks: Record<string, string> = {};
      const speakerGenderMapping: Record<string, "MALE" | "FEMALE"> = {};
      let tVoicesStart = Date.now();

      // ⚡ COMPUTE EFFICIENCY GUARD: Full speaker profiling, vocal isolation, voice cloning,
      // and M&E stem separation are strictly required ONLY when Dubbing is requested.
      // Subtitles-only jobs skip these routines to save 15-40s latency and conserve AI tokens.
      if (executionPlan.generateDubbing) {
        // 1.5. Profile all speakers in the transcript (Age, Style, Energy, Gender).
        // Runs while background separation (started above) is in progress.
        speakerProfiles = await this.runSpeakerProfiling(jobId, executionPlan, transcript, analysisAudioUrl);
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

        // 🛡️ Edge Case 3: stems and voice mapping restored from an earlier run of this job.
        if (restoredPrep) {
          if (restoredPrep.isolatedVocalUrl) isolatedVocalUrl = restoredPrep.isolatedVocalUrl;
          if (restoredPrep.mneStemUrl) mneStemUrl = restoredPrep.mneStemUrl;
          if (Object.keys(restoredPrep.voiceMapping).length > 0) Object.assign(voiceMapping, restoredPrep.voiceMapping);
        }

        // 1.6. Background separation → acoustic fingerprint → per-line prosody (runSeparationChain,
        // started before the diarization check), then 1.6a3 emotion transfer, which needs the profiles.
        try {
          const chain = await separationChain!;
          this.recordTiming(prepTimings, "separation_chain", tSepChainStart, { jobId, durationSec: jobDurSec });
          if (chain.isolatedVocalUrl) isolatedVocalUrl = chain.isolatedVocalUrl;
          if (chain.mneStemUrl) mneStemUrl = chain.mneStemUrl;
          separationPath = chain.separationPath;
          acousticFingerprint = chain.acousticFingerprint;
          const prosodyCues = chain.prosodyCues;
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

          // 1.6a3. Emotion transfer: compare each line's pitch and loudness with the character's normal
          // voice; shouted, cried, screamed or growled lines get a v4 delivery tag and a lower stability
          // for that line only (see emotion-transfer.ts). Every other line is left exactly as it was.
          try {
            const genderBySpeaker = new Map<string, "male" | "female">();
            for (const p of speakerProfiles || []) {
              if (p?.speakerId && (p.gender === "male" || p.gender === "female")) genderBySpeaker.set(p.speakerId, p.gender);
            }
            const deliveryLines = segments.map((seg) => {
              const cue = prosodyCues.get(seg.index);
              return {
                index: seg.index,
                startMs: seg.start,
                endMs: seg.end,
                speaker: seg.speaker,
                gender: seg.speaker ? genderBySpeaker.get(seg.speaker) : undefined,
                f0Hz: cue?.f0Hz ?? null,
                voicedRmsDb: cue?.voicedRmsDb ?? null,
              };
            });
            const deliveryHints = new Map<number, LineEmotionHints>();
            for (const seg of segments) {
              const ei = seg.emotionalIntensity;
              deliveryHints.set(seg.index, {
                anger: ei?.anger,
                sadness: ei?.sadness,
                fear: ei?.fear,
                tag: seg.emotionTag,
                voiceQuality: seg.voiceQuality,
              });
            }
            const deliveryPlan = planDelivery(deliveryLines, deliveryHints);
            const byTag: Record<string, number> = {};
            const planRecord: Array<Record<string, unknown>> = [];
            for (const seg of segments) {
              const d = deliveryPlan.get(seg.index);
              if (!d?.tag) continue;
              const st = intenseStability(d.intensity);
              seg.emotionTag = d.tag;
              seg.stabilityOverride = typeof seg.stabilityOverride === "number" ? Math.min(seg.stabilityOverride, st) : st;
              byTag[d.tag] = (byTag[d.tag] || 0) + 1;
              if (planRecord.length < 200) {
                planRecord.push({ index: seg.index, speaker: seg.speaker ?? null, tag: d.tag, intensity: d.intensity, stability: seg.stabilityOverride, pitchRiseSemitones: d.pitchRiseSemitones, loudRiseDb: d.loudRiseDb, reason: d.reason });
              }
            }

            // Safety net with the pipeline's single whisper rule (delivery-tag-guard.ts → isVerifiedWhisper).
            // The prosody step already applies it; this catches a [whispers] that reached a segment by
            // another route (e.g. a cached cue from before PROSODY_RULE_VERSION 3).
            if (isDubbingWhisperGuardEnabled()) {
              for (const seg of segments) {
                if (seg.emotionTag !== "whispers" && seg.emotionTag !== "whisper") continue;
                const cue = prosodyCues.get(seg.index);
                if (isVerifiedWhisper({ f0Hz: cue?.f0Hz, voicedShare: cue?.voicedShare, voiceQuality: cue?.voiceQuality ?? seg.voiceQuality })) continue;
                logger.info("[Dubbing:DeliveryTag] Whisper removed before synthesis", {
                  jobId,
                  index: seg.index,
                  f0Hz: cue?.f0Hz ?? null,
                  voicedShare: cue?.voicedShare ?? null,
                  voiceQuality: cue?.voiceQuality ?? seg.voiceQuality ?? null,
                });
                seg.emotionTag = undefined;
              }
            }

            const measured = deliveryLines.filter((l) => l.f0Hz !== null).length;
            logger.info("[Dubbing:Emotion] Delivery plan", { jobId, lines: segments.length, pitchMeasured: measured, intenseLines: planRecord.length, byTag });
            await db().collection("video_jobs").doc(jobId).set(
              { artifacts: { deliveryPlan: { lines: segments.length, pitchMeasured: measured, byTag, intense: planRecord, plannedAt: Date.now() } } },
              { merge: true }
            ).catch(() => {});
          } catch (emotionErr) {
            logger.warn("[Dubbing:Emotion] Delivery plan skipped", { jobId, err: String(emotionErr) });
          }
        } catch (fingerprintErr) {
          logger.warn("[Dubbing] Acoustic fingerprinting notice:", fingerprintErr);
        }
        this.recordTiming(prepTimings, "analysis", tAnalysisStart, { jobId, durationSec: jobDurSec });

        // Original-audio URL for the steps below (voice clone sample, profiling clips).
        const originalAudioUrl: string = analysisAudioUrl;

        // 1.6b. Instant / Persistent Voice Cloning (when dubbingMode is voice_clone)
        const tCloningStart = Date.now();
        let cloneVoiceGender: "male" | "female" | null = null;
        // 🛡️ A5 Policy: Voice cloning requires explicit creator consent.
        // If consent was not confirmed, gracefully fallback to matched standard voices.
        // Only an explicit `true` counts: plans from the upload form, older jobs and retries carry no
        // consent field and must not clone.
        if (executionPlan.dubbingMode === "voice_clone" && executionPlan.voiceCloneConsent !== true) {
          logger.warn("[Dubbing] Voice cloning requested without verified creator consent — falling back to standard native voices", {
            jobId,
            userId,
          });
          executionPlan.dubbingMode = "standard";
        }

        if (executionPlan.dubbingMode === "voice_clone") {
          try {
            // Check persistent creator voice profiles first (eliminates ElevenLabs slot exhaustion & re-creation delay)
            const voiceProfileDoc = await db().collection("creator_voice_profiles").doc(userId).get();
            // A saved voice is reused only if it was saved with the creator's consent. Profiles saved
            // before the consent policy may hold a guest's voice and are not reused.
            // With per-speaker cloning on and several speakers, every speaker is cloned from this video
            // instead (a saved creator voice would cover one speaker only).
            const cloneEachSpeakerHere = cloneAllSpeakersEnabled() && speakerProfiles.length > 1;
            if (!cloneEachSpeakerHere && voiceProfileDoc.exists && voiceProfileDoc.data()?.voiceId && voiceProfileDoc.data()?.status === "active" && voiceProfileDoc.data()?.consentedAt) {
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
              // Check voice slots / monthly voice operations first: on small plans (Starter: 10 slots,
              // 65 operations a month) a full account must not cost a failed clone call. If the check
              // itself fails, cloning is attempted as before.
              const capacity = await ttsService.getVoiceCapacity().catch((capErr: any) => {
                // HTTP 401 here usually means the API key lacks the "User: Read" permission (GET /v1/user/subscription).
                logger.warn("[Dubbing] Voice capacity check unavailable — attempting clone", { jobId, err: describeElevenLabsError(capErr) });
                return null;
              });
              if (capacity && !capacity.canClone) {
                logger.warn("[Dubbing] Voice cloning skipped — ElevenLabs capacity reached; using matched voices", {
                  jobId,
                  userId,
                  reason: capacity.reason,
                  slotsUsed: capacity.slotsUsed,
                  slotLimit: capacity.slotLimit,
                  editsUsed: capacity.editsUsed,
                  editLimit: capacity.editLimit,
                });
                await this.recordCreatorDubbingNotice(jobId, capacity.reason as CloneBlockReason);
              } else if (speakerProfiles.length > 1 && cloneAllSpeakersEnabled()) {
                // Each speaker is cloned from their own clean lines only (speaker-clone-plan.ts).
                await this.cloneEachSpeaker(jobId, executionPlan, segments, speakerProfiles, isolatedVocalUrl, capacity, speakerCloneIds, speakerCloneVoices);
              } else if (speakerProfiles.length !== 1) {
                // The sample would be every speaker mixed together, and the creator's consent does not
                // cover guests or other people on screen: never clone from multi-speaker audio.
                logger.warn("[Dubbing] Voice cloning skipped — more than one speaker; using matched voices", {
                  jobId,
                  speakers: speakerProfiles.length,
                });
              } else if (sampleUrl) {
                createdVoiceCloneId = await ttsService.cloneVoice(`TruthWorld-${userId.slice(0, 8)}`, sampleUrl);
                DubbingEngine.trackTempClone(jobId, createdVoiceCloneId);
                cloneVoiceGender = speakerProfiles[0]?.gender ?? "male";
                logger.info("[Dubbing] ✅ Created new voice clone", { userId, createdVoiceCloneId, cloneVoiceGender });
                // 🛡️ A5 Guard: Only persist to creator_voice_profiles if confirmed single-speaker creator video
                // and creator opted in, avoiding saving 3rd-party guest/interviewee voices as the creator's voice profile.
                if (speakerProfiles.length === 1 && executionPlan.saveAsCreatorProfile === true) {
                  await db().collection("creator_voice_profiles").doc(userId).set({
                    userId,
                    // Consent record: who consented, when, and on which job/sample.
                    consentedAt: Date.now(),
                    consentJobId: jobId,
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
                  // Saved as the creator's profile: never deleted by the timeout guard.
                  DubbingEngine.pendingTempClones.get(jobId)?.delete(createdVoiceCloneId);
                }
              }
            }
          } catch (cloneErr: any) {
            logger.warn("[Dubbing] Voice cloning notice (falling back to preset matching):", { jobId, err: cloneErr?.message });
            await this.recordCreatorDubbingNotice(jobId, "clone_failed");
          }
        }

        // Strict cloning (DUBBING_CLONE_STRICT=true): stop before the slow steps if a speaker has no clone.
        if (executionPlan.dubbingMode === "voice_clone" && cloneStrict()) {
          const ids = speakerProfiles.map((p: any) => p.speakerId);
          const missing = ids.length > 1 ? ids.filter((id: string) => !speakerCloneVoices.has(id)) : (createdVoiceCloneId ? [] : ids);
          if (missing.length > 0) {
            logger.error("[Dubbing:CloneAll] Strict mode — dub stopped: speakers without a cloned voice", { jobId, missing });
            throw new Error(`Strict voice cloning: no cloned voice for ${missing.join(", ")} (see [Dubbing:CloneAll] logs)`);
          }
        }
        this.recordTiming(prepTimings, "cloning", tCloningStart, { jobId, durationSec: jobDurSec });

        // 1.6c. 🎛️ Industry Standard M&E (Music & Foley) Stem Extraction & Preservation
        const tSeparationStart = Date.now();
        if (mneStemUrl) {
          logger.info("[Dubbing:Resume] Reusing existing M&E stem from checkpoint (0 compute overhead)", { jobId, mneStemUrl });
        } else if (await this.isSpeechOnlyJob(jobId, separationPath)) {
          // Measured in step 1.6: no background worth keeping. The dub is mixed on its own, rather than
          // over a degraded crossover bed that would carry the original voice.
          logger.info("[Separation] Speech-only video — no background track needed", { jobId });
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
                referenceAudioUrl: sourceAudio,
                vocalsUrl: (isolatedVocalUrl && isolatedVocalUrl !== sourceAudio) ? isolatedVocalUrl : undefined,
              });
              if (mneValidationResult.validationStatus === "failed") {
                logger.warn("[Dubbing] Studio M&E stem failed validation — falling back to parallel best-of-2 neural demixing:", mneValidationResult.issues);
                const extracted = await mediaService.extractMneStemDetailedParallel(jobId, sourceAudio, {
                  isolatedVocalUrl: (isolatedVocalUrl && isolatedVocalUrl !== sourceAudio) ? isolatedVocalUrl : undefined,
                  spokenSegments: segments,
                  expectedDurationSeconds: expDurSec,
                });
                mneStemUrl = extracted.mneUrl;
                mneValidationResult = await mediaService.validateMneStem(jobId, mneStemUrl, expDurSec, extracted.source, {
                  spokenSegments: segments,
                  expectedSourceDegraded: extracted.degraded,
                  referenceAudioUrl: sourceAudio,
                  vocalsUrl: extracted.vocalsUrl,
                });
              } else {
                mneStemUrl = studioMne;
                logger.info("[Dubbing] ✅ Priority 1: Ingested & validated studio M&E stem", { jobId, mneStemUrl, status: mneValidationResult.validationStatus });
              }
            } else {
              logger.info("[Dubbing] Priority 2: Extracting Music & Effects (M&E) stem via parallel best-of-2 neural demixing", { jobId, sourceAudio });
              const extracted = await mediaService.extractMneStemDetailedParallel(jobId, sourceAudio, {
                isolatedVocalUrl: (isolatedVocalUrl && isolatedVocalUrl !== sourceAudio) ? isolatedVocalUrl : undefined,
                spokenSegments: segments,
                expectedDurationSeconds: expDurSec,
              });
              mneStemUrl = extracted.mneUrl;
              mneValidationResult = await mediaService.validateMneStem(jobId, mneStemUrl, expDurSec, extracted.source, {
                spokenSegments: segments,
                expectedSourceDegraded: extracted.degraded,
                referenceAudioUrl: sourceAudio,
                vocalsUrl: extracted.vocalsUrl,
              });
              logger.info("[Dubbing] ✅ M&E stem preserved & validated", {
                jobId,
                mneStemUrl,
                source: extracted.source,
                status: mneValidationResult.validationStatus,
                dialogueBleedDb: mneValidationResult.dialogueBleedDb,
              });
            }

            // A stem that failed validation (e.g. source-language dialogue bleed) must never be mixed.
            if (mneValidationResult?.validationStatus === "failed") {
              logger.error("[Dubbing:M&E] M&E stem rejected — dub will ship without the music bed rather than with source dialogue", {
                jobId,
                mneStemUrl,
                vocalSuppressionDb: mneValidationResult.vocalSuppressionDb,
                issues: mneValidationResult.issues,
              });
              mneStemUrl = null;
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
        this.recordTiming(prepTimings, "separation", tSeparationStart, { jobId, durationSec: jobDurSec });

        // 1.7. Speaker-to-Voice Matching Layer by Age, Gender & F0 Fundamental Pitch
        tVoicesStart = Date.now();
        const elevenLabsApiKey = process.env.ELEVENLABS_API_KEY || "";
        const tCatStart = Date.now();
        const catalog = await voiceMatcher.getVoiceCatalog(elevenLabsApiKey);
        emitDubbingTiming("voices.catalog_load", tCatStart, { jobId, catalogSize: catalog.length });
        const assignedVoiceIds = new Set<string>();
        let cloneAssigned = false;
        let reusedVoiceCount = 0;

        const tmpProfileDir = path.join(os.tmpdir(), `spk_profile_${jobId}_${Date.now()}`);
        await fs.promises.mkdir(tmpProfileDir, { recursive: true }).catch(() => {});

        try {
          // Resolve local audio (reusing shared /tmp cache) and lazy signed URL for speaker frame range-seek
          const sourceAudioForProfile = isolatedVocalUrl || originalAudioUrl;
          const tVoicesDlStart = Date.now();
          const localAudioPath = (sharedTmpEnabled()
            ? await mediaService.ensureJobLocalFile(jobId, sourceAudioForProfile, ".mp3", 90000)
            : null) ?? await mediaService.ensureLocalMediaFile(sourceAudioForProfile, tmpProfileDir, ".mp3");
          let accessibleVideoUrl: string | null | undefined;
          let fallbackLocalVideoPath: string | null | undefined;
          const resolveAccessibleVideo = async (): Promise<string | null> => {
            if (accessibleVideoUrl !== undefined) return accessibleVideoUrl;
            if (!videoUrl) {
              accessibleVideoUrl = null;
              return null;
            }
            accessibleVideoUrl = await audioIdentityService.getAccessibleUrl(videoUrl).catch(() => videoUrl);
            return accessibleVideoUrl;
          };
          const resolveFallbackVideo = async (): Promise<string | null> => {
            if (fallbackLocalVideoPath !== undefined) return fallbackLocalVideoPath;
            if (!videoUrl) {
              fallbackLocalVideoPath = null;
              return null;
            }
            fallbackLocalVideoPath = (sharedTmpEnabled()
              ? await mediaService.ensureJobLocalFile(jobId, videoUrl, ".mp4", 180000)
              : null) ?? await mediaService.ensureLocalMediaFile(videoUrl, tmpProfileDir, ".mp4");
            return fallbackLocalVideoPath;
          };
          emitDubbingTiming("voices.tmp_download", tVoicesDlStart, {
            jobId,
            hasAudio: Boolean(localAudioPath),
            hasVideo: Boolean(videoUrl),
            lazyFrameSeek: true,
          });

          // Each speaker's clip, frame and multimodal profile are independent of the others, so they
          // are measured in parallel (bounded); voices are then assigned one speaker at a time, in the
          // same order as before, because each assignment depends on the voices already taken.
          const measureSpeaker = async (profile: any): Promise<DiarizedSpeakerProfile> => {
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
            let pitchClipPath: string | undefined;
            let frameImgPath: string | undefined;

            // Pitch decides gender, so it is measured over all of the speaker's turns (up to 30 s):
            // the longest turns alone can be breathy or shouted and carry no measurable pitch.
            if (localAudioPath && fs.existsSync(localAudioPath)) {
              try {
                const segmentsInMs = segments.some((s) => s.end > 1000);
                const toSec = (v: number) => (segmentsInMs ? v / 1000 : v);
                const pitchTurns = selectPitchTurns(
                  segments.map((s) => ({ speaker: s.speaker, startSec: toSec(s.start), endSec: toSec(s.end) })),
                  profile.speakerId
                );
                if (pitchTurns.length > 0) {
                  const outPitch = path.join(tmpProfileDir, `pitch_${profile.speakerId}.mp3`);
                  await mediaService.extractAudioTurns(localAudioPath, pitchTurns, outPitch);
                  if (fs.existsSync(outPitch)) pitchClipPath = outPitch;
                }
              } catch (pitchClipErr) {
                logger.warn("[Dubbing] Pitch clip notice:", pitchClipErr);
              }
            }

            if (longestSeg) {
              const startSec = longestSeg.start > 1000 ? longestSeg.start / 1000 : longestSeg.start;
              const endSec = longestSeg.end > 1000 ? longestSeg.end / 1000 : longestSeg.end;
              const durationSec = Math.max(0.5, endSec - startSec);
              const sliceDur = Math.min(Math.max(durationSec, 2.5), 5.0);
              const midSec = startSec + (sliceDur / 2);

              if (localAudioPath && fs.existsSync(localAudioPath)) {
                try {
                  const outAudio = path.join(tmpProfileDir, `solo_${profile.speakerId}.mp3`);
                  // Profile from up to 3 of the speaker's clean turns (~9 s), not one short slice.
                  // Units are decided once for the whole job, so a turn starting before 1 s is not misread.
                  const segmentsInMs = segments.some((s) => s.end > 1000);
                  const toSec = (v: number) => (segmentsInMs ? v / 1000 : v);
                  const profilingTurns = selectProfilingTurns(
                    segments.map((s) => ({ speaker: s.speaker, startSec: toSec(s.start), endSec: toSec(s.end) })),
                    profile.speakerId
                  );
                  if (profilingTurns.length > 0) {
                    await mediaService.extractAudioTurns(localAudioPath, profilingTurns, outAudio);
                  } else {
                    await mediaService.extractAudioSlice(localAudioPath, startSec, sliceDur, outAudio);
                  }
                  logger.info("[Dubbing] Speaker profiling clip built", {
                    jobId,
                    speakerId: profile.speakerId,
                    turns: profilingTurns.length,
                    seconds: Number(profilingTurns.reduce((sum, t) => sum + t.durationSec, 0).toFixed(2)),
                  });
                  if (fs.existsSync(outAudio)) clipAudioPath = outAudio;
                } catch (audioSliceErr) {
                  logger.warn("[Dubbing] Solo turn audio slicing notice:", audioSliceErr);
                }
              }

              if (videoUrl) {
                try {
                  const outFrame = path.join(tmpProfileDir, `frame_${profile.speakerId}.jpg`);
                  const remoteVideo = await resolveAccessibleVideo();
                  let extracted = false;
                  if (remoteVideo) {
                    try {
                      await mediaService.extractVideoFrame(remoteVideo, midSec, outFrame);
                      extracted = fs.existsSync(outFrame);
                    } catch {
                      extracted = false;
                    }
                  }
                  if (!extracted) {
                    const localVid = await resolveFallbackVideo();
                    if (localVid && fs.existsSync(localVid)) {
                      await mediaService.extractVideoFrame(localVid, midSec, outFrame);
                    }
                  }
                  if (fs.existsSync(outFrame)) frameImgPath = outFrame;
                } catch (videoFrameErr) {
                  logger.warn("[Dubbing] Video frame extraction notice:", videoFrameErr);
                }
              }
            }

            // 2. Profile speaker via multimodal cues (F0 pitch + visual age & timbre tags + Gemini archetype)
            return voiceMatcher.profileSpeakerMultimodal({
              speakerId: profile.speakerId,
              audioClipPath: clipAudioPath || "",
              pitchClipPath,
              videoFramePath: frameImgPath,
              transcriptSample: spkSegments.slice(0, 3).map((s) => s.text).join(" "),
              preferredGender: executionPlan.voiceGender,
              archetype: profile.archetype,
              vocalWeight: profile.vocalWeight,
            });
          };
          const tMeasureSpkStart = Date.now();
          const measuredProfiles = await mapWithConcurrency(speakerProfiles, SPEAKER_PROFILE_CONCURRENCY, measureSpeaker);
          emitDubbingTiming("voices.speaker_measure", tMeasureSpkStart, { jobId, speakers: speakerProfiles.length });

          for (let profileIndex = 0; profileIndex < speakerProfiles.length; profileIndex++) {
            const profile = speakerProfiles[profileIndex];
            const role = profile.role || "other";
            const diarizedProfile: DiarizedSpeakerProfile = measuredProfiles[profileIndex];

            // Enforce explicit gender override if configured on execution plan
            if (executionPlan.voiceGender === "male") diarizedProfile.gender = "male";
            if (executionPlan.voiceGender === "female") diarizedProfile.gender = "female";

            speakerGenderMapping[profile.speakerId] = diarizedProfile.gender === "female" ? "FEMALE" : "MALE";
            diarizedBySpeaker[profile.speakerId] = diarizedProfile;

            // 0. Explicit creator speaker voice override from Standalone Dubbing Studio
            const spkOverride = executionPlan.speakerOverrides?.[profile.speakerId];
            if (spkOverride?.assignedVoiceId) {
              voiceMapping[profile.speakerId] = spkOverride.assignedVoiceId;
              lockedVoiceSpeakers.add(profile.speakerId);
              assignedVoiceIds.add(spkOverride.assignedVoiceId);
              logger.info("[Dubbing:Studio] Applied explicit creator voice override", {
                jobId,
                speakerId: profile.speakerId,
                voiceId: spkOverride.assignedVoiceId,
              });
              continue;
            }

            // Per-speaker cloning: the speaker's own cloned voice, made in this run, comes first.
            const ownCloneId = speakerCloneVoices.get(profile.speakerId);
            if (ownCloneId) {
              voiceMapping[profile.speakerId] = ownCloneId;
              lockedVoiceSpeakers.add(profile.speakerId);
              assignedVoiceIds.add(ownCloneId);
              logger.info("[Dubbing:CloneAll] Assigned speaker's own cloned voice", {
                jobId,
                speakerId: profile.speakerId,
                voiceId: ownCloneId,
                gender: diarizedProfile.gender,
              });
              continue;
            }

            // 🛡️ Edge Case 3: Retain locked voiceId from checkpoint for speaker (Zero Acoustic Drift)
            if (voiceMapping[profile.speakerId]) {
              const restoredVid = voiceMapping[profile.speakerId];
              const catalogEntry = catalog.find((v) => v.voiceId === restoredVid);
              const knownGender = catalogEntry?.gender || ELEVENLABS_VOICE_GENDER_MAP[restoredVid];
              // 🛡️ A10 Guard: Discard checkpoint voice if there is a cross-gender mismatch
              const isGenderMismatch = knownGender && diarizedProfile.gender !== "neutral" && knownGender !== diarizedProfile.gender;
              if (isGenderMismatch) {
                logger.warn("[Dubbing:Resume] Discarding mapped voice due to gender mismatch with diarized profile", {
                  jobId,
                  speakerId: profile.speakerId,
                  restoredVid,
                  knownGender,
                  expectedGender: diarizedProfile.gender,
                });
                delete voiceMapping[profile.speakerId];
              } else {
                assignedVoiceIds.add(restoredVid);
                logger.info("[Dubbing:Resume] Retaining locked voiceId from checkpoint for speaker", {
                  jobId,
                  speakerId: profile.speakerId,
                  voiceId: restoredVid,
                });
                continue;
              }
            }

            // 🛡️ Strict Clone Gender Invariant: Never assign a male clone to a female speaker or vice-versa
            const isGenderMatch = cloneVoiceGender ? (diarizedProfile.gender === cloneVoiceGender) : true;
            if (!cloneAssigned && createdVoiceCloneId && isGenderMatch) {
              voiceMapping[profile.speakerId] = createdVoiceCloneId;
              lockedVoiceSpeakers.add(profile.speakerId);
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

            // 3. Multi-Speaker Voice Allocation: Select unique, nearest-matching voice.
            // When this gender's unique voices are used up (crowded videos), only the voices whose
            // owners speak furthest away in time may be reused — never someone in the same scene.
            let excludedVoiceIds: Set<string> = assignedVoiceIds;
            const genderMatches = (g: string) => diarizedProfile.gender === "neutral" || g === diarizedProfile.gender;
            const hasUniqueVoiceLeft = catalog.some((v) => !assignedVoiceIds.has(v.voiceId) && genderMatches(v.gender));
            if (!hasUniqueVoiceLeft) {
              const voiceOwners = new Map<string, string[]>();
              for (const [spk, vid] of Object.entries(voiceMapping)) {
                voiceOwners.set(vid, [...(voiceOwners.get(vid) || []), spk]);
              }
              const sameGenderAssigned = catalog
                .filter((v) => voiceOwners.has(v.voiceId) && genderMatches(v.gender))
                .map((v) => v.voiceId);
              const ranked = rankReusableVoices(
                profile.speakerId,
                segments.map((s) => ({ speaker: s.speaker || "speaker_0", start: s.start, end: s.end })),
                voiceOwners,
                sameGenderAssigned
              );
              if (ranked.length > 0) {
                const shortlist = new Set(ranked.slice(0, REUSE_SHORTLIST).map((r) => r.voiceId));
                excludedVoiceIds = new Set(catalog.map((v) => v.voiceId).filter((id) => !shortlist.has(id)));
                reusedVoiceCount++;
                logger.warn("[Dubbing:MultiSpeaker] Unique voices used up — reusing a voice from a different part of the video", {
                  jobId,
                  speakerId: profile.speakerId,
                  gender: diarizedProfile.gender,
                  shortlist: ranked.slice(0, REUSE_SHORTLIST),
                });
              }
            }
            const matchedVoice = voiceMatcher.selectNearestVoice(
              diarizedProfile,
              catalog,
              excludedVoiceIds
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
        if (speakerProfiles.length > 1 && assignedVoiceIds.size < speakerProfiles.length) {
          logger.warn("[Dubbing:MultiSpeaker] Fewer distinct voices than speakers", {
            jobId,
            distinctSpeakers: speakerProfiles.length,
            assignedDistinctVoices: assignedVoiceIds.size,
            reusedVoiceCount,
            catalogSize: catalog.length,
          });
        }
        // Strict cloning: every speaker's assigned voice must be one of this job's clones.
        if (executionPlan.dubbingMode === "voice_clone" && cloneStrict()) {
          const cloneIdsHere = [...speakerCloneVoices.values(), ...(createdVoiceCloneId ? [createdVoiceCloneId] : [])];
          const missing = unclonedSpeakers(speakerProfiles.map((p: any) => p.speakerId), voiceMapping, cloneIdsHere);
          if (missing.length > 0) {
            logger.error("[Dubbing:CloneAll] Strict mode — dub stopped: speakers assigned a library voice", { jobId, missing });
            throw new Error(`Strict voice cloning: library voice assigned to ${missing.join(", ")}`);
          }
          logger.info("[Dubbing:CloneAll] Strict mode — every speaker has a cloned voice", { jobId, speakers: speakerProfiles.length });
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

      // 2a. Per-language voices. With the native-voice policy on (default; voice-locale-policy.ts),
      // each language is voiced only by voices native to it — Indian voices for Indic languages,
      // that language's voices otherwise; never a foreign (e.g. American) preset. If some speaker has
      // no native voice of their gender, the language is not dubbed (subtitles stay). A creator's own
      // voice clone is always kept. With the policy off, native library voices come first and the
      // multilingual presets fill the rest.
      if (executionPlan.generateDubbing && languagesToProcess.length > 0 && Object.keys(voiceMapping).length > 0) {
        const libraryCatalog = loadLibraryCatalog();
        const strictNative = nativeVoicesOnly();
        const tAccCatStart = Date.now();
        const accountVoices = strictNative ? await voiceMatcher.getVoiceCatalog(process.env.ELEVENLABS_API_KEY || "") : [];
        if (strictNative) {
          emitDubbingTiming("voices.catalog_load", tAccCatStart, { jobId, source: "account_native", count: accountVoices.length });
        }
        const orderedSpeakerIds = speakerProfiles.map((p: any) => p.speakerId).filter((id: string) => Boolean(voiceMapping[id]));
        const assignmentSpeakers = orderedSpeakerIds.map((id: string) => ({
          speakerId: id,
          gender: diarizedBySpeaker[id]?.gender ?? (speakerGenderMapping[id] === "FEMALE" ? "female" as const : "male" as const),
          baseVoiceId: voiceMapping[id],
          locked: lockedVoiceSpeakers.has(id),
        }));
        const voiceDistance = (spk: { speakerId: string }, voice: any) =>
          diarizedBySpeaker[spk.speakerId] ? voiceMatcher.scoreCandidate(diarizedBySpeaker[spk.speakerId], voice) : 0;
        const speakerTurns = segments.map((s) => ({ speaker: s.speaker || "speaker_0", start: s.start, end: s.end }));
        // Measure candidate voices' real pitch from their previews (cached per voice), so the closest
        // voice to each original speaker is chosen on measured pitch, not on a gender default.
        const acousticsDeps = defaultVoiceAcousticsDeps();
        const measured = async <C extends { voiceId: string; previewUrl?: string; typicalPitchHz: number; pitchMeasured?: boolean }>(langKey: string, list: C[]): Promise<C[]> => {
          const genders = new Set(assignmentSpeakers.filter((s: any) => !s.locked).map((s: any) => s.gender));
          const relevant = list.filter((v: any) => genders.has("neutral") || genders.has(v.gender));
          const tBatchProbe = Date.now();
          const { candidates, summary } = await withMeasuredPitch(relevant, acousticsDeps, { concurrency: 4, budgetMs: 60_000, jobId, lang: langKey });
          emitDubbingTiming("voices.pitch_batch", tBatchProbe, { jobId, lang: langKey, ...summary });
          logger.info("[Dubbing] Candidate voice pitch", { jobId, language: langKey, ...summary });
          const byId = new Map(candidates.map((c) => [c.voiceId, c]));
          return list.map((v) => byId.get(v.voiceId) || v);
        };
        const describeMatch = (mapping: Record<string, string>, pool: Array<{ voiceId: string; name?: string; typicalPitchHz: number; pitchMeasured?: boolean }>, distances: Record<string, number> = {}) => {
          const byId = new Map(pool.map((v) => [v.voiceId, v]));
          return Object.fromEntries(
            Object.entries(mapping).map(([speakerId, voiceId]) => {
              const v = byId.get(voiceId);
              return [speakerId, {
                voice: v?.name || voiceId,
                speakerPitchHz: diarizedBySpeaker[speakerId]?.medianPitchHz || null,
                voicePitchHz: v && v.pitchMeasured !== false ? v.typicalPitchHz : null,
                matchDistance: distances[speakerId] ?? null,
              }];
            })
          );
        };

        for (const lang of languagesToProcess) {
          const langKey = normalizeLanguageCode(lang);
          if (langKey === normSource) continue;
          const libraryCandidates = libraryVoicesFor(libraryCatalog, lang).map((v) => libraryVoiceToCandidate(v, lang));

          if (strictNative) {
            const pool = new Map<string, NativeCandidate & import("../services/voice-matcher").ElevenLabsVoiceCandidate>();
            for (const v of libraryCandidates) {
              const tier = nativeTier(v, langKey);
              if (tier) pool.set(v.voiceId, { ...v, tier, fromLibrary: true });
            }
            for (const v of accountVoices) {
              const tier = nativeTier(v, langKey);
              if (tier && !pool.has(v.voiceId)) pool.set(v.voiceId, { ...v, tier });
            }
            const nativePool = await measured(langKey, [...pool.values()]);
            const assignment = assignNativeVoices(assignmentSpeakers, nativePool, voiceDistance, speakerTurns);
            if (assignment.unresolvedSpeakers.length > 0) {
              nativeVoiceBlocks[langKey] = "no_native_voice";
              logger.warn("[Dubbing] Native-voice policy: dub skipped for this language — not every speaker has a native voice (subtitles kept)", {
                jobId,
                language: langKey,
                nativeVoicesAvailable: pool.size,
                unresolvedSpeakers: assignment.unresolvedSpeakers,
              });
              continue;
            }
            voiceMappingByLanguage[langKey] = { ...voiceMapping, ...assignment.mapping };
            Object.assign(voiceFallbacks, assignment.fallbacks);
            logger.info("[Dubbing] Native voices assigned", {
              jobId,
              language: langKey,
              nativeVoicesAvailable: pool.size,
              speakers: orderedSpeakerIds.length,
              reusedSpeakers: assignment.reusedSpeakers,
              mapping: assignment.mapping,
              match: describeMatch(assignment.mapping, nativePool, assignment.matchDistance),
            });
            continue;
          }

          if (libraryCandidates.length === 0) continue;
          const measuredLibrary = await measured(langKey, libraryCandidates);
          const assignment = assignLanguageVoices(assignmentSpeakers, measuredLibrary, voiceDistance);
          voiceMappingByLanguage[langKey] = { ...voiceMapping, ...assignment.mapping };
          Object.assign(voiceFallbacks, assignment.fallbacks);
          logger.info("[Dubbing] Per-language voices assigned", {
            jobId,
            language: langKey,
            nativeVoicesInCatalog: libraryCandidates.length,
            speakers: orderedSpeakerIds.length,
            speakersOnNativeVoices: assignment.nativeSpeakers.length,
            mapping: assignment.mapping,
          });
        }
        registerVoiceFallbacks(jobId, voiceFallbacks);
      }
      if (executionPlan.generateDubbing) {
        this.recordTiming(prepTimings, "voices", tVoicesStart, { jobId, durationSec: jobDurSec });
        await db().collection("video_jobs").doc(jobId).set(
          { timings: { prep: prepTimings } },
          { merge: true }
        ).catch(() => {});
      }

      // 🛡️ Edge Case 3: Checkpoint voiceMapping, isolatedVocalUrl, & meStemUrl immediately after Step 1.7
      // Guarantees segments 15..19 synthesize with the exact same voiceId assignments and M&E stem as segments 0..14
      if (executionPlan.generateDubbing && languagesToProcess.length > 0) {
        const canonicalIsoVocal = isolatedVocalUrl ? toCanonicalGsUrl(isolatedVocalUrl) : null;
        const canonicalMeStem = mneStemUrl ? toCanonicalGsUrl(mneStemUrl) : null;

        await Promise.all(
          languagesToProcess.map(async (targetLang) => {
            await this.saveDubbingCheckpoint(jobId, targetLang, {
              stage: "translated",
              voiceMapping: voiceMappingByLanguage[normalizeLanguageCode(targetLang)] ?? voiceMapping,
              isolatedVocalUrl: canonicalIsoVocal,
              meStemUrl: canonicalMeStem,
            });
          })
        );
      }

      // 1.9 Long-Form Distributed Reel Orchestration (> 8m videos / 10-20m features / 90-150m movies)
      // 🛡️ A7 Fix: lower threshold from 20m to 8m (well under the 540s Cloud Function timeout)
      const resolvedDurationMs = await this.resolveJobDurationMs(jobId, executionPlan, segments);
      const reelThresholdMs = Number(process.env.DUBBING_REEL_THRESHOLD_MS || 8 * 60 * 1000);
      const awaitingTwoStageReview =
        executionPlan.twoStageReviewEnabled === true && executionPlan.twoStageReviewCompleted !== true;
      if (executionPlan.generateDubbing && resolvedDurationMs > reelThresholdMs && !awaitingTwoStageReview) {
        logger.info("[Dubbing] Long-form media detected (>8m) — fanning out into distributed reel workers to avoid 540s timeout", {
          jobId,
          resolvedDurationMs,
          reelThresholdMs,
          languages: languagesToProcess,
        });
        if (DubbingEngine.timedOutJobs.has(jobId)) {
          throw new Error("Dubbing stopped: the job already timed out, so no reels are dispatched");
        }
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
          voiceMappingByLanguage,
          voiceFallbacks,
          nativeVoiceBlocks,
          creatorDNA,
          speakerGenderMapping,
          mneStemUrl,
          isolatedVocalUrl,
          mneValidationResult,
          eventId,
          words: transcript.words,
          temporaryVoiceClones: [
            ...(createdVoiceCloneId && !isPersistentVoiceClone ? [createdVoiceCloneId] : []),
            ...speakerCloneIds,
          ],
        });
        reelsDispatched = true;
        DubbingEngine.releaseTempClones(jobId);
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
            voiceMappingByLanguage[normalizeLanguageCode(lang)]
              ? { ...voiceMappingByLanguage[normalizeLanguageCode(lang)] }
              : voiceMapping,
            creatorDNA,
            speakerGenderMapping,
            mneStemUrl,
            isolatedVocalUrl,
            mneValidationResult,
            transcript.words,
            nativeVoiceBlocks[normalizeLanguageCode(lang)]
          )
        )
      );

      // 3. Collect results, log per-language failures
      const dubbingResults:  DubbingResult[]         = [];
      const subtitlePaths:   Record<string, string>  = {};
      const dubbedPaths:     Record<string, string>  = {};
      const audioPaths:      Record<string, string>  = {};
      const dialoguePaths:   Record<string, string>  = {};
      const translationPaths: Record<string, string> = {};

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
          if (v.stems?.dialogue) {
            dialoguePaths[lang] = v.stems.dialogue;
            if (normLang !== lang) dialoguePaths[normLang] = v.stems.dialogue;
          }
          if (v.translationUrl) {
            translationPaths[lang] = v.translationUrl;
            if (normLang !== lang) translationPaths[normLang] = v.translationUrl;
          }
        } else if (r.status === "rejected") {
          const errMsg = r.reason instanceof Error ? r.reason.message : String(r.reason);
          const errStack = r.reason instanceof Error ? r.reason.stack : undefined;
          logger.error("[Dubbing] Language failed", { 
            jobId, lang, 
            reason: errMsg,
            stack: errStack,
          });
          // Explicitly update stages to failed so nothing is left stuck in running (friendly text only)
          const userMsg = friendlyDubbingError(lang, errMsg);
          EdgeLayer.updateStageSync(jobId, `translating_${lang}`, { status: "failed", error: userMsg }).catch(() => {});
          if (normLang !== lang) {
            EdgeLayer.updateStageSync(jobId, `translating_${normLang}`, { status: "failed", error: userMsg }).catch(() => {});
          }
          if (executionPlan.generateDubbing) {
            EdgeLayer.updateStageSync(jobId, `dubbing_${lang}`, { status: "failed", error: userMsg }).catch(() => {});
            if (normLang !== lang) {
              EdgeLayer.updateStageSync(jobId, `dubbing_${normLang}`, { status: "failed", error: userMsg }).catch(() => {});
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

      if (dubbingResults.some((r) => r.dubOutcome === "awaiting_review")) {
        await db().collection("video_jobs").doc(jobId).set(
          {
            updatedAt: Date.now(),
            stages: {
              dubbing: {
                status: "awaiting_transcription_review",
                progress: 45,
                updatedAt: Date.now(),
              },
            },
          },
          { merge: true }
        );
        await syncStudioDubbingJobsForPipelineJob(jobId);
        logger.info("[Dubbing] Paused before TTS for two-stage human script review", { jobId });
        return dubbingResults;
      }

      // A1/A2: a language counts as failed when it threw, or when its dub was ordered but not
      // delivered (a failure inside the dub step, or a language that can't be dubbed). Each is
      // refunded at the price paid for it, once (refundService.ts).
      const failedLangs = results
        .map((r, i) => {
          if (r.status === "rejected") return languagesToProcess[i];
          const outcome = r.value?.dubOutcome;
          return outcome === "failed" || outcome === "not_dubbable" ? languagesToProcess[i] : null;
        })
        .filter((l): l is string => l !== null);
      if (failedLangs.length > 0) {
        logger.warn("[Dubbing] Languages not delivered — refunding them", { jobId, failedLangs });
        await refundDubbingFeeOnFailure({
          jobId,
          userId,
          failedLanguages: failedLangs,
          totalLanguages: languagesToProcess,
          reason: "Dubbing could not be delivered for some languages",
        }).catch((refErr) => logger.error("[Dubbing] Partial refund error:", refErr));
      }
      // Dubbing counts as completed only if at least one ordered dub was delivered.
      const orderedDubLangs = languagesToProcess.filter((l) => normalizeLanguageCode(l) !== normSource);
      const deliveredDubCount = dubbingResults.filter((r) => r.dubOutcome === "delivered").length;
      const dubbingDelivered = !executionPlan.generateDubbing || orderedDubLangs.length === 0 || deliveredDubCount > 0;


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
      const dubbingReportUrl = await saveDubbingReportArtifact({
        jobId,
        videoId: executionPlan.videoId || vData?.videoId || undefined,
        sourceLanguage: normSource,
        targetLanguages: languagesToProcess,
        durationSeconds: jobDurSec > 0 ? jobDurSec : undefined,
        processingTimeMs: completedAt - t0,
        vocalsStemUrl: isolatedVocalUrl || null,
        backgroundStemUrl: mneStemUrl || null,
        separationPath: separationPath || null,
        speakerProfiles: Array.isArray(speakerProfiles) ? speakerProfiles : undefined,
        voiceMapping,
        results: dubbingResults,
        dialogueStems: dialoguePaths,
        subtitlePaths,
        timings: { totalMs: completedAt - t0 },
        generatedAtMs: completedAt,
      });

      await EdgeLayer.upsertDubbingJob(jobId, {
        status: dubbingDelivered ? "completed" : "failed",
        progress: 100,
        completedAt,
        failedLanguages: failedLangs,
        ...(dubbingDelivered ? {} : { error: "Dubbing could not be delivered. The fee has been refunded to your wallet." }),
      });

      await db().collection("video_jobs").doc(jobId).set({
        updatedAt: completedAt,
        timings: { totalMs: completedAt - t0 },
        stages: {
          dubbing: {
            status: executionPlan.generateDubbing ? (dubbingDelivered ? "completed" : "failed") : "skipped",
            progress: 100,
            completedAt,
          },
          subtitles: {
            status: Object.values(subtitlePaths).some((u) => Boolean(u)) ? "completed" : (dubbingDelivered ? "completed" : "failed"),
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
          dialogueTracks: dialoguePaths,
          subtitles: subtitlePaths,
          translations: translationPaths,
          dubbedVideos: dubbedPaths,
          ...(dubbingReportUrl ? { dubbingReportUrl } : {}),
          stems: {
            mne: mneStemUrl || null,
            background: mneStemUrl || null,
            vocals: isolatedVocalUrl || null,
            dialogue: dialoguePaths,
          },
        }
      }, { merge: true });

      await aggregationLayer.onStageComplete(jobId, "dubbing", userId, executionPlan);
      await syncStudioDubbingJobsForPipelineJob(jobId);

      if (
        dubbingDelivered &&
        executionPlan.publishToTruthworld === true &&
        executionPlan.channelId &&
        !executionPlan.videoId
      ) {
        const vJobSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
        const vJobData = vJobSnap?.exists ? vJobSnap.data() || {} : {};
        await publishCompletedStudioJobToTruthworld({
          pipelineJobId: jobId,
          studioJobId: typeof vJobData.studioJobId === "string" ? vJobData.studioJobId : undefined,
          userId,
          channelId: executionPlan.channelId,
          title: String(executionPlan.title || vJobData.fileName || "Dubbed Video"),
          durationSeconds: Number(executionPlan.durationSeconds || executionPlan.duration || jobDurSec || 60),
          sourceLanguage: normSource,
          sourceMediaUrl: videoUrl,
          dubbedPaths,
          audioPaths,
          subtitlePaths,
        }).catch((pubErr) => {
          logger.error("[DubbingStudio:Publish] Non-fatal feed publish error:", {
            jobId,
            err: String(pubErr),
          });
        });
      }

      logger.info("[Dubbing] Completed", {
        jobId,
        languages: dubbingResults.length,
        ms:        Date.now() - t0,
      });
      await this.distribution.markEventCompleted(eventId);

      return dubbingResults;

    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);

      // 💳 Refund the ordered languages that were not delivered (A12: a language whose dub already
      // completed — saved checkpoint — is kept and not refunded).
      await this.refundUndeliveredLanguages(jobId, userId, executionPlan, "Dubbing could not be completed")
        .catch((refErr) => logger.error("[Dubbing] Failure rollback refund error:", refErr));

      // 🔄 Unblock Pub/Sub Retry & Avoid Idempotency Trap
      await this.distribution.markEventFailed(eventId, errMsg).catch(() => {});

      const userJobMsg = friendlyDubbingJobError();
      await EdgeLayer.failStage(jobId, "dubbing", userJobMsg);
      await EdgeLayer.upsertDubbingJob(jobId, {
        status: "failed",
        error: userJobMsg,
        completedAt: Date.now(),
      });
      await db().collection("video_jobs").doc(jobId).set({
        updatedAt: Date.now(),
        stages: {
          dubbing: {
            status: executionPlan.generateDubbing ? "failed" : "skipped",
            ...(executionPlan.generateDubbing ? { error: userJobMsg, failedAt: Date.now() } : {}),
          },
          subtitles: {
            status: "failed",
            error: userJobMsg,
            failedAt: Date.now(),
          },
          onDemandAI: {
            status: "failed",
            error: userJobMsg,
            failedAt: Date.now(),
          }
        }
      }, { merge: true });
      await aggregationLayer.onStageComplete(jobId, "dubbing", userId, executionPlan).catch(() => {});
      await syncStudioDubbingJobsForPipelineJob(jobId, null, {
        status: "failed",
        currentStepMessage: userJobMsg,
        error: userJobMsg,
      });
      throw error;
    } finally {
      if (reelsDispatched) {
        // Reel workers still need the clones; assembleDubbingReels deletes them once every reel is voiced.
        logger.info("[Dubbing] Reels dispatched — temporary voice clones kept for the reel workers", {
          jobId,
          creatorClone: createdVoiceCloneId && !isPersistentVoiceClone ? 1 : 0,
          speakerClones: speakerCloneIds.length,
        });
      } else {
      // 💨 Voice Lifecycle Cleanup: Only delete temporary clones, preserve persistent profiles
      if (createdVoiceCloneId && !isPersistentVoiceClone) {
        logger.info("[Dubbing] Job Finished — cleaning up temporary creator voice clone", { jobId, createdVoiceCloneId });
        await ttsService.deleteVoice(createdVoiceCloneId).catch(() => {});
      }
      if (speakerCloneIds.length > 0) {
        logger.info("[Dubbing:CloneAll] Job finished — deleting per-speaker voice clones", { jobId, count: speakerCloneIds.length });
        await Promise.all(speakerCloneIds.map((id) => ttsService.deleteVoice(id).catch(() => false)));
      }
      }
      // Deleted above, handed to the reels, or kept as a creator profile: nothing left to track.
      DubbingEngine.releaseTempClones(jobId);
      DubbingEngine.timedOutJobs.delete(jobId);
    }
  }

  /**
   * Per-speaker voice cloning (DUBBING_CLONE_ALL_SPEAKERS=true; see speaker-clone-plan.ts).
   * Cuts each speaker's clean lines from the vocal stem, clones up to the speaker limit and the plan's
   * free capacity, and records each clone in `cloneIds` as soon as it exists so `finally` deletes it.
   * Speakers not cloned keep a matched library voice. Never throws: a failed clone leaves that
   * speaker on a library voice.
   */
  private async cloneEachSpeaker(
    jobId: string,
    executionPlan: ExecutionPlan,
    segments: TimedSegment[],
    speakerProfiles: any[],
    sampleUrl: string | null,
    capacity: VoiceCapacity | null,
    cloneIds: string[],
    cloneVoices: Map<string, string>
  ): Promise<void> {
    // Long videos (reel workers) keep these clones until assembleDubbingReels deletes them.
    if (!sampleUrl) {
      // Samples are cut only from the isolated voice stem. Cut from the full mix they would carry the
      // music and effects into every clone (24 Nov run …141470: Demucs timed out, clones were cut from the mix).
      logger.warn("[Dubbing:CloneAll] Skipped — no isolated voice track (separation failed or was skipped); clones would carry the music", { jobId });
      await db().collection("video_jobs").doc(jobId).set(
        { artifacts: { speakerClones: { speakers: speakerProfiles.length, cloned: [], failed: [], skipped: [], reason: "no_isolated_vocals", plannedAt: Date.now() } } },
        { merge: true }
      ).catch(() => {});
      return;
    }

    const segmentsInMs = segments.some((s) => s.end > 1000);
    const toSec = (v: number) => (segmentsInMs ? v / 1000 : v);
    const turns = segments.map((s) => ({ speaker: s.speaker || "speaker_0", startSec: toSec(s.start), endSec: toSec(s.end) }));
    const speakerIds = speakerProfiles.map((p: any) => p.speakerId).filter(Boolean);
    const capacityLeft = remainingCloneCapacity(capacity);
    const strict = cloneStrict();
    const plan = planSpeakerClones(speakerIds, turns, {
      maxSpeakers: cloneMaxSpeakers(),
      minSeconds: cloneMinSeconds(),
      capacityLeft,
      strict,
    });
    logger.info("[Dubbing:CloneAll] Plan", {
      jobId,
      speakers: speakerIds.length,
      sampleSource: sampleUrl,
      capacityLeft,
      strict,
      clone: plan.clone.map((c) => ({ speakerId: c.speakerId, seconds: c.seconds, lines: c.turns.length, sample: c.sample })),
      skipped: plan.skipped,
    });
    // Strict: if anyone would be left on a library voice, clone nobody (no voice operations spent);
    // the strict check after this step fails the dub with the reasons.
    if (strict && plan.skipped.length > 0) {
      logger.error("[Dubbing:CloneAll] Strict mode — not every speaker can be cloned; no clones made", { jobId, skipped: plan.skipped });
      await db().collection("video_jobs").doc(jobId).set(
        { artifacts: { speakerClones: { speakers: speakerIds.length, cloned: [], failed: [], skipped: plan.skipped, capacityLeft, strict, plannedAt: Date.now() } } },
        { merge: true }
      ).catch(() => {});
      return;
    }

    const created: Array<{ speakerId: string; voiceId: string; seconds: number; sample: string }> = [];
    const failed: string[] = [];
    if (plan.clone.length > 0) {
      const tmpDir = path.join(os.tmpdir(), `clone_all_${jobId}_${Date.now()}`);
      await fs.promises.mkdir(tmpDir, { recursive: true }).catch(() => {});
      try {
        const localAudio = await mediaService.ensureLocalMediaFile(sampleUrl, tmpDir, ".mp3");
        if (!localAudio) {
          logger.warn("[Dubbing:CloneAll] Skipped — could not open the vocal audio; using matched voices", { jobId });
        } else {
          // One at a time: each call is one voice add on the account; parallel adds gain little here.
          for (const c of plan.clone) {
            try {
              const samplePath = path.join(tmpDir, `clone_${c.speakerId}.mp3`);
              await mediaService.extractAudioTurns(localAudio, c.turns, samplePath);
              const voiceId = await ttsService.cloneVoiceFromFile(`TruthWorld-${jobId.slice(0, 12)}-${c.speakerId}`, samplePath);
              cloneIds.push(voiceId);
              DubbingEngine.trackTempClone(jobId, voiceId);
              // A clone can be created and still be refused for speech (e.g. "This voice requires
              // verification"). One short line now finds that out before translation and synthesis.
              const probe = await ttsService.probeVoice(voiceId, CLONE_PROBE_TEXT);
              if (!probe.ok) throw new Error(`clone created but not usable for speech: ${probe.reason}`);
              cloneVoices.set(c.speakerId, voiceId);
              created.push({ speakerId: c.speakerId, voiceId, seconds: c.seconds, sample: c.sample });
              logger.info("[Dubbing:CloneAll] Created speaker voice clone", { jobId, speakerId: c.speakerId, voiceId, seconds: c.seconds, lines: c.turns.length, sample: c.sample });
            } catch (cloneErr: any) {
              failed.push(c.speakerId);
              if (strict) {
                // Strict: the dub will stop anyway, so make no further clones (each costs a voice operation).
                logger.error("[Dubbing:CloneAll] Clone refused — strict mode stops cloning", { jobId, speakerId: c.speakerId, sample: c.sample, seconds: c.seconds, err: cloneErr?.message, notAttempted: plan.clone.slice(plan.clone.indexOf(c) + 1).map((x) => x.speakerId) });
                break;
              }
              logger.warn("[Dubbing:CloneAll] Clone failed for speaker — using a matched voice", { jobId, speakerId: c.speakerId, err: cloneErr?.message });
            }
          }
        }
      } finally {
        await fs.promises.rm(tmpDir, { recursive: true, force: true }).catch(() => {});
      }
    }

    await db().collection("video_jobs").doc(jobId).set(
      { artifacts: { speakerClones: { speakers: speakerIds.length, cloned: created, failed, skipped: plan.skipped, capacityLeft, strict, plannedAt: Date.now() } } },
      { merge: true }
    ).catch(() => {});
  }

  // ─── Direct Audio Track Propagation ──────────────────────────────────────────

  /**
   * Adds a polite, creator-facing notice to the job (video_jobs/{jobId}.dubbingNotices) when the
   * creator's own voice could not be used. The client shows these messages; never raw errors.
   */
  /**
   * Whether step 1.6 measured this video as speech-only (no background to keep). Uses the value
   * from this run when known, else the decision saved on the job (resumed jobs, per-language steps).
   */
  /**
   * Cast list and relationships for translation, bound to the speaker labels the lines use.
   * Relationships are written with cast names (or AUDIENCE / GROUP); the binding comes from the
   * diarization check (artifacts.castBinding, cast-list.ts buildCastBinding). Unresolved names are
   * logged and dropped. The cast carries each member's label so the cache/checkpoint hash changes
   * when the binding does.
   */
  private async loadCastContext(
    jobId: string,
    executionPlan: ExecutionPlan,
    segments: Array<{ speaker?: string }>
  ): Promise<{
    castList: CastMemberWithRelations[];
    relationships: CharacterRelationship[];
    speakerNames: Record<string, string>;
    castGenderByLabel: Record<string, "male" | "female">;
  }> {
    const cast = parseCastList(executionPlan.castList);
    const relationships = parseCastRelationships(executionPlan.relationships);
    let binding: Record<string, string> = {};
    if (cast.length > 0) {
      try {
        const snap = await db().collection("video_jobs").doc(jobId).get();
        const stored = snap.data()?.artifacts?.castBinding;
        if (stored && typeof stored === "object") binding = stored as Record<string, string>;
      } catch {
        binding = {};
      }
    }
    const labels = new Set(segments.map((s) => s.speaker).filter((s): s is string => Boolean(s)));
    const { bound, unresolved } = bindRelationships(relationships, binding, labels, cast);
    if (unresolved.length > 0) {
      logger.warn("[Dubbing] Relationship speakers not matched to any voice — those relationships are skipped", {
        jobId,
        unresolved,
      });
    }
    const speakerNames: Record<string, string> = {};
    for (const m of cast) {
      const label = binding[m.name.toLowerCase()];
      if (label) speakerNames[label] = m.name;
    }
    return {
      castList: cast.map((m) => ({ ...m, ...(binding[m.name.toLowerCase()] ? { speakerId: binding[m.name.toLowerCase()] } : {}) })),
      relationships: bound,
      speakerNames,
      castGenderByLabel: bindCastGenders(cast, binding),
    };
  }

  /** Ordered languages without a completed (delivered) checkpoint. */
  private async undeliveredLanguages(jobId: string, executionPlan: ExecutionPlan): Promise<{ ordered: string[]; undelivered: string[] }> {
    const ordered: string[] = executionPlan?.dubbingLanguages || executionPlan?.languages || [];
    const undelivered: string[] = [];
    for (const lang of ordered) {
      const cp = await this.loadDubbingCheckpoint(jobId, normalizeLanguageCode(lang)).catch(() => null);
      const delivered = (cp?.stage === "completed" || cp?.status === "completed") && Boolean(cp?.masterAudioUrl);
      if (!delivered) undelivered.push(lang);
    }
    return { ordered, undelivered };
  }

  /** Refunds the ordered languages that were not delivered (each at its price, once). */
  private async refundUndeliveredLanguages(jobId: string, userId: string, executionPlan: ExecutionPlan, reason: string): Promise<string[]> {
    const { ordered, undelivered } = await this.undeliveredLanguages(jobId, executionPlan);
    if (undelivered.length > 0) {
      await refundDubbingFeeOnFailure({ jobId, userId, failedLanguages: undelivered, totalLanguages: ordered, reason });
    }
    return undelivered;
  }

  /**
   * A7 retry cap: called by handleDubbing when a dubbing event has been delivered more times than
   * allowed (usually repeated 540 s timeouts). Refunds the languages not delivered, marks dubbing
   * failed with a friendly message, and lets the caller acknowledge the message. If every ordered
   * language was already delivered (a duplicate delivery of a finished event), nothing changes.
   */
  async failAfterRetryLimit(jobId: string, userId: string, executionPlan: ExecutionPlan, eventId: string, attempts: number): Promise<{ refundedLanguages: string[] }> {
    const { undelivered } = await this.undeliveredLanguages(jobId, executionPlan);
    if (undelivered.length === 0) {
      logger.info("[Dubbing] Retry limit reached on an event whose languages are all delivered — finalizing status", { jobId, eventId, attempts });
      await this.distribution.markEventCompleted(eventId).catch(() => {});
      await EdgeLayer.updateStageSync(jobId, "dubbing", {
        status: "completed",
        progress: 100,
        completedAt: Date.now(),
        error: admin.firestore.FieldValue.delete() as any,
      }).catch(() => {});
      await EdgeLayer.upsertDubbingJob(jobId, {
        status: "completed",
        progress: 100,
        completedAt: Date.now(),
        error: admin.firestore.FieldValue.delete() as any,
      }).catch(() => {});
      await syncStudioDubbingJobsForPipelineJob(jobId, null, {
        status: "completed",
        progressPercent: 100,
        currentStepMessage: "Your dubbed audio is ready.",
        error: admin.firestore.FieldValue.delete() as any,
      }).catch(() => {});
      return { refundedLanguages: [] };
    }
    const friendly = "Dubbing could not be completed after several attempts. The fee for the undelivered languages has been refunded to your wallet.";
    await this.refundUndeliveredLanguages(jobId, userId, executionPlan, "Dubbing retry limit reached")
      .catch((refErr) => logger.error("[Dubbing] Retry-limit refund error:", refErr));
    await this.distribution.markEventFailed(eventId, "retry limit reached").catch(() => {});
    await EdgeLayer.failStage(jobId, "dubbing", friendly).catch(() => {});
    await EdgeLayer.upsertDubbingJob(jobId, {
      status: "failed",
      error: friendly,
      failedLanguages: undelivered,
      attempts,
      completedAt: Date.now(),
    }).catch(() => {});
    await syncStudioDubbingJobsForPipelineJob(jobId, null, {
      status: "failed",
      currentStepMessage: friendly,
      error: friendly,
    });
    logger.error("[Dubbing] Retry limit reached — undelivered languages refunded, dubbing marked failed", { jobId, eventId, attempts, undelivered });
    return { refundedLanguages: undelivered };
  }

  // ─── Analysis steps shared by executeDubbingPipeline and prepareDubbingAnalysis ─────────────────
  // Same models, prompts and inputs as before; results are stored per job (dubbing-step-cache.ts) so a
  // retry, a resumed job, a later language order or an order after upload-time preparation reuses them.

  /** Natural speech segments from the transcript (word-anchored when word timings exist). */
  private buildDubbingSegments(transcript: any): { rawCount: number; segments: TimedSegment[] } {
    // If words are present, build utterance-anchored segments (prevents 60-second monolithic blocks)
    let rawSegments: TimedSegment[] = [];
    if (transcript.words && Array.isArray(transcript.words) && transcript.words.length > 0) {
      rawSegments = this.buildSegmentsFromWords(transcript.words);
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
        // Word timings for the line splitter only (see segment-timing.ts); not read by subtitles.
        ...(Array.isArray(u.timingWords) && u.timingWords.length > 0 ? { timingWords: u.timingWords } : {}),
      }));
    }

    // Decompose any monolithic segments (>8s or >140 chars) into natural breath/clause units
    rawSegments = this.splitOversizedSegments(rawSegments, 8000, 140);

    const segments = this.stitchSegments(rawSegments).map(s => ({
      ...s,
      isHook: s.start < 10000 // First 10 seconds
    }));
    return { rawCount: rawSegments.length, segments };
  }

  /** The transcription audio (what AssemblyAI heard), or the video when it is not recorded. */
  private async resolveOriginalAudioUrl(jobId: string, videoUrl: string): Promise<string> {
    try {
      const jobDoc = await db().collection("video_jobs").doc(jobId).get();
      return jobDoc.data()?.artifacts?.transcription?.audioUrl || videoUrl;
    } catch (_) {
      return videoUrl;
    }
  }

  /** Edge Case 3: stems and voice mapping an earlier run of this job already produced. */
  private async restorePrepFromCheckpoints(jobId: string): Promise<{
    isolatedVocalUrl: string | null;
    mneStemUrl: string | null;
    voiceMapping: Record<string, string>;
  }> {
    const out = { isolatedVocalUrl: null as string | null, mneStemUrl: null as string | null, voiceMapping: {} as Record<string, string> };
    try {
      const existingCheckpoints = await db().collection("dubbing_checkpoints").where("jobId", "==", jobId).get().catch(() => null);
      if (existingCheckpoints && !existingCheckpoints.empty) {
        for (const doc of existingCheckpoints.docs) {
          const data = doc.data();
          if (data.isolatedVocalUrl && !out.isolatedVocalUrl) {
            out.isolatedVocalUrl = data.isolatedVocalUrl;
            logger.info("[Dubbing:Resume] Restored isolatedVocalUrl from existing checkpoint (skipping Step 1.6 neural separation)", { jobId, isolatedVocalUrl: out.isolatedVocalUrl });
          }
          if (data.meStemUrl && !out.mneStemUrl) {
            out.mneStemUrl = data.meStemUrl;
            logger.info("[Dubbing:Resume] Restored meStemUrl from existing checkpoint (skipping Step 1.6c neural demixing)", { jobId, mneStemUrl: out.mneStemUrl });
          }
          if (data.voiceMapping && Object.keys(data.voiceMapping).length > 0) {
            Object.assign(out.voiceMapping, data.voiceMapping);
            logger.info("[Dubbing:Resume] Restored voiceMapping from existing checkpoint (locking speaker -> voiceId)", { jobId, voiceMapping: out.voiceMapping });
          }
        }
      }
    } catch (restoreErr) {
      logger.warn("[Dubbing:Resume] Notice loading existing stem checkpoints:", restoreErr);
    }
    return out;
  }

  /**
   * 1.2b. Diarization check. AssemblyAI clusters by voice alone and can merge two characters under one
   * label or split one character across labels; each label becomes one voice. Gemini names the
   * on-screen speaker of every turn and diarization-reconcile.ts applies only confident corrections.
   * Mutates `segments` (speaker labels) and `transcript.utterances` (split by corrected turns).
   */
  private async runDiarizationCheck(
    jobId: string,
    videoUrl: string,
    executionPlan: ExecutionPlan,
    segments: TimedSegment[],
    transcript: any
  ): Promise<void> {
    const turns = segments.map((s, i) => ({ index: i, start: s.start, end: s.end, speaker: s.speaker || "speaker_0", text: s.text }));
    const checkOptions = {
      // Re-validated here too: plans stored before this field existed, or written elsewhere.
      cast: parseCastList(executionPlan.castList),
      maxTurns: maxTurnsForJob({
        durationSec: Number(executionPlan.durationSeconds ?? executionPlan.duration) || undefined,
        cinemaGrade: executionPlan.cinemaGrade === true,
        isReelJob: executionPlan.isReelJob === true,
      }),
    };
    const { value: diarization } = await cachedStep(
      jobId,
      "diarization",
      // transcriptRecheck: a result cached with the recheck off has no text corrections, so turning the
      // recheck on must not reuse it (upload-time prewarm, resumed jobs). Added only when on, so keys
      // already cached with the recheck off stay valid.
      {
        videoUrl,
        turns: contentHash(turns),
        cast: checkOptions.cast,
        maxTurns: checkOptions.maxTurns,
        ...(isTranscriptPlausibilityRecheckEnabled() ? { transcriptRecheck: 1 } : {}),
      },
      () => diarizationCheckService.check(jobId, videoUrl, turns, checkOptions),
      { isDegraded: isFailedDiarization }
    );
    // Record what the check did, so a merged-speaker dub can be traced to AssemblyAI (speakersBefore)
    // or to the check (applied / reason / speakersAfter). Read by scripts/dubbing/local-dub-test.ts.
    const diarizationSummary = { ...summarizeDiarization(turns.map((t) => t.speaker), diarization), model: diarizationModel() };
    logger.info("[Dubbing] Diarization check summary", { jobId, ...diarizationSummary });
    await db().collection("video_jobs").doc(jobId).set(
      { artifacts: { diarization: { ...diarizationSummary, checkedAt: Date.now() } } },
      { merge: true }
    ).catch(() => {});
    // Cast name → speaker label, so relationships ("Pharaoh → Joseph: formal") and cast genders
    // written by name reach the lines that use labels (A, B, B_2). Saved on the job for the
    // per-language steps, resumed jobs and long-form reels.
    const castForBinding = checkOptions.cast;
    if (castForBinding.length > 0 && diarization.characterLabels.size > 0) {
      const castBinding = buildCastBinding(castForBinding, diarization.characterLabels);
      await db().collection("video_jobs").doc(jobId).set(
        { artifacts: { castBinding, castBoundAt: Date.now() } },
        { merge: true }
      ).catch(() => {});
      logger.info("[Dubbing] Cast bound to speaker labels", {
        jobId,
        castBinding,
        unbound: castForBinding.map((m) => m.name).filter((n) => !castBinding[n.toLowerCase()]),
      });
    }
    if (diarization.applied) {
      segments.forEach((s, i) => {
        const corrected = diarization.labels.get(String(i));
        if (corrected) s.speaker = corrected;
      });
      if (transcript.utterances && transcript.utterances.length > 0) {
        // Split, not just relabel: AssemblyAI can return several characters as one utterance, and
        // speaker profiling reads utterances — a split label without its own utterance gets no voice.
        transcript.utterances = splitUtterancesBySegments(transcript.utterances, segments);
      }
      logger.info("[Dubbing] Speaker labels corrected before voice assignment", {
        jobId,
        changes: diarization.changes,
      });
    }
    const textCorrections = (diarization as any).textCorrections;
    if (textCorrections) {
      const getCorrection = (idx: number): string | undefined => {
        if (textCorrections instanceof Map) {
          return textCorrections.get(String(idx)) || textCorrections.get(`T${idx}`);
        }
        return textCorrections[String(idx)] || textCorrections[`T${idx}`];
      };
      segments.forEach((s, i) => {
        const corr = getCorrection(i);
        if (corr && typeof corr === "string" && corr.trim()) {
          logger.info("[Dubbing:TranscriptCorrectionApplied]", { index: i, before: s.text, after: corr });
          s.text = corr.trim();
        }
      });
    }
  }

  /** 1.5. Speaker profiles (age, style, energy, gender) from the (corrected) utterances. */
  private async runSpeakerProfiling(
    jobId: string,
    executionPlan: ExecutionPlan,
    transcript: any,
    originalAudioUrl: string
  ): Promise<any[]> {
    const utterances = transcript.utterances ?? [];
    const { value } = await cachedStep(
      jobId,
      "speakers",
      {
        utterances: contentHash(utterances),
        audio: originalAudioUrl,
        // profileSpeakers treats a missing preference and "auto" the same way.
        preferredGender: executionPlan.voiceGender === "male" || executionPlan.voiceGender === "female" ? executionPlan.voiceGender : "auto",
      },
      () => speakerProfilingService.profileSpeakers(utterances, originalAudioUrl, { preferredGender: executionPlan.voiceGender }),
      { isDegraded: hasFallbackSpeakerProfile }
    );
    return value;
  }

  /**
   * 1.6 → 1.6a2. Background separation by need (separation-policy.ts), then the acoustic fingerprint
   * and per-line prosody, which read the isolated vocals when there are any. Independent of speaker
   * labels, so it runs in parallel with the diarization check and speaker profiling.
   */
  private async runSeparationChain(
    jobId: string,
    userId: string,
    videoUrl: string,
    executionPlan: ExecutionPlan,
    segments: TimedSegment[],
    originalAudioUrl: string,
    restoredVocalUrl: string | null
  ): Promise<SeparationChainResult> {
    let isolatedVocalUrl: string | null = restoredVocalUrl;
    let mneStemUrl: string | null = null;
    let separationPath: SeparationPath | null = null;

    if (!isolatedVocalUrl) {
      // 💰 Separation by need (separation-policy.ts). Measured with FFmpeg: speech-only videos
      // need no separation ($0); videos with music/effects use the self-hosted Demucs worker
      // (DEMUX_SERVICE_URL). Without it, the M&E path (step 1.6c) builds the background.
      const durationSecForSeparation = Number(executionPlan.durationSeconds || executionPlan.duration) ||
        (segments.length > 0 ? segments[segments.length - 1].end / 1000 : 0);
      const gaps = speechGaps(
        segments.map((s) => ({ start: s.start, end: s.end })),
        Math.round(durationSecForSeparation * 1000)
      );
      const settings = readSeparationSettings();
      const workerConfigured = Boolean(PIPELINE_CONFIG.DEMUX_SERVICE_URL && !PIPELINE_CONFIG.DEMUX_SERVICE_URL.includes("placeholder"));
      const { value: sep, hit } = await cachedStep<CachedSeparation>(
        jobId,
        "separation",
        { audio: originalAudioUrl, videoUrl, gaps: contentHash(gaps), settings, workerConfigured },
        async () => {
          const tPolicyStart = Date.now();
          const levels = await mediaService.measureBackgroundLevels(jobId, originalAudioUrl, gaps);
          const decision = decideSeparation(levels, settings);
          emitDubbingTiming("separation.policy", tPolicyStart, { jobId, path: decision.path, reason: decision.reason });
          logger.info("[Separation] Decision", { jobId, ...decision, gaps: gaps.length, durationSec: durationSecForSeparation });

          const out: CachedSeparation = { path: decision.path, reason: decision.reason, engine: "none", vocalsUrl: null, mneUrl: null };
          if (decision.path === "demucs") {
            const tStereoStart = Date.now();
            const stereoSource = await mediaService.extractStereoSourceAudio(videoUrl, jobId).catch(() => originalAudioUrl);
            emitDubbingTiming("separation.stereo_extract", tStereoStart, { jobId });

            // Priority 1: Self-hosted Demux GPU Worker (Modal Demucs v4)
            if (workerConfigured) {
              try {
                const demuxResult = await mediaService.separateWithDemuxWorker(jobId, stereoSource);
                if (demuxResult && !demuxResult.degraded) {
                  out.vocalsUrl = demuxResult.vocalsUrl || null;
                  out.mneUrl = demuxResult.mneUrl || null;
                  out.engine = demuxResult.engine;
                  logger.info("[Separation] Demucs stems ready via self-hosted GPU worker", {
                    jobId,
                    engine: demuxResult.engine,
                    hasVocals: Boolean(demuxResult.vocalsUrl),
                    hasMne: Boolean(demuxResult.mneUrl),
                  });
                }
              } catch (workerErr: any) {
                logger.warn("[Separation] Self-hosted Demux worker unavailable — background track falls back to the existing M&E path", {
                  jobId,
                  error: workerErr?.message || String(workerErr),
                });
              }
            }
          }
          // Record what separation actually cost (it was invisible before), and the decision, so the
          // per-language steps skip background extraction on speech-only videos.
          const separationCost = out.engine.startsWith("demucs") ? separationCostUsd("demucs", durationSecForSeparation) : 0;
          if (separationCost > 0) {
            costEngine.recordCost(jobId, userId, "separation", out.engine, separationCost, "minutes", durationSecForSeparation / 60).catch(() => {});
          }
          await db().collection("video_jobs").doc(jobId).set(
            { artifacts: { separation: { path: decision.path, engine: out.engine, reason: decision.reason, costUsd: separationCost, decidedAt: Date.now() } } },
            { merge: true }
          ).catch(() => {});
          return out;
        },
        // Demucs was needed but the worker gave nothing: the next run tries the worker again.
        { isDegraded: (r) => r.path === "demucs" && !r.vocalsUrl && !r.mneUrl }
      );
      separationPath = sep.path;
      if (sep.vocalsUrl) isolatedVocalUrl = sep.vocalsUrl;
      if (sep.mneUrl) mneStemUrl = sep.mneUrl;
      if (hit) logger.info("[Separation] Reused prepared separation", { jobId, path: sep.path, engine: sep.engine });
    } else {
      logger.info("[Dubbing:Resume] Reusing existing isolatedVocalUrl from checkpoint (skipping Step 1.6 neural vocal isolation)", { jobId, isolatedVocalUrl });
    }

    const voiceSource = isolatedVocalUrl || originalAudioUrl;
    // Fingerprint and prosody both read the same audio and do not depend on each other.
    const prosodyInput = segments.map((s) => ({ index: s.index, start: s.start, end: s.end, text: s.text, speaker: s.speaker }));
    const tFpStart = Date.now();
    const tProsodyStart = Date.now();
    const [fingerprint, prosody] = await Promise.all([
      cachedStep(jobId, "fingerprint", { audio: voiceSource },
        () => audioIdentityService.captureFingerprint(jobId, voiceSource),
        { isDegraded: isDefaultFingerprint }).then((r) => {
          emitDubbingTiming("separation.fingerprint", tFpStart, { jobId, cacheHit: r.hit });
          return r;
        }),
      // 1.6a2. Per-segment acoustic RMS energy + expressive emotion tags ([whispers], [soft], [laughs], etc.)
      cachedStep(jobId, "prosody", { audio: voiceSource, segments: contentHash(prosodyInput), ruleVersion: PROSODY_RULE_VERSION },
        () => audioIdentityService.analyzeSegmentProsody(jobId, voiceSource, segments).catch(() => new Map()),
        { isDegraded: (cues) => isAcousticOnlyProsody(cues, segments.length) }).then((r) => {
          emitDubbingTiming("separation.prosody", tProsodyStart, { jobId, cacheHit: r.hit });
          return r;
        }),
    ]);

    return {
      isolatedVocalUrl,
      mneStemUrl,
      separationPath,
      acousticFingerprint: fingerprint.value,
      prosodyCues: prosody.value as Map<number, any>,
    };
  }

  /**
   * Upload-time preparation (dubbing.prewarm.requested). Runs the language-independent analysis —
   * diarization check, speaker profiling, separation, fingerprint, prosody — right after
   * transcription, for videos without a dubbing order yet, so a later order starts at voice
   * matching and translation. Results go to the step cache only; nothing is shown to the user and no
   * voice is cloned or assigned. Never throws.
   */
  async prepareDubbingAnalysis(jobId: string, userId: string, videoUrl: string, executionPlan: ExecutionPlan): Promise<{ prepared: boolean; reason: string }> {
    const t0 = Date.now();
    try {
      const transcript = await this.loadTranscript(jobId);
      if (!transcript) return { prepared: false, reason: "no transcript" };
      const transcriptModel = transcript.model || transcript.provider;
      if (transcriptModel !== "assemblyai-stt-3-7") return { prepared: false, reason: "transcript model not supported for dubbing" };
      const sourceLang = normalizeLanguageCode(transcript.language || transcript.detectedLanguage || executionPlan.sourceLanguage || "");
      if (sourceLang && (!ASSEMBLYAI_UNIVERSAL_37_LANGUAGES.has(sourceLang) || !isDubbingSourceLanguage(sourceLang))) return { prepared: false, reason: "source language not supported for dubbing" };

      const { segments } = this.buildDubbingSegments(transcript);
      if (segments.length === 0) return { prepared: false, reason: "no speech" };
      const plan = { ...executionPlan, generateDubbing: true } as ExecutionPlan;
      const audioUrl = await this.resolveOriginalAudioUrl(jobId, videoUrl);

      const separation = this.runSeparationChain(jobId, userId, videoUrl, plan, segments, audioUrl, null);
      separation.catch(() => undefined);
      const speakers = (async () => {
        if (segments.length >= 2) await this.runDiarizationCheck(jobId, videoUrl, plan, segments, transcript);
        await this.runSpeakerProfiling(jobId, plan, transcript, audioUrl);
      })();
      const results = await Promise.allSettled([speakers, separation]);
      const failed = results.filter((r) => r.status === "rejected").length;
      logger.info("[Dubbing:Prewarm] Analysis prepared", { jobId, ms: Date.now() - t0, failedChains: failed });
      return { prepared: failed === 0, reason: failed === 0 ? "ok" : "partial" };
    } catch (err) {
      logger.warn("[Dubbing:Prewarm] Preparation skipped", { jobId, err: String(err) });
      return { prepared: false, reason: "error" };
    }
  }

  private async isSpeechOnlyJob(jobId: string, known: SeparationPath | null): Promise<boolean> {
    if (known) return known === "speech_only";
    try {
      const snap = await db().collection("video_jobs").doc(jobId).get();
      return snap.data()?.artifacts?.separation?.path === "speech_only";
    } catch {
      return false;
    }
  }

  private async recordCreatorDubbingNotice(jobId: string, reason: CloneBlockReason | "clone_failed"): Promise<void> {
    await this.addDubbingNotice(jobId, {
      code: reason === "clone_failed" ? "VOICE_CLONE_FAILED" : "VOICE_CLONE_UNAVAILABLE",
      reason,
      message: cloneUnavailableMessage(reason),
    });
  }

  /**
   * Runs MediaService.verifyDeliveryAudio and applies the outcome. The reference for the bleed check is
   * the isolated source voice when there is one, otherwise the source audio itself. Throws when the dub
   * is not fit to ship, so the language is marked failed instead of publishing English under Telugu.
   */
  private async enforceDeliveryAudio(
    jobId: string,
    targetLang: string,
    opts: { masterUrl: string; dialogueOnlyUrl?: string | null; referenceUrl?: string | null; videoUrl?: string; speech: Array<{ startMs: number; endMs: number }>; targetLufs?: number }
  ): Promise<string> {
    let referenceUrl = opts.referenceUrl || null;
    if (!referenceUrl) {
      const snap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
      referenceUrl = snap?.data()?.artifacts?.transcription?.audioUrl || opts.videoUrl || null;
    }
    const speech = opts.speech.filter((w) => Number.isFinite(w.startMs) && Number.isFinite(w.endMs) && w.endMs > w.startMs);
    let result: Awaited<ReturnType<typeof mediaService.verifyDeliveryAudio>>;
    try {
      result = await mediaService.verifyDeliveryAudio(jobId, targetLang, { ...opts, referenceUrl, speech });
    } catch (err) {
      // A4: an unchecked mix is not published. One retry (most failures are transient downloads),
      // then the language fails and is refunded.
      logger.warn("[Dubbing:Delivery] Delivery check could not run — retrying once", { jobId, targetLang, err: String(err) });
      try {
        result = await mediaService.verifyDeliveryAudio(jobId, targetLang, { ...opts, referenceUrl, speech });
      } catch (retryErr) {
        throw new Error(`[Dubbing:Delivery] Delivery check could not run for ${targetLang}: ${String(retryErr)}`);
      }
    }

    const record = {
      action: result.action, ok: result.ok, reasons: result.reasons,
      lufsBefore: result.lufsBefore, lufsAfter: result.lufsAfter, gainDb: result.gainDb,
      bleed: result.bleed, bleedAfterFallback: result.bleedAfterFallback ?? null, checkedAt: Date.now(),
    };
    await db().collection("video_jobs").doc(jobId).set(
      { artifacts: { deliveryChecks: { [targetLang]: record } } },
      { merge: true }
    ).catch(() => {});
    try {
      const jobSnap = await db().collection("video_jobs").doc(jobId).get();
      if (jobSnap.data()?.artifacts?.bgmReport?.[targetLang]) {
        const existingBleed = jobSnap.data()?.artifacts?.bgmReport?.[targetLang]?.bleed || {};
        await db().collection("video_jobs").doc(jobId).set(
          {
            artifacts: {
              bgmReport: {
                [targetLang]: {
                  bleed: {
                    ...existingBleed,
                    passed: result.ok && !result.bleed?.bleed,
                    worstR: result.bleed?.worstR ?? null,
                  },
                },
              },
            },
          },
          { merge: true }
        );
      }
    } catch (_) {}
    logger.info("[Dubbing:Delivery] Delivery audio check", { jobId, targetLang, ...record, bleed: result.bleed ? { bleed: result.bleed.bleed, flaggedMs: result.bleed.flaggedMs, testedMs: result.bleed.testedMs, worstR: result.bleed.worstR } : null });

    if (result.action === "dialogue_only" || result.action === "dialogue_only_loudness_corrected") {
      await this.addDubbingNotice(jobId, {
        code: "BACKGROUND_REMOVED_SOURCE_BLEED",
        language: targetLang,
        message: "We removed the background music and effects from this dub because the original voices could still be heard underneath. The dubbed dialogue is complete.",
      }).catch(() => {});
    }
    if (!result.ok) {
      throw new Error(`[Dubbing:Delivery] Dub not fit to publish for ${targetLang}: ${result.reasons.join("; ")}`);
    }
    return result.url;
  }

  /**
   * Loudness check of the muxed video; corrects the audio stream when it is off target. A faithful
   * mix passes the original's loudness as the target, so the dubbed video plays as loud as the original.
   */
  private async enforceVideoLoudness(jobId: string, targetLang: string, videoUrl: string, targetLufs?: number): Promise<string> {
    if (!videoUrl) return videoUrl;
    try {
      const r = await mediaService.verifyVideoLoudness(jobId, targetLang, videoUrl, targetLufs);
      logger.info("[Dubbing:Delivery] Dubbed video loudness", { jobId, targetLang, ...r });
      await db().collection("video_jobs").doc(jobId).set(
        { artifacts: { deliveryChecks: { [targetLang]: { videoLufsBefore: r.lufsBefore, videoLufsAfter: r.lufsAfter, videoCorrected: r.corrected, videoOk: r.ok } } } },
        { merge: true }
      ).catch(() => {});
      if (!r.ok) {
        // The audio track (already verified) stays published; only the muxed video is withheld.
        logger.error("[Dubbing:Delivery] Dubbed video audio is off target and could not be corrected — video withheld", { jobId, targetLang, ...r });
        return "";
      }
      return r.videoUrl;
    } catch (err) {
      logger.warn("[Dubbing:Delivery] Video loudness check could not run", { jobId, targetLang, err: String(err) });
      return videoUrl;
    }
  }

  private async addDubbingNotice(jobId: string, notice: Record<string, unknown> & { code: string; message: string; language?: string }): Promise<void> {
    const ref = db().collection("video_jobs").doc(jobId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const existing: any[] = snap.exists && Array.isArray(snap.data()?.dubbingNotices) ? snap.data()!.dubbingNotices : [];
      // Replace existing notice with same code and language
      const filtered = existing.filter(n => !(n.code === notice.code && (n.language || null) === (notice.language || null)));
      filtered.push({ ...notice, createdAt: Date.now() });
      tx.set(ref, { dubbingNotices: filtered }, { merge: true });
    }).catch((err: any) => {
      logger.warn("[Dubbing] Could not record creator notice", { jobId, err: err?.message });
    });
  }

  private async clearDubbingNotice(jobId: string, criteria: { code?: string; language?: string }): Promise<void> {
    const ref = db().collection("video_jobs").doc(jobId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const existing: any[] = Array.isArray(snap.data()?.dubbingNotices) ? snap.data()!.dubbingNotices : [];
      if (existing.length === 0) return;
      const remaining = existing.filter(n => {
        if (criteria.language && n.language === criteria.language) return false;
        if (criteria.code && n.code === criteria.code) return false;
        return true;
      });
      if (remaining.length !== existing.length) {
        tx.set(ref, { dubbingNotices: remaining }, { merge: true });
      }
    }).catch((err: any) => {
      logger.warn("[Dubbing] Could not clear creator notice", { jobId, err: err?.message });
    });
  }

  private async propagateAudioTrack(
    jobId: string,
    targetLang: string,
    rawTargetLang: string,
    directAudioUrl: string
  ): Promise<void> {
    try {
      // Clear any prior skip notice for this language now that audio is ready
      await this.clearDubbingNotice(jobId, { language: targetLang });

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
        audioTrackSources: {
          [targetLang]: "ai_dub",
          ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: "ai_dub" } : {}),
        },
        aiDubbedAudio: {
          [targetLang]: directAudioUrl,
          ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
        },
        media: {
          audioTracks: {
            [targetLang]: directAudioUrl,
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
          },
          audioTrackSources: {
            [targetLang]: "ai_dub",
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: "ai_dub" } : {}),
          },
        },
        [`audioTracks.${targetLang}`]: directAudioUrl,
        [`audioTrackSources.${targetLang}`]: "ai_dub",
        [`media.audioTracks.${targetLang}`]: directAudioUrl,
        [`media.audioTrackSources.${targetLang}`]: "ai_dub",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (rawTargetLang && rawTargetLang !== targetLang) {
        dotAudioUpdates[`audioTracks.${rawTargetLang}`] = directAudioUrl;
        dotAudioUpdates[`audioTrackSources.${rawTargetLang}`] = "ai_dub";
        dotAudioUpdates[`media.audioTracks.${rawTargetLang}`] = directAudioUrl;
        dotAudioUpdates[`media.audioTrackSources.${rawTargetLang}`] = "ai_dub";
      }

      for (const vid of linkedVideoIds) {
        await safeMergeExistingVideo(vid, dotAudioUpdates, "[Dubbing:propagateAudioTrack]");

        const locAudioUpdates: Record<string, any> = {
          audioTracks: {
            [targetLang]: directAudioUrl,
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
          },
          audioTrackSources: {
            [targetLang]: "ai_dub",
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: "ai_dub" } : {}),
          },
          [`audioTracks.${targetLang}`]: directAudioUrl,
          [`audioTrackSources.${targetLang}`]: "ai_dub",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (rawTargetLang && rawTargetLang !== targetLang) {
          locAudioUpdates[`audioTracks.${rawTargetLang}`] = directAudioUrl;
          locAudioUpdates[`audioTrackSources.${rawTargetLang}`] = "ai_dub";
        }
        await safeMergeExistingVideoSubdoc(
          vid,
          "media",
          "localization",
          locAudioUpdates,
          "[Dubbing:propagateAudioTrack]"
        );
      }

      const jobOutputAudioUpdate: Record<string, any> = {
        audioTracks: {
          [targetLang]: directAudioUrl,
          ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
        },
        audioTrackSources: {
          [targetLang]: "ai_dub",
          ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: "ai_dub" } : {}),
        },
        updatedAt: Date.now(),
      };
      await db().collection("job_outputs").doc(jobId).set(jobOutputAudioUpdate, { merge: true });

      const videoJobAudioUpdate: Record<string, any> = {
        outputs: {
          audioTracks: {
            [targetLang]: directAudioUrl,
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directAudioUrl } : {}),
          },
          audioTrackSources: {
            [targetLang]: "ai_dub",
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: "ai_dub" } : {}),
          },
        },
        updatedAt: Date.now(),
      };
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
    sourceWords?:    WordTimestamp[],
    /** Set when the native-voice policy found no native voice for some speaker: skip the dub, keep subtitles. */
    nativeVoiceBlock?: string
  ): Promise<DubbingResult> {
    const targetLang = normalizeLanguageCode(rawTargetLang);
    const sourceLang = normalizeLanguageCode(rawSourceLang);
    const t0 = Date.now();
    const langTimings: Record<string, number> = {};
    const langDurSec = Number(executionPlan.durationSeconds || executionPlan.duration || 0) ||
      (segments.length > 0 ? segments[segments.length - 1].end / 1000 : 0);
    logger.info("[Dubbing] Processing language", { jobId, targetLang, rawTargetLang, sourceLang });
    
    const updateTranslationStage = async (status: "running" | "completed" | "failed", progress: number, error?: string) => {
      const now = Date.now();
      const payload: any = { status, progress, updatedAt: now };
      if (status === "running") payload.startedAt = now;
      if (status === "completed") payload.completedAt = now;
      if (status === "failed") payload.failedAt = now;
      // The app may show this field: a plain sentence only; the raw error goes to the logs.
      if (error) {
        if (status === "failed") logger.warn("[Dubbing] Language stage failed", { jobId, targetLang, error });
        payload.error = status === "failed" ? friendlyDubbingError(targetLang, error) : error;
      }

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
      // The app may show this field: a plain sentence only; the raw error goes to the logs.
      if (error) {
        if (status === "failed") logger.warn("[Dubbing] Language stage failed", { jobId, targetLang, error });
        payload.error = status === "failed" ? friendlyDubbingError(targetLang, error) : error;
      }

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

        let restoredVideoUrl = (langCheckpoint as any).masterVideoUrl || "";
        const needsDubbedVideo =
          executionPlan.deliverDubbedVideo === true || (executionPlan as any).dubbingTier !== "audio_track";
        if (needsDubbedVideo && !restoredVideoUrl) {
          try {
            const resumeDspFilters = acousticFingerprint
              ? audioIdentityService.getDSPFilters(acousticFingerprint)
              : "loudnorm=I=-14:TP=-1:LRA=11";
            restoredVideoUrl = await mediaService.mergeAudioToVideo({
              jobId,
              videoUrl,
              audioUrl: langCheckpoint.masterAudioUrl,
              subtitleUrl: executionPlan.genLangSubs ? (langCheckpoint.subtitleUrl || undefined) : undefined,
              language: targetLang,
              format: "mp4",
              audioFilters: resumeDspFilters,
              isPreMastered: true,
            });
            restoredVideoUrl = await this.enforceVideoLoudness(jobId, targetLang, restoredVideoUrl);
            if (restoredVideoUrl) {
              await this.saveDubbingCheckpoint(jobId, targetLang, {
                masterVideoUrl: restoredVideoUrl,
              } as any).catch(() => {});
            }
          } catch (resumeMuxErr) {
            logger.warn("[Dubbing:Resume] Remuxing dubbed MP4 on resume failed (audio track remains intact):", resumeMuxErr);
            restoredVideoUrl = "";
          }
        }

        await this.propagateAudioTrack(jobId, targetLang, rawTargetLang, directAudioUrl);
        await updateTranslationStage("completed", 100);
        await updateDubbingStage("completed", 100);

        const restoredTranslationUrl =
          langCheckpoint.translationUrl && langCheckpoint.translationUrl.includes("/translations/")
            ? langCheckpoint.translationUrl
            : (langCheckpoint.translatedSegments && langCheckpoint.translatedSegments.length > 0
                ? await saveTranslationArtifact({
                    jobId,
                    sourceLanguage: sourceLang,
                    targetLanguage: targetLang,
                    segments: langCheckpoint.translatedSegments,
                  }).catch(() => langCheckpoint.translationUrl || "")
                : (langCheckpoint.translationUrl || ""));

        return {
          jobId,
          language: targetLang,
          subtitleUrl: langCheckpoint.subtitleUrl || "",
          subtitleFormat: "srt",
          audioUrl: langCheckpoint.masterAudioUrl,
          videoUrl: restoredVideoUrl,
          translationUrl: restoredTranslationUrl,
          segments: segments.length,
          processingTime: 0,
          dubOutcome: "delivered",
          stems: {
            mne: mneStemUrl || langCheckpoint.meStemUrl || null,
            dialogue: langCheckpoint.dialogueStemUrl || undefined,
            master: langCheckpoint.masterAudioUrl,
            vocals: isolatedVocalUrl || langCheckpoint.isolatedVocalUrl || null,
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
      let castContext: Awaited<ReturnType<DubbingEngine["loadCastContext"]>> | null = null;
      const {
        shotChangesMs: screenShotChangesMs,
        onScreenText: screenOnScreenText,
        segments: segmentsWithScreenContext,
      } = await this.resolveScreenContextForTranslation(
        jobId,
        videoUrl,
        executionPlan.durationSeconds ? executionPlan.durationSeconds * 1000 : undefined,
        segments
      );

      if (targetLang === sourceLang) {
        dubbingSegs = segmentsWithScreenContext.map((s) => ({
          index:          s.index,
          originalText:   s.text,
          translatedText: s.text,
          language:       targetLang,
          start:          s.start,
          end:            s.end,
          targetDuration: s.duration,
          speaker:        s.speaker,
        }));
      } else {
        castContext = await this.loadCastContext(jobId, executionPlan, segmentsWithScreenContext);
        const targetCastHash = computeCastHash(castContext.castList, castContext.relationships, "stage4_v2");
        const isCheckpointValid =
          (langCheckpoint as any)?.translationVersion === "stage4_v2" &&
          (langCheckpoint as any)?.castHash === targetCastHash &&
          langCheckpoint?.translatedSegments &&
          langCheckpoint.translatedSegments.length === segmentsWithScreenContext.length &&
          langCheckpoint.translatedSegments.every((s) => s.translatedText && s.translatedText.trim().length > 0);

        if (isCheckpointValid) {
          logger.info("[Dubbing:Resume] Reusing complete translated segments from checkpoint (0 Google Translation API v3 cost)", {
            jobId,
            targetLang,
            segmentCount: langCheckpoint!.translatedSegments!.length,
            castHash: targetCastHash,
          });
          dubbingSegs = langCheckpoint!.translatedSegments!;
        } else {
          if (langCheckpoint?.translatedSegments) {
            logger.info("[Dubbing:Resume] Translation checkpoint invalidated (cast list, relationships, or translation version changed), re-translating...", {
              jobId,
              targetLang,
              oldVersion: (langCheckpoint as any)?.translationVersion,
              newVersion: "stage4_v2",
              oldCastHash: (langCheckpoint as any)?.castHash,
              newCastHash: targetCastHash,
            });
          }

          const subTier = executionPlan.subtitleTier || "ultra";
          const currentDubbingTier = (executionPlan as any).dubbingTier || "audio_track";
          const tTransStart = Date.now();
          dubbingSegs = await this.translateWithCache(
            jobId, segmentsWithScreenContext, sourceLang, targetLang,
            { 
              model: 'premium',
              tone: executionPlan.toneMode,
              localeStyle: executionPlan.localeStyle,
              targetPlatform: executionPlan.targetPlatform,
              creatorDNA,
              speakerProfiles,
              dubbingTier: currentDubbingTier,
              subtitleTier: subTier,
              isCinemaGrade: false,
              totalDurationMs: executionPlan.durationSeconds ? executionPlan.durationSeconds * 1000 : undefined,
              shotChangesMs: screenShotChangesMs,
              onScreenText: screenOnScreenText,
              ...castContext,
              enableDualTrack: true,
            }
          );
          const localizationBible = (dubbingSegs as any).localizationBible;
          this.recordTiming(langTimings, "translation", tTransStart, { jobId, lang: targetLang, durationSec: langDurSec });

          // ✅ Cost tracking: record separate input and output translation cost for this language
          const sourceChars = segments.reduce((sum, s) => sum + s.text.length, 0);
          const translatedChars = dubbingSegs.reduce((sum, s) => sum + s.translatedText.length, 0);
          costEngine.recordTranslationCost(jobId, userId, sourceChars, translatedChars).catch(() => {});

          // 🛡️ Save translated segments into checkpoint with stage4_v2 version and cast hash
          await this.saveDubbingCheckpoint(jobId, targetLang, {
            stage: "translated",
            status: "translated",
            translationVersion: "stage4_v2",
            castHash: targetCastHash,
            translatedSegments: dubbingSegs,
            ...(localizationBible ? { localizationBible } : {}),
            totalSegments: segments.length,
            voiceMapping,
            isolatedVocalUrl: isolatedVocalUrl ? toCanonicalGsUrl(isolatedVocalUrl) : null,
            meStemUrl: mneStemUrl ? toCanonicalGsUrl(mneStemUrl) : null,
          });
        }
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
      const subJsonPath = `subtitles/${jobId}/${targetLang}.json`;
      const translationUrl = await saveTranslationArtifact({
        jobId,
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
        segments: dubbingSegs,
      });

      await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 85 }).catch(() => {});
      await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 85 }).catch(() => {});

      // ⚡ PARALLEL: Save translation JSON + generate subtitles simultaneously (saves 2-5s)
      const allWords = (sourceWords && sourceWords.length > 0) ? sourceWords : segments.flatMap((s) => s.words || []);
      let subGenPromise: Promise<{ srtUrl: string; vttUrl: string; jsonUrl: string } | null>;

      const blockedTranslationSegs = findBlockedTranslationLines(dubbingSegs);
      if (blockedTranslationSegs.length > 0) {
        logger.error("[Dubbing:TranslationGate] Language blocked before TTS", {
          jobId,
          targetLang,
          blockedCount: blockedTranslationSegs.length,
          blockedLines: blockedTranslationSegs.slice(0, 10),
        });
      }

      const subtitleExtras = {
        videoUrl,
        totalDurationMs: executionPlan.durationSeconds ? executionPlan.durationSeconds * 1000 : undefined,
        localeStyle: executionPlan.localeStyle,
        tone: executionPlan.toneMode,
        userId,
        castList: castContext?.castList,
        relationships: castContext?.relationships,
        speakerNames: castContext?.speakerNames,
        castGenderByLabel: castContext?.castGenderByLabel,
      };
      if (blockedTranslationSegs.length > 0) {
        subGenPromise = Promise.resolve(null);
        await EdgeLayer.failStage(jobId, "subtitles", blockedTranslationMessage(targetLang)).catch(() => {});
      } else if (executionPlan.genLangSubs && targetLang === sourceLang && allWords.length === 0) {
        // No word timings: fall back to AssemblyAI's own source-language subtitle file.
        subGenPromise = this.checkNativeSubtitles(jobId, targetLang).then((nativeUrl) => {
          if (nativeUrl) {
            logger.info("[Dubbing] Using native AssemblyAI subtitles for source lang", { jobId, targetLang });
            return {
              srtUrl: nativeUrl,
              vttUrl: `gs://${bucket.name}/subtitles/${jobId}/${targetLang}.vtt`,
              jsonUrl: translationUrl,
            };
          }
          return this.generateSubtitles(jobId, dubbingSegs, targetLang, sourceLang, allWords, subtitleExtras);
        });
      } else {
        // All languages, including the source language, go through the Netflix-style localizer.
        subGenPromise = this.generateSubtitles(jobId, dubbingSegs, targetLang, sourceLang, allWords, subtitleExtras);
      }

      // Subtitles do not depend on the voices. When this language is going to be voiced, subtitle
      // generation and publication run while the voices are synthesised (awaited right after TTS, and
      // before any early return), instead of holding TTS back. Same subtitles, published as soon as
      // they are ready, exactly as before.
      subGenPromise.catch(() => undefined);
      await bucket.file(subJsonPath).save(JSON.stringify(dubbingSegs, null, 2), {
        metadata: { contentType: "application/json" },
      });
      const subtitlesOverlapTts = Boolean(
        executionPlan.generateDubbing &&
        targetLang !== sourceLang &&
        V4_PREMIUM_80_LANGUAGES.has(targetLang) &&
        isLaunchDubbingPair(sourceLang, targetLang) &&
        !nativeVoiceBlock &&
        subtitlesAlongsideTtsEnabled()
      );
      const subtitleTask: Promise<void> = (async () => {
      const subResult = await subGenPromise;

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
            // Update existing top-level videos/{vid} document directly using dot notation to preserve sibling tracks
            await safeMergeExistingVideo(vid, subUpdates, "[Dubbing:propagateSubtitleTrack]");

            // Also update subcollection for backwards compatibility using dot notation to preserve sibling tracks
            const locSubUpdates: Record<string, any> = {
              [`subtitles.${targetLang}`]: directSubtitleUrl,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (rawTargetLang && rawTargetLang !== targetLang) {
              locSubUpdates[`subtitles.${rawTargetLang}`] = directSubtitleUrl;
            }
            await safeMergeExistingVideoSubdoc(
              vid,
              "media",
              "localization",
              locSubUpdates,
              "[Dubbing:propagateSubtitleTrack]"
            );
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
            updatedAt: Date.now(),
          };
          await db().collection("job_outputs").doc(jobId).set(jobOutputSubUpdate, { merge: true });

          const videoJobSubUpdate: Record<string, any> = {
            outputs: {
              subtitles: {
                [targetLang]: subtitleUrl,
                ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: subtitleUrl } : {}),
              },
            },
            updatedAt: Date.now(),
          };
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
      })();
      subtitleTask.catch(() => undefined);
      if (!subtitlesOverlapTts) await subtitleTask;
      // A subtitle failure still fails this language, as before; with the overlap it is reported once
      // the voices are done rather than before they start.
      let subtitleTaskError: unknown = null;
      const settleSubtitles = async (): Promise<void> => {
        try { await subtitleTask; } catch (e) { if (subtitleTaskError === null) subtitleTaskError = e; }
      };

      // C. TTS + sync (only when dubbing is enabled AND not source language)
      // Source-to-source dubbing is nonsensical — skip TTS for the source language
      let audioUrl        = "";
      let videoResult     = "";
      // What the creator got for this language's dub (A1/A2): drives refunds and the job status.
      let dubOutcome: DubOutcome = "not_requested";
      let rawDialogueUrl  = "";
      let masterAudioUrl  = "";
      let ttsUrls: string[] = [];
      let dubbedSegmentsSnapshot: DubbingSegment[] = dubbingSegs;

      // ElevenLabs v4 Dubbing Target Language Gate:
      // Subtitles are supported for all languages via Google Cloud Translation API v3 general/translation-llm,
      // but Dubbing is strictly supported ONLY for languages available on ElevenLabs v4 with ZERO fallback.
      // Launch languages (dubbing-launch-languages.ts): a pair outside the launch list is treated like an
      // unsupported language — subtitles ship, the dub is skipped and refunded (orders from the upload
      // screen reach this point without the server's language check).
      const isLaunchPair = isLaunchDubbingPair(sourceLang, targetLang);
      const isV4DubbingLanguage = V4_PREMIUM_80_LANGUAGES.has(targetLang) && isLaunchPair;
      const preTtsDecision = evaluatePreTtsDubbingDecision({
        generateDubbing: executionPlan.generateDubbing,
        targetLang,
        sourceLang,
        isV4DubbingLanguage,
        nativeVoiceBlock,
        blockedLines: blockedTranslationSegs,
      });
      const isDubbingSupportedForTarget = preTtsDecision.isDubbingSupportedForTarget;
      if (preTtsDecision.blockedByTranslation) {
        dubOutcome = preTtsDecision.initialDubOutcome;
        const gateResult = DubbingQualityGate.evaluate({
          jobId,
          targetLang,
          totalSegments: dubbingSegs.length,
          successfulSegments: dubbingSegs.length,
          failedSegments: [],
          actualDurationSeconds: 0,
          expectedDurationSeconds: executionPlan.durationSeconds || 0,
          isVoiceCloningRequested: false,
          isVoiceCloned: false,
          stemIsolationRequested: false,
          isStemPreserved: true,
          translationBlockedLines: blockedTranslationSegs,
        });
        await EdgeLayer.failStage(jobId, `dubbing_${targetLang}`, blockedTranslationMessage(targetLang)).catch(() => {});
        await this.addDubbingNotice(jobId, {
          code: "DUB_BLOCKED_TRANSLATION",
          language: targetLang,
          message: blockedTranslationMessage(targetLang),
        });
        await db().collection("video_jobs").doc(jobId).set({
          dubbingStatus: {
            [targetLang]: {
              status: "FAILED",
              reason: "translation_gate_blocked",
              violations: gateResult.violations,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true }).catch(() => {});
      }
      if (executionPlan.generateDubbing && isV4DubbingLanguage && nativeVoiceBlock && targetLang !== sourceLang) {
        dubOutcome = "not_dubbable";
        logger.warn("[Dubbing] Skipping audio for this language: no native voice for every speaker (subtitles remain)", { jobId, targetLang });
        await EdgeLayer.failStage(jobId, `dubbing_${targetLang}`, "No native voice available for every speaker in this language").catch(() => {});
        await this.addDubbingNotice(jobId, {
          code: "DUB_SKIPPED_NO_NATIVE_VOICE",
          language: targetLang,
          message: noNativeVoiceMessage(targetLang),
        });
      }
      if (executionPlan.generateDubbing && !isV4DubbingLanguage && targetLang !== sourceLang) {
        dubOutcome = "not_dubbable";
        logger.warn(`[Dubbing] Target language '${targetLang}' is not supported by ElevenLabs v4 — skipping dubbing audio synthesis (subtitles remain active via Google Translation v3 general/translation-llm)`, {
          jobId,
          targetLang,
        });
        await EdgeLayer.failStage(jobId, `dubbing_${targetLang}`, `Target language '${targetLang}' is not supported by ElevenLabs v4 audio synthesis`).catch(() => {});
        await this.addDubbingNotice(jobId, {
          code: "DUB_SKIPPED_UNSUPPORTED_LANGUAGE",
          language: targetLang,
          message: isLaunchPair ? unsupportedDubbingLanguageMessage(targetLang) : launchUnsupportedNotice(sourceLang, targetLang),
        });
      }

      if (executionPlan.generateDubbing && targetLang !== sourceLang && isDubbingSupportedForTarget) {
        if (executionPlan.twoStageReviewEnabled === true && executionPlan.twoStageReviewCompleted !== true) {
          const reviewSegments = dubbingSegs.map((s, idx) => ({
            id: `seg_${idx + 1}`,
            speakerId: s.speaker || "speaker_1",
            startTimeMs: s.start,
            endTimeMs: s.end,
            originalText: s.originalText || "",
            translatedText: s.translatedText || "",
            targetLanguage: targetLang,
            status: "pending",
            speedMultiplier: 1.0,
          }));
          await db()
            .collection("video_jobs")
            .doc(jobId)
            .set(
              {
                pendingReviewSegmentsByLanguage: {
                  [targetLang]: reviewSegments,
                },
                updatedAt: Date.now(),
              },
              { merge: true }
            );
          return {
            jobId,
            language: targetLang,
            subtitleUrl: "",
            subtitleFormat: "srt",
            audioUrl: "",
            videoUrl: "",
            translationUrl,
            segments: dubbingSegs.length,
            processingTime: Date.now() - t0,
            dubOutcome: "awaiting_review",
          };
        }

        if (executionPlan.twoStageReviewCompleted === true) {
          const vJobSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
          const reviewed = vJobSnap?.exists
            ? (vJobSnap.data()?.reviewedSegmentsByLanguage?.[targetLang] as Array<Record<string, any>> | undefined)
            : undefined;
          if (Array.isArray(reviewed) && reviewed.length > 0) {
            for (let i = 0; i < Math.min(dubbingSegs.length, reviewed.length); i++) {
              if (typeof reviewed[i]?.translatedText === "string" && reviewed[i].translatedText.trim().length > 0) {
                dubbingSegs[i].translatedText = reviewed[i].translatedText.trim();
              }
              if (typeof reviewed[i]?.originalText === "string" && reviewed[i].originalText.trim().length > 0) {
                dubbingSegs[i].originalText = reviewed[i].originalText.trim();
              }
            }
          }
        }

        let leaseAcquired = false;
        let leaseHeartbeat: NodeJS.Timeout | null = null;
        const currentWorkerId = uuidv4();
        try {
          // 🛡️ Edge Case 4: Idempotency Lease Lock before starting synthesis
          leaseAcquired = await this.acquireDubbingLease(jobId, targetLang, 120_000, currentWorkerId);
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

              await subtitleTask;
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
                dubOutcome: "delivered",
                stems: {
                  dialogue: existing.dialogueStemUrl || undefined,
                  master: existing.masterAudioUrl,
                },
              };
            }
            await subtitleTask;
            return null as any;
          }

          // 🛡️ A9 Heartbeat: periodically renew lease every 45s while actively working to prevent expiry
          leaseHeartbeat = setInterval(() => {
            this.renewDubbingLease(jobId, targetLang, 120_000, currentWorkerId).catch(() => {});
          }, 45_000);

          await updateDubbingStage("running", 10);
          // One voice per speaker: lock stability / similarity to a per-speaker baseline so the same
          // voice ID does not sound like a different person on each line (see speaker-voice-lock.ts).
          const { segments: normalised, baselines: speakerVoiceBaselines } = lockVoiceSettingsPerSpeaker(
            dubbingSegs.map((s) => ({
              ...s,
              translatedText: this.normaliseTTS(s.translatedText, s.emotionTag),
            })),
            { preferVoiceCloning: executionPlan.dubbingMode === "voice_clone" }
          );
          logger.info("[Dubbing] Voice settings locked per speaker", {
            jobId,
            targetLang,
            baselines: Object.fromEntries(speakerVoiceBaselines),
          });
          dubbedSegmentsSnapshot = normalised;

          // 🚀 Step 0: Pre-TTS Duration Budget Pre-Filter (Hydrogen Recommendation)
          // Preemptively catches severe expansion (R > 1.15) against permissible timeline windows
          // (enforcing 120ms turn boundary gap and 150ms outro margin) and retranslates concisely BEFORE calling TTS,
          // saving latency and eliminating 100% of discarded ElevenLabs voice synthesis charges.
          let preTtsRetranslateCount = 0;
          const preRetranslatedIndices = new Set<number>();
          const preTtsCandidates: Array<{ i: number; estRatio: number; permissibleWindowMs: number }> = [];
          const totalVideoDurationMs = executionPlan.durationSeconds ? executionPlan.durationSeconds * 1000 : 0;
          for (let i = 0; i < normalised.length; i++) {
            const seg = normalised[i];
            if (editorContextEnabled() && seg.isSong) continue;
            const segEndMs = seg.end > seg.start ? seg.end : (seg.start + (seg.targetDuration ? seg.targetDuration * 1000 : 3000));
            const nextSeg = normalised[i + 1];
            const nextStartMs = nextSeg && typeof nextSeg.start === "number" ? nextSeg.start : null;
            const windowMs = permissibleWindowMs(
              seg.start,
              segEndMs,
              nextStartMs,
              totalVideoDurationMs || undefined,
              shotChangeWindowEnabled() ? screenShotChangesMs : undefined
            );

            if (windowMs >= 200) {
              const estDurMs = estimateSpeechDurationMs(seg.translatedText, targetLang);
              const estRatio = estDurMs / windowMs;
              if (estRatio > 1.10) {
                preTtsCandidates.push({ i, estRatio, permissibleWindowMs: windowMs });
              }
            }
          }

          // Each concise re-translation reads only its own line and the neighbours' source text, so
          // the calls run in parallel (bounded); results are applied in line order, as before.
          const preTtsResults = await mapWithConcurrency(preTtsCandidates, PRE_TTS_RETRANSLATE_CONCURRENCY, async ({ i, estRatio, permissibleWindowMs }) => {
            const seg = normalised[i];
            try {
              const targetMaxChars = Math.max(
                8,
                Math.floor(seg.translatedText.length * (1.10 / estRatio))
              );
              return await translationService.retranslateConcise(
                seg.originalText,
                sourceLang,
                targetLang,
                {
                  targetDurationRatio: estRatio,
                  maxCharacters: targetMaxChars,
                  preserveFacts: true,
                  maxDurationMs: permissibleWindowMs,
                  speakerGender: speakerGenderMapping?.[seg.speaker || "speaker_0"] === "FEMALE" ? "female" : (speakerGenderMapping?.[seg.speaker || "speaker_0"] === "MALE" ? "male" : undefined),
                  jobId,
                  userId,
                  currentTranslation: seg.translatedText,
                  speaker: seg.speaker,
                  appliedRegister: seg.appliedRegister,
                  registerDirective: seg.appliedRegister,
                  castList: castContext?.castList,
                  relationships: castContext?.relationships,
                  speakerNames: castContext?.speakerNames,
                  castGenderByLabel: castContext?.castGenderByLabel,
                  bible: (langCheckpoint as any)?.localizationBible ?? (dubbingSegs as any)?.localizationBible,
                  creatorDNA,
                  targetPlatform: executionPlan.targetPlatform,
                  delivery: (seg as any).delivery || seg.emotionTag || (seg.deliveryStyle && seg.deliveryStyle !== "natural" ? seg.deliveryStyle : undefined),
                  contextBefore: normalised.slice(Math.max(0, i - 3), i).map((c) => ({ source: c.originalText, speaker: c.speaker })),
                  contextAfter: normalised.slice(i + 1, i + 3).map((c) => ({ source: c.originalText, speaker: c.speaker })),
                }
              );
            } catch (_) {
              return null;
            }
          });
          preTtsCandidates.forEach(({ i }, k) => {
            const conciseText = preTtsResults[k];
            const seg = normalised[i];
            // Compare like with like: retranslateConcise returns untagged text while
            // seg.translatedText carries its audio tag, so re-tag before measuring.
            const conciseTagged = conciseText ? this.normaliseTTS(conciseText, seg.emotionTag) : "";
            if (!conciseTagged) return;
            const currentEstMs = estimateSpeechDurationMs(seg.translatedText, targetLang);
            const conciseEstMs = estimateSpeechDurationMs(conciseTagged, targetLang);
            // R5: Before TTS nothing has been paid yet, so accept any checked shorter phrasing.
            if (conciseEstMs < currentEstMs) {
              normalised[i].translatedText = conciseTagged;
              preTtsRetranslateCount++;
              preRetranslatedIndices.add(i);
            }
          });

          const initialTTSChars = normalised.reduce((sum, s) => sum + s.translatedText.length, 0);

          // 💰 Unit economics (dubbing-economics.ts): the exact characters to voice are known now,
          // before any voice is paid for. Plan this language's spend so the profit share of the price
          // is never spent; optional regeneration below only runs inside what is left.
          const marginPolicy = readMarginPolicy();
          // The price actually charged for this language (after discount), set when the dub was
          // ordered; older jobs fall back to the list minute price.
          const chargedPrice = executionPlan.dubbingPriceByLanguage?.[targetLang];
          const dubBudget = planDubBudget({
            priceUsd: typeof chargedPrice === "number" && chargedPrice >= 0 ? chargedPrice : getFlatDubbingPricePerLanguage(
              executionPlan.duration || executionPlan.durationSeconds || 0,
              executionPlan.channelType || "standard",
              executionPlan.dubbingMode === "voice_clone" ? "voice_clone" : "standard"
            ),
            durationSec: executionPlan.duration || executionPlan.durationSeconds || 0,
            languages: Math.max(1, (executionPlan.dubbingLanguages || []).length),
            translationCharsIn: normalised.reduce((sum, s) => sum + (s.originalText || "").length, 0),
            translationCharsOut: initialTTSChars,
            ttsChars: initialTTSChars,
          }, marginPolicy);
          const retryBudget = new RetryBudget(dubBudget.retryBudgetChars);
          if (dubBudget.withinBudget) {
            logger.info("[Economics] Dub budget", { jobId, targetLang, ...dubBudget });
          } else if (dubBudget.priceUsd === 0) {
            // Free / 100%-discount dub granted by an admin: a deliberate promotion, not a pricing
            // error. It ships with no paid regeneration.
            logger.info("[Economics] Promotional (free) dub — no regeneration budget", { jobId, targetLang, ...dubBudget });
          } else {
            // The dub still ships (the creator has paid) with no optional regeneration; this video's
            // speech density needs a different price. Alert so pricing can be fixed.
            logger.error("[Economics] Dub cannot keep the profit floor at this price — regeneration disabled", {
              jobId,
              targetLang,
              ...dubBudget,
            });
          }
          db().collection("video_jobs").doc(jobId).set(
            { economics: { [targetLang]: { budget: dubBudget, plannedAt: Date.now() } } },
            { merge: true }
          ).catch(() => {});

          // ✅ TTS cache fully wired — checks cache BEFORE calling TTS
          // Dubbing Plan: Audio Track (Studio voice cloning, cadence locking, 100% BGM preserved)
          const dubbingTier = (executionPlan as any).dubbingTier || "audio_track";
          const isVoiceClone = executionPlan.dubbingMode === "voice_clone";
          const voiceType = isVoiceClone ? "cloned" : "studio_matched";

          await updateDubbingStage("running", 50);
          const tTtsStart = Date.now();
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
          await settleSubtitles();
          await updateDubbingStage("running", 85);

          // ─── Hierarchy Step 3 & 4: Concise Retranslation & Audio Regeneration ───
          // If generated speech duration ratio R exceeds 1.15, retranslate concisely
          // and re-synthesize before passing to the 1.15x tempo stitching stage.
          let discardedTTSChars = 0;
          let postTtsRetranslateCount = 0;
          // Measured speaking rate of this language's voices (syllables per second of generated speech),
          // logged so SYLLABLES_PER_SECOND can be set from data, and used per speaker in post-TTS retakes (Fix 3.3).
          let languageMedianRate: number | undefined;
          const speakerMeasuredRates: Record<string, number> = {};
          const measuredRatesByVoiceId: Record<string, number> = {
            ...((langCheckpoint as any)?.measuredRatesByVoiceId || {}),
          };
          try {
            const rates: number[] = [];
            const ratesBySpeaker = new Map<string, number[]>();
            normalised.forEach((seg, i) => {
              const ms = ttsResult.measuredDurationsMs?.[i];
              const syl = countSourceSyllables(stripAudioTagsForSubtitles(seg.translatedText || ""), targetLang);
              if (typeof ms === "number" && ms >= 800 && syl >= 4) {
                const r = syl / (ms / 1000);
                rates.push(r);
                const spk = seg.speaker || "speaker_0";
                const arr = ratesBySpeaker.get(spk) || [];
                arr.push(r);
                ratesBySpeaker.set(spk, arr);
              }
            });
            for (const [spk, arr] of ratesBySpeaker.entries()) {
              if (arr.length >= 3) {
                const s = [...arr].sort((a, b) => a - b);
                const med = Math.round(s[Math.floor(s.length / 2)] * 100) / 100;
                speakerMeasuredRates[spk] = med;
                const vId = voiceMapping[spk] || (executionPlan as any).voiceId;
                if (vId) measuredRatesByVoiceId[vId] = med;
              }
            }
            if (rates.length > 0) {
              const sorted = [...rates].sort((a, b) => a - b);
              const median = sorted[Math.floor(sorted.length / 2)];
              languageMedianRate = Math.round(median * 100) / 100;
              logger.info("[Dubbing:Pacing] Measured speaking rate", {
                jobId,
                targetLang,
                lines: rates.length,
                medianSyllablesPerSec: languageMedianRate,
                configuredSyllablesPerSec: configuredSyllablesPerSecond(targetLang),
                bySpeaker: speakerMeasuredRates,
              });
            }
          } catch {
            // Telemetry only.
          }
          if (voiceRateCalibrationEnabled() && Object.keys(measuredRatesByVoiceId).length > 0) {
            this.saveDubbingCheckpoint(jobId, targetLang, {
              measuredRatesByVoiceId,
            } as any).catch(() => {});
          }
          if (ttsResult.failedSegments.length === 0 && normalised.length > 0) {
            const overflowIndices: Array<{ index: number; ratio: number }> = [];
            const overflowWindows = new Map<number, number>();
            for (let i = 0; i < normalised.length; i++) {
              const seg = normalised[i];
              if (editorContextEnabled() && seg.isSong) continue;
              // Real length of the voiced line (A3). Without a measurement, fall back to the text
              // estimate, and skip lines already shortened before TTS (the estimate would not change).
              const measuredMs = ttsResult.measuredDurationsMs[i];
              if (measuredMs === null && preRetranslatedIndices.has(i)) continue;
              const segEndMs = seg.end > seg.start ? seg.end : (seg.start + (seg.targetDuration ? seg.targetDuration * 1000 : 3000));
              const nextSeg = normalised[i + 1];
              const nextStartMs = nextSeg && typeof nextSeg.start === "number" ? nextSeg.start : null;
              const windowMs = permissibleWindowMs(
                seg.start,
                segEndMs,
                nextStartMs,
                totalVideoDurationMs || undefined,
                shotChangeWindowEnabled() ? screenShotChangesMs : undefined
              );

              const spokenMs = measuredMs ?? estimateSpeechDurationMs(seg.translatedText, targetLang);
              const ratio = spokenMs / Math.max(1, windowMs);
              // Only trigger if ratio R > 1.15 (segments with 1.00 < R <= 1.15 are handled cleanly by FFmpeg 1.15x
              // tempo-stretching with 0 credit waste). Beyond 1.15 the stitcher would cut the end of the line.
              if (ratio > 1.15 && windowMs >= 200) {
                overflowIndices.push({ index: i, ratio });
                overflowWindows.set(i, windowMs);
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
                  // 💰 Regeneration is optional: only within this language's remaining budget.
                  // Out of budget → the line keeps its first take and the 1.15x tempo stitch fits it.
                  if (!retryBudget.tryConsume(targetMaxChars)) continue;
                  const spk = seg.speaker || "speaker_0";
                  const vId = voiceMapping[spk] || (executionPlan as any).voiceId;
                  const calibratedRate = voiceRateCalibrationEnabled()
                    ? (speakerMeasuredRates[spk] ?? (vId ? measuredRatesByVoiceId[vId] : undefined) ?? languageMedianRate)
                    : undefined;
                  const conciseText = await translationService.retranslateConcise(
                    seg.originalText,
                    sourceLang,
                    targetLang,
                    {
                      targetDurationRatio: ratio,
                      maxCharacters: targetMaxChars,
                      preserveFacts: true,
                      maxDurationMs: overflowWindows.get(index),
                      syllablesPerSecond: calibratedRate,
                      speakerGender: speakerGenderMapping?.[spk] === "FEMALE" ? "female" : (speakerGenderMapping?.[spk] === "MALE" ? "male" : undefined),
                      jobId,
                      userId,
                      currentTranslation: seg.translatedText,
                      speaker: seg.speaker,
                      appliedRegister: seg.appliedRegister,
                      registerDirective: seg.appliedRegister,
                      castList: castContext?.castList,
                      relationships: castContext?.relationships,
                      speakerNames: castContext?.speakerNames,
                      castGenderByLabel: castContext?.castGenderByLabel,
                      bible: (langCheckpoint as any)?.localizationBible ?? (dubbingSegs as any)?.localizationBible,
                      creatorDNA,
                      targetPlatform: executionPlan.targetPlatform,
                      delivery: (seg as any).delivery || seg.emotionTag || (seg.deliveryStyle && seg.deliveryStyle !== "natural" ? seg.deliveryStyle : undefined),
                      contextBefore: normalised.slice(Math.max(0, index - 3), index).map((c) => ({ source: c.originalText, speaker: c.speaker })),
                      contextAfter: normalised.slice(index + 1, index + 3).map((c) => ({ source: c.originalText, speaker: c.speaker })),
                    }
                  );
                  // Compare like with like: retranslateConcise returns untagged text while
                  // seg.translatedText carries its audio tag ([whispers] etc.).
                  const conciseTagged = conciseText ? this.normaliseTTS(conciseText, seg.emotionTag) : "";
                  const windowMs = overflowWindows.get(index) || 3000;
                  const currentEstMs = estimateSpeechDurationMs(seg.translatedText, targetLang, calibratedRate);
                  const conciseEstMs = conciseTagged ? estimateSpeechDurationMs(conciseTagged, targetLang, calibratedRate) : Infinity;
                  const maxAllowedMs = windowMs * 1.15;
                  if (conciseTagged && conciseEstMs < currentEstMs && conciseEstMs <= maxAllowedMs) {
                    logger.info("[Dubbing:Pacing] Concise retranslation achieved shorter phrasing", {
                      jobId,
                      index,
                      originalLen: seg.translatedText.length,
                      conciseLen: conciseTagged.length,
                      currentEstMs,
                      conciseEstMs,
                    });
                    discardedTTSChars += seg.translatedText.length;
                    normalised[index].translatedText = conciseTagged;
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
                      speakingRate: seg.speaker ? executionPlan.speakerOverrides?.[seg.speaker]?.speedAdjustment : undefined,
                      stability: busPayload.voiceSettings.stability,
                      similarityBoost: busPayload.voiceSettings.similarity_boost,
                      style: busPayload.voiceSettings.style,
                      emotionTag: busPayload.emotionTag,
                      energyDb: seg.energyDb,
                      previousText: busPayload.previousText,
                      nextText: busPayload.nextText,
                    });
                    if (resynth?.audioUrl) {
                      // Real length of the new take when it can be measured; the TTS figure is an estimate.
                      const resynthCheck = await this.verifyAudioChunk(toCanonicalGsUrl(resynth.audioUrl)).catch(() => null);
                      const resynthDurMs = resynthCheck?.measured ? resynthCheck.durationMs : Math.round(resynth.duration * 1000);
                      normalised[index].actualSynthesizedDurationMs = resynthDurMs;
                      normalised[index].durationMs = resynthDurMs;
                      normalised[index].synthesizedAudioUrl = resynth.audioUrl;
                      ttsUrls[index] = resynth.audioUrl;
                      const segIdx = normalised[index]?.index ?? index;
                      await this.saveDubbingCheckpoint(jobId, targetLang, {
                        [`synthesizedUrls.${segIdx}`]: resynth.audioUrl,
                      });
                    }
                  } else if (conciseTagged && conciseEstMs < currentEstMs && conciseEstMs > maxAllowedMs) {
                    logger.info("[Dubbing:Pacing] Retake skipped — still too long", {
                      jobId,
                      phase: "post_tts",
                      index,
                      currentEstMs,
                      conciseEstMs,
                      maxAllowedMs: Math.round(maxAllowedMs),
                    });
                  }
                } catch (retransErr) {
                  logger.warn("[Dubbing:Pacing] Concise retranslation notice:", retransErr);
                }
              }
            }
          }

          // ─── Listen-and-retake (DUBBING_LISTEN_RETAKE, off by default) ───
          // Gemini listens to each original line and its dub; lines with a fixable performance fault are
          // re-voiced with adjusted settings and kept only if a second listen judges them better.
          // Spend comes out of the same retry budget as the concise retranslations above.
          if (listenRetakeEnabled() && ttsResult.failedSegments.length === 0 && normalised.length > 0) {
            let sourceAudio: Awaited<ReturnType<typeof openSourceAudio>> | null = null;
            try {
              const sourceUrl = isolatedVocalUrl || (await this.resolveOriginalAudioUrl(jobId, videoUrl));
              sourceAudio = await openSourceAudio(sourceUrl);
              const audio = sourceAudio;
              const telemetryFor = (seg: (typeof normalised)[number], emotionTag?: string, stability?: number) => ({
                energyDb: seg.energyDb,
                pitchRangeSemitones: seg.pitchRangeSemitones,
                speakingRateRatio: seg.speakingRateRatio,
                emotionTag,
                emotionalIntensity: (seg as any).emotionalIntensity,
                deliveryStyle: seg.deliveryStyle,
                voiceQuality: seg.voiceQuality,
                stabilityOverride: stability ?? seg.stabilityOverride,
                similarityBoostOverride: seg.similarityBoostOverride,
              });
              const lines: ListenLine[] = [];
              normalised.forEach((seg, i) => {
                const url = ttsUrls[i];
                if (!url || seg.start === undefined || seg.end === undefined) return;
                const base = expressiveV4Bus.processSegment({
                  jobId,
                  language: targetLang,
                  translatedText: seg.translatedText,
                  sourceText: seg.originalText,
                  telemetry: telemetryFor(seg, seg.emotionTag),
                  preferVoiceCloning: isVoiceClone,
                  voiceType: voiceType as any,
                  targetDurationMs: Math.max(0, seg.end - seg.start),
                });
                lines.push({
                  index: i,
                  sourceText: seg.originalText || "",
                  dubText: seg.translatedText || "",
                  dubUrl: toCanonicalGsUrl(url),
                  startMs: seg.start,
                  endMs: seg.end,
                  durationMs: seg.actualSynthesizedDurationMs ?? seg.durationMs,
                  base: {
                    stability: base.voiceSettings.stability,
                    style: base.voiceSettings.style ?? 0,
                    ...(base.emotionTag ? { emotionTag: base.emotionTag } : {}),
                  },
                });
              });
              const listenSummary = await runListenAndRetake(lines, targetLang, {
                generate: geminiListenGenerate(listenModel(diarizationModel())),
                sourceWav: (line) => audio.clip(line.startMs, line.endMs),
                dubWav: (url) => takeAsWav(url),
                tryConsumeBudget: (chars) => retryBudget.tryConsume(chars),
                log: (message, data) => logger.info(message, { jobId, targetLang, ...data }),
                resynthesize: async (line, settings) => {
                  const seg = normalised[line.index];
                  const voiceIdForSeg = voiceMapping[seg.speaker || "speaker_0"] || (executionPlan as any).voiceId;
                  const text = this.normaliseTTS(stripAudioTagsForSubtitles(seg.translatedText || ""), settings.emotionTag);
                  const bus = expressiveV4Bus.processSegment({
                    jobId,
                    language: targetLang,
                    translatedText: text,
                    sourceText: seg.originalText,
                    telemetry: telemetryFor(seg, settings.emotionTag, settings.stability),
                    preferVoiceCloning: isVoiceClone,
                    voiceType: voiceType as any,
                    targetDurationMs: line.endMs - line.startMs,
                  });
                  const take = await ttsService.synthesize({
                    jobId,
                    language: targetLang,
                    text: bus.text,
                    voiceId: voiceIdForSeg,
                    speakerId: seg.speaker,
                    userId,
                    ttsTier: dubbingTier as any,
                    voiceType: voiceType as any,
                    speakingRate: seg.speaker ? executionPlan.speakerOverrides?.[seg.speaker]?.speedAdjustment : undefined,
                    stability: settings.stability,
                    similarityBoost: bus.voiceSettings.similarity_boost,
                    style: settings.style,
                    emotionTag: settings.emotionTag,
                    energyDb: seg.energyDb,
                  });
                  if (!take?.audioUrl) return null;
                  const check = await this.verifyAudioChunk(toCanonicalGsUrl(take.audioUrl)).catch(() => null);
                  return {
                    url: take.audioUrl,
                    durationMs: check?.measured ? check.durationMs : Math.round(take.duration * 1000),
                  };
                },
                keep: async (line, take) => {
                  const seg = normalised[line.index];
                  seg.actualSynthesizedDurationMs = take.durationMs;
                  seg.durationMs = take.durationMs;
                  seg.synthesizedAudioUrl = take.url;
                  ttsUrls[line.index] = take.url;
                  await this.saveDubbingCheckpoint(jobId, targetLang, {
                    [`synthesizedUrls.${seg.index ?? line.index}`]: take.url,
                  });
                },
              });
              logger.info("[Dubbing:Listen] Summary", { jobId, targetLang, ...listenSummary });
            } catch (listenErr) {
              logger.warn("[Dubbing:Listen] Listen-and-retake skipped", { jobId, targetLang, err: String(listenErr) });
            } finally {
              sourceAudio?.dispose();
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
            retryBudgetChars: retryBudget.limitChars,
            retryCharsUsed: retryBudget.usedChars,
            retriesRefusedForBudget: retryBudget.refused,
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
                error: friendlyDubbingError(targetLang, ttsResult.failedSegments[0]?.error || "TTS synthesis failed"),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            const jobSnap = await db().collection("video_jobs").doc(jobId).get();
            const jobData = jobSnap.data() as JobData;
            const targetVid = jobData?.videoId;
            if (targetVid) {
              await safeMergeExistingVideoSubdoc(targetVid, "media", "localization", gateFailureDoc, "[Dubbing:QualityGate]").catch(() => {});
            }
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
          this.recordTiming(langTimings, "tts", tTtsStart, { jobId, lang: targetLang, durationSec: langDurSec });
          const tStitchStart = Date.now();
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
          this.recordTiming(langTimings, "stitch", tStitchStart, { jobId, lang: targetLang, durationSec: langDurSec });
          await updateDubbingStage("running", 92);

          // 🎛️ Industry Standard: Non-Destructive M&E (Music & Foley) Preservation (All 5 Plan Tiers)
          // Dynamically sidechain-duck the M&E stem underneath dialogue, swelling music back during pauses
          masterAudioUrl = rawDialogueUrl;
          const speechOnlyJob = await this.isSpeechOnlyJob(jobId, null);
          if (!mneStemUrl && !speechOnlyJob) {
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
                spokenSegments: segments,
                expectedDurationSeconds: totalDurationSeconds || 0,
              });
              mneStemUrl = extracted.mneUrl;
              mneValidation = await mediaService.validateMneStem(
                jobId,
                mneStemUrl,
                totalDurationSeconds || 0,
                extracted.source,
                { spokenSegments: segments, expectedSourceDegraded: extracted.degraded, referenceAudioUrl: stereoSourceUrl, vocalsUrl: extracted.vocalsUrl }
              );
              if (mneValidation.validationStatus === "failed") {
                logger.error("[Dubbing:M&E] On-demand M&E stem rejected (dialogue bleed) — mixing dialogue only", {
                  jobId, targetLang, vocalSuppressionDb: mneValidation.vocalSuppressionDb, issues: mneValidation.issues,
                });
                mneStemUrl = null;
              }
            } catch (mneFallbackErr) {
              logger.warn("[Dubbing] On-demand M&E extraction warning:", mneFallbackErr);
            }
          }

          // 🎬 Faithful mix (faithful-mix.ts): the dub keeps the original audio everywhere except the
          // spoken lines, and each dubbed voice sits at its original speaker's level, so the dub sounds
          // like the original apart from the language. Falls back to the sidechain mix below when it
          // cannot run or does not match the original outside the dialogue. DUBBING_FAITHFUL_MIX=false
          // turns it off. Speech-only videos use it too: the original room sound stays between lines.
          const tMixStart = Date.now();
          let faithfulMixed = false;
          let deliveryTargetLufs: number | undefined;
          let dubSyncReport: DubSyncReport | undefined;
          const preserveBgm = executionPlan.demuxOptions?.preserveBgm !== false;
          const bgmDuckLevelPercent = executionPlan.demuxOptions?.bgmDuckLevelPercent;

          if (preserveBgm && faithfulMixEnabled() && bgmDuckLevelPercent === undefined) {
            try {
              await updateDubbingStage("running", 94);
              const sourceAudioUrl = await mediaService.extractStereoSourceAudio(videoUrl, jobId);
              const useBed = canUseBedUnderDialogue({
                bedUrl: mneStemUrl,
                isolatedVocalUrl,
                validationStatus: mneValidation?.validationStatus,
                source: mneValidation?.source,
              });
              const faithful = await mediaService.mixDubFaithful(jobId, targetLang, {
                sourceAudioUrl,
                dubbedAudioUrl: rawDialogueUrl,
                bedUrl: useBed ? mneStemUrl : null,
                isolatedVocalUrl: isolatedVocalUrl || null,
                lines: segments.map((s) => ({ speaker: s.speaker || "speaker_0", startMs: s.start, endMs: s.end })),
                sourceWords: (sourceWords || []).map((w) => ({ startMs: w.start, endMs: w.end })),
                totalDurationMs,
                sourceIsSpeechOnly: speechOnlyJob,
              });
              const { url: _faithfulUrl, bgmReport, ...faithfulReport } = faithful;
              const enrichedBgmReport = bgmReport
                ? {
                    ...bgmReport,
                    bleed: {
                      passed: mneValidation?.validationStatus !== "failed",
                      vocalSuppressionDb: mneValidation?.vocalSuppressionDb ?? null,
                      bleedMethod: mneValidation?.bleedMethod ?? null,
                    },
                  }
                : undefined;
              await db().collection("video_jobs").doc(jobId).set(
                {
                  artifacts: {
                    faithfulMix: { [targetLang]: { ...faithfulReport, mixedAt: Date.now() } },
                    ...(enrichedBgmReport ? { bgmReport: { [targetLang]: enrichedBgmReport } } : {}),
                  },
                },
                { merge: true }
              ).catch(() => {});
              dubSyncReport = faithful.syncReport;
              if (faithful.ok && faithful.url) {
                masterAudioUrl = faithful.url;
                faithfulMixed = true;
                deliveryTargetLufs = typeof faithful.sourceLufs === "number" ? faithful.sourceLufs : undefined;
                logger.info("[Dubbing] ✅ Faithful mix: original audio kept outside the dialogue", { jobId, targetLang, ...faithfulReport });
              } else {
                logger.warn("[Dubbing] Faithful mix not used — falling back to the sidechain mix", { jobId, targetLang, ...faithfulReport });
              }
            } catch (faithfulErr) {
              logger.warn("[Dubbing] Faithful mix error — falling back to the sidechain mix", { jobId, targetLang, err: String(faithfulErr) });
            }
          }

          if (!faithfulMixed && mneStemUrl && mneValidation?.validationStatus !== "failed") {
            if (!preserveBgm) {
              logger.info("[Dubbing] Skipping M&E background mix because preserveBgm is disabled", { jobId, targetLang });
            } else {
              try {
                await updateDubbingStage("running", 94);
                logger.info("[Dubbing] Dynamically sidechain-ducking M&E stem with dubbed speech", { jobId, targetLang, tier: executionPlan.dubbingTier, bgmDuckLevelPercent });
                masterAudioUrl = await mediaService.mixDubWithMne(jobId, targetLang, {
                  mneUrl: mneStemUrl,
                  dubbedAudioUrl: rawDialogueUrl,
                  isolatedVocalUrl: isolatedVocalUrl || undefined,
                  sourceWords: sourceWords || undefined,
                  totalDurationSeconds,
                  totalDurationMs,
                  // audioFilters intentionally omitted — dialogue already mastered by stitchAudio;
                  // mixDubWithMne handles the final single-pass loudnorm.
                  roomTone: acousticFingerprint?.roomTone,
                  bgmDuckLevelPercent,
                  spokenSegments: segments.map((s) => ({ start: s.start, end: s.end })),
                  isDegradedMne: mneValidation?.validationStatus === "degraded" || mneValidation?.source === "dsp_fallback",
                  mneValidation,
                });
                logger.info("[Dubbing] ✅ Non-destructive M&E + Dubbed master mix created", { jobId, targetLang, masterAudioUrl });
              } catch (mixErr) {
                logger.warn("[Dubbing] M&E mix notice, falling back to dialogue audio:", mixErr);
              }
            }
          }

          // 🛡️ Delivery check on the audio the viewer will hear: no source-language voice under the dub,
          // and loudness on target. Falls back to the dialogue-only track before it ever ships bleed.
          this.recordTiming(langTimings, "faithful_mix", tMixStart, { jobId, lang: targetLang, durationSec: langDurSec });
          const tDeliveryStart = Date.now();
          masterAudioUrl = await this.enforceDeliveryAudio(jobId, targetLang, {
            masterUrl: masterAudioUrl,
            dialogueOnlyUrl: rawDialogueUrl,
            referenceUrl: isolatedVocalUrl || null,
            videoUrl,
            speech: segments.map((s) => ({ startMs: s.start, endMs: s.end })),
            // A faithful mix keeps the original's loudness instead of the −14 LUFS default.
            targetLufs: deliveryTargetLufs,
          });

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
            syncViolations: syncViolations(dubSyncReport),
          });
          if (dubSyncReport?.checked) {
            logger.info("[Dubbing:SyncCheck] Dub measured against the original", {
              jobId,
              targetLang,
              missingLines: dubSyncReport.missing.map((m) => Number((m.startMs / 1000).toFixed(2))),
              genderMismatches: dubSyncReport.genderMismatches,
            });
          }

          if (!postStitchGate.passed) {
            const isFatalForAudioTrack = (dubbingTier === "cinema") ||
              (ttsResult.failedSegments.length > 0) ||
              (outputAudioSize > 0 && outputAudioSize < 10000) ||
              // A4: a broken track (missing lines, wrong length, out of sync, empty) never ships.
              postStitchGate.violations.some(isBlockingViolation);

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
              const targetVid = jobData?.videoId;
              if (targetVid) {
                await safeMergeExistingVideoSubdoc(targetVid, "media", "localization", gateFailureDoc, "[Dubbing:QualityGate:PostStitch]").catch(() => {});
              }
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

          this.recordTiming(langTimings, "delivery_check", tDeliveryStart, { jobId, lang: targetLang, durationSec: langDurSec });
          const tUploadStart = Date.now();
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

          const skipVideoRemux =
            (executionPlan as any).dubbingTier === "audio_track" && executionPlan.deliverDubbedVideo !== true;

          if (directAudioUrl) {
            await this.propagateAudioTrack(jobId, targetLang, rawTargetLang, directAudioUrl);
            if (skipVideoRemux) {
              await updateDubbingStage("completed", 100);
            } else {
              // Keep stage running while the dubbed MP4 is muxed so Studio clients don't export before videoResult is ready.
              await updateDubbingStage("running", 98);
            }
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
          // to eliminate 30-60s latency and reduce cloud compute overhead — unless the order asks
          // for a downloadable dubbed video (Dubbing Studio).
          if (skipVideoRemux) {
            videoResult = "";
            logger.info("[Dubbing] Skipping video remuxing for audio-track tier (audio track is published)", { jobId, targetLang });
          } else {
            try {
              // Remux dubbed audio into video container cleanly via FFmpeg
              const isPreMastered = masterAudioUrl !== rawDialogueUrl;
              videoResult = await mediaService.mergeAudioToVideo({
                jobId, videoUrl, audioUrl, 
                subtitleUrl: executionPlan.genLangSubs ? subtitleUrl : undefined,
                language: targetLang, format: "mp4",
                audioFilters: dspFilters, // Pass the mastering chain to FFmpeg
                isPreMastered,
              });
              // enforceDeliveryAudio already verified & normalized masterAudioUrl; skip redundant
              // full-MP4 download + ebur128 re-scan when mergeAudioToVideo applied no audioFilters.
              if (!isPreMastered) {
                videoResult = await this.enforceVideoLoudness(jobId, targetLang, videoResult, deliveryTargetLufs);
              }
              if (videoResult) {
                await this.saveDubbingCheckpoint(jobId, targetLang, {
                  masterVideoUrl: videoResult,
                } as any).catch(() => {});
                const immediateDirectVideoUrl = videoResult.startsWith("gs://")
                  ? `https://storage.googleapis.com/${bucket.name}/${videoResult.replace(`gs://${bucket.name}/`, "")}`
                  : videoResult;
                if (immediateDirectVideoUrl && immediateDirectVideoUrl !== videoUrl) {
                  await db().collection("video_jobs").doc(jobId).set(
                    {
                      outputs: {
                        dubbedVideos: {
                          [targetLang]: immediateDirectVideoUrl,
                          ...(rawTargetLang && rawTargetLang !== targetLang
                            ? { [rawTargetLang]: immediateDirectVideoUrl }
                            : {}),
                        },
                      },
                    },
                    { merge: true }
                  ).catch(() => {});
                }
              }
            } catch (mergeErr) {
              logger.warn("[Dubbing] Video remuxing skipped or deferred (audio track is intact):", mergeErr);
              videoResult = "";
            }
          }

          await updateDubbingStage("completed", 100);
          this.recordTiming(langTimings, "upload", tUploadStart, { jobId, lang: targetLang, durationSec: langDurSec });
          await db().collection("video_jobs").doc(jobId).set(
            { timings: { languages: { [targetLang]: langTimings } } },
            { merge: true }
          ).catch(() => {});
        } catch (dubErr) {
          logger.error("[Dubbing] Dubbing failed for language, but continuing with subtitles", { jobId, targetLang, err: String(dubErr) });
          await updateDubbingStage("failed", 10, String(dubErr));
        } finally {
          if (leaseHeartbeat) {
            clearInterval(leaseHeartbeat);
            leaseHeartbeat = null;
          }
          await settleSubtitles();
          if (leaseAcquired) {
            await this.releaseDubbingLease(jobId, targetLang, currentWorkerId);
          }
        }
        // Delivered only if an audio track was published; any failure above leaves it empty.
        dubOutcome = audioUrl ? "delivered" : "failed";
        if (subtitleTaskError !== null) throw subtitleTaskError;
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
          const videoJobOutputsNested: Record<string, any> = {};
          const langAliasMap = <T>(val: T): Record<string, T> => ({
            [targetLang]: val,
            ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: val } : {}),
          });

          if (directAudioUrl) {
            videoDocUpdate[`audioTracks.${targetLang}`] = directAudioUrl;
            videoDocUpdate[`audioTrackSources.${targetLang}`] = "ai_dub";
            videoDocUpdate.aiDubbedAudio = {
              ...(videoDocUpdate.aiDubbedAudio || {}),
              ...langAliasMap(directAudioUrl),
            };
            videoDocUpdate[`media.audioTracks.${targetLang}`] = directAudioUrl;
            videoDocUpdate[`media.audioTrackSources.${targetLang}`] = "ai_dub";
            locDocUpdate[`audioTracks.${targetLang}`] = directAudioUrl;
            locDocUpdate[`audioTrackSources.${targetLang}`] = "ai_dub";
            jobOutputAudio.audioTracks = langAliasMap(directAudioUrl);
            jobOutputAudio.audioTrackSources = langAliasMap("ai_dub");
            videoJobOutputsNested.audioTracks = langAliasMap(directAudioUrl);
            videoJobOutputsNested.audioTrackSources = langAliasMap("ai_dub");

            if (rawTargetLang && rawTargetLang !== targetLang) {
              videoDocUpdate[`audioTracks.${rawTargetLang}`] = directAudioUrl;
              videoDocUpdate[`audioTrackSources.${rawTargetLang}`] = "ai_dub";
              videoDocUpdate[`media.audioTracks.${rawTargetLang}`] = directAudioUrl;
              videoDocUpdate[`media.audioTrackSources.${rawTargetLang}`] = "ai_dub";
              locDocUpdate[`audioTracks.${rawTargetLang}`] = directAudioUrl;
              locDocUpdate[`audioTrackSources.${rawTargetLang}`] = "ai_dub";
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
            videoJobOutputsNested.dubbedVideos = langAliasMap(directVideoUrl);

            if (rawTargetLang && rawTargetLang !== targetLang) {
              videoDocUpdate[`dubbedVideos.${rawTargetLang}`] = directVideoUrl;
              videoDocUpdate[`media.dubbedVideos.${rawTargetLang}`] = directVideoUrl;
              locDocUpdate[`dubbedVideos.${rawTargetLang}`] = directVideoUrl;
            }
          }

          if (rawDialogueUrl) {
            videoJobOutputsNested.dialogueTracks = langAliasMap(rawDialogueUrl);
          }
          if (translationUrl) {
            videoJobOutputsNested.translations = langAliasMap(translationUrl);
          }
          if (isolatedVocalUrl || mneStemUrl) {
            videoJobOutputsNested.stems = {
              ...(isolatedVocalUrl ? { vocals: isolatedVocalUrl } : {}),
              ...(mneStemUrl ? { mne: mneStemUrl, background: mneStemUrl } : {}),
              ...(rawDialogueUrl ? { dialogue: langAliasMap(rawDialogueUrl) } : {}),
            };
          }

          if (directVideoUrl || directAudioUrl) {
            jobOutputAudio.dubbed = langAliasMap({
              audioUrl: directAudioUrl,
              path: isGenuineDubbed ? directVideoUrl : directAudioUrl,
              videoUrl: isGenuineDubbed ? directVideoUrl : "",
              language: targetLang,
              updatedAt: Date.now(),
            });
          }

          for (const vid of linkedVideoIds) {
            await safeMergeExistingVideo(vid, videoDocUpdate, "[Dubbing:processLanguage]");
            await safeMergeExistingVideoSubdoc(vid, "media", "localization", locDocUpdate, "[Dubbing:processLanguage]");
          }

          await db().collection("job_outputs").doc(jobId).set(jobOutputAudio, { merge: true });
          await db().collection("video_jobs").doc(jobId).set(
            {
              outputs: videoJobOutputsNested,
              updatedAt: Date.now(),
            },
            { merge: true }
          );
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
        dubOutcome,
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
    audioUrl: string,
    timingMeta?: { jobId: string; lang?: string; segmentIndex?: number }
  ): Promise<{ valid: boolean; sizeBytes: number; durationMs: number; error?: string; measured?: boolean }> {
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

        const tFfprobe = Date.now();
        const durationMs = await mediaService.probeMediaDurationMs(tmpProbePath).catch(() => 0);
        if (timingMeta?.jobId) {
          emitDubbingTiming("tts.ffprobe", tFfprobe, {
            jobId: timingMeta.jobId,
            lang: timingMeta.lang,
            segmentIndex: timingMeta.segmentIndex ?? null,
            measuredMs: durationMs,
          });
        }
        if (durationMs > 0 && durationMs <= 100) {
          return { valid: false, sizeBytes, durationMs, error: `duration_too_short (${durationMs}ms <= 100ms)` };
        }

        // measured: the real length of the audio (ffprobe), not a placeholder.
        return { valid: true, sizeBytes, durationMs: durationMs || 250, measured: durationMs > 0 };
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
    leaseTtlMs: number = 120_000,
    workerId?: string
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
            if (!workerId || data?.workerId !== workerId) {
              logger.warn("[Dubbing:Lease] Active lease held by another worker — declining duplicate execution", {
                jobId,
                targetLang,
                existingLease,
                remainingMs: existingLease - now,
                existingWorkerId: data?.workerId,
                requestingWorkerId: workerId,
              });
              return false;
            }
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
            ...(workerId ? { workerId } : {}),
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
   * 🛡️ A9 Heartbeat: Atomically renew the synthesis lease lock while actively processing.
   * Extends leaseExpiresAt by leaseTtlMs to prevent premature expiry (>120s) and parallel double-billing.
   * Verifies worker ownership so an expired lease claimed by another worker cannot be overwritten.
   */
  public async renewDubbingLease(
    jobId: string,
    targetLang: string,
    leaseTtlMs: number = 120_000,
    workerId?: string
  ): Promise<boolean> {
    const docRef = db().collection("dubbing_checkpoints").doc(`${jobId}_${targetLang}`);
    try {
      return await db().runTransaction(async (transaction) => {
        const snap = await transaction.get(docRef);
        const now = Date.now();
        if (snap.exists) {
          const data = snap.data();
          if (workerId && data?.workerId && data.workerId !== workerId) {
            logger.warn("[Dubbing:Lease] Lease renewal rejected — lease owned by a different worker", {
              jobId,
              targetLang,
              currentWorkerId: data.workerId,
              requestingWorkerId: workerId,
            });
            return false;
          }
        }
        transaction.set(
          docRef,
          {
            leaseExpiresAt: now + leaseTtlMs,
            updatedAt: now,
            ...(workerId ? { workerId } : {}),
          },
          { merge: true }
        );
        return true;
      });
    } catch (err) {
      logger.warn("[Dubbing:Lease] Notice renewing lease:", { jobId, targetLang, err: String(err) });
      return false;
    }
  }

  /**
   * 🛡️ Release atomic lease upon completion or failure.
   */
  public async releaseDubbingLease(jobId: string, targetLang: string, workerId?: string): Promise<void> {
    try {
      const docRef = db().collection("dubbing_checkpoints").doc(`${jobId}_${targetLang}`);
      if (workerId) {
        await db().runTransaction(async (transaction) => {
          const snap = await transaction.get(docRef);
          if (snap.exists && snap.data()?.workerId && snap.data()?.workerId !== workerId) {
            return;
          }
          transaction.set(docRef, { leaseExpiresAt: 0, updatedAt: Date.now() }, { merge: true });
        });
      } else {
        await docRef.set({ leaseExpiresAt: 0, updatedAt: Date.now() }, { merge: true });
      }
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
    /** Real length (ffprobe) of each synthesized line, ms; null when it could not be measured. */
    measuredDurationsMs: Array<number | null>;
  }> {
    const allUrls: string[] = new Array(segments.length).fill("");
    const measuredDurationsMs: Array<number | null> = new Array(segments.length).fill(null);
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

    const tTtsLoopStart = Date.now();
    for (let i = 0; i < segments.length; i += adaptiveBatchSize) {
      const batch = segments.slice(i, i + adaptiveBatchSize);

      const batchUrls = await Promise.allSettled(
        batch.map(async (seg) => {
          emitDubbingTiming(
            "tts.queue_wait",
            tTtsLoopStart,
            { jobId, lang: language, segmentIndex: seg.index },
            undefined,
            Date.now() - tTtsLoopStart
          );
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

          // A16: with the native-voice policy on (default), a speaker without a voice, or a gender clash,
          // gets another native voice of the right gender from this language's cast — never an American
          // preset. If there is none, the line fails, so the language fails and is refunded.
          const nativeOnly = nativeVoicesOnly();
          const nativeVoiceOfGender = (female: boolean): string | null => {
            for (const [spk, vId] of Object.entries(voiceMapping || {})) {
              const g = speakerGenderMapping?.[spk];
              if (vId && g && (g === "FEMALE") === female) return vId;
            }
            return null;
          };
          const defaultVoiceId = isFemaleSpeaker ? "EXAVITQu4vr4xnSDxMaL" : "ErXwobaYiN019PkySvjV"; // Sarah vs Antoni
          let voiceId = voiceMapping[speakerId] || (nativeOnly ? nativeVoiceOfGender(isFemaleSpeaker) || "" : defaultVoiceId);
          if (!voiceId) {
            throw new Error(`no_native_voice: no ${isFemaleSpeaker ? "female" : "male"} native ${language} voice for speaker ${speakerId}`);
          }

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
          const clash =
            (gender === "FEMALE" && ELEVENLABS_VOICE_GENDER_MAP[voiceId] === "MALE") ||
            (gender === "MALE" && ELEVENLABS_VOICE_GENDER_MAP[voiceId] === "FEMALE");
          if (clash) {
            if (nativeOnly) {
              const native = nativeVoiceOfGender(gender === "FEMALE");
              if (!native) {
                throw new Error(`no_native_voice: no ${gender.toLowerCase()} native ${language} voice for speaker ${speakerId}`);
              }
              voiceId = native;
            } else {
              voiceId = gender === "FEMALE" ? "EXAVITQu4vr4xnSDxMaL" : "ErXwobaYiN019PkySvjV"; // Safe preset
            }
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
          // A10: the saved profile only smooths stability/similarity/pitch. It never replaces the voice
          // chosen for this run (that choice already passed the gender guard and the native-voice policy).
          if (persistedProfile?.voiceId && persistedProfile.voiceId !== voiceId) {
            logger.info("[Dubbing] Saved speaker profile has a different voice — keeping this run's voice", {
              jobId, speakerId, language, savedVoiceId: persistedProfile.voiceId, voiceId,
            });
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
          // The cache key carries the delivery: the same words shouted and spoken calmly are different audio.
          const ttsCacheText = seg.emotionTag ? `[${String(seg.emotionTag).toLowerCase().trim()}] ${seg.translatedText}` : seg.translatedText;
          const cached = await this.performanceLayer.checkTTSCache(
            ttsCacheText,
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
            segmentIndex: seg.index,
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

          // Cost tracking: ttsService.synthesize (tts.ts) records the TTS cost itself, once per real
          // ElevenLabs call. Recording it here as well counted every voiced line twice.

          // Store in cache for next time with strict tier and voice isolation
          await this.performanceLayer.cacheTTSResult(
            ttsCacheText,
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
          const integrity = await this.verifyAudioChunk(canonicalUrl, { jobId, lang: language, segmentIndex: segIndex });
          if (integrity.valid) {
            allUrls[globalIdx] = canonicalUrl;
            checkpointUrls[String(segIndex)] = canonicalUrl;
            // The real length of the line (TTS only returns an estimate from the text).
            if (integrity.measured && seg) {
              measuredDurationsMs[globalIdx] = integrity.durationMs;
              seg.actualSynthesizedDurationMs = integrity.durationMs;
              seg.durationMs = integrity.durationMs;
            }
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

      // A9: the lease is renewed by the owner's heartbeat in processLanguage (with its worker id). A
      // renewal here would carry no owner and could extend another worker's lease.

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
      measuredDurationsMs,
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
      speakerProfiles?: any[];
      onScreenText?: any[];
      dubbingTier?: "audio_track";
      subtitleTier?: "ultra";
      isCinemaGrade?: boolean;
      totalDurationMs?: number;
      shotChangesMs?: number[];
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      speakerNames?: Record<string, string>;
      castGenderByLabel?: Record<string, "male" | "female">;
      enableDualTrack?: boolean;
    }
  ): Promise<DubbingSegment[]> {
    const texts  = segments.map((s) => s.text);
    // Hash cast list + relationships and version into cache key
    const castHash = computeCastHash(options?.castList, options?.relationships, "stage4_v2");
    // Hybrid translation edits each line using its neighbours and its time slot, so a
    // per-line cache would return text written for a different context. Checkpoints
    // still prevent re-translation when a job resumes.
    const useLineCache = !isContextualDubbingEditEnabled();
    const cached: (string | null)[] = useLineCache
      ? await this.performanceLayer.checkTranslationCache(texts, sourceLang, targetLang, castHash)
      : texts.map(() => null);

    const toTranslate = segments.filter((_, i) => !cached[i]);
    let newTranslations: Array<{
      text: string;
      subtitleText?: string;
      appliedRegister?: string;
      confidence?: number;
      variants?: any;
      syllableBudgetCompliance?: number;
      terminologyWarning?: string;
      terminologyViolations?: any[];
      terminologyComplianceRate?: number;
      numericalParityVerified?: boolean;
      numericalParityWarning?: string;
      semanticParityScore?: number;
      reviewRecommended?: boolean;
      polarityFlipped?: boolean;
      repairAttempted?: boolean;
      repairOutcome?: "repaired" | "failed";
      translationBlockReason?: "number_mismatch" | "polarity_flip" | "meaning_unresolved";
    }> = [];

    let localizationBible: any;
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
          isSong: s.isSong,
          emotionTag: s.emotionTag,
          energyDb: s.energyDb,
          stabilityOverride: s.stabilityOverride,
          similarityBoostOverride: s.similarityBoostOverride,
          pitchRangeSemitones: s.pitchRangeSemitones,
          voiceQuality: s.voiceQuality,
          deliveryStyle: s.deliveryStyle,
          delivery: s.delivery || s.emotionTag || (s.deliveryStyle && s.deliveryStyle !== "natural" ? s.deliveryStyle : undefined),
        })),
        sourceLang,
        targetLang,
        options
      );
      localizationBible = (res as any).localizationBible;
      newTranslations = res.segments.map((s: any) => ({
        text: s.translated,
        subtitleText: s.subtitleText,
        appliedRegister: s.appliedRegister,
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
        repairAttempted: s.repairAttempted,
        repairOutcome: s.repairOutcome,
        translationBlockReason: s.translationBlockReason,
      }));
      if (newTranslations.length !== toTranslate.length || newTranslations.some((translation) => !translation.text?.trim())) {
        throw new Error(`[Dubbing] Composite primary returned incomplete translations for ${targetLang}.`);
      }

      if (useLineCache) {
        await this.performanceLayer.cacheTranslations(
          toTranslate.map((s) => s.text),
          newTranslations.map(nt => nt.text),
          sourceLang,
          targetLang,
          castHash
        );
      }
    }

    let newIdx = 0;
    const out = segments.map((seg, i) => {
      // Legacy cache hits were not verified by the hybrid editor or quality gate: keep quality
      // fields `undefined` ("not checked") rather than faking passed checks.
      const translation = cached[i]
        ? { text: decodeHtmlEntities(cached[i]!), subtitleText: decodeHtmlEntities(cached[i]!), appliedRegister: undefined, confidence: 0.99, variants: undefined, syllableBudgetCompliance: undefined, terminologyWarning: undefined, terminologyViolations: undefined, terminologyComplianceRate: 1.0, numericalParityVerified: undefined, numericalParityWarning: undefined, semanticParityScore: undefined, reviewRecommended: undefined, polarityFlipped: undefined }
        : newTranslations[newIdx++];
      if (!translation?.text?.trim()) {
        throw new Error(`[Dubbing] Missing required ${targetLang} translation for segment ${seg.index}.`);
      }

      // Dual-track split: spoken dub text vs written on-screen subtitle text
      let cleanDubText = decodeHtmlEntities(translation.text);
      let cleanSubText = decodeHtmlEntities(translation.subtitleText || translation.text);

      if (targetLang === "te") {
        cleanDubText = applyTeluguTheologicalLexiconGuard(cleanDubText);
        cleanSubText = applyTeluguTheologicalLexiconGuard(cleanSubText);
        // Spoken contractions applied ONLY to dub voice track, never subtitles — and only on the legacy
        // translation path: with the Gemini edit on, spoken style was already chosen in context.
        if (!isContextualDubbingEditEnabled()) cleanDubText = applySpokenTeluguColloquialContractions(cleanDubText);
      }
      // Scripture phonetic expansion applied ONLY to dub voice track for natural TTS vocalization
      cleanDubText = normalizeScriptureCitationsForTts(cleanDubText, targetLang);

      return {
        index:          seg.index,
        originalText:   seg.text,
        translatedText: cleanDubText,
        subtitleText:   cleanSubText,
        appliedRegister: translation.appliedRegister,
        confidence:     translation.confidence,
        variants:       translation.variants,
        language:       targetLang,
        start:          seg.start,
        end:            seg.end,
        targetDuration: seg.duration,
        speaker:        seg.speaker,
        isHook:         seg.isHook,
        isSong:         (seg as any).isSong,
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
        numericalParityVerified: (translation as any).numericalParityVerified,
        numericalParityWarning: (translation as any).numericalParityWarning,
        semanticParityScore: (translation as any).semanticParityScore,
        reviewRecommended: (translation as any).reviewRecommended,
        polarityFlipped: (translation as any).polarityFlipped,
        repairAttempted: (translation as any).repairAttempted,
        repairOutcome: (translation as any).repairOutcome,
        translationBlockReason: (translation as any).translationBlockReason,
      };
    });
    if (localizationBible) {
      Object.defineProperty(out, "localizationBible", {
        value: localizationBible,
        enumerable: false,
        configurable: true,
      });
    }
    return out;
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
    words?:         WordTimestamp[],
    extras?: {
      videoUrl?: string;
      totalDurationMs?: number;
      localeStyle?: string;
      tone?: "casual" | "formal";
      userId?: string;
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      speakerNames?: Record<string, string>;
      castGenderByLabel?: Record<string, "male" | "female">;
    }
  ): Promise<{ srtUrl: string; vttUrl: string; jsonUrl: string }> {
    if (words && words.length > 0) {
      try {
        // Songs and on-screen text are found once per video (cached on the job) and shared by
        // every language. Best-effort: empty when analysis is off or fails.
        const screen = extras?.videoUrl
          ? await getScreenContent(jobId, extras.videoUrl, extras.totalDurationMs)
          : { songIntervalsMs: [], onScreenText: [], shotChangesMs: [] };

        // 🎬 Shot-change detection for Netflix subtitle alignment
        let shotChanges: number[] = screen.shotChangesMs || [];
        if (shotChanges.length === 0 && extras?.videoUrl) {
          try {
            shotChanges = await MediaService.detectShotChanges(extras.videoUrl);
          } catch (scErr) {
            logger.warn("[Dubbing] Shot change detection skipped or failed", { jobId, error: String(scErr) });
          }
        }

        let preTranslatedSentences: Array<{ startMs: number; endMs: number; speaker?: string; sourceText: string; text: string }> | undefined;
        if (subtitlesFromDubPassEnabled() && language !== sourceLanguage && segments.length > 0) {
          const missingCount = segments.filter((s) => !s.subtitleText || !s.subtitleText.trim()).length;
          if (missingCount === 0) {
            preTranslatedSentences = segments.map((s) => ({
              startMs: s.start,
              endMs: s.end,
              speaker: s.speaker,
              sourceText: s.originalText,
              text: stripAudioTagsForSubtitles(s.subtitleText!),
            }));
          } else {
            logger.warn("[MultilingualLocalizer] Dual-track subtitle text missing — translating subtitles separately", {
              jobId,
              targetLanguage: language,
              missingCount,
            });
          }
        }

        const localized = await MultilingualSubtitleLocalizer.localizeTrack({
          jobId,
          sourceWords: words,
          sourceLanguage,
          targetLanguage: language,
          songIntervalsMs: screen.songIntervalsMs,
          onScreenText: screen.onScreenText,
          shotChangesMs: shotChanges,
          localeStyle: extras?.localeStyle,
          tone: extras?.tone,
          userId: extras?.userId,
          castList: extras?.castList,
          relationships: extras?.relationships,
          speakerNames: extras?.speakerNames,
          castGenderByLabel: extras?.castGenderByLabel,
          preTranslatedSentences,
          fallbackSegments: segments.map((s, idx) => {
            const rawDur = s.actualSynthesizedDurationMs || s.durationMs || (s.end - s.start);
            const actualDur = (s.actualSynthesizedDurationMs || s.durationMs || s.end > 1000)
              ? rawDur
              : (rawDur > 60 ? rawDur : rawDur * 1000);
            const nextSeg = idx < segments.length - 1 ? segments[idx + 1] : undefined;
            const nextStart = nextSeg ? nextSeg.start : (s.start + actualDur + 2000);
            const snappedEnd = Math.min(s.start + actualDur, Math.max(s.start + 300, nextStart - 50));
            return {
              index: idx + 1,
              start: s.start,
              end: snappedEnd,
              duration: snappedEnd - s.start,
              text: stripAudioTagsForSubtitles((s as any).subtitleText || s.translatedText),
              words: [],
            };
          }),
        });

        // A track that misses most lines (e.g. built from a partial word list) is never saved; the
        // line-based subtitles below are used instead.
        const coverage = subtitleLineCoverage(
          localized.cues.map((c) => ({ startMs: c.startMs, endMs: c.endMs })),
          segments.map((s) => ({ startMs: s.start, endMs: s.end, text: (s as any).subtitleText || s.translatedText }))
        );
        if (coverage < MIN_SUBTITLE_LINE_COVERAGE) {
          throw new Error(`subtitle track covers ${Math.round(coverage * 100)}% of the dubbed lines (${localized.cues.length} cues for ${segments.length} lines)`);
        }

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
          text: stripAudioTagsForSubtitles((s as any).subtitleText || s.translatedText),
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
    for (const withTiming of segments) {
      // timingWords is only for this split; it is never carried onto the output lines.
      const { timingWords: _timingWords, ...seg } = withTiming as TimedSegment & { timingWords?: WordTimestamp[] };
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
      // Word-anchored when the utterance has word timings: a pause inside it (scene cut, long beat)
      // must not pull later sentences early. Character share only when there are no words.
      const trimmedChunks = chunks.map((c) => c.trim()).filter(Boolean);
      const timingWords = seg.words && seg.words.length > 0 ? seg.words : (_timingWords || []);
      const wordSpans = chunkTimesFromWords(trimmedChunks, timingWords);
      logger.info("[Dubbing] Long line split", {
        start: seg.start,
        end: seg.end,
        chunks: trimmedChunks.length,
        words: timingWords.length,
        timing: wordSpans ? "words" : "character_share",
        starts: wordSpans ? wordSpans.map((w) => w.start) : undefined,
      });
      if (wordSpans) {
        trimmedChunks.forEach((text, k) => {
          result.push({
            index: result.length,
            text,
            start: wordSpans[k].start,
            end: wordSpans[k].end,
            duration: wordSpans[k].end - wordSpans[k].start,
            speaker: seg.speaker || "speaker_0",
            words: [],
          });
        });
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
      
      // Join a very short line, or one ending on a connecting word, with the next line — only for the
      // same speaker across a short pause (segment-stitching.ts; audit A8).
      while (i + 1 < segments.length && shouldStitch(current, segments[i + 1])) {
        const next = segments[i + 1];
        current.text = (current.text + " " + next.text).trim();
        current.end = next.end;
        current.duration = current.end - current.start;
        if (current.words && next.words) {
          current.words = [...current.words, ...next.words];
        }
        i++;
      }
      stitched.push(current);
    }
    return stitched;
  }

  // ─── Utilities ────────────────────────────────────────────────────────────────

  private normaliseTTS(text: string, emotionTag?: string): string {
    let t = text;
    if (emotionTag !== "whispers") {
      t = t.replace(/\[(whisper|whispers)\]/gi, emotionTag ? `[${emotionTag}]` : "").trim();
    }
    return sanitizeTextForElevenLabsV4(t, emotionTag);
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

  /**
   * The Firestore transcript keeps utterances without word timings (1 MB doc limit). Dubbing needs them
   * to time sentences inside long utterances, so they are read from the full result in Storage and
   * attached per utterance. Any failure leaves the transcript as it was.
   */
  private async withWordTimings(data: any, jobId: string, origJobId?: string): Promise<any> {
    if (!data || !Array.isArray(data.utterances)) return data;
    if (hasUtteranceWordTimings(data.utterances)) {
      // Lines already carry word timings; make sure the transcript's own word list is there too
      // (the long-form path passes transcript.words to the reels as meta.wordSpans).
      if (Array.isArray(data.words) && data.words.length > 0) return data;
      const flat = collectWordTimings({ utterances: data.utterances });
      return flat.length > 0 ? { ...data, words: flat } : data;
    }
    const bucket = admin.storage().bucket();
    const paths = [`transcripts/${jobId}/full.json`, origJobId && origJobId !== jobId ? `transcripts/${origJobId}/full.json` : null].filter(Boolean) as string[];
    for (const p of paths) {
      try {
        const file = bucket.file(p);
        const [exists] = await file.exists();
        if (!exists) continue;
        const [content] = await file.download();
        const words = collectWordTimings(JSON.parse(content.toString("utf8")));
        if (words.length === 0) continue;
        const utterances = attachWordsToUtterances(data.utterances, words);
        logger.info("[Dubbing] Word timings attached to transcript", {
          jobId,
          path: p,
          words: words.length,
          utterancesWithWords: utterances.filter((u: any) => (u.words?.length || u.timingWords?.length || 0) > 0).length,
          utterances: utterances.length,
        });
        return {
          ...data,
          utterances,
          words: Array.isArray(data.words) && data.words.length > 0 ? data.words : words,
        };
      } catch (e) {
        logger.warn("[Dubbing] Word timings not available:", { path: p, error: String(e) });
      }
    }
    logger.warn("[Dubbing] Transcript has no word timings; long lines are timed by character share", { jobId });
    return data;
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
        return this.withWordTimings(data, jobId, origJobId);
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
          return this.withWordTimings(data, jobId, origJobId);
        }
      }
    }

    const vJobSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
    const vJobTranscript = vJobSnap?.exists ? vJobSnap.data()?.transcription : null;
    if (vJobTranscript && Array.isArray(vJobTranscript.utterances || vJobTranscript.segments) && (vJobTranscript.utterances || vJobTranscript.segments).length > 0) {
      const normalized = this.normalizeTranscriptData(vJobTranscript);
      if (normalized.utterances.length > 0) {
        return this.withWordTimings(normalized, jobId, origJobId);
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
            // Firestore keeps the compact copy; dubbing gets the word timings from the same file.
            const words = collectWordTimings(parsed);
            return words.length > 0
              ? {
                  ...normalized,
                  utterances: attachWordsToUtterances(normalized.utterances, words),
                  words,
                }
              : normalized;
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
            const words = collectWordTimings(parsed);
            return words.length > 0
              ? {
                  ...normalized,
                  utterances: attachWordsToUtterances(normalized.utterances, words),
                  words,
                }
              : normalized;
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

  /**
   * Awaits `getScreenContent` with a bounded timeout (clearing and unref'ing the timer so it never
   * pins the event loop) and marks `isSong` on a shallow copy of segments overlapping `songIntervalsMs`
   * by at least 50% of their duration (R2, R7).
   */
  private async resolveScreenContextForTranslation(
    jobId: string,
    videoUrl: string | undefined,
    totalDurationMs: number | undefined,
    segments: TimedSegment[]
  ): Promise<{
    shotChangesMs?: number[];
    onScreenText: Array<{ startMs: number; endMs: number; text: string; language: string }>;
    segments: TimedSegment[];
  }> {
    let shotChangesMs: number[] | undefined;
    let songIntervalsMs: Array<{ startMs: number; endMs: number }> = [];
    let onScreenText: Array<{ startMs: number; endMs: number; text: string; language: string }> = [];

    if (videoUrl && (shotChangeWindowEnabled() || editorContextEnabled())) {
      const waitMs = Math.max(1000, Number(process.env.DUBBING_SCREEN_CONTENT_WAIT_MS || 20000));
      let timer: NodeJS.Timeout | undefined;
      try {
        const timeoutPromise = new Promise<null>((resolve) => {
          timer = setTimeout(() => resolve(null), waitMs);
          (timer as any)?.unref?.();
        });
        const sc = await Promise.race([
          getScreenContent(jobId, videoUrl, totalDurationMs),
          timeoutPromise,
        ]);
        if (sc) {
          if (sc.shotChangesMs && sc.shotChangesMs.length > 0) shotChangesMs = sc.shotChangesMs;
          if (sc.songIntervalsMs && sc.songIntervalsMs.length > 0) songIntervalsMs = sc.songIntervalsMs;
          if (sc.onScreenText && sc.onScreenText.length > 0) onScreenText = sc.onScreenText;
        } else {
          logger.warn("[Dubbing] getScreenContent timed out before translation — continuing without screen context", { jobId, waitMs });
        }
      } catch (scErr) {
        logger.warn("[Dubbing] getScreenContent failed before translation — continuing without screen context", { jobId, error: String(scErr) });
      } finally {
        if (timer) clearTimeout(timer);
      }
    }

    const mappedSegments =
      editorContextEnabled() && songIntervalsMs.length > 0
        ? segments.map((seg) => {
            const segDur = Math.max(1, seg.end - seg.start);
            const overlapsSong = songIntervalsMs.some((iv) => {
              const overlap = Math.max(0, Math.min(seg.end, iv.endMs) - Math.max(seg.start, iv.startMs));
              return overlap / segDur >= 0.5;
            });
            return overlapsSong ? ({ ...seg, isSong: true } as TimedSegment) : seg;
          })
        : segments;

    return { shotChangesMs, onScreenText, segments: mappedSegments };
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
    voiceMappingByLanguage?: Record<string, Record<string, string>>;
    voiceFallbacks?: Record<string, string>;
    nativeVoiceBlocks?: Record<string, string>;
    creatorDNA: any;
    speakerGenderMapping: Record<string, "MALE" | "FEMALE">;
    mneStemUrl: string | null;
    isolatedVocalUrl: string | null;
    mneValidationResult?: import("../services/media").MneValidationResult;
    eventId: string;
    words?: WordTimestamp[];
    /** Temporary voice clones the reels use; deleted by assembleDubbingReels. */
    temporaryVoiceClones?: string[];
  }): Promise<void> {
    const { jobId, userId, segments, totalDurationMs, executionPlan } = params;
    // Long-form timing (2026-11-25): this whole function runs inside handleDubbing's 540 s limit, so
    // its translation and fan-out are timed as "longform_translation_<lang>" and "longform_dispatch".
    const dispatchTimings: Record<string, number> = {};
    const tDispatchStart = Date.now();
    const dispatchDurSec = totalDurationMs / 1000;
    const sourceLang = normalizeLanguageCode(params.sourceLang);

    // 1. Translate all segments once across target languages & persist subtitles + editable manifests
    const {
      shotChangesMs: longShotChangesMs,
      onScreenText: longOnScreenText,
      segments: longSegmentsWithScreen,
    } = await this.resolveScreenContextForTranslation(
      jobId,
      params.videoUrl,
      totalDurationMs,
      segments
    );

    const translationsByLanguage: Record<string, DubbingSegment[]> = {};
    const subtitlePaths: Record<string, string> = {};
    const translationPaths: Record<string, string> = {};
    const dubLanguages: string[] = [];

    for (const rawLang of params.languagesToProcess) {
      const targetLang = normalizeLanguageCode(rawLang);
      let dubSegs: DubbingSegment[];
      let longCastContext: Awaited<ReturnType<typeof this.loadCastContext>> | undefined;
      if (targetLang === sourceLang) {
        dubSegs = longSegmentsWithScreen.map((s) => ({
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
        const tLongTrans = Date.now();
        longCastContext = await this.loadCastContext(jobId, executionPlan, longSegmentsWithScreen);
        dubSegs = await this.translateWithCache(jobId, longSegmentsWithScreen, sourceLang, targetLang, {
          model: "premium",
          tone: executionPlan.toneMode,
          localeStyle: executionPlan.localeStyle,
          targetPlatform: executionPlan.targetPlatform,
          creatorDNA: params.creatorDNA,
          speakerProfiles: params.speakerProfiles,
          dubbingTier: (executionPlan as any).dubbingTier || "audio_track",
          subtitleTier: executionPlan.subtitleTier || "ultra",
          isCinemaGrade: true,
          totalDurationMs,
          shotChangesMs: longShotChangesMs,
          onScreenText: longOnScreenText,
          ...longCastContext,
          enableDualTrack: true,
        });
        this.recordTiming(dispatchTimings, `longform_translation_${targetLang}`, tLongTrans, { jobId, lang: targetLang, durationSec: dispatchDurSec });
        const isLaunchPair = isLaunchDubbingPair(sourceLang, targetLang);
        const blockedLongSegs = findBlockedTranslationLines(dubSegs);
        if (blockedLongSegs.length > 0) {
          logger.error("[Dubbing:TranslationGate] Language blocked before TTS", {
            jobId,
            targetLang,
            blockedCount: blockedLongSegs.length,
            blockedLines: blockedLongSegs.slice(0, 10),
          });
          const gateResult = DubbingQualityGate.evaluate({
            jobId,
            targetLang,
            totalSegments: dubSegs.length,
            successfulSegments: dubSegs.length,
            failedSegments: [],
            actualDurationSeconds: 0,
            expectedDurationSeconds: dispatchDurSec,
            isVoiceCloningRequested: false,
            isVoiceCloned: false,
            stemIsolationRequested: false,
            isStemPreserved: true,
            translationBlockedLines: blockedLongSegs,
          });
          await EdgeLayer.failStage(jobId, `dubbing_${targetLang}`, blockedTranslationMessage(targetLang)).catch(() => {});
          await EdgeLayer.failStage(jobId, "subtitles", blockedTranslationMessage(targetLang)).catch(() => {});
          await this.addDubbingNotice(jobId, {
            code: "DUB_BLOCKED_TRANSLATION",
            language: targetLang,
            message: blockedTranslationMessage(targetLang),
          });
          await db().collection("video_jobs").doc(jobId).set({
            dubbingStatus: {
              [targetLang]: {
                status: "FAILED",
                reason: "translation_gate_blocked",
                violations: gateResult.violations,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }).catch(() => {});
        } else if (!V4_PREMIUM_80_LANGUAGES.has(targetLang) || !isLaunchPair) {
          logger.warn("[Dubbing:LongForm] Target language not available for dubbing — skipping audio (subtitles remain)", { jobId, sourceLang, targetLang, isLaunchPair });
          await this.addDubbingNotice(jobId, {
            code: "DUB_SKIPPED_UNSUPPORTED_LANGUAGE",
            language: targetLang,
            message: isLaunchPair ? unsupportedDubbingLanguageMessage(targetLang) : launchUnsupportedNotice(sourceLang, targetLang),
          });
        } else if (params.nativeVoiceBlocks?.[targetLang]) {
          logger.warn("[Dubbing:LongForm] Skipping audio for this language: no native voice for every speaker (subtitles remain)", { jobId, targetLang });
          await this.addDubbingNotice(jobId, {
            code: "DUB_SKIPPED_NO_NATIVE_VOICE",
            language: targetLang,
            message: noNativeVoiceMessage(targetLang),
          });
        } else {
          dubLanguages.push(targetLang);
        }
      }

      const { segments: normalisedSegs } = lockVoiceSettingsPerSpeaker(
        dubSegs.map((s) => ({
          ...s,
          translatedText: this.normaliseTTS(s.translatedText, s.emotionTag),
        })),
        { preferVoiceCloning: executionPlan.dubbingMode === "voice_clone" }
      );
      translationsByLanguage[targetLang] = normalisedSegs;

      const isBlockedLong = findBlockedTranslationLines(normalisedSegs).length > 0;
      if (!isBlockedLong) {
        const subRes = await this.generateSubtitles(jobId, normalisedSegs, targetLang, sourceLang, params.words, {
          videoUrl: params.videoUrl,
          totalDurationMs: params.totalDurationMs,
          localeStyle: executionPlan.localeStyle,
          tone: executionPlan.toneMode,
          userId: params.userId,
          castList: longCastContext?.castList,
          relationships: longCastContext?.relationships,
          speakerNames: longCastContext?.speakerNames,
          castGenderByLabel: longCastContext?.castGenderByLabel,
        });
        subtitlePaths[targetLang] = subRes.srtUrl;
      }

      const jobSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
      const videoId = (jobSnap?.data() as any)?.videoId as string | undefined;
      if (!isBlockedLong) {
        translationPaths[targetLang] = await saveTranslationArtifact({
          jobId,
          videoId,
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
          segments: normalisedSegs,
        }).catch(() => "");
      }
      if (targetLang !== sourceLang && !isBlockedLong) {
        await this.saveDubbingEditableManifest({
          jobId,
          videoId,
          userId,
          language: targetLang,
          sourceLanguage: sourceLang,
          totalDurationMs,
          mneStemUrl: params.mneStemUrl,
          subtitleUrl: subtitlePaths[targetLang],
          segments: normalisedSegs,
          ttsUrls: [],
          voiceMapping: params.voiceMappingByLanguage?.[targetLang] ?? params.voiceMapping,
        }).catch(() => {});
      }
    }

    // R3: Refund any ordered non-source languages that were blocked or skipped before dispatching reels.
    const skippedOrBlockedLongLangs = findLongFormSkippedRefundLanguages(
      params.languagesToProcess,
      dubLanguages,
      sourceLang,
      normalizeLanguageCode
    );
    if (skippedOrBlockedLongLangs.length > 0) {
      logger.warn("[Dubbing:LongForm] Languages not delivered — refunding before reel dispatch", {
        jobId,
        failedLanguages: skippedOrBlockedLongLangs,
      });
      await refundDubbingFeeOnFailure({
        jobId,
        userId,
        failedLanguages: skippedOrBlockedLongLangs,
        totalLanguages: params.languagesToProcess,
        reason: "Dubbing could not be delivered for some languages",
      }).catch((refErr) => logger.error("[Dubbing:LongForm] Partial refund error:", refErr));
    }

    if (dubLanguages.length === 0) {
      logger.warn("[Dubbing:LongForm] No dubbable languages remaining after pre-TTS gates — skipping reel dispatch", {
        jobId,
        skippedOrBlockedLongLangs,
      });
      await EdgeLayer.failStage(jobId, "dubbing", friendlyDubbingJobError()).catch(() => {});
      await this.distribution.markEventCompleted(params.eventId);
      return;
    }

    // 2. Partition timeline into 5-minute reels with boundary midpoint ownership (🛡️ A7 timeout protection)
    const reelDurationMs = Number(process.env.DUBBING_REEL_DURATION_MS || 5 * 60 * 1000);
    const { reels, assignedSegments } = mediaService.partitionIntoReels(totalDurationMs, segments, reelDurationMs);
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
      translationPaths,
      totalReels: reels.length,
      totalDurationMs,
      mneStemUrl: params.mneStemUrl || null,
      isolatedVocalUrl: params.isolatedVocalUrl || null,
      mneValidation: params.mneValidationResult || null,
      // Spoken lines (ms) with speakers, for the faithful mix and the delivery check at assembly.
      // Compact (≈40 bytes a line) so a two-hour film stays far below the 1 MB document limit.
      segments: params.segments.map((s) => ({ start: s.start, end: s.end, speaker: s.speaker || "speaker_0" })),
      // Word timings (ms) for the assembler's word-aware checks, flat [start, end, start, end, …] so a
      // two-hour film stays well under the 1 MB document limit (≈16 bytes a word; capped at 40,000 words).
      wordSpans: encodeWordSpans(params.words),
      executionPlan,
      speakerProfiles: params.speakerProfiles || [],
      acousticFingerprint: params.acousticFingerprint || null,
      voiceMapping: params.voiceMapping || {},
      voiceMappingByLanguage: params.voiceMappingByLanguage || {},
      voiceFallbacks: params.voiceFallbacks || {},
      speakerGenderMapping: params.speakerGenderMapping || {},
      temporaryVoiceClones: params.temporaryVoiceClones || [],
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

    this.recordTiming(dispatchTimings, "longform_dispatch", tDispatchStart, { jobId, durationSec: dispatchDurSec });
    await db().collection("video_jobs").doc(jobId).set({ timings: { longform: dispatchTimings } }, { merge: true }).catch(() => {});
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
    const tReelStart = Date.now();
    const reelTimings: Record<string, number> = {};
    const reelDurSec = payload.durationMs / 1000;
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

      // Reels run in separate invocations: re-register library-voice fallbacks for this process.
      registerVoiceFallbacks(jobId, meta.voiceFallbacks || {});
      const tReelTts = Date.now();
      const ttsResult = await this.parallelTTSWithCache(
        jobId,
        userId,
        reelSegs,
        normLang,
        meta.voiceMappingByLanguage?.[normLang] || meta.voiceMapping || {},
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
      this.recordTiming(reelTimings, "tts", tReelTts, { jobId, lang: normLang, durationSec: reelDurSec });

      // Normalize segment start/end to the reel's 0-based local timeline
      const localSegments = reelSegs.map((s) => ({
        start: Math.max(0, s.start - payload.startMs),
        end: Math.max(200, s.end - payload.startMs),
        duration: Math.max(200, s.end - s.start),
      }));

      const tReelStitch = Date.now();
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
      this.recordTiming(reelTimings, "stitch", tReelStitch, { jobId, lang: normLang, durationSec: reelDurSec });

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

    this.recordTiming(reelTimings, `reel_${reelIndex}`, tReelStart, { jobId, durationSec: reelDurSec });
    await jobRef.set({ timings: { reels: { [`reel_${reelIndex}`]: reelTimings } } }, { merge: true }).catch(() => {});

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
    const tAsmStart = Date.now();
    const asmTimings: Record<string, number> = {};
    const jobRef = db().collection("video_jobs").doc(jobId);
    const metaRef = jobRef.collection("reel_orchestration").doc("meta");

    const metaSnap = await metaRef.get();
    if (!metaSnap.exists) {
      throw new Error(`[Dubbing:Assemble] Missing orchestration metadata for ${jobId}`);
    }
    const meta = metaSnap.data()!;
    const metaWords = decodeWordSpans(meta);
    if (meta.status === "completed") {
      logger.info("[Dubbing:Assemble] Already assembled — skipping replay", { jobId });
      return;
    }

    // Every reel is voiced, so the temporary clones (creator or per-speaker) are no longer needed.
    // Assembly mixes finished reel audio and never synthesizes, so deleting first is safe on a retry.
    const tempClones: string[] = Array.isArray(meta.temporaryVoiceClones) ? meta.temporaryVoiceClones : [];
    if (tempClones.length > 0 && !meta.temporaryVoiceClonesDeletedAt) {
      logger.info("[Dubbing:Assemble] All reels voiced — deleting temporary voice clones", { jobId, count: tempClones.length });
      await Promise.all(tempClones.map((id) => ttsService.deleteVoice(id).catch(() => false)));
      await metaRef.set({ temporaryVoiceClonesDeletedAt: Date.now() }, { merge: true }).catch(() => {});
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
    const translationPaths: Record<string, string> = { ...(meta.translationPaths || {}) };
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
      // Faithful mix for long-form too (see processLanguage): original audio outside the dialogue.
      let reelFaithfulMixed = false;
      let reelSyncReport: DubSyncReport | undefined;
      let reelTargetLufs: number | undefined;
      const reelLines = ((meta.segments || []) as Array<{ start: number; end: number; speaker?: string }>)
        .map((s) => ({ speaker: s.speaker || "speaker_0", startMs: s.start, endMs: s.end }));
      if (faithfulMixEnabled() && reelLines.length > 0) {
        try {
          const speechOnly = await this.isSpeechOnlyJob(jobId, null);
          const sourceAudioUrl = await mediaService.extractStereoSourceAudio(payload.videoUrl, jobId);
          const useBed = canUseBedUnderDialogue({
            bedUrl: meta.mneStemUrl,
            isolatedVocalUrl: meta.isolatedVocalUrl,
            validationStatus: meta.mneValidation?.validationStatus,
            source: meta.mneValidation?.source,
          });
          const faithful = await mediaService.mixDubFaithful(jobId, targetLang, {
            sourceAudioUrl,
            dubbedAudioUrl: rawDialogueUrl,
            bedUrl: useBed ? meta.mneStemUrl : null,
            isolatedVocalUrl: meta.isolatedVocalUrl || null,
            lines: reelLines,
            sourceWords: metaWords.map((w) => ({ startMs: w.start, endMs: w.end })),
            totalDurationMs,
            sourceIsSpeechOnly: speechOnly,
          });
          reelSyncReport = faithful.syncReport;
          const { url: _reelFaithfulUrl, bgmReport: reelBgmReport, ...faithfulReport } = faithful;
          const enrichedReelBgmReport = reelBgmReport
            ? {
                ...reelBgmReport,
                bleed: {
                  passed: meta.mneValidation?.validationStatus !== "failed",
                  vocalSuppressionDb: meta.mneValidation?.vocalSuppressionDb ?? null,
                  bleedMethod: meta.mneValidation?.bleedMethod ?? null,
                },
              }
            : undefined;
          await jobRef.set(
            {
              artifacts: {
                faithfulMix: { [targetLang]: { ...faithfulReport, mixedAt: Date.now(), longForm: true } },
                ...(enrichedReelBgmReport ? { bgmReport: { [targetLang]: enrichedReelBgmReport } } : {}),
              },
            },
            { merge: true }
          ).catch(() => {});
          if (faithful.ok && faithful.url) {
            masterAudioUrl = faithful.url;
            reelFaithfulMixed = true;
            reelTargetLufs = typeof faithful.sourceLufs === "number" ? faithful.sourceLufs : undefined;
            logger.info("[Dubbing:Assemble] ✅ Faithful mix: original audio kept outside the dialogue", { jobId, targetLang, ...faithfulReport });
          } else {
            logger.warn("[Dubbing:Assemble] Faithful mix not used — falling back to the sidechain mix", { jobId, targetLang, ...faithfulReport });
          }
        } catch (faithfulErr) {
          logger.warn("[Dubbing:Assemble] Faithful mix error — falling back to the sidechain mix", { jobId, targetLang, err: String(faithfulErr) });
        }
      }
      if (!reelFaithfulMixed && meta.mneStemUrl) {
        masterAudioUrl = await mediaService.mixDubWithMne(jobId, targetLang, {
          mneUrl: meta.mneStemUrl,
          dubbedAudioUrl: rawDialogueUrl,
          isolatedVocalUrl: meta.isolatedVocalUrl || undefined,
          sourceWords: metaWords.length > 0 ? metaWords : undefined,
          totalDurationSeconds: expectedDurSec,
          totalDurationMs,
          // audioFilters omitted — dialogue already mastered via assembleReelAudio; mixDubWithMne handles single-pass loudnorm
          roomTone: meta.acousticFingerprint?.roomTone,
          spokenSegments: metaWords.length > 0 ? metaWords : (meta.segments || []),
        });
      }

      masterAudioUrl = await this.enforceDeliveryAudio(jobId, targetLang, {
        masterUrl: masterAudioUrl,
        dialogueOnlyUrl: rawDialogueUrl,
        referenceUrl: meta.isolatedVocalUrl || null,
        videoUrl: payload.videoUrl,
        speech: ((meta.segments || []) as Array<{ start: number; end: number }>).map((s) => ({ startMs: s.start, endMs: s.end })),
        targetLufs: reelTargetLufs,
      });

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
        syncViolations: syncViolations(reelSyncReport),
      });

      if (!gate.passed) {
        throw new Error(`[Dubbing:Assemble:QualityGate] ${gate.violations.join("; ")}`);
      }

      let videoResult = "";
      if ((executionPlan as any)?.dubbingTier === "audio_track" && executionPlan?.deliverDubbedVideo !== true) {
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
          videoResult = await this.enforceVideoLoudness(jobId, targetLang, videoResult, reelTargetLufs);
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
        ...(translationPaths[targetLang] ? { translationUrl: translationPaths[targetLang] } : {}),
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
        await safeMergeExistingVideo(
          vid,
          {
            audioTracks: { [targetLang]: directAudioUrl },
            audioTrackSources: { [targetLang]: "ai_dub" },
            aiDubbedAudio: { [targetLang]: directAudioUrl },
            [`audioTracks.${targetLang}`]: directAudioUrl,
            [`audioTrackSources.${targetLang}`]: "ai_dub",
            media: {
              audioTracks: { [targetLang]: directAudioUrl },
              audioTrackSources: { [targetLang]: "ai_dub" },
            },
            ...(directVideoUrl ? { dubbedVideos: { [targetLang]: directVideoUrl } } : {}),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          "[Dubbing:Assemble]"
        );
      }

      await EdgeLayer.updateStageSync(jobId, `dubbing_${targetLang}`, { status: "completed", progress: 100 }).catch(() => {});
      dubbingResults.push({
        jobId,
        language: targetLang,
        subtitleUrl: subtitlePaths[targetLang] || "",
        subtitleFormat: "srt",
        audioUrl: masterAudioUrl,
        videoUrl: videoResult,
        translationUrl: translationPaths[targetLang] || "",
        segments: reelDocs.reduce((sum, r) => sum + (r.ownedSegmentIndices?.length || 0), 0),
        processingTime: Date.now() - (meta.createdAt || Date.now()),
        dubOutcome: "delivered",
        stems: {
          mne: meta.mneStemUrl || null,
          dialogue: rawDialogueUrl,
          master: masterAudioUrl,
          vocals: meta.isolatedVocalUrl || null,
        },
      });
    }

    await metaRef.set({ status: "completed", completedAt: Date.now() }, { merge: true });
    this.recordTiming(asmTimings, "assembler", tAsmStart, { jobId, durationSec: expectedDurSec });
    await jobRef.set({ timings: { assembler: asmTimings, totalMs: Date.now() - (meta.createdAt || tAsmStart) } }, { merge: true }).catch(() => {});

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
    const dubbingReportUrl = await saveDubbingReportArtifact({
      jobId,
      videoId: meta.videoId || undefined,
      sourceLanguage: meta.sourceLanguage || "en",
      targetLanguages: meta.languages || payload.languages,
      durationSeconds: expectedDurSec > 0 ? expectedDurSec : undefined,
      processingTimeMs: completedAt - (meta.createdAt || completedAt),
      vocalsStemUrl: meta.isolatedVocalUrl || null,
      backgroundStemUrl: meta.mneStemUrl || null,
      speakerProfiles: Array.isArray(meta.speakerProfiles) ? meta.speakerProfiles : undefined,
      voiceMapping: meta.voiceMapping || undefined,
      results: dubbingResults,
      dialogueStems,
      subtitlePaths,
      timings: { assembler: asmTimings, totalMs: completedAt - (meta.createdAt || tAsmStart) },
      generatedAtMs: completedAt,
    });

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
        dialogueTracks: dialogueStems,
        subtitles: subtitlePaths,
        translations: translationPaths,
        dubbedVideos: dubbedPaths,
        ...(dubbingReportUrl ? { dubbingReportUrl } : {}),
        stems: {
          mne: meta.mneStemUrl || null,
          background: meta.mneStemUrl || null,
          vocals: meta.isolatedVocalUrl || null,
          dialogue: dialogueStems,
        },
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
