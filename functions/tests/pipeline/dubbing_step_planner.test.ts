import {
  STEP_BUDGET_SECONDS,
  CLOUD_FUNCTION_EVENT_MAX_SECONDS,
  planDubbingSteps,
  nextRunnableSteps,
  shouldSkipChargeOnRetry,
} from "../../src/pipeline/services/dubbing-step-planner";

describe("Dubbing step planner & resume safety", () => {
  test("every planned step fits under the 480s budget (60s below 540s CF limit)", () => {
    expect(STEP_BUDGET_SECONDS).toBeLessThanOrEqual(480);
    expect(STEP_BUDGET_SECONDS).toBeLessThan(CLOUD_FUNCTION_EVENT_MAX_SECONDS);

    for (const durationMs of [25_000, 195_000, 720_000, 5_400_000]) {
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

  test("short-form (<= 8m) chains prep_analysis -> prep_voices -> translate_lang -> synthesize_and_mix", () => {
    const plan = planDubbingSteps({
      jobId: "short_1",
      durationMs: 195_000,
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

  test("long-form (> 8m) fans out reel workers after prepare_reels and converges on assemble_reels", () => {
    const plan = planDubbingSteps({
      jobId: "long_1",
      durationMs: 720_000, // 12 min
      languages: ["te"],
      sourceLanguage: "en",
    });
    expect(plan.mode).toBe("long_form");
    expect(plan.totalReels).toBe(3);
    const reels = plan.steps.filter((s) => s.step === "reel_worker");
    expect(reels).toHaveLength(3);
    const asm = plan.steps.find((s) => s.step === "assemble_reels")!;
    expect(asm.dependsOn).toEqual(["long_1:reel:0", "long_1:reel:1", "long_1:reel:2"]);
  });

  test("resume skips completed steps, completed languages, and completed reels", () => {
    const plan = planDubbingSteps({
      jobId: "long_resume",
      durationMs: 720_000,
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
