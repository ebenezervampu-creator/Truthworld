/**
 * 💰 COST ENGINE — Real-time Cost Attribution & Unit Economics
 *
 * Central cost tracking for every AI API call in the pipeline.
 */

import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import { ChannelType } from "../types";

const db = () => admin.firestore();

// ─── Provider Rate Cards (USD) ──────────────────────────────────────────────

export const RATE_CARDS = {
  assemblyai: { perMinute: 0.039 },
  "google-translate-v3": { perCharacter: 0.000020 },
  elevenlabs: { perCharacter: 0.000030 },
  storage: { perGBMonth: 0.020 },
  ffmpeg: { perSecond: 0.0001 },
} as const;

// ─── Types ──────────────────────────────────────────────────────────────────

export interface CostEvent {
  jobId: string;
  userId: string;
  channelId?: string;
  stage: string;
  provider: string;
  amount: number;
  currency: "USD";
  unit: string;
  quantity: number;
  timestamp: number;
}

export interface CostRollup {
  userId: string;
  month: string; // "2026-04"
  channelType: ChannelType;
  totalCostUsd: number;
  jobCount: number;
  minutesProcessed: number;
  breakdown: Record<string, number>;
  lastUpdated: number;
}

// ─── CostEngine ─────────────────────────────────────────────────────────────

export class CostEngine {

  /**
   * Record an actual cost incurred by the pipeline.
   */
  async recordCost(
    jobId: string,
    userId: string,
    stage: string,
    provider: string,
    amount: number,
    unit: string = "units",
    quantity: number = 0
  ): Promise<void> {
    try {
      // 1. Fetch job to find channelId and channelType
      // Try both video_jobs and pipeline_jobs (backward compatibility)
      let jobDoc = await db().collection("video_jobs").doc(jobId).get();
      if (!jobDoc.exists) {
        jobDoc = await db().collection("pipeline_jobs").doc(jobId).get();
      }
      
      if (!jobDoc.exists) return;
      
      const jobData = jobDoc.data() as any;
      const channelId = jobData.channelId;
      const config = jobData.config || {};
      const channelType = config.channelType || 'standard';

      const event: CostEvent = {
        jobId,
        userId,
        channelId,
        stage,
        provider,
        amount: Math.round(amount * 1000000) / 1000000,
        currency: "USD",
        unit,
        quantity,
        timestamp: Date.now(),
      };

      // 1. Append to cost_events (audit trail)
      await db().collection("cost_events").add(event);

      // 2. Update rollup
      await this.updateRollup(userId, channelType, stage, amount);

      // 3. If Custom Channel, increment outstandingCosts
      if (channelType === 'custom' && channelId) {
        await db().collection("channels").doc(channelId).update({
          outstandingCosts: admin.firestore.FieldValue.increment(amount),
          updatedAt: Date.now(),
        });
      }

      logger.debug(`[CostEngine] Recorded $${amount.toFixed(6)} for ${channelType} channel ${channelId}`);
    } catch (err) {
      logger.error("[CostEngine] Failed to record cost", { jobId, err });
    }
  }

  // ─── Convenience Methods ────────────────────────────────────────────────

  async recordTranscriptionCost(jobId: string, userId: string, seconds: number): Promise<void> {
    const min = seconds / 60;
    const cost = min * RATE_CARDS.assemblyai.perMinute;
    await this.recordCost(jobId, userId, "transcription", "assemblyai", cost, "minutes", min);
  }

  async recordTranslationCost(jobId: string, userId: string, chars: number): Promise<void> {
    const cost = chars * RATE_CARDS["google-translate-v3"].perCharacter;
    await this.recordCost(jobId, userId, "translation", "google-translate-v3", cost, "characters", chars);
  }

  async recordTTSCost(jobId: string, userId: string, chars: number): Promise<void> {
    const cost = chars * RATE_CARDS.elevenlabs.perCharacter;
    await this.recordCost(jobId, userId, "tts", "elevenlabs", cost, "characters", chars);
  }

  async recordMediaCost(jobId: string, userId: string, seconds: number): Promise<void> {
    const cost = seconds * RATE_CARDS.ffmpeg.perSecond;
    await this.recordCost(jobId, userId, "media", "ffmpeg", cost, "seconds", seconds);
  }

  async recordJobAccepted(userId: string, channelType: string, minutes: number): Promise<void> {
    const monthKey = this.currentMonthKey();
    const rollupRef = db().collection("cost_rollups").doc(`${userId}_${monthKey}`);
    
    await rollupRef.set({
      jobCount: admin.firestore.FieldValue.increment(1),
      minutesProcessed: admin.firestore.FieldValue.increment(minutes),
      lastUpdated: Date.now(),
    }, { merge: true });
  }

  // ─── Dashboard APIs ─────────────────────────────────────────────────────

  async getCreatorDashboard(userId: string, month?: string): Promise<any | null> {
    const monthKey = month || this.currentMonthKey();
    const doc = await db().collection("cost_rollups").doc(`${userId}_${monthKey}`).get();
    return doc.exists ? doc.data() : null;
  }

  async getSystemOverview(month?: string): Promise<any> {
    const monthKey = month || this.currentMonthKey();
    const snap = await db().collection("cost_rollups").where("month", "==", monthKey).get();
    
    let total = 0;
    let jobs = 0;
    snap.forEach(doc => {
      total += doc.data().totalCostUsd || 0;
      jobs += doc.data().jobCount || 0;
    });

    return { month: monthKey, totalCostUsd: total, totalJobs: jobs, creators: snap.size };
  }

  async getJobBreakdown(jobId: string): Promise<any | null> {
    const snap = await db().collection("cost_events").where("jobId", "==", jobId).get();
    if (snap.empty) return null;

    const items = snap.docs.map(doc => doc.data());
    const total = items.reduce((sum, item) => sum + (item.amount || 0), 0);
    
    return { jobId, totalCostUsd: total, lineItems: items };
  }

  private async updateRollup(userId: string, channelType: ChannelType, stage: string, amount: number): Promise<void> {
    const monthKey = this.currentMonthKey();
    const rollupRef = db().collection("cost_rollups").doc(`${userId}_${monthKey}`);

    await rollupRef.set({
      userId,
      month: monthKey,
      channelType,
      totalCostUsd: admin.firestore.FieldValue.increment(amount),
      [`breakdown.${stage}`]: admin.firestore.FieldValue.increment(amount),
      lastUpdated: Date.now(),
    }, { merge: true });
  }

  private currentMonthKey(): string {
    const d = new Date();
    return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
  }

  // Quota check (Legacy but kept for EdgeLayer)
  async checkQuota(userId: string, channelType: string, estimatedMinutes: number): Promise<{ allowed: boolean; reason?: string }> {
    return { allowed: true }; // Unlimited for now under new model
  }
}

export const costEngine = new CostEngine();
