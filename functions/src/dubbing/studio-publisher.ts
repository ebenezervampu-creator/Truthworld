import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { logger } from "firebase-functions/v2";
import { isVideoId } from "../utils/videosCollectionGuard";
import { toDirectHttpUrl } from "./studio-job-sync";

export interface PublishStudioJobParams {
  pipelineJobId: string;
  studioJobId?: string;
  userId: string;
  channelId: string;
  title: string;
  durationSeconds: number;
  sourceLanguage: string;
  sourceMediaUrl: string;
  dubbedPaths: Record<string, string>;
  audioPaths: Record<string, string>;
  subtitlePaths: Record<string, string>;
}

/**
 * Publishes a completed Standalone Dubbing Studio project to the creator's TruthWorld channel
 * using an authentic RFC-4122 UUID v4 document in `videos/{uuid}`.
 * Only called after dubbing delivery succeeds and only when `publishToTruthworld === true`.
 */
export async function publishCompletedStudioJobToTruthworld(
  params: PublishStudioJobParams
): Promise<string | null> {
  const {
    pipelineJobId,
    studioJobId,
    userId,
    channelId,
    title,
    durationSeconds,
    sourceLanguage,
    sourceMediaUrl,
    dubbedPaths,
    audioPaths,
    subtitlePaths,
  } = params;

  if (!channelId || !userId) return null;

  const firestore = admin.firestore();
  const channelSnap = await firestore.collection("channels").doc(channelId).get();
  if (!channelSnap.exists) {
    logger.warn("[DubbingStudio:Publish] Channel not found — skipping feed publish", {
      pipelineJobId,
      channelId,
    });
    return null;
  }

  const chData = channelSnap.data() || {};
  if (chData.ownerId !== userId && chData.userId !== userId) {
    logger.warn("[DubbingStudio:Publish] User does not own channel — skipping feed publish", {
      pipelineJobId,
      channelId,
      userId,
    });
    return null;
  }

  const videoUuid = crypto.randomUUID();
  if (!isVideoId(videoUuid)) {
    throw new Error("Generated video ID failed UUID v4 validation");
  }

  const normalizedDubbedVideos: Record<string, string> = {};
  for (const [lang, url] of Object.entries(dubbedPaths || {})) {
    if (url) normalizedDubbedVideos[lang] = toDirectHttpUrl(url);
  }

  const normalizedAudioTracks: Record<string, string> = {};
  const audioTrackSources: Record<string, string> = {};
  for (const [lang, url] of Object.entries(audioPaths || {})) {
    if (url) {
      normalizedAudioTracks[lang] = toDirectHttpUrl(url);
      audioTrackSources[lang] = "ai_dub";
    }
  }

  const normalizedSubtitles: Record<string, string> = {};
  for (const [lang, url] of Object.entries(subtitlePaths || {})) {
    if (url) normalizedSubtitles[lang] = toDirectHttpUrl(url);
  }

  const primaryVideoUrl =
    Object.values(normalizedDubbedVideos).find((u) => Boolean(u)) ||
    toDirectHttpUrl(sourceMediaUrl);

  const nowTs = admin.firestore.FieldValue.serverTimestamp();
  const docPayload = {
    id: videoUuid,
    ownerId: userId,
    userId,
    uploaderId: userId,
    channelId,
    channelName: String(chData.name || "TruthWorld Creator"),
    channelAvatarUrl: String(chData.image || chData.avatarUrl || ""),
    title: title || "Dubbed Video",
    description: "",
    videoUrl: primaryVideoUrl,
    originalVideoUrl: toDirectHttpUrl(sourceMediaUrl),
    durationSeconds: Math.max(1, Math.round(durationSeconds || 60)),
    language: sourceLanguage || "en",
    sourceLanguage: sourceLanguage || "en",
    dubbedVideos: normalizedDubbedVideos,
    audioTracks: normalizedAudioTracks,
    aiDubbedAudio: normalizedAudioTracks,
    audioTrackSources,
    subtitles: normalizedSubtitles,
    visibility: "public",
    status: "published",
    pipelineStatus: "completed",
    source: "dubbing_studio",
    pipelineJobId,
    views: 0,
    uploadedAt: nowTs,
    createdAt: nowTs,
    updatedAt: nowTs,
  };

  await firestore.collection("videos").doc(videoUuid).create(docPayload);

  await firestore
    .collection("video_jobs")
    .doc(pipelineJobId)
    .set(
      {
        videoId: videoUuid,
        linkedVideoIds: admin.firestore.FieldValue.arrayUnion(videoUuid),
        publishedToFeedAt: Date.now(),
      },
      { merge: true }
    )
    .catch(() => {});

  if (studioJobId) {
    await firestore
      .collection("studio_dubbing_jobs")
      .doc(studioJobId)
      .set(
        {
          videoId: videoUuid,
          updatedAt: Date.now(),
        },
        { merge: true }
      )
      .catch(() => {});
  }

  logger.info("[DubbingStudio:Publish] Published dubbed video to TruthWorld Feed", {
    videoUuid,
    pipelineJobId,
    channelId,
  });

  return videoUuid;
}
