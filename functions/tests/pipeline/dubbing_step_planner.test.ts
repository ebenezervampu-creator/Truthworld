import {
  STEP_BUDGET_SECONDS,
  CLOUD_FUNCTION_EVENT_MAX_SECONDS,
  DEFAULT_REEL_THRESHOLD_MS,
  DEFAULT_REEL_DURATION_MS,
  computePerWorkerTtsConcurrency,
  planDubbingSteps,
  nextRunnableSteps,
  shouldSkipChargeOnRetry,
} from "../../src/pipeline/services/dubbing-step-planner";

describe("Dubbing step planner & resume safety", () => {
  test("every planned step fits under the 480s budget (60s below 540s CF limit)", () => {
    expect(STEP_BUDGET_SECONDS).toBeLessThanOrEqual(480);
    expect(STEP_BUDGET_SECONDS).toBeLessThan(CLOUD_FUNCTION_EVENT_MAX_SECONDS);
    expect(DEFAULT_REEL_THRESHOLD_MS).toBe(180_000);
    expect(DEFAULT_REEL_DURATION_MS).toBe(150_000);

    for (const durationMs of [25_000, 175_000, 600_000, 720_000, 5_400_000]) {
      const plan = planDubbingSteps({
        jobId: `job_${durationMs}`,
        durationMs,
        languages: ["te", "hi"],
        sourceLanguage: "en",
      });
      for (const step of plan.steps) {
        expect(step.estimatedMaxSeconds).toBeLessThanOrEqual(STEP_BUDGET_SECONDS);
      }
    }
  });

  test("short-form (<= 3m) chains prep_analysis -> prep_voices -> translate_lang -> synthesize_and_mix", () => {
    const plan = planDubbingSteps({
      jobId: "short_1",
      durationMs: 175_000,
      languages: ["en", "te", "hi"],
      sourceLanguage: "en",
    });
    expect(plan.mode).toBe("short_form");
    expect(plan.totalReels).toBe(0);
    expect(plan.steps.map((s) => s.step)).toEqual([
      "prep_analysis",
      "prep_voices",
      "translate_lang",
      "synthesize_and_mix",
      "translate_lang",
      "synthesize_and_mix",
    ]);
  });

  test("long-form (> 3m, e.g. 10m = 600s) fans out 2.5m reel workers after prepare_reels and converges on assemble_reels", () => {
    const plan = planDubbingSteps({
      jobId: "long_10m",
      durationMs: 600_000, // 10 min
      languages: ["te"],
      sourceLanguage: "en",
    });
    expect(plan.mode).toBe("long_form");
    expect(plan.totalReels).toBe(4);
    const reels = plan.steps.filter((s) => s.step === "reel_worker");
    expect(reels).toHaveLength(4);
    const asm = plan.steps.find((s) => s.step === "assemble_reels")!;
    expect(asm.dependsOn).toEqual(["long_10m:reel:0", "long_10m:reel:1", "long_10m:reel:2", "long_10m:reel:3"]);
  });

  test("long-form with twoStageReviewPending gates prepare_reels behind per-language translate_lang -> await_review", () => {
    const plan = planDubbingSteps({
      jobId: "long_rev",
      durationMs: 600_000,
      languages: ["te", "hi"],
      sourceLanguage: "en",
      twoStageReviewPending: true,
    });
    expect(plan.mode).toBe("long_form");
    const prepReels = plan.steps.find((s) => s.step === "prepare_reels")!;
    expect(prepReels.dependsOn).toEqual(["long_rev:await_review:te", "long_rev:await_review:hi"]);
  });

  test("computePerWorkerTtsConcurrency clamps total parallel ElevenLabs requests to plan ceiling", () => {
    expect(computePerWorkerTtsConcurrency(3, 3)).toBe(1); // Starter: 3 instances x 1 slot = 3
    expect(computePerWorkerTtsConcurrency(5, 3)).toBe(1); // Creator: <= 5
    expect(computePerWorkerTtsConcurrency(10, 3)).toBe(3); // Pro: 3 instances x 3 = 9 <= 10
    expect(computePerWorkerTtsConcurrency(15, 3)).toBe(5); // Scale: 3 instances x 5 = 15
  });

  test("resume skips completed steps, completed languages, and completed reels", () => {
    const plan = planDubbingSteps({
      jobId: "long_resume",
      durationMs: 450_000, // 7.5m -> 3 reels at 2.5m
      languages: ["te"],
      sourceLanguage: "en",
    });

    const step1 = nextRunnableSteps(plan, { completedStepKeys: new Set() });
    expect(step1.map((s) => s.step)).toEqual(["prep_analysis"]);

    const afterPrep = nextRunnableSteps(plan, {
      completedStepKeys: new Set(["long_resume:prep_analysis", "long_resume:prep_voices", "long_resume:prepare_reels"]),
      completedReels: new Set([0, 2]),
    });
    expect(afterPrep.map((s) => s.key)).toEqual(["long_resume:reel:1"]);

    const readyToAssemble = nextRunnableSteps(plan, {
      completedStepKeys: new Set(["long_resume:prep_analysis", "long_resume:prep_voices", "long_resume:prepare_reels"]),
      completedReels: new Set([0, 1, 2]),
    });
    expect(readyToAssemble.map((s) => s.step)).toEqual(["assemble_reels"]);
  });

  test("shouldSkipChargeOnRetry prevents double charging", () => {
    expect(shouldSkipChargeOnRetry({ exists: false })).toBe(false);
    expect(shouldSkipChargeOnRetry({ exists: true, status: "charged", chargedUsd: 0.3 })).toBe(true);
    expect(shouldSkipChargeOnRetry({ exists: true, status: "completed", chargedUsd: 0 })).toBe(true);
    expect(shouldSkipChargeOnRetry({ exists: true, status: "pending", chargedUsd: 0 })).toBe(false);
  });
});
