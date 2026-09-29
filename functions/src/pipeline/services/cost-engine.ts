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
  // ─── Gemini AI (Vertex AI pricing, USD per token) ───────────────────────
  "gemini-flash": { perInputToken: 0.00000015, perOutputToken: 0.0000006 },
  "gemini-pro": { perInputToken: 0.00000125, perOutputToken: 0.000005 },
  // ─── Google Search Grounding API ────────────────────────────────────────
  "search-grounding": { perQuery: 0.005 },
  // ─── Cloud Functions compute (USD per vCPU-second) ──────────────────────
  "cloud-functions": { perVCPUSecond: 0.0000100 },
  // ─── Firestore (USD per operation) ──────────────────────────────────────
  firestore: { perRead: 0.0000006, perWrite: 0.0000018 },
} as const;

// ─── Google Cloud CDN Egress Rate Cards (USD per GB, region-tiered) ─────────
export const CDN_RATE_CARDS = {
  india: 0.08,           // Asia-South1
  asiaPacific: 0.10,     // Other APAC
  europe: 0.08,          // EU
  northAmerica: 0.08,    // US/Canada
  southAmerica: 0.11,    // LATAM
  africa: 0.12,          // MEA
  default: 0.08,         // Fallback
} as const;

export const CHANNEL_DUBBING_PRICING = {
  standard: {
    ratePerLanguageUSD: 0.25,
    minCostUSD: 0.75,
    capCostUSD: 5.00,
    voiceCloneIncluded: false,
    tier: "raw_at_cost",
  },
  custom: {
    ratePerLanguageUSD: 0.25, // At-cost pass-through
    minCostUSD: 0.75,
    capCostUSD: 5.00,
    voiceCloneIncluded: true,
    tier: "raw_at_cost",
  },
} as const;

export interface DubbingDurationTier {
  id: string;
  label: string;
  minSeconds: number;
  maxSeconds: number;
  standardPriceUSD: number;
  customPriceUSD: number;
}

export const DUBBING_DURATION_TIERS: DubbingDurationTier[] = [
  {
    id: "shorts",
    label: "Shorts & Clips (≤ 60s)",
    minSeconds: 0,
    maxSeconds: 60,
    standardPriceUSD: 0.10,
    customPriceUSD: 0.10,
  },
  {
    id: "mini",
    label: "Mini Video (1–5 min)",
    minSeconds: 61,
    maxSeconds: 300,
    standardPriceUSD: 0.25,
    customPriceUSD: 0.25,
  },
  {
    id: "standard",
    label: "Standard Video (5–10 min)",
    minSeconds: 301,
    maxSeconds: 600,
    standardPriceUSD: 0.50,
    customPriceUSD: 0.50,
  },
  {
    id: "extended",
    label: "Extended Video (10–30 min)",
    minSeconds: 601,
    maxSeconds: 1800,
    standardPriceUSD: 1.25,
    customPriceUSD: 1.25,
  },
  {
    id: "long_form",
    label: "Long-Form Video (30–60 min)",
    minSeconds: 1801,
    maxSeconds: 3600,
    standardPriceUSD: 2.50,
    customPriceUSD: 2.50,
  },
];

export function getFlatDubbingPricePerLanguage(
  durationSeconds: number,
  channelType: "standard" | "custom" = "standard"
): number {
  if (durationSeconds <= 60) return 0.10;
  if (durationSeconds <= 300) return 0.25;
  if (durationSeconds <= 600) return 0.50;
  if (durationSeconds <= 1800) return 1.25;
  if (durationSeconds <= 3600) return 2.50;

  // Beyond 60 minutes: base 60 min price ($2.50) + $1.25 per 30m block (0% platform profit)
  const extraSeconds = durationSeconds - 3600;
  const extraBlocks = Math.ceil(extraSeconds / 1800);
  const basePrice = 2.50;
  const blockPrice = 1.25;
  return basePrice + extraBlocks * blockPrice;
}

