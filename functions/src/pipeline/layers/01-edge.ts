/**
 * ⚡ LAYER 01 — EDGE LAYER (REFACTORED — NO REDIS)
 *
 * Sub-second user-facing responses. Returns jobId instantly; all heavy work is async.
 */

import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";
import {
  EdgeResponse,
  ProgressiveStatus,
  StageStatus,
  UserConfig,
  AggregatedOutput,
  JobData,
  ExecutionPlan,
} from "../types";
import { InputLayer } from "./02-input";
import { DistributionLayer } from "./04-distribution";
import { costEngine } from "../services/cost-engine";
import { pipelineEstimator } from "../services/pipeline-estimator";
import { logger } from "../utils/logger";
import { getAnalysisRepository, AnalysisRepository } from "../services/analysisRepository";
import { normalizeLanguageCode } from "../../shared/language-normalizer";

const db = () => admin.firestore();

/** Number of Firestore shards for video_jobs — prevents write hotspot */
const SHARD_COUNT = 20;

/** Initial static weights for fixed stages */
const BASE_STAGE_WEIGHTS: Record<string, number> = {
  upload: 0.05,
  validation: 0.05,
  queue: 0.05,
  transcription: 0.20,
  credibility: 0.15,
  rendering: 0.15,
  finalizing: 0.10,
};

const LOCALIZATION_TOTAL_WEIGHT = 0.25;

export class EdgeLayer {
  private readonly inputLayer: InputLayer;
  private readonly distribution: DistributionLayer;
  private readonly analysisRepository: AnalysisRepository;

