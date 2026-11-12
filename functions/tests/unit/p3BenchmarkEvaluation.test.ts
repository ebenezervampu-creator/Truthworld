import { BenchmarkEvaluationService } from '../../src/pipeline/services/benchmarkEvaluationService';
import { GOLD_STANDARD_BENCHMARK_DATASET } from '../../src/pipeline/benchmarks/goldStandardClaims';
import { BenchmarkClaimRecord, BenchmarkReport } from '../../src/pipeline/types';

describe('P3 Benchmark & Comprehensive Evaluation Suite', () => {
  let benchmarkService: BenchmarkEvaluationService;

  beforeEach(() => {
    benchmarkService = new BenchmarkEvaluationService();
  });

  // Test 1: Full Gold-Standard Benchmark Execution
  it('1. Gold-Standard Benchmark: Evaluates multi-category dataset and generates comprehensive report', async () => {
    const report: BenchmarkReport = await benchmarkService.runBenchmark(GOLD_STANDARD_BENCHMARK_DATASET);

    expect(report.reportId).toBeDefined();
    expect(report.totalDatasetSize).toBeGreaterThanOrEqual(10);
    expect(report.verdictAccuracy.totalClaims).toBe(report.totalDatasetSize);
    expect(report.verdictAccuracy.accuracy).toBeGreaterThanOrEqual(0.85);
    expect(report.verdictAccuracy.f1Macro).toBeGreaterThanOrEqual(0.80);

    // Verify confusion matrix exists and contains valid keys
    expect(report.verdictAccuracy.confusionMatrix).toBeDefined();
    expect(Object.keys(report.verdictAccuracy.confusionMatrix).length).toBeGreaterThan(0);

    // Verify coverage rate vs abstention rate
    expect(report.verdictAccuracy.coverageRate + report.verdictAccuracy.abstentionRate).toBeCloseTo(1.0, 5);
  });

  // Test 2: Confidence Calibration & Brier Score
  it('2. Confidence Calibration: Computes Brier score, ECE, reliability bins, and verifies score decoupling', async () => {
    const report: BenchmarkReport = await benchmarkService.runBenchmark(GOLD_STANDARD_BENCHMARK_DATASET);
    const cal = report.confidenceCalibration;

    // Brier score should be well-calibrated (<= 0.20 for an authoritative system)
    expect(cal.brierScore).toBeLessThanOrEqual(0.20);

    // Expected Calibration Error (ECE) should be bounded
    expect(cal.expectedCalibrationError).toBeLessThanOrEqual(0.25);

    // Reliability bins should be generated
    expect(cal.reliabilityBins.length).toBeGreaterThan(0);
    for (const bin of cal.reliabilityBins) {
      expect(bin.sampleCount).toBeGreaterThan(0);
      expect(bin.meanPredictedConfidence).toBeGreaterThanOrEqual(0);
      expect(bin.meanPredictedConfidence).toBeLessThanOrEqual(1.0);
    }

    // Crucial: verdictConfidence must be decoupled from evidenceStrength
    expect(cal.decoupledScoresEvaluated).toBe(true);
  });

  // Test 3: Evidence Quality Metrics & Provenance
  it('3. Evidence Quality: Evaluates evidence precision, Tier-E exclusion, and citation provenance', async () => {
    const report: BenchmarkReport = await benchmarkService.runBenchmark(GOLD_STANDARD_BENCHMARK_DATASET);
    const ev = report.evidenceQuality;

    expect(ev.totalAdmittedSources).toBeGreaterThan(0);
    expect(ev.evidencePrecision).toBeGreaterThanOrEqual(0.90);
    expect(ev.tierEExclusionRate).toBe(1.0); // 100% of Tier-E excluded
    expect(ev.provenanceCompletenessRate).toBe(1.0); // 100% with direct URLs & publishers
  });

  // Test 4: Temporal & Comparative Evaluation Hard Gate
  it('4. Temporal & Comparative Integrity: Enforces ZERO acceptance of invalid comparisons as verified_true', async () => {
    const report: BenchmarkReport = await benchmarkService.runBenchmark(GOLD_STANDARD_BENCHMARK_DATASET);
    const temp = report.temporalEvaluation;

    expect(temp.totalComparativeClaims).toBeGreaterThan(0);
    expect(temp.invalidComparisonsTested).toBeGreaterThan(0);

    // Critical Release Invariant: MUST BE EXACTLY 0
    expect(temp.invalidComparisonsAcceptedAsTrue).toBe(0);
    expect(temp.temporalConstraintExtractionAccuracy).toBeGreaterThanOrEqual(0.90);
  });

  // Test 5: Release Gates Enforcement
  it('5. Release Gates: Passes when all quality invariants are met, and blocks on violations', async () => {
    const report: BenchmarkReport = await benchmarkService.runBenchmark(GOLD_STANDARD_BENCHMARK_DATASET);

    expect(report.releaseGates.passed).toBe(true);
    expect(report.releaseGates.blockingViolations.length).toBe(0);

    // Verify individual blocking rules
    const rules = report.releaseGates.rules;
    const g1 = rules.find(r => r.gateName === 'Zero Invalid-Comparison Acceptance');
    expect(g1?.passed).toBe(true);
    expect(g1?.isBlocking).toBe(true);

    const g2 = rules.find(r => r.gateName === 'Zero Tier-E Source Admission');
    expect(g2?.passed).toBe(true);

    const g3 = rules.find(r => r.gateName === 'Citation Provenance Completeness');
    expect(g3?.passed).toBe(true);

    const g4 = rules.find(r => r.gateName === 'Finalization Barrier Enforcement');
    expect(g4?.passed).toBe(true);
  });

  // Test 6: Release Gate Blocking Test
  it('6. Release Gate Barrier: Blocks release if an invalid comparison is erroneously accepted as true', () => {
    const syntheticFailingEvaluation = {
      verdictAccuracy: {
        totalClaims: 1,
        evaluatedClaims: 1,
        correctPredictions: 0,
        accuracy: 0,
        precisionMacro: 0,
        recallMacro: 0,
        f1Macro: 0,
        f1Weighted: 0,
        perVerdictMetrics: {},
        confusionMatrix: {},
        abstentionRate: 0,
        coverageRate: 1.0,
      },
      confidenceCalibration: {
        brierScore: 0.1,
        expectedCalibrationError: 0.1,
        maxCalibrationError: 0.1,
        overconfidenceError: 0.05,
        underconfidenceError: 0.05,
        reliabilityBins: [],
        decoupledScoresEvaluated: true,
      },
      evidenceQuality: {
        totalAdmittedSources: 1,
        relevantAdmittedSources: 1,
        evidencePrecision: 1.0,
        tierEExclusionRate: 1.0,
        contradictoryPreservationRate: 1.0,
        wireDeduplicationAccuracy: 1.0,
        provenanceCompletenessRate: 1.0,
        quarantinedSourcesAudited: 0,
      },
      temporalEvaluation: {
        totalComparativeClaims: 1,
        invalidComparisonsTested: 1,
        invalidComparisonsAcceptedAsTrue: 1, // VIOLATION!
        temporalConstraintExtractionAccuracy: 1.0,
        eventBoundaryResolutionAccuracy: 1.0,
        accountingMismatchDetectionRate: 1.0,
      },
      evaluatedClaims: [{
        record: GOLD_STANDARD_BENCHMARK_DATASET[0],
        predicted: {
          status: 'verified_true' as any,
          lifecycle: 'finalized',
          confidence: 0.85,
        } as any,
        isMatch: false,
      }],
    };

    const gateResult = benchmarkService.evaluateReleaseGates(syntheticFailingEvaluation as any);

    expect(gateResult.passed).toBe(false);
    expect(gateResult.blockingViolations.length).toBeGreaterThan(0);
    expect(gateResult.blockingViolations.some(v => v.includes('invalid comparison(s) were accepted'))).toBe(true);
  });

  // Test 7: Historical Regression Detection
  it('7. Regression Detection: Flags unexpected verdict changes when compared against baseline report', () => {
    const baselineReport: BenchmarkReport = {
      reportId: 'tw_baseline_v1',
      timestamp: '2026-11-01T00:00:00Z',
      modelVersion: 'v1.0.0',
      totalDatasetSize: 1,
      categoryBreakdown: { historical: 1 },
      verdictAccuracy: {
        totalClaims: 1,
        evaluatedClaims: 1,
        correctPredictions: 1,
        accuracy: 1.0,
        precisionMacro: 1.0,
        recallMacro: 1.0,
        f1Macro: 1.0,
        f1Weighted: 1.0,
        perVerdictMetrics: {},
        confusionMatrix: {},
        abstentionRate: 0,
        coverageRate: 1.0,
      },
      confidenceCalibration: {
        brierScore: 0.05,
        expectedCalibrationError: 0.05,
        maxCalibrationError: 0.05,
        overconfidenceError: 0,
        underconfidenceError: 0,
        reliabilityBins: [],
        decoupledScoresEvaluated: true,
      },
      evidenceQuality: {
        totalAdmittedSources: 1,
        relevantAdmittedSources: 1,
        evidencePrecision: 1.0,
        tierEExclusionRate: 1.0,
        contradictoryPreservationRate: 1.0,
        wireDeduplicationAccuracy: 1.0,
        provenanceCompletenessRate: 1.0,
        quarantinedSourcesAudited: 0,
      },
      temporalEvaluation: {
        totalComparativeClaims: 0,
        invalidComparisonsTested: 0,
        invalidComparisonsAcceptedAsTrue: 0,
        temporalConstraintExtractionAccuracy: 1.0,
        eventBoundaryResolutionAccuracy: 1.0,
        accountingMismatchDetectionRate: 1.0,
      },
      releaseGates: {
        passed: true,
        blockingViolations: [],
        rules: [],
      },
    };

    const simulatedRegressionItem = {
      record: {
        id: 'hist_001_india_first_election',
        category: 'historical' as any,
        claimText: 'India first general election was in 1951-1952',
        normalizedProposition: 'General elections 1951-1952',
        referenceVerdict: 'verified_true' as any,
        referenceSources: [],
        expertAnnotationNotes: '',
        annotatorAgreementRate: 1.0,
      },
      predicted: {
        status: 'verified_false' as any, // FLIPPED TO WRONG VERDICT!
      } as any,
      isMatch: false,
    };

    const regressions = benchmarkService.detectRegressions([simulatedRegressionItem], baselineReport);

    expect(regressions.length).toBe(1);
    expect(regressions[0].claimId).toBe('hist_001_india_first_election');
    expect(regressions[0].isRegression).toBe(true);
    expect(regressions[0].previousVerdict).toBe('verified_true');
    expect(regressions[0].currentVerdict).toBe('verified_false');
  });

  // Test 8: The 7 Auditable Claim Verification Invariants
  it('8. Auditable Claim Verification Architecture: Every finalized claim answers the 7 core questions', async () => {
    const record = GOLD_STANDARD_BENCHMARK_DATASET.find(r => r.id === 'comp_001_nehru_thailand_pakistan')!;
    const claim = await benchmarkService.evaluateSingleBenchmarkRecord(record);

    // Q1: What exactly was claimed?
    expect(claim.text).toBe(record.claimText);

    // Q2: What evidence supports it?
    expect(claim.richSources).toBeDefined();
    expect(claim.richSources!.length).toBeGreaterThan(0);

    // Q3: What evidence contradicts it?
    expect(claim.reasoning).toBeDefined();

    // Q4: Which sources were admitted and why?
    expect(claim.richSources![0].tier).toBeDefined();
    expect(claim.richSources![0].publisher).toBeDefined();

    // Q5: Were dates and measurements comparable?
    expect(claim.temporalConstraints).toBeDefined();
    expect(claim.comparabilityAssessment).toBeDefined();
    expect(claim.comparabilityAssessment!.isComparable).toBe(false);

    // Q6: How confident is the system?
    expect(claim.verdictConfidence).toBeDefined();
    expect(claim.verdictConfidence).toBeGreaterThan(0);

    // Q7: What limitations prevent a stronger conclusion?
    expect(claim.publicNote).toBeDefined();
    expect(claim.publicNote).toContain('Incompatible comparative baseline');
  });

  // Test 9: P3 Refinement: Multiclass Brier score, 95% CI & Dataset Independence
  it('9. Multiclass Brier Score, 95% Confidence Intervals, and Independence Verification', async () => {
    const report = await benchmarkService.runBenchmark(GOLD_STANDARD_BENCHMARK_DATASET);

    // Multiclass Brier Score
    expect(report.confidenceCalibration.multiclassBrierScore).toBeDefined();
    expect(report.confidenceCalibration.multiclassBrierScore).toBeGreaterThanOrEqual(0);
    expect(report.confidenceCalibration.multiclassBrierScore).toBeLessThan(1.0);

    // 95% Confidence Interval for Accuracy
    expect(report.verdictAccuracy.accuracyConfidenceInterval).toBeDefined();
    expect(report.verdictAccuracy.accuracyConfidenceInterval!.confidenceLevel).toBe(0.95);
    expect(report.verdictAccuracy.accuracyConfidenceInterval!.lower).toBeGreaterThan(0);
    expect(report.verdictAccuracy.accuracyConfidenceInterval!.upper).toBeLessThanOrEqual(1.0);

    // Independent Provenance Verification
    expect(report.datasetIntegrityVerified).toBe(true);
    expect(GOLD_STANDARD_BENCHMARK_DATASET.every(d => d.isIndependentlyEstablished)).toBe(true);
    expect(GOLD_STANDARD_BENCHMARK_DATASET.every(d => d.annotatorId)).toBe(true);
    expect(GOLD_STANDARD_BENCHMARK_DATASET.every(d => d.datasetVersion === '1.2.0-gold')).toBe(true);
  });

  // Test 10: P3 Refinement: Epistemic Categorization for Religious & Metaphysical Claims
  it('10. Epistemic Classification: Distinguishes faith tradition, textual records, and empirical claims', async () => {
    // 1. Traditional Faith Belief: Must NOT be marked false simply because it is unfalsifiable
    const faithRecord = GOLD_STANDARD_BENCHMARK_DATASET.find(r => r.id === 'rel_001_traditional_belief_gospel')!;
    const faithClaim = await benchmarkService.evaluateSingleBenchmarkRecord(faithRecord);
    expect(faithClaim.status).toBe('religious_belief');
    expect(faithClaim.publicNote).toContain('Not subject to empirical falsification');

    // 2. Textual Record: Fact about what a text contains
    const textRecord = GOLD_STANDARD_BENCHMARK_DATASET.find(r => r.id === 'rel_002_textual_record_saraswati')!;
    const textClaim = await benchmarkService.evaluateSingleBenchmarkRecord(textRecord);
    expect(textClaim.status).toBe('verified_true');

    // 3. Unfalsifiable Metaphysical Doctrine (Karma)
    const karmaRecord = GOLD_STANDARD_BENCHMARK_DATASET.find(r => r.id === 'rel_003_unfalsifiable_metaphysical_karma')!;
    const karmaClaim = await benchmarkService.evaluateSingleBenchmarkRecord(karmaRecord);
    expect(karmaClaim.status).toBe('religious_belief');

    // 4. Testable Empirical Claim: False because medical evidence contradicts
    const empiricalRecord = GOLD_STANDARD_BENCHMARK_DATASET.find(r => r.id === 'rel_004_testable_empirical_claim_supernatural_cure')!;
    const empiricalClaim = await benchmarkService.evaluateSingleBenchmarkRecord(empiricalRecord);
    expect(empiricalClaim.status).toBe('verified_false');
  });
});