export function calculateDubbingCost(
  languageCount: number,
  durationSeconds: number = 0,
  channelType: "standard" | "custom" = "standard"
): number {
  if (languageCount <= 0) return 0.0;
  if (durationSeconds > 0) {
    const flatPerLang = getFlatDubbingPricePerLanguage(durationSeconds, channelType);
    return Math.round(languageCount * flatPerLang * 100) / 100;
  }
  const pricing =
    CHANNEL_DUBBING_PRICING[channelType] || CHANNEL_DUBBING_PRICING.standard;
  const rawCost = languageCount * pricing.ratePerLanguageUSD;
  return Math.min(Math.max(rawCost, pricing.minCostUSD), pricing.capCostUSD);
}

export const CHANNEL_SUBTITLE_PRICING = {
  standard: {
    ratePerLanguageUSD: 0.05,
    minCostUSD: 0.05,
    capCostUSD: 2.50,
    tier: "raw_at_cost",
  },
  custom: {
    ratePerLanguageUSD: 0.05,
    minCostUSD: 0.05,
    capCostUSD: 2.50,
    tier: "raw_at_cost",
  },
} as const;

export interface SubtitleDurationTier {
  id: string;
  label: string;
  minSeconds: number;
  maxSeconds: number;
  standardPriceUSD: number;
  customPriceUSD: number;
}

export const SUBTITLE_DURATION_TIERS: SubtitleDurationTier[] = [
  {
    id: "mini",
    label: "Mini Video (2–5 min)",
    minSeconds: 120,
    maxSeconds: 300,
    standardPriceUSD: 0.025,
    customPriceUSD: 0.025,
  },
  {
    id: "standard",
    label: "Standard Video (5–10 min)",
    minSeconds: 301,
    maxSeconds: 600,
    standardPriceUSD: 0.05,
    customPriceUSD: 0.05,
  },
  {
    id: "extended",
    label: "Extended Video (10–30 min)",
    minSeconds: 601,
    maxSeconds: 1800,
    standardPriceUSD: 0.10,
    customPriceUSD: 0.10,
  },
  {
    id: "long_form",
    label: "Long-Form Video (30–60 min)",
    minSeconds: 1801,
    maxSeconds: 3600,
    standardPriceUSD: 0.20,
    customPriceUSD: 0.20,
  },
];

export function getFlatSubtitlePricePerLanguage(
  durationSeconds: number,
  channelType: "standard" | "custom" = "standard"
): number {
  if (durationSeconds <= 300) return 0.025;
  if (durationSeconds <= 600) return 0.05;
  if (durationSeconds <= 1800) return 0.10;
  if (durationSeconds <= 3600) return 0.20;

  // Beyond 60 minutes: base 60 min price ($0.20) + $0.075 per 30m block (0% platform profit)
  const extraSeconds = durationSeconds - 3600;
  const extraBlocks = Math.ceil(extraSeconds / 1800);
  const basePrice = 0.20;
  const blockPrice = 0.075;
  return Number((basePrice + extraBlocks * blockPrice).toFixed(3));
}

