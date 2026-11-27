/**
 * Dubbing Step Planner & Resume Guard (pure, dependency-free, unit-tested).
 *
 * Breaks the dubbing pipeline into bounded steps so no single Cloud Functions (2nd gen)
 * Pub/Sub invocation needs more than STEP_BUDGET_SECONDS (480 s, 60 s below the 540 s limit).
 *
 * Short-form (<= reelThresholdMs):
 *   prep_analysis -> prep_voices -> translate_lang (per lang) -> synthesize_and_mix (per lang)
 * Long-form (> reelThresholdMs):
 *   prep_analysis -> prep_voices -> prepare_reels -> reel_worker (per reel, translates in-worker) -> assemble_reels
 */

export const CLOUD_FUNCTION_EVENT_MAX_SECONDS = 540;
export const STEP_BUDGET_SECONDS = 480;
export const STEP_HANDOFF_MS = 360_000;
export const DEFAULT_REEL_THRESHOLD_MS = 3 * 60 * 1000;
export const DEFAULT_REEL_DURATION_MS = 150_000;
export const DEFAULT_REEL_WORKER_MAX_INSTANCES = 3;

export type DubbingChainStep =
  | "prep_analysis"
  | "prep_voices"
  | "translate_lang"
  | "await_review"
  | "synthesize_and_mix"
  | "prepare_reels"
  | "reel_worker"
  | "assemble_reels";

export interface PlannedStep {
  step: DubbingChainStep;
  topic: string;
  key: string;
  estimatedMaxSeconds: number;
  dependsOn: string[];
  language?: string;
  reelIndex?: number;
}

export interface StepPlanInput {
  jobId: string;
  durationMs: number;
  languages: string[];
  sourceLanguage: string;
  reelThresholdMs?: number;
  reelDurationMs?: number;
  twoStageReviewPending?: boolean;
}

export interface StepPlan {
  jobId: string;
  mode: "short_form" | "long_form";
  stepBudgetSeconds: number;
  totalReels: number;
  steps: PlannedStep[];
}

export interface ResumeState {
  completedStepKeys: ReadonlySet<string>;
  completedLanguages?: ReadonlySet<string>;
  completedReels?: ReadonlySet<number>;
  orderAlreadyCharged?: boolean;
}

/**
 * Computes per-worker ElevenLabs TTS concurrency so parallel Cloud Function instances
 * never exceed the account-wide plan ceiling (e.g. Starter = 3, maxInstances = 3 -> 1/worker).
 */
export function computePerWorkerTtsConcurrency(
  accountMaxConcurrency: number,
  workerMaxInstances: number = DEFAULT_REEL_WORKER_MAX_INSTANCES
): number {
  const ceiling = Math.max(1, Math.floor(accountMaxConcurrency || 1));
  const instances = Math.max(1, Math.floor(workerMaxInstances || 1));
  return Math.max(1, Math.floor(ceiling / instances));
}

