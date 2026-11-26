/**
 * 🎥 RESOLUTION — Video Resolution Processing (≤ 2160p / 4K UHD)
 *
 * Firebase Cloud Function triggered by video uploads.
 * Processes uploaded videos into adaptive bitrate ladder up to 4K (2160p).
 *
 * ✅ FEATURES:
 *   - Storage trigger: onObjectFinalized for videos/ prefix
 *   - Resolution ladder: [2160p, 1440p, 1080p, 720p, 480p, 360p, 240p, 144p]
 *   - Stores processed metadata in Firestore
 *   - Stores processed files in Firebase Storage
 *   - minInstances: 0 (scale-to-zero)
 *
 * ✅ COST OPTIMIZATION:
 *   - Only transcode if source resolution >= target
 *   - Skip redundant resolutions (never upscale)
 *   - Bitrate ladder dynamically set per resolution
 *   - Heavy & long-form media (> 500 MB or > 10 min) delegated directly to GCP Transcoder API
 */

import * as admin from "firebase-admin";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { v4 as uuidv4 } from "uuid";
import { MessagingService } from "../shared/messaging";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { requireRecentAdmin, verifyAuth } from "../utils/auth";
import { checkAndMarkEventId, markEventCompleted, markEventFailed } from "../shared/idempotency";
import { safeMergeExistingVideoSubdoc } from "../utils/videosCollectionGuard";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";
import { TranscoderGateway } from "./transcoderGateway";
import { evaluateUploadOwnership, canViewResolution, toPublicVariants } from "./resolutionAccess";
import {
  planVariantRetries,
  tierFitsSource,
  playbackResetFields,
  secondaryBatchEventId,
  MAX_VARIANT_DISPATCH_ATTEMPTS,
  planUploadBatches,
  variantShortSide,
  TRANSCODE_FAILED_MESSAGE,
} from "./resolutionPlanning";
import {
  HlsRendition,
  FREE_MAX_SHORT_SIDE,
  buildMasterPlaylist,
  codecsFor,
  filterMasterByShortSide,
  firebaseDownloadUrl,
  hlsRemuxOutputOptions,
  measurePlaylistBandwidth,
  resolveRelativeObjectPath,
  rewritePlaylistUris,
} from "./hlsLadder";

let _ffmpegInitialized = false;
let _ffmpegInstance: any = null;

function getFFmpegInstance(): any {
  if (!_ffmpegInitialized) {
    const ffmpeg = require("fluent-ffmpeg");
    const ffmpegInstaller = require("ffmpeg-static");
    if (ffmpegInstaller) {
      ffmpeg.setFfmpegPath(ffmpegInstaller);
    }
    try {
      const ffprobeInstaller = require("@ffprobe-installer/ffprobe");
      if (ffprobeInstaller && ffprobeInstaller.path) {
        ffmpeg.setFfprobePath(ffprobeInstaller.path);
      }
    } catch {
      // Fallback handled in probeVideoFile
    }
    _ffmpegInstance = ffmpeg;
    _ffmpegInitialized = true;
  }
  return _ffmpegInstance;
}

const db = admin.firestore();
const REGION = "asia-south1";

// â”€â”€â”€ Resolution Configuration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/** Maximum resolution cap â€” 2160p (4K Ultra HD) */
const MAX_STANDARD_RESOLUTION_HEIGHT = 2160;
const MAX_CUSTOM_RESOLUTION_HEIGHT = 2160;

/** Full resolution ladder (descending). Only resolutions â‰¤ source are generated. */
export interface ResolutionProfile {
  height: number;
  width: number;
  label: string;
  bitrateKbps: number;
  audioBitrateKbps: number;
  fps: number;
}

/** Standard channel audio bitrate: 192 kbps (broadcast-standard transparent AAC stereo across all tiers) */
export const STANDARD_AUDIO_BITRATE_KBPS = 192;

/** Pro channel audio bitrate: 256 kbps (studio-grade high-fidelity AAC stereo across all tiers) */
export const CUSTOM_AUDIO_BITRATE_KBPS = 256;

export const STANDARD_RESOLUTION_LADDER: ResolutionProfile[] = [
  { height: 2160, width: 3840, label: "2160p", bitrateKbps: 15000, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 1440, width: 2560, label: "1440p", bitrateKbps: 10000, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 1080, width: 1920, label: "1080p", bitrateKbps: 4500, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 720, width: 1280, label: "720p", bitrateKbps: 2500, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 480, width: 854, label: "480p", bitrateKbps: 1200, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 360, width: 640, label: "360p", bitrateKbps: 800, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 240, width: 426, label: "240p", bitrateKbps: 400, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 24 },
  { height: 144, width: 256, label: "144p", bitrateKbps: 200, audioBitrateKbps: STANDARD_AUDIO_BITRATE_KBPS, fps: 15 },
];

export const CUSTOM_RESOLUTION_LADDER: ResolutionProfile[] = [
  { height: 2160, width: 3840, label: "2160p", bitrateKbps: 15000, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 1440, width: 2560, label: "1440p", bitrateKbps: 10000, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 1080, width: 1920, label: "1080p", bitrateKbps: 4500, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 720, width: 1280, label: "720p", bitrateKbps: 2500, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 480, width: 854, label: "480p", bitrateKbps: 1200, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 360, width: 640, label: "360p", bitrateKbps: 800, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 30 },
  { height: 240, width: 426, label: "240p", bitrateKbps: 400, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 24 },
  { height: 144, width: 256, label: "144p", bitrateKbps: 200, audioBitrateKbps: CUSTOM_AUDIO_BITRATE_KBPS, fps: 15 },
];

const VALID_VIDEO_EXTENSIONS = new Set([
  ".mp4", ".avi", ".mov", ".mkv", ".webm", ".flv", ".wmv", 
  ".3gpp", ".3gp", ".mpeg", ".mpg", ".mpegps", ".m4v", 
  ".dnxhr", ".prores", ".cineform", ".hevc"
]);

const VALID_AUDIO_EXTENSIONS = new Set([
  ".mp3", ".wav", ".m4a", ".aac", ".flac", ".ogg", ".opus", ".wma"
]);

export interface MediaProbeInfo {
  width: number;
  height: number;
  codec: string;
  fps: number;
  duration: number; // Media duration in seconds
  hasVideo: boolean;
  hasAudio: boolean;
  audioCodec: string;
  audioChannels: number;
  audioSampleRate: number;
  audioBitrateKbps: number;
  pixFmt?: string;
  profile?: string;
  videoBitrateKbps?: number;
}

/** Fallback probe using ffmpeg -i via child_process to ensure 100% reliability */
function probeWithFfmpegCli(filePath: string): Promise<MediaProbeInfo> {
  return new Promise((resolve) => {
    try {
      const { execFile } = require("child_process");
      const ffmpegInstaller = require("ffmpeg-static");
      if (!ffmpegInstaller) {
        return resolve({
          width: 0, height: 0, codec: "unknown", fps: 30, duration: 0,
          hasVideo: false, hasAudio: false, audioCodec: "none", audioChannels: 2,
          audioSampleRate: 48000, audioBitrateKbps: 0,
        });
      }
      execFile(ffmpegInstaller, ["-i", filePath], (err: any, stdout: string, stderr: string) => {
        const output = (stderr || "") + (stdout || "");
        let duration = 0;
        const durMatch = output.match(/Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/);
        if (durMatch) {
          duration = parseInt(durMatch[1], 10) * 3600 + parseInt(durMatch[2], 10) * 60 + parseFloat(durMatch[3]);
        }
        let width = 0, height = 0, codec = "unknown", fps = 30, hasVideo = false;
        const codecMatch = output.match(/Video:\s*([a-zA-Z0-9_-]+)/);
        if (codecMatch) {
          hasVideo = true;
          codec = codecMatch[1].toLowerCase();
        }
        const dimMatch = output.match(/,\s*(\d{2,5})x(\d{2,5})/);
        if (dimMatch) {
          width = parseInt(dimMatch[1], 10);
          height = parseInt(dimMatch[2], 10);
        }
        const fpsMatch = output.match(/,\s*(\d+(?:\.\d+)?)\s*(?:fps|tbr)/);
        if (fpsMatch) {
          fps = Math.round(parseFloat(fpsMatch[1])) || 30;
        }
        let hasAudio = false, audioCodec = "none", audioChannels = 2, audioSampleRate = 48000, audioBitrateKbps = 192;
        const audioMatch = output.match(/Audio:\s*([a-zA-Z0-9_-]+)/);
        if (audioMatch) {
          hasAudio = true;
          audioCodec = audioMatch[1].toLowerCase();
        }
        const rateMatch = output.match(/,\s*(\d{4,6})\s*Hz/);
        if (rateMatch) {
          audioSampleRate = parseInt(rateMatch[1], 10);
        }
        const chMatch = output.match(/,\s*(mono|stereo|\d+\s*channels?)/i);
        if (chMatch) {
          const ch = chMatch[1].toLowerCase();
          if (ch === "mono") audioChannels = 1;
          else if (ch === "stereo") audioChannels = 2;
          else {
            const m = ch.match(/(\d+)/);
            if (m) audioChannels = parseInt(m[1], 10);
          }
        }
        const bitMatch = output.match(/,\s*(\d+)\s*kb\/s/);
        if (bitMatch) {
          audioBitrateKbps = parseInt(bitMatch[1], 10);
        }

        resolve({
          width,
          height,
          codec,
          fps,
          duration: isNaN(duration) ? 0 : duration,
          hasVideo,
          hasAudio,
          audioCodec,
          audioChannels,
          audioSampleRate,
          audioBitrateKbps,
        });
      });
    } catch {
      resolve({
        width: 0, height: 0, codec: "unknown", fps: 30, duration: 0,
        hasVideo: false, hasAudio: false, audioCodec: "none", audioChannels: 2,
        audioSampleRate: 48000, audioBitrateKbps: 0,
      });
    }
  });
}

/** Helper to probe media dimensions, video codec, and audio stream properties with ffprobe + ffmpeg fallback */
function probeVideoFile(filePath: string): Promise<MediaProbeInfo> {
  return new Promise((resolve) => {
    try {
      getFFmpegInstance().ffprobe(filePath, async (err: any, metadata: any) => {
        if (err || !metadata || !metadata.streams) {
          const fallbackInfo = await probeWithFfmpegCli(filePath);
          resolve(fallbackInfo);
          return;
        }

        const videoStream = metadata.streams.find((s: any) => s.codec_type === "video");
        const audioStream = metadata.streams.find((s: any) => s.codec_type === "audio");

        const width = videoStream ? Number(videoStream.width) || 0 : 0;
        const height = videoStream ? Number(videoStream.height) || 0 : 0;
        const codec = videoStream ? String(videoStream.codec_name || "unknown") : "unknown";

        let fps = 30;
        if (videoStream) {
          if (videoStream.r_frame_rate) {
            const parts = String(videoStream.r_frame_rate).split("/");
            if (parts.length === 2) {
              const num = parseFloat(parts[0]);
              const den = parseFloat(parts[1]);
              if (den > 0) fps = Math.round(num / den);
            } else {
              fps = Math.round(parseFloat(videoStream.r_frame_rate)) || 30;
            }
          } else if (videoStream.avg_frame_rate) {
            const parts = String(videoStream.avg_frame_rate).split("/");
            if (parts.length === 2) {
              const num = parseFloat(parts[0]);
              const den = parseFloat(parts[1]);
              if (den > 0) fps = Math.round(num / den);
            }
          }
        }

        const hasAudio = !!audioStream;
        const audioCodec = audioStream ? String(audioStream.codec_name || "unknown").toLowerCase() : "none";
        const audioChannels = audioStream ? Math.max(1, Number(audioStream.channels) || 2) : 2;
        const audioSampleRate = audioStream ? Number(audioStream.sample_rate) || 48000 : 48000;
        const audioBitrateKbps = audioStream && audioStream.bit_rate
          ? Math.round(Number(audioStream.bit_rate) / 1000)
          : 0;

        const pixFmt = videoStream ? String(videoStream.pix_fmt || "").toLowerCase() : "";
        const profile = videoStream ? String(videoStream.profile || "") : "";
        const videoBitrateKbps = videoStream && videoStream.bit_rate
          ? Math.round(Number(videoStream.bit_rate) / 1000)
          : (metadata?.format?.bit_rate ? Math.round(Number(metadata.format.bit_rate) / 1000) : 0);

        const duration = metadata?.format?.duration
          ? parseFloat(metadata.format.duration)
          : (videoStream?.duration
              ? parseFloat(videoStream.duration)
              : (audioStream?.duration ? parseFloat(audioStream.duration) : 0));

        const parsedDuration = isNaN(duration) ? 0 : duration;

        if (width === 0 && parsedDuration === 0) {
          const fallbackInfo = await probeWithFfmpegCli(filePath);
          resolve(fallbackInfo);
          return;
        }

        resolve({
          width,
          height,
          codec,
          fps,
          duration: parsedDuration,
          hasVideo: !!videoStream,
          hasAudio,
          audioCodec,
          audioChannels,
          audioSampleRate,
          audioBitrateKbps,
          pixFmt,
          profile,
          videoBitrateKbps,
        });
      });
    } catch {
      probeWithFfmpegCli(filePath).then(resolve);
    }
  });
}

/**
 * Reads videos/{videoId} for the upload ownership gate.
 * Returns null when the doc does not exist. Read errors are thrown on purpose so
 * the Storage trigger fails and is retried (retry: true) instead of silently
 * dropping a legitimate upload.
 */
async function loadVideoDocForUpload(videoId: string): Promise<Record<string, any> | null> {
  const snap = await db.collection("videos").doc(videoId).get();
  return snap.exists ? (snap.data() || {}) : null;
}

/** True when the uid has an admin custom claim (same claims the rules check). */
async function isAdminUid(uid: unknown): Promise<boolean> {
  if (typeof uid !== "string" || uid.trim().length === 0) return false;
  try {
    const user = await admin.auth().getUser(uid);
    const claims = user.customClaims || {};
    return claims.admin === true || claims.role === "admin";
  } catch {
    return false;
  }
}

// â”€â”€â”€ Storage Trigger â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/**
 * Triggered when a video is uploaded to Firebase Storage under the `videos/` prefix.
 *
 * âœ… COST OPTIMIZED:
 *   - memory: 128MiB (only reads metadata, $0.0000002 per invocation)
 *   - minInstances: 0 (zero idle cost)
 *   - maxInstances: 2 (governed concurrency)
 *   - timeoutSeconds: 60s
 */
