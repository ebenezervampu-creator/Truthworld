/**
 * 🧪 TRUTHWORLD BENCHMARK SUITE — TYPE DEFINITIONS
 *
 * Types for the benchmark evaluation harness that measures
 * claim verification quality, routing correctness, and scoring fairness.
 */

import { ClaimStatus } from "../pipeline/types";

// ─── Dataset Types ───────────────────────────────────────────────────────────

export interface BenchmarkClaim {
  id:               string;
  claim:            string;
  domain:           string;
  type:             string;             // ClaimType from pipeline
  riskLevel:        number;             // 0-1 expected risk score
  groundTruth:      ClaimStatus;        // Human-reviewed correct label
  acceptableLabels: ClaimStatus[];      // Labels that are "close enough"
  severityIfWrong:  "low" | "medium" | "high" | "extreme";
  shouldUsePro:     boolean;            // Should this have been routed to Pro?
  notes:            string;             // Human reviewer reasoning
}

export interface BenchmarkDataset {
  version:     string;
  createdAt:   string;
  description: string;
  reviewers:   string[];
  claims:      BenchmarkClaim[];
}

// ─── Result Types ────────────────────────────────────────────────────────────

export interface ClaimResult {
  id:              string;
  claim:           string;
  domain:          string;
  groundTruth:     ClaimStatus;
  predictedLabel:  ClaimStatus;
  acceptableLabels: ClaimStatus[];
  confidence:      number;
  reasoning:       string;
  modelUsed:       string;
  wasRouted:       "flash" | "pro";
  shouldUsePro:    boolean;
  latencyMs:       number;

  // Scoring
  exactMatch:      boolean;     // predictedLabel === groundTruth
  acceptableMatch: boolean;     // predictedLabel in acceptableLabels
  routingCorrect:  boolean;     // wasRouted matches shouldUsePro
  isFalseAccusation: boolean;   // Marked incorrect but truth is correct/mostly_correct
  isFalseLeniency:   boolean;   // Marked correct but truth is incorrect
}

export interface BenchmarkRun {
  runId:        string;
  timestamp:    string;
  version:      string;           // Pipeline version (e.g., "v1.2.0")
  datasetVersion: string;
  config: {
    extractionModel:   string;
    verificationModel: string;
    groundingMode:     string;
  };
  results:  ClaimResult[];
  metrics:  BenchmarkMetrics;
  duration: number;               // Total benchmark time in ms
}

// ─── Metrics Types ───────────────────────────────────────────────────────────

export interface BenchmarkMetrics {
  // Model Accuracy
  accuracy: {
    exactMatchRate:        number;  // % exact label matches
    acceptableMatchRate:   number;  // % within acceptable label set
    highRiskAccuracy:      number;  // % correct for riskLevel > 0.7
    lowRiskAccuracy:       number;  // % correct for riskLevel <= 0.7
  };

  // Error Analysis
  errors: {
    falseAccusationRate:   number;  // % claims wrongly marked incorrect
    falseLeniencyRate:     number;  // % harmful claims wrongly marked correct
    totalMismatches:       number;  // Count of exact match failures
    worstMismatches:       ClaimResult[];  // Top 5 worst failures
  };

  // Routing Quality
  routing: {
    totalClaims:           number;
    routedToPro:           number;
    routedToFlash:         number;
    escalationRate:        number;  // % sent to Pro
    routingAccuracy:       number;  // % routing decisions correct
    missedEscalations:     number;  // Should've used Pro but didn't
    unnecessaryPro:        number;  // Used Pro when Flash was fine
  };

  // Label Distribution
  labelDistribution: {
    predicted: Record<string, number>;
    expected:  Record<string, number>;
  };

  // Domain Breakdown
  domainAccuracy: Record<string, {
    total:         number;
    exactMatch:    number;
    acceptableMatch: number;
    accuracy:      number;
  }>;

  // Nuance Recognition
  nuance: {
    mostlyCorrectRecognition: number;   // % of mostly_true claims caught
    inconclusiveRecognition:  number;   // % of inconclusive claims caught
    limitedSupportRecognition: number;  // % of limited_support claims caught
  };

  // Cost & Performance
  performance: {
    avgLatencyMs:       number;
    avgLatencyFlash:    number;
    avgLatencyPro:      number;
    estimatedCostPer100: number;  // USD estimate per 100 claims
  };

  // TruthWorld-Specific
  trustMetrics: {
    creatorHarmIndex:         number;  // How often creators unfairly penalized
    misinformationEscapeRate: number;  // Dangerous false claims marked safe
    nuanceRecognitionScore:   number;  // Overall nuance quality (0-1)
  };
}

// ─── Report Types ────────────────────────────────────────────────────────────

export interface RegressionComparison {
  previous:    BenchmarkRun;
  current:     BenchmarkRun;
  deltas: {
    exactAccuracy:     number;   // +/- percentage points
    acceptableAccuracy: number;
    falseAccusation:   number;
    falseLeniency:     number;
    routingAccuracy:   number;
    avgLatency:        number;
    costPer100:        number;
  };
  improved: string[];
  degraded: string[];
  unchanged: string[];
}
