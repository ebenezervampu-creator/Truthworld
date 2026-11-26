import * as admin from "firebase-admin";
import { DubbingResult, DubbingSegment } from "../types";
import { logger } from "../utils/logger";

export interface TranslationArtifactSegment {
  index: number;
  startMs: number;
  endMs: number;
  speaker: string;
  originalText: string;
  translatedText: string;
  subtitleText?: string;
  emotionTag?: string;
  deliveryStyle?: string;
}

export interface TranslationArtifactPayload {
  jobId: string;
  videoId?: string;
  sourceLanguage: string;
  targetLanguage: string;
  generatedAt: string;
  segmentCount: number;
  segments: TranslationArtifactSegment[];
}

export interface DubbingReportLanguageEntry {
  status: string;
  dubOutcome?: string;
  segmentCount: number;
  processingTimeMs: number;
  confidence?: number;
  artifacts: {
    dubbedVideoUrl?: string;
    masterAudioUrl?: string;
    dialogueAudioUrl?: string;
    translationUrl?: string;
    subtitleSrtUrl?: string;
    subtitleVttUrl?: string;
  };
}

export interface DubbingReportPayload {
  jobId: string;
  videoId?: string;
  sourceLanguage: string;
  targetLanguages: string[];
  generatedAt: string;
  generatedAtMs: number;
  durationSeconds?: number;
  processingTimeMs?: number;
  stems: {
    vocalsStemUrl: string | null;
    backgroundStemUrl: string | null;
    separationPath?: string | null;
  };
  speakers?: Array<Record<string, unknown>>;
  voiceMapping?: Record<string, string>;
  languages: Record<string, DubbingReportLanguageEntry>;
  timings?: Record<string, unknown>;
}

/**
 * Builds the canonical translation JSON payload for `translations/{jobId}/translation_{lang}.json`.
 */
export function buildTranslationArtifactPayload(params: {
  jobId: string;
  videoId?: string;
  sourceLanguage: string;
  targetLanguage: string;
  segments: Array<Partial<DubbingSegment> & Record<string, any>>;
  generatedAt?: string;
}): TranslationArtifactPayload {
  const segments: TranslationArtifactSegment[] = (params.segments || []).map((seg, idx) => ({
    index: typeof seg.index === "number" ? seg.index : idx,
    startMs: Math.round(Number(seg.startMs ?? seg.start ?? 0)),
    endMs: Math.round(Number(seg.endMs ?? seg.end ?? 0)),
    speaker: String(seg.speaker || "speaker_0"),
    originalText: String(seg.originalText || ""),
    translatedText: String(seg.editedText || seg.translatedText || ""),
    ...(seg.subtitleText ? { subtitleText: String(seg.subtitleText) } : {}),
    ...(seg.emotionTag ? { emotionTag: String(seg.emotionTag) } : {}),
    ...(seg.deliveryStyle ? { deliveryStyle: String(seg.deliveryStyle) } : {}),
  }));

  return {
    jobId: params.jobId,
    ...(params.videoId ? { videoId: params.videoId } : {}),
    sourceLanguage: params.sourceLanguage,
    targetLanguage: params.targetLanguage,
    generatedAt: params.generatedAt || new Date().toISOString(),
    segmentCount: segments.length,
    segments,
  };
}

/**
 * Saves `translations/{jobId}/translation_{lang}.json` to Firebase Storage and returns its `gs://` URL.
 */
export async function saveTranslationArtifact(params: {
  jobId: string;
  videoId?: string;
  sourceLanguage: string;
  targetLanguage: string;
  segments: Array<Partial<DubbingSegment> & Record<string, any>>;
}): Promise<string> {
  const bucket = admin.storage().bucket();
  const objectPath = `translations/${params.jobId}/translation_${params.targetLanguage}.json`;
  const payload = buildTranslationArtifactPayload(params);
  await bucket.file(objectPath).save(JSON.stringify(payload, null, 2), {
    metadata: {
      contentType: "application/json; charset=utf-8",
      cacheControl: "public, max-age=86400",
    },
  });
  return `gs://${bucket.name}/${objectPath}`;
}

/**
 * Builds the canonical `report.json` payload strictly from measured pipeline outputs.
 */
