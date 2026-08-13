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

/** Maximum resolution cap — strictly 1040p */
const MAX_RESOLUTION_HEIGHT = 1040;

/** Full resolution ladder (descending). Only resolutions ≤ source are generated. */
interface ResolutionProfile {
  height: number;
  width: number;
  label: string;
  bitrateKbps: number;
  audioBitrateKbps: number;
  fps: number;
}

const RESOLUTION_LADDER: ResolutionProfile[] = [
  { height: 1040, width: 1848, label: "1040p", bitrateKbps: 5500, audioBitrateKbps: 192, fps: 30 },
  { height: 720, width: 1280, label: "720p", bitrateKbps: 3500, audioBitrateKbps: 128, fps: 30 },
  { height: 480, width: 854, label: "480p", bitrateKbps: 1500, audioBitrateKbps: 96, fps: 30 },
  { height: 360, width: 640, label: "360p", bitrateKbps: 1000, audioBitrateKbps: 96, fps: 30 },
  { height: 240, width: 426, label: "240p", bitrateKbps: 500, audioBitrateKbps: 64, fps: 24 },
  { height: 144, width: 256, label: "144p", bitrateKbps: 200, audioBitrateKbps: 48, fps: 15 },
];

const VALID_VIDEO_EXTENSIONS = new Set([
  ".mp4", ".avi", ".mov", ".mkv", ".webm", ".flv", ".wmv", 
  ".3gpp", ".3gp", ".mpeg", ".mpg", ".mpegps", ".m4v", 
  ".dnxhr", ".prores", ".cineform", ".hevc"
]);

// ─── Storage Trigger ─────────────────────────────────────────────────────────

/**
 * Triggered when a video is uploaded to Firebase Storage under the `videos/` prefix.
 *
 * Creates a resolution processing job:
 *   1. Validates the uploaded file
 *   2. Determines source resolution from metadata
 *   3. Computes applicable resolution ladder (capped at 1040p)
 *   4. Stores job metadata in Firestore `resolution_jobs` collection
 *   5. Marks each resolution variant status as pending
 *
 * ✅ CONFIG: minInstances=0, maxInstances=10, 512MiB, 300s timeout
 */
