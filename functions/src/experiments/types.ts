/**
 * 🧪 EXPERIMENT TYPES — A/B Testing Framework
 *
 * Shared types for TruthWorld's recommendation experimentation system.
 * Supports multi-variant testing with deterministic user bucketing
 * and statistical significance analysis.
 */

import { FieldValue } from "firebase-admin/firestore";

// ─── Experiment Definition ──────────────────────────────────────────────────

export type ExperimentStatus = "draft" | "active" | "paused" | "completed" | "graduated";

export interface AlgorithmWeights {
  engagement: number;
  freshness: number;
  channelAffinity: number;
  topicAffinity: number;
  twoTowerAffinity: number;
  trending: number;
  credibility: number;
  watchCompletion: number;
}

export interface ExperimentVariant {
  /** Unique variant ID (e.g., "control", "variant_a", "variant_b") */
  variantId: string;
  /** Human-readable name */
  name: string;
  /** Algorithm weights for this variant */
  weights: AlgorithmWeights;
  /** Traffic allocation percentage (0-100). All variants must sum to 100. */
  trafficPercent: number;
  /** Whether this is the control (baseline) variant */
  isControl: boolean;
}

export interface Experiment {
  experimentId: string;
  name: string;
  description: string;
  hypothesis: string;
  /** Algorithm surface being tested (e.g., "homeFeed", "relatedVideos") */
  surface: "homeFeed" | "relatedVideos" | "trending" | "discover";
  status: ExperimentStatus;
  variants: ExperimentVariant[];
  /** Minimum sample size per variant before analysis is valid */
  minSampleSize: number;
  /** Minimum experiment duration in hours */
  minDurationHours: number;
  /** Primary metric to optimize */
  primaryMetric: MetricType;
  /** Secondary metrics to monitor */
  secondaryMetrics: MetricType[];
  createdBy: string;
  createdAt: FieldValue;
  startedAt?: FieldValue;
  completedAt?: FieldValue;
  graduatedVariantId?: string;
  updatedAt: FieldValue;
}

// ─── Metric Tracking ────────────────────────────────────────────────────────

export type MetricType =
  | "impressions"
  | "clicks"
  | "ctr"
  | "watch_time_seconds"
  | "avg_watch_time"
  | "completion_rate"
  | "like_rate"
  | "return_24h"
  | "session_depth";

export interface ExperimentMetricEvent {
  experimentId: string;
  variantId: string;
  userId: string;
  metricType: MetricType;
  value: number;
  videoId?: string;
  timestamp: FieldValue;
}

// ─── Analysis Results ───────────────────────────────────────────────────────

export interface VariantMetrics {
  variantId: string;
  name: string;
  sampleSize: number;
  impressions: number;
  clicks: number;
  ctr: number;
  totalWatchTimeSeconds: number;
  avgWatchTimeSeconds: number;
  completions: number;
  completionRate: number;
  likes: number;
  likeRate: number;
  returns24h: number;
  returnRate: number;
  avgSessionDepth: number;
}

export interface SignificanceResult {
  /** Z-score of the difference */
  zScore: number;
  /** Two-tailed p-value */
  pValue: number;
  /** Whether the result is statistically significant at 95% confidence */
  isSignificant: boolean;
  /** Relative improvement of treatment over control */
  relativeImprovement: number;
  /** 95% confidence interval for relative improvement */
  confidenceInterval: { lower: number; upper: number };
}

export interface ExperimentAnalysis {
  experimentId: string;
  analyzedAt: FieldValue;
  variantMetrics: VariantMetrics[];
  significance: Record<string, SignificanceResult>; // keyed by variantId (vs control)
  recommendation: "continue" | "graduate_treatment" | "stop_negative" | "insufficient_data";
  recommendationReason: string;
  primaryMetricWinner?: string;
}

// ─── Bucketing ──────────────────────────────────────────────────────────────

export interface UserBucketAssignment {
  experimentId: string;
  variantId: string;
  bucketNumber: number;
  weights: AlgorithmWeights;
}

// ─── Constants ──────────────────────────────────────────────────────────────

/** Default algorithm weights (production baseline) */
export const DEFAULT_WEIGHTS: AlgorithmWeights = {
  engagement: 0.18,
  freshness: 0.13,
  channelAffinity: 0.10,
  topicAffinity: 0.18,
  twoTowerAffinity: 0.15,
  trending: 0.10,
  credibility: 0.08,
  watchCompletion: 0.05,
};

/** Minimum confidence level for statistical significance */
export const SIGNIFICANCE_THRESHOLD = 0.05; // p < 0.05 = 95% confidence

/** Z-score for 95% confidence interval */
export const Z_95 = 1.96;
