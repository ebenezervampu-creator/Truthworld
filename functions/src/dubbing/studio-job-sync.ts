import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";
import { parseAnyStorageUrl } from "../pipeline/services/media";
import { isDubbedVideoUrl } from "./studio-order";
import { DubbingJobStatus } from "./types";

export const STUDIO_JOBS_COLLECTION = "studio_dubbing_jobs";

/**
 * Converts a `gs://bucket/path` or Firebase/GCS URL to a browser-safe HTTPS URL synchronously.
 */
export function toDirectHttpUrl(url: unknown): string {
  if (typeof url !== "string") return "";
  const trimmed = url.trim();
  if (!trimmed) return "";
  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
    return trimmed;
  }
  const info = parseAnyStorageUrl(trimmed);
  if (info && info.bucketName && info.filePath) {
    return `https://firebasestorage.googleapis.com/v0/b/${info.bucketName}/o/${encodeURIComponent(info.filePath)}?alt=media`;
  }
  return trimmed;
}

function clampProgress(n: unknown, fallback = 0): number {
  const num = Number(n);
  if (!Number.isFinite(num)) return fallback;
  return Math.max(0, Math.min(100, Math.round(num)));
}

function extractStageMap(videoJobData: Record<string, any>): Record<string, any> {
  return videoJobData?.stages && typeof videoJobData.stages === "object" ? videoJobData.stages : {};
}

function isStageDone(stage: any): boolean {
  const s = String(stage?.status || "").toLowerCase();
  return s === "completed" || s === "done" || s === "skipped";
}

function isStageFailed(stage: any): boolean {
  return String(stage?.status || "").toLowerCase() === "failed";
}

function extractUrlString(entry: unknown): string {
  if (typeof entry === "string") return entry;
  if (entry && typeof entry === "object") {
    const obj = entry as Record<string, unknown>;
    const candidate = obj.srtPath || obj.url || obj.subtitleUrl || obj.vttPath || obj.videoUrl || obj.path || obj.audioUrl;
    if (typeof candidate === "string") return candidate;
  }
  return "";
}

function extractVttUrlString(entry: unknown): string {
  if (entry && typeof entry === "object") {
    const obj = entry as Record<string, unknown>;
    if (typeof obj.vttPath === "string") return obj.vttPath;
  }
  const srt = extractUrlString(entry);
  return srt ? srt.replace(/\.srt(\?|$)/i, ".vtt$1") : "";
}

/**
 * Computes the `studio_dubbing_jobs` patch from a `video_jobs` snapshot (pure, side-effect free).
 */
