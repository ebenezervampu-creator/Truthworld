/**
 * ⚡ TRUTHWORLD CREDIBILITY PIPELINE: 5-TIER BENCHMARK SUITE TEST (LIVE-ENTITY & ADVERSARIAL)
 *
 * Automated regression suite testing 16 critical claims across 5 tiers:
 *   Tier 1: Baseline Ground Truth (Ingestion & Retrieval)
 *   Tier 2: Context, Framing & Cherry-Picking (Semantic & Nuance Layer)
 *   Tier 3: Cross-Lingual, Paraphrased & Repeating Claims (Semantic Matching Layer)
 *   Tier 4: Temporal Drift & Evolving Reality (Freshness & Provenance Layer)
 *   Tier 5: Adversarial, Unverifiable & Geopolitically Contested Claims (Governance & Calibration Layer)
 *
 * And verifying the 5-point Bottom-Line Audit Checklist:
 *   1. Claim Decomposition
 *   2. Source Diversity & True Triangulation (>= 2 independent Tier A/B authorities)
 *   3. Strict Confidence Calibration (Projections <=95%, Speculation/Contested <=80%)
 *   4. Explainability & Citations
 *   5. Audit Trail & Provenance
 */

import {
  runTieredStressTest,
  TIERED_BENCHMARK_SUITE,
  TieredBenchmarkResult,
} from '../../src/benchmark/tiered_stress_test';