export function calculateSubtitleCost(
  languageCount: number,
  durationSeconds: number = 0,
  channelType: "standard" | "custom" = "standard"
): number {
  if (languageCount <= 0) return 0.0;
  const pricing =
    CHANNEL_SUBTITLE_PRICING[channelType] || CHANNEL_SUBTITLE_PRICING.standard;
  if (durationSeconds > 0) {
    const flatPerLang = getFlatSubtitlePricePerLanguage(durationSeconds, channelType);
    const rawCost = languageCount * flatPerLang;
    return Math.round(Math.max(pricing.minCostUSD, rawCost) * 100) / 100;
  }
  const rawCost = languageCount * pricing.ratePerLanguageUSD;
  return Math.min(Math.max(rawCost, pricing.minCostUSD), pricing.capCostUSD);
}

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
   * Helper to estimate data transfer egress in GB from streamed watch seconds and playback bitrate.
   */
  static estimateEgressGB(watchTimeSeconds: number, quality: string = "auto"): number {
    const bitratesMbps: Record<string, number> = {
      "2160p": 15.0,
      "4k": 15.0,
      "1440p": 8.0,
      "1080p": 3.5,
      "720p": 2.0,
      "480p": 1.0,
      "360p": 0.5,
      "240p": 0.3,
      "144p": 0.15,
      "audio": 0.128,
      "audio_only": 0.128,
      "auto": 2.0, // Blended streaming average (~2 Mbps)
    };
    const mbps = bitratesMbps[quality.toLowerCase()] ?? 2.0;
    // MB/s = mbps / 8. GB = (seconds * MB/s) / 1024
    return (watchTimeSeconds * (mbps / 8)) / 1024;
  }

  /**
   * Maps country code (ISO 3166-1 alpha-2) to the appropriate Google Cloud CDN egress pricing region.
   */
  static mapCountryToCDNRegion(countryCode: string): keyof typeof CDN_RATE_CARDS {
    const code = (countryCode || "").toUpperCase();
    if (code === "IN") return "india";
    if (["US", "CA", "MX"].includes(code)) return "northAmerica";
    if (["GB", "DE", "FR", "IT", "ES", "NL", "SE", "CH", "PL", "IE"].includes(code)) return "europe";
    if (["JP", "KR", "SG", "AU", "NZ", "ID", "MY", "TH", "VN", "PH"].includes(code)) return "asiaPacific";
    if (["BR", "AR", "CO", "CL", "PE"].includes(code)) return "southAmerica";
    if (["ZA", "EG", "NG", "KE", "AE", "SA"].includes(code)) return "africa";
    return "default";
  }

  /**
   * Record an actual cost incurred by the pipeline or media delivery.
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
      let resolvedUserId = userId;
      let channelId: string | undefined;
      let channelType: ChannelType = 'standard';

      // 1. Fetch job to find channelId and channelType
      // Try video_jobs and pipeline_jobs first
      let jobDoc = await db().collection("video_jobs").doc(jobId).get();
      if (!jobDoc.exists) {
        jobDoc = await db().collection("pipeline_jobs").doc(jobId).get();
      }

      if (jobDoc.exists) {
        const jobData = jobDoc.data() as any;
        channelId = jobData.channelId;
        const config = jobData.config || {};
        channelType = config.channelType || 'standard';
        resolvedUserId = resolvedUserId || jobData.userId || "system";
      } else {
        // Fallback 1: check if jobId is a videoId in the videos collection
        const videoDoc = await db().collection("videos").doc(jobId).get();
        if (videoDoc.exists) {
          const videoData = videoDoc.data() || {};
          channelId = videoData.channelId;
          resolvedUserId = resolvedUserId || videoData.userId || videoData.ownerId || "system";
          if (channelId) {
            const chDoc = await db().collection("channels").doc(channelId).get();
            if (chDoc.exists) {
              channelType = (chDoc.data()?.type || chDoc.data()?.channelType || 'standard') as ChannelType;
            }
          }
        } else {
          // Fallback 2: check if jobId is an ad campaignId
          const adDoc = await db().collection("ad_campaigns").doc(jobId).get();
          if (adDoc.exists) {
            const adData = adDoc.data() || {};
            channelId = adData.channelId;
            resolvedUserId = resolvedUserId || adData.userId || "advertiser";
          }
        }
      }

      if (!resolvedUserId) {
        resolvedUserId = "system";
      }

      const event: CostEvent = {
        jobId,
        userId: resolvedUserId,
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
      await this.updateRollup(resolvedUserId, channelType, stage, amount);

      // 3. If Custom Channel, increment outstandingCosts
      if (channelType === 'custom' && channelId) {
        await db().collection("channels").doc(channelId).update({
          outstandingCosts: admin.firestore.FieldValue.increment(amount),
          updatedAt: Date.now(),
        });
      }

      logger.debug(`[CostEngine] Recorded $${amount.toFixed(6)} for ${channelType} channel ${channelId || "unassigned"}`);
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

  // ─── Gemini AI Cost Tracking ──────────────────────────────────────────────

  /**
   * Record Gemini API cost from usageMetadata returned by generateContent().
   * @param modelTier - "flash" or "pro" to select the correct rate card
   * @param inputTokens - from response.response.usageMetadata?.promptTokenCount
   * @param outputTokens - from response.response.usageMetadata?.candidatesTokenCount
   */
  async recordGeminiCost(
    jobId: string,
    userId: string,
    stage: string,
    modelTier: "flash" | "pro",
    inputTokens: number,
    outputTokens: number
  ): Promise<void> {
    const rateCard = modelTier === "pro"
      ? RATE_CARDS["gemini-pro"]
      : RATE_CARDS["gemini-flash"];
    const cost = (inputTokens * rateCard.perInputToken) + (outputTokens * rateCard.perOutputToken);
    await this.recordCost(jobId, userId, stage, `gemini-${modelTier}`, cost, "tokens", inputTokens + outputTokens);
  }

  /**
   * Record Google Search Grounding API cost per query.
   * @param queryCount - number of grounding queries executed (typically 1 per claim)
   */
  async recordGroundingCost(jobId: string, userId: string, queryCount: number): Promise<void> {
    const cost = queryCount * RATE_CARDS["search-grounding"].perQuery;
    await this.recordCost(jobId, userId, "grounding", "search-grounding", cost, "queries", queryCount);
  }

  // ─── Infrastructure Cost Tracking ─────────────────────────────────────────

  /**
   * Record Google Cloud CDN egress cost for video delivery.
   * Called per-view or batched periodically from analytics.
   * @param egressGB - total egress in gigabytes
   * @param region - CDN region key (india, asiaPacific, europe, northAmerica, etc.)
   */
  async recordCDNCost(
    jobId: string,
    userId: string,
    egressGB: number,
    region: keyof typeof CDN_RATE_CARDS = "default"
  ): Promise<void> {
    const rate = CDN_RATE_CARDS[region] ?? CDN_RATE_CARDS.default;
    const cost = egressGB * rate;
    await this.recordCost(jobId, userId, "cdn_egress", `gcloud-cdn-${region}`, cost, "GB", egressGB);
  }

  /**
   * High-level method to calculate and record Google Cloud CDN delivery cost
   * from streamed watch time, resolution, and viewer country.
   */
  async recordStreamingEgress(
    videoId: string,
    userId: string,
    watchTimeSeconds: number,
    quality: string = "auto",
    countryCode: string = "IN"
  ): Promise<{ egressGB: number; costUSD: number; region: keyof typeof CDN_RATE_CARDS }> {
    if (watchTimeSeconds <= 0) return { egressGB: 0, costUSD: 0, region: "default" };
    const egressGB = CostEngine.estimateEgressGB(watchTimeSeconds, quality);
    const region = CostEngine.mapCountryToCDNRegion(countryCode);
    const rate = CDN_RATE_CARDS[region] ?? CDN_RATE_CARDS.default;
    const costUSD = Math.round(egressGB * rate * 1000000) / 1000000;

    await this.recordCost(videoId, userId, "cdn_egress", `gcloud-cdn-${region}`, costUSD, "GB", egressGB);
    return { egressGB, costUSD, region };
  }

  /**
   * Record Firestore read/write operation costs.
   * @param reads - number of document reads
   * @param writes - number of document writes
   */
  async recordFirestoreCost(jobId: string, userId: string, reads: number, writes: number): Promise<void> {
    const cost = (reads * RATE_CARDS.firestore.perRead) + (writes * RATE_CARDS.firestore.perWrite);
    await this.recordCost(jobId, userId, "firestore", "firestore", cost, "operations", reads + writes);
  }

  /**
   * Record Cloud Functions compute cost.
   * @param vCPUSeconds - total vCPU-seconds consumed by function execution
   */
  async recordComputeCost(jobId: string, userId: string, vCPUSeconds: number): Promise<void> {
    const cost = vCPUSeconds * RATE_CARDS["cloud-functions"].perVCPUSecond;
    await this.recordCost(jobId, userId, "compute", "cloud-functions", cost, "vCPU-seconds", vCPUSeconds);
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
    const snap = await db().collection("cost_rollups").where("month", "==", monthKey).limit(500).get();
    
    let total = 0;
    let jobs = 0;
    snap.forEach(doc => {
      total += doc.data().totalCostUsd || 0;
      jobs += doc.data().jobCount || 0;
    });

    return { month: monthKey, totalCostUsd: total, totalJobs: jobs, creators: snap.size };
  }

  async getJobBreakdown(jobId: string): Promise<any | null> {
    const snap = await db().collection("cost_events").where("jobId", "==", jobId).limit(100).get();
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
    if (channelType === "standard" && estimatedMinutes > 10) {
      return { allowed: false, reason: "Standard channel video duration cannot exceed 10 minutes" };
    }
    return { allowed: true };
  }
}

export const costEngine = new CostEngine();