export function computeStudioJobUpdate(
  videoJobData: Record<string, any>,
  studioJob: Record<string, any>
): Record<string, any> {
  const stages = extractStageMap(videoJobData);
  const mode = String(studioJob?.mode || "dubbing");
  const isSubtitlesOnly = mode === "subtitles_only";
  const targetLanguages: string[] = Array.isArray(studioJob?.targetLanguages)
    ? studioJob.targetLanguages.map((l) => String(l))
    : [];

  const transStage = stages.transcription || {};
  const dubStage = stages.dubbing || {};
  const subStage = stages.subtitles || {};
  const overallStatus = String(videoJobData?.status || "").toLowerCase();

  const transProgress = clampProgress(transStage.progress, isStageDone(transStage) ? 100 : 0);
  const dubProgress = clampProgress(dubStage.progress, isStageDone(dubStage) ? 100 : 0);
  const subProgress = clampProgress(subStage.progress, isStageDone(subStage) ? 100 : 0);

  const transDone = isStageDone(transStage);
  const dubDone = String(dubStage.status || "").toLowerCase() === "completed";
  const subDone = String(subStage.status || "").toLowerCase() === "completed";

  const transFailed = isStageFailed(transStage);
  const dubFailed = !isSubtitlesOnly && isStageFailed(dubStage);
  const subFailed = isSubtitlesOnly && isStageFailed(subStage);
  const jobFailed = overallStatus === "failed" || overallStatus === "rejected";

  const isFailed = jobFailed || transFailed || dubFailed || subFailed;
  const isCompleted = !isFailed && (isSubtitlesOnly
    ? (subDone || overallStatus === "completed")
    : (dubDone || overallStatus === "completed"));

  let status: DubbingJobStatus = "processing";
  let progressPercent = Math.max(10, clampProgress(studioJob?.progressPercent, 10));
  let currentStepMessage = String(
    studioJob?.currentStepMessage || "Extracting dialogue and generating transcription..."
  );
  let errorMessage: string | undefined;

  if (isFailed) {
    status = "failed";
    const rawError =
      dubStage.error ||
      subStage.error ||
      transStage.error ||
      videoJobData?.error ||
      videoJobData?.rejectionReason ||
      "We couldn't finish processing your media. If you were charged, your payment has been refunded.";
    errorMessage = String(rawError);
    currentStepMessage = errorMessage;
  } else if (isCompleted) {
    status = "completed";
    progressPercent = 100;
    currentStepMessage = isSubtitlesOnly
      ? "Subtitles are ready to download."
      : "Your dubbed video and audio tracks are ready.";
  } else if (!transDone) {
    status = "transcribing";
    progressPercent = Math.max(progressPercent, 10 + Math.round(transProgress * 0.25));
    currentStepMessage =
      transProgress >= 30
        ? "Transcribing spoken dialogue and detecting speakers..."
        : "Preparing audio and extracting speech...";
  } else if (isSubtitlesOnly) {
    status = "generating_subtitles";
    progressPercent = Math.max(progressPercent, 35 + Math.round(subProgress * 0.60));
    currentStepMessage = "Translating script and generating timed subtitles...";
  } else {
    // Transcription completed, dubbing running or pending
    const dubStatusStr = String(dubStage.status || "").toLowerCase();
    if (dubStatusStr !== "running" && dubProgress <= 5) {
      status = "translating";
      progressPercent = Math.max(progressPercent, 35);
      currentStepMessage = "Transcript ready. Preparing voices and translation...";
    } else if (dubProgress >= 90) {
      status = "muxing_audio";
      progressPercent = Math.max(progressPercent, 88 + Math.round((dubProgress - 90) * 0.9));
      currentStepMessage = "Mixing audio tracks and building dubbed video...";
    } else if (dubProgress >= 55) {
      status = "synthesizing_speech";
      progressPercent = Math.max(progressPercent, 60 + Math.round((dubProgress - 55) * 0.8));
      currentStepMessage = "Generating natural dubbed voices...";
    } else if (dubProgress >= 20) {
      status = "translating";
      progressPercent = Math.max(progressPercent, 45 + Math.round((dubProgress - 20) * 0.4));
      currentStepMessage = "Translating script and matching speaker voices...";
    } else {
      status = "diarizing";
      progressPercent = Math.max(progressPercent, 38 + Math.round(dubProgress * 0.3));
      currentStepMessage = "Analyzing acoustics and speaker profiles...";
    }
  }

  if (!isCompleted && !isFailed) {
    progressPercent = Math.min(99, Math.max(10, progressPercent));
  }

  // Normalize stage markers so the Studio UI's 5-step tracker accurately reflects progress.
  const audioPrepDone = transDone || transProgress >= 25 || dubProgress >= 10 || isCompleted;
  const speakersDone = isSubtitlesOnly
    ? transDone || isCompleted
    : (dubProgress >= 20 || dubDone || isCompleted);
  const transcriptDone = transDone || isCompleted;
  const voiceoverDone = isSubtitlesOnly ? (subDone || isCompleted) : (dubDone || isCompleted);
  const finalizeDone = isCompleted;

  const syncedStages: Record<string, any> = {
    ...stages,
    audio_extraction: { status: audioPrepDone ? "completed" : "running" },
    diarization: { status: speakersDone ? "completed" : (transDone ? "running" : "pending") },
    transcription: {
      ...transStage,
      status: transcriptDone ? "completed" : (transStage.status || "running"),
    },
    dubbing: {
      ...dubStage,
      status: voiceoverDone ? "completed" : (dubStage.status || (transDone ? "running" : "pending")),
    },
    mastering: { status: finalizeDone ? "completed" : (dubProgress >= 90 ? "running" : "pending") },
  };

  const outputs = videoJobData?.outputs && typeof videoJobData.outputs === "object" ? videoJobData.outputs : {};
  const originalUrl = String(videoJobData?.videoUrl || studioJob?.sourceMediaUrl || "");
  const videoByLang: Record<string, string> = {};
  const audioByLang: Record<string, string> = {};
  const dialogueByLang: Record<string, string> = {};
  const translationByLang: Record<string, string> = {};
  const srtMap: Record<string, string> = {};
  const vttMap: Record<string, string> = {};

  const lookupLangEntry = (map: Record<string, any>, dottedPrefix: string, lang: string): any => {
    const norm = lang.trim().toLowerCase();
    const direct = map[lang] ?? map[norm] ?? videoJobData?.[`${dottedPrefix}.${lang}`] ?? videoJobData?.[`${dottedPrefix}.${norm}`];
    if (direct !== undefined && direct !== null && direct !== "") return direct;
    for (const [k, v] of Object.entries(map)) {
      if (k.trim().toLowerCase() === norm && v !== undefined && v !== null && v !== "") return v;
    }
    return undefined;
  };

  const rawDubbedVideos = outputs.dubbedVideos && typeof outputs.dubbedVideos === "object" ? outputs.dubbedVideos : {};
  const rawDubbed = outputs.dubbed && typeof outputs.dubbed === "object" ? outputs.dubbed : {};
  const rawAudioTracks = outputs.audioTracks && typeof outputs.audioTracks === "object" ? outputs.audioTracks : {};
  const rawDialogueTracks = outputs.dialogueTracks && typeof outputs.dialogueTracks === "object"
    ? outputs.dialogueTracks
    : (outputs.stems?.dialogue && typeof outputs.stems.dialogue === "object" ? outputs.stems.dialogue : {});
  const rawTranslations = outputs.translations && typeof outputs.translations === "object" ? outputs.translations : {};
  const rawSubtitles = outputs.subtitles && typeof outputs.subtitles === "object" ? outputs.subtitles : {};

  for (const lang of targetLanguages) {
    const vidCandidate =
      extractUrlString(lookupLangEntry(rawDubbedVideos, "outputs.dubbedVideos", lang)) ||
      extractUrlString(lookupLangEntry(rawDubbed, "outputs.dubbed", lang));
    if (vidCandidate && isDubbedVideoUrl(vidCandidate, originalUrl)) {
      videoByLang[lang] = toDirectHttpUrl(vidCandidate);
    }
    const audCandidate =
      extractUrlString(lookupLangEntry(rawAudioTracks, "outputs.audioTracks", lang)) ||
      extractUrlString(lookupLangEntry(rawDubbed, "outputs.dubbed", lang)?.audioUrl);
    if (audCandidate) {
      audioByLang[lang] = toDirectHttpUrl(audCandidate);
    }
    const dlgCandidate = extractUrlString(lookupLangEntry(rawDialogueTracks, "outputs.dialogueTracks", lang));
    if (dlgCandidate) {
      dialogueByLang[lang] = toDirectHttpUrl(dlgCandidate);
    }
    const trCandidate = extractUrlString(lookupLangEntry(rawTranslations, "outputs.translations", lang));
    if (trCandidate) {
      translationByLang[lang] = toDirectHttpUrl(trCandidate);
    }
    const subEntry = lookupLangEntry(rawSubtitles, "outputs.subtitles", lang);
    const srtCandidate = extractUrlString(subEntry);
    if (srtCandidate) {
      srtMap[lang] = toDirectHttpUrl(srtCandidate);
    }
    const vttCandidate = extractVttUrlString(subEntry);
    if (vttCandidate) {
      vttMap[lang] = toDirectHttpUrl(vttCandidate);
    }
  }

  const rawVocalsStem = extractUrlString(outputs.stems?.vocals ?? videoJobData?.["outputs.stems.vocals"]);
  const vocalsStemMp3 = rawVocalsStem ? toDirectHttpUrl(rawVocalsStem) : "";
  const rawBgStem = extractUrlString(
    outputs.stems?.background ??
      outputs.stems?.mne ??
      videoJobData?.["outputs.stems.background"] ??
      videoJobData?.["outputs.stems.mne"]
  );
  const backgroundStemMp3 = rawBgStem ? toDirectHttpUrl(rawBgStem) : "";
  const rawReportUrl = extractUrlString(outputs.dubbingReportUrl ?? videoJobData?.["outputs.dubbingReportUrl"]);
  const reportJson = rawReportUrl ? toDirectHttpUrl(rawReportUrl) : "";

  const hasExportAssets =
    Object.keys(videoByLang).length > 0 ||
    Object.keys(audioByLang).length > 0 ||
    Object.keys(dialogueByLang).length > 0 ||
    Object.keys(translationByLang).length > 0 ||
    Object.keys(srtMap).length > 0 ||
    Boolean(vocalsStemMp3) ||
    Boolean(backgroundStemMp3) ||
    Boolean(reportJson);

  const now = Date.now();
  const patch: Record<string, any> = {
    status,
    progressPercent,
    currentStepMessage,
    stages: syncedStages,
    updatedAt: now,
  };

  if (isFailed && errorMessage) {
    patch.error = errorMessage;
  }

  if (isCompleted) {
    patch.completedAt = studioJob?.completedAt || videoJobData?.completedAt || now;
    if (hasExportAssets) {
      const existingExports =
        studioJob?.exportUrls && typeof studioJob.exportUrls === "object"
          ? (studioJob.exportUrls as Record<string, any>)
          : {};
      const existingVideos =
        existingExports.dubbedVideoByLanguage && typeof existingExports.dubbedVideoByLanguage === "object"
          ? (existingExports.dubbedVideoByLanguage as Record<string, string>)
          : {};
      const existingAudios =
        existingExports.dubbedAudioByLanguage && typeof existingExports.dubbedAudioByLanguage === "object"
          ? (existingExports.dubbedAudioByLanguage as Record<string, string>)
          : {};
      const existingDialogues =
        existingExports.dialogueAudioByLanguage && typeof existingExports.dialogueAudioByLanguage === "object"
          ? (existingExports.dialogueAudioByLanguage as Record<string, string>)
          : {};
      const existingTranslations =
        existingExports.translationJsonByLanguage && typeof existingExports.translationJsonByLanguage === "object"
          ? (existingExports.translationJsonByLanguage as Record<string, string>)
          : {};
      const existingSrt =
        existingExports.subtitlesSrt && typeof existingExports.subtitlesSrt === "object"
          ? (existingExports.subtitlesSrt as Record<string, string>)
          : {};
      const existingVtt =
        existingExports.subtitlesVtt && typeof existingExports.subtitlesVtt === "object"
          ? (existingExports.subtitlesVtt as Record<string, string>)
          : {};

      const mergedVideos = { ...videoByLang, ...existingVideos };
      const mergedAudios = { ...audioByLang, ...existingAudios };
      const mergedDialogues = { ...dialogueByLang, ...existingDialogues };
      const mergedTranslations = { ...translationByLang, ...existingTranslations };
      const mergedSrt = { ...srtMap, ...existingSrt };
      const mergedVtt = { ...vttMap, ...existingVtt };

      const mergedVocals = existingExports.vocalsStemMp3 || vocalsStemMp3;
      const mergedBg = existingExports.backgroundStemMp3 || backgroundStemMp3;
      const mergedReport = existingExports.reportJson || reportJson;
      const mergedFirstLang = targetLanguages.find((l) => mergedVideos[l] || mergedAudios[l]);

      const nextExports: Record<string, any> = {
        ...existingExports,
        dubbedVideoByLanguage: mergedVideos,
        dubbedAudioByLanguage: mergedAudios,
        ...(Object.keys(mergedDialogues).length > 0 ? { dialogueAudioByLanguage: mergedDialogues } : {}),
        ...(Object.keys(mergedTranslations).length > 0 ? { translationJsonByLanguage: mergedTranslations } : {}),
        ...(mergedVocals ? { vocalsStemMp3: mergedVocals } : {}),
        ...(mergedBg ? { backgroundStemMp3: mergedBg } : {}),
        ...(mergedReport ? { reportJson: mergedReport } : {}),
        ...(mergedFirstLang && mergedVideos[mergedFirstLang] ? { dubbedVideoMp4: mergedVideos[mergedFirstLang] } : {}),
        ...(mergedFirstLang && mergedAudios[mergedFirstLang] ? { dubbedAudioMp3: mergedAudios[mergedFirstLang] } : {}),
        subtitlesSrt: mergedSrt,
        subtitlesVtt: mergedVtt,
      };

      const changed =
        !studioJob?.exportUrls ||
        JSON.stringify(existingExports) !== JSON.stringify(nextExports);
      if (changed) {
        patch.exportUrls = nextExports;
      }
    }
  }

  return patch;
}

