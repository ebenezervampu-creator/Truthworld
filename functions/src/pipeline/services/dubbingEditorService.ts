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
  sanitizeTextForElevenLabsV4,
  stripAudioTagsForSubtitles,
} from "./tts";
import { mediaService, parseAnyStorageUrl } from "./media";
import { audioIdentityService } from "./audio-identity";
import { DubbingQualityGate } from "../layers/quality-gate";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import { filterVideoIds } from "../../utils/videosCollectionGuard";
import { logger } from "../utils/logger";

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
  }): Promise<{
    segment: DubbingEditableSegment;
    version: number;
    subtitleUrl?: string;
    playableAudioUrl?: string;
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

    const ttsText = sanitizeTextForElevenLabsV4(nextTextRaw, nextEmotion);

    const synthResult = await ttsService.synthesize({
      jobId,
      language: normLang,
      text: ttsText,
      voiceId: nextVoiceId,
      speakerId: existingSeg.speaker,
      userId: jobData.userId || params.uid,
      preferVoiceCloning: true,
      ttsTier: "audio_track",
      voiceType: "cloned",
      stability: nextStability,
      similarityBoost: nextSimilarity,
      emotionTag: nextEmotion,
      energyDb: existingSeg.energyDb,
      pronunciationGlossary: manifest.pronunciationGlossary || [],
    });

    const updatedSeg: DubbingEditableSegment = {
      ...existingSeg,
      editedText: nextTextRaw,
      translatedText: ttsText,
      emotionTag: nextEmotion,
      stabilityOverride: nextStability,
      similarityBoostOverride: nextSimilarity,
      voiceId: nextVoiceId || synthResult.voiceName,
      synthesizedAudioUrl: synthResult.audioUrl,
      updatedAt: Date.now(),
    };

    const updatedSegments = [...manifest.segments];
    updatedSegments[targetIdx] = updatedSeg;

    // Synchronize captions cleanly (with bracketed ElevenLabs audio tags stripped)
    const subtitleUrl = await this.syncEditableSubtitles(
      jobId,
      normLang,
      updatedSegments,
      manifest.subtitleUrl || undefined
    );

    const nextVersion = (manifest.version || 1) + 1;
    await manifestRef.set(
      {
        segments: updatedSegments,
        subtitleUrl: subtitleUrl ?? null,
        version: nextVersion,
        updatedAt: Date.now(),
      },
      { merge: true }
    );

    const playableAudioUrl = await audioIdentityService
      .getAccessibleUrl(synthResult.audioUrl)
      .catch(() => synthResult.audioUrl);

    return {
      segment: updatedSeg,
      version: nextVersion,
      subtitleUrl,
      playableAudioUrl,
    };
  }

  private async syncEditableSubtitles(
    jobId: string,
    normLang: string,
    segments: DubbingEditableSegment[],
    fallbackUrl?: string
  ): Promise<string | undefined> {
    try {
      const subRes = await mediaService.generateAllSubtitles(
        jobId,
        segments.map((s) => ({
          start: s.startMs,
          end: s.endMs,
          text: stripAudioTagsForSubtitles(s.editedText || s.translatedText),
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
      manifest.subtitleUrl || undefined
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

    // Fill any missing segment audio before stitching
    const segmentUrls: string[] = [];
    const updatedSegments = [...manifest.segments];
    for (let i = 0; i < updatedSegments.length; i++) {
      const seg = updatedSegments[i];
      if (seg.synthesizedAudioUrl) {
        segmentUrls.push(seg.synthesizedAudioUrl);
      } else {
        const synth = await ttsService.synthesize({
          jobId,
          language: normLang,
          text: sanitizeTextForElevenLabsV4(seg.editedText || seg.translatedText, seg.emotionTag),
          voiceId: seg.voiceId,
          speakerId: seg.speaker,
          userId: manifest.userId,
          preferVoiceCloning: true,
          ttsTier: "audio_track",
          voiceType: "cloned",
          stability: seg.stabilityOverride,
          similarityBoost: seg.similarityBoostOverride,
          emotionTag: seg.emotionTag,
          pronunciationGlossary: manifest.pronunciationGlossary || [],
        });
        updatedSegments[i] = { ...seg, synthesizedAudioUrl: synth.audioUrl, updatedAt: Date.now() };
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
      isVoiceCloningRequested: false,
      isVoiceCloned: true,
      stemIsolationRequested: Boolean(manifest.mneStemUrl),
      isStemPreserved: Boolean(manifest.mneStemUrl),
      outputAudioSize: outputSize,
      mneValidation: jobData?.artifacts?.mneValidation,
    });

    if (!gate.passed) {
      throw new HttpsError(
        "failed-precondition",
        `Remastered track did not pass quality validation: ${gate.violations.join("; ")}`
      );
    }

    let masterVideoUrl = manifest.masterVideoUrl || undefined;
    const sourceVideoUrl = jobData.videoUrl as string | undefined;
    if (sourceVideoUrl) {
      masterVideoUrl = await mediaService
        .mergeAudioToVideo({
          jobId,
          videoUrl: sourceVideoUrl,
          audioUrl: masterAudioUrl,
          subtitleUrl: manifest.subtitleUrl || undefined,
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
      await db()
        .collection("videos")
        .doc(vid)
        .set(
          {
            audioTracks: { [normLang]: directAudioUrl },
            media: { audioTracks: { [normLang]: directAudioUrl } },
            ...(directVideoUrl ? { dubbedVideos: { [normLang]: directVideoUrl } } : {}),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
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
}

export const dubbingEditorService = new DubbingEditorService();