export const onVideoUploadedForResolution = onObjectFinalized(
  {
    bucket: "truthworld-1.firebasestorage.app",
    region: REGION,
    memory: "256MiB",       // Reduced from 512MiB — only reads GCS metadata + writes Firestore
    timeoutSeconds: 120,    // Reduced from 300s — typical execution is <10s
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

    // ─── MODERATION GATE: Skip resolution for rejected videos ────────────
    // Cost optimization: don't waste compute transcoding videos that will be rejected.
    // For pending moderation, we proceed but the video won't be exposed until approved.
    try {
      const videoDoc = await db.collection("videos").doc(videoId).get();
      if (videoDoc.exists) {
        const moderationStatus = videoDoc.data()?.moderation?.status;
        if (moderationStatus === "rejected") {
          console.log(`[Resolution Service] Video REJECTED by moderation — skipping resolution`, { videoId });
          return;
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

      // Determine effective source resolution
      const effectiveHeight = sourceHeight > 0 ? Math.min(sourceHeight, MAX_RESOLUTION_HEIGHT) : MAX_RESOLUTION_HEIGHT;

      // Build applicable resolution ladder (only resolutions ≤ source height, capped at 1040)
      const applicableResolutions = RESOLUTION_LADDER.filter(
        (r) => r.height <= effectiveHeight
      );

      if (applicableResolutions.length === 0) {
        console.warn(`[Resolution] No applicable resolutions for height=${sourceHeight}`);
        applicableResolutions.push(RESOLUTION_LADDER[RESOLUTION_LADDER.length - 1]); // at minimum 144p
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
        maxResolution: MAX_RESOLUTION_HEIGHT,
        variants,
        totalVariants: applicableResolutions.length,
        completedVariants: 0,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[Resolution] Job created`, {
        videoId,
        variants: applicableResolutions.map((r) => r.label).join(", "),
        maxRes: `${effectiveHeight}p`,
      });

      // ─── Autonomous Event Publishing ─────────────────────────────────────────────

      await MessagingService.publish("resolution.requested", {
        eventId: uuidv4(),
        jobId: videoId,
        userId,
        timestamp: Date.now(),
        data: {
          videoId,
          sourcePath: filePath,
          sourceBucket: bucket,
          sourceHeight,
          variants: applicableResolutions,
        },
      }, {
        source: "resolution-media-service",
        userId,
      });

      console.log(`[Resolution Service] Published resolution.requested autonomous event`, { videoId });
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
/**
 * Returns the resolution ladder configuration.
 * Useful for client-side adaptive bitrate player configuration.
 *
 * ✅ CONFIG: minInstances=0, maxInstances=5, 256MiB, 10s timeout
 * Note: Increased to 256MiB to avoid Cloud Run startup health check timeouts
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
  async (_req, res) => {
    res.status(200).json({
      maxResolution: `${MAX_RESOLUTION_HEIGHT}p`,
      profiles: RESOLUTION_LADDER.map((r) => ({
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
 * Orchestrates transcoding into multiple resolutions.
 *
 * ✅ v2.0 LOW-LATENCY:
 *   1. Parallel batch processing: 2 variants transcoded simultaneously (50% faster)
 *   2. 2GiB memory for parallel FFmpeg stability
 *   3. minInstances=1 for warm start (no cold start delay)
 *   4. Idempotency preserved via Firestore checks
 *
 * ✅ CONFIG: minInstances=1, maxInstances=5, 2GiB memory, 540s timeout
 */
export const handleResolution = onMessagePublished(
  {
    topic: "resolution.requested",
    region: REGION,
    memory: "2GiB",
    timeoutSeconds: 540,
    minInstances: 0,        // Scale-to-zero to optimize costs
    maxInstances: 2,
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
          sourceHeight: number;
          variants: ResolutionProfile[];
        };
      }>(event.data.message);

      videoId = parsedEvent.jobId;
      const { sourcePath, sourceBucket, variants } = parsedEvent.data;

      // 2. IDEMPOTENCY — Shared Bulletproof logic
      const status = await checkAndMarkEventId(parsedEvent.eventId, videoId);
      if (status === "COMPLETED" || status === "PROCESSING") {
        console.log(`[Resolution Worker] Duplicate event detected, skipping: ${parsedEvent.eventId}`, { videoId });
        return;
      }

      console.log(`[Resolution Worker] Starting job: ${videoId}`, { variants: variants.length, eventId: parsedEvent.eventId });

      // 3. Update overall status to processing (atomic)
      await db.collection("resolution_jobs").doc(videoId).update({
        status: "processing",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 4. PREPARE LOCAL WORKSPACE
      const tempDir = path.join(os.tmpdir(), `res_${videoId}`);
      if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

      const localSourcePath = path.join(tempDir, "original.mp4");
      const bucket = admin.storage().bucket(sourceBucket);

      console.log(`[Resolution Worker] Downloading source: ${sourcePath}`, { videoId });
      await bucket.file(sourcePath).download({ destination: localSourcePath });

      // 5. PROCESS VARIANTS — PARALLEL BATCHES (v2.0)
      // Process 2 variants simultaneously for ~50% faster completion.
      // 2GiB memory supports 2 concurrent FFmpeg processes safely.
      const BATCH_SIZE = 2;
      let completedCount = 0;

      /** Process a single variant — extracted for parallel batch execution */
      const processVariant = async (variant: ResolutionProfile): Promise<boolean> => {
        const variantLabel = variant.label;
        const variantRef = db.collection("resolution_jobs").doc(videoId);

        // Check if already completed (idempotency for partial retries)
        const currentDoc = await variantRef.get();
        const currentData = currentDoc.data();
        if (currentData?.variants?.[variantLabel]?.status === "completed") {
          console.log(`[Resolution Worker] Variant ${variantLabel} already completed, skipping.`, { videoId });
          return true;
        }

        console.log(`[Resolution Worker] Transcoding variant: ${variantLabel}`, { videoId });

        await variantRef.update({
          [`variants.${variantLabel}.status`]: "processing",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        try {
          const localOutputPath = path.join(tempDir, `${variantLabel}.mp4`);
          const targetPath = `resolutions/${videoId}/${variantLabel}.mp4`;

          // Execute FFmpeg Transcode
          await new Promise<void>((resolve, reject) => {
            getFFmpegInstance()(localSourcePath)
              .outputOptions([
                "-c:v libx264",
                `-b:v ${variant.bitrateKbps}k`,
                "-preset faster",
                `-vf scale=${variant.width}:${variant.height}`,
                "-c:a aac",
                `-b:a ${variant.audioBitrateKbps}k`,
                `-r ${variant.fps}`,
                "-movflags +faststart",
              ])
              .output(localOutputPath)
              .on("start", (cmd: string) => console.log(`[FFmpeg] ${variantLabel}: ${cmd}`))
              .on("end", () => resolve())
              .on("error", (err: Error) => reject(err))
              .run();
          });

          // Upload processed file
          console.log(`[Resolution Worker] Uploading: ${variantLabel}`, { videoId });
          await bucket.upload(localOutputPath, {
            destination: targetPath,
            metadata: { contentType: "video/mp4" },
          });

          // Update Firestore
          await variantRef.update({
            [`variants.${variantLabel}.status`]: "completed",
            [`variants.${variantLabel}.outputPath`]: targetPath,
            [`variants.${variantLabel}.processedAt`]: Date.now(),
            completedVariants: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Cleanup local variant output to save /tmp space
          if (fs.existsSync(localOutputPath)) fs.unlinkSync(localOutputPath);
          return true;

        } catch (variantErr) {
          console.error(`[Resolution Worker] Variant failed: ${variantLabel}`, { videoId, variantErr: (variantErr as any).message });

          await variantRef.update({
            [`variants.${variantLabel}.status`]: "failed",
            [`variants.${variantLabel}.error`]: variantErr instanceof Error ? variantErr.message : String(variantErr),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return false;
        }
      };

      // Process variants in parallel batches of BATCH_SIZE
      for (let i = 0; i < variants.length; i += BATCH_SIZE) {
        const batch = variants.slice(i, i + BATCH_SIZE);
        console.log(`[Resolution Worker] Processing batch ${Math.floor(i / BATCH_SIZE) + 1}: [${batch.map(v => v.label).join(", ")}]`, { videoId });

        const results = await Promise.all(batch.map(v => processVariant(v)));
        completedCount += results.filter(Boolean).length;
      }

      // 6. CLEANUP WORKSPACE
      if (fs.existsSync(localSourcePath)) fs.unlinkSync(localSourcePath);
      if (fs.existsSync(tempDir)) fs.rmdirSync(tempDir);

      // 7. Final job state evaluation
      const finalStatus = completedCount === variants.length ? "completed" : "partial";
      const resolutionRef = db.collection("resolution_jobs").doc(videoId);

      await resolutionRef.update({
        status: finalStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 🔥 UI EXPOSURE: Standard practice to sync results to the main 'videos' collection
      try {
        const jobSnapshot = await resolutionRef.get();
        const jobData = jobSnapshot.data();
        const processedVariants = jobData?.variants || {};
        const bucketName = jobData?.sourceBucket || "truthworld-1.firebasestorage.app";
        
        const playbackVariants: Record<string, string> = {};
        const adaptiveResolutions: Array<{ label: string; url: string; width: number; height: number; bitrate: number }> = [];
        let topLabel = "";
        let maxHeight = 0;

        for (const [label, v] of Object.entries(processedVariants) as [string, any][]) {
          if (v.status === "completed" && v.outputPath) {
            const filePath = v.outputPath;
            const directUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(filePath)}?alt=media`;
            playbackVariants[label] = directUrl;
            adaptiveResolutions.push({
              label,
              url: directUrl,
              width: v.width || 1280,
              height: v.height || 720,
              bitrate: (v.bitrateKbps || 2500) * 1000,
            });
            if (v.height > maxHeight) {
              maxHeight = v.height;
              topLabel = label;
            }
          }
        }

        if (Object.keys(playbackVariants).length > 0) {
          const updatePayload: Record<string, any> = {
            "media.variants": playbackVariants,
            "media.maxQuality": topLabel,
            "status": "ready", // Signals the UI that the video is playable
            "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
          };

          if (adaptiveResolutions.length > 0) {
            updatePayload.adaptiveResolutions = adaptiveResolutions;
            updatePayload["media.adaptiveResolutions"] = adaptiveResolutions;
          }

          await db.collection("videos").doc(videoId).update(updatePayload);
          console.log(`[Resolution Service] UI Exposure successful: ${videoId}`, { variants: Object.keys(playbackVariants), adaptiveResolutionsCount: adaptiveResolutions.length });
        }
      } catch (exposeErr) {
        console.warn(`[Resolution Service] UI Exposure failed for ${videoId} (non-fatal)`, exposeErr);
      }

      console.log(`[Resolution Worker] Finished job: ${videoId}`, { status: finalStatus, duration: Date.now() - t0 });

      // Permanently mark event as completed in idempotency ledger
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
