/**
 * 🎥 RESOLUTION — Video Resolution Processing (≤ 1040p)
 *
 * Firebase Cloud Function triggered by video uploads.
 * Processes uploaded videos into adaptive bitrate ladder capped at 1040p.
 *
 * ✅ FEATURES:
 *   - Storage trigger: onObjectFinalized for videos/ prefix
 *   - Resolution cap: Maximum 1040p. Ladder: [1040, 720, 480, 360, 240, 144]
 *   - Stores processed metadata in Firestore
 *   - Stores processed files in Firebase Storage
 *   - minInstances: 0 (scale-to-zero)
 *
 * ✅ COST OPTIMIZATION:
 *   - Only transcode if source resolution > target
 *   - Skip redundant resolutions (e.g., don't upscale 480p to 720p/1040p)
 *   - Bitrate ladder dynamically set per resolution
 */

import * as admin from "firebase-admin";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onRequest } from "firebase-functions/v2/https";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { v4 as uuidv4 } from "uuid";
import { MessagingService } from "../shared/messaging";
import { checkAndMarkEventId, markEventCompleted } from "../shared/idempotency";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";

let _ffmpegInitialized = false;
let _ffmpegInstance: any = null;

function getFFmpegInstance(): any {
  if (!_ffmpegInitialized) {
    const ffmpeg = require("fluent-ffmpeg");
    const ffmpegInstaller = require("ffmpeg-static");
    if (ffmpegInstaller) {
      ffmpeg.setFfmpegPath(ffmpegInstaller);
    }
    _ffmpegInstance = ffmpeg;
    _ffmpegInitialized = true;
  }
  return _ffmpegInstance;
}

const db = admin.firestore();
const REGION = "asia-south1";

// ─── Resolution Configuration ────────────────────────────────────────────────

/** Maximum resolution cap — 1080p standard, 2160p custom */
const MAX_STANDARD_RESOLUTION_HEIGHT = 1080;
const MAX_CUSTOM_RESOLUTION_HEIGHT = 2160;

/** Full resolution ladder (descending). Only resolutions ≤ source are generated. */
export interface ResolutionProfile {
  height: number;
  width: number;
  label: string;
  bitrateKbps: number;
  audioBitrateKbps: number;
  fps: number;
}

export const STANDARD_RESOLUTION_LADDER: ResolutionProfile[] = [
  { height: 1080, width: 1920, label: "1080p", bitrateKbps: 4500, audioBitrateKbps: 128, fps: 30 },
  { height: 720, width: 1280, label: "720p", bitrateKbps: 2500, audioBitrateKbps: 128, fps: 30 },
  { height: 480, width: 854, label: "480p", bitrateKbps: 1200, audioBitrateKbps: 96, fps: 30 },
  { height: 360, width: 640, label: "360p", bitrateKbps: 800, audioBitrateKbps: 64, fps: 30 },
  { height: 240, width: 426, label: "240p", bitrateKbps: 400, audioBitrateKbps: 48, fps: 24 },
  { height: 144, width: 256, label: "144p", bitrateKbps: 200, audioBitrateKbps: 32, fps: 15 },
];

export const CUSTOM_RESOLUTION_LADDER: ResolutionProfile[] = [
  { height: 2160, width: 3840, label: "2160p", bitrateKbps: 15000, audioBitrateKbps: 192, fps: 30 },
  { height: 1440, width: 2560, label: "1440p", bitrateKbps: 10000, audioBitrateKbps: 160, fps: 30 },
  ...STANDARD_RESOLUTION_LADDER,
];

const VALID_VIDEO_EXTENSIONS = new Set([
  ".mp4", ".avi", ".mov", ".mkv", ".webm", ".flv", ".wmv", 
  ".3gpp", ".3gp", ".mpeg", ".mpg", ".mpegps", ".m4v", 
  ".dnxhr", ".prores", ".cineform", ".hevc"
]);

/** Helper to probe media dimensions and codec with ffprobe */
function probeVideoFile(filePath: string): Promise<{ width: number; height: number; codec: string }> {
  return new Promise((resolve) => {
    try {
      getFFmpegInstance().ffprobe(filePath, (err: any, metadata: any) => {
        if (err || !metadata || !metadata.streams) {
          resolve({ width: 0, height: 0, codec: "unknown" });
          return;
        }
        const videoStream = metadata.streams.find((s: any) => s.codec_type === "video");
        if (videoStream) {
          resolve({
            width: Number(videoStream.width) || 0,
            height: Number(videoStream.height) || 0,
            codec: String(videoStream.codec_name || "unknown"),
          });
        } else {
          resolve({ width: 0, height: 0, codec: "unknown" });
        }
      });
    } catch {
      resolve({ width: 0, height: 0, codec: "unknown" });
    }
  });
}

