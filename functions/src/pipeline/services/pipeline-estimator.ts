/**
 * ⏱️ PIPELINE ESTIMATOR — Smart ETA Engine
 * 
 * Calculates estimated time-to-completion using nonlinear heuristics.
 * Future versions will use rolling medians from actual telemetry.
 */

import { ExecutionPlan } from "../types";

export type ETAMode = "cold" | "stable" | "high-variance";

export interface ETAEstimate {
  seconds: number;
  minSeconds: number;
  maxSeconds: number;
  mode: ETAMode;
}

export class PipelineEstimator {
  
  /**
   * Estimate duration for a specific stage.
   */
  estimateStageDuration(stage: string, duration: number, languages: number = 0): number {
    // Non-linear duration factor: larger videos take exponentially more time
    const durationFactor = Math.pow(duration, 1.1); 
    
    switch (stage) {
      case "upload": return 5;
      case "validation": return 5;
      case "queue": return 10;
      case "transcription": return durationFactor * 0.45;
      case "credibility": return durationFactor * 0.25;
      case "rendering": return 25 + (durationFactor * 0.20);
      case "finalizing": return 10;
      case "aggregation": return 5;
      default:
        if (stage.startsWith("translating_")) return 10;
        if (stage.startsWith("dubbing_")) return 20 + (durationFactor * 0.55);
        return 0;
    }
  }

  /**
   * Estimate total time for a full execution plan.
   */
  estimateTotal(duration: number, plan: ExecutionPlan, queueMultiplier: number = 1.0): ETAEstimate {
    let total = 0;
    
    // Base Stages
    total += this.estimateStageDuration("upload", duration);
    total += this.estimateStageDuration("validation", duration);
    total += this.estimateStageDuration("queue", duration);
    total += this.estimateStageDuration("transcription", duration);
    
    if (plan.enablePath1 || plan.enableTruthEngine) {
      total += this.estimateStageDuration("credibility", duration);
    }
    
    if (plan.enablePath2 || plan.enableReachEngine) {
      const targetLangs = (plan.languages ?? []).filter(l => l !== "en");
      for (const lang of targetLangs) {
        total += this.estimateStageDuration(`translating_${lang}`, duration);
        total += this.estimateStageDuration(`dubbing_${lang}`, duration);
      }
    }
    
    total += this.estimateStageDuration("rendering", duration);
    total += this.estimateStageDuration("finalizing", duration);
    
    // Apply queue multiplier (peak load factor)
    total = total * queueMultiplier;

    // Confidence bands (heuristic)
    const variance = total * 0.2; // 20% variance
    const mode: ETAMode = duration > 300 ? "high-variance" : "stable";

    return {
      seconds: Math.round(total),
      minSeconds: Math.round(total - variance),
      maxSeconds: Math.round(total + variance),
      mode
    };
  }
}

export const pipelineEstimator = new PipelineEstimator();
