/**
 * 🧮 LAYER 09 — AGGREGATION LAYER
 */

import * as admin from "firebase-admin";
import {
  AggregatedOutput,
  ExecutionPlan,
  JobData,
  CredibilityResult,
} from "../types";
import { DistributionLayer } from "./04-distribution";
import { EdgeLayer } from "./01-edge";
import { logger } from "../utils/logger";
import { reputationService } from "../services/reputationService";
import { SpeakerReputationService } from "../services/speakerReputationService";
import { getAnalysisRepository, AnalysisRepository } from "../services/analysisRepository";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import { notifyUser } from "../../notifications/notifications";

const db = () => admin.firestore();

export function getDownloadUrl(gsOrPath: string, defaultBucket?: string): string {
  if (!gsOrPath) return "";
  if (gsOrPath.startsWith("http://") || gsOrPath.startsWith("https://")) {
    return gsOrPath;
  }
  let bucketName = defaultBucket || "truthworld-1.firebasestorage.app";
  let filePath = gsOrPath;
  if (gsOrPath.startsWith("gs://")) {
    const parts = gsOrPath.replace("gs://", "").split("/");
    bucketName = parts[0];
    filePath = parts.slice(1).join("/");
  }
  filePath = filePath.replace(/^\/+/, "");
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
    const dedupEventId = eventId || `stage_${stageName}_${jobId}`;
    const status = await this.distribution.checkAndMarkEventId(dedupEventId, jobId);
    if (status === "COMPLETED" || status === "PROCESSING") {
      return this.getFinalOutput(jobId);
    }

    logger.info("[Aggregation] Stage completed, evaluating truth table", { jobId, stageName });

    // Ensure the stage is marked as completed (or skipped if not enabled) in the canonical ledger
    const stageStatus = (stageName === "dubbing" && !executionPlan.generateDubbing)
      ? "skipped"
      : "completed";

    await EdgeLayer.updateStageSync(jobId, stageName, {
      status: stageStatus,
      progress: 100,
      completedAt: Date.now(),
    });

    // 🕊 Truth Table Check: Are all required stages done?
    const ready = await this.checkAllStagesReady(jobId, executionPlan);
    
    // 🚀 Early Propagation: Propagate partial results (scores, audio)
    // even if the job isn't terminal so the UI can show progress and results in real-time.
    await this.propagateStageResults(jobId, stageName, userId, executionPlan);

    if (!ready) {
      logger.info("[Aggregation] Job not yet terminal — waiting for other stages", { jobId, stageName });
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
  public async checkAllStagesReady(jobId: string, plan: ExecutionPlan): Promise<boolean> {
    const job = await db().collection("video_jobs").doc(jobId).get();
    if (!job.exists) return false;
    const data = job.data() as JobData;
    const stages = (data.stages || {}) as any;
    
    const isDone = (s: any) => s?.status === "completed" || s?.status === "skipped" || s?.status === "failed";

    // 1. Transcription is ALWAYS required
    const transcriptionDone = isDone(stages.transcription);

    // 1.5. Copyright check is required (if configured in stages)
    const copyrightDone = stages.copyright ? isDone(stages.copyright) : true;

    // 2. TruthEngine (Path 1) is required if enabled
    const truthEngineRequired = !!(plan.enablePath1 || plan.enableTruthEngine);
    const truthEngineDone = !truthEngineRequired || isDone(stages.credibility);

    // 3. ReachEngine (Path 2) is required if enabled
    const reachEngineRequired = !!(plan.enablePath2 || plan.enableReachEngine);
    let reachEngineDone = true;
    
    if (reachEngineRequired) {
      // Must have the base 'dubbing' stage marked as completed or skipped
      reachEngineDone = isDone(stages.dubbing);
      
      // Also verify all individual language stages if they exist or were requested
      const sourceLang = normalizeLanguageCode(plan.primaryLanguage || "en");
      const targetLangs = (plan.languages || []).filter(l => normalizeLanguageCode(l) !== sourceLang);
      for (const lang of targetLangs) {
        const normLang = normalizeLanguageCode(lang);
        const transStage = stages[`translating_${normLang}`] || stages[`translating_${lang}`];
        
        if (!transStage) {
          reachEngineDone = false;
          break;
        } else if (!isDone(transStage)) {
          // If translation stage has been stuck in 'running' for > 3 minutes, treat it as auto-advanced
          if (transStage.status === "running" && transStage.startedAt && Date.now() - transStage.startedAt > 3 * 60 * 1000) {
            logger.warn("[Aggregation] Translation stage stuck in running > 3m — auto-advancing", { jobId, lang, normLang });
          } else {
            reachEngineDone = false;
            break;
          }
        }
        // Dubbing stage is only required if dubbing is explicitly enabled
        if (plan.generateDubbing) {
          const dubStage = stages[`dubbing_${normLang}`] || stages[`dubbing_${lang}`];
          if (!dubStage) {
            reachEngineDone = false;
            break;
          } else if (!isDone(dubStage)) {
            if (dubStage.status === "running" && dubStage.startedAt && Date.now() - dubStage.startedAt > 3 * 60 * 1000) {
              logger.warn("[Aggregation] Dubbing stage stuck in running > 3m — auto-advancing", { jobId, lang, normLang });
            } else {
              reachEngineDone = false;
              break;
            }
          }
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
   * 🚀 Final Completion Transaction with Exponential Backoff Retry
   */
  private async runAggregationTransaction(
    jobId: string,
    userId: string,
    plan: ExecutionPlan,
    triggerStage: string
  ): Promise<AggregatedOutput | null> {
    // 🛡 1. Check if already completed before doing any work
    const earlyCheck = await db().collection("video_jobs").doc(jobId).get();
    if (earlyCheck.exists && (earlyCheck.data() as JobData)?.status === "completed") {
      logger.info("[Aggregation] Job already marked completed — returning final output", { jobId });
      return this.getFinalOutput(jobId);
    }

    // 🚀 2. Pre-fetch heavy GCS credibility result OUTSIDE the transaction
    let preloadedCred: CredibilityResult | null = null;
    const initialOutputs = (earlyCheck.data() as JobData)?.outputs || {};
    if (initialOutputs.factCheckUrl && typeof initialOutputs.factCheckUrl === "string") {
      try {
        const bucket = admin.storage().bucket();
        const path = initialOutputs.factCheckUrl.replace(`gs://${bucket.name}/`, "");
        const [content] = await bucket.file(path).download();
        preloadedCred = JSON.parse(content.toString()) as CredibilityResult;
        logger.info("[Aggregation] Pre-fetched credibility report from Storage prior to transaction", { jobId });
      } catch (err) {
        logger.warn("[Aggregation] Non-fatal pre-fetch warning for credibility report", { jobId, err: String(err) });
      }
    }

    // 🛡 3. Execute atomic transaction with retry for Firestore contention
    let resultOutput: AggregatedOutput | null = null;
    let lastError: any = null;

    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        resultOutput = await this.executeAtomicAggregation(jobId, userId, plan, triggerStage, preloadedCred);
        break;
      } catch (err: any) {
        lastError = err;
        const errMsg = String(err?.message || err);
        const isContention = err?.code === 10 || /contention|aborted|unavailable|resource_exhausted/i.test(errMsg);
        if (isContention && attempt < 3) {
          const backoff = 100 * Math.pow(2, attempt) + Math.floor(Math.random() * 50);
          logger.warn(`[Aggregation] Transaction contention on attempt ${attempt}/3 — retrying in ${backoff}ms`, { jobId });
          await new Promise((r) => setTimeout(r, backoff));
        } else {
          logger.error("[Aggregation] Transaction failed on attempt", { jobId, attempt, err: errMsg });
          break;
        }
      }
    }

    if (!resultOutput && lastError) {
      logger.error("[Aggregation] Permanent transaction failure", { jobId, err: String(lastError) });
      // Fallback check: Did another concurrent worker successfully complete it?
      const checkDoc = await db().collection("video_jobs").doc(jobId).get();
      if (checkDoc.exists && (checkDoc.data() as JobData)?.status === "completed") {
        return this.getFinalOutput(jobId);
      }
      return null;
    }

    // 🚀 4. Post-Transaction Execution (Decoupled from Firestore transaction locks)
    if (resultOutput) {
      await this.runPostTransactionSideEffects(jobId, userId, plan, resultOutput, preloadedCred);
    }

    return resultOutput;
  }

  /**
   * 🔒 Atomic Firestore Transaction Execution
   * Contains strictly transactional reads and writes (no nested transactions, no GCS downloads).
   */
  private async executeAtomicAggregation(
    jobId: string,
    userId: string,
    plan: ExecutionPlan,
    triggerStage: string,
    preloadedCred: CredibilityResult | null
  ): Promise<AggregatedOutput | null> {
    return db().runTransaction(async (transaction) => {
      const jobRef = db().collection("video_jobs").doc(jobId);
      const jobSnap = await transaction.get(jobRef);
      const jobData = jobSnap.data() as JobData;

      // 🛡 Idempotent Guard: Prevent duplicate terminal writes
      if (jobData?.status === "completed") {
        logger.info("[Aggregation] Job already completed within transaction — exiting", { jobId });
        return null;
      }

      const transSnap = await transaction.get(db().collection("transcripts").doc(jobId));

      // Fetch job outputs document
      const jobOutputsRef = db().collection("job_outputs").doc(jobId);
      const jobOutputsSnap = await transaction.get(jobOutputsRef);
      const jobOutputsData = jobOutputsSnap.exists ? jobOutputsSnap.data() : {};

      // Localization artifacts (Dubbing & Subtitles) per language
      const sourceLang = jobData?.sourceLanguage || "en";
      const uniqueLangs = Array.from(new Set([
        ...(plan.languages || []),
        ...((plan.languages || []).map(normalizeLanguageCode)),
        sourceLang,
        normalizeLanguageCode(sourceLang)
      ])).filter(Boolean);

      const [dubbingSnaps, subtitleSnaps] = await Promise.all([
        Promise.all(uniqueLangs.map(lang => transaction.get(db().collection("dubbing_results").doc(`${jobId}_${lang}`)))),
        Promise.all(uniqueLangs.map(lang => transaction.get(db().collection("subtitle_results").doc(`${jobId}_${lang}`))))
      ]);

      // Read linked videos upfront (Firestore transaction rule: all reads before all writes)
      const linkedVideoIds = jobData?.linkedVideoIds || [];
      if (jobData?.videoId && !linkedVideoIds.includes(jobData.videoId)) {
        linkedVideoIds.push(jobData.videoId);
      }
      const linkedVideoSnaps = await Promise.all(
        linkedVideoIds.map(vid => transaction.get(db().collection("videos").doc(vid)))
      );
      const linkedVideoDataMap = new Map<string, FirebaseFirestore.DocumentData | undefined>();
      linkedVideoSnaps.forEach((vSnap, idx) => {
        if (vSnap.exists) {
          linkedVideoDataMap.set(linkedVideoIds[idx], vSnap.data());
        }
      });

      const trans = transSnap.exists ? transSnap.data() as any : null;
      const jobOutputs = {
        ...(jobData?.outputs || {}),
        ...(jobOutputsData || {})
      };

      const cred: CredibilityResult | null = preloadedCred;

      // Subtitles normalization
      const subtitlesMap: Record<string, any> = {};
      const flatSubtitles: Record<string, string> = {};

      if (jobData?.outputs?.subtitles) {
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

      subtitleSnaps.forEach(snap => {
        if (snap.exists) {
          const data = snap.data();
          const lang = data?.language;
          const url = data?.subtitleUrl;
          if (lang && url) {
            const directUrl = getDownloadUrl(url);
            subtitlesMap[lang] = {
              ...data,
              url: directUrl,
              srtPath: data?.srtPath ? getDownloadUrl(data.srtPath) : directUrl,
              vttPath: data?.vttPath ? getDownloadUrl(data.vttPath) : directUrl.replace(/\.srt$/, ".vtt"),
              jsonPath: data?.jsonPath ? getDownloadUrl(data.jsonPath) : directUrl.replace(/\.srt$/, ".json"),
              format: data?.subtitleFormat || "srt",
              language: lang,
              updatedAt: data?.createdAt || Date.now(),
            };
            flatSubtitles[lang] = directUrl;
          }
        }
      });

      // Dubbing normalization
      const dubbedMap: Record<string, any> = {};
      if (jobData?.outputs?.dubbed) {
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
      const audioTracksMap: Record<string, string> = {};

      dubbingSnaps.forEach(snap => {
        if (snap.exists) {
          const data = snap.data();
          if (data?.videoUrl) {
            const directVideoUrl = getDownloadUrl(data.videoUrl);
            const directAudioUrl = getDownloadUrl(data.audioUrl);
            dubbedMap[data.language] = {
              path: directVideoUrl,
              audioUrl: directAudioUrl,
              createdAt: data.createdAt || Date.now(),
            };
          }
          if (data?.audioUrl) {
            audioTracksMap[data.language] = getDownloadUrl(data.audioUrl);
          }
        }
      });

      const directFactCheckUrl = jobOutputs.factCheckUrl ? getDownloadUrl(jobOutputs.factCheckUrl) : "";
      const bucket = admin.storage().bucket();
      const transcriptUrl = `gs://${bucket.name}/transcripts/${jobId}/full.json`;
      const directTranscriptUrl = getDownloadUrl(transcriptUrl);

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

      const output: AggregatedOutput = {
        jobId,
        userId,
        videoUrl: jobData?.videoUrl || "",
        trustScore: jobOutputs.trustScore || cred?.trustScore || 0,
        trustLabel: jobOutputs.trustLabel || cred?.trustLabel || "Low Reliability",
        confidence: cred?.confidence || 0,
        confidenceTier: cred?.confidenceTier || "low",
        speakerConfidence: trans?.speakerConfidence || 0,
        rating: jobOutputs.trustScore || cred?.trustScore || 0,
        summary: jobOutputs.summary || cred?.summary || "",
        conclusion: (cred?.conclusion || undefined) as any,
        keyThemes: cred?.keyThemes || [],
        chapters: (jobOutputs.chapters || trans?.chapters || []),
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
        checkedClaimsRatio: cred?.factCheckStats?.checkedClaimsRatio || 0,
        isLaunchNews: jobOutputs.isLaunchNews || cred?.isLaunchNews || false,
        launchGrounded: jobOutputs.launchGrounded || cred?.launchGrounded || false,
        speakerMetrics: cred?.speakers || [],
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
        completedAt: now,
        artifacts: {
          subtitles: subtitlesMap,
          dubbing: dubbedMap,
          audio: audioTracksMap,
        },
      };

      // ─── 1. Update Video Job Document ─────────────────────────────────────
      transaction.update(jobRef, {
        status: "completed",
        progress: 100,
        completedAt: now,
        actualCompletedAt: now,
        stageDurations,
        completionSource: triggerStage,
        updatedAt: now,
        version: admin.firestore.FieldValue.increment(1),
        processedLocalizationVersions: admin.firestore.FieldValue.arrayUnion(
          (plan.languages ?? []).sort().join(",")
        ),
        outputs: {
          trustScore: null,
          trustLabel: null,
          rating: 0,
          contentIntent: cred?.contentIntent ? {
            primaryIntent: cred.contentIntent.primaryIntent,
            confidence: cred.contentIntent.confidence,
            subjectiveRatio: cred.contentIntent.subjectiveRatio,
            promotionalSignals: cred.contentIntent.promotionalSignals,
          } : null,
          summary: cred?.summary || "",
          conclusion: cred?.conclusion || null,
          viewerNote: cred?.viewerNote || "",
          checkedClaimsRatio: cred?.factCheckStats?.checkedClaimsRatio || 0,
          factCheckUrl: jobOutputs.factCheckUrl || null,
          credibilityVerified: !!cred,
        }
      });

      // ─── 2. Write Job Outputs Document ────────────────────────────────────
      transaction.set(jobOutputsRef, {
        subtitles: subtitlesMap,
        dubbed: dubbedMap,
        audioTracks: audioTracksMap,
        updatedAt: now,
      }, { merge: true });

      // ─── 3. Propagate to Linked Video Documents ────────────────────────────
      for (const vid of linkedVideoIds) {
        const vRef = db().collection("videos").doc(vid);
        const vData = linkedVideoDataMap.get(vid);

        // 🛡 Hardened Lifecycle Status Resolution
        // Strict Priority: Rejection > Moderation/Copyright Holds > Scheduled > Draft > Published
        let finalStatus = "published";
        if (vData?.status === "rejected" || vData?.moderation?.status === "rejected") {
          finalStatus = "rejected";
        } else if (
          vData?.status === "pending_review" ||
          vData?.status === "held" ||
          vData?.moderation?.status === "manual_review" ||
          vData?.moderation?.status === "held" ||
          vData?.moderation?.status === "pending_review" ||
          vData?.copyrightHold === true
        ) {
          finalStatus = vData.status && vData.status !== "processing" && vData.status !== "uploading"
            ? vData.status
            : "pending_review";
        } else if (vData?.visibility === "Scheduled" || vData?.status === "scheduled" || vData?.targetStatus === "scheduled") {
          finalStatus = "scheduled";
        } else if (vData?.status === "draft" || vData?.targetStatus === "draft") {
          finalStatus = "draft";
        } else if (vData?.status === "published" || vData?.targetStatus === "published" || vData?.isPublished === true || vData?.aiFeatures?.pipelineStage === "published") {
          finalStatus = "published";
        } else {
          finalStatus = vData?.status && vData.status !== "processing" && vData.status !== "uploading" ? vData.status : "published";
        }

        // Clean Summary Resolution
        const isInvalidSummary = (s?: string) => !s || /moderation timed out|video approved pending|async review|moderation could not complete|verification in progress|held safely in review queue|video held for admin|admin manual review|gemini ai bypassed|infrastructure timeout|synthesis unavailable|analysis unavailable|quota saturated|quota_backpressure|timeout_passthrough|retry_exhausted_passthrough|summary unavailable|peak load|strategic analysis unavailable/i.test(s);
        
        const isTranscriptSnippet = (s?: string) => {
          if (!s || !trans?.text) return false;
          const clean = s.replace(/\.{3}$/, "").trim();
          return clean.length > 20 && trans.text.trim().startsWith(clean);
        };

        let resolvedSummary = "";
        if (vData && !isInvalidSummary(vData.moderation?.summary) && !isTranscriptSnippet(vData.moderation?.summary)) {
          resolvedSummary = vData.moderation.summary || "";
        } else if (vData && !isInvalidSummary(vData.moderationSummary) && !isTranscriptSnippet(vData.moderationSummary)) {
          resolvedSummary = vData.moderationSummary || "";
        } else if ((jobData as any)?.stages?.moderation?.summary && !isInvalidSummary((jobData as any).stages.moderation.summary) && !isTranscriptSnippet((jobData as any).stages.moderation.summary)) {
          resolvedSummary = (jobData as any).stages.moderation.summary || "";
        } else if (!isInvalidSummary((jobData as any)?.gatewayDecision?.summary) && !isTranscriptSnippet((jobData as any)?.gatewayDecision?.summary)) {
          resolvedSummary = String((jobData as any)?.gatewayDecision?.summary || "");
        } else if (!isInvalidSummary(jobOutputs.summary) && !isTranscriptSnippet(jobOutputs.summary)) {
          resolvedSummary = jobOutputs.summary || "";
        } else if (cred && !isInvalidSummary(cred.summary) && !isTranscriptSnippet(cred.summary)) {
          resolvedSummary = cred.summary || "";
        } else if (vData && !isInvalidSummary(vData.summary) && !isTranscriptSnippet(vData.summary)) {
          resolvedSummary = vData.summary || "";
        }

        // 🛡 Chapter Resolution: Creator Custom Chapters ALWAYS Take Precedence Over AI autoChapters
        const rawResolvedChapters = (vData?.customChapters && Array.isArray(vData.customChapters) && vData.customChapters.length > 0)
          ? vData.customChapters
          : ((vData?.chapters && Array.isArray(vData.chapters) && vData.chapters.length > 0 && vData.hasCustomChapters === true)
              ? vData.chapters
              : ((vData?.autoChapters && Array.isArray(vData.autoChapters) && vData.autoChapters.length > 0)
                  ? vData.autoChapters
                  : ((vData?.chapters && Array.isArray(vData.chapters) && vData.chapters.length > 0)
                      ? vData.chapters
                      : (((jobData as any)?.gatewayDecision?.autoChapters && (jobData as any).gatewayDecision.autoChapters.length > 0)
                          ? (jobData as any).gatewayDecision.autoChapters
                          : (trans?.chapters || [])))));

        // Preserve authentic chapter thumbnails: never wipe dedicated thumbnails with main video cover or undefined
        const candidateChaptersWithThumbs = [
          ...(Array.isArray(vData?.chapters) ? vData.chapters : []),
          ...(Array.isArray(vData?.autoChapters) ? vData.autoChapters : []),
          ...(Array.isArray(trans?.chapters) ? trans.chapters : []),
        ];
        const mainCoverThumb = vData?.thumbnailUrl || "";
        const resolvedChapters = (rawResolvedChapters || []).map((ch: any, idx: number) => {
          let thumb = ch.thumbnailUrl;
          if (!thumb || thumb === mainCoverThumb) {
            const chStart = Number(ch.startTimeMs ?? ch.startMs ?? 0);
            const found = candidateChaptersWithThumbs.find((e: any, eIdx: number) =>
              (eIdx === idx || Math.abs(Number(e.startTimeMs ?? e.startMs ?? 0) - chStart) < 1500) &&
              e.thumbnailUrl && typeof e.thumbnailUrl === "string" && e.thumbnailUrl !== mainCoverThumb && e.thumbnailUrl.startsWith("http")
            );
            if (found && found.thumbnailUrl) {
              thumb = found.thumbnailUrl;
            }
          }
          return {
            ...ch,
            thumbnailUrl: thumb || undefined,
          };
        });

        // 🛡 Deep-Merge Media: Strictly protect adaptiveResolutions, variants, hlsUrl, storyboardUrl
        const existingMedia = (vData?.media && typeof vData.media === "object") ? vData.media : {};
        const mergedMedia = {
          ...existingMedia,
          subtitles: flatSubtitles,
          audioTracks: audioTracksMap,
          dubbedVideos: dubbedMap,
          factCheckUrl: directFactCheckUrl,
          transcriptionUrl: directTranscriptUrl,
        };

        transaction.update(vRef, {
          status: finalStatus,
          summary: resolvedSummary,
          moderationSummary: resolvedSummary,
          autoChapters: resolvedChapters,
          chapters: resolvedChapters,
          trustIndex: null,
          contentIntent: jobOutputs.contentIntent?.primaryIntent || null,
          factCheckUrl: directFactCheckUrl,
          transcriptionUrl: directTranscriptUrl,
          subtitles: flatSubtitles,
          audioTracks: audioTracksMap,
          dubbedVideos: dubbedMap,
          media: mergedMedia,
          trustLabel: null,
          isVerified: !!cred,
          isFactChecked: !!(cred && ((cred.claims && cred.claims.length > 0) || directFactCheckUrl)),
          ...(vData?.factCheckReviewMode ? { factCheckReviewMode: vData.factCheckReviewMode } : {}),
          ...(vData?.isFactCheckApproved !== undefined ? { isFactCheckApproved: vData.isFactCheckApproved } : {}),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Write localization subcollection
        const locRef = vRef.collection("media").doc("localization");
        transaction.set(locRef, {
          subtitles: flatSubtitles,
          dubbedVideos: dubbedMap,
          audioTracks: audioTracksMap,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Write credibility subcollection
        const credRef = vRef.collection("media").doc("credibility");
        transaction.set(credRef, {
          trustScore: null,
          trustLabel: null,
          scoringFactors: null,
          deductions: [],
          contextualFlags: cred?.contextualFlags || [],
          harmCapApplied: false,
          harmCapReason: null,
          categoryWeightProfile: null,
          confidenceNotes: cred?.confidenceNotes || [],
          diagnostics: cred?.diagnostics || [],
          intentToMisleadScore: 0,
          hardeningMetadata: null,
          factCheckStats: cred?.factCheckStats ? {
            totalClaims: cred.factCheckStats.totalClaims,
            correct: cred.factCheckStats.correct,
            incorrect: cred.factCheckStats.incorrect,
            unverifiable: cred.factCheckStats.unverifiable,
            extractionPartial: cred.factCheckStats.extractionPartial || false
          } : null,
          factCheckUrl: directFactCheckUrl,
          transcriptionUrl: directTranscriptUrl,
          credibilityVerified: !!cred,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Write streaming subcollection
        const streamRef = vRef.collection("media").doc("streaming");
        transaction.set(streamRef, {
          chapters: resolvedChapters || trans?.chapters || [],
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Regulatory Audit Logging
        if (cred) {
          const auditRef = db().collection("audit_trust_decisions").doc();
          transaction.set(auditRef, {
            videoId: vid,
            jobId: jobId,
            userId: userId,
            hardening: null,
            finalScore: null,
            category: cred.videoCategory,
            effectiveCategory: cred.effectiveCategory,
            credibilityVerified: true,
            claimsAnalyzed: cred.factCheckStats?.totalClaims || 0,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            version: "v12.0-no-scoring"
          });
        }
      }

      return output;
    });
  }

  /**
   * 🚀 Post-Transaction Side Effects Execution
   * Executes outside the Firestore transaction to prevent lock contention & timeouts.
   */
  private async runPostTransactionSideEffects(
    jobId: string,
    userId: string,
    plan: ExecutionPlan,
    resultOutput: AggregatedOutput,
    cred: CredibilityResult | null
  ): Promise<void> {
    const now = Date.now();

    // 1. Mark rendering & finalizing completed in edge stage sync
    await EdgeLayer.updateStageSync(jobId, "rendering", { 
      status: "completed", progress: 100, completedAt: now 
    }).catch(err => logger.warn("[Aggregation] Non-fatal rendering stage sync warning", { jobId, err: String(err) }));

    await EdgeLayer.updateStageSync(jobId, "finalizing", { 
      status: "completed", progress: 100, completedAt: now 
    }).catch(err => logger.warn("[Aggregation] Non-fatal finalizing stage sync warning", { jobId, err: String(err) }));

    // 2. Speaker reputation updates
    if (cred?.speakers && cred.speakerIdentities) {
      const identities = cred.speakerIdentities;
      for (const metrics of cred.speakers) {
        const idInfo = (identities as any)[metrics.speakerId];
        if (idInfo?.id) {
          await this.speakerReputation.updateReputation(jobId, idInfo.id, metrics, cred.factCheckStats)
            .catch(err => logger.warn("[Aggregation] Non-fatal speaker reputation error", { jobId, err: String(err) }));
        }
      }
    }

    // 3. Creator reputation updates
    const jobSnap = await db().collection("video_jobs").doc(jobId).get().catch(() => null);
    const jobData = jobSnap?.exists ? jobSnap.data() as JobData : null;
    if (cred && jobData?.channelId) {
      try {
        const metadataScore = this.calculateMetadataReliability(jobData.executionPlan || plan, cred);
        await reputationService.updateReputation(userId, jobData.channelId, {
          ...cred,
          metadataReliability: metadataScore
        } as any);
      } catch (repErr) {
        logger.warn("[Aggregation] Non-fatal creator reputation error", { jobId, userId, err: String(repErr) });
      }
    }

    // 4. Persist final aggregated output in Storage with transient retry
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const { path: latestPath } = await this.analysisRepository.saveAnalysis(jobId, "final_outputs", resultOutput);
        logger.info("[Aggregation] Successfully stored final aggregated output in Storage", { jobId, latestPath });
        break;
      } catch (storageErr) {
        if (attempt === 3) {
          logger.error("[Aggregation] Failed to store final aggregated output in Storage after 3 attempts", { jobId, err: String(storageErr) });
        } else {
          await new Promise(r => setTimeout(r, 200 * attempt));
        }
      }
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
  public async propagateStageResults(
    jobId: string,
    stageName: string,
    userId: string,
    _plan: ExecutionPlan
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
          updateData.trustIndex = null;
          updateData.trustLabel = null;
          updateData.factCheckUrl = directFactCheckUrl;
          updateData.summary = cred.summary || "";
          updateData.viewerNote = cred.viewerNote || "";
          updateData.credibilityVerified = true;
          updateData["media.factCheckUrl"] = directFactCheckUrl;
          
          updateData.scoringFactors = null;
          updateData.deductions = [];
          updateData.contextualFlags = cred.contextualFlags || [];
          updateData.harmCapApplied = false;
          updateData.harmCapReason = null;
          updateData.videoCategory = cred.videoCategory || null;
          updateData.categoryWeightProfile = null;
          
          updateData.hardeningMetadata = null;
          updateData.intentToMisleadScore = 0;
          
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

          // Dispatch Fact-Checking notification atomically guarded
          const notifFlag = (jobData as any)?.factCheckNotified;
          if (!notifFlag) {
            await db().collection("video_jobs").doc(jobId).set({ factCheckNotified: true }, { merge: true }).catch(() => {});
            for (const vid of linkedVideoIds) {
              try {
                const vSnap = await db().collection("videos").doc(vid).get();
                if (vSnap.exists) {
                  const vData = vSnap.data();
                  const reviewMode = vData?.factCheckReviewMode || vData?.aiFeatures?.factCheckReviewMode || "open_to_users";
                  const isReviewFirst = reviewMode === "first_to_creator";
                  const recipientId = vData?.userId || vData?.ownerId || userId;
                  const channelId = vData?.channelId || "";
                  const videoTitle = vData?.title || "Your video";

                  if (recipientId) {
                    const notifTitle = isReviewFirst
                      ? "Fact-Check Ready for Review"
                      : "Fact-Check Completed";
                    const notifMsg = isReviewFirst
                      ? `Fact-checking analysis is complete for "${videoTitle}". Review the results now to approve them for viewers.`
                      : `Fact-checking analysis is complete for "${videoTitle}". Verification results are now visible to viewers.`;

                    await notifyUser({
                      userId: recipientId,
                      type: "fact_check_ready" as any,
                      severity: isReviewFirst ? "info" as any : "success" as any,
                      title: notifTitle,
                      message: notifMsg,
                      actionUrl: `/studio`,
                      targetApp: "studio",
                      metadata: {
                        targetApp: "studio",
                        videoId: vid,
                        channelId,
                        videoTitle,
                        thumbnailUrl: vData?.thumbnailUrl || vData?.customThumbnailUrl || "",
                        factCheckReviewMode: reviewMode,
                        isFactCheckApproved: !isReviewFirst,
                        approved: !isReviewFirst,
                      },
                    });
                  }
                }
              } catch (notifErr) {
                logger.warn("[Aggregation] Failed to dispatch fact-check notification", { vid, err: String(notifErr) });
              }
            }
          }
        } catch (err) {
          logger.error("[Aggregation] Early propagation failed: Credibility", { jobId, err: String(err) });
        }
      }

      // 2. Handle Dubbing/Localization Propagation
      if (stageName.startsWith("dubbing") || stageName.startsWith("translating")) {
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

        if (jobOutputs.dubbed || jobOutputs.audioTracks) {
          const audioTracks: Record<string, string> = {};
          if (jobOutputs.audioTracks) {
            for (const [lang, url] of Object.entries(jobOutputs.audioTracks) as [string, any][]) {
              if (url) {
                audioTracks[lang] = getDownloadUrl(String(url));
              }
            }
          }
          const dubbedMap: Record<string, any> = {};
          if (jobOutputs.dubbed) {
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
          }
          if (Object.keys(dubbedMap).length > 0) {
            updateData.dubbedVideos = dubbedMap;
            updateData["media.dubbedVideos"] = dubbedMap;
          }
          if (Object.keys(audioTracks).length > 0) {
            updateData.audioTracks = audioTracks;
            updateData["media.audioTracks"] = audioTracks;
          }
        }
        
        logger.info("[Aggregation] Early propagation: Localization artifacts", { jobId, stageName });
      }

      // Only perform batch update if meaningful fields were added
      if (Object.keys(updateData).length > 1) {
        const batch = db().batch();
        for (const vid of linkedVideoIds) {
          batch.update(db().collection("videos").doc(vid), updateData);
        }
        await batch.commit();
      }

    } catch (err) {
      logger.error("[Aggregation] Early propagation failed", { jobId, err: String(err) });
    }
  }

  /**
   * ⚖️ v7.2: Metadata Reliability Engine (v7.3: Field-Specific)
   * Compares creator input vs AI truth to score metadata accuracy.
   */
  public calculateMetadataReliability(plan: ExecutionPlan, result: CredibilityResult): any {
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
