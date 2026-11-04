/**
 * 🌍 LAYER 07 — DUBBING ENGINE (PATH 2)
 *
 * Translation + TTS + video merge. Full parallel execution per language and per segment.
 *
 * ✅ UPGRADED PIPELINE:
 *   - Translation: Google Cloud Translation v3 (TranslationServiceClient) with v2 fallback
 *   - TTS: Google Cloud Text-to-Speech (Neural2 / Journey / Studio / Standard) with ElevenLabs voice cloning & automatic fallback
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
import { v4 as uuidv4 } from "uuid";
import {
  ExecutionPlan,
  DubbingResult,
  DubbingSegment,
  SyncInstruction,
  TimedSegment,
  DubbingCompleteData,
  JobData,
} from "../types";
import { translationService, decodeHtmlEntities } from "../services/translation";
import { ttsService }         from "../services/tts";
import { mediaService, parseDurationToSeconds } from "../services/media";
import { lipSyncService } from "../services/lipSyncService";
import { ELEVENLABS_VOICE_GENDER_MAP, ELEVENLABS_MULTI_SPEAKER_PALETTE } from "../services/googleTextToSpeechService";
import { costEngine, getFlatDubbingPricePerLanguage } from "../services/cost-engine";
import { speakerProfilingService } from "../services/speaker-profiling";
import { audioIdentityService } from "../services/audio-identity";
import { DistributionLayer }  from "./04-distribution";
import { EdgeLayer }          from "./01-edge";
import { aggregationLayer }   from "./09-aggregation";
import { PerformanceLayer }   from "./10-performance";
import { creatorStyleService } from "../services/creatorStyleService";
import { refundDubbingFeeOnFailure, creditLipSyncFallbackToWallet } from "../services/refundService";
import { logger }             from "../utils/logger";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import { filterVideoIds } from "../../utils/videosCollectionGuard";

const db = () => admin.firestore();

/** Max segments processed concurrently per TTS batch */
const TTS_BATCH_SIZE = 25;