// ─── Storage Trigger ─────────────────────────────────────────────────────────

/**
 * Triggered when a video is uploaded to Firebase Storage under the `videos/` prefix.
 *
 * ✅ COST OPTIMIZED:
 *   - memory: 128MiB (only reads metadata, $0.0000002 per invocation)
 *   - minInstances: 0 (zero idle cost)
 *   - maxInstances: 2 (governed concurrency)
 *   - timeoutSeconds: 60s
 */
export const onVideoUploadedForResolution = onObjectFinalized(
  {
    bucket: "truthworld-1.firebasestorage.app",
    region: REGION,
    memory: "128MiB",       // Ultra low memory for GCS metadata reader
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 2,
  },
  async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType ?? "";
    const bucket = event.data.bucket;

    // Only process files under videos/ prefix
    if (!filePath.startsWith("videos/")) {
      return;
    }

    // Validate content type
    const fileName = filePath.split("/").pop() ?? "";
    const ext = fileName.toLowerCase().slice(fileName.lastIndexOf("."));
    if (!VALID_VIDEO_EXTENSIONS.has(ext) && !contentType.startsWith("video/")) {
      console.log(`[Resolution] Skipping non-video file: ${fileName}`);
      return;
    }

    // Extract videoId from path: videos/{videoId}/original.mp4
    const pathParts = filePath.split("/");
    if (pathParts.length < 3) {
      console.error(`[Resolution] Unexpected path structure: ${filePath}`);
      return;
    }

    const videoId = pathParts[1]; // videos/[videoId]/...

    // ✅ INDUSTRY STANDARD: Autonomous Service Sovereignty
    // We get the userId from Storage Metadata instead of querying the main database.
    // This allows the media service to work even if the main API is lagging or down.
    const storageMetadata = event.data.metadata ?? {};
    const userId = storageMetadata.userId || storageMetadata.ownerId || "system_automated";

    console.log(`[Resolution Service] Autonomous processing: ${filePath}`, { videoId, userId });

    let channelType = "standard";

    // ─── MODERATION GATE: Skip resolution for rejected videos ────────────
    try {
      const videoDoc = await db.collection("videos").doc(videoId).get();
      if (videoDoc.exists) {
        const videoData = videoDoc.data();
        const moderationStatus = videoData?.moderation?.status;
        if (moderationStatus === "rejected") {
          console.log(`[Resolution Service] Video REJECTED by moderation — skipping resolution`, { videoId });
          return;
        }
        if (videoData?.channelType === "custom" || videoData?.type === "custom") {
          channelType = "custom";
        }
      }
    } catch (modCheckErr) {
      // Non-fatal: if we can't check moderation, proceed anyway
      console.warn(`[Resolution Service] Moderation check failed (non-fatal), proceeding`, { videoId, err: modCheckErr });
    }

    try {
      // Read source metadata from GCS
      const [metadata] = await admin.storage().bucket(bucket).file(filePath).getMetadata();
      const sourceHeight = parseInt(String(metadata.metadata?.height ?? "0"), 10);
      const sourceWidth = parseInt(String(metadata.metadata?.width ?? "0"), 10);
      const fileSize = parseInt(String(metadata.size ?? "0"), 10);
      const codec = String(metadata.metadata?.codec ?? "unknown");

      // Select ladder based on channelType (Standard up to 1080p, Custom up to 4K / 2160p)
      const baseLadder = channelType === "custom" ? CUSTOM_RESOLUTION_LADDER : STANDARD_RESOLUTION_LADDER;
      const maxLadderHeight = channelType === "custom" ? MAX_CUSTOM_RESOLUTION_HEIGHT : MAX_STANDARD_RESOLUTION_HEIGHT;

      // Determine effective source resolution
      const effectiveHeight = sourceHeight > 0 ? Math.min(sourceHeight, maxLadderHeight) : maxLadderHeight;

      // Build applicable resolution ladder (only resolutions ≤ source height)
      const applicableResolutions = baseLadder.filter(
        (r) => r.height <= effectiveHeight
      );

      if (applicableResolutions.length === 0) {
        console.warn(`[Resolution] No applicable resolutions for height=${sourceHeight}`);
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
        channelType,
        maxResolution: effectiveHeight,
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
        maxRes: `${effectiveHeight}p`,
      });


      // ─── Autonomous Event Publishing (Per-Variant Concurrency) ───────────────────
      // Instead of 1 monolithic job trying to transcode all 6 resolutions in a single function,
      // dispatch individual Pub/Sub events for each variant so each variant executes in its
      // own isolated Cloud Function instance with dedicated memory (2GiB) and fresh 540s timeout.
      for (const variant of applicableResolutions) {
        const variantEventId = `${videoId}_${variant.label}_${uuidv4().slice(0, 8)}`;
        await MessagingService.publish("resolution.requested", {
          eventId: variantEventId,
          jobId: videoId,
          userId,
          timestamp: Date.now(),
          data: {
            videoId,
            sourcePath: filePath,
            sourceBucket: bucket,
            sourceHeight,
            variant, // Isolated variant for dedicated function instance
            totalVariants: applicableResolutions.length,
          },
        }, {
          source: "resolution-media-service",
          userId,
        });
      }

      console.log(`[Resolution Service] Published ${applicableResolutions.length} parallel resolution.requested events`, { videoId });
    } catch (error) {
      console.error(`[Resolution] Failed to process upload`, {
        filePath,
        error: error instanceof Error ? error.message : String(error),
      });

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

// ─── HTTP Endpoint — Status ──────────────────────────────────────────────────

/**
 * Get resolution processing status and available quality variants.
 *
 * ✅ CONFIG: minInstances=0, maxInstances=5, 256MiB, 30s timeout
 */
export const getVideoResolutionStatus = onRequest(
  {
    region: REGION,
    memory: "256MiB",
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 2,
    cors: true,
  },
  async (req, res) => {
    try {
      const videoId = req.query.videoId as string;

      if (!videoId || typeof videoId !== "string") {
        res.status(400).json({ error: "videoId query parameter is required" });
        return;
      }

      const doc = await db.collection("resolution_jobs").doc(videoId).get();

      if (!doc.exists) {
        res.status(404).json({ error: "Resolution job not found" });
        return;
      }

      const data = doc.data()!;

      // Build response with variant status
      const variants = data.variants ?? {};
      const availableQualities: string[] = [];

      for (const [label, variant] of Object.entries(variants) as [string, any][]) {
        if (variant.status === "completed") {
          availableQualities.push(label);
        }
      }

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

// ─── HTTP Endpoint — Available Profiles ──────────────────────────────────────

/**
 * Returns the resolution ladder configuration.
 * Useful for client-side adaptive bitrate player configuration.
 *
 * ✅ CONFIG: minInstances=0, maxInstances=5, 256MiB, 10s timeout
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

// ─── Pub/Sub Worker — Process Resolution ─────────────────────────────────────

/**
 * Worker triggered by 'resolution.requested' Pub/Sub topic via push subscription.
 *
 * 💰 INDUSTRY-STANDARD TRANSCODING ENGINE (YouTube-grade):
 *   1. 2GiB RAM allocation to prevent OOM on large video downloads & FFmpeg transcode
 *   2. Native resolution passthrough (-c copy) when source matches target
 *   3. Universal browser compatibility via -pix_fmt yuv420p, -c:v libx264, -c:a aac
 *   4. Direct Firebase Storage download token generation for 100% reliable HTML5 playback
 *   5. Immediate /tmp disk cleanup to ensure 0 disk leakage
 *   6. Real-time UI exposure on each variant completion
 *
 * ✅ CONFIG: minInstances=0 (scale-to-zero), maxInstances=5, 2GiB memory, 540s timeout
 */
export const handleResolution = onMessagePublished(
  {
    topic: "resolution.requested",
    region: REGION,
    memory: "2GiB",         // 2GiB RAM guarantees zero OOM on 1080p/4K transcode
    timeoutSeconds: 540,
    minInstances: 0,        // Scale-to-zero (0 idle cost)
    maxInstances: 2,        // Max 2 concurrent workers to respect CPU quota
  },
  async (event) => {
    const t0 = Date.now();
    let videoId = "unknown";

    try {
      // 1. Parse Pub/Sub message autonomously
      const parsedEvent = MessagingService.parseMessage<{
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

      // 2. IDEMPOTENCY — Check if event was already handled
      const status = await checkAndMarkEventId(parsedEvent.eventId, videoId);
      if (status === "COMPLETED" || status === "PROCESSING") {
        console.log(`[Resolution Worker] Duplicate event detected, skipping: ${parsedEvent.eventId}`, { videoId });
        return;
      }

      console.log(`[Resolution Worker] Starting job: ${videoId}`, {
        variantLabels: variantsToProcess.map(v => v.label).join(", "),
        eventId: parsedEvent.eventId,
      });

      // 3. Update overall status to processing (atomic)
      await db.collection("resolution_jobs").doc(videoId).update({
        status: "processing",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 4. PREPARE LOCAL WORKSPACE (Unique subfolder per event to prevent collisions)
      const instanceId = uuidv4().slice(0, 8);
      const tempDir = path.join(os.tmpdir(), `res_${videoId}_${instanceId}`);
      if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

      const localSourcePath = path.join(tempDir, "original.mp4");
      const bucket = admin.storage().bucket(sourceBucket);

      try {
        console.log(`[Resolution Worker] Downloading source: ${sourcePath}`, { videoId });
        await bucket.file(sourcePath).download({ destination: localSourcePath });

        // Probe downloaded file directly with ffprobe for accurate dimensions
        const probed = await probeVideoFile(localSourcePath);
        const actualSourceHeight = probed.height > 0 ? probed.height : initialSourceHeight;
        const actualSourceWidth = probed.width > 0 ? probed.width : 0;
        console.log(`[Resolution Worker] Source probed: ${actualSourceWidth}x${actualSourceHeight}, codec=${probed.codec}`, { videoId });

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

          // 🚫 STRICT NO-UPSCALING GATE:
          // Never generate resolutions higher than the source video uploaded by the creator.
          // E.g. If creator uploads 720p, only generate 720p, 480p, 360p, 240p, 144p (never 1080p, 1440p, 2160p).
          if (actualSourceHeight > 0 && targetVariant.height > actualSourceHeight + 16) {
            console.log(`[Resolution Worker] 🚫 Skipping upscaling: variant ${variantLabel} (${targetVariant.height}p) > source (${actualSourceHeight}p)`, { videoId });
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

          // 💰 COST OPTIMIZATION: Passthrough Copy for Native Resolution
          // If the source video matches this resolution height and is already MP4 H.264/AAC, fast-copy!
          const isNativeMatch = actualSourceHeight > 0 &&
            Math.abs(actualSourceHeight - targetVariant.height) <= 16 &&
            probed.codec.includes("h264") &&
            sourcePath.endsWith(".mp4");

          try {
            if (isNativeMatch) {
              console.log(`[Resolution Worker] ⚡ Native passthrough copy for ${variantLabel} (0 CPU re-encoding cost)`, { videoId });
              await new Promise<void>((resolve, reject) => {
                getFFmpegInstance()(localSourcePath)
                  .outputOptions([
                    "-c copy",
                    "-movflags +faststart",
                  ])
                  .output(localOutputPath)
                  .on("end", () => resolve())
                  .on("error", (err: Error) => reject(err))
                  .run();
              });
            } else {
              // Execute FFmpeg Transcode with standard web profile (H.264 Main + AAC + YUV420p)
              await new Promise<void>((resolve, reject) => {
                getFFmpegInstance()(localSourcePath)
                  .outputOptions([
                    "-c:v libx264",
                    "-pix_fmt yuv420p",
                    "-crf 23",
                    `-maxrate ${targetVariant.bitrateKbps}k`,
                    `-bufsize ${targetVariant.bitrateKbps * 2}k`,
                    "-preset veryfast",
                    `-vf scale=-2:${targetVariant.height}`,
                    "-c:a aac",
                    `-b:a ${targetVariant.audioBitrateKbps}k`,
                    "-ar 44100",
                    "-ac 2",
                    `-r ${targetVariant.fps}`,
                    "-threads 2",
                    "-movflags +faststart",
                  ])
                  .output(localOutputPath)
                  .on("start", (cmd: string) => console.log(`[FFmpeg] ${variantLabel}: ${cmd}`))
                  .on("end", () => resolve())
                  .on("error", (err: Error) => reject(err))
                  .run();
              });
            }

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
            await syncVariantToVideoDoc(videoId, bucket.name, variantLabel, targetVariant, targetPath, downloadToken);

          } catch (variantErr) {
            console.error(`[Resolution Worker] Variant failed: ${variantLabel}`, {
              videoId,
              err: variantErr instanceof Error ? variantErr.message : String(variantErr),
            });

            await variantRef.update({
              [`variants.${variantLabel}.status`]: "failed",
              [`variants.${variantLabel}.error`]: variantErr instanceof Error ? variantErr.message : String(variantErr),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
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
          const allDone = allVariants.length > 0 && allVariants.every(v => v.status === "completed" || v.status === "failed" || v.status === "skipped");
          if (allDone) {
            const hasCompleted = allVariants.some(v => v.status === "completed");
            await variantRef.update({
              status: hasCompleted ? "completed" : "failed",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
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
 */
async function syncVariantToVideoDoc(
  videoId: string,
  bucketName: string,
  variantLabel: string,
  variant: ResolutionProfile,
  outputPath: string,
  downloadToken?: string
): Promise<void> {
  try {
    const videoRef = db.collection("videos").doc(videoId);
    const videoDoc = await videoRef.get();
    if (!videoDoc.exists) return;

    const directUrl = downloadToken
      ? `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(outputPath)}?alt=media&token=${downloadToken}`
      : `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(outputPath)}?alt=media`;

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
      status: "ready", // Signals the player that playable resolutions exist
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await videoRef.update(updatePayload);
    console.log(`[Resolution Service] Synced ${variantLabel} with download token to video doc: ${videoId}`);
  } catch (err) {
    console.warn(`[Resolution Service] Failed to sync ${variantLabel} to video doc (non-fatal):`, err);
  }
}