/**
 * Finds and updates `studio_dubbing_jobs` linked to `pipelineJobId`.
 */
export async function syncStudioDubbingJobsForPipelineJob(
  pipelineJobId: string,
  videoJobData?: Record<string, any> | null,
  overridePatch?: Partial<{ status: DubbingJobStatus; progressPercent: number; currentStepMessage: string; error: string }>
): Promise<number> {
  if (!pipelineJobId) return 0;
  try {
    const firestore = admin.firestore();
    const effectiveVideoJobData = videoJobData ??
      ((await firestore.collection("video_jobs").doc(pipelineJobId).get()).data() || {});

    const docs: FirebaseFirestore.QueryDocumentSnapshot[] | FirebaseFirestore.DocumentSnapshot[] = [];
    const directStudioId = typeof effectiveVideoJobData?.studioJobId === "string"
      ? effectiveVideoJobData.studioJobId.trim()
      : "";

    if (directStudioId) {
      const snap = await firestore.collection(STUDIO_JOBS_COLLECTION).doc(directStudioId).get();
      if (snap.exists) {
        (docs as FirebaseFirestore.DocumentSnapshot[]).push(snap);
      }
    }

    if (docs.length === 0) {
      const querySnap = await firestore
        .collection(STUDIO_JOBS_COLLECTION)
        .where("pipelineJobId", "==", pipelineJobId)
        .limit(5)
        .get();
      docs.push(...querySnap.docs);
    }

    if (docs.length === 0) return 0;

    let updatedCount = 0;
    for (const docSnap of docs) {
      const existing = docSnap.data() || {};
      const computed = computeStudioJobUpdate(effectiveVideoJobData, existing);
      if (overridePatch) {
        Object.assign(computed, overridePatch);
      }

      // Resolve accessible URLs for dubbed videos and audio tracks so browser playback/downloads never hit 403
      if (computed.exportUrls) {
        const { audioIdentityService } = require("../pipeline/services/audio-identity");
        const resolveUrlMap = async (rawMap: unknown): Promise<Record<string, string> | undefined> => {
          if (!rawMap || typeof rawMap !== "object") return undefined;
          const resolved: Record<string, string> = {};
          for (const [langKey, rawUrl] of Object.entries(rawMap as Record<string, string>)) {
            if (typeof rawUrl === "string" && rawUrl) {
              resolved[langKey] = await audioIdentityService.getAccessibleUrl(rawUrl).catch(() => rawUrl);
            }
          }
          return resolved;
        };

        const resolvedVideos = await resolveUrlMap(computed.exportUrls.dubbedVideoByLanguage);
        if (resolvedVideos) {
          computed.exportUrls.dubbedVideoByLanguage = resolvedVideos;
          const firstVid = Object.values(resolvedVideos).find((u) => Boolean(u));
          if (firstVid) {
            computed.exportUrls.dubbedVideoMp4 = firstVid;
          }
        }

        const resolvedAudios = await resolveUrlMap(computed.exportUrls.dubbedAudioByLanguage);
        if (resolvedAudios) {
          computed.exportUrls.dubbedAudioByLanguage = resolvedAudios;
          const firstAud = Object.values(resolvedAudios).find((u) => Boolean(u));
          if (firstAud) {
            computed.exportUrls.dubbedAudioMp3 = firstAud;
          }
        }

        const resolvedDialogues = await resolveUrlMap(computed.exportUrls.dialogueAudioByLanguage);
        if (resolvedDialogues) {
          computed.exportUrls.dialogueAudioByLanguage = resolvedDialogues;
        }
      }

      // Skip redundant writes if nothing meaningful changed
      if (
        existing.status === computed.status &&
        existing.progressPercent === computed.progressPercent &&
        existing.currentStepMessage === computed.currentStepMessage &&
        existing.error === computed.error &&
        !computed.exportUrls
      ) {
        continue;
      }

      await docSnap.ref.set(computed, { merge: true });
      updatedCount++;
    }
    return updatedCount;
  } catch (err) {
    logger.warn("[DubbingStudio:Sync] Failed to sync studio_dubbing_jobs", {
      pipelineJobId,
      error: String(err),
    });
    return 0;
  }
}
