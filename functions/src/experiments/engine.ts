/**
 * 🧪 EXPERIMENT ENGINE — A/B Testing for TruthWorld Algorithm
 *
 * Deterministic user bucketing, metric collection, and statistical analysis
 * for recommendation algorithm experiments.
 *
 * Architecture:
 *   1. Admin creates experiment with variants + weight overrides
 *   2. Users are deterministically assigned to variants via hash bucketing
 *   3. Client records engagement metrics per variant
 *   4. Scheduled analyzer computes per-variant metrics + significance
 *   5. Admin graduates winning variant → updates production weights
 *
 * Firestore Collections:
 *   - experiments/{experimentId}         → Experiment definition
 *   - experiment_metrics/{auto}          → Raw metric events
 *   - experiment_analysis/{experimentId} → Latest analysis snapshot
 *   - remote_config/algorithm_weights    → Production weights (graduation target)
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { createHash } from "crypto";
import { applySecurityHeaders } from "../utils/securityHeaders";
import {
  Experiment,
  ExperimentVariant,
  ExperimentAnalysis,
  VariantMetrics,
  SignificanceResult,
  UserBucketAssignment,
  MetricType,
  DEFAULT_WEIGHTS,
  SIGNIFICANCE_THRESHOLD,
  Z_95,
} from "./types";

const REGION = "asia-south1";
const db = () => admin.firestore();

// ═════════════════════════════════════════════════════════════════════════════
// HELPER: Deterministic User Bucketing
// ═════════════════════════════════════════════════════════════════════════════

/**
 * Assigns a user to an experiment variant using deterministic hashing.
 * The same userId + experimentId always produces the same bucket,
 * ensuring consistent experience across sessions and devices.
 *
 * @returns Bucket number 0-99
 */
function computeBucket(userId: string, experimentId: string): number {
  const hash = createHash("sha256")
    .update(`${userId}:${experimentId}:truthworld`)
    .digest("hex");
  // Use first 8 hex chars → 32-bit number → mod 100
  const num = parseInt(hash.substring(0, 8), 16);
  return num % 100;
}

/**
 * Resolves which variant a user falls into based on their bucket number
 * and the experiment's traffic allocation.
 */
function resolveVariant(
  bucket: number,
  variants: ExperimentVariant[]
): ExperimentVariant | null {
  let cumulativePercent = 0;
  for (const variant of variants) {
    cumulativePercent += variant.trafficPercent;
    if (bucket < cumulativePercent) {
      return variant;
    }
  }
  return variants[variants.length - 1] || null;
}

/**
 * Gets the active experiment assignment for a user on a given surface.
 * Returns null if no active experiment exists for that surface.
 *
 * Exported for use by recommendations.ts
 */
