/**
 * 🩺 TRUTHWORLD FACTCHECK PIPELINE — OBSERVABILITY & DIAGNOSTICS ENGINE
 *
 * Provides granular stage tracing, breadcrumbs, structured error classification,
 * and root-cause attribution across the entire Fact-Checking lifecycle.
 *
 * Enables human developers and AI agents to pinpoint:
 * 1. Which exact stage failed (Stage 1 to Stage 11).
 * 2. Which backend service/component caused the issue.
 * 3. Specific input/output metrics at failure time (claims, tokens, elapsed ms).
 * 4. Clear, actionable troubleshooting guidance to fix the root cause.
 */

import { logger } from "../utils/logger";

export enum FactcheckStage {
  STAGE_01_PREFLIGHT = "01_PREFLIGHT_AND_IDEMPOTENCY",
  STAGE_02_INPUT_RESOLUTION = "02_INPUT_AND_MEDIA_RESOLUTION",
  STAGE_03_QUOTA_AND_SAFETY_GATES = "03_QUOTA_AND_SAFETY_GATES",
  STAGE_04_CLAIM_EXTRACTION = "04_CLAIM_EXTRACTION_AND_INTENT",
  STAGE_05_RANKING_AND_STREAMING = "05_RANKING_AND_STREAMING",
  STAGE_06_SOURCE_HARVESTING = "06_SOURCE_HARVESTING",
  STAGE_07_CASCADE_VERIFICATION = "07_CASCADE_VERIFICATION",
  STAGE_08_LEDGER_AND_EXPLAINABILITY = "08_LEDGER_AND_EXPLAINABILITY",
  STAGE_09_PERSISTENCE_AND_DISPATCH = "09_PERSISTENCE_AND_DISPATCH",
  STAGE_10_COST_ATTRIBUTION = "10_COST_ATTRIBUTION",
  STAGE_11_ASYNC_SYNTHESIS = "11_ASYNC_SYNTHESIS",
}

export interface FactcheckBreadcrumb {
  timestamp: number;
  stage: FactcheckStage;
  message: string;
  meta?: Record<string, any>;
}

export interface FactcheckDiagnosticTelemetry {
  jobId: string;
  videoId?: string;
  userId?: string;
  totalElapsedMs: number;
  activeStage: FactcheckStage;
  stageLatenciesMs: Record<string, number>;
  metrics: Record<string, any>;
  breadcrumbs: FactcheckBreadcrumb[];
  lastError?: {
    stage: FactcheckStage;
    component: string;
    message: string;
    suggestedRemedy: string;
    context?: Record<string, any>;
    stack?: string;
  };
}

/**
 * Structured pipeline error with explicit stage and component attribution.
 * Guarantees that any failure clearly reports its exact origin and suggested remedy.
 */
export class FactcheckPipelineError extends Error {
  public readonly stage: FactcheckStage;
  public readonly component: string;
  public readonly jobId: string;
  public readonly videoId?: string;
  public readonly userId?: string;
  public readonly suggestedRemedy: string;
  public readonly context?: Record<string, any>;
  public readonly originalError?: any;
  public readonly timestamp: number;

  constructor(params: {
    stage: FactcheckStage;
    component: string;
    message: string;
    jobId: string;
    videoId?: string;
    userId?: string;
    suggestedRemedy: string;
    context?: Record<string, any>;
    originalError?: any;
  }) {
    const formattedMessage = `[Factcheck:${params.stage}][${params.component}] ${params.message} (Job: ${params.jobId})`;
    super(formattedMessage);
    this.name = "FactcheckPipelineError";
    this.stage = params.stage;
    this.component = params.component;
    this.jobId = params.jobId;
    this.videoId = params.videoId;
    this.userId = params.userId;
    this.suggestedRemedy = params.suggestedRemedy;
    this.context = params.context;
    this.originalError = params.originalError;
    this.timestamp = Date.now();

    if (params.originalError instanceof Error && params.originalError.stack) {
      this.stack = `${this.stack}\nCaused by: ${params.originalError.stack}`;
    }
  }

  public toDiagnosticSummary(): Record<string, any> {
    return {
      errorType: "FactcheckPipelineError",
      stage: this.stage,
      component: this.component,
      message: this.message,
      jobId: this.jobId,
      videoId: this.videoId,
      userId: this.userId,
      suggestedRemedy: this.suggestedRemedy,
      context: this.context,
      timestamp: this.timestamp,
    };
  }
}

/**
 * Diagnostic tracker that accompanies each run of the Factcheck Pipeline.
 * Records stage transitions, latencies, breadcrumbs, and structured error attribution.
 */
export class FactcheckDiagnosticTracker {
  public readonly jobId: string;
  public readonly videoId?: string;
  public readonly userId?: string;
  private readonly startTime: number;
  private currentStage: FactcheckStage = FactcheckStage.STAGE_01_PREFLIGHT;
  private stageStartTimes: Partial<Record<FactcheckStage, number>> = {};
  private stageLatencies: Partial<Record<FactcheckStage, number>> = {};
  private stageMetrics: Record<string, any> = {};
  private breadcrumbs: FactcheckBreadcrumb[] = [];
  private lastCapturedError?: FactcheckPipelineError;