export const onVideoUploadedForResolution = onObjectFinalized(
  {
    bucket: process.env.STORAGE_BUCKET || (process.env.GCLOUD_PROJECT ? `${process.env.GCLOUD_PROJECT}.firebasestorage.app` : "truthworld-1.firebasestorage.app"),
    region: REGION,
    memory: "512MiB",       // 512MiB prevents OOM on Node.js 22 SDK initialization
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 20,       // Scale up to 20 concurrent instances for burst uploads
    retry: true,            // Auto-retry transient delivery failures
  },
  async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType ?? "";
    const bucket = event.data.bucket;

    // Only process files under videos/ prefix
    if (!filePath.startsWith("videos/")) {
      return;
    }

    // Validate content type for both video and audio assets
    const fileName = filePath.split("/").pop() ?? "";
    const ext = fileName.toLowerCase().slice(fileName.lastIndexOf("."));
    const isVideo = VALID_VIDEO_EXTENSIONS.has(ext) || contentType.startsWith("video/");
    const isAudio = VALID_AUDIO_EXTENSIONS.has(ext) || contentType.startsWith("audio/");
    if (!isVideo && !isAudio) {
      console.log(`[Resolution] Skipping non-media file: ${fileName}`);
      return;
    }

    // Extract videoId from path: videos/{videoId}/original.<ext>
    const pathParts = filePath.split("/");
    if (pathParts.length < 3) {
      console.error(`[Resolution] Unexpected path structure: ${filePath}`);
      return;
    }

    // Prevent non-primary sub-path assets (e.g., videos/{videoId}/tracks/...) from triggering resolution pipeline
    if (pathParts.length > 3) {
      console.log(`[Resolution] Skipping subfolder asset: ${filePath}`);
      return;
    }

    const videoId = pathParts[1]; // videos/[videoId]/...

    // ─── OWNERSHIP GATE (audit C1) ───────────────────────────────────────────
    // Only the video's own source upload, written by the video's owner (or an
    // admin), may start the pipeline. Without this, any signed-in user could
    // upload videos/<someone else's id>/x.mp4 and replace that video's playback.
    // Storage rules force metadata.uploaderId == request.auth.uid for client
    // uploads, so uploaderId is trustworthy here (userId/ownerId metadata is not).
    const storageMetadata = event.data.metadata ?? {};
    const uploaderId = storageMetadata.uploaderId;

    let videoData = await loadVideoDocForUpload(videoId);
    if (!videoData) {
      // The app creates the Firestore doc before uploading; allow a short lag.
      await new Promise((resolve) => setTimeout(resolve, 3000));
      videoData = await loadVideoDocForUpload(videoId);
    }

    const uploaderIsAdmin = await isAdminUid(uploaderId);
    const ownership = evaluateUploadOwnership({
      filePath,
      videoId,
      uploaderId,
      videoData,
      uploaderIsAdmin,
    });
    if (!ownership.allowed || !ownership.ownerId) {
      console.warn(`[Resolution Service] Upload ignored: ${ownership.reason}`, { videoId, filePath, uploaderId });
      return;
    }
    const userId = ownership.ownerId;

    console.log(`[Resolution Service] Processing source upload: ${filePath}`, { videoId, userId });

    // ─── IDEMPOTENCY GATE (audit H5) ─────────────────────────────────────────
    const generation = (event.data as any).generation || "1";
    const uploadEventId = `upload_${videoId}_${generation}`;
    // Lease slightly longer than this function's 120 s timeout: if a run crashes,
    // the retry (retry: true) can take over instead of being skipped for 10 minutes.
    const idempotencyStatus = await checkAndMarkEventId(uploadEventId, videoId, 150 * 1000);
    if (idempotencyStatus === "COMPLETED" || idempotencyStatus === "PROCESSING") {
      console.log(`[Resolution Service] Skipping already handled upload event ${uploadEventId}`, { videoId });
      return;
    }

    // Reset every playback field this service owns, so a re-upload never leaves
    // media.playbackReady: true pointing at an emptied ladder (re-audit R5).
    // The old files are overwritten in place, so their URLs stop working anyway.
    await db.collection("videos").doc(videoId).update({
      ...playbackResetFields(videoId, videoData, admin.firestore.FieldValue.delete()),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(() => null);

    // ─── MODERATION GATE: Skip resolution for rejected videos ────────────────
    if (videoData?.moderation?.status === "rejected") {
      console.log(`[Resolution Service] Video rejected by moderation; skipping resolution`, { videoId });
      await markEventCompleted(uploadEventId);
      return;
    }

    let channelType = "standard";
    if (videoData?.channelType === "custom" || videoData?.type === "custom" || videoData?.channelType === "pro" || videoData?.type === "pro") {
      channelType = "custom";
    }

    try {
      // 1. Read source metadata from GCS
      const [metadata] = await admin.storage().bucket(bucket).file(filePath).getMetadata();
      const fileSize = parseInt(String(metadata.size ?? "0"), 10);

      // Files over 500 MB are probed too (re-audit R2): ffprobe reads only the
      // container header through the signed URL, and isLongFormOr4K below still
      // sends them to the Transcoder, now with their real size, orientation and audio.

      // ─── P0 SIGNED-URL PROBING ──────────────────────────────────────────────────────
      // Probes container headers via HTTP range requests without downloading the entire media file
      let probedDuration = 0;
      let sourceHeight = parseInt(String(metadata.metadata?.height ?? "0"), 10);
      let sourceWidth = parseInt(String(metadata.metadata?.width ?? "0"), 10);
      let sourceFps = parseInt(String(metadata.metadata?.fps ?? metadata.metadata?.framerate ?? "30"), 10);
      let codec = String(metadata.metadata?.codec ?? "unknown");
      let hasAudio = true;

      try {
        const [signedUrl] = await admin.storage().bucket(bucket).file(filePath).getSignedUrl({
          action: "read",
          expires: Date.now() + 15 * 60 * 1000,
        });
        // Bounded so a stalled probe can't use up the trigger's 120 s budget.
        const probed = await Promise.race([
          probeVideoFile(signedUrl),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error("probe timed out after 45s")), 45 * 1000)),
        ]);
        if (probed.height > 0) sourceHeight = probed.height;
        if (probed.width > 0) sourceWidth = probed.width;
        if (probed.fps > 0) sourceFps = probed.fps;
        if (probed.duration > 0) probedDuration = probed.duration;
        if (probed.codec !== "unknown") codec = probed.codec;
        hasAudio = probed.hasAudio !== false;
      } catch (probeErr) {
        console.warn(`[Resolution Service] Signed URL probe fallback to GCS metadata`, { videoId, err: probeErr });
      }

      // ─── P0 DELEGATION GATE: Long-form (> 10 mins) or 4K Ultra HD (>= 5s) ───────────
      const isHeavyMedia = TranscoderGateway.isLongFormOr4K({
        fileSizeBytes: fileSize,
        durationSeconds: probedDuration,
        height: sourceHeight,
        width: sourceWidth,
      });

      if (isHeavyMedia) {
        console.log(`[Resolution Service] Video is heavy media (duration=${probedDuration.toFixed(1)}s, ${sourceWidth}x${sourceHeight}). Delegating to GCP Video Transcoder API.`, { videoId });

        await db.collection("resolution_jobs").doc(videoId).set({
          videoId,
          userId,
          sourcePath: filePath,
          sourceBucket: bucket,
          sourceHeight,
          sourceWidth,
          sourceDuration: probedDuration,
          sourceCodec: codec,
          sourceFileSize: fileSize,
          sourceFps,
          hasAudio,
          sourceGeneration: String(generation),
          hlsToken: uuidv4(),
          channelType,
          delegatedToTranscoder: true,
          status: "processing",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const jobResult = await TranscoderGateway.submitTranscodingJob({
          videoId,
          inputGcsUri: `gs://${bucket}/${filePath}`,
          outputGcsUri: `gs://${bucket}/resolutions/${videoId}/hls`,
          durationSeconds: probedDuration,
          hasAudio,
          sourceWidth,
          sourceHeight,
          sourceFps,
        });

        await db.collection("resolution_jobs").doc(videoId).update({
          transcoderJobName: jobResult.name,
          transcoderJobId: jobResult.jobId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await markEventCompleted(uploadEventId);
        return;
      }

      // Select ladder based on channelType (Standard & Custom both support up to 4K / 2160p)
      const baseLadder = channelType === "custom" ? CUSTOM_RESOLUTION_LADDER : STANDARD_RESOLUTION_LADDER;
      const maxLadderHeight = channelType === "custom" ? MAX_CUSTOM_RESOLUTION_HEIGHT : MAX_STANDARD_RESOLUTION_HEIGHT;

      // Determine effective source resolution by shorter dimension to support portrait and landscape (audit Medium)
      const isPortrait = sourceWidth > 0 && sourceHeight > 0 && sourceHeight > sourceWidth;
      const shorterSide = (sourceWidth > 0 && sourceHeight > 0)
        ? Math.min(sourceWidth, sourceHeight)
        : (sourceHeight || maxLadderHeight);
      const effectiveDimension = shorterSide > 0 ? Math.min(shorterSide, maxLadderHeight) : maxLadderHeight;
      const is60Fps = sourceFps >= 50;

      // Build applicable resolution ladder (only resolutions <= shorter side)
      // When source is 60fps, preserve native 60fps for high-definition tiers (>= 720p).
      // Lower tiers (480p, 360p, 240p, 144p) remain at 30 fps to save mobile data.
      const applicableResolutions = baseLadder
        .filter((r) => tierFitsSource(r.height, effectiveDimension))
        .map((r) => {
          const targetWidth = isPortrait ? r.height : r.width;
          const targetHeight = isPortrait ? r.width : r.height;
          if (is60Fps && r.height >= 720) {
            return {
              ...r,
              width: targetWidth,
              height: targetHeight,
              label: `${r.height}p60`,
              fps: 60,
              bitrateKbps: Math.round(r.bitrateKbps * 1.5),
            };
          }
          return {
            ...r,
            width: targetWidth,
            height: targetHeight,
          };
        });

      if (applicableResolutions.length === 0) {
        console.warn(`[Resolution] No applicable resolutions for dimension=${effectiveDimension}`);
        applicableResolutions.push(baseLadder[baseLadder.length - 1]); // at minimum 144p
      }

      // Build resolution variants (pending status)
      const variants: Record<string, {
        height: number;
        width: number;
        label: string;
        bitrateKbps: number;
        audioBitrateKbps: number;
        fps: number;
        status: "pending" | "processing" | "completed" | "failed";
        outputPath: string | null;
        downloadUrl?: string | null;
        processedAt: number | null;
        error: string | null;
      }> = {};

      for (const res of applicableResolutions) {
        variants[res.label] = {
          height: res.height,
          width: res.width,
          label: res.label,
          bitrateKbps: res.bitrateKbps,
          audioBitrateKbps: res.audioBitrateKbps,
          fps: res.fps,
          status: "pending",
          outputPath: null,
          downloadUrl: null,
          processedAt: null,
          error: null,
        };
      }

      // Store resolution job in Firestore
      await db.collection("resolution_jobs").doc(videoId).set({
        videoId,
        userId,
        sourcePath: filePath,
        sourceBucket: bucket,
        sourceHeight,
        sourceWidth,
        sourceCodec: codec,
        sourceFileSize: fileSize,
        sourceGeneration: String(generation),
        hlsToken: uuidv4(),
        channelType,
        maxResolution: effectiveDimension,
        variants,
        totalVariants: applicableResolutions.length,
        completedVariants: 0,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[Resolution] Job created`, {
        videoId,
        channelType,
        variants: applicableResolutions.map((r) => r.label).join(", "),
        maxRes: `${effectiveDimension}p`,
      });


      // â”€â”€â”€ Cost-Effective 2-Tier Event Publishing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      // Instead of 8 separate Pub/Sub events (which boots 8 parallel 4GiB Cloud Functions
      // each downloading the full 2GB raw video independently = 16GB download egress),
      // we partition variants into:
      // 1. Primary batch: downloads the original ONCE and makes 360p, then 720p and up.
      // 2. Secondary batch (other qualities below 720p): sent when the primary batch finishes,
      //    downscaling from the completed 720p.mp4 (25MB instead of 2GB) in seconds.
      //
      // Order (YouTube-style "low quality first"): 360p is made first from the original
      // so the video is playable within seconds, then 720p and up (lowest first). The
      // other low qualities stay pending and are made by the secondary batch from the
      // finished 720p file. See planUploadBatches.
      const primaryBatch = planUploadBatches(applicableResolutions).primary;

      const primaryEventId = `${videoId}_primary_${generation}`;
      await MessagingService.publish("resolution.requested", {
        eventId: primaryEventId,
        jobId: videoId,
        userId,
        timestamp: Date.now(),
        data: {
          videoId,
          sourcePath: filePath,
          sourceBucket: bucket,
          sourceHeight,
          variants: primaryBatch,
          totalVariants: applicableResolutions.length,
        },
      }, {
        source: "resolution-media-service",
        userId,
      });

      console.log(`[Resolution Service] Published primary resolution batch (${primaryBatch.map((r) => r.label).join(", ")}) for ${videoId}`);
      await markEventCompleted(uploadEventId);
    } catch (error) {
      console.error(`[Resolution] Failed to process upload`, {
        filePath,
        error: error instanceof Error ? error.message : String(error),
      });
      await markEventFailed(uploadEventId, error instanceof Error ? error.message : String(error));

      // Write error state
      await db.collection("resolution_jobs").doc(videoId).set({
        videoId,
        userId,
        sourcePath: filePath,
        status: "failed",
        error: error instanceof Error ? error.message : String(error),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => { });
    }
  }
);

// â”€â”€â”€ HTTP Endpoint â€” Status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/**
 * Get resolution processing status and available quality variants.
 *
 * âœ… CONFIG: minInstances=0, maxInstances=5, 256MiB, 30s timeout
 */
/**
 * Automated Reconciliation Engine: Guarantees that no video on TruthWorld ever has an incomplete ladder.
 * If a resolution job is stuck or missing lower tiers (480p, 360p, 240p, 144p), this function backfills
 * valid stream URLs using the lowest completed variant (e.g. 720p or 1080p), updates resolution_jobs to
 * status: "completed", and syncs the complete ladder down to 144p to the public videos document.
 */
export async function reconcileResolutionJob(videoId: string): Promise<boolean> {
  const jobRef = db.collection("resolution_jobs").doc(videoId);
  const videoRef = db.collection("videos").doc(videoId);

  const [jobSnap, videoSnap] = await Promise.all([
    jobRef.get(),
    videoRef.get(),
  ]);

  if (!jobSnap.exists) {
    return false;
  }

  const jobData = jobSnap.data() || {};
  const videoData = videoSnap.exists ? (videoSnap.data() || {}) : {};

  const variants = { ...(jobData.variants || {}) };

  // Find all currently completed variants with valid downloadUrls
  const completedList = Object.values(variants).filter(
    (v: any) => v && v.status === "completed" && v.downloadUrl && String(v.downloadUrl).trim().length > 0
  ) as any[];

  // P0/P2 ESCALATION: Guard against duplicate escalations to GCP Video Transcoder
  if (completedList.length === 0) {
    // 1. If already escalated or active job name exists, check Transcoder API status
    if (jobData.escalatedToTranscoder || jobData.transcoderJobName || jobData.status === "escalated_to_transcoder") {
      if (jobData.transcoderJobName) {
        try {
          const jobStatus = await TranscoderGateway.getJobStatus(jobData.transcoderJobName);
          if (jobStatus.state === "RUNNING" || jobStatus.state === "PENDING") {
            console.log(`[Resolution Reconcile] Video ${videoId} has active Transcoder job ${jobData.transcoderJobName} (state: ${jobStatus.state}). Guarding against duplicate escalation.`);
            await jobRef.update({ updatedAt: admin.firestore.FieldValue.serverTimestamp() }).catch(() => null);
            return true;
          }
          if (jobStatus.state === "SUCCEEDED") {
            // The completion message may have been lost: finalize here (idempotent).
            // Chapter thumbnails are left to the completion handler / manual trigger
            // to keep the scheduler inside its 120 s budget.
            console.log(`[Resolution Reconcile] Transcoder job for ${videoId} is SUCCEEDED but not finalized. Finalizing now.`);
            return await finalizeTranscoderJob(videoId, { extractChapters: false });
          }
          if (jobStatus.state === "FAILED") {
            console.warn(`[Resolution Reconcile] Transcoder job for ${videoId} FAILED:`, jobStatus.error);
            await markTranscoderJobFailed(videoId, jobStatus.error?.message || "GCP Video Transcoder job failed", "FAILED");
            return false;
          }
        } catch (statusErr) {
          console.warn(`[Resolution Reconcile] Error checking transcoder job status for ${videoId}:`, statusErr);
        }
        return true; // Durable lock in place, skip duplicate submission
      }

      // If locked without an active transcoderJobName, check 15-minute lease expiry (Audit H5 lock recovery)
      const escalatedAt = jobData.escalatedAt || 0;
      if (Date.now() - escalatedAt > 15 * 60 * 1000) {
        console.warn(`[Resolution Reconcile] Escalation lock expired without active job name for ${videoId}. Resetting lock to allow retry.`);
        await jobRef.update({
          escalatedToTranscoder: false,
          status: "processing",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Continues below to allow re-escalation
      } else {
        return true; // Lock still within 15-minute lease
      }
    }

    // 2. Not yet escalated: atomic check-and-lock in transaction BEFORE submitting paid job (audit H5)
    const sourcePath = jobData.sourcePath || `videos/${videoId}/original.mp4`;
    const bucketName = jobData.sourceBucket || admin.app().options.storageBucket || "truthworld-1.firebasestorage.app";
    const bucket = admin.storage().bucket(bucketName);
    const [sourceExists] = await bucket.file(sourcePath).exists().catch(() => [false]);

    if (sourceExists) {
      let shouldSubmit = false;
      await db.runTransaction(async (transaction) => {
        const curSnap = await transaction.get(jobRef);
        if (!curSnap.exists) return;
        const curData = curSnap.data() || {};
        if (curData.escalatedToTranscoder || curData.transcoderJobName || curData.status === "escalated_to_transcoder") {
          shouldSubmit = false;
          return;
        }
        transaction.update(jobRef, {
          status: "escalated_to_transcoder",
          escalatedToTranscoder: true,
          escalatedAt: Date.now(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        shouldSubmit = true;
      });

      if (shouldSubmit) {
        console.log(`[Resolution Reconcile] Escalating stuck job ${videoId} (0 completed variants) to GCP Video Transcoder API`);
        try {
          const transcodeResult = await TranscoderGateway.submitTranscodingJob({
            videoId,
            inputGcsUri: `gs://${bucket.name}/${sourcePath}`,
            outputGcsUri: `gs://${bucket.name}/resolutions/${videoId}/hls`,
            durationSeconds: jobData.sourceDuration || 600,
            hasAudio: jobData.hasAudio !== false,
            sourceWidth: jobData.sourceWidth,
            sourceHeight: jobData.sourceHeight,
            sourceFps: jobData.sourceFps,
          });
          await jobRef.update({
            transcoderJobName: transcodeResult.name,
            transcoderJobId: transcodeResult.jobId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return true;
        } catch (transcodeErr: any) {
          console.warn(`[Resolution Reconcile] Failed to escalate ${videoId} to GCP Transcoder:`, transcodeErr);
          await jobRef.update({
            status: "failed",
            escalatedToTranscoder: false,
            error: transcodeErr?.message || String(transcodeErr),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          await videoRef.update({
            "media.transcodeFailed": true,
            "media.transcodeError": TRANSCODE_FAILED_MESSAGE,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }).catch(() => null);
          return false;
        }
      }
      return true;
    }
  }

  // ─── AUDIT C3 FIX: Never mark missing tiers completed with fake URLs ────────
  // Re-dispatch any pending/stalled variants to the worker instead of fabricating fake tiers.
  // Each variant is re-sent at most MAX_VARIANT_DISPATCH_ATTEMPTS times (re-audit R1):
  // a variant whose worker keeps dying (timeout / out of memory) would otherwise be
  // re-sent every 15-25 minutes forever, each a 4 GiB, up-to-9-minute run.
  const retryPlan = planVariantRetries(variants);

  if (retryPlan.retry.length > 0 || retryPlan.giveUp.length > 0) {
    const variantUpdates: Record<string, any> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    for (const label of retryPlan.giveUp) {
      const message = `Gave up after ${MAX_VARIANT_DISPATCH_ATTEMPTS} attempts`;
      variantUpdates[`variants.${label}.status`] = "failed";
      variantUpdates[`variants.${label}.error`] = message;
      variants[label] = { ...variants[label], status: "failed", error: message };
    }
    for (const label of retryPlan.retry) {
      variantUpdates[`variants.${label}.status`] = "pending";
      variantUpdates[`variants.${label}.dispatchAttempts`] = admin.firestore.FieldValue.increment(1);
    }
    await jobRef.update(variantUpdates);

    if (retryPlan.giveUp.length > 0) {
      console.warn(`[Resolution Reconcile] Giving up on ${retryPlan.giveUp.join(", ")} for ${videoId} after ${MAX_VARIANT_DISPATCH_ATTEMPTS} attempts`);
    }

    if (retryPlan.retry.length > 0) {
      const retryVariants = retryPlan.retry.map((label) => ({ ...variants[label], status: "pending" }));
      console.log(`[Resolution Reconcile] Re-dispatching ${retryVariants.length} pending variants for ${videoId}`);
      const reconcileEventId = `${videoId}_reconcile_${Date.now()}`;
      await MessagingService.publish("resolution.requested", {
        eventId: reconcileEventId,
        jobId: videoId,
        userId: jobData.userId,
        timestamp: Date.now(),
        data: {
          videoId,
          sourcePath: jobData.sourcePath,
          sourceBucket: jobData.sourceBucket || "truthworld-1.firebasestorage.app",
          sourceHeight: jobData.sourceHeight,
          variants: retryVariants,
          totalVariants: jobData.totalVariants || Object.keys(variants).length,
        },
      }, {
        source: "resolution-media-service",
        userId: jobData.userId,
      });
      return true;
    }
    // Every unfinished variant was given up on: finalize below with what completed.
  }

  // If no pending variants remain, finalize status strictly based on genuine completed variants
  const genuineCompleted = Object.values(variants).filter(
    (v: any) => v && v.status === "completed" && v.downloadUrl && !v.fallback
  ) as any[];

  if (genuineCompleted.length > 0) {
    const totalCount = Object.keys(variants).length;
    await jobRef.update({
      completedVariants: genuineCompleted.length,
      totalVariants: Math.max(totalCount, genuineCompleted.length),
      status: "completed",
      reconciledAt: Date.now(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (videoSnap.exists) {
      const adaptiveList = genuineCompleted.map((v: any) => ({
        label: v.label,
        url: v.downloadUrl,
        width: v.width,
        height: v.height,
        bitrate: (v.bitrateKbps || 2500) * 1000,
      }));
      adaptiveList.sort((a, b) => (b.height || 0) - (a.height || 0));

      const mediaVariants: Record<string, string> = { ...(videoData.media?.variants || {}) };
      for (const v of genuineCompleted) {
        if (v.downloadUrl) mediaVariants[v.label] = v.downloadUrl;
      }

      await videoRef.update({
        adaptiveResolutions: adaptiveList,
        "media.adaptiveResolutions": adaptiveList,
        "media.variants": mediaVariants,
        "media.maxQuality": adaptiveList[0]?.label || "1080p",
        "media.playbackReady": true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(err => console.warn(`[Resolution Reconcile] Video sync non-fatal error:`, err));
    }

    console.log(`[Resolution Reconcile] Successfully reconciled job ${videoId}: ${genuineCompleted.length} authentic tiers finalized.`);
    return true;
  } else {
    // All variants failed
    await jobRef.update({
      status: "failed",
      error: "All resolution variants failed",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await videoRef.update({
      "media.transcodeFailed": true,
      "media.transcodeError": TRANSCODE_FAILED_MESSAGE,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(() => null);
    return false;
  }
}

export const getVideoResolutionStatus = onRequest(
  {
    region: REGION,
    memory: "256MiB",
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 20,
    cors: true,
  },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const videoId = req.query.videoId as string;

      if (!videoId || typeof videoId !== "string") {
        res.status(400).json({ error: "videoId query parameter is required" });
        return;
      }

      // Access check (audit C4): private / draft videos are visible only to
      // their owner and admins. The same 404 is returned for "no job" and
      // "not allowed" so callers can't probe which private videos exist.
      const [doc, videoSnap, requester] = await Promise.all([
        db.collection("resolution_jobs").doc(videoId).get(),
        db.collection("videos").doc(videoId).get(),
        verifyAuth(req),
      ]);

      const allowed = canViewResolution({
        videoData: videoSnap.exists ? videoSnap.data() : null,
        requesterUid: requester?.uid,
        requesterIsAdmin: requester?.isAdmin === true,
      });

      if (!doc.exists || !allowed) {
        res.status(404).json({ error: "Resolution job not found" });
        return;
      }

      // Read-only: this public GET no longer runs reconcileResolutionJob.
      // Reconciling from here marked unfinished lower tiers as completed with a
      // higher tier's URL, so they were never transcoded (audit C3), and let any
      // anonymous caller trigger writes. The scheduled reconciler still runs.
      const data = doc.data()!;
      const variants = toPublicVariants(data.variants);

      const availableQualities = Object.entries(variants)
        .filter(([, variant]) => variant.status === "completed")
        .map(([label]) => label);

      res.status(200).json({
        videoId,
        status: data.status,
        maxResolution: `${data.maxResolution}p`,
        sourceResolution: data.sourceHeight > 0 ? `${data.sourceHeight}p` : "unknown",
        totalVariants: data.totalVariants,
        completedVariants: data.completedVariants,
        availableQualities,
        variants,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      });
    } catch (error) {
      console.error("[Resolution] Status query failed", { error });
      res.status(500).json({ error: "Failed to retrieve resolution status" });
    }
  }
);

// â”€â”€â”€ HTTP Endpoint â€” Available Profiles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/**
 * Returns the resolution ladder configuration.
 * Useful for client-side adaptive bitrate player configuration.
 *
 * âœ… CONFIG: minInstances=0, maxInstances=5, 256MiB, 10s timeout
 */
export const getResolutionProfiles = onRequest(
  {
    region: REGION,
    memory: "256MiB",
    timeoutSeconds: 10,
    minInstances: 0,
    maxInstances: 2,
    cors: true,
  },
  async (req, res) => {
    applySecurityHeaders(res);
    const isCustom = req.query.type === "custom";
    const ladder = isCustom ? CUSTOM_RESOLUTION_LADDER : STANDARD_RESOLUTION_LADDER;
    res.status(200).json({
      maxResolution: isCustom ? `${MAX_CUSTOM_RESOLUTION_HEIGHT}p` : `${MAX_STANDARD_RESOLUTION_HEIGHT}p`,
      profiles: ladder.map((r) => ({
        label: r.label,
        height: r.height,
        width: r.width,
        bitrateKbps: r.bitrateKbps,
        audioBitrateKbps: r.audioBitrateKbps,
        fps: r.fps,
      })),
    });
  }
);

// â”€â”€â”€ Pub/Sub Worker â€” Process Resolution â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/**
 * Worker triggered by 'resolution.requested' Pub/Sub topic via push subscription.
 *
 * ðŸ’° INDUSTRY-STANDARD TRANSCODING ENGINE:
 *   1. 2GiB RAM allocation to prevent OOM on large video downloads & FFmpeg transcode
 *   2. Native resolution passthrough (-c copy) when source matches target
 *   3. Universal browser compatibility via -pix_fmt yuv420p, -c:v libx264, -c:a aac
 *   4. Direct Firebase Storage download token generation for 100% reliable HTML5 playback
 *   5. Immediate /tmp disk cleanup to ensure 0 disk leakage
 *   6. Real-time UI exposure on each variant completion
 *
 * âœ… CONFIG: minInstances=0 (scale-to-zero), maxInstances=5, 2GiB memory, 540s timeout
 */
export const handleResolution = onMessagePublished(
  {
    topic: "resolution.requested",
    region: REGION,
    memory: "4GiB",         // 4GiB RAM guarantees zero OOM on 1080p/4K transcode & tmpfs downloads
    timeoutSeconds: 540,    // 540s (9 minutes) max allowed timeout for Pub/Sub event triggers
    minInstances: 0,        // Scale-to-zero (0 idle cost)
    maxInstances: 5,        // Scale up to 5 concurrent workers (20GiB max allocation)
    retry: false,           // Prevent triple-billing loop on hard SIGKILL / timeout (P2 guard)
  },
  async (event) => {
    const t0 = Date.now();
    let videoId = "unknown";
    let parsedEvent: any = null;

    // P2 GUARD: Clean up stale /tmp workspaces (> 10m old) from warm container instances
    try {
      const tmpBase = os.tmpdir();
      const entries = fs.readdirSync(tmpBase);
      const now = Date.now();
      for (const entry of entries) {
        if (entry.startsWith("res_") || entry.startsWith("capture_") || entry.startsWith("ch_extract_")) {
          const fullPath = path.join(tmpBase, entry);
          try {
            const stat = fs.statSync(fullPath);
            if (now - stat.mtimeMs > 10 * 60 * 1000) {
              fs.rmSync(fullPath, { recursive: true, force: true });
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    try {
      // 1. Parse Pub/Sub message autonomously
      parsedEvent = MessagingService.parseMessage<{
        jobId: string;
        eventId: string;
        data: {
          videoId: string;
          sourcePath: string;
          sourceBucket: string;
          sourceHeight?: number;
          variant?: ResolutionProfile;       // Per-variant payload (preferred)
          variants?: ResolutionProfile[];    // Legacy array payload
          totalVariants?: number;
        };
      }>(event.data.message);

      videoId = parsedEvent.jobId;
      const { sourcePath, sourceBucket, sourceHeight: initialSourceHeight = 0, variant, variants: legacyVariants } = parsedEvent.data;

      // Extract the list of variants to process in this function invocation
      const variantsToProcess: ResolutionProfile[] = variant
        ? [variant]
        : (legacyVariants && legacyVariants.length > 0 ? legacyVariants : []);

      if (variantsToProcess.length === 0) {
        console.warn(`[Resolution Worker] No variants to process for ${videoId}`);
        return;
      }

      // 2. IDEMPOTENCY â€” Check if event was already handled
      const status = await checkAndMarkEventId(parsedEvent.eventId, videoId);
      if (status === "COMPLETED" || status === "PROCESSING") {
        console.log(`[Resolution Worker] Duplicate event detected, skipping: ${parsedEvent.eventId}`, { videoId });
        return;
      }

      console.log(`[Resolution Worker] Starting job: ${videoId}`, {
        variantLabels: variantsToProcess.map(v => v.label).join(", "),
        eventId: parsedEvent.eventId,
      });

      // 3. Update overall status to processing (atomic & idempotent)
      await db.collection("resolution_jobs").doc(videoId).set({
        status: "processing",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // 4. PREPARE LOCAL WORKSPACE (Unique subfolder per event to prevent collisions)
      const instanceId = uuidv4().slice(0, 8);
      const tempDir = path.join(os.tmpdir(), `res_${videoId}_${instanceId}`);
      if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

      const localSourcePath = path.join(tempDir, "original.mp4");
      const bucket = admin.storage().bucket(sourceBucket);

      try {
        // Safe file size guard to prevent tmpfs RAM exhaustion (> 2.5 GB)
        const [sourceMetadata] = await bucket.file(sourcePath).getMetadata();
        const sourceSizeBytes = parseInt(String(sourceMetadata.size || "0"), 10);
        const MAX_TRANSCODE_BYTES = 2.5 * 1024 * 1024 * 1024; // 2.5 GB cap
        if (sourceSizeBytes > MAX_TRANSCODE_BYTES) {
          console.warn(`[Resolution Worker] Source video exceeds 2.5 GB (${sourceSizeBytes} bytes). Skipping full transcode to protect container RAM.`, { videoId });
          await db.collection("resolution_jobs").doc(videoId).update({
            [`variants.${variantsToProcess[0]?.label || "default"}.status`]: "skipped",
            [`variants.${variantsToProcess[0]?.label || "default"}.error`]: "Video exceeds maximum serverless transcode limit (> 2.5 GB)",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        let sourceToDownload = sourcePath;
        // Optimization: For lower tiers (<= 480p), if 720p is already transcoded, use 720p as source to save 75% CPU and download bandwidth
        const allLowTier = variantsToProcess.every((v) => variantShortSide(v) <= 480);
        if (allLowTier) {
          const transCandidates = [
            `resolutions/${videoId}/720p.mp4`,
            `resolutions/${videoId}/720p60.mp4`,
            `resolutions/${videoId}/1080p.mp4`,
            `resolutions/${videoId}/1080p60.mp4`,
          ];
          for (const cand of transCandidates) {
            const [exists] = await bucket.file(cand).exists().catch(() => [false]);
            if (exists) {
              sourceToDownload = cand;
              console.log(`[Resolution Worker] Cascaded downscaling: using completed ${cand} as transcode source for low tier batch`, { videoId });
              break;
            }
          }
        }

        console.log(`[Resolution Worker] Downloading source: ${sourceToDownload} (${(sourceSizeBytes / (1024 * 1024)).toFixed(1)} MB)`, { videoId });
        await bucket.file(sourceToDownload).download({ destination: localSourcePath });

        // Probe downloaded file directly with ffprobe for accurate dimensions and audio streams
        const probed = await probeVideoFile(localSourcePath);
        const actualSourceHeight = probed.height > 0 ? probed.height : initialSourceHeight;
        const actualSourceWidth = probed.width > 0 ? probed.width : 0;
        console.log(`[Resolution Worker] Source probed: ${actualSourceWidth}x${actualSourceHeight}, videoCodec=${probed.codec}, hasAudio=${probed.hasAudio}, audioCodec=${probed.audioCodec}, audioChannels=${probed.audioChannels}, audioRate=${probed.audioSampleRate}Hz, audioBitrate=${probed.audioBitrateKbps}kbps`, { videoId });

        const variantRef = db.collection("resolution_jobs").doc(videoId);

        // 5. PROCESS EACH VARIANT (Sequentially per container to guarantee low RAM usage)
        for (const targetVariant of variantsToProcess) {
          const variantLabel = targetVariant.label;

          // Check if already completed (idempotency for partial retries)
          const currentDoc = await variantRef.get();
          const currentData = currentDoc.data();
          if (currentData?.variants?.[variantLabel]?.status === "completed") {
            console.log(`[Resolution Worker] Variant ${variantLabel} already completed, skipping.`, { videoId });
            continue;
          }

          // ðŸš« STRICT NO-UPSCALING GATE:
          // Never generate resolutions higher than the source video uploaded by the creator.
          // E.g. If creator uploads 720p, only generate 720p, 480p, 360p, 240p, 144p (never 1080p, 1440p, 2160p).
          if (actualSourceHeight > 0 && targetVariant.height > actualSourceHeight + 16) {
            console.log(`[Resolution Worker] ðŸš« Skipping upscaling: variant ${variantLabel} (${targetVariant.height}p) > source (${actualSourceHeight}p)`, { videoId });
            await variantRef.update({
              [`variants.${variantLabel}.status`]: "skipped",
              [`variants.${variantLabel}.error`]: `Source resolution (${actualSourceHeight}p) is lower than target (${targetVariant.height}p)`,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            continue;
          }

          console.log(`[Resolution Worker] Transcoding variant: ${variantLabel} (${targetVariant.height}p)`, { videoId });

          await variantRef.update({
            [`variants.${variantLabel}.status`]: "processing",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const localOutputPath = path.join(tempDir, `${variantLabel}.mp4`);
          const targetPath = `resolutions/${videoId}/${variantLabel}.mp4`;

          // ðŸ’° COST OPTIMIZATION: Passthrough Copy for Native Resolution
          // If the source video matches this resolution height and is already MP4 H.264/AAC, fast-copy!
          const isYuv420p = !probed.pixFmt || probed.pixFmt === "yuv420p";
          const isCompatibleProfile = !probed.profile || ["Constrained Baseline", "Baseline", "Main", "High"].includes(probed.profile);
          const isBitrateReasonable = !probed.videoBitrateKbps || probed.videoBitrateKbps <= targetVariant.bitrateKbps * 1.5;

          const isNativeMatch = actualSourceHeight > 0 &&
            Math.abs(actualSourceHeight - targetVariant.height) <= 16 &&
            probed.codec.includes("h264") &&
            sourcePath.endsWith(".mp4") &&
            isYuv420p &&
            isCompatibleProfile &&
            isBitrateReasonable;

          try {
            if (isNativeMatch) {
              console.log(`[Resolution Worker] âš¡ Native passthrough copy for ${variantLabel} (0 CPU re-encoding cost)`, { videoId });
              await new Promise<void>((resolve, reject) => {
                getFFmpegInstance()(localSourcePath)
                  .outputOptions([
                    "-c copy",
                    "-movflags", "+faststart",
                  ])
                  .output(localOutputPath)
                  .on("end", () => resolve())
                  .on("error", (err: Error) => reject(err))
                  .run();
              });
            } else {
              // Build audio processing options based on probed source audio
              const audioOptions: string[] = [];

              if (!probed.hasAudio) {
                // Video is silent / contains no audio stream
                audioOptions.push("-an");
              } else if (
                probed.audioCodec === "aac" &&
                probed.audioChannels <= 2 &&
                (probed.audioSampleRate === 44100 || probed.audioSampleRate === 48000)
              ) {
                // âš¡ ZERO-GENERATION-LOSS PASSTHROUGH:
                // Source audio is already AAC stereo/mono at standard broadcast sample rate.
                // Stream-copy audio directly without re-compression to preserve 100% master audio quality across all resolution tiers.
                audioOptions.push("-c:a", "copy");
              } else {
                // Re-encode audio to high-fidelity AAC (192 kbps Standard, 256 kbps Custom)
                const targetSampleRate = probed.audioSampleRate >= 44100 && probed.audioSampleRate <= 96000
                  ? probed.audioSampleRate
                  : 48000;

                audioOptions.push("-c:a", "aac");
                audioOptions.push("-b:a", `${targetVariant.audioBitrateKbps}k`);
                audioOptions.push("-ar", String(targetSampleRate));

                // Multi-channel surround downmix protection:
                // Dolby Pro Logic II / matrix downmix keeps center dialogue clean and loud
                if (probed.audioChannels > 2) {
                  audioOptions.push("-af", "aresample=matrix_encoding=dplii");
                  audioOptions.push("-ac", "2");
                } else if (probed.audioChannels === 1) {
                  audioOptions.push("-ac", "1");
                } else {
                  audioOptions.push("-ac", "2");
                }
              }

              // Execute FFmpeg Transcode with Standard Progressive Faststart Profile:
              // - Fixed Closed-GOP aligned keyframes across all resolution tiers (-g, -keyint_min, -sc_threshold 0)
              // - Web-optimized progressive MP4 with moov atom at beginning (+faststart) for immediate playback and full duration metadata
              // - P1 Tuning: Tier 1 (>= 720p) uses 'superfast' + CRF 22 to restore CABAC arithmetic coding & B-frames,
              //   preventing VBV buffer starvation in high-motion scenes and generating a pristine intermediate for cascaded downscaling.
              // - Lower mobile tiers (< 720p) use 'ultrafast' + CRF 23.
              const isHighTier = variantShortSide(targetVariant) >= 720;
              const preset = isHighTier ? "superfast" : "ultrafast";
              const crf = isHighTier ? "22" : "23";

              await new Promise<void>((resolve, reject) => {
                getFFmpegInstance()(localSourcePath)
                  .outputOptions([
                    "-c:v", "libx264",
                    "-pix_fmt", "yuv420p",
                    "-crf", crf,
                    "-maxrate", `${targetVariant.bitrateKbps}k`,
                    "-bufsize", `${targetVariant.bitrateKbps * 2}k`,
                    "-preset", preset,
                    "-g", String(targetVariant.fps),            // Fixed 1-second GOP strictly aligned across tiers
                    "-keyint_min", String(targetVariant.fps),   // Closed GOP minimum keyframe interval
                    "-sc_threshold", "0",                       // Disable scene detection keyframe variance to enforce strict GOP alignment
                    "-vf", `scale=-2:${targetVariant.height}`,
                    ...audioOptions,
                    "-r", String(targetVariant.fps),
                    "-threads", "0",
                    "-movflags", "+faststart",
                  ])
                  .output(localOutputPath)
                  .on("start", (cmd: string) => console.log(`[FFmpeg Progressive Faststart] ${variantLabel}: ${cmd}`))
                  .on("end", () => resolve())
                  .on("error", (err: Error) => reject(err))
                  .run();
              });
            }

            // 🛡️ Scale & Integrity Guard: Verify output file with ffprobe/ffmpeg before uploading
            const outputProbed = await probeVideoFile(localOutputPath);
            const sourceDuration = probed.duration > 0 ? probed.duration : 0;
            if (sourceDuration > 10) {
              if (outputProbed.duration <= 5 || outputProbed.duration < sourceDuration * 0.85) {
                throw new Error(
                  `Output stream integrity violation: output duration (${outputProbed.duration.toFixed(1)}s) is truncated compared to source (${sourceDuration.toFixed(1)}s). Aborting corrupted upload.`
                );
              }
            }
            if (probed.hasVideo && !outputProbed.hasVideo) {
              throw new Error(
                `Output stream integrity violation: source video has visual stream but transcode produced zero video tracks. Aborting corrupted upload.`
              );
            }
            console.log(
              `[Resolution Worker] Output integrity verified for ${variantLabel}: ${outputProbed.width}x${outputProbed.height}, duration=${outputProbed.duration.toFixed(1)}s, codec=${outputProbed.codec}`
            );

            // Generate Firebase Storage download token for direct, auth-free client playback
            const downloadToken = uuidv4();

            // Upload processed file to Firebase Storage
            console.log(`[Resolution Worker] Uploading: ${variantLabel}`, { videoId });
            await bucket.upload(localOutputPath, {
              destination: targetPath,
              metadata: {
                contentType: "video/mp4",
                metadata: {
                  firebaseStorageDownloadTokens: downloadToken,
                  resolution: variantLabel,
                  height: String(targetVariant.height),
                  width: String(targetVariant.width),
                  bitrate: String(targetVariant.bitrateKbps * 1000),
                },
              },
            });

            const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(targetPath)}?alt=media&token=${downloadToken}`;

            // Update Firestore resolution_jobs document
            await variantRef.update({
              [`variants.${variantLabel}.status`]: "completed",
              [`variants.${variantLabel}.outputPath`]: targetPath,
              [`variants.${variantLabel}.downloadUrl`]: downloadUrl,
              [`variants.${variantLabel}.processedAt`]: Date.now(),
              completedVariants: admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Immediately expose new resolution to the main 'videos' collection in real-time
            await syncVariantToVideoDoc(videoId, bucket.name, variantLabel, targetVariant, targetPath, downloadToken, probed.duration);

            // Adaptive HLS: remux this quality (no re-encode) into one fragmented-MP4
            // file + byte-range playlist, then refresh the master playlists so players
            // can switch qualities seamlessly. Non-fatal: the MP4 above still plays.
            try {
              const hlsToken = await getOrCreateHlsToken(variantRef);
              const rendition = await packageVariantHls({
                localOutputPath,
                tempDir,
                bucket,
                videoId,
                label: variantLabel,
                fps: targetVariant.fps,
                generation: String(currentData?.sourceGeneration || "1"),
                token: hlsToken,
              });
              if (rendition) {
                await variantRef.update({
                  [`variants.${variantLabel}.hls`]: rendition,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                await publishAbrMasters(videoId, bucket.name);
              }
            } catch (hlsErr) {
              console.warn(`[Resolution Worker] HLS packaging failed for ${variantLabel} (non-fatal):`, hlsErr);
            }

          } catch (variantErr) {
            console.error(`[Resolution Worker] Variant failed: ${variantLabel}`, {
              videoId,
              err: variantErr instanceof Error ? variantErr.message : String(variantErr),
            });

            // Audit C3 fix: Mark failed variants as failed; never mark completed with fallback: true or another tier's URL
            await variantRef.update({
              [`variants.${variantLabel}.status`]: "failed",
              [`variants.${variantLabel}.error`]: variantErr instanceof Error ? variantErr.message : String(variantErr),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }).catch(() => null);
          } finally {
            // Immediate cleanup of output file to keep /tmp memory usage minimal
            if (fs.existsSync(localOutputPath)) {
              try { fs.unlinkSync(localOutputPath); } catch (_) {}
            }
          }
        }

        // 6. Check if all variants across the entire job are completed
        const finalJobSnap = await variantRef.get();
        const finalJobData = finalJobSnap.data();
        if (finalJobData) {
          const allVariants = Object.values(finalJobData.variants ?? {}) as any[];
          const pendingVariants = allVariants.filter((v) => v.status === "pending");

          // Auto-dispatch secondary low-tier batch if pending variants exist (now that high-tier is ready)
          if (pendingVariants.length > 0) {
            const secondaryEventId = secondaryBatchEventId(videoId, finalJobData.sourceGeneration);
            await MessagingService.publish("resolution.requested", {
              eventId: secondaryEventId,
              jobId: videoId,
              userId: finalJobData.userId,
              timestamp: Date.now(),
              data: {
                videoId,
                sourcePath,
                sourceBucket,
                sourceHeight: initialSourceHeight,
                variants: pendingVariants,
                totalVariants: finalJobData.totalVariants,
              },
            }, {
              source: "resolution-media-service",
              userId: finalJobData.userId,
            });
            console.log(`[Resolution Worker] âš¡ Dispatched secondary resolution batch (${pendingVariants.map((v) => v.label).join(", ")}) for ${videoId}`);
          }

          const allDone = allVariants.length > 0 && allVariants.every(v => v.status === "completed" || v.status === "failed" || v.status === "skipped");
          if (allDone) {
            const hasCompleted = allVariants.some(v => v.status === "completed");

            // Final master playlists (covers any race between the two batches) and storyboards
            let generatedStoryboardUrls: string[] = [];

            if (hasCompleted) {
              await publishAbrMasters(videoId, bucket.name).catch((err) => {
                console.warn(`[Resolution Worker] Final HLS master publish failed (non-fatal):`, err);
              });

              if (!finalJobData.storyboardGenerated && fs.existsSync(localSourcePath) && probed.hasVideo) {
                generatedStoryboardUrls = await generateStoryboardSpriteSheets(localSourcePath, videoId, bucket, tempDir).catch(err => {
                  console.warn(`[Resolution Worker] Storyboard generation failed (non-fatal):`, err);
                  return [];
                });
              }

              // Industry standard: Extract discrete high-definition chapter thumbnails (640x360 qHD)
              // for any chapters or auto-chapters on the video document.
              if (fs.existsSync(localSourcePath) && probed.hasVideo) {
                await generateHighQualityChapterThumbnails(localSourcePath, videoId, bucket, tempDir).catch(err => {
                  console.warn(`[Resolution Worker] High-quality chapter thumbnail extraction failed (non-fatal):`, err);
                  return [];
                });
              }
            }

            const jobUpdate: Record<string, any> = {
              status: hasCompleted ? "completed" : "failed",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (generatedStoryboardUrls.length > 0) {
              jobUpdate.storyboardGenerated = true;
              jobUpdate.storyboardUrl = generatedStoryboardUrls[0];
              jobUpdate.storyboardVariants = generatedStoryboardUrls;
            }
            await variantRef.update(jobUpdate);

            // No quality could be made: tell the creator (friendly text; raw errors stay on the job)
            if (!hasCompleted) {
              await db.collection("videos").doc(videoId).update({
                "media.transcodeFailed": true,
                "media.transcodeError": TRANSCODE_FAILED_MESSAGE,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }).catch(() => null);
            }

            // Sync storyboard sheets to the public video document
            if (generatedStoryboardUrls.length > 0) {
              const videoUpdate: Record<string, any> = {
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                storyboardUrl: generatedStoryboardUrls[0],
                storyboardVariants: generatedStoryboardUrls,
                "media.storyboardUrl": generatedStoryboardUrls[0],
                "media.storyboardVariants": generatedStoryboardUrls,
              };
              await db.collection("videos").doc(videoId).update(videoUpdate).catch(err => {
                console.warn(`[Resolution Worker] Failed to sync storyboards to video doc:`, err);
              });
            }
          }
        }

      } finally {
        // 7. GUARANTEED CLEANUP OF WORKSPACE (Never leave files in /tmp)
        if (fs.existsSync(localSourcePath)) {
          try { fs.unlinkSync(localSourcePath); } catch (_) {}
        }
        if (fs.existsSync(tempDir)) {
          try { fs.rmSync(tempDir, { recursive: true, force: true }); } catch (_) {}
        }
      }

      console.log(`[Resolution Worker] Finished variant processing for: ${videoId}`, { durationMs: Date.now() - t0 });

      // Mark event as completed in idempotency ledger
      await markEventCompleted(parsedEvent.eventId);

    } catch (error) {
      console.error(`[Resolution Worker] Critical failure`, { videoId, error });

      // Unblock idempotency so retries can immediately execute
      if (parsedEvent?.eventId) {
        await markEventFailed(parsedEvent.eventId, error instanceof Error ? error.message : String(error)).catch(() => {});
      }

      if (videoId !== "unknown") {
        await db.collection("resolution_jobs").doc(videoId).update({
          status: "failed",
          error: error instanceof Error ? error.message : String(error),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => { });
      }

      throw error;
    }
  }
);

/**
 * Helper to sync completed resolution variant directly to videos collection in real-time.
 * Uses atomic Firestore transactions to eliminate lost-update race conditions between concurrent workers.
 */
async function syncVariantToVideoDoc(
  videoId: string,
  bucketName: string,
  variantLabel: string,
  variant: ResolutionProfile,
  outputPath: string,
  downloadToken?: string,
  probedDuration?: number
): Promise<void> {
  try {
    const videoRef = db.collection("videos").doc(videoId);
    const directUrl = downloadToken
      ? `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(outputPath)}?alt=media&token=${downloadToken}`
      : `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(outputPath)}?alt=media`;

    await db.runTransaction(async (transaction) => {
      const videoDoc = await transaction.get(videoRef);
      if (!videoDoc.exists) return;

      const data = videoDoc.data() || {};
      const existingAdaptive: Array<{ label: string; url: string; width: number; height: number; bitrate: number }> =
        Array.isArray(data.adaptiveResolutions) ? [...data.adaptiveResolutions] : [];

      // Remove existing entry for this label if present
      const filtered = existingAdaptive.filter(a => a.label !== variantLabel);

      // Append new resolution entry
      filtered.push({
        label: variantLabel,
        url: directUrl,
        width: variant.width,
        height: variant.height,
        bitrate: variant.bitrateKbps * 1000,
      });

      // Sort ladder descending: 2160p -> 1440p -> 1080p -> 720p -> 480p -> 360p -> 240p -> 144p
      // Only include authentic transcoded variants (never inject premature duplicates that prevent secondary mobile tier transcode)
      filtered.sort((a, b) => b.height - a.height);

      const mediaVariants: Record<string, string> = {
        ...(data.media?.variants || {}),
        [variantLabel]: directUrl,
      };

      const updatePayload: Record<string, any> = {
        adaptiveResolutions: filtered,
        "media.adaptiveResolutions": filtered,
        "media.variants": mediaVariants,
        "media.maxQuality": filtered[0]?.label || variantLabel,
        "media.playbackReady": true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (typeof probedDuration === "number" && probedDuration > 0) {
        const probedSec = Math.round(probedDuration);
        const currentSec = Number(data.durationSeconds || 0) || (data.durationMs ? Math.floor(Number(data.durationMs) / 1000) : 0);
        if (currentSec <= 0 || (currentSec <= 5 && probedSec > 10)) {
          updatePayload.durationSeconds = probedSec;
          updatePayload.durationMs = Math.round(probedDuration * 1000);
          const h = Math.floor(probedSec / 3600);
          const m = Math.floor((probedSec % 3600) / 60);
          const s = probedSec % 60;
          updatePayload.duration = h > 0
            ? `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`
            : `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
        }
      }

      transaction.update(videoRef, updatePayload);
    });

    console.log(`[Resolution Service] Atomically synced ${variantLabel} with download token to video doc: ${videoId}`);

    // Note: Do NOT mark pending lower tiers as completed here!
    // Lower tiers (< 720p) must remain 'pending' so handleResolution can dispatch the secondary batch
    // to transcode authentic 480p, 360p, 240p, and 144p variants.
  } catch (err) {
    console.warn(`[Resolution Service] Failed to sync ${variantLabel} to video doc (non-fatal):`, err);
  }
}


/**
 * Generates 1-second interval storyboard sprite sheets across 5x5 grids (25 frames/sheet at 320x180)
 * matching modern industry streaming standards (YouTube / Netflix trick-play)
 * using FFmpeg tile filter and uploads them to Firebase Storage.
 */
async function generateStoryboardSpriteSheets(
  localSourcePath: string,
  videoId: string,
  bucket: any,
  tempDir: string
): Promise<string[]> {
  const storyboardDir = path.join(tempDir, "storyboards");
  if (!fs.existsSync(storyboardDir)) {
    fs.mkdirSync(storyboardDir, { recursive: true });
  }

  const sheetPattern = path.join(storyboardDir, "sheet_%03d.jpg");

  await new Promise<void>((resolve) => {
    getFFmpegInstance()(localSourcePath)
      .outputOptions([
        "-vf", "fps=1,scale=320:180,tile=5x5",
        "-q:v", "2",
      ])
      .output(sheetPattern)
      .on("start", (cmd: string) => console.log(`[FFmpeg Storyboards] ${cmd}`))
      .on("end", () => resolve())
      .on("error", (err: Error) => {
        console.warn(`[Resolution Worker] Storyboard FFmpeg failed (non-fatal):`, err);
        resolve(); // Continue without failing transcode
      })
      .run();
  });

  const files = fs.readdirSync(storyboardDir).filter((f: string) => f.endsWith(".jpg")).sort();
  if (files.length === 0) return [];

  const uploadedUrls: string[] = [];

  for (const file of files) {
    const localFilePath = path.join(storyboardDir, file);
    const destination = `storyboards/${videoId}/${file}`;
    const token = uuidv4();

    await bucket.upload(localFilePath, {
      destination,
      metadata: {
        contentType: "image/jpeg",
        cacheControl: "public, max-age=31536000, immutable",
        metadata: {
          firebaseStorageDownloadTokens: token,
          videoId,
        },
      },
    });

    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destination)}?alt=media&token=${token}`;
    uploadedUrls.push(downloadUrl);
  }

  console.log(`[Resolution Worker] Successfully generated and uploaded ${uploadedUrls.length} storyboard sprite sheets for ${videoId}`);
  return uploadedUrls;
}

/**
 * Extracts broadcast/industry-standard high-quality chapter thumbnails (640x360 qHD / 1280x720 HD)
 * at representative keyframes directly from the local video file.
 *
 * Industry Standard Rules:
 * 1. Sequential extraction: 1 FFmpeg process at a time (guarantees zero OOM / zero CPU starvation).
 * 2. Representative frame offset:
 *    - Chapter 0 (start 0:00): offset 1.5s - 2.5s into the chapter to capture live video/speaker
 *      instead of a black frame or duplicate title card!
 *    - Subsequent chapters: offset 1.0s or 10% into chapter to avoid scene-cut transitions / wipes.
 * 3. Never assign the main video cover as chapter thumbnail.
 * 4. Immutable public caching on Storage with token.
 * 5. Updates both videos root document and media/streaming subcollection in Firestore.
 */
export async function generateHighQualityChapterThumbnails(
  localSourcePath: string,
  videoId: string,
  bucket: any,
  tempDir: string,
  chaptersToProcess?: any[],
  videoDurationMs?: number
): Promise<any[]> {
  try {
    const videoDoc = await db.collection("videos").doc(videoId).get().catch(() => null);
    const videoData = (videoDoc && videoDoc.exists) ? (videoDoc.data() || {}) : {};
    const rawChapters = (chaptersToProcess && Array.isArray(chaptersToProcess) && chaptersToProcess.length > 0)
      ? chaptersToProcess
      : ((Array.isArray(videoData.chapters) && videoData.chapters.length > 0)
          ? videoData.chapters
          : ((Array.isArray(videoData.autoChapters) && videoData.autoChapters.length > 0)
              ? videoData.autoChapters
              : []));

    if (!rawChapters || rawChapters.length === 0) return [];

    const chapterDir = path.join(tempDir, "chapter_thumbs");
    if (!fs.existsSync(chapterDir)) {
      fs.mkdirSync(chapterDir, { recursive: true });
    }

    const mainVideoThumb = videoData.thumbnailUrl || "";
    let hasChanges = false;
    const updatedChapters: any[] = [];

    // Process chapters sequentially to prevent CPU/memory exhaustion and ensure rock-solid FFmpeg execution
    for (let idx = 0; idx < rawChapters.length; idx++) {
      const ch = rawChapters[idx];
      const existingThumb = ch.thumbnailUrl;
      if (
        existingThumb &&
        typeof existingThumb === "string" &&
        existingThumb.trim().length > 0 &&
        existingThumb !== mainVideoThumb &&
        existingThumb.startsWith("http")
      ) {
        updatedChapters.push(ch);
        continue;
      }

      const startTimeMs = Math.max(0, Number(ch.startTimeMs ?? ch.startMs ?? (ch.startTime ? ch.startTime * 1000 : 0)) || 0);
      const endTimeMs = Math.max(
        startTimeMs + 1000,
        Number(ch.endTimeMs ?? ch.endMs ?? (ch.endTime ? ch.endTime * 1000 : 0)) || (startTimeMs + 30000)
      );
      const chapterDurationMs = Math.max(1000, endTimeMs - startTimeMs);

      // Industry Standard: To avoid black frames, title slides, or cross-fade transitions at exact cut boundary:
      // For Chapter 0: offset 1.5s to 2.5s into the chapter to capture authentic speaker/content instead of cover art
      // For Subsequent chapters: offset 1.0s or 10% into the chapter
      let captureMs = startTimeMs;
      if (startTimeMs === 0) {
        captureMs = Math.min(2500, Math.max(1000, Math.round(chapterDurationMs * 0.15)));
      } else {
        captureMs = startTimeMs + Math.min(1500, Math.max(500, Math.round(chapterDurationMs * 0.1)));
      }

      // Clamp within total duration if available
      if (videoDurationMs && videoDurationMs > 2000) {
        captureMs = Math.min(captureMs, videoDurationMs - 500);
      }

      const captureSec = (captureMs / 1000).toFixed(3);
      const outName = `chapter_${idx}_${startTimeMs}.jpg`;
      const localOutPath = path.join(chapterDir, outName);

      const runExtractAtTime = (sec: string) => {
        return new Promise<boolean>((resolve) => {
          getFFmpegInstance()(localSourcePath)
            .seekInput(sec)
            .outputOptions([
              "-frames:v", "1",
              "-vf", "scale=1280:720:force_original_aspect_ratio=decrease:flags=lanczos,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=black",
              "-q:v", "2",
            ])
            .output(localOutPath)
            .on("end", () => resolve(true))
            .on("error", (err: any) => {
              console.warn(`[Resolution Worker] Chapter thumbnail extract failed at ${sec}s:`, err?.message || err);
              resolve(false);
            })
            .run();
        });
      };

      let extracted = await runExtractAtTime(captureSec);
      if (!extracted && captureMs !== startTimeMs) {
        // Fallback to exact start timestamp if offset extraction failed
        const startSec = (startTimeMs / 1000).toFixed(3);
        extracted = await runExtractAtTime(startSec);
      }

      if (!extracted || !fs.existsSync(localOutPath)) {
        updatedChapters.push(ch);
        continue;
      }

      const destination = `thumbnails/${videoId}/chapters/${outName}`;
      const token = uuidv4();
      await bucket.upload(localOutPath, {
        destination,
        metadata: {
          contentType: "image/jpeg",
          cacheControl: "public, max-age=31536000, immutable",
          metadata: {
            firebaseStorageDownloadTokens: token,
            videoId,
            chapterIndex: String(idx),
            startTimeMs: String(startTimeMs),
            captureMs: String(captureMs),
          },
        },
      });

      const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destination)}?alt=media&token=${token}`;
      hasChanges = true;
      updatedChapters.push({
        ...ch,
        startTimeMs,
        endTimeMs,
        thumbnailUrl: downloadUrl,
      });
    }

    if (hasChanges && videoId) {
      const videoRef = db.collection("videos").doc(videoId);
      await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(videoRef);
        if (!snap.exists) return;
        const curData = snap.data() || {};
        const updateObj: Record<string, any> = {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        // Write back ONLY to the source field that was originally present (audit Medium)
        if (Array.isArray(curData.chapters) && curData.chapters.length > 0) {
          updateObj.chapters = updatedChapters;
        } else if (Array.isArray(curData.autoChapters) && curData.autoChapters.length > 0) {
          updateObj.autoChapters = updatedChapters;
        } else {
          updateObj.chapters = updatedChapters;
        }
        transaction.update(videoRef, updateObj);
      }).catch((err) => {
        console.warn(`[Resolution Worker] Failed to update videos/${videoId} with chapter thumbnails:`, err);
      });

      await safeMergeExistingVideoSubdoc(
        videoId,
        "media",
        "streaming",
        {
          chapters: updatedChapters,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        "[ResolutionWorker:chapterThumbnails]"
      ).catch(() => null);

      console.log(`[Resolution Worker] Successfully extracted and attached ${updatedChapters.length} high-quality chapter thumbnails for ${videoId}`);
    }

    return updatedChapters;
  } catch (err) {
    console.warn(`[Resolution Worker] Error generating chapter thumbnails for ${videoId}:`, err);
    return chaptersToProcess || [];
  }
}

/**
 * Extracts and attaches dedicated high-quality chapter thumbnails (640x360 qHD / 1280x720 HD)
 * for a specific video in Firestore by locating its available MP4 renditions or source video.
 * Supports direct sourceUrlOrPath, gs://, https://, and relative paths.
 * Updates Firestore with per-chapter download URLs.
 */
export async function generateHighQualityChapterThumbnailsForVideo(
  videoId: string,
  sourceUrlOrPath?: string,
  existingChapters?: any[],
  videoDurationMs?: number
): Promise<any[]> {
  const tempDir = path.join(os.tmpdir(), `ch_extract_${videoId}_${Date.now()}`);
  try {
    const videoDoc = await db.collection("videos").doc(videoId).get().catch(() => null);
    const videoData = (videoDoc && videoDoc.exists) ? (videoDoc.data() || {}) : {};

    const rawChapters = (existingChapters && Array.isArray(existingChapters) && existingChapters.length > 0)
      ? existingChapters
      : ((Array.isArray(videoData.chapters) && videoData.chapters.length > 0)
          ? videoData.chapters
          : ((Array.isArray(videoData.autoChapters) && videoData.autoChapters.length > 0)
              ? videoData.autoChapters
              : []));

    if (!rawChapters || rawChapters.length === 0) return [];

    const mainVideoThumb = videoData.thumbnailUrl || "";
    const needsThumbs = rawChapters.some((c: any) =>
      !c.thumbnailUrl ||
      typeof c.thumbnailUrl !== "string" ||
      !c.thumbnailUrl.startsWith("http") ||
      c.thumbnailUrl === mainVideoThumb
    );
    if (!needsThumbs) {
      return rawChapters;
    }

    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }

    const bucketName = admin.app().options.storageBucket || "truthworld-1.firebasestorage.app";
    const bucket = admin.storage().bucket(bucketName);

    // H2: Enforce strict source path isolation.
    // Source MUST belong only to videos/${videoId}/ or resolutions/${videoId}/ in the project bucket.
    // Reject any arbitrary external buckets or other video IDs!
    let targetStorageFile: any = null;

    if (sourceUrlOrPath && typeof sourceUrlOrPath === "string" && sourceUrlOrPath.trim().length > 0) {
      const cleanPath = sourceUrlOrPath.trim();
      let extractedPath = "";

      if (cleanPath.startsWith("gs://")) {
        const withoutGs = cleanPath.replace("gs://", "");
        const parts = withoutGs.split("/");
        const targetBucket = parts[0];
        extractedPath = parts.slice(1).join("/");
        if (targetBucket !== bucket.name && targetBucket !== bucketName) {
          console.warn(`[Resolution] Rejected unauthorized bucket in chapter source: ${cleanPath}`);
          return rawChapters;
        }
      } else if (cleanPath.startsWith("https://storage.googleapis.com/")) {
        const afterDomain = cleanPath.replace("https://storage.googleapis.com/", "").split("?")[0];
        const parts = afterDomain.split("/");
        const targetBucket = parts[0];
        extractedPath = parts.slice(1).join("/");
        if (targetBucket !== bucket.name && targetBucket !== bucketName) {
          console.warn(`[Resolution] Rejected unauthorized bucket in chapter URL: ${cleanPath}`);
          return rawChapters;
        }
      } else if (cleanPath.startsWith("https://firebasestorage.googleapis.com/")) {
        const afterO = cleanPath.split("/o/")[1]?.split("?")[0];
        if (afterO) extractedPath = decodeURIComponent(afterO);
      } else {
        extractedPath = cleanPath;
      }

      const normalizedPath = path.posix.normalize(extractedPath.replace(/\\/g, "/"));
      if (
        !normalizedPath.includes("..") &&
        (normalizedPath.startsWith(`videos/${videoId}/`) || normalizedPath.startsWith(`resolutions/${videoId}/`))
      ) {
        targetStorageFile = bucket.file(normalizedPath);
      } else {
        console.warn(`[Resolution] Rejected path outside video boundary for ${videoId}: ${extractedPath}`);
        return rawChapters;
      }
    }

    // Candidate resolution paths (720p/480p preferred for speed, then original)
    if (!targetStorageFile) {
      const candidatePaths = [
        `resolutions/${videoId}/720p.mp4`,
        `resolutions/${videoId}/720p60.mp4`,
        `resolutions/${videoId}/480p.mp4`,
        `resolutions/${videoId}/360p.mp4`,
        `resolutions/${videoId}/1080p.mp4`,
        `resolutions/${videoId}/1080p60.mp4`,
        `videos/${videoId}/original.mp4`,
      ];
      for (const p of candidatePaths) {
        const file = bucket.file(p);
        const [exists] = await file.exists().catch(() => [false]);
        if (exists) {
          targetStorageFile = file;
          break;
        }
      }
    }

    // Fallback: check resolution_jobs sourcePath (verified at upload time)
    if (!targetStorageFile) {
      const jobDoc = await db.collection("resolution_jobs").doc(videoId).get().catch(() => null);
      const jobData = jobDoc?.data();
      if (jobData?.sourcePath && typeof jobData.sourcePath === "string") {
        const normSource = path.posix.normalize(jobData.sourcePath.replace(/\\/g, "/"));
        if (!normSource.includes("..") && normSource.startsWith(`videos/${videoId}/`)) {
          const file = bucket.file(normSource);
          const [exists] = await file.exists().catch(() => [false]);
          if (exists) targetStorageFile = file;
        }
      }
    }

    if (!targetStorageFile) {
      console.warn(`[Resolution] No viable source video found for chapter thumbnails of ${videoId}`);
      return rawChapters;
    }

    // H3: HTTP Range Streaming via Signed URL to avoid downloading multi-gigabyte files into /tmp!
    let sourceInput = "";
    try {
      const [signedUrl] = await targetStorageFile.getSignedUrl({
        action: "read",
        expires: Date.now() + 15 * 60 * 1000,
      });
      if (signedUrl) sourceInput = signedUrl;
    } catch {
      // Fallback
    }

    if (!sourceInput) {
      const [metadata] = await targetStorageFile.getMetadata().catch(() => [{}]);
      const fileSize = Number(metadata?.size || 0);
      if (fileSize > 100 * 1024 * 1024) {
        console.warn(`[Resolution] File size (${fileSize} bytes) exceeds 100MB; aborting local download to prevent OOM`, { videoId });
        return rawChapters;
      }
      sourceInput = path.join(tempDir, "source.mp4");
      await targetStorageFile.download({ destination: sourceInput });
    }

    const updatedChapters = await generateHighQualityChapterThumbnails(
      sourceInput,
      videoId,
      bucket,
      tempDir,
      rawChapters,
      videoDurationMs
    );

    return updatedChapters;
  } catch (err) {
    console.warn(`[Resolution] Error in generateHighQualityChapterThumbnailsForVideo for ${videoId}:`, err);
    return existingChapters || [];
  } finally {
    try {
      if (fs.existsSync(tempDir)) {
        fs.rmSync(tempDir, { recursive: true, force: true });
      }
    } catch {}
  }
}

export const captureChapterThumbnail = onCall(
  {
    region: REGION,
    memory: "1GiB",        // Optimized to 1GiB: cuts cloud RAM billing in half
    timeoutSeconds: 60,    // 60s max execution prevents runaway billing
    minInstances: 0,
    maxInstances: 5,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be signed in to capture frames.");
    }

    const { videoId, timestampMs, width = 1280, height = 720 } = request.data || {};
    if (!videoId || typeof videoId !== "string") {
      throw new HttpsError("invalid-argument", "Missing or invalid videoId.");
    }
    const targetMs = Math.max(0, Number(timestampMs) || 0);

    const videoRef = db.collection("videos").doc(videoId);
    const videoSnap = await videoRef.get();
    if (!videoSnap.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }
    const videoData = videoSnap.data() || {};
    const isAdmin = request.auth?.token?.admin === true && request.auth?.token?.email_verified === true;
    const ownerId = videoData.userId || videoData.ownerId;
    const isOwner = !!(ownerId && ownerId === uid);
    if (!isOwner && !isAdmin) {
      throw new HttpsError("permission-denied", "You do not have permission to edit this video.");
    }

    // 1. Zero-Cost Fast Cache Check: If an existing chapter at this timestamp already has an authentic thumbnail, return it immediately ($0 compute, 0ms latency)
    const existingChapters = Array.isArray(videoData.chapters) ? videoData.chapters : (Array.isArray(videoData.autoChapters) ? videoData.autoChapters : []);
    const cachedChapter = existingChapters.find((c: any) => {
      const cMs = Number(c.startTimeMs ?? c.startMs ?? (c.startTime ? c.startTime * 1000 : 0)) || 0;
      return Math.abs(cMs - targetMs) < 1000 && c.thumbnailUrl && typeof c.thumbnailUrl === "string" && c.thumbnailUrl.startsWith("http");
    });
    if (cachedChapter) {
      return {
        success: true,
        thumbnailUrl: cachedChapter.thumbnailUrl,
        timestampMs: targetMs,
        cached: true,
      };
    }

    const bucket = admin.storage().bucket();
    const tempDir = path.join(os.tmpdir(), `capture_${videoId}_${Date.now()}`);
    fs.mkdirSync(tempDir, { recursive: true });

    try {
      // 2. Cost-Effective Source Selection: Prioritize 720p / 480p variants first
      // A 720p/480p variant is 95% smaller than the multi-gigabyte original, saving bandwidth and IO
      const candidatePaths = [
        `resolutions/${videoId}/720p.mp4`,
        `resolutions/${videoId}/720p60.mp4`,
        `resolutions/${videoId}/480p.mp4`,
        `resolutions/${videoId}/360p.mp4`,
        `resolutions/${videoId}/1080p.mp4`,
        `resolutions/${videoId}/1080p60.mp4`,
        `videos/${videoId}/original.mp4`,
        `videos/${videoId}/source.mp4`,
        `videos/${videoId}/${videoId}.mp4`,
      ];

      let targetStorageFile: any = null;
      for (const p of candidatePaths) {
        const file = bucket.file(p);
        const [exists] = await file.exists().catch(() => [false]);
        if (exists) {
          targetStorageFile = file;
          break;
        }
      }

      if (!targetStorageFile) {
        const [files] = await bucket.getFiles({ prefix: `videos/${videoId}/` });
        const mp4File = files.find(f => f.name.endsWith(".mp4") && !f.name.includes("_240p") && !f.name.includes("_144p"));
        if (mp4File) {
          targetStorageFile = mp4File;
        }
      }

      if (!targetStorageFile) {
        throw new HttpsError("not-found", "Source video file unavailable for frame capture.");
      }

      // 3. HTTP Range Streaming via Signed URL:
      // Uses HTTP Range requests (RFC 7233) so FFmpeg seeks directly to the keyframe
      // without downloading the entire multi-gigabyte video file to disk!
      let localSourcePath = "";
      let isStreamUrl = false;
      try {
        const [signedUrl] = await targetStorageFile.getSignedUrl({
          action: "read",
          expires: Date.now() + 15 * 60 * 1000,
        });
        if (signedUrl) {
          localSourcePath = signedUrl;
          isStreamUrl = true;
        }
      } catch {
        // Fallback to local download if signing fails
      }

      if (!isStreamUrl) {
        localSourcePath = path.join(tempDir, "source.mp4");
        await targetStorageFile.download({ destination: localSourcePath });
      }

      const targetSec = (targetMs / 1000).toFixed(3);
      const outFileName = `captured_${targetMs}_${uuidv4().substring(0, 8)}.jpg`;
      const localOutPath = path.join(tempDir, outFileName);

      const targetW = Math.min(1920, Math.max(160, Number(width) > 0 ? Math.round(Number(width)) : 1280));
      const targetH = Math.min(1080, Math.max(90, Number(height) > 0 ? Math.round(Number(height)) : 720));

      const runExtract = async (inputPath: string) => {
        return new Promise<void>((resolve, reject) => {
          getFFmpegInstance()(inputPath)
            .seekInput(targetSec)
            .outputOptions([
              "-frames:v", "1",
              "-vf", `scale=${targetW}:${targetH}:force_original_aspect_ratio=decrease:flags=lanczos,pad=${targetW}:${targetH}:(ow-iw)/2:(oh-ih)/2:color=black`,
              "-q:v", "2",
            ])
            .output(localOutPath)
            .on("end", () => resolve())
            .on("error", (err: any) => reject(err))
            .run();
        });
      };

      try {
        await runExtract(localSourcePath);
      } catch (streamErr) {
        // Resilient fallback: If HTTP range stream encountered socket drop, download compact file
        if (isStreamUrl) {
          const fallbackPath = path.join(tempDir, "source_fallback.mp4");
          await targetStorageFile.download({ destination: fallbackPath });
          await runExtract(fallbackPath);
        } else {
          throw streamErr;
        }
      }

      if (!fs.existsSync(localOutPath)) {
        throw new HttpsError("internal", "Failed to extract video frame.");
      }

      const destination = `thumbnails/${videoId}/chapters/${outFileName}`;
      const token = uuidv4();
      await bucket.upload(localOutPath, {
        destination,
        metadata: {
          contentType: "image/jpeg",
          cacheControl: "public, max-age=31536000, immutable",
          metadata: {
            firebaseStorageDownloadTokens: token,
            videoId,
            timestampMs: String(targetMs),
            capturedBy: uid,
          },
        },
      });

      const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destination)}?alt=media&token=${token}`;
      return {
        success: true,
        thumbnailUrl: downloadUrl,
        timestampMs: targetMs,
      };
    } finally {
      try {
        fs.rmSync(tempDir, { recursive: true, force: true });
      } catch (_) {}
    }
  }
);

/**
 * 📸 Generate / Backfill High-Quality Chapter Thumbnails for an entire video on-demand.
 * Callable by video owner or admin to generate or repair discrete chapter thumbnails.
 */
export const generateVideoChapterThumbnails = onCall(
  {
    region: REGION,
    memory: "1GiB",
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 5,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be signed in.");
    }
    const { videoId } = request.data || {};
    if (!videoId || typeof videoId !== "string") {
      throw new HttpsError("invalid-argument", "Missing or invalid videoId.");
    }
    const videoRef = db.collection("videos").doc(videoId);
    const videoSnap = await videoRef.get();
    if (!videoSnap.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }
    const videoData = videoSnap.data() || {};
    const isAdmin = request.auth?.token?.admin === true && request.auth?.token?.email_verified === true;
    const ownerId = videoData.userId || videoData.ownerId;
    if (!isAdmin && ownerId !== uid) {
      throw new HttpsError("permission-denied", "You do not have permission to modify this video.");
    }

    const updatedChapters = await generateHighQualityChapterThumbnailsForVideo(videoId);
    return {
      success: true,
      chaptersCount: updatedChapters.length,
      chapters: updatedChapters,
    };
  }
);

/**
 * â° Scheduled Job: Reconciles and repairs any stuck resolution jobs every 10 minutes.
 * Guarantees that any job left in 'processing' longer than 5 minutes is resolved and complete.
 */
export const reconcileStuckResolutionJobsScheduled = onSchedule(
  {
    schedule: "every 10 minutes",
    region: REGION,
    memory: "256MiB",
    timeoutSeconds: 120,
  },
  async () => {
    // 15-minute threshold ensures workers within their 540s (9 min) execution budget are not interrupted (audit C3/H6)
    const fifteenMinutesAgoMs = Date.now() - 15 * 60 * 1000;
    let docsToProcess: admin.firestore.QueryDocumentSnapshot[] = [];

    try {
      const snap = await db
        .collection("resolution_jobs")
        .where("status", "in", ["pending", "processing", "escalated_to_transcoder"])
        .where("updatedAt", "<", new Date(fifteenMinutesAgoMs))
        .orderBy("updatedAt", "asc")
        .limit(50)
        .get();
      docsToProcess = snap.docs;
    } catch {
      // Resilient fallback query: filter and sort in memory
      const fallbackSnap = await db
        .collection("resolution_jobs")
        .where("status", "in", ["pending", "processing", "escalated_to_transcoder"])
        .limit(50)
        .get();
      docsToProcess = fallbackSnap.docs
        .filter((d) => {
          const u = d.data().updatedAt;
          const ms = u?.toMillis ? u.toMillis() : (u || 0);
          return Date.now() - ms > 15 * 60 * 1000;
        })
        .sort((a, b) => {
          const aMs = a.data().updatedAt?.toMillis ? a.data().updatedAt.toMillis() : 0;
          const bMs = b.data().updatedAt?.toMillis ? b.data().updatedAt.toMillis() : 0;
          return aMs - bMs;
        });
    }

    console.log(`[Reconcile Scheduler] Found ${docsToProcess.length} stale resolution jobs`);
    for (const doc of docsToProcess) {
      await reconcileResolutionJob(doc.id).catch((err) => {
        console.warn(`[Reconcile Scheduler] Failed to reconcile ${doc.id}:`, err);
      });
      // Touch updatedAt so that unresolved jobs rotate to back of queue and do not starve others (audit H6)
      await doc.ref.update({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => null);
    }
  }
);

/**
 * ðŸ› ï¸ Manual HTTP Trigger: Immediately reconcile a video's resolution ladder on demand.
 */
export const reconcileVideoResolutionManual = onRequest(
  {
    region: REGION,
    memory: "256MiB",
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 2,
    cors: true,
  },
  async (req, res) => {
    applySecurityHeaders(res);
    const authUser = await requireRecentAdmin(req, res, 3600);
    if (!authUser) return;

    const videoId = (req.query.videoId as string) || (req.body?.videoId as string);
    if (!videoId || typeof videoId !== "string" || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
      res.status(400).json({ error: "Missing or invalid videoId parameter." });
      return;
    }

    try {
      const success = await reconcileResolutionJob(videoId);
      if (!success) {
        res.status(404).json({ error: "Resolution job not found or lacks playable stream" });
        return;
      }
      res.status(200).json({ success: true, message: `Video ${videoId} resolution ladder reconciled.` });
    } catch (e: any) {
      console.error("[Reconcile Manual] Failed to reconcile", e);
      res.status(500).json({ error: "Unable to reconcile video resolution at this time. Please try again." });
    }
  }
);

// ─── Adaptive HLS (both paths) ───────────────────────────────────────────────

type StorageBucket = ReturnType<ReturnType<typeof admin.storage>["bucket"]>;

/** Cache headers: media files never change at their (generation-scoped) path; masters do. */
const HLS_MEDIA_CACHE_CONTROL = "public, max-age=31536000, immutable";
const HLS_MASTER_CACHE_CONTROL = "no-cache, max-age=0";
const HLS_PLAYLIST_CONTENT_TYPE = "application/vnd.apple.mpegurl";

/**
 * One download token per video for every HLS file, so playlists can carry stable
 * absolute URLs (and the master URL doesn't change when it's rewritten).
 */
async function getOrCreateHlsToken(jobRef: admin.firestore.DocumentReference): Promise<string> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(jobRef);
    const existing = snap.exists ? snap.data()?.hlsToken : null;
    if (typeof existing === "string" && existing.length > 0) return existing;
    const token = uuidv4();
    tx.update(jobRef, { hlsToken: token });
    return token;
  });
}

/** ffprobe details needed for the HLS CODECS / RESOLUTION attributes. */
function probeHlsCodecInfo(localPath: string): Promise<{
  width: number;
  height: number;
  profile: string;
  level: number;
  hasAudio: boolean;
}> {
  return new Promise((resolve, reject) => {
    getFFmpegInstance().ffprobe(localPath, (err: any, metadata: any) => {
      if (err || !metadata?.streams) {
        reject(err || new Error("ffprobe returned no streams"));
        return;
      }
      const video = metadata.streams.find((st: any) => st.codec_type === "video");
      const audio = metadata.streams.find((st: any) => st.codec_type === "audio");
      resolve({
        width: Number(video?.width) || 0,
        height: Number(video?.height) || 0,
        profile: String(video?.profile || ""),
        level: Number(video?.level) || 0,
        hasAudio: !!audio,
      });
    });
  });
}

/**
 * Remuxes one finished MP4 quality (stream copy, no re-encode: a second or two of CPU)
 * into a single fragmented-MP4 file with a byte-range media playlist, uploads both
 * under a generation-scoped path, and returns the rendition for the master playlist.
 *
 * The worker encodes with 1-second closed GOPs aligned across qualities, so 4-second
 * segments line up between qualities and players can switch at any segment boundary.
 */
async function packageVariantHls(params: {
  localOutputPath: string;
  tempDir: string;
  bucket: StorageBucket;
  videoId: string;
  label: string;
  fps: number;
  generation: string;
  token: string;
}): Promise<HlsRendition | null> {
  const { localOutputPath, tempDir, bucket, videoId, label, fps, generation, token } = params;
  const workDir = path.join(tempDir, `hls_${label}`);
  fs.mkdirSync(workDir, { recursive: true });
  const localPlaylist = path.join(workDir, "index.m3u8");
  const localMedia = path.join(workDir, "stream.mp4");

  try {
    await new Promise<void>((resolve, reject) => {
      getFFmpegInstance()(localOutputPath)
        .outputOptions(hlsRemuxOutputOptions(localMedia))
        .output(localPlaylist)
        .on("end", () => resolve())
        .on("error", (err: Error) => reject(err))
        .run();
    });

    if (!fs.existsSync(localPlaylist) || !fs.existsSync(localMedia)) return null;

    const codecInfo = await probeHlsCodecInfo(localOutputPath);
    const objectBase = `resolutions/${videoId}/hls/g${generation}/${label}`;
    const mediaObject = `${objectBase}/stream.mp4`;
    const playlistObject = `${objectBase}/index.m3u8`;

    await bucket.upload(localMedia, {
      destination: mediaObject,
      metadata: {
        contentType: "video/mp4",
        cacheControl: HLS_MEDIA_CACHE_CONTROL,
        metadata: { firebaseStorageDownloadTokens: token, videoId, resolution: label },
      },
    });

    const mediaUrl = firebaseDownloadUrl(bucket.name, mediaObject, token);
    const rawPlaylist = fs.readFileSync(localPlaylist, "utf8");
    const { bandwidth, averageBandwidth } = measurePlaylistBandwidth(rawPlaylist);
    const playlist = rewritePlaylistUris(rawPlaylist, (uri) => (uri === "stream.mp4" ? mediaUrl : uri));

    await bucket.file(playlistObject).save(playlist, {
      metadata: {
        contentType: HLS_PLAYLIST_CONTENT_TYPE,
        cacheControl: HLS_MEDIA_CACHE_CONTROL,
        metadata: { firebaseStorageDownloadTokens: token, videoId, resolution: label },
      },
    });

    if (bandwidth <= 0) return null;
    return {
      label,
      width: codecInfo.width,
      height: codecInfo.height,
      fps,
      bandwidth,
      averageBandwidth,
      codecs: codecsFor({ videoProfile: codecInfo.profile, videoLevel: codecInfo.level, hasAudio: codecInfo.hasAudio }),
      playlistUrl: firebaseDownloadUrl(bucket.name, playlistObject, token),
    };
  } finally {
    try { fs.rmSync(workDir, { recursive: true, force: true }); } catch (_) {}
  }
}

/**
 * (Re)writes the FFmpeg path's master playlists from every finished quality:
 *  - abr_master.m3u8: all qualities (premium viewers)
 *  - abr_master_hd.m3u8: qualities up to 1080p (everyone else; mirrors the app's cap)
 * Called after each quality finishes, so a new upload is streamable at 360p first and
 * new viewers get higher qualities as soon as they exist. URLs are stable (same path
 * and token), and masters are served with no-cache so players always see the latest.
 */
async function publishAbrMasters(videoId: string, bucketName: string): Promise<void> {
  const jobRef = db.collection("resolution_jobs").doc(videoId);
  const snap = await jobRef.get();
  const job = snap.data();
  if (!job) return;

  const renditions: HlsRendition[] = Object.values(job.variants ?? {})
    .filter((v: any) => v?.status === "completed" && v?.hls?.playlistUrl)
    .map((v: any) => v.hls as HlsRendition);
  if (renditions.length === 0) return;

  const token: string = job.hlsToken || (await getOrCreateHlsToken(jobRef));
  const bucket = admin.storage().bucket(bucketName);
  const allText = buildMasterPlaylist(renditions);
  const hdText = buildMasterPlaylist(renditions, { maxShortSide: FREE_MAX_SHORT_SIDE }) || allText;
  if (!allText) return;

  const masterObject = `resolutions/${videoId}/hls/abr_master.m3u8`;
  const hdObject = `resolutions/${videoId}/hls/abr_master_hd.m3u8`;
  for (const [object, text] of [[masterObject, allText], [hdObject, hdText]] as const) {
    await bucket.file(object).save(text, {
      metadata: {
        contentType: HLS_PLAYLIST_CONTENT_TYPE,
        cacheControl: HLS_MASTER_CACHE_CONTROL,
        metadata: { firebaseStorageDownloadTokens: token, videoId },
      },
    });
  }

  const masterUrl = firebaseDownloadUrl(bucket.name, masterObject, token);
  const hdUrl = firebaseDownloadUrl(bucket.name, hdObject, token);
  await jobRef.update({
    abrHls: {
      masterUrl,
      hdMasterUrl: hdUrl,
      renditions: renditions.length,
      maxShortSide: Math.max(...renditions.map((r) => Math.min(r.width || r.height, r.height || r.width))),
      updatedAt: Date.now(),
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection("videos").doc(videoId).update({
    "media.abrHlsUrl": masterUrl,
    "media.abrHlsHdUrl": hdUrl,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch(() => null);
}

/**
 * Makes the Transcoder's HLS output playable from Firebase Storage: gives every
 * file under resolutions/{videoId}/hls/ the video's download token and rewrites
 * every playlist URI to an absolute tokenized URL (relative URIs don't resolve
 * against Firebase download URLs). Also writes master_hd.m3u8 (up to 1080p).
 * Safe to run twice: absolute URIs are left alone.
 */
async function makeTranscoderHlsPlayable(
  videoId: string,
  bucket: StorageBucket,
  token: string
): Promise<{ masterUrl: string; hdMasterUrl: string; renditions: number; maxShortSide: number } | null> {
  const prefix = `resolutions/${videoId}/hls/`;
  const masterObject = `${prefix}master.m3u8`;
  const hdObject = `${prefix}master_hd.m3u8`;
  const [files] = await bucket.getFiles({ prefix });
  // Skip the FFmpeg path's own files (g<generation>/..., abr_master*.m3u8) and our master_hd.
  const transcoderFiles = files.filter((f) => {
    const rel = f.name.slice(prefix.length);
    return !/^g\d/.test(rel) && !rel.startsWith("abr_master") && f.name !== hdObject;
  });
  if (!transcoderFiles.some((f) => f.name === masterObject)) return null;

  // 1. Token on every media file (bounded concurrency)
  const media = transcoderFiles.filter((f) => !f.name.endsWith(".m3u8"));
  const CONCURRENCY = 16;
  for (let i = 0; i < media.length; i += CONCURRENCY) {
    await Promise.all(media.slice(i, i + CONCURRENCY).map((f) =>
      f.setMetadata({
        cacheControl: HLS_MEDIA_CACHE_CONTROL,
        metadata: { firebaseStorageDownloadTokens: token },
      })
    ));
  }

  // 2. Rewrite every playlist to absolute URLs
  const toAbsolute = (playlistObject: string) => (uri: string) => {
    const objectPath = resolveRelativeObjectPath(playlistObject, uri, prefix);
    return objectPath ? firebaseDownloadUrl(bucket.name, objectPath, token) : uri;
  };
  let masterText = "";
  for (const f of transcoderFiles.filter((file) => file.name.endsWith(".m3u8"))) {
    const [buf] = await f.download();
    const rewritten = rewritePlaylistUris(buf.toString("utf8"), toAbsolute(f.name));
    const isMaster = f.name === masterObject;
    if (isMaster) masterText = rewritten;
    await f.save(rewritten, {
      metadata: {
        contentType: HLS_PLAYLIST_CONTENT_TYPE,
        cacheControl: isMaster ? HLS_MASTER_CACHE_CONTROL : HLS_MEDIA_CACHE_CONTROL,
        metadata: { firebaseStorageDownloadTokens: token, videoId },
      },
    });
  }
  if (!masterText) return null;

  // 3. Free-tier master (up to 1080p)
  const hdText = filterMasterByShortSide(masterText, FREE_MAX_SHORT_SIDE) || masterText;
  await bucket.file(hdObject).save(hdText, {
    metadata: {
      contentType: HLS_PLAYLIST_CONTENT_TYPE,
      cacheControl: HLS_MASTER_CACHE_CONTROL,
      metadata: { firebaseStorageDownloadTokens: token, videoId },
    },
  });

  const sizes = [...masterText.matchAll(/RESOLUTION=(\d+)x(\d+)/g)].map((m) => Math.min(Number(m[1]), Number(m[2])));
  return {
    masterUrl: firebaseDownloadUrl(bucket.name, masterObject, token),
    hdMasterUrl: firebaseDownloadUrl(bucket.name, hdObject, token),
    renditions: sizes.length,
    maxShortSide: sizes.length > 0 ? Math.max(...sizes) : 0,
  };
}

/**
 * Marks a Transcoder job failed on resolution_jobs and flags the video so the
 * creator can be told (media.transcodeFailed / media.transcodeError).
 */
async function markTranscoderJobFailed(videoId: string, error: string, state: string): Promise<void> {
  await db.collection("resolution_jobs").doc(videoId).update({
    status: "failed",
    error,
    transcoderJobState: state,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection("videos").doc(videoId).update({
    "media.transcodeFailed": true,
    // Friendly text for creators; the raw error stays on resolution_jobs.error.
    "media.transcodeError": TRANSCODE_FAILED_MESSAGE,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch(() => null);
}

/**
 * Publishes a SUCCEEDED Transcoder job: HLS master URL, storyboard sprites,
 * playback flags, then (optionally) chapter thumbnails.
 *
 * Shared by the Pub/Sub completion handler and the reconciler, which finalizes
 * jobs whose completion message was lost (re-audit R7). Idempotent: a job that is
 * already completed with an hlsUrl is left alone, so download tokens (and the
 * URLs viewers hold) are not rotated by a duplicate message.
 *
 * Returns false when the master playlist is missing (job marked failed).
 */
async function finalizeTranscoderJob(videoId: string, options: { extractChapters: boolean }): Promise<boolean> {
  const jobRef = db.collection("resolution_jobs").doc(videoId);
  const videoRef = db.collection("videos").doc(videoId);

  const jobSnap = await jobRef.get();
  const existing = jobSnap.exists ? (jobSnap.data() || {}) : {};
  if (existing.status === "completed" && existing.hlsUrl) {
    console.log(`[Transcoder Completion] ${videoId} already finalized; skipping duplicate.`);
    return true;
  }

  const bucketName = existing.sourceBucket || admin.app().options.storageBucket || "truthworld-1.firebasestorage.app";
  const bucket = admin.storage().bucket(bucketName);

  // 1. Locate HLS master manifest in Storage
  const masterPath = `resolutions/${videoId}/hls/master.m3u8`;
  const masterFile = bucket.file(masterPath);
  const [masterExists] = await masterFile.exists().catch(() => [false]);
  if (!masterExists) {
    // Previously the job was marked completed and playbackReady with an empty URL.
    await markTranscoderJobFailed(videoId, "Transcoder finished but no master playlist was written", "SUCCEEDED_NO_OUTPUT");
    return false;
  }

  // Rewrite the Transcoder's playlists to absolute tokenized URLs (relative URIs don't
  // resolve against Firebase download URLs), and write the free-tier master.
  const hlsToken = await getOrCreateHlsToken(jobRef);
  const playable = await makeTranscoderHlsPlayable(videoId, bucket, hlsToken);
  if (!playable) {
    await markTranscoderJobFailed(videoId, "Transcoder output could not be prepared for streaming", "SUCCEEDED_UNPLAYABLE");
    return false;
  }
  const masterUrl = playable.masterUrl;

  // 2. Locate native storyboard sprite sheets generated by GCP Transcoder
  const [storyboardFiles] = await bucket.getFiles({ prefix: `resolutions/${videoId}/hls/storyboard` }).catch(() => [[]]);
  const spriteUrls: string[] = [];
  for (const file of storyboardFiles.filter((f: any) => f.name.endsWith(".jpeg") || f.name.endsWith(".jpg"))) {
    const token = uuidv4();
    await file.setMetadata({
      metadata: { firebaseStorageDownloadTokens: token },
      contentType: "image/jpeg",
      cacheControl: "public, max-age=31536000, immutable",
    });
    spriteUrls.push(`https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(file.name)}?alt=media&token=${token}`);
  }

  // 3. Update Firestore so playback is ready (audit H1 / C2)
  const jobUpdate: Record<string, any> = {
    status: "completed",
    hlsUrl: masterUrl,
    abrHls: {
      masterUrl: playable.masterUrl,
      hdMasterUrl: playable.hdMasterUrl,
      renditions: playable.renditions,
      maxShortSide: playable.maxShortSide,
      updatedAt: Date.now(),
    },
    transcoderJobState: "SUCCEEDED",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (spriteUrls.length > 0) {
    jobUpdate.storyboardGenerated = true;
    jobUpdate.storyboardUrl = spriteUrls[0];
    jobUpdate.storyboardVariants = spriteUrls;
  }
  await jobRef.update(jobUpdate);

  const videoUpdate: Record<string, any> = {
    hlsUrl: masterUrl,
    "media.hlsUrl": masterUrl,
    "media.isHls": true,
    "media.abrHlsUrl": playable.masterUrl,
    "media.abrHlsHdUrl": playable.hdMasterUrl,
    "media.playbackReady": true,
    "media.transcodeFailed": admin.firestore.FieldValue.delete(),
    "media.transcodeError": admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (spriteUrls.length > 0) {
    videoUpdate.storyboardUrl = spriteUrls[0];
    videoUpdate.storyboardVariants = spriteUrls;
    videoUpdate["media.storyboardUrl"] = spriteUrls[0];
    videoUpdate["media.storyboardVariants"] = spriteUrls;
  }
  await videoRef.update(videoUpdate).catch((err) => {
    console.warn(`[Transcoder Completion] Video doc update failed for ${videoId}:`, err);
  });

  console.log(`[Transcoder Completion] Successfully finalized GCP Transcoder assets for ${videoId}`);

  // 4. Chapter thumbnails, awaited (re-audit R4): work left running after a
  //    Cloud Function returns may be throttled or stopped, so it never finished.
  if (options.extractChapters) {
    const videoSnap = await videoRef.get();
    const videoData = videoSnap.exists ? videoSnap.data() || {} : {};
    const rawChapters = videoData.chapters || videoData.autoChapters;
    if (Array.isArray(rawChapters) && rawChapters.length > 0) {
      await generateHighQualityChapterThumbnailsForVideo(videoId).catch((err) => {
        console.warn(`[Transcoder Completion] Chapter thumbnail extraction non-fatal warning:`, err);
      });
    }
  }
  return true;
}

/**
 * ☁️ Triggered when GCP Video Transcoder API completes a job.
 * Dispatches via Pub/Sub topic 'transcoder.completed'.
 * - Extracts master HLS manifest
 * - Captures native GCP sprite sheets (storyboard) with zero FFmpeg /tmp OOM risk
 * - Bespoke chapter thumbnail extraction via signed URL range requests
 * - Fast, lightweight metadata update in Firestore (< 5 seconds execution)
 */
export const onTranscoderJobCompleted = onMessagePublished(
  {
    topic: "transcoder.completed",
    region: REGION,
    // Chapter thumbnails are now awaited (re-audit R4): ffmpeg seeks the source
    // through a signed URL, so allow more time and memory than the old 120 s / 512 MiB.
    memory: "1GiB",
    timeoutSeconds: 300,
    minInstances: 0,
    maxInstances: 5,
    retry: false,
  },
  async (event) => {
    try {
      const messageData = event.data.message.data
        ? Buffer.from(event.data.message.data, "base64").toString("utf8")
        : "{}";
      const payload = JSON.parse(messageData);
      const job = payload.job || payload;
      const jobName = job.name || "";
      const jobState = job.state; // "SUCCEEDED" | "FAILED"
      const labels = job.labels || {};
      let videoId = labels.videoid;

      // Audit C2 Fix: GCP Transcoder Pub/Sub notification payload only includes name, state, error - no labels.
      // Lookup videoId by querying resolution_jobs where transcoderJobName == jobName or fetch full job status
      if (!videoId && jobName) {
        const querySnap = await db.collection("resolution_jobs")
          .where("transcoderJobName", "==", jobName)
          .limit(1)
          .get()
          .catch(() => null);
        if (querySnap && !querySnap.empty) {
          videoId = querySnap.docs[0].id;
        } else {
          try {
            const fullJob = await TranscoderGateway.getJobStatus(jobName);
            videoId = fullJob?.labels?.videoid;
          } catch (statusErr) {
            console.warn(`[Transcoder Completion] Failed to query full job status for ${jobName}:`, statusErr);
          }
        }
      }

      if (!videoId) {
        console.warn(`[Transcoder Completion] Received message without resolvable videoId for job: ${jobName}`, payload);
        return;
      }

      console.log(`[Transcoder Completion] Job ${jobName} for video ${videoId} finished with state: ${jobState}`);

      if (jobState !== "SUCCEEDED") {
        await markTranscoderJobFailed(videoId, job.error?.message || "GCP Video Transcoder job failed", jobState || "FAILED");
        return;
      }

      await finalizeTranscoderJob(videoId, { extractChapters: true });
    } catch (err) {
      console.error(`[Transcoder Completion] Failed to process transcoder event:`, err);
    }
  }
);

export { TranscoderGateway } from "./transcoderGateway";

