/**
 * 🧪 NETFLIX SUBTITLE 22-LANGUAGE BENCHMARK TEST SUITE
 *
 * Verifies the automated shot-change detection and Netflix compliance engine
 * across 20 authentic TruthWorld video corpora and 22 languages.
 *
 * Enforces:
 *   1. Overall compliance rate >= 98.0% across all 22 languages
 *   2. Zero temporal overlap (100% compliance)
 *   3. 100% adherence to broadcast maximum cue duration (<= 7000ms)
 *   4. Frame-accurate shot-change boundary alignment
 */

import { NetflixSubtitleBenchmark } from "../../src/benchmark/netflix_subtitle_22_languages_benchmark";

describe("Netflix Timed Text Style Guide (TTSG) 22-Language Benchmark", () => {
  // Benchmark runs in ~3-4 seconds across all 20 videos and 22 languages (2,598 cues)
  jest.setTimeout(30000);

  test("achieves >= 98.0% compliance against Netflix rules in all 22 languages", async () => {
    const report = await NetflixSubtitleBenchmark.runBenchmark();

    expect(report.totalVideos).toBe(20);
    expect(report.totalLanguages).toBe(22);
    expect(report.totalCuesEvaluated).toBeGreaterThan(2000);

    // Overlap: Zero overlap permitted across any language
    expect(report.ruleScores.noOverlap.passed).toBe(report.totalCuesEvaluated);

    // Max duration: 100% adherence to 7s ceiling
    expect(report.ruleScores.maxDuration.passed).toBe(report.totalCuesEvaluated);

    // Shot-change alignment: Frame-accurate snapping and flash prevention
    expect(report.ruleScores.shotChangeAlignment.passed).toBe(report.totalCuesEvaluated);

    // Overall compliance rate must exceed 98.0%
    expect(report.overallComplianceRate).toBeGreaterThanOrEqual(0.98);

    // Verify all 22 individual languages achieve >= 95.0% compliance
    for (const [code, lang] of Object.entries(report.languageScores)) {
      const rate = lang.passedCues / lang.totalCues;
      expect(rate).toBeGreaterThanOrEqual(0.95);
    }
  });
});