describe('TruthWorld Credibility Pipeline: 5-Tier Benchmark Stress-Test (Adversarial & Live-Entity)', () => {
  let results: TieredBenchmarkResult[];
  let summary: Awaited<ReturnType<typeof runTieredStressTest>>['summary'];

  beforeAll(async () => {
    const output = await runTieredStressTest();
    results = output.results;
    summary = output.summary;
  });

  it('evaluates exactly 16 critical claims across the 5 tiers', () => {
    expect(results).toHaveLength(16);
    expect(summary.totalEvaluated).toBe(16);
    expect(TIERED_BENCHMARK_SUITE).toHaveLength(16);
  });

  it('achieves 100% verdict accuracy across all 16 benchmark claims', () => {
    expect(summary.verdictAccuracy).toBe(100.0);
    for (const r of results) {
      expect(r.verdictMatch).toBe(true);
      expect(r.actualVerdict).toBe(r.expectedVerdict);
    }
  });

  describe('Tier 1: Baseline Ground Truth (Ingestion & Retrieval)', () => {
    it('T1_C01: verifies WHO smallpox eradication declaration (1980) triangulated with CDC', () => {
      const c = results.find((r) => r.id === 'T1_C01')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('verified_true');
      expect(c.confidence).toBe(1.0);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.primarySourceTitle).toContain('World Health Organization');
      expect(c.auditChecklist.sourceDiversityAndWeighting).toBe(true);
    });

    it('T1_C02: verifies compound climate emissions claim (China annual vs US cumulative) triangulated with IEA', () => {
      const c = results.find((r) => r.id === 'T1_C02')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('verified_true');
      expect(c.auditChecklist.claimDecomposition).toBe(true);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('China is the largest annual emitter of CO2');
      expect(c.reasoning).toContain('United States is the largest cumulative historical emitter');
    });

    it('T1_C03: refutes 2008 financial crisis cryptocurrency causation claim triangulated with Federal Reserve', () => {
      const c = results.find((r) => r.id === 'T1_C03')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('false_claim');
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.primarySourceTitle).toContain('Financial Crisis Inquiry Commission');
      expect(c.reasoning).toContain('Cryptocurrencies did not cause the 2008 crisis');
    });
  });

  describe('Tier 2: Context, Framing & Cherry-Picking (Semantic & Nuance Layer)', () => {
    it('T2_C04: marks doubled life expectancy non-sequitur healthcare claim as misleading (WHO + World Bank)', () => {
      const c = results.find((r) => r.id === 'T2_C04')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('misleading');
      expect(c.auditChecklist.claimDecomposition).toBe(true);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('global average life expectancy has more than doubled');
      expect(c.reasoning).toContain('does not prove healthcare reaches everyone equally');
    });

    it('T2_C05: marks solar night grid argument as misleading strawman (IEA + NREL)', () => {
      const c = results.find((r) => r.id === 'T2_C05')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('misleading');
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('strawman argument');
    });

    it('T2_C06: marks GDP 6% growth meaning citizens 6% wealthier as misleading conflation (World Bank + IMF)', () => {
      const c = results.find((r) => r.id === 'T2_C06')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('misleading');
      expect(c.auditChecklist.claimDecomposition).toBe(true);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('GDP growth measures aggregate economic output');
    });
  });

  describe('Tier 3: Cross-Lingual, Paraphrased & Repeating Claims (Semantic Matching Layer)', () => {
    it('T3_C07: refutes 5G viral infection myth with consistent multi-lingual resolution (WHO + ICNIRP)', () => {
      const c = results.find((r) => r.id === 'T3_C07')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('false_claim');
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('Radiofrequency electromagnetic fields emitted by 5G telecommunications are non-ionizing radiation');
    });

    it('T3_C08: refutes recurring secret central bank physical cash ban treaty hoax (BIS + Fed)', () => {
      const c = results.find((r) => r.id === 'T3_C08')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('false_claim');
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.primarySourceTitle).toContain('Bank for International Settlements');
    });

    it('T3_C09: refutes high-harm medical misinformation: warm lemon water cures cancer (ACS + Cancer Research UK)', () => {
      const c = results.find((r) => r.id === 'T3_C09')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('false_claim');
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.primarySourceTitle).toContain('American Cancer Society');
    });
  });

  describe('Tier 4: Temporal Drift & Evolving Reality (Freshness & Provenance Layer)', () => {
    it('T4_C10: confirms India largest population with strict demographic projection calibration (<=95%)', () => {
      const c = results.find((r) => r.id === 'T4_C10')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('verified_true');
      expect(c.confidence).toBeLessThanOrEqual(0.95); // Strictly calibrated (not falsely 100%)
      expect(c.confidence).toBeGreaterThanOrEqual(0.90);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.primarySourceTitle).toContain('UN DESA');
      expect(c.reasoning).toContain('demographic projection modeling');
    });

    it('T4_C11: marks permanent 1.5C Paris breach claim as misleading (WMO + Copernicus)', () => {
      const c = results.find((r) => r.id === 'T4_C11')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('misleading');
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('sustained 20-year climatological average');
    });

    it('T4_C12: verifies live named institution monetary rate (RBI Repo 6.50%) triangulated with BIS', () => {
      const c = results.find((r) => r.id === 'T4_C12')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('verified_true');
      expect(c.confidence).toBe(0.95);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('Reserve Bank of India (RBI) Monetary Policy Committee');
      expect(c.reasoning).toContain('6.50%');
    });
  });

  describe('Tier 5: Adversarial, Unverifiable & Geopolitically Contested Claims', () => {
    it('T5_C13: refutes spurious precision on active conflict casualty figures (UN OHCHR + Amnesty + ACLED)', () => {
      const c = results.find((r) => r.id === 'T5_C13')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('unproven');
      expect(c.auditChecklist.confidenceCalibration).toBe(true);
      expect(c.confidence).toBeLessThanOrEqual(0.80); // Strict calibration
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('Mariupol');
    });

    it('T5_C14: strictly calibrates confidence (<=80%) on speculative future AGI prediction (OECD + WEF)', () => {
      const c = results.find((r) => r.id === 'T5_C14')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('unproven');
      expect(c.confidence).toBeLessThanOrEqual(0.80);
      expect(c.claimFactualProbability).toBeNull(); // N/A for speculative forecasts
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
    });

    it('T5_C15: rejects unauthenticated leaked audio allegation requiring C2PA provenance (C2PA + Sensity)', () => {
      const c = results.find((r) => r.id === 'T5_C15')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('unproven');
      expect(c.confidence).toBeLessThanOrEqual(0.80);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.reasoning).toContain('cryptographic media provenance');
    });

    it('T5_C16: BLIND RETRACTION TEST: identifies retracted Lancet COVID study without prompt leakage (Retraction Watch + Lancet)', () => {
      const c = results.find((r) => r.id === 'T5_C16')!;
      expect(c).toBeDefined();
      expect(c.actualVerdict).toBe('false_claim');
      expect(c.confidence).toBe(0.99);
      expect(c.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      expect(c.primarySourceTitle).toContain('Retraction Watch');
      expect(c.reasoning).toContain('formally retracted by The Lancet');
      expect(c.reasoning).toContain('Surgisphere');
    });
  });

  describe('5-Point Bottom-Line Audit Checklist Compliance', () => {
    it('achieves 100% Claim Decomposition Rate', () => {
      expect(summary.checklistScores.claimDecompositionRate).toBe(100.0);
    });

    it('achieves 100% Source Diversity & Multi-Source Triangulation Rate', () => {
      expect(summary.checklistScores.sourceDiversityRate).toBe(100.0);
      for (const r of results) {
        expect(r.triangulatedSources.length).toBeGreaterThanOrEqual(2);
      }
    });

    it('achieves 100% Strict Confidence Calibration Rate across all tiers', () => {
      expect(summary.checklistScores.confidenceCalibrationRate).toBe(100.0);
    });

    it('achieves 100% Explainability & Citations Rate', () => {
      expect(summary.checklistScores.explainabilityRate).toBe(100.0);
    });

    it('achieves 100% Audit Trail & Provenance Rate', () => {
      expect(summary.checklistScores.auditTrailRate).toBe(100.0);
    });

    it('achieves a Perfect 5.00 / 5.00 Average Composite Checklist Score', () => {
      expect(summary.checklistScores.meanCompositeScore).toBe(5.00);
    });
  });
});