  constructor(analysisRepository?: AnalysisRepository) {
    this.inputLayer = new InputLayer();
    this.distribution = new DistributionLayer();
    this.analysisRepository = analysisRepository || getAnalysisRepository();
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /**
   * Accept a video submission. Returns a jobId in < 100 ms.
   */
  async submitVideo(
    userId: string,
    videoUrl: string,
    fileName: string,
    userConfig: Partial<UserConfig>
  ): Promise<EdgeResponse> {
    const t0 = Date.now();

    try {
      // ── 0. Security Validations ─────────────────────────────────────────────
      if (!fileName || !/^[a-zA-Z0-9._\-\s]{1,255}$/.test(fileName)) {
        return this.rejected("Invalid file name format");
      }

      const isValidGCSVideoUrl = (url: string): boolean => {
        if (!url || typeof url !== "string") return false;
        const normalized = url.trim();
        const allowedPrefixes = [
          "gs://truthworld-1.firebasestorage.app/videos/",
          "gs://truthworld-1.appspot.com/videos/",
          "https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/",
          "https://storage.googleapis.com/truthworld-1.appspot.com/videos/",
          "https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/videos",
          "https://firebasestorage.googleapis.com/v0/b/truthworld-1.appspot.com/o/videos",
        ];
        const hasPrefix = allowedPrefixes.some((prefix) => normalized.startsWith(prefix));
        return hasPrefix && !normalized.includes("..") && !normalized.toLowerCase().includes("%2e");
      };

      if (!isValidGCSVideoUrl(videoUrl)) {
        return this.rejected("Invalid video URL. Must be a valid GCS path in the TruthWorld video bucket.");
      }

      // ── 1. Validate ──────────────────────────────────────────────────────────
      const config = this.inputLayer.normalizeConfig(userId, userConfig);
      const validation = this.inputLayer.validateConfig(config);

      if (!validation.valid) {
        return this.rejected(`Invalid config: ${validation.errors.join(", ")}`);
      }

      // 🔒 Language Policy Enforcement: TruthWorld is strictly English-only at this phase
      if (userConfig.primaryLanguage && normalizeLanguageCode(userConfig.primaryLanguage) !== "en") {
        return this.rejected("Truthworld currently only supports English content. Non-English videos cannot be accepted at this stage.");
      }

      // ── 2. Pre-flight cost estimate ───────────────────────────────────────────
      const executionPlan = this.inputLayer.createExecutionPlan("__pre__", config);
      const estimatedCost = this.inputLayer.estimateJobCost(executionPlan);

      // ── 3. Quota gate (Optional/Simplified for new model) ────────────────────
      const estimatedMinutes = 10;
      
      // ── 4. Generate IDs ─────────────────────────────────────────────────────────
      const jobId = `job_${Date.now()}_${uuidv4().substring(0, 8)}`;
      const eventId = uuidv4();
      const shard = EdgeLayer.shardKey(userId);
      const plan = this.inputLayer.createExecutionPlan(jobId, config);

      // ── 5. Smart ETA Engine ──────────────────────────────────────────────────
      const duration = config.duration ?? 60;
      const eta = pipelineEstimator.estimateTotal(duration, plan);

      const now = Date.now();
      const stages: JobData["stages"] = {
        upload: { status: "completed", progress: 100, startedAt: t0, completedAt: now },
        validation: { status: "completed", progress: 100, startedAt: now, completedAt: now },
        queue: { status: "running", progress: 50, startedAt: now },
        transcription: this.stagePending(),
        credibility: plan.enablePath1 ? this.stagePending() : this.stageSkipped(),
        dubbing: plan.generateDubbing ? this.stagePending() : this.stageSkipped(),
      };

      if (plan.enablePath2 || plan.enableReachEngine) {
        const sourceLang = normalizeLanguageCode(plan.primaryLanguage || "en");
        const targetLanguages = (plan.languages || []).filter(l => normalizeLanguageCode(l) !== sourceLang); 
        for (const lang of targetLanguages) {
          const normLang = normalizeLanguageCode(lang);
          stages[`translating_${normLang}`] = this.stagePending();
          if (lang !== normLang) stages[`translating_${lang}`] = this.stagePending();
          if (plan.generateDubbing) {
            stages[`dubbing_${normLang}`] = this.stagePending();
            if (lang !== normLang) stages[`dubbing_${lang}`] = this.stagePending();
          }
        }
      }

      stages.rendering = this.stagePending();
      stages.finalizing = this.stagePending();
      stages.aggregation = this.stagePending();

      const jobData: JobData = {
        jobId,
        userId,
        videoUrl,
        fileName,
        status: "accepted",
        eventId,
        shard,
        executionPlan: plan,
        config,
        estimatedCostUsd: estimatedCost,
        stages,
        createdAt: now,
        updatedAt: now,
        version: 1,
        etaSeconds: eta.seconds,
        etaMin: eta.minSeconds,
        etaMax: eta.maxSeconds,
        etaMode: eta.mode,
        estimatedCompletionAt: now + (eta.seconds * 1000),
      };

      // ── 6. Firestore write ────────────────
      this.persistJobAsync(shard, jobId, jobData);

      // ── 6.5 Record job acceptance ─────────────────────────
      costEngine.recordJobAccepted(userId, config.channelType, estimatedMinutes).catch((err: any) =>
        logger.error("[Edge] Failed to record job acceptance", { jobId, err })
      );

      // ── 7. Emit event (async) ────────────────────────────────────────────────
      this.distribution
        .publish("video-uploaded", {
          eventId,
          eventType: "video-uploaded",
          jobId,
          userId,
          timestamp: Date.now(),
          data: { videoUrl, fileName, executionPlan: plan },
          retryCount: 0,
          source: "edge-layer",
        })
        .catch((err) => logger.error("[Edge] Pub/Sub emit failed", { jobId, err }));

      return {
        jobId,
        status: "accepted",
        message: "Video accepted for processing",
        estimatedTime: this.estimateSeconds(plan),
        trackingUrl: `/api/status/${jobId}`,
      };
    } catch (error) {
      logger.error("[Edge] Unhandled submit error", { error });
      return this.rejected(
        error instanceof Error ? error.message : "Internal error"
      );
    }
  }

  async getProgressiveStatus(jobId: string): Promise<ProgressiveStatus | null> {
    try {
      const job = await this.loadJob(jobId);
      if (!job) return null;

      const stages = (job.stages ?? {}) as any;
      let overall = 0;

      for (const [stage, weight] of Object.entries(BASE_STAGE_WEIGHTS)) {
        const s = stages[stage];
        if (!s) continue;
        if (s.status === "completed" || s.status === "skipped") overall += weight * 100;
        else if (s.status === "running") overall += weight * (s.progress ?? 50);
      }

      if (job.executionPlan?.enablePath2 || job.executionPlan?.enableReachEngine) {
        const sourceLang = normalizeLanguageCode(job.executionPlan.primaryLanguage || "en");
        const targetLanguages = (job.executionPlan.languages || []).filter(l => normalizeLanguageCode(l) !== sourceLang);
        if (targetLanguages.length > 0) {
          const weightPerLang = LOCALIZATION_TOTAL_WEIGHT / targetLanguages.length;
          const translationWeight = weightPerLang * 0.4;
          const dubbingWeight = weightPerLang * 0.6;

          for (const lang of targetLanguages) {
            const normLang = normalizeLanguageCode(lang);
            const ts = stages[`translating_${normLang}`] || stages[`translating_${lang}`];
            const ds = stages[`dubbing_${normLang}`] || stages[`dubbing_${lang}`];

            if (ts) {
              if (ts.status === "completed" || ts.status === "skipped") overall += translationWeight * 100;
              else if (ts.status === "running") overall += translationWeight * (ts.progress ?? 50);
            }

            if (ds) {
              if (ds.status === "completed" || ds.status === "skipped") overall += dubbingWeight * 100;
              else if (ds.status === "running") overall += dubbingWeight * (ds.progress ?? 50);
            }
          }
        } else {
          overall += LOCALIZATION_TOTAL_WEIGHT * 100; 
        }
      } else {
        overall += LOCALIZATION_TOTAL_WEIGHT * 100;
      }

      let partial: Partial<AggregatedOutput> | undefined;
      if (stages.credibility?.status === "completed") {
        try {
          const d = await this.analysisRepository.loadAnalysis(jobId, "factChecks");
          if (d) {
            partial = {
              rating: d.trustScore ?? 0,
              claims: d.claims?.map((c: any) => ({ claim: c.claim || c.text, status: c.status, severity: c.severity || "low" })) || [],
              fullResultPath: `factChecks/${jobId}/latest.json`,
            };
          }
        } catch (err) {
          logger.error("[Edge] Failed to retrieve partial credibility from storage", { jobId, err: String(err) });
        }
      }

      return {
        jobId,
        overall: Math.round(overall),
        stages: {
          ...stages,
          transcription: stages.transcription ?? this.stagePending(),
          credibility: stages.credibility ?? this.stagePending(),
          dubbing: stages.dubbing ?? this.stagePending(),
          aggregation: stages.aggregation ?? this.stagePending(),
        },
        partialResults: partial,
        etaSeconds: job.etaSeconds,
        etaMin: job.etaMin,
        etaMax: job.etaMax,
        etaMode: job.etaMode,
        estimatedCompletionAt: job.estimatedCompletionAt,
      };
    } catch (error) {
      logger.error("[Edge] Status query failed", { jobId, error });
      return null;
    }
  }

  static async updateStage(jobId: string, stage: string, update: Partial<StageStatus>): Promise<void> {
    setImmediate(async () => {
      try {
        await EdgeLayer.updateStageSync(jobId, stage, update);
      } catch (err) {
        logger.error("[Edge] Async stage update failed", { jobId, stage, err });
      }
    });
  }

  static async updateStageSync(jobId: string, stage: string, update: Partial<StageStatus>): Promise<void> {
    const now = Date.now();
    const fields: Record<string, unknown> = { 
      updatedAt: now,
      version: admin.firestore.FieldValue.increment(1)
    };
    
    for (const [k, v] of Object.entries(update)) {
      fields[`stages.${stage}.${k}`] = v;
    }

    let lastErr: any = null;
    for (let attempt = 1; attempt <= 4; attempt++) {
      try {
        await db().collection("video_jobs").doc(jobId).update(fields);
        return;
      } catch (err) {
        lastErr = err;
        const errMsg = String((err as any)?.message || err);
        const isContention = /contention|aborted|unavailable|resource_exhausted|deadline/i.test(errMsg);
        if (isContention && attempt < 4) {
          // Jittered backoff between 50ms and 300ms to resolve document write collisions
          const backoff = 50 * Math.pow(2, attempt - 1) + Math.floor(Math.random() * 50);
          await new Promise((res) => setTimeout(res, backoff));
          continue;
        }
        logger.error("[Edge] Canonical stage update failed", { jobId, stage, err });
        throw err;
      }
    }
    if (lastErr) {
      throw lastErr;
    }
  }

  static async failJob(jobId: string, stage: string, errorMessage: string): Promise<void> {
    const now = Date.now();
    const fields: Record<string, unknown> = {
      status: "failed",
      updatedAt: now,
      version: admin.firestore.FieldValue.increment(1),
      [`stages.${stage}.status`]: "failed",
      [`stages.${stage}.error`]: errorMessage,
      [`stages.${stage}.completedAt`]: now,
    };

    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        await db().collection("video_jobs").doc(jobId).update(fields);
        return;
      } catch (err) {
        const errMsg = String((err as any)?.message || err);
        const isContention = /contention|aborted|unavailable|resource_exhausted|deadline/i.test(errMsg);
        if (isContention && attempt < 3) {
          await new Promise((res) => setTimeout(res, 50 * attempt + Math.floor(Math.random() * 50)));
          continue;
        }
        logger.error("[Edge] Failed to mark job as failed", { jobId, stage, err });
        break;
      }
    }
  }

  private persistJobAsync(_shard: string, jobId: string, data: JobData): void {
    setImmediate(async () => {
      try {
        await db().collection("video_jobs").doc(jobId).set(data);
      } catch (err) {
        logger.error("[Edge] Async Firestore persist failed", { jobId, err });
      }
    });
  }

  private async loadJob(jobId: string): Promise<JobData | null> {
    try {
      const doc = await db().collection("video_jobs").doc(jobId).get();
      return doc.exists ? (doc.data() as JobData) : null;
    } catch (err) {
      logger.error("[Edge] Job load failed", { jobId, err });
      return null;
    }
  }

  private rejected(message: string): EdgeResponse {
    return { jobId: "", status: "rejected", message };
  }

  private estimateSeconds(plan: ExecutionPlan): number {
    return 480;
  }

  private stagePending(): StageStatus {
    return { status: "pending", progress: 0 };
  }

  private stageSkipped(): StageStatus {
    return { status: "skipped", progress: 100 };
  }

  static shardKey(userId: string): string {
    const hash = require("crypto").createHash("md5").update(userId).digest("hex");
    return String(parseInt(hash.substring(0, 8), 16) % SHARD_COUNT).padStart(2, "0");
  }
}