export function planDubbingSteps(input: StepPlanInput): StepPlan {
  const thresholdMs = input.reelThresholdMs ?? DEFAULT_REEL_THRESHOLD_MS;
  const reelDurationMs = Math.max(60_000, input.reelDurationMs ?? DEFAULT_REEL_DURATION_MS);
  const isLongForm = input.durationMs > thresholdMs;
  const src = (input.sourceLanguage || "en").toLowerCase().trim();
  const langs = Array.from(
    new Set((input.languages || []).map((l) => l.toLowerCase().trim()).filter((l) => l && l !== src))
  );

  const steps: PlannedStep[] = [
    {
      step: "prep_analysis",
      topic: "dubbing.step.prep",
      key: `${input.jobId}:prep_analysis`,
      estimatedMaxSeconds: 240,
      dependsOn: [],
    },
    {
      step: "prep_voices",
      topic: "dubbing.requested",
      key: `${input.jobId}:prep_voices`,
      estimatedMaxSeconds: 120,
      dependsOn: [`${input.jobId}:prep_analysis`],
    },
  ];

  if (!isLongForm) {
    for (const lang of langs) {
      const translateKey = `${input.jobId}:translate:${lang}`;
      steps.push({
        step: "translate_lang",
        topic: "dubbing.step.translate",
        key: translateKey,
        language: lang,
        estimatedMaxSeconds: 120,
        dependsOn: [`${input.jobId}:prep_voices`],
      });
      if (input.twoStageReviewPending) {
        const reviewKey = `${input.jobId}:await_review:${lang}`;
        steps.push({
          step: "await_review",
          topic: "dubbing.requested",
          key: reviewKey,
          language: lang,
          estimatedMaxSeconds: 10,
          dependsOn: [translateKey],
        });
        steps.push({
          step: "synthesize_and_mix",
          topic: "dubbing.requested",
          key: `${input.jobId}:synthesize:${lang}`,
          language: lang,
          estimatedMaxSeconds: 300,
          dependsOn: [reviewKey],
        });
      } else {
        steps.push({
          step: "synthesize_and_mix",
          topic: "dubbing.requested",
          key: `${input.jobId}:synthesize:${lang}`,
          language: lang,
          estimatedMaxSeconds: 300,
          dependsOn: [translateKey],
        });
      }
    }
    return {
      jobId: input.jobId,
      mode: "short_form",
      stepBudgetSeconds: STEP_BUDGET_SECONDS,
      totalReels: 0,
      steps,
    };
  }

  let preReelDeps: string[] = [`${input.jobId}:prep_voices`];
  if (input.twoStageReviewPending && langs.length > 0) {
    const reviewKeys: string[] = [];
    for (const lang of langs) {
      const translateKey = `${input.jobId}:translate:${lang}`;
      const reviewKey = `${input.jobId}:await_review:${lang}`;
      steps.push({
        step: "translate_lang",
        topic: "dubbing.step.translate",
        key: translateKey,
        language: lang,
        estimatedMaxSeconds: 180,
        dependsOn: [`${input.jobId}:prep_voices`],
      });
      steps.push({
        step: "await_review",
        topic: "dubbing.requested",
        key: reviewKey,
        language: lang,
        estimatedMaxSeconds: 10,
        dependsOn: [translateKey],
      });
      reviewKeys.push(reviewKey);
    }
    preReelDeps = reviewKeys;
  }

  const totalReels = Math.max(1, Math.ceil(input.durationMs / reelDurationMs));
  const prepReelsKey = `${input.jobId}:prepare_reels`;
  steps.push({
    step: "prepare_reels",
    topic: "dubbing.requested",
    key: prepReelsKey,
    estimatedMaxSeconds: 120,
    dependsOn: preReelDeps,
  });

  const reelKeys: string[] = [];
  for (let i = 0; i < totalReels; i++) {
    const rk = `${input.jobId}:reel:${i}`;
    reelKeys.push(rk);
    steps.push({
      step: "reel_worker",
      topic: "dubbing.reel.requested",
      key: rk,
      reelIndex: i,
      estimatedMaxSeconds: 240,
      dependsOn: [prepReelsKey],
    });
  }

  steps.push({
    step: "assemble_reels",
    topic: "dubbing.reel.assemble",
    key: `${input.jobId}:assemble`,
    estimatedMaxSeconds: 240,
    dependsOn: reelKeys,
  });

  return {
    jobId: input.jobId,
    mode: "long_form",
    stepBudgetSeconds: STEP_BUDGET_SECONDS,
    totalReels,
    steps,
  };
}

/** Returns runnable steps whose dependencies are all complete and that are not yet completed. */
export function nextRunnableSteps(plan: StepPlan, state: ResumeState): PlannedStep[] {
  const isDone = (s: PlannedStep): boolean => {
    if (state.completedStepKeys.has(s.key)) return true;
    if (s.step === "synthesize_and_mix" && s.language && state.completedLanguages?.has(s.language)) return true;
    if (s.step === "reel_worker" && typeof s.reelIndex === "number" && state.completedReels?.has(s.reelIndex)) return true;
    return false;
  };

  const doneSet = new Set<string>(state.completedStepKeys);
  for (const s of plan.steps) {
    if (isDone(s)) doneSet.add(s.key);
  }

  return plan.steps.filter((s) => !doneSet.has(s.key) && s.dependsOn.every((dep) => doneSet.has(dep)));
}

/** Retries must never charge an order twice. */
export function shouldSkipChargeOnRetry(orderState: { exists: boolean; status?: string; chargedUsd?: number }): boolean {
  if (!orderState.exists) return false;
  return orderState.status === "charged" || orderState.status === "completed" || Number(orderState.chargedUsd || 0) > 0;
}
