/**
 * ☁️ LAYER 03 — INGESTION LAYER (NO REDIS)
 *
 * Entry point for Cloud Storage trigger. Validates, deduplicates, tracks uploads.
 *
 * ✅ ARCHITECTURE (v8.0 — Publish-Gated Pipeline):
 *   1. Content-hash dedup    — Firestore-only (no Redis)
 *   2. Metadata extraction   — reads real GCS object metadata (size, duration hint)
 *   3. Lightweight tracking  — updates video doc with upload metadata ONLY
 *   4. NO pipeline trigger   — the pipeline is triggered by onVideoPublished (index.ts)
 *                              when the user publishes with complete metadata + aiFeatures
 */

import * as admin from "firebase-admin";
import { logger } from "../utils/logger";

const db = () => admin.firestore();
const storage = admin.storage();

/** Valid video MIME types and extensions */
const VALID_EXTENSIONS = new Set([
  ".mp4", ".avi", ".mov", ".mkv", ".webm", ".flv", ".wmv", 
  ".3gpp", ".3gp", ".mpeg", ".mpg", ".mpegps", ".m4v", 
  ".dnxhr", ".prores", ".cineform", ".hevc"
]);

export class IngestionLayer {
  constructor() {
    // No dependencies — ingestion now only tracks uploads in Firestore.
    // Pipeline trigger logic has moved to onVideoPublished (index.ts).
  }

