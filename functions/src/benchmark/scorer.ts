/**
 * 🧮 TRUTHWORLD BENCHMARK SCORER
 *
 * Computes all metrics from benchmark results:
 * - Model accuracy (exact + acceptable)
 * - Error analysis (false accusations, false leniency)
 * - Routing quality
 * - Domain breakdown
 * - Nuance recognition
 * - Cost/performance estimates
 * - TruthWorld-specific trust metrics
 */

import { ClaimResult, BenchmarkMetrics } from "./types";
import { ClaimStatus } from "../pipeline/types";

/** Statuses that should NEVER be marked safe if actually harmful */
const HARMFUL_STATUSES: ClaimStatus[] = ["incorrect", "historical_consensus_denial", "incorrect_citation"];

/** Statuses that count as "correct-ish" — penalizing these unfairly hurts creators */
const SAFE_STATUSES: ClaimStatus[] = ["correct", "mostly_correct", "faith_context", "tradition_linked", "historical_tradition", "opinion", "satire"];

/** Nuanced labels that distinguish TruthWorld from binary fact-checkers */
const NUANCE_LABELS: ClaimStatus[] = ["mostly_correct", "outdated", "needs_context", "unsupported"];

export class BenchmarkScorer {

  /**
   * Compute all metrics from a set of claim results
   */
  score(results: ClaimResult[]): BenchmarkMetrics {
    return {
      accuracy:          this.computeAccuracy(results),
      errors:            this.computeErrors(results),
      routing:           this.computeRouting(results),
      labelDistribution: this.computeLabelDistribution(results),
      domainAccuracy:    this.computeDomainAccuracy(results),
      nuance:            this.computeNuance(results),
      performance:       this.computePerformance(results),
      trustMetrics:      this.computeTrustMetrics(results),
    };
  }

  // ─── Accuracy ────────────────────────────────────────────────────────────

  private computeAccuracy(results: ClaimResult[]) {
    const total = results.length;
    if (total === 0) return { exactMatchRate: 0, acceptableMatchRate: 0, highRiskAccuracy: 0, lowRiskAccuracy: 0 };

    const exactMatches     = results.filter(r => r.exactMatch).length;
    const acceptableMatches = results.filter(r => r.acceptableMatch).length;

    const highRisk = results.filter(r => {
      // Find original claim data — use shouldUsePro as proxy for high risk
      return r.shouldUsePro;
    });
    const highRiskCorrect = highRisk.filter(r => r.acceptableMatch).length;

    const lowRisk = results.filter(r => !r.shouldUsePro);
    const lowRiskCorrect = lowRisk.filter(r => r.acceptableMatch).length;

    return {
      exactMatchRate:      Math.round((exactMatches / total) * 1000) / 10,
      acceptableMatchRate: Math.round((acceptableMatches / total) * 1000) / 10,
      highRiskAccuracy:    highRisk.length > 0 ? Math.round((highRiskCorrect / highRisk.length) * 1000) / 10 : 0,
      lowRiskAccuracy:     lowRisk.length > 0 ? Math.round((lowRiskCorrect / lowRisk.length) * 1000) / 10 : 0,
    };
  }

  // ─── Error Analysis ──────────────────────────────────────────────────────

  private computeErrors(results: ClaimResult[]) {
    const falseAccusations = results.filter(r => r.isFalseAccusation);
    const falseLeniency    = results.filter(r => r.isFalseLeniency);
    const mismatches       = results.filter(r => !r.exactMatch);

    // Sort mismatches by severity — worst first
    const worstMismatches = [...mismatches]
      .sort((a, b) => {
        // Prioritize Pro-worthy claims (high risk) as worst mismatches
        return (b.shouldUsePro ? 3 : 1) - (a.shouldUsePro ? 3 : 1);
      })
      .slice(0, 5);

    return {
      falseAccusationRate: results.length > 0
        ? Math.round((falseAccusations.length / results.length) * 1000) / 10
        : 0,
      falseLeniencyRate: results.length > 0
        ? Math.round((falseLeniency.length / results.length) * 1000) / 10
        : 0,
      totalMismatches: mismatches.length,
      worstMismatches,
    };
  }

  // ─── Routing Quality ─────────────────────────────────────────────────────

  private computeRouting(results: ClaimResult[]) {
    const total        = results.length;
    const routedToPro  = results.filter(r => r.wasRouted === "pro").length;
    const routedToFlash = total - routedToPro;

    const routingCorrect    = results.filter(r => r.routingCorrect).length;
    const missedEscalations = results.filter(r => r.shouldUsePro && r.wasRouted === "flash").length;
    const unnecessaryPro    = results.filter(r => !r.shouldUsePro && r.wasRouted === "pro").length;

    return {
      totalClaims:     total,
      routedToPro,
      routedToFlash,
      escalationRate:  total > 0 ? Math.round((routedToPro / total) * 1000) / 10 : 0,
      routingAccuracy: total > 0 ? Math.round((routingCorrect / total) * 1000) / 10 : 0,
      missedEscalations,
      unnecessaryPro,
    };
  }

