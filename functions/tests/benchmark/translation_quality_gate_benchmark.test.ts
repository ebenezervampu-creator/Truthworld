import {
  TranslationQualityGateBenchmark,
  STATISTICAL_RELEASE_GATE_THRESHOLDS,
  SEED_BENCHMARK_SAMPLES,
} from "../../src/benchmark/translation_quality_gate_benchmark";

describe("Translation & Dubbing Quality Gate Benchmark Suite", () => {
  describe("1. Partition Generation & Category Distribution", () => {
    test("generates exactly 600 samples per language across all 6 categories", () => {
      const tePartition = TranslationQualityGateBenchmark.generatePartition("te");
      expect(tePartition).toHaveLength(600);

      const categoryCounts: Record<string, number> = {};
      for (const sample of tePartition) {
        categoryCounts[sample.category] = (categoryCounts[sample.category] || 0) + 1;
      }

      expect(categoryCounts["everyday_conversation"]).toBe(100);
      expect(categoryCounts["news_and_politics"]).toBe(100);
      expect(categoryCounts["science_and_technology"]).toBe(100);
      expect(categoryCounts["religious_and_philosophical"]).toBe(100);
      expect(categoryCounts["idioms_and_cultural_expressions"]).toBe(100);
      expect(categoryCounts["long_form_dialogue"]).toBe(100);
    });

    test("preserves canonical seed samples and metadata in generated partitions", () => {
      const hiPartition = TranslationQualityGateBenchmark.generatePartition("hi");
      const firstSample = hiPartition[0];

      expect(firstSample.sampleId).toBe("hi_everyday_conversation_001");
      expect(firstSample.sourceEn).toBeTruthy();
      expect(firstSample.expectedDurationWindowMs).toBeGreaterThan(0);
      expect(firstSample.canonicalTranslations).toBeDefined();
    });
  });

  describe("2. Track A (Linguistic) & Track B (Acoustic) Sample Evaluation", () => {
    test("accurately verifies named entity and number preservation", async () => {
      const sample = SEED_BENCHMARK_SAMPLES.find((s) => s.sampleId === "news_01")!;
      const validTeTranslation = "సాక్ష్యాల ఆధారిత వాదనల కోసం 15 ప్రాంతీయ న్యూస్‌రూమ్‌లు ధ్రువీకరణ పొందినట్లు TruthWorld ప్రకటించింది.";

      const res = await TranslationQualityGateBenchmark.evaluateSample(sample, "te", validTeTranslation, { isDryRun: true });

      expect(res.trackA.namedEntityPreservationRate).toBe(1.0);
      expect(res.trackA.numberPreservationRate).toBe(1.0);
      expect(res.trackA.isLinguisticallyPassed).toBe(true);
    });

    test("flags linguistic failures when named entity or number is dropped", async () => {
      const sample = SEED_BENCHMARK_SAMPLES.find((s) => s.sampleId === "news_01")!;
      // Omits "TruthWorld" and drops "15"
      const droppedTranslation = "సాక్ష్యాల ఆధారిత వాదనల కోసం అనేక ప్రాంతీయ న్యూస్‌రూమ్‌లు ధ్రువీకరణ పొందాయి.";

      const res = await TranslationQualityGateBenchmark.evaluateSample(sample, "te", droppedTranslation, { isDryRun: true });

      expect(res.trackA.namedEntityPreservationRate).toBe(0.0);
      expect(res.trackA.numberPreservationRate).toBe(0.0);
      expect(res.trackA.isLinguisticallyPassed).toBe(false);
    });

    test("verifies acoustic tempo ceiling and breath floor preservation", async () => {
      const sample = SEED_BENCHMARK_SAMPLES.find((s) => s.sampleId === "conv_01")!;
      const validTeTranslation = "ఈ ఉదయం సమావేశంలో ఏమి జరిగిందో దయచేసి వివరించగలరా?";

      const res = await TranslationQualityGateBenchmark.evaluateSample(sample, "te", validTeTranslation, { isDryRun: true });

      expect(res.trackB.finalTempoRatio).toBeLessThanOrEqual(1.15);
      expect(res.trackB.breathFloorPreserved).toBe(true);
      expect(res.trackB.speakerTimbreSimilarity).toBeGreaterThanOrEqual(0.82);
      expect(res.trackB.isAcousticallyPassed).toBe(true);
    });
  });

  describe("3. Statistical Release Gate Threshold Standards", () => {
    test("enforces exact Go/No-Go Statistical Release Gate Threshold values", () => {
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.minNamedEntityPreservationRate).toBe(1.0); // 100.0%
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.minNumericParityRate).toBe(1.0); // 100.0%
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.minGlossaryComplianceRate).toBe(0.995); // >= 99.5%
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.minMeanDurationRatio).toBe(0.85); // 0.85 <= mu(R)
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.maxMeanDurationRatio).toBe(1.05); // mu(R) <= 1.05
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.maxP99DurationRatio).toBe(1.12); // P99 <= 1.12
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.maxConciseTriggerRate).toBe(0.12); // <= 12.0%
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.minTempoCeilingComplianceRate).toBe(1.0); // 100.0%
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.minBreathFloorPreservationRate).toBe(1.0); // 100.0%
      expect(STATISTICAL_RELEASE_GATE_THRESHOLDS.minSpeakerTimbreSimilarity).toBe(0.82); // >= 0.82 cosine
    });
  });

  describe("4. End-to-End Benchmark Execution & Production Certification", () => {
    test("runs partitioned benchmark dry-run and achieves CERTIFIED_PRODUCTION_READY status", async () => {
      // Evaluate all 4 target languages (te, hi, ta, ml) across sample limit for quick test pass
      const scorecard = await TranslationQualityGateBenchmark.runBenchmark({
        isDryRun: true,
        sampleLimitPerLanguage: 12,
      });

      expect(scorecard.languagesEvaluated).toEqual(["te", "hi", "ta", "ml"]);
      expect(scorecard.totalSamples).toBe(48);
      expect(scorecard.certifiedStatus).toBe("CERTIFIED_PRODUCTION_READY");
      expect(scorecard.summary.allGatesPassed).toBe(true);

      for (const lang of scorecard.languagesEvaluated) {
        const report = scorecard.languageReports[lang];
        expect(report.certifiedProductionReady).toBe(true);
        expect(report.thresholdGateResults).toHaveLength(9);

        // Verify each individual statistical gate passed
        for (const gate of report.thresholdGateResults) {
          expect(gate.passed).toBe(true);
        }

        // Verify Track A & Track B metrics
        expect(report.trackAMetrics.avgNamedEntityPreservationRate).toBe(1.0);
        expect(report.trackAMetrics.avgNumberPreservationRate).toBe(1.0);
        expect(report.trackAMetrics.avgTerminologyComplianceRate).toBeGreaterThanOrEqual(0.995);
        expect(report.trackBMetrics.avgDurationRatioR).toBeGreaterThanOrEqual(0.85);
        expect(report.trackBMetrics.avgDurationRatioR).toBeLessThanOrEqual(1.05);
        expect(report.trackBMetrics.p99DurationRatioR).toBeLessThanOrEqual(1.12);
        expect(report.trackBMetrics.tempoCeilingComplianceRate).toBe(1.0);
        expect(report.trackBMetrics.breathFloorPreservationRate).toBe(1.0);
        expect(report.trackBMetrics.speakerTimbreSimilarity).toBeGreaterThanOrEqual(0.82);
      }
    });
  });
});