  constructor(jobId: string, videoId?: string, userId?: string) {
    this.jobId = jobId;
    this.videoId = videoId;
    this.userId = userId;
    this.startTime = Date.now();
    this.stageStartTimes[FactcheckStage.STAGE_01_PREFLIGHT] = this.startTime;
  }

  /**
   * Transition to a new pipeline stage, recording duration of the previous stage.
   */
  public enterStage(stage: FactcheckStage, metadata?: Record<string, any>): void {
    const now = Date.now();
    if (this.currentStage && this.stageStartTimes[this.currentStage]) {
      this.stageLatencies[this.currentStage] = now - this.stageStartTimes[this.currentStage]!;
    }
    this.currentStage = stage;
    this.stageStartTimes[stage] = now;

    this.addBreadcrumb(`Entered ${stage}`, metadata);
    logger.info(`[Factcheck:Stage] >>> ${stage}`, {
      jobId: this.jobId,
      videoId: this.videoId,
      ...metadata,
    });
  }

  /**
   * Complete the current stage and record its execution latency.
   */
  public completeStage(stage: FactcheckStage, metadata?: Record<string, any>): number {
    const now = Date.now();
    const start = this.stageStartTimes[stage] || now;
    const durationMs = now - start;
    this.stageLatencies[stage] = durationMs;

    this.addBreadcrumb(`Completed ${stage} in ${durationMs}ms`, metadata);
    logger.info(`[Factcheck:Stage] <<< COMPLETED ${stage} (${durationMs}ms)`, {
      jobId: this.jobId,
      videoId: this.videoId,
      durationMs,
      ...metadata,
    });
    return durationMs;
  }

  /**
   * Records a key metric for a specific stage.
   */
  public recordMetric(key: string, value: any): void {
    this.stageMetrics[key] = value;
  }

  /**
   * Adds an immutable breadcrumb to trace the execution history.
   */
  public addBreadcrumb(message: string, meta?: Record<string, any>): void {
    this.breadcrumbs.push({
      timestamp: Date.now(),
      stage: this.currentStage,
      message,
      meta,
    });
    // Keep breadcrumbs capped at 100 entries to prevent memory bloat
    if (this.breadcrumbs.length > 100) {
      this.breadcrumbs.shift();
    }
  }

  /**
   * Wraps an asynchronous stage execution block with timing and automatic error capture.
   */
  public async executeStage<T>(
    stage: FactcheckStage,
    component: string,
    action: () => Promise<T>,
    metadata?: Record<string, any>,
    suggestedRemedyOnFailure: string = "Inspect component logs and upstream provider quotas"
  ): Promise<T> {
    this.enterStage(stage, metadata);
    try {
      const result = await action();
      this.completeStage(stage);
      return result;
    } catch (err: any) {
      const pipelineError = this.captureError({
        stage,
        component,
        originalError: err,
        suggestedRemedy: suggestedRemedyOnFailure,
        context: metadata,
      });
      throw pipelineError;
    }
  }

  /**
   * Captures an error, enriches it with pipeline diagnostic context, logs it, and saves it.
   */
  public captureError(params: {
    stage: FactcheckStage;
    component: string;
    originalError: any;
    suggestedRemedy: string;
    context?: Record<string, any>;
  }): FactcheckPipelineError {
    const rawMsg = params.originalError instanceof Error
      ? params.originalError.message
      : String(params.originalError);

    const pipelineError = new FactcheckPipelineError({
      stage: params.stage,
      component: params.component,
      message: rawMsg,
      jobId: this.jobId,
      videoId: this.videoId,
      userId: this.userId,
      suggestedRemedy: params.suggestedRemedy,
      context: params.context,
      originalError: params.originalError,
    });

    this.lastCapturedError = pipelineError;

    logger.error(`[Factcheck:Error] Failure at ${params.stage} in ${params.component}`, {
      jobId: this.jobId,
      videoId: this.videoId,
      stage: params.stage,
      component: params.component,
      error: rawMsg,
      remedy: params.suggestedRemedy,
      elapsedMs: Date.now() - this.startTime,
      ...params.context,
    });

    return pipelineError;
  }

  /**
   * Generates a telemetry and diagnostic payload suitable for persistence and debugging.
   */
  public getDiagnosticTelemetry(): FactcheckDiagnosticTelemetry {
    const now = Date.now();
    // Finalize active stage latency
    if (this.currentStage && this.stageStartTimes[this.currentStage]) {
      this.stageLatencies[this.currentStage] = now - this.stageStartTimes[this.currentStage]!;
    }

    return {
      jobId: this.jobId,
      videoId: this.videoId,
      userId: this.userId,
      totalElapsedMs: now - this.startTime,
      activeStage: this.currentStage,
      stageLatenciesMs: this.stageLatencies as Record<string, number>,
      metrics: this.stageMetrics,
      breadcrumbs: this.breadcrumbs,
      lastError: this.lastCapturedError
        ? {
            stage: this.lastCapturedError.stage,
            component: this.lastCapturedError.component,
            message: this.lastCapturedError.message,
            suggestedRemedy: this.lastCapturedError.suggestedRemedy,
            context: this.lastCapturedError.context,
            stack: this.lastCapturedError.stack,
          }
        : undefined,
    };
  }
}
