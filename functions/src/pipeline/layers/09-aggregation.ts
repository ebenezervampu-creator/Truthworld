/**
 * 🧮 LAYER 09 — AGGREGATION LAYER
 */

import * as admin from "firebase-admin";
import {
  AggregatedOutput,
  ExecutionPlan,
  JobData,
} from "../types";
import { DistributionLayer } from "./04-distribution";
import { EdgeLayer } from "./01-edge";
import { logger } from "../utils/logger";
import { reputationService } from "../services/reputationService";
import { SpeakerReputationService } from "../services/speakerReputationService";
import { CredibilityResult } from "../types";
import { getAnalysisRepository, AnalysisRepository } from "../services/analysisRepository.js";

const db = () => admin.firestore();

function getDownloadUrl(gsOrPath: string, defaultBucket?: string): string {
  if (!gsOrPath) return "";
  if (gsOrPath.startsWith("http://") || gsOrPath.startsWith("https://")) {
    return gsOrPath;
  }
  let bucketName = defaultBucket || admin.storage().bucket().name;
  let filePath = gsOrPath;
  if (gsOrPath.startsWith("gs://")) {
    const parts = gsOrPath.replace("gs://", "").split("/");
    bucketName = parts[0];
    filePath = parts.slice(1).join("/");
  }
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(filePath)}?alt=media`;
}

export class AggregationLayer {
  private readonly distribution: DistributionLayer;

  private readonly speakerReputation: SpeakerReputationService;
  private readonly analysisRepository: AnalysisRepository;
  
  constructor(analysisRepository?: AnalysisRepository) {
    this.distribution = new DistributionLayer();
    this.speakerReputation = new SpeakerReputationService();
    this.analysisRepository = analysisRepository || getAnalysisRepository();
  }

  /**
   * 🎯 Generic Stage Completion Handler
   * Replaces stage-specific methods (onFactComplete, onDubbingComplete).
   * Ensures any terminal stage can trigger job completion.
   */
  async onStageComplete(
    jobId: string,
    stageName: "transcription" | "credibility" | "dubbing" | "aggregation" | "copyright",
    userId: string,
    executionPlan: ExecutionPlan,
    eventId?: string
  ): Promise<AggregatedOutput | null> {
    if (eventId) {
      const status = await this.distribution.checkAndMarkEventId(eventId, jobId);
      if (status === "COMPLETED" || status === "PROCESSING") return this.getFinalOutput(jobId);
    }

    logger.info("[Aggregation] Stage completed, evaluating truth table", { jobId, stageName });

    // Ensure the stage is marked as completed in the canonical ledger
    await EdgeLayer.updateStageSync(jobId, stageName, {
      status: "completed",
      progress: 100,
      completedAt: Date.now(),
    });

    // 🕊 Truth Table Check: Are all required stages done?
    const ready = await this.checkAllStagesReady(jobId, executionPlan);
    
    // 🚀 NEW: Early Propagation (v8.5)
    // Even if the job isn't terminal, propagate partial results (scores, audio)
    // so the UI can show progress and results in real-time.
    await this.propagateStageResults(jobId, stageName, userId, executionPlan);

    if (!ready) {
      logger.info("[Aggregation] Job not yet terminal — waiting for other stages", { jobId });
      return null;
    }

    await EdgeLayer.updateStageSync(jobId, "rendering", { 
      status: "running", progress: 50, startedAt: Date.now() 
    });

    return this.runAggregationTransaction(jobId, userId, executionPlan, stageName);
  }

  /**
   * 🎤 Backward compatibility for legacy triggers
   */
  async onFactComplete(jobId: string, userId: string, _data: any, plan: ExecutionPlan, eventId: string) {
    return this.onStageComplete(jobId, "credibility", userId, plan, eventId);
  }

  async onDubbingComplete(jobId: string, userId: string, _data: any, plan: ExecutionPlan, eventId: string) {
    return this.onStageComplete(jobId, "dubbing", userId, plan, eventId);
  }

  /**
   * 🧩 Truth Table Logic: 
   * Determines if the job is ready for completion based on the ExecutionPlan.
   */
  private async checkAllStagesReady(jobId: string, plan: ExecutionPlan): Promise<boolean> {
    const job = await db().collection("video_jobs").doc(jobId).get();
    if (!job.exists) return false;
    const data = job.data() as JobData;
    const stages = (data.stages || {}) as any;
    
    const isDone = (s: any) => s?.status === "completed" || s?.status === "skipped" || s?.status === "failed";

    // 1. Transcription is ALWAYS required
    const transcriptionDone = isDone(stages.transcription);

    // 1.5. Copyright check is required (backward compatible if stages.copyright doesn't exist)
    const copyrightDone = !stages.copyright || isDone(stages.copyright);

    // 2. TruthEngine (Path 1) is required if enabled
    const truthEngineRequired = plan.enablePath1 || plan.enableTruthEngine;
    const truthEngineDone = !truthEngineRequired || isDone(stages.credibility);

    // 3. ReachEngine (Path 2) is required if enabled
    const reachEngineRequired = plan.enablePath2 || plan.enableReachEngine;
    let reachEngineDone = true;
    
    if (reachEngineRequired) {
      // Must have the base 'dubbing' stage marked as completed or skipped
      reachEngineDone = isDone(stages.dubbing);
      
      // Also verify all individual language stages if they exist
      const targetLangs = (plan.languages || []).filter(l => l !== "en");
      for (const lang of targetLangs) {
        // Translation stage is always required for non-source languages
        if (!isDone(stages[`translating_${lang}`])) {
          reachEngineDone = false;
          break;
        }
        // Dubbing stage is only required if dubbing is explicitly enabled
        if (plan.generateDubbing && !isDone(stages[`dubbing_${lang}`])) {
          reachEngineDone = false;
          break;
        }
      }
    }

    const ready = transcriptionDone && copyrightDone && truthEngineDone && reachEngineDone;

    if (ready) {
      logger.info("[Aggregation] Truth table satisfied — proceeding to completion", { 
        jobId, transcriptionDone, copyrightDone, truthEngineDone, reachEngineDone 
      });
    }

    return ready;
  }

  /**
   * 🚀 Final Completion Transaction
   * Atomically flips the job to 'completed' and propagates status to linked videos.
   */
  private async runAggregationTransaction(
    jobId: string,
    userId: string,
    plan: ExecutionPlan,
    triggerStage: string
  ): Promise<AggregatedOutput | null> {
    try {
      const resultOutput = await db().runTransaction(async (transaction) => {
        const jobRef = db().collection("video_jobs").doc(jobId);
        const jobSnap = await transaction.get(jobRef);
        const jobData = jobSnap.data() as JobData;

        // 🛡 Idempotent Guard: Prevent duplicate terminal writes
        if (jobData?.status === "completed") {
          logger.info("[Aggregation] Job already completed — exiting transaction", { jobId });
          return null;
        }

        const transSnap = await transaction.get(db().collection("transcripts").doc(jobId));

        // Fetch job outputs document (scale check split)
        const jobOutputsRef = db().collection("job_outputs").doc(jobId);
        const jobOutputsSnap = await transaction.get(jobOutputsRef);
        const jobOutputsData = jobOutputsSnap.exists ? jobOutputsSnap.data() : {};
        
        // 3.5. Fetch localization artifacts (Dubbing) per language
        const [dubbingSnaps, subtitleSnaps] = await Promise.all([
          Promise.all((plan.languages || []).map(lang => transaction.get(db().collection("dubbing_results").doc(`${jobId}_${lang}`)))),
          Promise.all((plan.languages || []).map(lang => transaction.get(db().collection("subtitle_results").doc(`${jobId}_${lang}`))))
        ]);

        // 3.6. Fetch source language subtitle if not already in the list
        const sourceLang = jobData.sourceLanguage || "en";
        let sourceSubSnap = null;
        if (!(plan.languages || []).includes(sourceLang)) {
          sourceSubSnap = await transaction.get(db().collection("subtitle_results").doc(`${jobId}_${sourceLang}`));
        }

        // Note: Partial results might be missing if stages were skipped
        const trans = transSnap.exists ? transSnap.data() as any : null;
        const jobOutputs = {
          ...(jobData.outputs || {}),
          ...(jobOutputsData || {})
        };

        // 🚀 Resolve full credibility result from GCS (Industry Standard for large payloads)
        let cred: CredibilityResult | null = null;
        if (jobOutputs.factCheckUrl) {
          try {
            const bucket = admin.storage().bucket();
            const path = jobOutputs.factCheckUrl.replace(`gs://${bucket.name}/`, "");
            const [content] = await bucket.file(path).download();
            cred = JSON.parse(content.toString()) as CredibilityResult;
            logger.info("[Aggregation] Resolved full credibility report from Storage", { jobId });
          } catch (err) {
            logger.error("[Aggregation] Failed to resolve credibility from Storage", { jobId, err: String(err) });
          }
        }

        // 🚀 Normalize Subtitles for Scalability & UI Consistency
        const subtitlesMap: Record<string, any> = {};
        const flatSubtitles: Record<string, string> = {};

        // 1. Initialise from jobData (source language or previous runs)
        if (jobData.outputs?.subtitles) {
          for (const [lang, data] of Object.entries(jobData.outputs.subtitles) as [string, any][]) {
            const url = data.vttPath || data.srtPath || data.url || data.subtitleUrl;
            if (!url) continue;

            const directUrl = getDownloadUrl(url);
            subtitlesMap[lang] = {
              ...data,
              url: directUrl,
              format: data.vttPath ? "vtt" : (data.srtPath ? "srt" : (data.format || data.subtitleFormat || "srt")),
              language: lang,
              updatedAt: data.createdAt || data.updatedAt || Date.now(),
            };
            flatSubtitles[lang] = directUrl;
          }
        }
        
        // 2. Merge from subtitle_results snaps (ReachEngine results)
        if (sourceSubSnap?.exists) {
          const data = sourceSubSnap.data();
          const url = data?.subtitleUrl;
          if (url) {
            const directUrl = getDownloadUrl(url);
            subtitlesMap[sourceLang] = {
              url: directUrl,
              format: data?.subtitleFormat || "srt",
              language: sourceLang,
              updatedAt: data?.createdAt || Date.now(),
            };
            flatSubtitles[sourceLang] = directUrl;
          }
        }

        subtitleSnaps.forEach(snap => {
          if (snap.exists) {
            const data = snap.data();
            const lang = data?.language;
            const url = data?.subtitleUrl;
            if (lang && url) {
              const directUrl = getDownloadUrl(url);
              subtitlesMap[lang] = {
                url: directUrl,
                format: data?.subtitleFormat || "srt",
                language: lang,
                updatedAt: data?.createdAt || Date.now(),
              };
              flatSubtitles[lang] = directUrl;
            }
          }
        });

        const dubbedMap: Record<string, any> = {};
        if (jobData.outputs?.dubbed) {
          for (const [lang, data] of Object.entries(jobData.outputs.dubbed) as [string, any][]) {
            if (data.audioUrl) {
              const directAudioUrl = getDownloadUrl(data.audioUrl);
              const directVideoUrl = data.videoUrl ? getDownloadUrl(data.videoUrl) : (data.path ? getDownloadUrl(data.path) : "");
              dubbedMap[lang] = {
                ...data,
                audioUrl: directAudioUrl,
                path: directVideoUrl || data.path || data.videoUrl,
              };
            }
          }
        }
        const audioTracksMap: Record<string, string> = {}; // Flat map for video doc convenience

        dubbingSnaps.forEach(snap => {
          if (snap.exists) {
            const data = snap.data();
            if (data?.videoUrl) {
              const directVideoUrl = getDownloadUrl(data.videoUrl);
              const directAudioUrl = getDownloadUrl(data.audioUrl);
              dubbedMap[data.language] = {
                path:      directVideoUrl,
                audioUrl:  directAudioUrl,
                createdAt: data.createdAt || Date.now(),
              };
            }
            if (data?.audioUrl) {
              audioTracksMap[data.language] = getDownloadUrl(data.audioUrl);
            }
          }
        });

        await EdgeLayer.updateStageSync(jobId, "rendering", { 
          status: "completed", progress: 100, completedAt: Date.now() 
        });
        await EdgeLayer.updateStageSync(jobId, "finalizing", { 
          status: "running", progress: 50, startedAt: Date.now() 
        });

        const directFactCheckUrl = getDownloadUrl(jobOutputs.factCheckUrl || "");
        const bucket = admin.storage().bucket();
        const transcriptUrl = `gs://${bucket.name}/transcripts/${jobId}/full.json`;
        const directTranscriptUrl = getDownloadUrl(transcriptUrl);

        const output: AggregatedOutput = {
          jobId,
          userId,
          videoUrl: jobData?.videoUrl || "",
          trustScore: jobOutputs.trustScore || cred?.trustScore || 0,
          trustLabel: jobOutputs.trustLabel || cred?.trustLabel || "Low Reliability",
          confidence: cred?.confidence || 0,
          confidenceTier: cred?.confidenceTier || "low",
          speakerConfidence: trans?.speakerConfidence || 0, // v5.3
          rating: jobOutputs.trustScore || cred?.trustScore || 0, // Legacy sync
          summary: jobOutputs.summary || cred?.summary || "",
          conclusion: (cred?.conclusion || undefined) as any,
          keyThemes: cred?.keyThemes || [],
          chapters: trans?.chapters || [], // ✅ Propagate auto-chapters from transcript
          viewerNote: cred?.viewerNote || "",
          domain: cred?.domain || "General",
          vertical: cred?.vertical || "general",
          verticalScores: (cred?.verticalScores || undefined) as any,
          reviewTriggered: cred?.reviewTriggered || false,
          reviewReason: cred?.reviewReason || "",
          verifiedAt: cred?.verifiedAt || Date.now(),
          factCheckUrl: directFactCheckUrl,
          diagnostics: cred?.diagnostics || [],
          confidenceNotes: cred?.confidenceNotes || [],
          checkedClaimsRatio: cred?.factCheckStats?.checkedClaimsRatio || 0, // v5.0
          isLaunchNews: jobOutputs.isLaunchNews || cred?.isLaunchNews || false, // v5.0
          launchGrounded: jobOutputs.launchGrounded || cred?.launchGrounded || false, // v5.0
          speakerMetrics: cred?.speakers || [], // v5.0
          claims: cred?.claims || [],
          subtitles: subtitlesMap, 
          media: {
            subtitles: flatSubtitles,
            audioTracks: audioTracksMap,
            factCheckUrl: directFactCheckUrl,
            transcriptionUrl: directTranscriptUrl,
          },
          dubbedVideoUrl: dubbedMap[plan.languages?.[0] || ""]?.path || "", 
          dubbedVideos: dubbedMap,
          audioTracks: audioTracksMap,
          status: "completed",
          processingTime: Date.now() - (jobData?.createdAt || Date.now()),
          completedAt: Date.now(),
          artifacts: {
            subtitles: subtitlesMap,
            dubbing: dubbedMap,
            audio: audioTracksMap,
          },
        };

        // Skip Firestore final_outputs write, persisting to GCS after transaction success
        logger.info("[Aggregation] Bypassed Firestore final_outputs write, persisting to Storage post-transaction", { jobId });

        // 2. Update job record with terminal metrics & results
        const now = Date.now();
        const stageDurations: Record<string, number> = {};
        if (jobData?.stages) {
          for (const [name, status] of Object.entries(jobData.stages)) {
            if (!status) continue;
            const start = status.startedAt;
            const end = status.completedAt || (status.status === "completed" ? now : null);
            if (start && end) {
              stageDurations[name] = Math.round((end - start) / 1000);
            }
          }
        }

        transaction.update(jobRef, {
          status: "completed",
          progress: 100,
          completedAt: now,
          actualCompletedAt: now,
          stageDurations,
          completionSource: triggerStage, // Terminal Metric
          updatedAt: now,
          version: admin.firestore.FieldValue.increment(1),
          // Record processed languages to prevent reactive double-trigger
          processedLocalizationVersions: admin.firestore.FieldValue.arrayUnion(
            (plan.languages ?? []).sort().join(",")
          ),
          outputs: {
            trustScore: cred?.trustScore || 0,
            videoRating: cred?.videoRating ?? (cred?.trustScore ? Number((cred.trustScore / 10).toFixed(1)) : 0),
            trustLabel: cred?.trustLabel || "Low Reliability",
            rating: cred?.trustScore || 0, // LEGACY
            contentIntent: cred?.contentIntent ? {
              primaryIntent: cred.contentIntent.primaryIntent,
              confidence: cred.contentIntent.confidence,
              subjectiveRatio: cred.contentIntent.subjectiveRatio,
              promotionalSignals: cred.contentIntent.promotionalSignals,
            } : null,
            summary: cred?.summary || "",
            conclusion: cred?.conclusion || null,
            viewerNote: cred?.viewerNote || "",
            checkedClaimsRatio: cred?.factCheckStats?.checkedClaimsRatio || 0, // v5.0
            factCheckUrl: jobOutputs.factCheckUrl || null,
          }
        });

        // Write the heavy fields to the separate job_outputs document:
        transaction.set(jobOutputsRef, {
          subtitles: subtitlesMap,
          dubbed: dubbedMap,
          audioTracks: audioTracksMap,
          updatedAt: now,
        }, { merge: true });

        await EdgeLayer.updateStageSync(jobId, "finalizing", { 
          status: "completed", progress: 100, completedAt: Date.now() 
        });
        
        if (cred?.speakers && cred.speakerIdentities) {
          const identities = cred.speakerIdentities;
          for (const metrics of cred.speakers) {
            const idInfo = (identities as any)[metrics.speakerId];
            if (idInfo?.id) {
              await this.speakerReputation.updateReputation(jobId, idInfo.id, metrics, cred.factCheckStats);
            }
          }
        }

        // Update the creator's reputation based on the final credibility report
        if (cred && jobData?.channelId) {
          try {
              // v7.2: Calculate Metadata Reliability Score
              const metadataScore = this.calculateMetadataReliability(jobData.executionPlan, cred as CredibilityResult);
              await reputationService.updateReputation(userId, jobData.channelId, {
                ...cred,
                metadataReliability: metadataScore
              } as any);
          } catch (repErr) {
             logger.error("[Aggregation] Failed to update creator reputation", { jobId, userId, err: String(repErr) });
          }
        }

        // 3. 🚀 CRITICAL: Propagate status to ALL linked videos (Deduplication Fix)
        const linkedVideoIds = jobData?.linkedVideoIds || [];
        if (jobData?.videoId && !linkedVideoIds.includes(jobData.videoId)) {
          linkedVideoIds.push(jobData.videoId);
        }

        logger.info("[Aggregation] Propagating 'ready' to linked videos", { 
          jobId, count: linkedVideoIds.length 
        });

        for (const vid of linkedVideoIds) {
          const vRef = db().collection("videos").doc(vid);
          const vSnap = await transaction.get(vRef);
          const vData = vSnap.data();

          // If video is scheduled for the future, keep it in 'scheduled' status
          // so the Scheduled Publishing function can flip it to 'published' later.
          let finalStatus = "ready";
          if (vData?.visibility === "Scheduled" || vData?.status === "scheduled") {
            finalStatus = "scheduled";
          }

          transaction.update(vRef, {
            status: finalStatus,
            trustIndex: jobOutputs.trustScore || 0,
            videoRating: jobOutputs.videoRating || 0,
            contentIntent: jobOutputs.contentIntent?.primaryIntent || null,
            factCheckUrl: directFactCheckUrl,
            trustLabel: cred?.trustLabel || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Write localization data to videos/{videoId}/media/localization
          const locRef = vRef.collection("media").doc("localization");
          transaction.set(locRef, {
            subtitles: flatSubtitles,
            dubbedVideos: dubbedMap,
            audioTracks: audioTracksMap,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

          // Write credibility data to videos/{videoId}/media/credibility
          const credRef = vRef.collection("media").doc("credibility");
          transaction.set(credRef, {
            trustScore: jobOutputs.trustScore || cred?.trustScore || 0,
            videoRating: jobOutputs.videoRating || 0,
            trustLabel: cred?.trustLabel || null,
            scoringFactors: cred?.factors || null,
            deductions: cred?.deductions || [],
            contextualFlags: cred?.contextualFlags || [],
            honestyBreakdown: cred?.honestyBreakdown || null,
            harmCapApplied: cred?.harmCapApplied || false,
            harmCapReason: cred?.harmCapReason || null,
            categoryWeightProfile: cred?.categoryWeightProfile || null,
            confidenceNotes: cred?.confidenceNotes || [],
            diagnostics: cred?.diagnostics || [],
            intentToMisleadScore: cred?.intentToMisleadScore || 0,
            hardeningMetadata: cred?.hardeningMetadata || null,
            factCheckStats: cred?.factCheckStats ? {
              totalClaims: cred.factCheckStats.totalClaims,
              correct: cred.factCheckStats.correct,
              incorrect: cred.factCheckStats.incorrect,
              unverifiable: cred.factCheckStats.unverifiable,
              extractionPartial: cred.factCheckStats.extractionPartial || false
            } : null,
            factCheckUrl: directFactCheckUrl,
            transcriptionUrl: directTranscriptUrl,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

          // Write streaming data to videos/{videoId}/media/streaming
          const streamRef = vRef.collection("media").doc("streaming");
          transaction.set(streamRef, {
            chapters: trans?.chapters || [],
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

          // v8.1: Regulatory Audit Logging (DSA/India compliance)
          if (cred?.hardeningMetadata) {
            const auditRef = db().collection("audit_trust_decisions").doc();
            transaction.set(auditRef, {
              videoId: vid,
              jobId: jobId,
              userId: userId,
              hardening: cred.hardeningMetadata,
              finalScore: cred.videoRating,
              category: cred.videoCategory,
              effectiveCategory: cred.effectiveCategory,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              version: "v8.1-hardened-stable"
            });
          }
        }

        return output;
      });

      if (resultOutput) {
        try {
          const { path: latestPath } = await this.analysisRepository.saveAnalysis(jobId, "final_outputs", resultOutput);
          logger.info("[Aggregation] Successfully stored final aggregated output in Storage", { jobId, latestPath });
        } catch (storageErr) {
          logger.error("[Aggregation] Failed to store final aggregated output in Storage", { jobId, err: String(storageErr) });
        }
      }

      return resultOutput;
    } catch (err) {
      logger.error("[Aggregation] Transaction failed", { jobId, err: String(err) });
      return null;
    }
  }

  async getFinalOutput(jobId: string): Promise<AggregatedOutput | null> {
    return this.analysisRepository.loadAnalysis(jobId, "final_outputs");
  }

  /**
   * 🚀 Early Result Propagation (v8.5)
   * Updates the videos collection with partial results (scores, audio)
   * as soon as individual stages complete.
   */
  private async propagateStageResults(
    jobId: string,
    stageName: string,
    userId: string,
    plan: ExecutionPlan
  ): Promise<void> {
    try {
      const jobSnap = await db().collection("video_jobs").doc(jobId).get();
      if (!jobSnap.exists) return;
      const jobData = jobSnap.data() as JobData;
      const jobOutputs = jobData.outputs || {};
      const linkedVideoIds = jobData.linkedVideoIds || [];
      if (jobData.videoId && !linkedVideoIds.includes(jobData.videoId)) {
        linkedVideoIds.push(jobData.videoId);
      }

      if (linkedVideoIds.length === 0) return;

      const updateData: any = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // 1. Handle Credibility Propagation
      if (stageName === "credibility" && jobOutputs.factCheckUrl) {
        let cred: CredibilityResult | null = null;
        try {
          const bucket = admin.storage().bucket();
          const path = jobOutputs.factCheckUrl.replace(`gs://${bucket.name}/`, "");
          const [content] = await bucket.file(path).download();
          cred = JSON.parse(content.toString()) as CredibilityResult;
          
          const directFactCheckUrl = getDownloadUrl(jobOutputs.factCheckUrl);
          updateData.trustIndex = cred.trustScore || 0;
          updateData.videoRating = cred.videoRating || (cred.trustScore ? Number((cred.trustScore / 10).toFixed(1)) : 0);
          updateData.trustLabel = cred.trustLabel || "Low Reliability";
          updateData.factCheckUrl = directFactCheckUrl;
          updateData.summary = cred.summary || "";
          updateData.viewerNote = cred.viewerNote || "";
          
          updateData["media.factCheckUrl"] = directFactCheckUrl;
          
          // Full Epistemic Breakdown (v8.0+)
          updateData.scoringFactors = cred.factors || null;
          updateData.deductions = cred.deductions || [];
          updateData.contextualFlags = cred.contextualFlags || [];
          updateData.honestyBreakdown = cred.honestyBreakdown || null;
          updateData.harmCapApplied = cred.harmCapApplied || false;
          updateData.harmCapReason = cred.harmCapReason || null;
          updateData.videoCategory = cred.videoCategory || null;
          updateData.categoryWeightProfile = cred.categoryWeightProfile || null;
          
          // v8.1: Hardened Trust
          updateData.hardeningMetadata = cred.hardeningMetadata || null;
          updateData.intentToMisleadScore = cred.intentToMisleadScore || 0;
          
          if (cred.factCheckStats) {
            updateData.factCheckStats = {
              totalClaims: cred.factCheckStats.totalClaims,
              correct: cred.factCheckStats.correct,
              incorrect: cred.factCheckStats.incorrect,
              unverifiable: cred.factCheckStats.unverifiable,
              extractionPartial: cred.factCheckStats.extractionPartial || false
            };
          }
          
          logger.info("[Aggregation] Early propagation: Credibility scores", { jobId, videoCount: linkedVideoIds.length });
        } catch (err) {
          logger.error("[Aggregation] Early propagation failed: Credibility", { jobId, err: String(err) });
        }
      }

      // 2. Handle Dubbing/Localization Propagation
      if (stageName.startsWith("dubbing") || stageName.startsWith("translating")) {
        // We'll update the dubbedVideos and subtitles if they are ready in jobOutputs
        if (jobOutputs.subtitles) {
          const flatSubtitles: Record<string, string> = {};
          const subtitlesMap: Record<string, any> = {};
          for (const [lang, data] of Object.entries(jobOutputs.subtitles) as [string, any][]) {
            const url = data.vttPath || data.srtPath || data.url || data.subtitleUrl;
            if (url) {
              const directUrl = getDownloadUrl(url);
              flatSubtitles[lang] = directUrl;
              subtitlesMap[lang] = {
                ...data,
                url: directUrl,
              };
            }
          }
          updateData.subtitles = subtitlesMap;
          updateData["media.subtitles"] = flatSubtitles;
        }

        if (jobOutputs.dubbed) {
          const audioTracks: Record<string, string> = {};
          const dubbedMap: Record<string, any> = {};
          for (const [lang, data] of Object.entries(jobOutputs.dubbed) as [string, any][]) {
            if (data.audioUrl) {
              const directAudioUrl = getDownloadUrl(data.audioUrl);
              const directVideoUrl = data.videoUrl ? getDownloadUrl(data.videoUrl) : (data.path ? getDownloadUrl(data.path) : "");
              audioTracks[lang] = directAudioUrl;
              dubbedMap[lang] = {
                ...data,
                audioUrl: directAudioUrl,
                path: directVideoUrl || data.path || data.videoUrl,
              };
            }
          }
          updateData.dubbedVideos = dubbedMap;
          updateData.audioTracks = audioTracks;
          updateData["media.audioTracks"] = audioTracks;
        }
        
        logger.info("[Aggregation] Early propagation: Localization artifacts", { jobId, stageName });
      }

      // Perform the update on all linked videos
      const batch = db().batch();
      for (const vid of linkedVideoIds) {
        batch.update(db().collection("videos").doc(vid), updateData);
      }
      await batch.commit();

    } catch (err) {
      logger.error("[Aggregation] Early propagation failed", { jobId, err: String(err) });
    }
  }

  /**
   * ⚖️ v7.2: Metadata Reliability Engine (v7.3: Field-Specific)
   * Compares creator input vs AI truth to score metadata accuracy.
   */
  private calculateMetadataReliability(plan: ExecutionPlan, result: CredibilityResult): any {
    let speakerMatch = 1;
    let languageMatch = 1;
    let formatMatch = 1;

    // 1. Speaker Count Verification
    if (plan.expectedSpeakerCount && plan.expectedSpeakerCount !== "not_sure") {
      const actualCount = result.speakerCount || 1;
      const expected = plan.expectedSpeakerCount;
      if (expected === "1") speakerMatch = actualCount === 1 ? 1 : 0;
      else if (expected === "2-3") speakerMatch = (actualCount >= 2 && actualCount <= 3) ? 1 : 0.5;
      else if (expected === "4+") speakerMatch = actualCount >= 4 ? 1 : 0.5;
    }

    // 2. Language Verification
    if (plan.primaryLanguage) {
      languageMatch = plan.primaryLanguage === result.detectedLanguage ? 1 : 0;
    }

    // 3. Format Verification (Heuristic)
    if (plan.contentFormat) {
      const mode = (result as any).pipelineMode;
      if (plan.contentFormat === "solo" && mode === "solo") formatMatch = 1;
      else if (["interview", "podcast"].includes(plan.contentFormat) && mode === "multi") formatMatch = 1;
      else if (plan.contentFormat === "debate" && mode === "debate") formatMatch = 1;
      else formatMatch = 0.5;
    }

    return {
      speakerAccuracy: speakerMatch,
      languageAccuracy: languageMatch,
      formatAccuracy: formatMatch,
      overall: (speakerMatch + languageMatch + formatMatch) / 3
    };
  }
}

export const aggregationLayer = new AggregationLayer();