  /**
   * Handle a Cloud Storage upload trigger.
   *
   * Returns the jobId (new or existing) or null if the file is invalid.
   *
   * Flow:
   *   1. Validate content type
   *   2. Extract userId from path
   *   3. Fetch GCS object metadata (size, MD5 hash)
   *   4. Firestore dedup check (content hash + filePath)
   *   5. Create job record + emit event
   *   6. Register video hash in Firestore for future dedup
   */
  async handleVideoUpload(
    bucket: string,
    filePath: string,
    contentType: string
  ): Promise<string | null> {
    const fileName = filePath.split("/").pop() ?? "";

    // 0. Only process original video uploads under the videos/ prefix (skip thumbnails, channels, etc.)
    if (!filePath.startsWith("videos/") || !fileName.startsWith("original")) {
      return null;  // Silently skip — other features handle these prefixes
    }

    logger.info("[Ingestion] Upload received", { filePath, contentType });

    // 1. Validate content type
    if (!this.isValidVideo(fileName, contentType)) {
      logger.warn("[Ingestion] Invalid file type — skipping", { fileName, contentType });
      return null;
    }

    // 2. Extract videoId from path: videos/{videoId}/original.mp4
    //    The Flutter app uploads to videos/{videoId}/original.mp4
    //    and creates a Firestore doc at videos/{videoId} with userId/ownerId
    const pathParts = filePath.split("/");
    if (pathParts.length < 3) {
      logger.error("[Ingestion] Unexpected path structure — expected videos/{videoId}/...", { filePath });
      return null;
    }
    const videoId = pathParts[1]; // videos/[videoId]/...
    if (!videoId || !/^[a-zA-Z0-9_-]{5,64}$/.test(videoId)) {
      logger.error("[Ingestion] Invalid videoId detected:", { videoId, filePath });
      return null;
    }

    // 3. Look up userId from Firestore video document (created by Flutter app before upload)
    let userId: string;
    let videoData: any = null;
    try {
      const videoDoc = await db().collection("videos").doc(videoId).get();
      if (!videoDoc.exists) {
        logger.error("[Ingestion] No Firestore document found for video", { videoId, filePath });
        return null;
      }
      videoData = videoDoc.data();
      userId = videoData?.userId ?? videoData?.ownerId ?? "";
      if (!userId) {
        logger.error("[Ingestion] Video document has no userId/ownerId", { videoId });
        return null;
      }
      logger.info("[Ingestion] Resolved userId from video doc", { videoId, userId });
    } catch (err) {
      logger.error("[Ingestion] Failed to look up video document", { videoId, err });
      return null;
    }

    // 4. Read GCS object metadata (includes MD5 hash + size)
    const meta = await this.fetchGCSMetadata(bucket, filePath);

    // Enforce 10 GB maximum file size
    const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024 * 1024; // 10 GB
    if (meta.fileSize && meta.fileSize > MAX_FILE_SIZE_BYTES) {
      logger.warn(`[Ingestion] File too large: ${meta.fileSize} bytes, videoId: ${videoId}`);
      await db().collection("videos").doc(videoId).update({
        status: "rejected",
        rejectionReason: "File size exceeds maximum allowed limit (10 GB)",
        updatedAt: Date.now(),
      });
      return null;
    }

    // 5. Firestore dedup check — content hash based
    if (meta.md5Hash) {
      const existingJobId = await this.firestoreHashDedup(meta.md5Hash);
      if (existingJobId) {
        logger.info("[Ingestion] Content hash dedup hit", { md5: meta.md5Hash, existingJobId });
        
        // RE-LINK Relationship: Ensure the new video document knows about the existing job
        const jobSnap = await db().collection("video_jobs").doc(existingJobId).get();
        const jobData = jobSnap.data();
        const originalUserId = jobData?.userId ?? "";

        // Cross-channel copyright check: only re-link if the uploader is the same owner
        if (originalUserId && originalUserId !== userId) {
          // Different owner — flag for copyright review instead of re-linking
          logger.info("[Ingestion] Cross-channel duplicate detected — flagging for copyright review", {
            videoId, userId, originalUserId, existingJobId, md5: meta.md5Hash,
          });

          await db().collection("videos").doc(videoId).update({
            copyrightStatus: "pending_review",
            copyrightHashMatch: {
              originalJobId: existingJobId,
              originalUserId,
              md5Hash: meta.md5Hash,
              detectedAt: Date.now(),
            },
            updatedAt: Date.now(),
          });

          // Register this video's hash so it gets its own tracking entry
          await this.registerVideoHash(meta.md5Hash!, videoId);

          // Fall through to the normal upload tracking path (lines 163-190)
          // so the video gets its own pipeline processing and copyright check.
        } else {
          // Same owner — proceed with re-link logic
          const isCompleted = jobData?.status === "completed";

          const videoUpdate: Record<string, any> = {
            jobId: existingJobId,
            updatedAt: Date.now(),
          };
          
          // If the job is already done, mark the video as ready immediately
          if (isCompleted) {
            videoUpdate.status = "ready";
          } else {
            videoUpdate.status = "processing";
          }

          await db().collection("videos").doc(videoId).update({
            ...videoUpdate,
          });

          // Reverse Mapping: Track that this job now serves multiple videos
          await db().collection("video_jobs").doc(existingJobId).update({
            linkedVideoCount: admin.firestore.FieldValue.increment(1),
            linkedVideoIds: admin.firestore.FieldValue.arrayUnion(videoId),
            updatedAt: Date.now(),
          });

          // RE-TRIGGER: If job is stalled/failed, the user can re-publish
          // via the UI and the onVideoPublished trigger will handle re-creation.
          if (!isCompleted) {
            logger.info("[Ingestion] Linked to in-progress job — user can re-publish if needed", { existingJobId });
          }

          return existingJobId;
        }
      }
    }

    // 6. Firestore dedup check — filePath based (covers in-flight jobs)
    const existingFromFilePath = await this.firestorePathDedup(userId, filePath);
    if (existingFromFilePath) {
      logger.info("[Ingestion] FilePath dedup hit", { existingJobId: existingFromFilePath });
      
      // RE-LINK for path-based dedup as well
      await db().collection("videos").doc(videoId).update({
        jobId: existingFromFilePath,
        updatedAt: Date.now(),
      });

      return existingFromFilePath;
    }

    // 7. Create lightweight tracking record (NO pipeline trigger)
    //    The actual video_job + pipeline trigger happens when the user publishes
    //    with complete metadata (title, description, aiFeatures.pipelineStage === 'published')
    const videoUrl = `gs://${bucket}/${filePath}`;

    // Check existing video document for duration if GCS meta doesn't have it
    const videoDoc = await db().collection("videos").doc(videoId).get();
    const existingData = videoDoc.data() || {};
    const existingDuration =
      existingData.duration ||
      (existingData.durationMs ? Math.round(existingData.durationMs / 1000) : 0);
    const finalDuration = meta.duration > 0 ? meta.duration : (existingDuration || 0);

    // Update the video document with upload metadata — do NOT trigger pipeline
    await db().collection("videos").doc(videoId).update({
      status: "uploaded", // Not 'processing' — waiting for publish
      videoUrl,
      videoHash: meta.md5Hash ?? null,
      duration: finalDuration,
      ...(finalDuration > 0 ? { durationMs: finalDuration * 1000 } : {}),
      resolution: meta.resolution,
      codec: meta.codec,
      fileSize: meta.fileSize,
      updatedAt: Date.now(),
    });

    // 8. Register content hash in Firestore for future dedup
    if (meta.md5Hash) {
      // Use videoId as placeholder — the real jobId will be created on publish
      await this.registerVideoHash(meta.md5Hash, videoId);
    }

    logger.info("[Ingestion] Upload tracked — awaiting publish with metadata", {
      videoId,
      fileName,
      md5: meta.md5Hash,
      duration: finalDuration,
    });
    return videoId;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  /** Fetch real GCS object metadata including MD5 hash */
  private async fetchGCSMetadata(
    bucketName: string,
    filePath: string
  ): Promise<{
    md5Hash: string | null;
    duration: number;
    resolution: string;
    codec: string;
    fileSize: number;
  }> {
    try {
      const [meta] = await storage.bucket(bucketName).file(filePath).getMetadata();
      // GCS returns MD5 as base64 string. We convert to hex for safe Firestore document IDs.
      const md5Base64 = meta.md5Hash as string | undefined;
      const md5Hex = md5Base64 ? Buffer.from(md5Base64, "base64").toString("hex") : null;
      const rawDur = meta.metadata?.duration
        ? parseInt(String(meta.metadata.duration), 10)
        : 0;

      return {
        md5Hash: md5Hex,
        duration: isNaN(rawDur) ? 0 : rawDur,
        resolution: String(meta.metadata?.resolution ?? "unknown"),
        codec: String(meta.metadata?.codec ?? "unknown"),
        fileSize: parseInt(String(meta.size ?? "0"), 10),
      };
    } catch (err) {
      logger.warn("[Ingestion] GCS metadata fetch failed — using defaults", { err });
      return {
        md5Hash: null,
        duration: 0,
        resolution: "unknown",
        codec: "unknown",
        fileSize: 0,
      };
    }
  }

  /**
   * Firestore-based dedup — checks video_hashes collection for content hash match.
   * 
   * In v8.0 (publish-gated), the hash registry stores videoId (not jobId) since
   * jobs are only created on publish. We look up the video doc to find any linked job.
   */
  private async firestoreHashDedup(md5Hash: string): Promise<string | null> {
    try {
      const hashDoc = await db().collection("video_hashes").doc(md5Hash).get();
      if (!hashDoc.exists) return null;

      const storedId = hashDoc.data()?.jobId; // May be a videoId or jobId (backward compat)
      if (!storedId) return null;

      // Case 1: Check if the stored ID is a jobId (backward compatibility)
      if (storedId.startsWith("job_")) {
        const jobDoc = await db().collection("video_jobs").doc(storedId).get();
        if (jobDoc.exists) {
          const jobStatus = jobDoc.data()?.status;
          if (jobStatus !== "failed" && jobStatus !== "error" && jobStatus !== "rejected") {
            return storedId;
          }
        }
        return null;
      }

      // Case 2: Stored ID is a videoId — look up the video doc for a linked jobId
      const videoDoc = await db().collection("videos").doc(storedId).get();
      if (!videoDoc.exists) return null;

      const videoData = videoDoc.data();
      const linkedJobId = videoData?.jobId;

      if (linkedJobId) {
        // Job exists — check its status
        const jobDoc = await db().collection("video_jobs").doc(linkedJobId).get();
        if (jobDoc.exists) {
          const jobStatus = jobDoc.data()?.status;
          if (jobStatus !== "failed" && jobStatus !== "error" && jobStatus !== "rejected") {
            return linkedJobId;
          }
        }
      }

      // No job yet or job failed — allow the upload (dedup will link to existing video)
      return null;
    } catch (err) {
      logger.warn("[Ingestion] Firestore hash dedup query failed", { err });
      return null;
    }
  }

  /**
   * Firestore-based dedup — checks for active jobs with the same filePath.
   */
  private async firestorePathDedup(userId: string, filePath: string): Promise<string | null> {
    try {
      const snap = await db()
        .collection("video_jobs")
        .where("userId", "==", userId)
        .where("filePath", "==", filePath)
        .where("status", "in", ["accepted", "processing", "running"]) // Added 'running'
        .limit(1)
        .get();

      return snap.empty ? null : snap.docs[0].data().jobId as string;
    } catch (err) {
      logger.warn("[Ingestion] Firestore path dedup query failed", { err });
      return null;
    }
  }

  /**
   * Register video content hash in Firestore for future dedup.
   * TTL managed by Firestore TTL policy on the `expiresAt` field.
   */
  private async registerVideoHash(md5Hash: string, jobId: string): Promise<void> {
    try {
      await db().collection("video_hashes").doc(md5Hash).set({
        jobId,
        registeredAt: Date.now(),
        expiresAt: Date.now() + 30 * 86400 * 1000, // 30 days TTL
      });
    } catch (err) {
      logger.warn("[Ingestion] Failed to register video hash", { md5Hash, err });
    }
  }

  private isValidVideo(fileName: string, _contentType: string): boolean {
    const ext = fileName.toLowerCase().slice(fileName.lastIndexOf("."));
    return VALID_EXTENSIONS.has(ext);
  }
}

export const ingestionLayer = new IngestionLayer();