export function buildDubbingReportPayload(params: {
  jobId: string;
  videoId?: string;
  sourceLanguage: string;
  targetLanguages: string[];
  durationSeconds?: number;
  processingTimeMs?: number;
  vocalsStemUrl?: string | null;
  backgroundStemUrl?: string | null;
  separationPath?: string | null;
  speakerProfiles?: Array<Record<string, unknown>>;
  voiceMapping?: Record<string, string>;
  results: DubbingResult[];
  dialogueStems?: Record<string, string>;
  subtitlePaths?: Record<string, string>;
  timings?: Record<string, unknown>;
  generatedAtMs?: number;
}): DubbingReportPayload {
  const generatedAtMs = params.generatedAtMs ?? Date.now();
  const languages: Record<string, DubbingReportLanguageEntry> = {};

  for (const r of params.results) {
    const lang = r.language;
    const dialogueUrl = r.stems?.dialogue || params.dialogueStems?.[lang] || "";
    const srtUrl = r.subtitleUrl || params.subtitlePaths?.[lang] || "";
    const vttUrl = srtUrl ? srtUrl.replace(/\.srt(\?|$)/i, ".vtt$1") : "";

    languages[lang] = {
      status: r.dubOutcome === "failed" || r.dubOutcome === "not_dubbable" ? r.dubOutcome : "completed",
      ...(r.dubOutcome ? { dubOutcome: r.dubOutcome } : {}),
      segmentCount: r.segments || 0,
      processingTimeMs: r.processingTime || 0,
      artifacts: {
        ...(r.videoUrl ? { dubbedVideoUrl: r.videoUrl } : {}),
        ...(r.audioUrl ? { masterAudioUrl: r.audioUrl } : {}),
        ...(dialogueUrl ? { dialogueAudioUrl: dialogueUrl } : {}),
        ...(r.translationUrl ? { translationUrl: r.translationUrl } : {}),
        ...(srtUrl ? { subtitleSrtUrl: srtUrl } : {}),
        ...(vttUrl ? { subtitleVttUrl: vttUrl } : {}),
      },
    };
  }

  return {
    jobId: params.jobId,
    ...(params.videoId ? { videoId: params.videoId } : {}),
    sourceLanguage: params.sourceLanguage,
    targetLanguages: params.targetLanguages,
    generatedAt: new Date(generatedAtMs).toISOString(),
    generatedAtMs,
    ...(typeof params.durationSeconds === "number" && params.durationSeconds > 0
      ? { durationSeconds: params.durationSeconds }
      : {}),
    ...(typeof params.processingTimeMs === "number" && params.processingTimeMs >= 0
      ? { processingTimeMs: params.processingTimeMs }
      : {}),
    stems: {
      vocalsStemUrl: params.vocalsStemUrl || null,
      backgroundStemUrl: params.backgroundStemUrl || null,
      ...(params.separationPath ? { separationPath: params.separationPath } : {}),
    },
    ...(params.speakerProfiles && params.speakerProfiles.length > 0
      ? { speakers: params.speakerProfiles }
      : {}),
    ...(params.voiceMapping && Object.keys(params.voiceMapping).length > 0
      ? { voiceMapping: params.voiceMapping }
      : {}),
    languages,
    ...(params.timings ? { timings: params.timings } : {}),
  };
}

/**
 * Saves `dubbing/{jobId}/report.json` to Firebase Storage and returns its `gs://` URL.
 */
export async function saveDubbingReportArtifact(
  params: Parameters<typeof buildDubbingReportPayload>[0]
): Promise<string | null> {
  try {
    const bucket = admin.storage().bucket();
    const objectPath = `dubbing/${params.jobId}/report.json`;
    const report = buildDubbingReportPayload(params);
    await bucket.file(objectPath).save(JSON.stringify(report, null, 2), {
      metadata: {
        contentType: "application/json; charset=utf-8",
        cacheControl: "public, max-age=3600",
      },
    });
    return `gs://${bucket.name}/${objectPath}`;
  } catch (err) {
    logger.warn("[Dubbing:Report] Non-fatal error saving dubbing report.json", {
      jobId: params.jobId,
      error: String(err),
    });
    return null;
  }
}
