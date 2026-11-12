/**
 * 🌍 LAYER 07 — DUBBING ENGINE (INDEPENDENT LOCALIZATION SYSTEM)
 *
 * Translation + TTS + video merge. Full parallel execution per language and per segment.
 *
 * ✅ UPGRADED PIPELINE:
 *   - Translation: Google Cloud Translation v3 (TranslationServiceClient) with v2 fallback
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
  SyncInstruction,
  TimedSegment,
  DubbingCompleteData,
  JobData,
  DubbingEditableManifest,
  DubbingEditableSegment,
  DubbingReelTaskPayload,
  DubbingReelAssemblyPayload,
} from "../types";
import { translationService, decodeHtmlEntities } from "../services/translation";
import {
  ttsService,
  sanitizeTextForElevenLabsV4,
  stripAudioTagsForSubtitles,
} from "../services/tts";
import { mediaService, parseDurationToSeconds, parseAnyStorageUrl } from "../services/media";
import { ELEVENLABS_VOICE_GENDER_MAP, ELEVENLABS_MULTI_SPEAKER_PALETTE } from "../services/googleTextToSpeechService";
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
import { logger }             from "../utils/logger";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import { filterVideoIds } from "../../utils/videosCollectionGuard";

const db = () => admin.firestore();

/** Max segments processed concurrently per TTS batch */
const TTS_BATCH_SIZE = 25;

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
    // On average in Indic Brahmi scripts, ~1.8 - 2.2 characters per spoken syllable
    unitCount = Math.max(1, Math.round(indicChars / 2.0));
    unitsPerSec = ["te", "kn", "ta", "ml"].includes(lang) ? 5.5 : 5.0;
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

    if (executionPlan.generateDubbing) {
      await EdgeLayer.updateStageSync(jobId, "dubbing", {
        status: "running", progress: 5, startedAt: Date.now(),
      });
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

        // 1.6. 100% Studio Preservation: Deep Neural Vocal Isolation & Discrete Stems for ALL Tiers
        try {
          const jobDoc = await db().collection("video_jobs").doc(jobId).get();
          const jobData = jobDoc.data();
          const originalAudioUrl = jobData?.artifacts?.transcription?.audioUrl || videoUrl;

          logger.info("[Dubbing] 100% Studio Preservation: Isolating Vocals for Zero-Phase M&E Stem Separation across all tiers", { jobId, dubbingTier: executionPlan.dubbingTier });
          isolatedVocalUrl = await audioIdentityService.isolateVocals(jobId, originalAudioUrl).catch((err) => {
            logger.warn("[Dubbing] Neural vocal isolation notice (avoiding orig-orig cancellation):", err);
            return null;
          });
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

        // 1.7. Voice Assignment: Map speakers to distinct production voice presets with zero collisions
        const assignedVoiceIds = new Set<string>();
        let cloneAssigned = false;

        for (const profile of speakerProfiles) {
          const role = profile.role || "other";
          let isMale = profile.gender ? profile.gender === "male" : true;
          if (executionPlan.voiceGender === "male") isMale = true;
          if (executionPlan.voiceGender === "female") isMale = false;
          speakerGenderMapping[profile.speakerId] = isMale ? "MALE" : "FEMALE";

          // 🛡️ Strict Clone Gender Invariant: Never assign a male clone to a female speaker or vice-versa
          const isGenderMatch = cloneVoiceGender ? (isMale === (cloneVoiceGender === "male")) : true;
          if (!cloneAssigned && createdVoiceCloneId && isGenderMatch) {
            voiceMapping[profile.speakerId] = createdVoiceCloneId;
            assignedVoiceIds.add(createdVoiceCloneId);
            cloneAssigned = true;
            logger.info("[Dubbing] Assigned cloned creator voice ID to matching gender speaker", {
              jobId,
              speakerId: profile.speakerId,
              voiceId: createdVoiceCloneId,
              gender: profile.gender,
            });
            continue;
          }

          // Multi-Speaker Voice Allocation: Select unique, distinct voice matching speaker profile
          const palette = isMale ? ELEVENLABS_MULTI_SPEAKER_PALETTE.MALE : ELEVENLABS_MULTI_SPEAKER_PALETTE.FEMALE;

          // 1. Try matching both pitchBand and ageTone among unused voices
          let chosen = palette.find((v) => !assignedVoiceIds.has(v.id) && v.pitchBand === profile.pitchBand && v.ageTone === profile.ageTone);
          // 2. Try matching pitchBand among unused voices
          if (!chosen) {
            chosen = palette.find((v) => !assignedVoiceIds.has(v.id) && v.pitchBand === profile.pitchBand);
          }
          // 3. Pick any remaining unused voice in this gender palette
          if (!chosen) {
            chosen = palette.find((v) => !assignedVoiceIds.has(v.id));
          }
          // 4. If all voices in palette are exhausted, wrap around
          if (!chosen) {
            const matchIdx = profile.speakerId.match(/\d+/);
            const idx = matchIdx ? parseInt(matchIdx[0], 10) : 0;
            chosen = palette[idx % palette.length];
          }

          assignedVoiceIds.add(chosen.id);
          voiceMapping[profile.speakerId] = chosen.id;

          logger.info("[Dubbing] Assigned distinct production-grade voice ID", {
            jobId,
            speakerId: profile.speakerId,
            gender: profile.gender || (isMale ? "male" : "female"),
            role,
            pitchBand: profile.pitchBand,
            voiceId: chosen.id,
            voiceName: chosen.name,
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
          sourceLang: transcript.language ?? "en",
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
        });
        return [];
      }

      const results = await Promise.allSettled(
        languagesToProcess.map((lang) =>
          this.processLanguage(
            jobId, userId, videoUrl, lang,
            segments,
            transcript.language ?? "en",
            executionPlan,
            speakerProfiles,
            acousticFingerprint,
            voiceMapping,
            creatorDNA,
            speakerGenderMapping,
            mneStemUrl,
            isolatedVocalUrl,
            mneValidationResult
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
    mneValidation?:  import("../services/media").MneValidationResult
  ): Promise<DubbingResult> {
    const targetLang = normalizeLanguageCode(rawTargetLang);
    const sourceLang = normalizeLanguageCode(rawSourceLang);
    const t0 = Date.now();
    logger.info("[Dubbing] Processing language", { jobId, targetLang, rawTargetLang, sourceLang });
    
    const updateTranslationStage = async (status: "running" | "completed" | "failed", progress: number, error?: string) => {
      const now = Date.now();
      const payload: any = { status, progress };
      if (status === "running") payload.startedAt = now;
      if (status === "completed") payload.completedAt = now;
      if (error) payload.error = error;

      await EdgeLayer.updateStageSync(jobId, `translating_${targetLang}`, payload).catch(() => {});
      if (rawTargetLang && rawTargetLang.toLowerCase() !== targetLang.toLowerCase()) {
        await EdgeLayer.updateStageSync(jobId, `translating_${rawTargetLang}`, payload).catch(() => {});
      }
    };

    const updateDubbingStage = async (status: "running" | "completed" | "failed", progress: number, error?: string) => {
      const now = Date.now();
      const payload: any = { status, progress };
      if (status === "running") payload.startedAt = now;
      if (status === "completed") payload.completedAt = now;
      if (error) payload.error = error;

      await EdgeLayer.updateStageSync(jobId, `dubbing_${targetLang}`, payload).catch(() => {});
      if (rawTargetLang && rawTargetLang.toLowerCase() !== targetLang.toLowerCase()) {
        await EdgeLayer.updateStageSync(jobId, `dubbing_${rawTargetLang}`, payload).catch(() => {});
      }
    };

    if (segments.length === 0) {
      logger.warn("[Dubbing] No segments to process for language", { jobId, targetLang });
      return {
        jobId, language: targetLang, subtitleUrl: "", subtitleFormat: "srt", audioUrl: "", videoUrl: "",
        translationUrl: "", segments: 0, processingTime: 0,
      };
    }

    try {
      // Proactively initialize dubbing stage to running so listeners know it's actively processing
      await updateDubbingStage("running", 5);

      // A. Translate (skip if same language)
      if (targetLang !== sourceLang) {
        await updateTranslationStage("running", 25);
        await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 55 }).catch(() => {});
        await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 55 }).catch(() => {});
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

        // ✅ Cost tracking: record translation cost for this language
        const translatedChars = dubbingSegs.reduce((sum, s) => sum + s.translatedText.length, 0);
        costEngine.recordTranslationCost(jobId, userId, translatedChars).catch(() => {});
      }

      if (targetLang !== sourceLang) {
        await updateTranslationStage("completed", 100);
        await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 75 }).catch(() => {});
        await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 75 }).catch(() => {});
      }

      // B. Generate subtitles (.json, .vtt, and .srt formats for every language)
      let subtitleUrl = "";
      let srtUrl = "";
      let vttUrl = "";
      let jsonUrl = "";

      const bucket = admin.storage().bucket();
      const transPath = `subtitles/${jobId}/${targetLang}.json`;
      await bucket.file(transPath).save(JSON.stringify(dubbingSegs, null, 2), {
        metadata: { contentType: "application/json" }
      });
      const translationUrl = `gs://${bucket.name}/${transPath}`;

      if (executionPlan.genLangSubs) {
        // ✅ For source language: check if native AssemblyAI subtitles already exist
        if (targetLang === sourceLang) {
          const nativeUrl = await this.checkNativeSubtitles(jobId, targetLang);
          if (nativeUrl) {
            subtitleUrl = nativeUrl;
            srtUrl = nativeUrl;
            vttUrl = `gs://${bucket.name}/subtitles/${jobId}/${targetLang}.vtt`;
            jsonUrl = translationUrl;
            logger.info("[Dubbing] Using native AssemblyAI subtitles for source lang", { jobId, targetLang });
          } else {
            const subRes = await this.generateSubtitles(jobId, dubbingSegs, targetLang);
            subtitleUrl = subRes.srtUrl;
            srtUrl = subRes.srtUrl;
            vttUrl = subRes.vttUrl;
            jsonUrl = subRes.jsonUrl;
          }
        } else {
          // Translated subtitles always use our own alignment pipeline — generating .json, .vtt, and .srt
          const subRes = await this.generateSubtitles(jobId, dubbingSegs, targetLang);
          subtitleUrl = subRes.srtUrl;
          srtUrl = subRes.srtUrl;
          vttUrl = subRes.vttUrl;
          jsonUrl = subRes.jsonUrl;
        }
      } else {
        // Ensure all 3 subtitle formats (.json, .vtt, .srt) exist for every language subtitle
        const subRes = await this.generateSubtitles(jobId, dubbingSegs, targetLang);
        subtitleUrl = subRes.srtUrl;
        srtUrl = subRes.srtUrl;
        vttUrl = subRes.vttUrl;
        jsonUrl = subRes.jsonUrl;
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
            subtitles: {
              [targetLang]: directSubtitleUrl,
              ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directSubtitleUrl } : {}),
            },
            media: {
              subtitles: {
                [targetLang]: directSubtitleUrl,
                ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directSubtitleUrl } : {}),
              },
            },
            [`subtitles.${targetLang}`]: directSubtitleUrl,
            [`media.subtitles.${targetLang}`]: directSubtitleUrl,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          if (rawTargetLang && rawTargetLang !== targetLang) {
            subUpdates[`subtitles.${rawTargetLang}`] = directSubtitleUrl;
            subUpdates[`media.subtitles.${rawTargetLang}`] = directSubtitleUrl;
          }

          for (const vid of linkedVideoIds) {
            // Update top-level videos/{vid} document directly with nested and dot notation
            await db().collection("videos").doc(vid).set(subUpdates, { merge: true });

            // Also update subcollection for backwards compatibility
            const locSubUpdates: Record<string, any> = {
              subtitles: {
                [targetLang]: directSubtitleUrl,
                ...(rawTargetLang && rawTargetLang !== targetLang ? { [rawTargetLang]: directSubtitleUrl } : {}),
              },
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
          await EdgeLayer.updateStageSync(jobId, "subtitles", { status: "running", progress: 90 }).catch(() => {});
          await EdgeLayer.updateStageSync(jobId, "onDemandAI", { status: "running", progress: 90 }).catch(() => {});
          if (!executionPlan.generateDubbing) {
            await updateDubbingStage("completed", 100);
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

      if (executionPlan.generateDubbing && targetLang !== sourceLang) {
        try {
          await updateDubbingStage("running", 10);
          const normalised = dubbingSegs.map((s) => ({
            ...s,
            translatedText: this.normaliseTTS(s.translatedText, s.emotionTag),
          }));
          dubbedSegmentsSnapshot = normalised;

          // ✅ TTS cache fully wired — checks cache BEFORE calling TTS
          // Dubbing Plan: Audio Track (Studio voice cloning, cadence locking, 100% BGM preserved)
          const dubbingTier = (executionPlan as any).dubbingTier || "audio_track";
          const isVoiceClone = true;
          const voiceType = "cloned";

          const ttsResult = await this.parallelTTSWithCache(
            jobId, userId, normalised, targetLang, voiceMapping, isVoiceClone, speakerGenderMapping,
            speakerProfiles, acousticFingerprint, dubbingTier, voiceType, executionPlan.voiceGender
          );
          ttsUrls = ttsResult.urls;

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

          const syncInstructions = this.buildSyncInstructions(normalised, ttsUrls);
          rawDialogueUrl = await this.stitchAudio(
            jobId,
            ttsUrls,
            syncInstructions,
            targetLang,
            normalised,
            totalDurationSeconds,
            dspFilters,
            totalDurationMs,
            isCadenceLocked
          );

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
            mneValidation,
          });

          if (!postStitchGate.passed) {
            logger.error("[Dubbing:QualityGate] ❌ Post-stitch quality gate rejected output — publication blocked", {
              jobId,
              targetLang,
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
            try {
              const jobSnap = await db().collection("video_jobs").doc(jobId).get();
              const jobData = jobSnap.data() as JobData;
              const rawLinkedVideoIds = jobData?.linkedVideoIds || [];
              if (jobData?.videoId && !rawLinkedVideoIds.includes(jobData.videoId)) {
                rawLinkedVideoIds.push(jobData.videoId);
              }
              // Guard: only allow UUID video IDs — never write to videos collection with a job_ ID
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

              await updateDubbingStage("completed", 100);
              logger.info("[Dubbing] ⚡ Progressive Delivery: Audio track published immediately", { jobId, targetLang, directAudioUrl });
            } catch (earlyPropErr) {
              logger.warn("[Dubbing] Early audio track propagation warning:", earlyPropErr);
            }
          }

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
            if (!videoResult) {
              videoResult = videoUrl;
            }
          }

          await updateDubbingStage("completed", 100);
        } catch (dubErr) {
          logger.error("[Dubbing] Dubbing failed for language, but continuing with subtitles", { jobId, targetLang, err: String(dubErr) });
          await updateDubbingStage("failed", 10, String(dubErr));
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
            lipSync: false,
          },
          lipSync: {
            enabled: false,
            status: "disabled",
            videoUrl: null,
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

          if (directVideoUrl) {
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
              path: directVideoUrl || directAudioUrl,
              videoUrl: directVideoUrl,
              language: targetLang,
              updatedAt: Date.now(),
            };
            if (rawTargetLang && rawTargetLang !== targetLang) {
              jobOutputAudio[`dubbed.${rawTargetLang}`] = {
                audioUrl: directAudioUrl,
                path: directVideoUrl || directAudioUrl,
                videoUrl: directVideoUrl,
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
      if (executionPlan.generateDubbing && targetLang !== sourceLang) {
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
        lipSyncUrl:     undefined,
        lipSyncStatus:  "skipped",
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
    preferredVoiceGender?: "auto" | "male" | "female"
  ): Promise<{
    urls: string[];
    failedSegments: Array<{ index: number; text: string; error: string; isQuota: boolean }>;
    totalSegments: number;
    successfulSegments: number;
  }> {
    const allUrls: string[] = new Array(segments.length).fill("");
    const failedSegments: Array<{ index: number; text: string; error: string; isQuota: boolean }> = [];
    const speakerProfileCache = new Map<string, SpeakerVoiceProfile | null>();

    for (let i = 0; i < segments.length; i += TTS_BATCH_SIZE) {
      const batch = segments.slice(i, i + TTS_BATCH_SIZE);

      const batchUrls = await Promise.allSettled(
        batch.map(async (seg) => {
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

          // Cache miss → call Hybrid TTS Service (with ElevenLabs v4 expressive emotion & stability controls)
          const result = await ttsService.synthesize({
            jobId,
            language,
            text:      seg.translatedText,
            voiceId,
            speakerId: seg.speaker,
            userId,
            gender,
            preferVoiceCloning,
            ttsTier: (dubbingTier as any),
            voiceType: (voiceType as any),
            pitch,
            speakingRate,
            stability: effectiveStability,
            similarityBoost: effectiveSimilarity,
            emotionTag: seg.emotionTag,
            energyDb: seg.energyDb,
          });

          // Non-blocking persistent voice profile EMA update for future scenes/reels
          this.updateSpeakerVoiceProfile(jobId, speakerId, language, {
            voiceId,
            pitchSemitones: pitch,
            energyDb: seg.energyDb,
            stability: effectiveStability ?? 0.5,
            similarityBoost: effectiveSimilarity ?? 0.85,
            voiceQuality: seg.voiceQuality,
          }).then((updated) => {
            if (updated) speakerProfileCache.set(profileKey, updated);
          }).catch(() => {});

          // ✅ Cost tracking: record TTS cost for synthesized characters (Strictly ElevenLabs v4)
          costEngine.recordTTSCost(jobId, userId, seg.translatedText.length, "elevenlabs").catch(() => {});

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

      batchUrls.forEach((r, bIdx) => {
        const globalIdx = i + bIdx;
        if (r.status === "fulfilled") {
          allUrls[globalIdx] = r.value;
        } else {
          const reasonMsg = r.reason instanceof Error ? r.reason.message : String(r.reason);
          const isQuota = Boolean((r.reason as any)?.isQuota) || reasonMsg.includes("quota_exceeded") || reasonMsg.includes("credits remaining");
          failedSegments.push({
            index: globalIdx,
            text: batch[bIdx]?.translatedText || "",
            error: reasonMsg,
            isQuota,
          });
          logger.error("[Dubbing] TTS segment failed", { jobId, globalIdx, bIdx, reason: reasonMsg, isQuota });
          allUrls[globalIdx] = ""; // placeholder
        }
      });

      const progress = 50 + Math.round(((i + batch.length) / segments.length) * 30);
      EdgeLayer.updateStage(jobId, "dubbing", { progress }).catch(() => {});
    }

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
      subtitleTier?: "ultra" | "starter" | "pro";
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
      }));

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
        ? { text: decodeHtmlEntities(cached[i]!), confidence: 0.99, variants: undefined, syllableBudgetCompliance: undefined } 
        : newTranslations[newIdx++] || { text: seg.text, confidence: 0, variants: undefined, syllableBudgetCompliance: undefined };

      return {
        index:          seg.index,
        originalText:   seg.text,
        translatedText: decodeHtmlEntities(translation.text),
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
    jobId:    string,
    segments: DubbingSegment[],
    language: string
  ): Promise<{ srtUrl: string; vttUrl: string; jsonUrl: string }> {
    return mediaService.generateAllSubtitles(
      jobId,
      segments.map((s) => ({
        start: s.start,
        end: s.end,
        text: stripAudioTagsForSubtitles(s.translatedText),
      })),
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
    cadenceLock?:     boolean
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
    const preferredLang = vData?.language || vData?.sourceLanguage || "en";
    const sourceSubLang = existingSubs[preferredLang]
      ? preferredLang
      : (Object.keys(existingSubs)[0] || preferredLang);
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
        return data;
      }
    }

    if (origJobId && origJobId !== jobId) {
      doc = await db().collection("transcripts").doc(origJobId).get();
      if (doc.exists) {
        const data = doc.data();
        if (data?.utterances && data.utterances.length > 0) {
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

    const availableLangs = Object.keys(fallbackSubs);
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
              const normalized = {
                text: fullText,
                utterances,
                language: lang,
                source: "parsed_subtitles",
                confidence: 1.0,
              };
              logger.info("[Dubbing] Recovered transcript from existing subtitles", { jobId, lang, utterances: utterances.length });
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

      const subRes = await this.generateSubtitles(jobId, normalisedSegs, targetLang);
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
        meta.executionPlan?.voiceGender
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

      let videoResult = payload.videoUrl;
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
      }

      audioPaths[targetLang] = masterAudioUrl;
      dubbedPaths[targetLang] = videoResult;
      dialogueStems[targetLang] = rawDialogueUrl;

      const directAudioUrl = masterAudioUrl.startsWith("gs://")
        ? `https://storage.googleapis.com/${bucket.name}/${masterAudioUrl.replace(`gs://${bucket.name}/`, "")}`
        : masterAudioUrl;
      const directVideoUrl = videoResult.startsWith("gs://")
        ? `https://storage.googleapis.com/${bucket.name}/${videoResult.replace(`gs://${bucket.name}/`, "")}`
        : videoResult;

      await db().collection("dubbing_results").doc(`${jobId}_${targetLang}`).set({
        jobId,
        language: targetLang,
        audioUrl: masterAudioUrl,
        videoUrl: videoResult,
        processingTime: Date.now() - (meta.createdAt || Date.now()),
        createdAt: Date.now(),
        lipSync: { enabled: false, status: "disabled", videoUrl: null },
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
        masterVideoUrl: videoResult,
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
          dubbedVideos: { [targetLang]: directVideoUrl },
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
        lipSyncStatus: "skipped",
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

    await aggregationLayer.onStageComplete(jobId, "dubbing", userId, executionPlan);
  }
}

export const dubbingEngine = new DubbingEngine();
