import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin } from "../utils/auth";
import { logger } from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 🛠️ REPAIR STUCK VIDEO JOBS
 * Finds all video_jobs that were flagged in MANUAL_REVIEW (e.g., due to AI evaluation 404 errors)
 * or marked approved/published but with downstream stages remaining stuck in 'pending'.
 * Resumes and triggers downstream processing (Fact checking, Dubbing, Transcoding, Copyright) for all of them.
 */
export const repairStuckVideoJobs = onRequest(
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

      const { jobId, dryRun = false } = req.body || {};

      const db = admin.firestore();
      let jobsToRepair: admin.firestore.QueryDocumentSnapshot[] = [];

      if (jobId && typeof jobId === "string") {
        const doc = await db.collection("video_jobs").doc(jobId).get();
        if (doc.exists) {
          jobsToRepair = [doc as any];
        }
      } else {
        // Query jobs stuck in MANUAL_REVIEW, pending credibility, or pending aggregation/finalizing
        const [manualReviewSnap, pendingCredibilitySnap, pendingAggregationSnap] = await Promise.all([
          db.collection("video_jobs").where("gatewayDecision.status", "==", "MANUAL_REVIEW").limit(100).get(),
          db.collection("video_jobs").where("stages.credibility.status", "==", "pending").limit(100).get(),
          db.collection("video_jobs").where("stages.aggregation.status", "==", "pending").where("status", "in", ["published", "accepted"]).limit(100).get()
        ]);

        const map = new Map<string, admin.firestore.QueryDocumentSnapshot>();
        manualReviewSnap.docs.forEach(doc => map.set(doc.id, doc));
        pendingCredibilitySnap.docs.forEach(doc => map.set(doc.id, doc));
        pendingAggregationSnap.docs.forEach(doc => map.set(doc.id, doc));

        jobsToRepair = Array.from(map.values());
      }

      logger.info(`[RepairStuckJobs] Found ${jobsToRepair.length} candidate jobs to repair (dryRun: ${dryRun})`);

      const repairedList: any[] = [];
      const now = Date.now();

      const { DistributionLayer } = require("../pipeline/layers/04-distribution");
      const { AggregationLayer } = require("../pipeline/layers/09-aggregation");
      const { translationService } = require("../pipeline/services/translation");
      const { mediaService } = require("../pipeline/services/media");
      const { normalizeLanguageCode } = require("../shared/language-normalizer");
      const distribution = new DistributionLayer();
      const aggregationLayer = new AggregationLayer();

      for (const jobDoc of jobsToRepair) {
        const id = jobDoc.id;
        const data = jobDoc.data() || {};
        const executionPlan = data.executionPlan || {};
        const userId = data.userId || "system";
        const videoId = data.videoId || id;

        const gatewayDecision = data.gatewayDecision || {};
        const isEvaluationError = typeof gatewayDecision.reviewReason === "string" &&
          (gatewayDecision.reviewReason.includes("Gateway AI evaluation encountered an error") || gatewayDecision.reviewReason.includes("404"));

        repairedList.push({
          jobId: id,
          videoId,
          status: data.status,
          wasEvaluationError: isEvaluationError,
          reviewReason: gatewayDecision.reviewReason
        });

        if (dryRun) continue;

        // 1. Update video_jobs record to APPROVED and published
        const updatePayload: any = {
          updatedAt: now,
          status: "published",
          gatewayStatus: "APPROVED",
          metadataComplete: true,
          publishedAt: data.publishedAt || now,
          "stages.moderation.status": "completed",
          "stages.moderation.progress": 100,
          "stages.moderation.completedAt": now,
        };

        if (gatewayDecision.status !== "APPROVED" || isEvaluationError) {
          updatePayload.gatewayDecision = {
            ...gatewayDecision,
            status: "APPROVED",
            confidence: 1.0,
            evaluatedAt: now,
            reviewReason: isEvaluationError ? "Cleared & Auto-Repaired from Gateway AI evaluation 404 error" : (gatewayDecision.reviewReason || "Manually approved by administrator"),
          };
        }

        // 1.5 Repair stuck translation / subtitle stages
        const targetLangs = (executionPlan.languages || []).filter((l: string) => normalizeLanguageCode(l) !== "en");

        if (targetLangs.length > 0) {
          try {
            // Load transcript if needed
            const transSnap = await db.collection("transcripts").doc(id).get();
            const transcript = transSnap.exists ? transSnap.data() : null;
            const utterances = transcript?.utterances || [];

            for (const lang of targetLangs) {
              const normLang = normalizeLanguageCode(lang);
              const subDocRef = db.collection("subtitle_results").doc(`${id}_${normLang}`);
              const subDocSnap = await subDocRef.get();

              if (!subDocSnap.exists && utterances.length > 0) {
                logger.info(`[RepairStuckJobs] Generating missing subtitles for ${id} in ${normLang}`);
                const segments = utterances.map((u: any, idx: number) => ({
                  start: u.start || 0,
                  end: u.end || 0,
                  text: u.text || "",
                  speaker: u.speaker,
                }));

                const transResult = await translationService.translateSegments(id, segments, "en", normLang);
                const subRes = await mediaService.generateAllSubtitles(
                  id,
                  transResult.segments.map((s: any) => ({ start: s.start, end: s.end, text: s.translated })),
                  normLang
                );

                const subData = {
                  jobId: id,
                  language: normLang,
                  subtitleUrl: subRes.srtUrl,
                  srtPath: subRes.srtUrl,
                  vttPath: subRes.vttUrl,
                  jsonPath: subRes.jsonUrl,
                  subtitleFormat: "srt",
                  createdAt: now,
                };

                await subDocRef.set(subData);
                if (lang !== normLang) {
                  await db.collection("subtitle_results").doc(`${id}_${lang}`).set({
                    ...subData,
                    language: lang,
                  });
                }
              }

              updatePayload[`stages.translating_${normLang}`] = { status: "completed", progress: 100, completedAt: now };
              if (lang !== normLang) {
                updatePayload[`stages.translating_${lang}`] = { status: "completed", progress: 100, completedAt: now };
              }
            }
          } catch (transErr) {
            logger.error(`[RepairStuckJobs] Subtitle repair error for ${id}:`, transErr);
          }
        }

        if (!executionPlan.generateDubbing) {
          updatePayload["stages.dubbing"] = { status: "completed", progress: 100, completedAt: now };
        }

        await jobDoc.ref.update(updatePayload);

        // 2. Ensure video document in `videos` collection is marked published
        await db.collection("videos").doc(videoId).set({
          status: "published",
          isPublished: true,
          metadataComplete: true,
          gatewayStatus: "APPROVED",
          updatedAt: now
        }, { merge: true });

        // 3. Mark admin_review_queue item as resolved
        await db.collection("admin_review_queue").doc(id).set({
          status: "approved",
          resolvedAt: now,
          resolvedBy: adminUser.uid,
          resolutionNotes: "Auto-repaired by repairStuckVideoJobs tool"
        }, { merge: true }).catch(() => {});

        // 4. Trigger Aggregation Stage Completion & Fan-out tasks
        await aggregationLayer.onStageComplete(id, "transcription", userId, executionPlan).catch(() => {});
        await aggregationLayer.onStageComplete(id, "dubbing", userId, executionPlan).catch(() => {});

        await distribution.publish("copyright-processing" as any, {
          eventId: `copy_repair_${id}`,
          eventType: "copyright-processing" as any,
          jobId: id, userId,
          timestamp: now,
          data: { videoUrl: data.videoUrl, executionPlan },
          retryCount: 0,
          source: "repair-stuck-jobs"
        }).catch(() => {});

        const shouldRunCredibility = !!(
          executionPlan.enablePath1 ||
          executionPlan.enableTruthEngine ||
          executionPlan.enableCredibility ||
          executionPlan.enableFactChecking
        );

        if (shouldRunCredibility) {
          await distribution.publish("fact-processing", {
            eventId: `fact_repair_${id}`,
            eventType: "fact-processing",
            jobId: id, userId,
            timestamp: now,
            data: { executionPlan },
            retryCount: 0,
            source: "repair-stuck-jobs"
          }).catch(() => {});
        }

        if (executionPlan.generateDubbing || executionPlan.enablePath2) {
          await distribution.publish("dubbing-processing", {
            eventId: `dub_repair_${id}`,
            eventType: "dubbing-processing",
            jobId: id, userId,
            timestamp: now,
            data: { executionPlan },
            retryCount: 0,
            source: "repair-stuck-jobs"
          }).catch(() => {});
        }
      }

      res.status(200).json({
        success: true,
        count: repairedList.length,
        dryRun,
        repairedJobs: repairedList
      });
    } catch (error) {
      logger.error("[repairStuckVideoJobs] Error:", error);
      res.status(500).json({ error: error instanceof Error ? error.message : "Internal error" });
    }
  }
);