/** Words per second assumed for TTS timing estimation */
const TTS_WPS = 2.5;

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
    logger.info("[ReachEngine] Starting Path 2", {
      jobId,
      languages: executionPlan.languages.length,
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
        logger.error(`[Dubbing] Cloud timeout guard reached (${seconds}s)`, { jobId });
        await EdgeLayer.failJob(jobId, "dubbing", `Dubbing processing reached maximum cloud engine duration (${seconds}s)`).catch(() => {});
        reject(new Error(`Dubbing processing reached maximum cloud engine duration (${seconds}s)`));
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

      // 1.2. Stitch incomplete segments (Phase 3 Premium Polish)
      const rawSegments: TimedSegment[] = (transcript.utterances ?? []).map(
        (u: any, i: number) => ({
          index:    i,
          text:     u.text,
          start:    u.start,
          end:      u.end,
          duration: u.end - u.start,
          speaker:  u.speaker,
          words:    [],
        })
      );

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
            logger.warn("[Dubbing] Neural vocal isolation notice, using original audio as fallback:", err);
            return originalAudioUrl;
          });
          acousticFingerprint = await audioIdentityService.captureFingerprint(jobId, isolatedVocalUrl || originalAudioUrl);
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

          logger.info("[Dubbing] Extracting Music & Effects (M&E) stem for non-destructive preservation", { jobId, sourceAudio });
          mneStemUrl = await mediaService.extractMneStem(jobId, sourceAudio, {
            isolatedVocalUrl: (isolatedVocalUrl && isolatedVocalUrl !== sourceAudio) ? isolatedVocalUrl : undefined,
          });
          logger.info("[Dubbing] ✅ M&E stem preserved successfully", { jobId, mneStemUrl });
        } catch (mneErr) {
          logger.warn("[Dubbing] M&E stem preservation notice (proceeding gracefully):", mneErr);
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
            isolatedVocalUrl
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

      // 🛡️ Auto-Credit on no_face_detected / fallback_remux:
      // If a video falls back to audio-only remux because of screen shares (no on-screen face)
      // or GPU worker limits, automatically credit the $2.50 lip-sync delta per language
      // back to the creator's wallet, and notify the channel in Studio.
      if (executionPlan.enableLipSync) {
        const lipSyncFallbacks: Array<{ language: string; status: "no_face_detected" | "fallback_remux" }> = [];
        for (const res of dubbingResults) {
          if (res.lipSyncStatus === "no_face_detected" || res.lipSyncStatus === "fallback_remux") {
            lipSyncFallbacks.push({
              language: res.language,
              status: res.lipSyncStatus,
            });
          }
        }

        if (lipSyncFallbacks.length > 0) {
          // Dynamic calculation of delta per language based on tier and duration
          const videoDurationSeconds = (transcript.utterances?.length)
            ? Math.max(10, Math.round(transcript.utterances[transcript.utterances.length - 1].end))
            : 60;
          const durationMinutes = Math.max(1, videoDurationSeconds / 60);
          const dynamicDelta = Number((durationMinutes * 0.20).toFixed(2));

          logger.info("[Dubbing] AI Lip-Sync fallback detected — auto-crediting lip-sync delta per language to channel wallet", {
            jobId,
            fallbacksCount: lipSyncFallbacks.length,
            lipSyncFallbacks,
            dubbingTier: executionPlan.dubbingTier,
            dynamicDelta,
          });
          await creditLipSyncFallbackToWallet({
            jobId,
            userId,
            fallbackLanguages: lipSyncFallbacks,
            deltaPerLanguageUSD: dynamicDelta,
            dubbingTier: executionPlan.dubbingTier,
            durationSeconds: videoDurationSeconds,
          }).catch((creditErr) => logger.error("[Dubbing] Auto-credit for lip-sync fallback error:", creditErr));
        }
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

      await aggregationLayer.onStageComplete(jobId, "dubbing", userId, executionPlan);

      logger.info("[ReachEngine] Completed", {
        jobId,
        languages: dubbingResults.length,
        ms:        Date.now() - t0,
      });
      await this.distribution.markEventCompleted(eventId);

      await db().collection("video_jobs").doc(jobId).set({
        status: "completed",
        progress: 100,
        stages: {
          dubbing: {
            status: executionPlan.generateDubbing ? "completed" : "skipped",
            progress: 100,
            completedAt: Date.now(),
          },
          subtitles: {
            status: "completed",
            progress: 100,
            completedAt: Date.now(),
          },
          onDemandAI: {
            status: "completed",
            progress: 100,
            completedAt: Date.now(),
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

      await EdgeLayer.failJob(jobId, "dubbing", errMsg);
      await db().collection("video_jobs").doc(jobId).set({
        status: "failed",
        stages: {
          dubbing: {
            status: "failed",
            error: errMsg,
            failedAt: Date.now(),
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
    isolatedVocalUrl?: string | null
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
        const subTier = executionPlan.subtitleTier || (executionPlan.channelType === 'custom' ? 'pro' : 'starter');
        const currentDubbingTier = (executionPlan as any).dubbingTier || "audio_starter";
        dubbingSegs = await this.translateWithCache(
          jobId, segments, sourceLang, targetLang,
          { 
            model: 'premium', // All 5 tiers use the hybrid Google v3 + Gemini architecture (Flash for starter/pro, Argon for ultra/video)
            tone: executionPlan.toneMode,
            localeStyle: executionPlan.localeStyle,
            targetPlatform: executionPlan.targetPlatform,
            creatorDNA,
            enableABHooks: executionPlan.enableABHooks ?? true, // Default to true for premium
            speakerProfiles,
            dubbingTier: currentDubbingTier,
            subtitleTier: subTier,
            isCinemaGrade: subTier === 'pro' || currentDubbingTier === "video_ultra" || currentDubbingTier === "video_pro" || currentDubbingTier === "audio_ultra" || Boolean((executionPlan as any).cinemaProduction),
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
      let masterAudioUrl   = "";
      let lipSyncStatus: string | undefined = undefined;

      if (executionPlan.generateDubbing && targetLang !== sourceLang) {
        try {
          await updateDubbingStage("running", 10);
          const normalised = dubbingSegs.map((s) => ({
            ...s,
            translatedText: this.normaliseTTS(s.translatedText),
          }));

          // ✅ TTS cache fully wired — checks cache BEFORE calling TTS
          // Tiered Dubbing: Route based on Audio Starter, Audio Pro, Audio Ultra, Video Pro, Video Ultra
          const dubbingTier = (executionPlan as any).dubbingTier || "audio_starter";
          const isVoiceClone = dubbingTier === "audio_ultra" || dubbingTier === "video_pro" || dubbingTier === "video_ultra" || executionPlan.dubbingMode === "voice_clone";
          const isAudioPro = dubbingTier === "audio_pro";
          const voiceType = isVoiceClone ? "cloned" : (isAudioPro ? "fast_api" : "standard");

          const ttsUrls = await this.parallelTTSWithCache(
            jobId, userId, normalised, targetLang, voiceMapping, isVoiceClone, speakerGenderMapping,
            speakerProfiles, acousticFingerprint, dubbingTier, voiceType, executionPlan.voiceGender
          );

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

          // Studio Mastering: Apply Acoustic Identity via DSP Rules Engine
          const dspFilters = acousticFingerprint
            ? audioIdentityService.getDSPFilters(acousticFingerprint)
            : "loudnorm=I=-14:TP=-1:LRA=11";
          logger.info("[Dubbing] Applying DSP mastering chain to audio track", { jobId, targetLang });

          const isCadenceLocked = dubbingTier === "audio_ultra" || 
            (executionPlan as any)?.isometryMode === "strict_syllable" || 
            (executionPlan as any)?.uncannyMitigation === "cadence_lock";

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
              const sourceAudio = jobDoc.data()?.artifacts?.transcription?.audioUrl || videoUrl;
              logger.info("[Dubbing] Guaranteed M&E extraction for tier", { jobId, targetLang, tier: executionPlan.dubbingTier });
              mneStemUrl = await mediaService.extractMneStem(jobId, sourceAudio, {
                isolatedVocalUrl: (isolatedVocalUrl && isolatedVocalUrl !== sourceAudio) ? isolatedVocalUrl : undefined,
              });
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
                audioFilters: dspFilters,
              });
              logger.info("[Dubbing] ✅ Non-destructive M&E + Dubbed master mix created", { jobId, targetLang, masterAudioUrl });
            } catch (mixErr) {
              logger.warn("[Dubbing] M&E mix notice, falling back to dialogue audio:", mixErr);
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
            if (executionPlan.enableLipSync) {
              logger.info("[Dubbing] AI Visual Lip-Sync requested. Engaging GPU LatentSync engine...", { 
                jobId, 
                targetLang, 
                tier: executionPlan.dubbingTier || "video_pro",
                cinemaGrade: executionPlan.cinemaGrade || executionPlan.dubbingTier === "video_ultra" 
              });
              const isCinemaUltra = executionPlan.dubbingTier === "video_ultra" || Boolean(executionPlan.cinemaGrade);
              const lipSyncRes = await lipSyncService.synchronizeLips({
                jobId,
                videoUrl,
                audioUrl: rawDialogueUrl || masterAudioUrl || audioUrl,
                masterAudioUrl: masterAudioUrl || audioUrl,
                language: targetLang,
                mode: executionPlan.lipSyncMode || "latentsync",
                dubbingTier: executionPlan.dubbingTier,
                cinemaGrade: isCinemaUltra,
                tier: isCinemaUltra ? "video_ultra" : "video_pro",
                qualityMode: isCinemaUltra ? "ultra" : "pro",
                subtitleUrl: executionPlan.genLangSubs ? subtitleUrl : undefined,
                audioFilters: dspFilters,
                isPreMastered: masterAudioUrl !== rawDialogueUrl,
              });
              videoResult = lipSyncRes.videoUrl || videoResult || videoUrl;
              lipSyncStatus = lipSyncRes.status;
            } else {
              videoResult = await mediaService.mergeAudioToVideo({
                jobId, videoUrl, audioUrl, 
                subtitleUrl: executionPlan.genLangSubs ? subtitleUrl : undefined,
                language: targetLang, format: "mp4",
                audioFilters: dspFilters, // Pass the mastering chain to FFmpeg
                isPreMastered: masterAudioUrl !== rawDialogueUrl,
              });
            }
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
            lipSync: Boolean(executionPlan.enableLipSync),
          },
          lipSync: {
            enabled: Boolean(executionPlan.enableLipSync),
            status: lipSyncStatus || (executionPlan.enableLipSync ? "fallback_remux" : "disabled"),
            videoUrl: executionPlan.enableLipSync ? (videoResult || null) : null,
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
        lipSyncUrl:     executionPlan.enableLipSync ? (videoResult || undefined) : undefined,
        lipSyncStatus:  lipSyncStatus as any,
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
  ): Promise<string[]> {
    const allUrls: string[] = new Array(segments.length).fill("");

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

          // Cache miss → call Hybrid TTS Service
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
          });

          // ✅ Cost tracking: record TTS cost for synthesized characters
          const ttsProvider = result.provider === "elevenlabs"
            ? (dubbingTier === "audio_pro" || voiceType === "fast_api" ? "elevenlabs-turbo" : "elevenlabs")
            : (result.voiceName?.includes("-Chirp") ? "google-tts-chirp3-hd" : "google-tts-neural2");
          costEngine.recordTTSCost(jobId, userId, seg.translatedText.length, ttsProvider).catch(() => {});

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
          logger.error("[Dubbing] TTS segment failed", { jobId, bIdx, reason: r.reason });
          allUrls[globalIdx] = ""; // placeholder
        }
      });

      const progress = 50 + Math.round(((i + batch.length) / segments.length) * 30);
      EdgeLayer.updateStage(jobId, "dubbing", { progress }).catch(() => {});
    }

    return allUrls;
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
      dubbingTier?: "audio_starter" | "audio_pro" | "audio_ultra" | "video_pro" | "video_ultra";
      subtitleTier?: "starter" | "pro";
      isCinemaGrade?: boolean;
    }
  ): Promise<DubbingSegment[]> {
    const texts  = segments.map((s) => s.text);
    const cached = await this.performanceLayer.checkTranslationCache(
      texts, sourceLang, targetLang
    );

    const toTranslate = segments.filter((_, i) => !cached[i]);
    let newTranslations: Array<{ text: string; confidence?: number; variants?: any }> = [];

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
        })),
        sourceLang,
        targetLang,
        options
      );
      newTranslations = res.segments.map((s: any) => ({
        text: s.translated,
        confidence: s.confidence,
        variants: s.variants,
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
        ? { text: decodeHtmlEntities(cached[i]!), confidence: 0.99, variants: undefined } 
        : newTranslations[newIdx++] || { text: seg.text, confidence: 0, variants: undefined };

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
      };
    });
  }

  // ─── Sync engine ─────────────────────────────────────────────────────────────

  private buildSyncInstructions(
    segments:  DubbingSegment[],
    audioUrls: string[]
  ): SyncInstruction[] {
    return segments.map((seg, i) => {
      // 🧠 Phase-Level Pacing: Instead of crude stretch, align to original emphasis arcs
      const words            = seg.translatedText.split(/\s+/).length;
      const estimatedMs      = (words / TTS_WPS) * 1000;
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
      segments.map((s) => ({ start: s.start, end: s.end, text: s.translatedText })),
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

  private normaliseTTS(text: string): string {
    return text
      .replace(/\s+/g, " ")
      .replace(/[""]/g, '"')
      .replace(/['']/g, "'")
      .replace(/\.{3,}/g, "…")
      .replace(/\([^)]*\)/g, "")
      .replace(/\[[^\]]*\]/g, "")
      .trim();
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
    const subUrlToUse = existingSubs[preferredLang] || Object.values(existingSubs)[0];

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
              language: preferredLang,
              source: "creator_edited_subtitles",
              confidence: 1.0,
            };
            logger.info("[Dubbing] Loaded verified creator-edited subtitles as transcript source", { jobId, lang: preferredLang, utterances: utterances.length });
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
}

export const dubbingEngine = new DubbingEngine();