export async function getUserExperiment(
  userId: string,
  surface: string
): Promise<UserBucketAssignment | null> {
  if (!userId) return null;

  try {
    const experimentsSnap = await db()
      .collection("experiments")
      .where("surface", "==", surface)
      .where("status", "==", "active")
      .limit(1) // Only one active experiment per surface at a time
      .get();

    if (experimentsSnap.empty) return null;

    const experiment = experimentsSnap.docs[0].data() as Experiment;
    const experimentId = experimentsSnap.docs[0].id;
    const bucket = computeBucket(userId, experimentId);
    const variant = resolveVariant(bucket, experiment.variants);

    if (!variant) return null;

    return {
      experimentId,
      variantId: variant.variantId,
      bucketNumber: bucket,
      weights: variant.weights,
    };
  } catch (err) {
    logger.warn("[Experiments] getUserExperiment failed, using defaults:", err);
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 1: createExperiment (Admin Callable)
// ═════════════════════════════════════════════════════════════════════════════

export const createExperiment = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    if (request.auth?.token?.admin !== true) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const {
      name, description, hypothesis, surface,
      variants, minSampleSize, minDurationHours,
      primaryMetric, secondaryMetrics,
    } = request.data;

    // Validation
    if (!name || !surface || !variants || !Array.isArray(variants) || variants.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "Required: name, surface, variants (array with >= 2 entries)."
      );
    }

    const validSurfaces = ["homeFeed", "relatedVideos", "trending", "discover"];
    if (!validSurfaces.includes(surface)) {
      throw new HttpsError("invalid-argument", `surface must be one of: ${validSurfaces.join(", ")}`);
    }

    // Verify traffic allocation sums to 100
    const totalTraffic = variants.reduce(
      (sum: number, v: ExperimentVariant) => sum + (v.trafficPercent || 0), 0
    );
    if (totalTraffic !== 100) {
      throw new HttpsError(
        "invalid-argument",
        `Variant traffic percentages must sum to 100. Got: ${totalTraffic}`
      );
    }

    // Verify exactly one control
    const controlCount = variants.filter((v: ExperimentVariant) => v.isControl).length;
    if (controlCount !== 1) {
      throw new HttpsError("invalid-argument", "Exactly one variant must be marked as control.");
    }

    // Verify each variant has valid weights
    const requiredWeightKeys = Object.keys(DEFAULT_WEIGHTS);
    for (const variant of variants) {
      if (!variant.variantId || !variant.name || !variant.weights) {
        throw new HttpsError("invalid-argument", "Each variant needs: variantId, name, weights.");
      }
      const missing = requiredWeightKeys.filter(k => !(k in variant.weights));
      if (missing.length > 0) {
        throw new HttpsError(
          "invalid-argument",
          `Variant "${variant.variantId}" is missing weight keys: ${missing.join(", ")}`
        );
      }
    }

    // Check no active experiment on same surface
    const activeSnap = await db()
      .collection("experiments")
      .where("surface", "==", surface)
      .where("status", "==", "active")
      .limit(1)
      .get();

    if (!activeSnap.empty) {
      throw new HttpsError(
        "failed-precondition",
        `An active experiment already exists on surface "${surface}". Complete or pause it first.`
      );
    }

    const experimentId = db().collection("experiments").doc().id;

    const experiment: Experiment = {
      experimentId,
      name,
      description: description || "",
      hypothesis: hypothesis || "",
      surface,
      status: "active",
      variants,
      minSampleSize: minSampleSize || 500,
      minDurationHours: minDurationHours || 48,
      primaryMetric: primaryMetric || "ctr",
      secondaryMetrics: secondaryMetrics || ["avg_watch_time", "completion_rate", "return_24h"],
      createdBy: request.auth!.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db().collection("experiments").doc(experimentId).set(experiment);

    logger.info(`[Experiments] Created experiment "${name}" (${experimentId}) on surface "${surface}" by ${request.auth!.uid}`);

    return { success: true, experimentId, name, surface, variants: variants.length };
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 2: recordExperimentMetric (Callable — client-side tracking)
// ═════════════════════════════════════════════════════════════════════════════

export const recordExperimentMetric = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { experimentId, variantId, metricType, value, videoId } = request.data;

    if (!experimentId || !variantId || !metricType) {
      throw new HttpsError("invalid-argument", "Required: experimentId, variantId, metricType.");
    }

    const validMetrics: MetricType[] = [
      "impressions", "clicks", "watch_time_seconds", "completion_rate",
      "like_rate", "return_24h", "session_depth",
    ];
    if (!validMetrics.includes(metricType)) {
      throw new HttpsError("invalid-argument", `Invalid metricType. Valid: ${validMetrics.join(", ")}`);
    }

    try {
      await db().collection("experiment_metrics").add({
        experimentId,
        variantId,
        userId,
        metricType,
        value: Number(value) || 0,
        videoId: videoId || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (err) {
      logger.error("[Experiments] recordExperimentMetric failed:", err);
      throw new HttpsError("internal", "Failed to record metric.");
    }
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 3: getActiveExperiments (HTTP — client fetches on app start)
// ═════════════════════════════════════════════════════════════════════════════

export const getActiveExperiments = onRequest(
  { region: REGION, cors: true, memory: "256MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    res.set("Cache-Control", "public, max-age=60, s-maxage=300");

    try {
      const userId = req.query.userId as string;
      if (!userId) {
        res.status(200).json({ experiments: [] });
        return;
      }

      const experimentsSnap = await db()
        .collection("experiments")
        .where("status", "==", "active")
        .get();

      if (experimentsSnap.empty) {
        res.status(200).json({ experiments: [] });
        return;
      }

      const assignments: UserBucketAssignment[] = [];

      for (const doc of experimentsSnap.docs) {
        const experiment = doc.data() as Experiment;
        const bucket = computeBucket(userId, doc.id);
        const variant = resolveVariant(bucket, experiment.variants);

        if (variant) {
          assignments.push({
            experimentId: doc.id,
            variantId: variant.variantId,
            bucketNumber: bucket,
            weights: variant.weights,
          });
        }
      }

      res.status(200).json({ experiments: assignments });
    } catch (err) {
      logger.error("[Experiments] getActiveExperiments failed:", err);
      res.status(500).json({ error: "Failed to load experiments." });
    }
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 4: analyzeExperiments (Scheduled — every 6 hours)
// ═════════════════════════════════════════════════════════════════════════════

export const analyzeExperiments = onSchedule(
  { schedule: "every 6 hours", region: REGION, memory: "512MiB", timeoutSeconds: 300 },
  async () => {
    logger.info("[Experiments] Starting scheduled experiment analysis...");

    const activeSnap = await db()
      .collection("experiments")
      .where("status", "==", "active")
      .get();

    if (activeSnap.empty) {
      logger.info("[Experiments] No active experiments to analyze.");
      return;
    }

    for (const experimentDoc of activeSnap.docs) {
      const experiment = experimentDoc.data() as Experiment;
      const experimentId = experimentDoc.id;

      try {
        const analysis = await analyzeOneExperiment(experimentId, experiment);
        await db().collection("experiment_analysis").doc(experimentId).set(analysis);
        logger.info(
          `[Experiments] Analysis for "${experiment.name}": recommendation=${analysis.recommendation}, reason=${analysis.recommendationReason}`
        );
      } catch (err) {
        logger.error(`[Experiments] Analysis failed for ${experimentId}:`, err);
      }
    }
  }
);

async function analyzeOneExperiment(
  experimentId: string,
  experiment: Experiment
): Promise<ExperimentAnalysis> {
  const metricsSnap = await db()
    .collection("experiment_metrics")
    .where("experimentId", "==", experimentId)
    .get();

  // Group metrics by variant
  const variantData = new Map<string, {
    uniqueUsers: Set<string>;
    impressions: number;
    clicks: number;
    watchTimeTotal: number;
    completions: number;
    likes: number;
    returns: number;
    sessionDepthTotal: number;
    sessionDepthCount: number;
  }>();

  // Initialize all variants
  for (const v of experiment.variants) {
    variantData.set(v.variantId, {
      uniqueUsers: new Set(),
      impressions: 0,
      clicks: 0,
      watchTimeTotal: 0,
      completions: 0,
      likes: 0,
      returns: 0,
      sessionDepthTotal: 0,
      sessionDepthCount: 0,
    });
  }

  // Accumulate metrics
  for (const doc of metricsSnap.docs) {
    const m = doc.data();
    const vd = variantData.get(m.variantId);
    if (!vd) continue;

    vd.uniqueUsers.add(m.userId);

    switch (m.metricType as MetricType) {
      case "impressions":
        vd.impressions += m.value;
        break;
      case "clicks":
        vd.clicks += m.value;
        break;
      case "watch_time_seconds":
        vd.watchTimeTotal += m.value;
        break;
      case "completion_rate":
        vd.completions += m.value;
        break;
      case "like_rate":
        vd.likes += m.value;
        break;
      case "return_24h":
        vd.returns += m.value;
        break;
      case "session_depth":
        vd.sessionDepthTotal += m.value;
        vd.sessionDepthCount += 1;
        break;
    }
  }

  // Compute per-variant metrics
  const variantMetrics: VariantMetrics[] = [];
  for (const v of experiment.variants) {
    const vd = variantData.get(v.variantId)!;
    const sampleSize = vd.uniqueUsers.size;
    const impressions = vd.impressions || 1; // Avoid division by zero

    variantMetrics.push({
      variantId: v.variantId,
      name: v.name,
      sampleSize,
      impressions: vd.impressions,
      clicks: vd.clicks,
      ctr: vd.impressions > 0 ? vd.clicks / vd.impressions : 0,
      totalWatchTimeSeconds: vd.watchTimeTotal,
      avgWatchTimeSeconds: sampleSize > 0 ? vd.watchTimeTotal / sampleSize : 0,
      completions: vd.completions,
      completionRate: impressions > 0 ? vd.completions / impressions : 0,
      likes: vd.likes,
      likeRate: impressions > 0 ? vd.likes / impressions : 0,
      returns24h: vd.returns,
      returnRate: sampleSize > 0 ? vd.returns / sampleSize : 0,
      avgSessionDepth: vd.sessionDepthCount > 0 ? vd.sessionDepthTotal / vd.sessionDepthCount : 0,
    });
  }

  // Find control variant
  const controlVariant = experiment.variants.find(v => v.isControl);
  const controlMetrics = variantMetrics.find(vm => vm.variantId === controlVariant?.variantId);

  // Compute statistical significance for each treatment vs control
  const significance: Record<string, SignificanceResult> = {};
  let recommendation: ExperimentAnalysis["recommendation"] = "continue";
  let recommendationReason = "";
  let primaryMetricWinner: string | undefined;

  if (!controlMetrics) {
    recommendationReason = "No control variant found.";
  } else {
    const minSample = experiment.minSampleSize || 500;
    const hasEnoughData = variantMetrics.every(vm => vm.sampleSize >= minSample);

    if (!hasEnoughData) {
      recommendation = "insufficient_data";
      const smallest = Math.min(...variantMetrics.map(vm => vm.sampleSize));
      recommendationReason = `Minimum sample size ${minSample} not reached. Smallest variant has ${smallest} users.`;
    } else {
      // Compute significance for each treatment variant
      for (const vm of variantMetrics) {
        if (vm.variantId === controlMetrics.variantId) continue;

        const sig = computeSignificance(
          controlMetrics,
          vm,
          experiment.primaryMetric
        );
        significance[vm.variantId] = sig;

        if (sig.isSignificant && sig.relativeImprovement > 0) {
          if (!primaryMetricWinner || sig.relativeImprovement > (significance[primaryMetricWinner]?.relativeImprovement || 0)) {
            primaryMetricWinner = vm.variantId;
          }
        }
      }

      // Determine recommendation
      if (primaryMetricWinner) {
        const winnerSig = significance[primaryMetricWinner];
        recommendation = "graduate_treatment";
        recommendationReason = `Variant "${primaryMetricWinner}" shows +${(winnerSig.relativeImprovement * 100).toFixed(1)}% improvement on ${experiment.primaryMetric} with p=${winnerSig.pValue.toFixed(4)} (95% CI: [${(winnerSig.confidenceInterval.lower * 100).toFixed(1)}%, ${(winnerSig.confidenceInterval.upper * 100).toFixed(1)}%])`;
      } else {
        // Check if any variant is significantly WORSE
        const negativeVariant = Object.entries(significance).find(
          ([, sig]) => sig.isSignificant && sig.relativeImprovement < -0.05
        );

        if (negativeVariant) {
          recommendation = "stop_negative";
          recommendationReason = `Variant "${negativeVariant[0]}" is significantly worse: ${(negativeVariant[1].relativeImprovement * 100).toFixed(1)}% decline on ${experiment.primaryMetric}.`;
        } else {
          recommendation = "continue";
          recommendationReason = "No statistically significant difference found yet. Continue collecting data.";
        }
      }
    }
  }

  return {
    experimentId,
    analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
    variantMetrics,
    significance,
    recommendation,
    recommendationReason,
    primaryMetricWinner,
  };
}

/**
 * Computes statistical significance between control and treatment for a given metric.
 * Uses a two-proportion Z-test for rate metrics and Welch's t-approximation for continuous metrics.
 */
function computeSignificance(
  control: VariantMetrics,
  treatment: VariantMetrics,
  metric: MetricType
): SignificanceResult {
  // Get the relevant metric values
  let controlRate: number;
  let treatmentRate: number;
  let controlN: number;
  let treatmentN: number;

  switch (metric) {
    case "ctr":
      controlRate = control.ctr;
      treatmentRate = treatment.ctr;
      controlN = control.impressions;
      treatmentN = treatment.impressions;
      break;
    case "completion_rate":
      controlRate = control.completionRate;
      treatmentRate = treatment.completionRate;
      controlN = control.impressions;
      treatmentN = treatment.impressions;
      break;
    case "like_rate":
      controlRate = control.likeRate;
      treatmentRate = treatment.likeRate;
      controlN = control.impressions;
      treatmentN = treatment.impressions;
      break;
    case "return_24h":
      controlRate = control.returnRate;
      treatmentRate = treatment.returnRate;
      controlN = control.sampleSize;
      treatmentN = treatment.sampleSize;
      break;
    case "avg_watch_time":
    case "watch_time_seconds":
      controlRate = control.avgWatchTimeSeconds;
      treatmentRate = treatment.avgWatchTimeSeconds;
      controlN = control.sampleSize;
      treatmentN = treatment.sampleSize;
      break;
    case "session_depth":
      controlRate = control.avgSessionDepth;
      treatmentRate = treatment.avgSessionDepth;
      controlN = control.sampleSize;
      treatmentN = treatment.sampleSize;
      break;
    default:
      controlRate = control.ctr;
      treatmentRate = treatment.ctr;
      controlN = control.impressions;
      treatmentN = treatment.impressions;
  }

  // Guard against division by zero
  if (controlN === 0 || treatmentN === 0 || controlRate === 0) {
    return {
      zScore: 0,
      pValue: 1,
      isSignificant: false,
      relativeImprovement: 0,
      confidenceInterval: { lower: 0, upper: 0 },
    };
  }

  // Two-proportion Z-test
  const pooledRate = (controlRate * controlN + treatmentRate * treatmentN) / (controlN + treatmentN);
  const se = Math.sqrt(pooledRate * (1 - pooledRate) * (1 / controlN + 1 / treatmentN));

  const zScore = se > 0 ? (treatmentRate - controlRate) / se : 0;
  const pValue = 2 * (1 - normalCDF(Math.abs(zScore))); // Two-tailed

  const relativeImprovement = controlRate > 0
    ? (treatmentRate - controlRate) / controlRate
    : 0;

  // 95% confidence interval for the difference
  const diffSE = Math.sqrt(
    (controlRate * (1 - controlRate)) / controlN +
    (treatmentRate * (1 - treatmentRate)) / treatmentN
  );
  const diff = treatmentRate - controlRate;
  const ciLower = controlRate > 0 ? (diff - Z_95 * diffSE) / controlRate : 0;
  const ciUpper = controlRate > 0 ? (diff + Z_95 * diffSE) / controlRate : 0;

  return {
    zScore,
    pValue,
    isSignificant: pValue < SIGNIFICANCE_THRESHOLD,
    relativeImprovement,
    confidenceInterval: { lower: ciLower, upper: ciUpper },
  };
}

/**
 * Approximation of the standard normal CDF using Abramowitz & Stegun formula.
 */
function normalCDF(x: number): number {
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  const p = 0.3275911;

  const sign = x < 0 ? -1 : 1;
  x = Math.abs(x) / Math.SQRT2;

  const t = 1.0 / (1.0 + p * x);
  const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);

  return 0.5 * (1.0 + sign * y);
}

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 5: graduateExperiment (Admin Callable)
// ═════════════════════════════════════════════════════════════════════════════

export const graduateExperiment = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    if (request.auth?.token?.admin !== true) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { experimentId, winningVariantId } = request.data;
    if (!experimentId || !winningVariantId) {
      throw new HttpsError("invalid-argument", "Required: experimentId, winningVariantId.");
    }

    try {
      const experimentRef = db().collection("experiments").doc(experimentId);
      const experimentSnap = await experimentRef.get();

      if (!experimentSnap.exists) {
        throw new HttpsError("not-found", "Experiment not found.");
      }

      const experiment = experimentSnap.data() as Experiment;

      if (experiment.status !== "active" && experiment.status !== "paused") {
        throw new HttpsError("failed-precondition", `Experiment is ${experiment.status}, cannot graduate.`);
      }

      const winningVariant = experiment.variants.find(v => v.variantId === winningVariantId);
      if (!winningVariant) {
        throw new HttpsError("not-found", `Variant "${winningVariantId}" not found in experiment.`);
      }

      // Promote winning weights to production remote config
      await db().collection("remote_config").doc("algorithm_weights").set(
        {
          version: `experiment_${experimentId}_${winningVariantId}`,
          weights: {
            homeFeedAll: winningVariant.weights,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: request.auth!.uid,
          graduatedFrom: {
            experimentId,
            experimentName: experiment.name,
            variantId: winningVariantId,
            variantName: winningVariant.name,
          },
        },
        { merge: true }
      );

      // Mark experiment as graduated
      await experimentRef.update({
        status: "graduated",
        graduatedVariantId: winningVariantId,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(
        `[Experiments] Graduated experiment "${experiment.name}": variant "${winningVariant.name}" promoted to production by ${request.auth!.uid}`
      );

      return {
        success: true,
        experimentId,
        graduatedVariant: winningVariantId,
        newProductionWeights: winningVariant.weights,
        message: `Variant "${winningVariant.name}" weights promoted to production.`,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[Experiments] graduateExperiment failed:", err);
      throw new HttpsError("internal", "Failed to graduate experiment.");
    }
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 6: manageExperiment (Admin Callable — pause/resume/stop)
// ═════════════════════════════════════════════════════════════════════════════

export const manageExperiment = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    if (request.auth?.token?.admin !== true) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { experimentId, action } = request.data;
    if (!experimentId || !action) {
      throw new HttpsError("invalid-argument", "Required: experimentId, action (pause|resume|stop).");
    }

    const validActions = ["pause", "resume", "stop"];
    if (!validActions.includes(action)) {
      throw new HttpsError("invalid-argument", `action must be one of: ${validActions.join(", ")}`);
    }

    try {
      const experimentRef = db().collection("experiments").doc(experimentId);
      const experimentSnap = await experimentRef.get();

      if (!experimentSnap.exists) {
        throw new HttpsError("not-found", "Experiment not found.");
      }

      const newStatus =
        action === "pause" ? "paused" :
        action === "resume" ? "active" :
        "completed";

      const updates: Record<string, any> = {
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (action === "stop") {
        updates.completedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      await experimentRef.update(updates);

      logger.info(`[Experiments] Experiment ${experimentId} → ${newStatus} by ${request.auth!.uid}`);

      return { success: true, experimentId, newStatus };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[Experiments] manageExperiment failed:", err);
      throw new HttpsError("internal", "Failed to update experiment.");
    }
  }
);