  // ─── Label Distribution ──────────────────────────────────────────────────

  private computeLabelDistribution(results: ClaimResult[]) {
    const predicted: Record<string, number> = {};
    const expected: Record<string, number> = {};

    results.forEach(r => {
      predicted[r.predictedLabel] = (predicted[r.predictedLabel] || 0) + 1;
      expected[r.groundTruth]     = (expected[r.groundTruth] || 0) + 1;
    });

    return { predicted, expected };
  }

  // ─── Domain Breakdown ────────────────────────────────────────────────────

  private computeDomainAccuracy(results: ClaimResult[]) {
    const domains: Record<string, { total: number; exactMatch: number; acceptableMatch: number; accuracy: number }> = {};

    results.forEach(r => {
      if (!domains[r.domain]) {
        domains[r.domain] = { total: 0, exactMatch: 0, acceptableMatch: 0, accuracy: 0 };
      }
      domains[r.domain].total++;
      if (r.exactMatch) domains[r.domain].exactMatch++;
      if (r.acceptableMatch) domains[r.domain].acceptableMatch++;
    });

    Object.keys(domains).forEach(d => {
      domains[d].accuracy = domains[d].total > 0
        ? Math.round((domains[d].acceptableMatch / domains[d].total) * 1000) / 10
        : 0;
    });

    return domains;
  }

  // ─── Nuance Recognition ──────────────────────────────────────────────────

  private computeNuance(results: ClaimResult[]) {
    const nuanceCheck = (label: ClaimStatus) => {
      const expected = results.filter(r => r.groundTruth === label);
      if (expected.length === 0) return 100;
      const caught = expected.filter(r => r.acceptableMatch);
      return Math.round((caught.length / expected.length) * 1000) / 10;
    };

    return {
      mostlyCorrectRecognition: nuanceCheck("mostly_correct"),
      outdatedRecognition:       nuanceCheck("outdated"),
      needsContextRecognition:   nuanceCheck("needs_context"),
      unsupportedRecognition:    nuanceCheck("unsupported"),
    };
  }

  // ─── Performance ─────────────────────────────────────────────────────────

  private computePerformance(results: ClaimResult[]) {
    const latencies     = results.map(r => r.latencyMs).filter(l => l > 0);
    const flashLatencies = results.filter(r => r.wasRouted === "flash").map(r => r.latencyMs).filter(l => l > 0);
    const proLatencies   = results.filter(r => r.wasRouted === "pro").map(r => r.latencyMs).filter(l => l > 0);

    const avg = (arr: number[]) => arr.length > 0 ? Math.round(arr.reduce((a, b) => a + b, 0) / arr.length) : 0;

    // Cost estimation: Flash ~$0.001/claim, Pro ~$0.008/claim
    const flashCount = results.filter(r => r.wasRouted === "flash").length;
    const proCount   = results.filter(r => r.wasRouted === "pro").length;
    const totalCost  = (flashCount * 0.001) + (proCount * 0.008);
    const costPer100 = results.length > 0 ? Math.round((totalCost / results.length) * 100 * 1000) / 1000 : 0;

    return {
      avgLatencyMs:    avg(latencies),
      avgLatencyFlash: avg(flashLatencies),
      avgLatencyPro:   avg(proLatencies),
      estimatedCostPer100: costPer100,
    };
  }

  // ─── TruthWorld-Specific Trust Metrics ────────────────────────────────────

  private computeTrustMetrics(results: ClaimResult[]) {
    // Creator Harm Index: % of safe claims wrongly penalized
    const safeClaims       = results.filter(r => SAFE_STATUSES.includes(r.groundTruth));
    const unfairlyPenalized = safeClaims.filter(r =>
      HARMFUL_STATUSES.includes(r.predictedLabel)
    );
    const creatorHarmIndex = safeClaims.length > 0
      ? Math.round((unfairlyPenalized.length / safeClaims.length) * 1000) / 10
      : 0;

    // Misinformation Escape Rate: % of harmful claims marked safe
    const harmfulClaims    = results.filter(r => HARMFUL_STATUSES.includes(r.groundTruth));
    const escapedHarmful    = harmfulClaims.filter(r =>
      SAFE_STATUSES.includes(r.predictedLabel)
    );
    const misinformationEscapeRate = harmfulClaims.length > 0
      ? Math.round((escapedHarmful.length / harmfulClaims.length) * 1000) / 10
      : 0;

    // Nuance Recognition Score: How well the system uses non-binary labels
    const nuanceClaims      = results.filter(r => NUANCE_LABELS.includes(r.groundTruth));
    const nuanceCaught      = nuanceClaims.filter(r => r.acceptableMatch);
    const nuanceRecognitionScore = nuanceClaims.length > 0
      ? Math.round((nuanceCaught.length / nuanceClaims.length) * 100) / 100
      : 0;

    return {
      creatorHarmIndex,
      misinformationEscapeRate,
      nuanceRecognitionScore,
    };
  }
}
