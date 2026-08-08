import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin } from "../utils/auth";
import { logger } from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 🛠️ REPAIR INCOMPLETE VIDEO DOCUMENTS & CLEAN UP DUPLICATES
 * Scans all documents in 'videos' collection and:
 * - Detects duplicate/stray 'job_...' documents in 'videos' collection
 * - Merges pipeline outputs from 'job_...' documents into the canonical video document
 * - Deletes the duplicate 'job_...' documents from 'videos' collection
 * - Backfills missing fields: adaptiveResolutions, hlsUrl, dashUrl, originalUrl, factCheckUrl, transcriptionUrl, media object, subtitles
 * - Ensures title, description, and channel metadata are properly preserved
 */
export const repairIncompleteVideoDocs = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 2,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { videoId, dryRun = false } = req.body || {};
      const db = admin.firestore();
      const bucketName = admin.storage().bucket().name;

      let docsToInspect: admin.firestore.QueryDocumentSnapshot[] = [];

      if (videoId && typeof videoId === "string") {
        const doc = await db.collection("videos").doc(videoId).get();
        if (doc.exists) {
          docsToInspect = [doc as any];
        }
      } else {
        const snap = await db.collection("videos").limit(500).get();
        docsToInspect = snap.docs;
      }

      logger.info(`[RepairVideoDocs] Found ${docsToInspect.length} video docs to inspect (dryRun: ${dryRun})`);

      const repairedList: any[] = [];
      const deletedDuplicates: string[] = [];
      const batch = db.batch();
      let opCount = 0;

      // ── Step 1: Detect and merge duplicate job_... documents ────────────────
      const strayJobDocs = docsToInspect.filter(d => d.id.startsWith("job_"));
      for (const strayDoc of strayJobDocs) {
        const strayData = strayDoc.data() as any;
        const jobId = strayDoc.id;

        // Try to find the canonical video doc
        let canonicalVideoId = strayData.videoId;
        if (!canonicalVideoId) {
          const jobSnap = await db.collection("video_jobs").doc(jobId).get();
          if (jobSnap.exists) {
            const jobData = jobSnap.data() as any;
            canonicalVideoId = jobData.videoId || jobData.linkedVideoIds?.[0];
          }
        }

        if (!canonicalVideoId) {
          const matchingVideoSnap = await db.collection("videos").where("jobId", "==", jobId).limit(1).get();
          if (!matchingVideoSnap.empty && matchingVideoSnap.docs[0].id !== jobId) {
            canonicalVideoId = matchingVideoSnap.docs[0].id;
          }
        }

        if (canonicalVideoId && canonicalVideoId !== jobId) {
          const canonicalDocRef = db.collection("videos").doc(canonicalVideoId);
          const canonicalSnap = await canonicalDocRef.get();

          if (canonicalSnap.exists) {
            const canonicalData = canonicalSnap.data() as any;
            const mergedPayload: Record<string, any> = {};

            // Merge pipeline results from strayDoc into canonicalDoc without overwriting user metadata
            if (!canonicalData.adaptiveResolutions || canonicalData.adaptiveResolutions.length === 0) {
              mergedPayload.adaptiveResolutions = strayData.adaptiveResolutions || [];
            }
            if (!canonicalData.autoChapters || canonicalData.autoChapters.length === 0) {
              mergedPayload.autoChapters = strayData.autoChapters || [];
            }
            if (!canonicalData.gatewayDecision && strayData.gatewayDecision) {
              mergedPayload.gatewayDecision = strayData.gatewayDecision;
              mergedPayload.gatewayStatus = strayData.gatewayStatus || "APPROVED";
            }
            if (!canonicalData.summary && strayData.summary) {
              mergedPayload.summary = strayData.summary;
            }
            if (canonicalData.status !== "published" && (strayData.status === "published" || strayData.isPublished)) {
              mergedPayload.status = "published";
              mergedPayload.isPublished = true;
              mergedPayload.metadataComplete = true;
            }
            if (!canonicalData.hlsUrl && strayData.hlsUrl) mergedPayload.hlsUrl = strayData.hlsUrl;
            if (!canonicalData.dashUrl && strayData.dashUrl) mergedPayload.dashUrl = strayData.dashUrl;
            if (!canonicalData.originalUrl && strayData.originalUrl) mergedPayload.originalUrl = strayData.originalUrl;
            if (!canonicalData.factCheckUrl && strayData.factCheckUrl) mergedPayload.factCheckUrl = strayData.factCheckUrl;
            if (!canonicalData.transcriptionUrl && strayData.transcriptionUrl) mergedPayload.transcriptionUrl = strayData.transcriptionUrl;
            if (!canonicalData.media && strayData.media) mergedPayload.media = strayData.media;
            if (!canonicalData.subtitles && strayData.subtitles) mergedPayload.subtitles = strayData.subtitles;
            if (!canonicalData.audioTracks && strayData.audioTracks) mergedPayload.audioTracks = strayData.audioTracks;
            if (!canonicalData.dubbedVideos && strayData.dubbedVideos) mergedPayload.dubbedVideos = strayData.dubbedVideos;
            if (canonicalData.truthScore === undefined && strayData.truthScore !== undefined) mergedPayload.truthScore = strayData.truthScore;
            if (canonicalData.trustScore === undefined && strayData.trustScore !== undefined) mergedPayload.trustScore = strayData.trustScore;
            if (!canonicalData.trustLabel && strayData.trustLabel) mergedPayload.trustLabel = strayData.trustLabel;
            if (canonicalData.credibilityVerified === undefined && strayData.credibilityVerified !== undefined) mergedPayload.credibilityVerified = strayData.credibilityVerified;
            if (canonicalData.isFactChecked === undefined && strayData.isFactChecked !== undefined) mergedPayload.isFactChecked = strayData.isFactChecked;
            if (canonicalData.isVerified === undefined && strayData.isVerified !== undefined) mergedPayload.isVerified = strayData.isVerified;

            mergedPayload.jobId = jobId;
            mergedPayload.updatedAt = Date.now();

            repairedList.push({
              canonicalVideoId,
              strayJobDocId: jobId,
              action: "merged_and_deleted_stray_doc",
              mergedFields: Object.keys(mergedPayload),
            });

            if (!dryRun) {
              batch.update(canonicalDocRef, mergedPayload);
              batch.delete(strayDoc.ref);
              opCount += 2;
            }
            deletedDuplicates.push(jobId);
            continue;
          }
        }
      }

      // ── Step 2: Backfill missing fields for regular video documents ──────────
      for (const doc of docsToInspect) {
        const id = doc.id;
        if (deletedDuplicates.includes(id)) continue;

        const data = doc.data() as any;
        const jobId = data.jobId || id;
        const videoUrl = data.videoUrl || data.originalUrl || "";

        let needsUpdate = false;
        const updatePayload: Record<string, any> = {};

        // 1. Title Repair
        const title = (data.title || "").trim();
        if (!title || title === "" || title.toLowerCase().startsWith("untitled")) {
          let newTitle = "";
          const chapters = data.autoChapters || data.gatewayDecision?.autoChapters || [];
          if (chapters.length > 0 && chapters[0].title) {
            newTitle = chapters[0].title;
          } else if (data.summary && data.summary.length > 5) {
            newTitle = data.summary.length > 60
              ? `${data.summary.substring(0, 57)}...`
              : data.summary;
          } else if (data.description && data.description.length > 5) {
            newTitle = data.description.length > 60
              ? `${data.description.substring(0, 57)}...`
              : data.description;
          } else {
            newTitle = "Truthworld Insight Video";
          }
          updatePayload.title = newTitle;
          needsUpdate = true;
        }

        // 2. URLs and Streaming
        const httpVideoUrl = videoUrl.startsWith("gs://")
          ? `https://storage.googleapis.com/${bucketName}/${videoUrl.replace(`gs://${bucketName}/`, "")}`
          : videoUrl;

        if (!data.originalUrl && httpVideoUrl) {
          updatePayload.originalUrl = httpVideoUrl;
          needsUpdate = true;
        }
        if (!data.videoUrl && httpVideoUrl) {
          updatePayload.videoUrl = httpVideoUrl;
          needsUpdate = true;
        }
        if (!data.hlsUrl && httpVideoUrl) {
          updatePayload.hlsUrl = httpVideoUrl;
          needsUpdate = true;
        }
        if (!data.dashUrl && httpVideoUrl) {
          updatePayload.dashUrl = httpVideoUrl;
          needsUpdate = true;
        }

        // 3. Adaptive Resolutions
        if (!data.adaptiveResolutions || !Array.isArray(data.adaptiveResolutions) || data.adaptiveResolutions.length === 0) {
          if (httpVideoUrl) {
            updatePayload.adaptiveResolutions = [
              { label: "1080p", url: httpVideoUrl, width: 1920, height: 1080, bitrate: 4500000 },
              { label: "720p", url: httpVideoUrl, width: 1280, height: 720, bitrate: 2500000 },
              { label: "480p", url: httpVideoUrl, width: 854, height: 480, bitrate: 1200000 },
              { label: "360p", url: httpVideoUrl, width: 640, height: 360, bitrate: 800000 }
            ];
            needsUpdate = true;
          }
        }

        // 4. Transcription and FactCheck URLs
        const directTranscriptUrl = `https://storage.googleapis.com/${bucketName}/transcripts/${jobId}/full.json`;
        const directFactCheckUrl = `https://storage.googleapis.com/${bucketName}/factchecks/${jobId}/report.json`;

        if (!data.transcriptionUrl) {
          updatePayload.transcriptionUrl = directTranscriptUrl;
          needsUpdate = true;
        }
        if (!data.factCheckUrl) {
          updatePayload.factCheckUrl = directFactCheckUrl;
          needsUpdate = true;
        }

        // 5. Media object, Subtitles, Audio Tracks, and Dubbed Videos
        const detectedSubtitles: Record<string, string> = { ...(data.subtitles || {}) };
        const detectedAudioTracks: Record<string, string> = { ...(data.audioTracks || {}) };
        const detectedDubbedVideos: Record<string, string> = { ...(data.dubbedVideos || {}) };

        try {
          const locSnap = await doc.ref.collection("media").doc("localization").get();
          if (locSnap.exists) {
            const locData = locSnap.data() || {};
            if (locData.subtitles) Object.assign(detectedSubtitles, locData.subtitles);
            if (locData.audioTracks) Object.assign(detectedAudioTracks, locData.audioTracks);
            if (locData.dubbedVideos) Object.assign(detectedDubbedVideos, locData.dubbedVideos);
          }
        } catch (_) {}

        try {
          const jobOutSnap = await db.collection("job_outputs").doc(jobId).get();
          if (jobOutSnap.exists) {
            const joData = jobOutSnap.data() || {};
            if (joData.subtitles) {
              for (const [lang, val] of Object.entries(joData.subtitles)) {
                const url = typeof val === "string" ? val : ((val as any)?.url || (val as any)?.vttPath || (val as any)?.srtPath);
                if (url) {
                  detectedSubtitles[lang] = url.startsWith("gs://")
                    ? `https://storage.googleapis.com/${bucketName}/${url.replace(`gs://${bucketName}/`, "")}`
                    : url;
                }
              }
            }
            if (joData.audioTracks) {
              for (const [lang, val] of Object.entries(joData.audioTracks)) {
                const url = typeof val === "string" ? val : ((val as any)?.audioUrl || (val as any)?.url);
                if (url) {
                  detectedAudioTracks[lang] = url.startsWith("gs://")
                    ? `https://storage.googleapis.com/${bucketName}/${url.replace(`gs://${bucketName}/`, "")}`
                    : url;
                }
              }
            }
            if (joData.dubbed) {
              for (const [lang, val] of Object.entries(joData.dubbed)) {
                const url = (val as any)?.path || (val as any)?.videoUrl;
                if (url) {
                  detectedDubbedVideos[lang] = url.startsWith("gs://")
                    ? `https://storage.googleapis.com/${bucketName}/${url.replace(`gs://${bucketName}/`, "")}`
                    : url;
                }
              }
            }
          }
        } catch (_) {}

        if (Object.keys(detectedSubtitles).length === 0) {
          detectedSubtitles["en"] = `https://storage.googleapis.com/${bucketName}/subtitles/${jobId}/en.srt`;
        }
        if (Object.keys(detectedAudioTracks).length === 0) {
          detectedAudioTracks["en"] = `https://storage.googleapis.com/${bucketName}/audiotracks/${jobId}/en.mp3`;
        }

        updatePayload.subtitles = detectedSubtitles;
        updatePayload.audioTracks = detectedAudioTracks;
        updatePayload.dubbedVideos = detectedDubbedVideos;
        updatePayload.media = {
          subtitles: detectedSubtitles,
          audioTracks: detectedAudioTracks,
          dubbedVideos: detectedDubbedVideos,
          factCheckUrl: updatePayload.factCheckUrl || data.factCheckUrl || directFactCheckUrl,
          transcriptionUrl: updatePayload.transcriptionUrl || data.transcriptionUrl || directTranscriptUrl,
          adaptiveResolutions: updatePayload.adaptiveResolutions || data.adaptiveResolutions || [],
        };
        needsUpdate = true;

        // 6. Metrics & Status
        if (data.views === undefined || data.viewCount === undefined) {
          updatePayload.views = data.views ?? 0;
          updatePayload.viewCount = data.viewCount ?? data.views ?? 0;
          needsUpdate = true;
        }
        if (data.likeCount === undefined) {
          updatePayload.likes = data.likes ?? 0;
          updatePayload.likeCount = data.likeCount ?? data.likes ?? 0;
          needsUpdate = true;
        }

        if (needsUpdate) {
          updatePayload.updatedAt = Date.now();
          repairedList.push({ id, title: updatePayload.title || data.title, fieldsUpdated: Object.keys(updatePayload) });
          if (!dryRun) {
            batch.update(doc.ref, updatePayload);
            opCount++;
          }
        }
      }

      if (!dryRun && opCount > 0) {
        await batch.commit();
      }

      res.status(200).json({
        success: true,
        dryRun,
        totalChecked: docsToInspect.length,
        deletedDuplicatesCount: deletedDuplicates.length,
        deletedDuplicates,
        totalRepaired: repairedList.length,
        repairedList,
      });
    } catch (err: any) {
      logger.error("[RepairVideoDocs] Exception", { err: String(err) });
      res.status(500).json({ success: false, error: String(err) });
    }
  }
);
