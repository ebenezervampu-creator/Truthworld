/**
 * TruthWorld Interactive Creator Dubbing Editor Service
 *
 * Powers timeline line editing, per-segment vocal emotion/stability tuning,
 * custom pronunciation glossary overrides, single-line ElevenLabs v4 re-synthesis,
 * and non-destructive full-track remastering onto existing M&E stems.
 */

import * as admin from "firebase-admin";
import * as os from "os";
import * as path from "path";
import * as fs from "fs";
import { HttpsError } from "firebase-functions/v2/https";
import {
  DubbingEditableManifest,
  DubbingEditableSegment,
  PronunciationRule,
} from "../types";
import {
  ttsService,
  VALID_ELEVENLABS_AUDIO_TAGS,
  stripAudioTagsForSubtitles,
} from "./tts";
import {
  applyTeluguTheologicalLexiconGuard,
  computeSyllableBudgetCompliance,
  decodeHtmlEntities,
  normalizeScriptureCitationsForTts,
  sanitizeSpokenTranslationForTts,
  translationService,
} from "./translation";
import {
  permissibleWindowMs as computePermissibleWindowMs,
} from "./speech-rate";
import { SubtitleGuardrails } from "./subtitleGuardrails";
import { conformCues } from "./netflixSubtitleConformer";
import {
  calculateMinInterCueGapMs,
  getSubtitleProfile,
} from "./subtitle_language_profiles";
import type { LocalizedSubtitleCue } from "./subtitle_readability_validator";
import { expressiveV4Bus } from "./expressiveV4Bus";
import { estimateSpeechDurationMs } from "../layers/07-dubbing";
import { mediaService, parseAnyStorageUrl } from "./media";
import { audioIdentityService } from "./audio-identity";
import { DubbingQualityGate } from "../layers/quality-gate";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import {
  filterVideoIds,
  isVideoId,
  safeMergeExistingVideo,
} from "../../utils/videosCollectionGuard";
import { logger } from "../utils/logger";
import { TerminologyService } from "./terminology_glossary";
import { hlsPackagerService } from "./hlsPackager";
import { NumericalEntityGuard } from "./numericalEntityGuard";
import { adaptiveMtDatasetService } from "./adaptiveMtDatasetService";
import { saveDubbingReportArtifact, saveTranslationArtifact } from "./dubbing-report";

const db = () => admin.firestore();

export class DubbingEditorService {
  private async authorizeAndResolveJobId(params: {
    jobId?: string;
    videoId?: string;
    language: string;
    uid: string;
    isAdmin?: boolean;
  }): Promise<{ jobId: string; videoId?: string; jobData: Record<string, any> }> {
    const normLang = normalizeLanguageCode(params.language);
    let resolvedJobId = params.jobId?.trim();
    let resolvedVideoId = params.videoId?.trim();

    if (!resolvedJobId && resolvedVideoId) {
      const videoSnap = await db().collection("videos").doc(resolvedVideoId).get();
      if (videoSnap.exists) {
        const vData = videoSnap.data() || {};
        const manifestIdx = vData.dubbingManifests?.[normLang] || vData.dubbingManifests?.[params.language];
        if (manifestIdx?.jobId) {
          resolvedJobId = String(manifestIdx.jobId);
        }
      }

      if (!resolvedJobId) {
        const jobsQuery = await db()
          .collection("video_jobs")
          .where("videoId", "==", resolvedVideoId)
          .limit(5)
          .get();
        if (!jobsQuery.empty) {
          const sorted = jobsQuery.docs
            .map((d) => ({ id: d.id, updatedAt: Number(d.data()?.updatedAt || d.data()?.createdAt || 0) }))
            .sort((a, b) => b.updatedAt - a.updatedAt);
          resolvedJobId = sorted[0]?.id;
        }
      }
    }

    if (!resolvedJobId) {
      throw new HttpsError(
        "not-found",
        "No dubbing session was found for this video and language."
      );
    }

    const jobSnap = await db().collection("video_jobs").doc(resolvedJobId).get();
    if (!jobSnap.exists) {
      throw new HttpsError("not-found", "The requested dubbing job could not be found.");
    }

    const jobData = jobSnap.data() || {};
    if (!resolvedVideoId && typeof jobData.videoId === "string") {
      resolvedVideoId = jobData.videoId;
    }

    const jobOwner = typeof jobData.userId === "string" ? jobData.userId : "";
    let isOwner = jobOwner === params.uid;

    if (!isOwner && resolvedVideoId) {
      const videoSnap = await db().collection("videos").doc(resolvedVideoId).get();
      if (videoSnap.exists) {
        const vOwner = videoSnap.data()?.userId;
        if (vOwner === params.uid) isOwner = true;
      }
    }

    if (!isOwner && !params.isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to edit dubbing tracks for this video."
      );
    }

    return { jobId: resolvedJobId, videoId: resolvedVideoId, jobData };
  }

  private async toPlayableUrls(manifest: DubbingEditableManifest): Promise<DubbingEditableManifest> {
    const resolvedMasterAudioUrl = manifest.masterAudioUrl
      ? await audioIdentityService.getAccessibleUrl(manifest.masterAudioUrl).catch(() => manifest.masterAudioUrl)
      : manifest.masterAudioUrl;

    const segments = await Promise.all(
      manifest.segments.map(async (seg) => ({
        ...seg,
        synthesizedAudioUrl: seg.synthesizedAudioUrl
          ? await audioIdentityService.getAccessibleUrl(seg.synthesizedAudioUrl).catch(() => seg.synthesizedAudioUrl)
          : undefined,
      }))
    );

    return {
      ...manifest,
      masterAudioUrl: resolvedMasterAudioUrl,
      segments,
    };
  }

  public async getManifest(params: {
    jobId?: string;
    videoId?: string;
    language: string;
    uid: string;
    isAdmin?: boolean;
  }): Promise<DubbingEditableManifest> {
    const normLang = normalizeLanguageCode(params.language);
    const { jobId } = await this.authorizeAndResolveJobId(params);

    const manifestRef = db()
      .collection("video_jobs")
      .doc(jobId)
      .collection("dubbing_manifests")
      .doc(normLang);

    const snap = await manifestRef.get();
    if (!snap.exists) {
      throw new HttpsError(
        "not-found",
        "This dubbed track does not have an interactive segment manifest yet."
      );
    }

    const manifest = snap.data() as DubbingEditableManifest;
    return this.toPlayableUrls(manifest);
  }

  private async consumeEditorQuota(
    manifestRef: FirebaseFirestore.DocumentReference,
    params: {
      kind: "regenerate" | "retranslate" | "remaster";
      isAdmin?: boolean;
      segmentIndex?: number;
      originalText?: string;
      editedText?: string;
    }
  ): Promise<void> {
    if (params.isAdmin) return;

    if (params.kind === "regenerate" && typeof params.editedText === "string") {
      const maxLen = Math.max(120, (params.originalText || "").length * 3);
      if (params.editedText.length > maxLen) {
        throw new HttpsError(
          "invalid-argument",
          `Edited line is too long (${params.editedText.length} chars; maximum ${maxLen} chars allowed).`
        );
      }
    }

    await db().runTransaction(async (tx) => {
      const snap = await tx.get(manifestRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Editable dubbing manifest not found.");
      }
      const data = snap.data() || {};
      if (params.kind === "regenerate") {
        const total = Number(data.regenerationCount || 0);
        if (total >= 50) {
          throw new HttpsError(
            "resource-exhausted",
            "Maximum line regenerations (50) reached for this dubbed track."
          );
        }
        const segKey = String(params.segmentIndex ?? 0);
        const segCounts = (data.segmentRegenerationCounts || {}) as Record<string, number>;
        const segCount = Number(segCounts[segKey] || 0);
        if (segCount >= 5) {
          throw new HttpsError(
            "resource-exhausted",
            "Maximum regenerations (5) reached for this line."
          );
        }
        tx.update(manifestRef, {
          regenerationCount: total + 1,
          [`segmentRegenerationCounts.${segKey}`]: segCount + 1,
        });
      } else if (params.kind === "retranslate") {
        const total = Number(data.retranslationCount || 0);
        if (total >= 50) {
          throw new HttpsError(
            "resource-exhausted",
            "Maximum AI retranslations (50) reached for this dubbed track."
          );
        }
        tx.update(manifestRef, {
          retranslationCount: total + 1,
        });
      } else if (params.kind === "remaster") {
        const total = Number(data.remasterCount || 0);
        if (total >= 10) {
          throw new HttpsError(
            "resource-exhausted",
            "Maximum audio remasters (10) reached for this dubbed track."
          );
        }
        tx.update(manifestRef, {
          remasterCount: total + 1,
        });
      }
    });
  }

  public async updateSegmentAndResynthesize(params: {
    jobId: string;
    language: string;
    segmentIndex: number;
    uid: string;
    isAdmin?: boolean;
    editedText?: string;
    emotionTag?: string | null;
    stabilityOverride?: number;
    similarityBoostOverride?: number;
    voiceId?: string;
    speedMultiplier?: number;
  }): Promise<{
    segment: DubbingEditableSegment;
    version: number;
    subtitleUrl?: string;
    playableAudioUrl?: string;
    terminologyWarning?: string;
  }> {
    const normLang = normalizeLanguageCode(params.language);
    const { jobId, jobData } = await this.authorizeAndResolveJobId({
      jobId: params.jobId,
      language: normLang,
      uid: params.uid,
      isAdmin: params.isAdmin,
    });

    const manifestRef = db()
      .collection("video_jobs")
      .doc(jobId)
      .collection("dubbing_manifests")
      .doc(normLang);

    const snap = await manifestRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Editable dubbing manifest not found.");
    }

    const manifest = snap.data() as DubbingEditableManifest;
    const targetIdx = manifest.segments.findIndex((s) => s.index === params.segmentIndex);
    if (targetIdx === -1) {
      throw new HttpsError("invalid-argument", "Requested segment index does not exist in this track.");
    }

    const existingSeg = manifest.segments[targetIdx];
    const nextTextRaw =
      typeof params.editedText === "string" && params.editedText.trim().length > 0
        ? params.editedText.trim()
        : (existingSeg.editedText || existingSeg.translatedText);

    await this.consumeEditorQuota(manifestRef, {
      kind: "regenerate",
      isAdmin: params.isAdmin,
      segmentIndex: params.segmentIndex,
      originalText: existingSeg.originalText,
      editedText: nextTextRaw,
    });

    let nextEmotion = existingSeg.emotionTag;
    if (params.emotionTag === null || params.emotionTag === "") {
      nextEmotion = undefined;
    } else if (typeof params.emotionTag === "string") {
      const normalized = params.emotionTag.toLowerCase().trim();
      if (!VALID_ELEVENLABS_AUDIO_TAGS.has(normalized)) {
        throw new HttpsError("invalid-argument", "Unsupported emotion delivery tag.");
      }
      nextEmotion = normalized;
    }

    const nextStability =
      typeof params.stabilityOverride === "number" && Number.isFinite(params.stabilityOverride)
        ? Number(Math.max(0, Math.min(1, params.stabilityOverride)).toFixed(2))
        : existingSeg.stabilityOverride;

    const nextSimilarity =
      typeof params.similarityBoostOverride === "number" && Number.isFinite(params.similarityBoostOverride)
        ? Number(Math.max(0, Math.min(1, params.similarityBoostOverride)).toFixed(2))
        : existingSeg.similarityBoostOverride;

    const nextVoiceId =
      typeof params.voiceId === "string" && params.voiceId.trim().length > 0
        ? params.voiceId.trim()
        : existingSeg.voiceId;

    // 🛡️ Guardrail 3: Included Edit Quota Enforcement (protects $1.15 COGS floor)
    const currentRegenCount = manifest.regenerationCount || 0;
    const maxFreeRegens = Math.max(20, Math.ceil((manifest.totalDurationMs || 60000) / 30000) * 2);
    if (currentRegenCount >= maxFreeRegens && !params.isAdmin) {
      throw new HttpsError(
        "resource-exhausted",
        `You have reached your included allowance of ${maxFreeRegens} line regenerations for this video. Remaster and publish your current track or contact support for extended studio allowance.`
      );
    }

    let textToVocalize = sanitizeSpokenTranslationForTts(nextTextRaw);
    if (normLang === "te") {
      textToVocalize = applyTeluguTheologicalLexiconGuard(textToVocalize);
    }
    textToVocalize = normalizeScriptureCitationsForTts(textToVocalize, normLang);

    // ── Checkpoint B: Creator DAW Override - Terminology & Numerical Parity Check ──
    const compCheck = TerminologyService.checkTerminologyCompliance(
      existingSeg.originalText || "",
      nextTextRaw,
      normLang
    );
    const numParity = NumericalEntityGuard.verifyNumericalParity(
      existingSeg.originalText || "",
      nextTextRaw,
      normLang
    );

    let terminologyWarning: string | undefined = undefined;
    if (compCheck.violations.length > 0) {
      const v = compCheck.violations[0];
      terminologyWarning = `Non-compliant term "${v.disallowedFound}" detected. Recommended: "${v.suggested}".`;
      logger.warn("[DubbingEditor] Terminology violation in creator manual line edit", {
        jobId,
        segmentIndex: params.segmentIndex,
        language: normLang,
        violations: compCheck.violations.map((viol) => `${viol.disallowedFound} -> ${viol.suggested}`),
      });
    }

    let numericalParityWarning: string | undefined = undefined;
    if (!numParity.isParity) {
      numericalParityWarning = numParity.details;
      const numAlert = `Numerical discrepancy detected: The original stated "${existingSeg.originalText}". Your edit may alter factual numbers.`;
      terminologyWarning = terminologyWarning ? `${terminologyWarning} ${numAlert}` : numAlert;
      logger.warn("[DubbingEditor] Numerical parity drift in creator manual line edit", {
        jobId,
        segmentIndex: params.segmentIndex,
        language: normLang,
        details: numParity.details,
      });
    }

    // 🛡️ Guardrail 1: Re-Run Rule 2c/2d & Lexical Guards on Single-Segment Resynthesis
    const prevSeg = targetIdx > 0 ? manifest.segments[targetIdx - 1] : undefined;
    const nextSeg = manifest.segments[targetIdx + 1];

    // 🛡️ Guardrail 3: Context-Windowing Gate — Same-speaker adjacent turns within 2.5s gap
    const prevGapMs = (prevSeg && existingSeg.startMs !== undefined && prevSeg.endMs !== undefined)
      ? (existingSeg.startMs - prevSeg.endMs)
      : Infinity;
    const isPrevSameSpeaker = Boolean(prevSeg && prevSeg.speaker && existingSeg.speaker && prevSeg.speaker === existingSeg.speaker);
    const gatedPrevText = (isPrevSameSpeaker && prevGapMs >= 0 && prevGapMs <= 2500)
      ? (prevSeg?.editedText || prevSeg?.translatedText)
      : undefined;

    const nextGapMs = (nextSeg && nextSeg.startMs !== undefined && existingSeg.endMs !== undefined)
      ? (nextSeg.startMs - existingSeg.endMs)
      : Infinity;
    const isNextSameSpeaker = Boolean(nextSeg && nextSeg.speaker && existingSeg.speaker && nextSeg.speaker === existingSeg.speaker);
    const gatedNextText = (isNextSameSpeaker && nextGapMs >= 0 && nextGapMs <= 2500)
      ? (nextSeg?.editedText || nextSeg?.translatedText)
      : undefined;

    const totalDurMs = manifest.totalDurationMs || 0;
    const hardCeilingMs = nextSeg
      ? Math.max(existingSeg.startMs + 200, nextSeg.startMs - 120)
      : (totalDurMs > existingSeg.startMs ? totalDurMs - 150 : existingSeg.endMs + 3000);
    const permissibleWindowMs = Math.max(200, hardCeilingMs - existingSeg.startMs);
    const estDurMs = estimateSpeechDurationMs(textToVocalize, normLang);
    const maxPermissibleDuration = permissibleWindowMs * 1.15; // atempo compression limit
    if (estDurMs > maxPermissibleDuration + 800) {
      throw new HttpsError(
        "invalid-argument",
        `Edited dialogue is too long for this speech window (${(estDurMs / 1000).toFixed(1)}s estimated vs ${(permissibleWindowMs / 1000).toFixed(1)}s available). Please tighten phrasing to prevent turn collision.`
      );
    }

    const isJobVoiceClone = jobData?.executionPlan?.dubbingMode === "voice_clone";
    const voiceType = isJobVoiceClone ? "cloned" : "standard";

    const busPayload = expressiveV4Bus.processSegment({
      jobId,
      language: normLang,
      translatedText: textToVocalize,
      sourceText: existingSeg.originalText,
      telemetry: {
        energyDb: existingSeg.energyDb,
        pitchRangeSemitones: existingSeg.pitchRangeSemitones,
        speakingRateRatio: (existingSeg as any).speakingRateRatio,
        emotionTag: nextEmotion,
        deliveryStyle: (existingSeg as any).deliveryStyle,
        voiceQuality: existingSeg.voiceQuality as any,
        stabilityOverride: nextStability,
        similarityBoostOverride: nextSimilarity,
      },
      preferVoiceCloning: isJobVoiceClone,
      voiceType: voiceType as any,
      targetDurationMs: permissibleWindowMs,
      previousText: gatedPrevText,
      nextText: gatedNextText,
    });

    const nextSpeedMultiplier =
      typeof params.speedMultiplier === "number" && Number.isFinite(params.speedMultiplier)
        ? Number(Math.max(0.5, Math.min(2.0, params.speedMultiplier)).toFixed(2))
        : 1.0;

    const synthResult = await ttsService.synthesize({
      jobId,
      language: normLang,
      text: busPayload.text,
      voiceId: nextVoiceId,
      speakerId: existingSeg.speaker,
      userId: jobData.userId || params.uid,
      preferVoiceCloning: isJobVoiceClone,
      ttsTier: "audio_track",
      voiceType,
      speakingRate: nextSpeedMultiplier !== 1.0 ? nextSpeedMultiplier : undefined,
      stability: busPayload.voiceSettings.stability,
      similarityBoost: busPayload.voiceSettings.similarity_boost,
      style: busPayload.voiceSettings.style,
      emotionTag: busPayload.emotionTag,
      energyDb: existingSeg.energyDb,
      pronunciationGlossary: manifest.pronunciationGlossary || [],
      previousText: busPayload.previousText,
      nextText: busPayload.nextText,
    });

    const synthDurationMs = Math.round(synthResult.duration * 1000);
    const updatedSeg: DubbingEditableSegment = {
      ...existingSeg,
      editedText: nextTextRaw,
      translatedText: busPayload.text,
      emotionTag: busPayload.emotionTag,
      stabilityOverride: busPayload.voiceSettings.stability,
      similarityBoostOverride: busPayload.voiceSettings.similarity_boost,
      voiceId: nextVoiceId || synthResult.voiceName,
      synthesizedAudioUrl: synthResult.audioUrl,
      durationMs: synthDurationMs,
      actualSynthesizedDurationMs: synthDurationMs,
      updatedAt: Date.now(),
      terminologyWarning,
      terminologyViolations: compCheck.violations.length > 0
        ? compCheck.violations.map((v) => ({
            termId: v.termId,
            source: v.source,
            disallowedFound: v.disallowedFound,
            suggested: v.suggested,
          }))
        : undefined,
      terminologyComplianceRate: compCheck.complianceRate,
      numericalParityVerified: numParity.isParity,
      numericalParityWarning,
      reviewRecommended: !numParity.isParity || compCheck.violations.length > 0,
    };

    const updatedSegments = [...manifest.segments];
    updatedSegments[targetIdx] = updatedSeg;

    // Synchronize captions cleanly (with bracketed ElevenLabs audio tags stripped)
    const subtitleUrl = await this.syncEditableSubtitles(
      jobId,
      normLang,
      updatedSegments,
      manifest.subtitleUrl || undefined,
      manifest.sourceLanguage || jobData?.sourceLanguage || "en"
    );

    const nextVersion = (manifest.version || 1) + 1;
    const nextRevision = (manifest.revision || 0) + 1;
    const nextRegenCount = currentRegenCount + 1;

    await manifestRef.set(
      {
        segments: updatedSegments,
        subtitleUrl: subtitleUrl ?? null,
        masterAudioUrl: null, // 🛡️ Guardrail 2: Invalidate stale master audio
        masterVideoUrl: null, // 🛡️ Guardrail 2: Invalidate stale master video
        version: nextVersion,
        revision: nextRevision,
        regenerationCount: nextRegenCount,
        updatedAt: Date.now(),
      },
      { merge: true }
    );

    // Increment dubbing revision on job document
    await db()
      .collection("video_jobs")
      .doc(jobId)
      .set(
        {
          dubbingRevision: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    // ── Option 3: Safe Quarantined Ingestion into Translation Memory ──
    // Ingests creator edits ONLY after audio synthesis & manifest persistence succeed
    // AND strictly gated behind: numericalParityPassed === true && complianceRate === 1.0!
    if (existingSeg.originalText) {
      await adaptiveMtDatasetService.ingestCreatorCorrection({
        jobId,
        sourceText: existingSeg.originalText,
        editedText: nextTextRaw,
        sourceLang: manifest.sourceLanguage || "en",
        targetLang: normLang,
        numericalParityPassed: numParity.isParity,
        terminologyComplianceRate: compCheck.complianceRate,
        reviewRecommended: !numParity.isParity || compCheck.violations.length > 0,
        segmentIndex: params.segmentIndex,
      }).catch((err) => {
        logger.warn("[AdaptiveMtDataset] TM ingestion skipped on edit:", err);
      });
    }

    const playableAudioUrl = await audioIdentityService
      .getAccessibleUrl(synthResult.audioUrl)
      .catch(() => synthResult.audioUrl);

    return {
      segment: updatedSeg,
      version: nextVersion,
      subtitleUrl,
      playableAudioUrl,
      terminologyWarning,
    };
  }

  private async syncEditableSubtitles(
    jobId: string,
    normLang: string,
    segments: DubbingEditableSegment[],
    fallbackUrl?: string,
    sourceLanguage?: string
  ): Promise<string | undefined> {
    try {
      const profile = getSubtitleProfile(normLang);
      const minGapMs = calculateMinInterCueGapMs(30, profile);

      const rawCues: LocalizedSubtitleCue[] = segments
        .map((s, idx) => {
          const rawText = stripAudioTagsForSubtitles(
            s.editedText || (s as any).subtitleText || s.translatedText
          );
          const sanitizedText = SubtitleGuardrails.sanitize(rawText, {
            targetLanguage: normLang,
            sourceLanguage,
          });
          if (!sanitizedText) return null;

          const startMs = Math.max(0, Math.round(s.startMs));
          const actualDurMs =
            s.actualSynthesizedDurationMs ||
            s.durationMs ||
            Math.max(300, s.endMs - s.startMs);
          const nextSeg = idx < segments.length - 1 ? segments[idx + 1] : undefined;
          const nextStart = nextSeg
            ? nextSeg.startMs
            : startMs + actualDurMs + 2000;
          const snappedEnd = Math.min(
            startMs + actualDurMs,
            Math.max(startMs + 300, nextStart - minGapMs)
          );

          const endMs = Math.max(startMs + 300, snappedEnd);
          const durationMs = Math.max(300, endMs - startMs);
          const cps = Number((sanitizedText.length / (durationMs / 1000)).toFixed(2));
          const cue: LocalizedSubtitleCue = {
            id: idx + 1,
            startMs,
            endMs,
            text: sanitizedText,
            speaker: s.speaker,
            sourceWordStartIndex: idx,
            sourceWordEndIndex: idx,
            alignmentConfidence: 1.0,
            languageCode: normLang,
            charactersPerSecond: cps,
            charactersPerLine: sanitizedText.length,
            durationMs,
            validationStatus: "pass",
          };
          return cue;
        })
        .filter((c): c is LocalizedSubtitleCue => c !== null);

      if (rawCues.length === 0) return fallbackUrl;

      const { cues: conformedCues } = conformCues(rawCues, {
        profile,
        fps: 30,
      });

      const subRes = await mediaService.generateAllSubtitles(
        jobId,
        conformedCues.map((c) => ({
          start: c.startMs,
          end: c.endMs,
          text: c.text,
        })),
        normLang
      );
      return subRes.srtUrl;
    } catch (subErr) {
      logger.warn("[DubbingEditor] Non-fatal subtitle sync warning:", {
        jobId,
        normLang,
        err: String(subErr),
      });
      return fallbackUrl;
    }
  }

  /**
   * Auto-translates or fits a single segment's translation to its exact speech timeline window,
   * preserving neighboring dialogue context, terminology compliance, and numerical parity.
   */
  public async retranslateSegment(params: {
    jobId?: string;
    videoId?: string;
    language: string;
    segmentIndex: number;
    uid: string;
    isAdmin?: boolean;
    mode?: "fit" | "fresh";
    draftText?: string;
  }): Promise<{
    segmentIndex: number;
    translatedText: string;
    subtitleText: string;
    estimatedDurationMs: number;
    permissibleWindowMs: number;
    syllableBudgetCompliance: number;
    numericalParityVerified: boolean;
    terminologyWarning?: string;
  }> {
    const normLang = normalizeLanguageCode(params.language);
    const { jobId, jobData } = await this.authorizeAndResolveJobId({
      jobId: params.jobId,
      videoId: params.videoId,
      language: normLang,
      uid: params.uid,
      isAdmin: params.isAdmin,
    });

    const manifestRef = db()
      .collection("video_jobs")
      .doc(jobId)
      .collection("dubbing_manifests")
      .doc(normLang);

    const snap = await manifestRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Editable dubbing manifest not found.");
    }

    const manifest = snap.data() as DubbingEditableManifest;
    const targetIdx = manifest.segments.findIndex((s) => s.index === params.segmentIndex);
    if (targetIdx === -1) {
      throw new HttpsError("invalid-argument", "Requested segment index does not exist in this track.");
    }

    const seg = manifest.segments[targetIdx];
    await this.consumeEditorQuota(manifestRef, {
      kind: "retranslate",
      isAdmin: params.isAdmin,
      segmentIndex: params.segmentIndex,
    });
    const sourceLang = normalizeLanguageCode(
      manifest.sourceLanguage || jobData?.sourceLanguage || "en"
    );
    const nextSeg = targetIdx < manifest.segments.length - 1 ? manifest.segments[targetIdx + 1] : undefined;
    const windowMs = computePermissibleWindowMs(
      seg.startMs,
      seg.endMs,
      nextSeg ? nextSeg.startMs : null,
      manifest.totalDurationMs
    );

    const contextBefore = manifest.segments
      .slice(Math.max(0, targetIdx - 3), targetIdx)
      .map((s) => ({ source: s.originalText, speaker: s.speaker }));
    const contextAfter = manifest.segments
      .slice(targetIdx + 1, targetIdx + 4)
      .map((s) => ({ source: s.originalText, speaker: s.speaker }));

    const currentDraft =
      params.mode === "fresh"
        ? undefined
        : (params.draftText?.trim() || seg.editedText || seg.translatedText);

    const fitted = await translationService.retranslateConcise(
      seg.originalText,
      sourceLang,
      normLang,
      {
        maxDurationMs: windowMs,
        currentTranslation: currentDraft,
        speaker: seg.speaker,
        jobId,
        userId: jobData.userId || params.uid,
        contextBefore,
        contextAfter,
      }
    );

    const cleanTranslated = decodeHtmlEntities(fitted).trim();
    const cleanSubtitle = SubtitleGuardrails.sanitize(
      stripAudioTagsForSubtitles(cleanTranslated),
      { targetLanguage: normLang, sourceLanguage: sourceLang }
    );

    const numParity = NumericalEntityGuard.verifyNumericalParity(
      seg.originalText || "",
      cleanTranslated,
      normLang
    );
    const compCheck = TerminologyService.checkTerminologyCompliance(
      seg.originalText || "",
      cleanTranslated,
      normLang
    );

    let terminologyWarning: string | undefined;
    if (compCheck.violations.length > 0) {
      const v = compCheck.violations[0];
      terminologyWarning = `Non-compliant term "${v.disallowedFound}" detected. Recommended: "${v.suggested}".`;
    }
    if (!numParity.isParity) {
      const numAlert = `Numerical discrepancy detected: The original stated "${seg.originalText}".`;
      terminologyWarning = terminologyWarning ? `${terminologyWarning} ${numAlert}` : numAlert;
    }

    const estimatedDurationMs = estimateSpeechDurationMs(cleanTranslated, normLang);
    const syllableBudgetCompliance = computeSyllableBudgetCompliance(
      seg.originalText || "",
      cleanTranslated,
      sourceLang,
      normLang,
      windowMs
    );

    return {
      segmentIndex: params.segmentIndex,
      translatedText: cleanTranslated,
      subtitleText: cleanSubtitle || cleanTranslated,
      estimatedDurationMs,
      permissibleWindowMs: windowMs,
      syllableBudgetCompliance,
      numericalParityVerified: numParity.isParity,
      terminologyWarning,
    };
  }

  /**
   * Persists DAW timeline drag edits (`startMs`, `endMs`) across one or more segments
   * and synchronizes the aligned subtitles before remastering.
   */
  public async updateSegmentTimings(params: {
    jobId: string;
    language: string;
    uid: string;
    isAdmin?: boolean;
    timings: Array<{ segmentIndex: number; startMs: number; endMs: number }>;
  }): Promise<{
    updatedCount: number;
    version: number;
    subtitleUrl?: string;
  }> {
    const normLang = normalizeLanguageCode(params.language);
    const { jobId } = await this.authorizeAndResolveJobId({
      jobId: params.jobId,
      language: normLang,
      uid: params.uid,
      isAdmin: params.isAdmin,
    });

    if (!Array.isArray(params.timings) || params.timings.length === 0 || params.timings.length > 1000) {
      throw new HttpsError("invalid-argument", "Provide between 1 and 1000 valid segment timing updates.");
    }

    const manifestRef = db()
      .collection("video_jobs")
      .doc(jobId)
      .collection("dubbing_manifests")
      .doc(normLang);

    const snap = await manifestRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Editable dubbing manifest not found.");
    }

    const manifest = snap.data() as DubbingEditableManifest;
    const timingByIndex = new Map<number, { startMs: number; endMs: number }>();
    for (const item of params.timings) {
      if (
        !item ||
        typeof item.segmentIndex !== "number" ||
        !Number.isFinite(item.startMs) ||
        !Number.isFinite(item.endMs)
      ) {
        throw new HttpsError("invalid-argument", "Segment timing values must be valid numbers.");
      }
      const startMs = Math.max(0, Math.round(item.startMs));
      const endMs = Math.round(item.endMs);
      if (endMs - startMs < 200) {
        throw new HttpsError("invalid-argument", "Each segment must span at least 200ms.");
      }
      timingByIndex.set(item.segmentIndex, { startMs, endMs });
    }

    const now = Date.now();
    let updatedCount = 0;
    const updatedSegments = manifest.segments.map((seg) => {
      const nextTiming = timingByIndex.get(seg.index);
      if (!nextTiming) return seg;
      updatedCount += 1;
      return {
        ...seg,
        startMs: nextTiming.startMs,
        endMs: nextTiming.endMs,
        durationMs: nextTiming.endMs - nextTiming.startMs,
        updatedAt: now,
      };
    });

    if (updatedCount === 0) {
      throw new HttpsError("not-found", "No matching segments found for timing update.");
    }

    const subtitleUrl = await this.syncEditableSubtitles(
      jobId,
      normLang,
      updatedSegments,
      manifest.subtitleUrl || undefined,
      manifest.sourceLanguage || "en"
    );

    const nextVersion = (manifest.version || 1) + 1;
    await manifestRef.set(
      {
        segments: updatedSegments,
        subtitleUrl: subtitleUrl ?? null,
        version: nextVersion,
        updatedAt: now,
      },
      { merge: true }
    );

    return {
      updatedCount,
      version: nextVersion,
      subtitleUrl,
    };
  }

  public async savePronunciationGlossary(params: {
    jobId: string;
    language: string;
    uid: string;
    isAdmin?: boolean;
    rules: PronunciationRule[];
  }): Promise<{ savedCount: number; version: number }> {
    const normLang = normalizeLanguageCode(params.language);
    const { jobId } = await this.authorizeAndResolveJobId({
      jobId: params.jobId,
      language: normLang,
      uid: params.uid,
      isAdmin: params.isAdmin,
    });

    if (!Array.isArray(params.rules) || params.rules.length > 100) {
      throw new HttpsError("invalid-argument", "Glossary must contain at most 100 rules.");
    }

    const sanitizedRules: PronunciationRule[] = params.rules
      .filter((r) => r && typeof r.term === "string" && r.term.trim().length > 0)
      .map((r, idx) => ({
        id: (r.id || `rule_${idx}`).slice(0, 64),
        term: r.term.trim().slice(0, 120),
        replacement: (r.replacement || r.ipaOrPhonetic || r.term).trim().slice(0, 160),
        ipaOrPhonetic: r.ipaOrPhonetic ? r.ipaOrPhonetic.trim().slice(0, 160) : undefined,
        caseSensitive: Boolean(r.caseSensitive),
      }));

    const manifestRef = db()
      .collection("video_jobs")
      .doc(jobId)
      .collection("dubbing_manifests")
      .doc(normLang);

    const snap = await manifestRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Editable dubbing manifest not found.");
    }

    const nextVersion = ((snap.data() as DubbingEditableManifest)?.version || 1) + 1;
    await manifestRef.set(
      {
        pronunciationGlossary: sanitizedRules,
        version: nextVersion,
        updatedAt: Date.now(),
      },
      { merge: true }
    );

    // Also save preset on creator profile for reuse across projects
    await db()
      .collection("creator_voice_profiles")
      .doc(params.uid)
      .set(
        {
          pronunciationGlossaryByLanguage: {
            [normLang]: sanitizedRules,
          },
          updatedAt: Date.now(),
        },
        { merge: true }
      )
      .catch(() => {});

    return { savedCount: sanitizedRules.length, version: nextVersion };
  }

  public async remasterTrack(params: {
    jobId: string;
    language: string;
    uid: string;
    isAdmin?: boolean;
    mneGain?: number;
    dialogueGain?: number;
  }): Promise<{
    masterAudioUrl: string;
    masterVideoUrl?: string;
    dialogueStemUrl: string;
    version: number;
    mneGain: number;
    dialogueGain: number;
  }> {
    const normLang = normalizeLanguageCode(params.language);
    const { jobId, videoId, jobData } = await this.authorizeAndResolveJobId({
      jobId: params.jobId,
      language: normLang,
      uid: params.uid,
      isAdmin: params.isAdmin,
    });

    const manifestRef = db()
      .collection("video_jobs")
      .doc(jobId)
      .collection("dubbing_manifests")
      .doc(normLang);

    const snap = await manifestRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Editable dubbing manifest not found.");
    }

    const manifest = snap.data() as DubbingEditableManifest;
    if (!manifest.segments || manifest.segments.length === 0) {
      throw new HttpsError("failed-precondition", "Manifest has no speech segments to remaster.");
    }

    await this.consumeEditorQuota(manifestRef, {
      kind: "remaster",
      isAdmin: params.isAdmin,
    });

    // Fill any missing segment audio before stitching
    const segmentUrls: string[] = [];
    const updatedSegments = [...manifest.segments];
    const isJobVoiceClone = jobData?.executionPlan?.dubbingMode === "voice_clone";
    const voiceType = isJobVoiceClone ? "cloned" : "standard";

    for (let i = 0; i < updatedSegments.length; i++) {
      const seg = updatedSegments[i];
      if (seg.synthesizedAudioUrl) {
        segmentUrls.push(seg.synthesizedAudioUrl);
      } else {
        let textToVocalize = seg.editedText || seg.translatedText;
        if (normLang === "te") {
          textToVocalize = applyTeluguTheologicalLexiconGuard(textToVocalize);
        }
        textToVocalize = normalizeScriptureCitationsForTts(textToVocalize, normLang);

        const prevSeg = i > 0 ? updatedSegments[i - 1] : undefined;
        const nextSeg = i < updatedSegments.length - 1 ? updatedSegments[i + 1] : undefined;

        // 🛡️ Guardrail 3: Context-Windowing Gate — Same-speaker adjacent turns within 2.5s gap
        const prevGapMs = (prevSeg && seg.startMs !== undefined && prevSeg.endMs !== undefined)
          ? (seg.startMs - prevSeg.endMs)
          : Infinity;
        const isPrevSameSpeaker = Boolean(prevSeg && prevSeg.speaker && seg.speaker && prevSeg.speaker === seg.speaker);
        const gatedPrevText = (isPrevSameSpeaker && prevGapMs >= 0 && prevGapMs <= 2500)
          ? (prevSeg?.editedText || prevSeg?.translatedText)
          : undefined;

        const nextGapMs = (nextSeg && nextSeg.startMs !== undefined && seg.endMs !== undefined)
          ? (nextSeg.startMs - seg.endMs)
          : Infinity;
        const isNextSameSpeaker = Boolean(nextSeg && nextSeg.speaker && seg.speaker && nextSeg.speaker === seg.speaker);
        const gatedNextText = (isNextSameSpeaker && nextGapMs >= 0 && nextGapMs <= 2500)
          ? (nextSeg?.editedText || nextSeg?.translatedText)
          : undefined;

        const targetDurationMs = (seg.endMs && seg.startMs) ? Math.max(0, seg.endMs - seg.startMs) : undefined;

        const busPayload = expressiveV4Bus.processSegment({
          jobId,
          language: normLang,
          translatedText: textToVocalize,
          sourceText: seg.originalText,
          telemetry: {
            energyDb: seg.energyDb,
            pitchRangeSemitones: seg.pitchRangeSemitones,
            speakingRateRatio: seg.speakingRateRatio,
            emotionTag: seg.emotionTag,
            deliveryStyle: seg.deliveryStyle,
            voiceQuality: seg.voiceQuality as any,
            stabilityOverride: seg.stabilityOverride,
            similarityBoostOverride: seg.similarityBoostOverride,
          },
          preferVoiceCloning: isJobVoiceClone,
          voiceType: voiceType as any,
          targetDurationMs,
          previousText: gatedPrevText,
          nextText: gatedNextText,
        });

        const synth = await ttsService.synthesize({
          jobId,
          language: normLang,
          text: busPayload.text,
          voiceId: seg.voiceId,
          speakerId: seg.speaker,
          userId: manifest.userId,
          preferVoiceCloning: isJobVoiceClone,
          ttsTier: "audio_track",
          voiceType,
          stability: busPayload.voiceSettings.stability,
          similarityBoost: busPayload.voiceSettings.similarity_boost,
          style: busPayload.voiceSettings.style,
          emotionTag: busPayload.emotionTag,
          pronunciationGlossary: manifest.pronunciationGlossary || [],
          previousText: busPayload.previousText,
          nextText: busPayload.nextText,
        });
        const synthDurMs = Math.round(synth.duration * 1000);
        updatedSegments[i] = {
          ...seg,
          translatedText: busPayload.text,
          emotionTag: busPayload.emotionTag,
          synthesizedAudioUrl: synth.audioUrl,
          durationMs: synthDurMs,
          actualSynthesizedDurationMs: synthDurMs,
          updatedAt: Date.now(),
        };
        segmentUrls.push(synth.audioUrl);
      }
    }

    const nextVersion = (manifest.version || 1) + 1;
    const dspFilters = "loudnorm=I=-14:TP=-1:LRA=11";
    const totalDurationMs =
      manifest.totalDurationMs > 0
        ? manifest.totalDurationMs
        : Math.max(...updatedSegments.map((s) => s.endMs));
    const expectedDurSec = totalDurationMs / 1000;

    const dialogueStemUrl = await mediaService.mergeAudioChunks(
      `${jobId}_remaster_v${nextVersion}`,
      segmentUrls,
      normLang,
      {
        segments: updatedSegments.map((s) => ({
          start: s.startMs,
          end: s.endMs,
          duration: Math.max(200, s.endMs - s.startMs),
        })),
        totalDurationMs,
        audioFilters: dspFilters,
        cadenceLock: true,
      }
    );

    const resolvedMneGain =
      typeof params.mneGain === "number" && Number.isFinite(params.mneGain)
        ? Number(Math.max(0, Math.min(2.0, params.mneGain)).toFixed(2))
        : (typeof manifest.mneGain === "number" ? manifest.mneGain : 1.0);
    const resolvedDialogueGain =
      typeof params.dialogueGain === "number" && Number.isFinite(params.dialogueGain)
        ? Number(Math.max(0.2, Math.min(2.0, params.dialogueGain)).toFixed(2))
        : (typeof manifest.dialogueGain === "number" ? manifest.dialogueGain : 1.0);

    let masterAudioUrl = dialogueStemUrl;
    if (manifest.mneStemUrl) {
      masterAudioUrl = await mediaService.mixDubWithMne(jobId, normLang, {
        mneUrl: manifest.mneStemUrl,
        dubbedAudioUrl: dialogueStemUrl,
        totalDurationSeconds: expectedDurSec,
        totalDurationMs,
        // audioFilters omitted — dialogue already mastered via mergeAudioChunks above;
        // passing DSP filters here caused double loudnorm stacking (Problem B root cause).
        mneGain: resolvedMneGain,
        dialogueGain: resolvedDialogueGain,
        spokenSegments: updatedSegments.map((s) => ({ start: s.startMs, end: s.endMs })),
        isDegradedMne: jobData?.artifacts?.mneValidation?.validationStatus === "degraded",
      });
    }

    // Probe mastered output & enforce QualityGate
    let probedDurSec = expectedDurSec;
    let outputSize = 0;
    try {
      const storageInfo = parseAnyStorageUrl(masterAudioUrl);
      if (storageInfo) {
        const file = admin.storage().bucket(storageInfo.bucketName).file(storageInfo.filePath);
        const [meta] = await file.getMetadata();
        outputSize = Number(meta.size || 0);
        const tmpFile = path.join(os.tmpdir(), `remaster_probe_${jobId}_${Date.now()}.mp3`);
        await file.download({ destination: tmpFile });
        const ms = await mediaService.probeMediaDurationMs(tmpFile);
        if (ms > 0) probedDurSec = ms / 1000;
        await fs.promises.unlink(tmpFile).catch(() => {});
      }
    } catch (_) {}

    const gate = DubbingQualityGate.evaluate({
      jobId,
      targetLang: normLang,
      totalSegments: updatedSegments.length,
      successfulSegments: updatedSegments.length,
      failedSegments: [],
      actualDurationSeconds: probedDurSec,
      expectedDurationSeconds: expectedDurSec,
      isVoiceCloningRequested: isJobVoiceClone,
      isVoiceCloned: isJobVoiceClone,
      stemIsolationRequested: Boolean(manifest.mneStemUrl),
      isStemPreserved: Boolean(manifest.mneStemUrl),
      outputAudioSize: outputSize,
      mneValidation: jobData?.artifacts?.mneValidation,
      translatedSegments: updatedSegments.map((s) => ({ translatedText: s.editedText || s.translatedText })),
      translatedTexts: updatedSegments.map((s) => s.editedText || s.translatedText),
    });

    if (!gate.passed) {
      throw new HttpsError(
        "failed-precondition",
        `Remastered track did not pass quality validation: ${gate.violations.join("; ")}`
      );
    }

    let masterVideoUrl = manifest.masterVideoUrl || undefined;
    // 🛡️ Guardrail 2: Synchronize snapped captions cleanly
    const updatedSubtitleUrl = await this.syncEditableSubtitles(
      jobId,
      normLang,
      updatedSegments,
      manifest.subtitleUrl || undefined,
      manifest.sourceLanguage || jobData?.sourceLanguage || "en"
    );

    const sourceVideoUrl = jobData.videoUrl as string | undefined;
    if (sourceVideoUrl) {
      masterVideoUrl = await mediaService
        .mergeAudioToVideo({
          jobId,
          videoUrl: sourceVideoUrl,
          audioUrl: masterAudioUrl,
          subtitleUrl: updatedSubtitleUrl || manifest.subtitleUrl || undefined,
          language: normLang,
          format: "mp4",
          audioFilters: dspFilters,
          isPreMastered: masterAudioUrl !== dialogueStemUrl,
        })
        .catch(() => masterVideoUrl);
    }

    await manifestRef.set(
      {
        segments: updatedSegments,
        subtitleUrl: updatedSubtitleUrl || manifest.subtitleUrl || null,
        dialogueStemUrl,
        masterAudioUrl,
        masterVideoUrl: masterVideoUrl ?? null,
        mneGain: resolvedMneGain,
        dialogueGain: resolvedDialogueGain,
        version: nextVersion,
        updatedAt: Date.now(),
      },
      { merge: true }
    );

    const bucket = admin.storage().bucket();
    const directAudioUrl = masterAudioUrl.startsWith("gs://")
      ? `https://storage.googleapis.com/${bucket.name}/${masterAudioUrl.replace(`gs://${bucket.name}/`, "")}`
      : masterAudioUrl;
    const directVideoUrl = masterVideoUrl && masterVideoUrl.startsWith("gs://")
      ? `https://storage.googleapis.com/${bucket.name}/${masterVideoUrl.replace(`gs://${bucket.name}/`, "")}`
      : masterVideoUrl;

    await db().collection("dubbing_results").doc(`${jobId}_${normLang}`).set(
      {
        audioUrl: masterAudioUrl,
        ...(masterVideoUrl ? { videoUrl: masterVideoUrl } : {}),
        stems: {
          mne: manifest.mneStemUrl || null,
          dialogue: dialogueStemUrl,
          master: masterAudioUrl,
        },
        remasteredAt: Date.now(),
        version: nextVersion,
      },
      { merge: true }
    );

    const linkedVideoIds = filterVideoIds(videoId ? [videoId] : [], "[DubbingEditor:remaster]");
    for (const vid of linkedVideoIds) {
      await safeMergeExistingVideo(
        vid,
        {
          audioTracks: { [normLang]: directAudioUrl },
          media: { audioTracks: { [normLang]: directAudioUrl } },
          aiDubbedAudio: { [normLang]: directAudioUrl },
          [`audioTracks.${normLang}`]: directAudioUrl,
          ...(directVideoUrl ? { dubbedVideos: { [normLang]: directVideoUrl } } : {}),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        "[DubbingEditor:remaster]"
      );
    }

    // 🎬 Package / Update Multilingual HLS Master Manifest (master.m3u8) with frame-aligned tracks
    const candidateVideoId = videoId || jobData.videoId || (linkedVideoIds.length > 0 ? linkedVideoIds[0] : "");
    const targetVideoId = isVideoId(candidateVideoId) ? candidateVideoId : "";
    if (targetVideoId) {
      try {
        const videoSnap = await db().collection("videos").doc(targetVideoId).get();
        const videoData = videoSnap.exists ? videoSnap.data() || {} : {};
        const existingAudioTracks: Record<string, string> = {
          ...(videoData.audioTracks || {}),
          [normLang]: directAudioUrl,
        };
        const activeSubUrl = updatedSubtitleUrl || manifest.subtitleUrl;
        const existingSubtitles: Record<string, string> = {
          ...(videoData.mediaSubtitles || {}),
          ...(activeSubUrl ? { [normLang]: activeSubUrl.replace(/\.srt$/, ".vtt") } : {}),
        };

        const audioRenditions = Object.entries(existingAudioTracks).map(([lang, aUrl]) => ({
          language: lang,
          audioUrl: aUrl,
          isDefault: lang === (jobData.sourceLanguage || "en"),
        }));

        const subtitleRenditions = Object.entries(existingSubtitles).map(([lang, subUrl]) => ({
          language: lang,
          vttUrl: subUrl.replace(/\.srt$/, ".vtt"),
          isDefault: false,
        }));

        await hlsPackagerService.packageMultilingualHlsManifest({
          jobId,
          videoId: targetVideoId,
          sourceLanguage: jobData.sourceLanguage || "en",
          audioRenditions,
          subtitleRenditions,
          baseVideoUrl: sourceVideoUrl,
          totalDurationSec: totalDurationMs > 0 ? totalDurationMs / 1000 : undefined,
        });
      } catch (hlsErr) {
        logger.warn("[DubbingEditor:Remaster] Notice packaging HLS multi-audio manifest:", hlsErr);
      }
    }

    const playableMasterUrl = await audioIdentityService
      .getAccessibleUrl(masterAudioUrl)
      .catch(() => directAudioUrl);

    return {
      masterAudioUrl: playableMasterUrl,
      masterVideoUrl: directVideoUrl,
      dialogueStemUrl,
      version: nextVersion,
      mneGain: resolvedMneGain,
      dialogueGain: resolvedDialogueGain,
    };
  }

  /**
   * Generates a complete, single-tap export package for a dubbed video:
   * Multi-track MP4 video container + Aligned .srt captions + Aligned .vtt captions.
   */
  public async getDubbingExportPackage(params: {
    jobId?: string;
    videoId?: string;
    language: string;
    uid: string;
    isAdmin?: boolean;
  }): Promise<{
    language: string;
    videoUrl?: string;
    audioUrl?: string;
    dialogueAudioUrl?: string;
    vocalsStemUrl?: string;
    backgroundStemUrl?: string;
    translationJsonUrl?: string;
    reportJsonUrl?: string;
    srtUrl?: string;
    vttUrl?: string;
    srtContent?: string;
    vttContent?: string;
    totalSegments: number;
    title?: string;
  }> {
    const normLang = normalizeLanguageCode(params.language);
    const { jobId, videoId, jobData } = await this.authorizeAndResolveJobId({
      jobId: params.jobId,
      videoId: params.videoId,
      language: normLang,
      uid: params.uid,
      isAdmin: params.isAdmin,
    });

    const manifestRef = db()
      .collection("video_jobs")
      .doc(jobId)
      .collection("dubbing_manifests")
      .doc(normLang);

    const [snap, dubResultSnap, subResultSnap] = await Promise.all([
      manifestRef.get(),
      db().collection("dubbing_results").doc(`${jobId}_${normLang}`).get().catch(() => null),
      db().collection("subtitle_results").doc(`${jobId}_${normLang}`).get().catch(() => null),
    ]);

    const dubResultData = dubResultSnap?.exists ? (dubResultSnap.data() || {}) : {};
    const subResultData = subResultSnap?.exists ? (subResultSnap.data() || {}) : {};

    if (!snap.exists && !dubResultSnap?.exists) {
      throw new HttpsError("not-found", "Dubbing manifest not found for export.");
    }

    const manifest = (snap.exists ? snap.data() : {}) as Partial<DubbingEditableManifest>;
    const segments = manifest.segments || [];

    // Generate formatted SRT and VTT string representations when manifest segments exist
    const cleanSegments = segments.map((s) => ({
      start: s.startMs,
      end: s.endMs,
      text: stripAudioTagsForSubtitles(s.editedText || s.translatedText),
    }));

    const srtContent = cleanSegments.length > 0 ? mediaService.generateSrt(cleanSegments) : undefined;
    const vttContent = cleanSegments.length > 0 ? mediaService.generateVtt(cleanSegments) : undefined;

    const bucket = admin.storage().bucket();
    const bucketName = bucket.name;
    const sourceVideoUrl = String(jobData.videoUrl || "");
    const isGenuineDubVideo = (url?: string | null): url is string => {
      if (!url || typeof url !== "string" || !url.trim()) return false;
      const clean = url.trim().toLowerCase();
      if (sourceVideoUrl && clean === sourceVideoUrl.trim().toLowerCase()) return false;
      if (clean.endsWith("original.mp4") || clean.includes("/original.mp4") || clean.includes("%2foriginal.mp4")) {
        return false;
      }
      return true;
    };

    const storageExists = async (rawUrl?: string | null): Promise<boolean> => {
      if (!rawUrl || typeof rawUrl !== "string" || !rawUrl.trim()) return false;
      try {
        const info = parseAnyStorageUrl(rawUrl.trim());
        if (!info || !info.filePath) return false;
        const targetBucket = info.bucketName ? admin.storage().bucket(info.bucketName) : bucket;
        const [exists] = await targetBucket.file(info.filePath).exists();
        return exists;
      } catch {
        return false;
      }
    };

    const toAccessible = async (rawUrl?: string | null): Promise<string | undefined> => {
      if (!rawUrl || typeof rawUrl !== "string" || !rawUrl.trim()) return undefined;
      return await audioIdentityService.getAccessibleUrl(rawUrl.trim()).catch(() => rawUrl.trim());
    };

    let resolvedVideoUrl: string | undefined = isGenuineDubVideo(manifest.masterVideoUrl)
      ? manifest.masterVideoUrl
      : undefined;
    let resolvedAudioUrl: string | undefined =
      manifest.masterAudioUrl ||
      jobData.outputs?.audioTracks?.[normLang] ||
      jobData.outputs?.audioTracks?.[params.language] ||
      dubResultData.audioUrl ||
      undefined;

    // 🛡️ Guardrail 2: If cache was invalidated by segment edits on a manifest, remaster automatically
    if (snap.exists && (!resolvedVideoUrl || !resolvedAudioUrl)) {
      try {
        const remasterRes = await this.remasterTrack({
          jobId,
          language: normLang,
          uid: params.uid,
          isAdmin: params.isAdmin,
          mneGain: manifest.mneGain ?? 1.0,
          dialogueGain: manifest.dialogueGain ?? 1.0,
        });
        if (isGenuineDubVideo(remasterRes.masterVideoUrl)) {
          resolvedVideoUrl = remasterRes.masterVideoUrl;
        }
        resolvedAudioUrl = resolvedAudioUrl || remasterRes.masterAudioUrl;
      } catch (remasterErr) {
        logger.warn("[DubbingEditor:export] Auto-remaster on invalidated cache:", remasterErr);
      }
    }

    if (!resolvedVideoUrl) {
      const candidateVideos = [
        jobData.outputs?.dubbedVideos?.[normLang],
        jobData.outputs?.dubbedVideos?.[params.language],
        dubResultData.videoUrl,
        `gs://${bucketName}/videos/${jobId}/${normLang}-dubbed.mp4`,
      ];
      for (const candidate of candidateVideos) {
        if (isGenuineDubVideo(candidate) && (await storageExists(candidate))) {
          resolvedVideoUrl = candidate;
          break;
        }
      }
    }

    let rawDialogueUrl: string | undefined =
      manifest.dialogueStemUrl ||
      jobData.outputs?.dialogueTracks?.[normLang] ||
      jobData.outputs?.dialogueTracks?.[params.language] ||
      jobData.outputs?.stems?.dialogue?.[normLang] ||
      dubResultData.stems?.dialogue ||
      `gs://${bucketName}/audio/${jobId}/${normLang}/stitched.mp3`;
    if (!(await storageExists(rawDialogueUrl))) {
      rawDialogueUrl = undefined;
    }

    let rawVocalsStemUrl: string | undefined =
      jobData.outputs?.stems?.vocals ||
      dubResultData.stems?.vocals ||
      `gs://${bucketName}/audio/${jobId}/vocals_demucs.mp3`;
    if (!(await storageExists(rawVocalsStemUrl))) {
      rawVocalsStemUrl = undefined;
    }

    let rawBackgroundStemUrl: string | undefined =
      manifest.mneStemUrl ||
      jobData.outputs?.stems?.background ||
      jobData.outputs?.stems?.mne ||
      dubResultData.stems?.mne ||
      `gs://${bucketName}/audio/${jobId}/m_and_e.mp3`;
    if (!(await storageExists(rawBackgroundStemUrl))) {
      rawBackgroundStemUrl = undefined;
    }

    let rawTranslationJsonUrl: string | undefined =
      jobData.outputs?.translations?.[normLang] ||
      jobData.outputs?.translations?.[params.language] ||
      (typeof dubResultData.translationUrl === "string" && dubResultData.translationUrl.includes("/translations/")
        ? dubResultData.translationUrl
        : undefined) ||
      `gs://${bucketName}/translations/${jobId}/translation_${normLang}.json`;
    if (!(await storageExists(rawTranslationJsonUrl))) {
      if (segments.length > 0) {
        rawTranslationJsonUrl = await saveTranslationArtifact({
          jobId,
          videoId,
          sourceLanguage: manifest.sourceLanguage || jobData.sourceLanguage || "en",
          targetLanguage: normLang,
          segments,
        }).catch(() => undefined);
      } else {
        rawTranslationJsonUrl = undefined;
      }
    }

    let rawReportJsonUrl: string | undefined =
      jobData.outputs?.dubbingReportUrl ||
      `gs://${bucketName}/dubbing/${jobId}/report.json`;
    if (!(await storageExists(rawReportJsonUrl))) {
      rawReportJsonUrl = (await saveDubbingReportArtifact({
        jobId,
        videoId,
        sourceLanguage: manifest.sourceLanguage || jobData.sourceLanguage || "en",
        targetLanguages: Array.isArray(jobData.executionPlan?.dubbingLanguages) && jobData.executionPlan.dubbingLanguages.length > 0
          ? jobData.executionPlan.dubbingLanguages
          : [normLang],
        durationSeconds: Number(jobData.durationSeconds || jobData.duration || 0) || undefined,
        vocalsStemUrl: rawVocalsStemUrl || null,
        backgroundStemUrl: rawBackgroundStemUrl || null,
        results: [
          {
            jobId,
            language: normLang,
            subtitleUrl: manifest.subtitleUrl || subResultData.srtPath || "",
            subtitleFormat: "srt",
            audioUrl: resolvedAudioUrl || "",
            videoUrl: resolvedVideoUrl || "",
            translationUrl: rawTranslationJsonUrl || "",
            segments: segments.length,
            processingTime: Number(dubResultData.processingTime || 0),
            stems: {
              dialogue: rawDialogueUrl,
              master: resolvedAudioUrl,
              vocals: rawVocalsStemUrl || null,
              mne: rawBackgroundStemUrl || null,
            },
          },
        ],
        dialogueStems: rawDialogueUrl ? { [normLang]: rawDialogueUrl } : undefined,
      })) || undefined;
    }

    const rawSrtUrl = manifest.subtitleUrl || subResultData.srtPath || subResultData.subtitleUrl;
    const rawVttUrl = subResultData.vttPath || (rawSrtUrl ? String(rawSrtUrl).replace(/\.srt$/i, ".vtt") : undefined);

    const [
      accessibleVideoUrl,
      accessibleAudioUrl,
      accessibleDialogueUrl,
      accessibleVocalsUrl,
      accessibleBgUrl,
      accessibleTranslationUrl,
      accessibleReportUrl,
      accessibleSrtUrl,
      accessibleVttUrl,
    ] = await Promise.all([
      toAccessible(resolvedVideoUrl),
      toAccessible(resolvedAudioUrl),
      toAccessible(rawDialogueUrl),
      toAccessible(rawVocalsStemUrl),
      toAccessible(rawBackgroundStemUrl),
      toAccessible(rawTranslationJsonUrl),
      toAccessible(rawReportJsonUrl),
      toAccessible(rawSrtUrl),
      toAccessible(rawVttUrl),
    ]);

    const videoTitle = (typeof jobData.title === "string" && jobData.title.trim()) || "truthworld_video";

    return {
      language: normLang,
      videoUrl: accessibleVideoUrl,
      audioUrl: accessibleAudioUrl,
      dialogueAudioUrl: accessibleDialogueUrl,
      vocalsStemUrl: accessibleVocalsUrl,
      backgroundStemUrl: accessibleBgUrl,
      translationJsonUrl: accessibleTranslationUrl,
      reportJsonUrl: accessibleReportUrl,
      srtUrl: accessibleSrtUrl,
      vttUrl: accessibleVttUrl,
      srtContent,
      vttContent,
      totalSegments: segments.length,
      title: videoTitle,
    };
  }
}

export const dubbingEditorService = new DubbingEditorService();
