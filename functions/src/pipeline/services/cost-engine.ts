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
  assemblyai: { perMinute: 0.00383 }, // Universal-3.5 Pro ($0.21/hr) + Speaker Diarization ($0.02/hr) = $0.23/hr ($0.00383/min)
  "google-translate-v3": { perCharacter: 0.000020 },
  elevenlabs: { perCharacter: 0.000200 }, // ElevenLabs Creator/Pro tier ($0.20 / 1K chars)
  "google-tts-chirp3-hd": { perCharacter: 0.000030 },
  "google-tts-neural2": { perCharacter: 0.000016 },
  "google-tts-standard": { perCharacter: 0.000004 },
  storage: { perGBMonth: 0.020 },
  ffmpeg: { perSecond: 0.0001 },
  // ─── Gemini AI (Vertex AI pricing, USD per token) ───────────────────────
  "gemini-flash-lite": { perInputToken: 0.000000075, perOutputToken: 0.0000003 },
  "gemini-flash": { perInputToken: 0.00000015, perOutputToken: 0.0000006 },
  "gemini-reasoning": { perInputToken: 0.0000020, perOutputToken: 0.000010 }, // Gemini 4 Argon ($2.00 in / $10.00 out per 1M)
  "gemini-4-argon": { perInputToken: 0.0000020, perOutputToken: 0.000010 },
  "gemini-pro": { perInputToken: 0.00000125, perOutputToken: 0.000005 },
  "gemini-cached-read": { perToken: 0.0000001 }, // $0.10 per 1M for Argon implicit cache read
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
  voiceClonePriceUSD?: number;
}

export const PER_MINUTE_STANDARD_DUBBING_RATE = 0.10; // $1.00 for 10 mins ($0.10/min)
export const PER_MINUTE_VOICE_CLONE_RATE = 0.20;       // $2.00 for 10 mins ($0.20/min)
export const PER_MINUTE_LIP_SYNC_RATE = 0.30;          // $3.00 for 10 mins ($0.30/min)

export const DUBBING_TIER_RATES = {
  audio_starter: 0.10, // $1.00 for 10 mins ($0.10/min)
  audio_pro: 0.20,     // $2.00 for 10 mins ($0.20/min)
  audio_ultra: 0.30,   // $3.00 for 10 mins ($0.30/min)
  video_pro: 0.40,     // $4.00 for 10 mins ($0.40/min)
  video_ultra: 0.50,   // $5.00 for 10 mins ($0.50/min, Cinema Grade)
} as const;

export function getTierDubbingRatePerMinute(tierId: string): number {
  return (DUBBING_TIER_RATES as any)[tierId] ?? DUBBING_TIER_RATES.audio_starter;
}

export function getFlatDubbingPriceForTier(durationSeconds: number, tierId: string = "audio_starter"): number {
  const perMinuteRate = getTierDubbingRatePerMinute(tierId);
  if (!durationSeconds || durationSeconds <= 0) {
    return perMinuteRate;
  }
  const effectiveSeconds = Math.max(60, durationSeconds);
  const cost = (effectiveSeconds / 60.0) * perMinuteRate;
  return Math.round(cost * 100) / 100;
}

export const DUBBING_DURATION_TIERS: DubbingDurationTier[] = [
  {
    id: "shorts",
    label: "Shorts & Clips (≤ 60s)",
    minSeconds: 0,
    maxSeconds: 60,
    standardPriceUSD: 0.10,
    customPriceUSD: 0.10,
    voiceClonePriceUSD: 0.20,
  },
  {
    id: "mini",
    label: "Mini Video (1–5 min)",
    minSeconds: 61,
    maxSeconds: 300,
    standardPriceUSD: 0.50,
    customPriceUSD: 0.50,
    voiceClonePriceUSD: 1.00,
  },
  {
    id: "standard",
    label: "Standard Video (5–10 min)",
    minSeconds: 301,
    maxSeconds: 600,
    standardPriceUSD: 1.00,
    customPriceUSD: 1.00,
    voiceClonePriceUSD: 2.00,
  },
  {
    id: "extended",
    label: "Extended Video (10–30 min)",
    minSeconds: 601,
    maxSeconds: 1800,
    standardPriceUSD: 3.00,
    customPriceUSD: 3.00,
    voiceClonePriceUSD: 6.00,
  },
  {
    id: "long_form",
    label: "Long-Form Video (30–60 min)",
    minSeconds: 1801,
    maxSeconds: 3600,
    standardPriceUSD: 6.00,
    customPriceUSD: 6.00,
    voiceClonePriceUSD: 12.00,
  },
];

export function getFlatDubbingPricePerLanguage(
  durationSeconds: number,
  channelType: "standard" | "custom" = "standard",
  voiceType: "standard" | "voice_clone" | "cloned" = "standard"
): number {
  const isVoiceClone = voiceType === "voice_clone" || voiceType === "cloned";
  const perMinuteRate = isVoiceClone ? PER_MINUTE_VOICE_CLONE_RATE : PER_MINUTE_STANDARD_DUBBING_RATE;

  if (!durationSeconds || durationSeconds <= 0) {
    return perMinuteRate;
  }

  // Proportional per-minute calculation (ElevenLabs model) with 60s floor
  const effectiveSeconds = Math.max(60, durationSeconds);
  const cost = (effectiveSeconds / 60.0) * perMinuteRate;
  return Math.round(cost * 100) / 100;
}

export function calculateDubbingCost(
  languageCount: number,
  durationSeconds: number = 0,
  channelType: "standard" | "custom" = "standard",
  voiceType: "standard" | "voice_clone" | "cloned" = "standard",
  discountPercent: number = 0
): number {
  if (languageCount <= 0) return 0.0;
  if (discountPercent >= 100) return 0.0;
  const isVoiceClone = voiceType === "voice_clone" || voiceType === "cloned";
  let baseCost = 0.0;
  if (durationSeconds > 0) {
    const flatPerLang = getFlatDubbingPricePerLanguage(durationSeconds, channelType, voiceType);
    baseCost = Math.round(languageCount * flatPerLang * 100) / 100;
  } else {
    const pricing =
      CHANNEL_DUBBING_PRICING[channelType] || CHANNEL_DUBBING_PRICING.standard;
    const multiplier = (isVoiceClone && channelType !== "custom") ? 2 : 1;
    const rawCost = languageCount * pricing.ratePerLanguageUSD * multiplier;
    baseCost = Math.min(Math.max(rawCost, pricing.minCostUSD * multiplier), pricing.capCostUSD * multiplier);
  }
  if (discountPercent > 0) {
    const clampedDiscount = Math.min(100.0, Math.max(0.0, discountPercent));
    const factor = (100.0 - clampedDiscount) / 100.0;
    return Math.round(baseCost * factor * 100) / 100;
  }
  return baseCost;
}

/**
 * 👄 AI Visual Lip-Sync (LatentSync / MuseTalk GPU pass-through rate card)
 *
 * TruthWorld Rule: Zero Charm-Pricing, clean round numbers.
 * Costs ~10x less than SyncLabs while delivering broadcast 1080p latent diffusion quality.
 */
export function getFlatLipSyncPricePerLanguage(
  durationSeconds: number,
  channelType: "standard" | "custom" = "standard"
): number {
  const perMinuteRate = PER_MINUTE_LIP_SYNC_RATE; // $0.30/min ($3.00 for 10 min, $2.10 for 7 min)

  if (!durationSeconds || durationSeconds <= 0) {
    return perMinuteRate;
  }

  // Proportional per-minute calculation (ElevenLabs model) with 60s floor
  const effectiveSeconds = Math.max(60, durationSeconds);
  const cost = (effectiveSeconds / 60.0) * perMinuteRate;
  return Math.round(cost * 100) / 100;
}

export function calculateLipSyncCost(
  languageCount: number,
  durationSeconds: number = 0,
  channelType: "standard" | "custom" = "standard",
  discountPercent: number = 0
): number {
  if (languageCount <= 0 || durationSeconds <= 0) return 0.0;
  if (discountPercent >= 100) return 0.0;
  const flatPerLang = getFlatLipSyncPricePerLanguage(durationSeconds, channelType);
  const baseCost = Math.round(languageCount * flatPerLang * 100) / 100;
  if (discountPercent > 0) {
    const clampedDiscount = Math.min(100.0, Math.max(0.0, discountPercent));
    const factor = (100.0 - clampedDiscount) / 100.0;
    return Math.round(baseCost * factor * 100) / 100;
  }
  return baseCost;
}

export interface SubtitleTierConfig {
  id: "starter" | "pro";
  name: string;
  basePrice10MinUSD: number; // $0.50 (Starter) or $0.75 (Pro)
  perMinuteRateUSD: number;  // $0.05/min (Starter) or $0.075/min (Pro)
  additionalLang10MinUSD: number; // $0.20 (Starter) or $0.30 (Pro)
  additionalLangPerMinuteUSD: number; // $0.02/min (Starter) or $0.03/min (Pro)
  sttEngine: string;
  translationEngine: string;
}

export const SUBTITLE_TIERS: Record<"starter" | "pro", SubtitleTierConfig> = {
  starter: {
    id: "starter",
    name: "Starter Subtitles",
    basePrice10MinUSD: 0.50,
    perMinuteRateUSD: 0.05,
    additionalLang10MinUSD: 0.20,
    additionalLangPerMinuteUSD: 0.02,
    sttEngine: "AssemblyAI Universal 3.5 Pro (Global) + Sarvam AI (Indic) + Google Cloud Chirp 2 (Long-tail)",
    translationEngine: "Google Cloud Translation v3 Advanced + Gemini 2.5 Flash",
  },
  pro: {
    id: "pro",
    name: "Pro Subtitles (Cinema-Grade)",
    basePrice10MinUSD: 0.75,
    perMinuteRateUSD: 0.075,
    additionalLang10MinUSD: 0.30,
    additionalLangPerMinuteUSD: 0.03,
    sttEngine: "AssemblyAI Universal 3.5 Pro (Global) + Sarvam AI (Indic) + Google Cloud Chirp 2 (Long-tail)",
    translationEngine: "Google Cloud Translation v3 Advanced + Gemini 4 Argon",
  },
};

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
  channelType: "standard" | "custom" = "standard",
  tier: "starter" | "pro" = "starter"
): number {
  const tierConfig = SUBTITLE_TIERS[tier] || SUBTITLE_TIERS.starter;
  const effectiveSeconds = Math.max(60, durationSeconds || 600);
  const cost = (effectiveSeconds / 60.0) * tierConfig.perMinuteRateUSD;
  return Number(cost.toFixed(3));
}

export function calculateSubtitleCost(
  languageCount: number,
  durationSeconds: number = 0,
  channelType: "standard" | "custom" = "standard",
  discountPercent: number = 0,
  tier: "starter" | "pro" = "starter"
): number {
  if (languageCount <= 0) return 0.0;
  if (discountPercent >= 100) return 0.0;

  const tierConfig = SUBTITLE_TIERS[tier] || SUBTITLE_TIERS.starter;
  const effectiveSeconds = Math.max(60, durationSeconds || 600);
  const effectiveMinutes = effectiveSeconds / 60.0;

  const baseCost = effectiveMinutes * tierConfig.perMinuteRateUSD;
  const additionalLanguages = Math.max(0, languageCount - 1);
  const additionalCost = additionalLanguages * effectiveMinutes * tierConfig.additionalLangPerMinuteUSD;

  let totalCost = Math.round((baseCost + additionalCost) * 100) / 100;

  if (discountPercent > 0) {
    const clampedDiscount = Math.min(100.0, Math.max(0.0, discountPercent));
    const factor = (100.0 - clampedDiscount) / 100.0;
    return Math.round(totalCost * factor * 100) / 100;
  }
  return totalCost;
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
      const isPlaceholderUser = !userId || userId === "system" || userId === "__batch__" || userId === "unknown";
      let resolvedUserId = isPlaceholderUser ? "" : userId;
      let channelId: string | undefined;
      let channelType: ChannelType = 'standard';

      // 1. Fetch job to find channelId, channelType, and owner userId
      let jobDoc = await db().collection("video_jobs").doc(jobId).get();
      if (!jobDoc.exists) {
        jobDoc = await db().collection("pipeline_jobs").doc(jobId).get();
      }

      if (jobDoc.exists) {
        const jobData = jobDoc.data() as any;
        channelId = jobData.channelId;
        const config = jobData.config || {};
        channelType = config.channelType || 'standard';
        if (!resolvedUserId) {
          resolvedUserId = jobData.userId || "";
        }
      } else {
        // Fallback 1: check if jobId is a videoId in the videos collection
        const videoDoc = await db().collection("videos").doc(jobId).get();
        if (videoDoc.exists) {
          const videoData = videoDoc.data() || {};
          channelId = videoData.channelId;
          if (!resolvedUserId) {
            resolvedUserId = videoData.userId || videoData.ownerId || "";
          }
          if (channelId) {
            const chDoc = await db().collection("channels").doc(channelId).get();
            if (chDoc.exists) {
              const chData = chDoc.data() || {};
              channelType = (chData.type || chData.channelType || 'standard') as ChannelType;
              if (!resolvedUserId) {
                resolvedUserId = chData.ownerId || chData.userId || "";
              }
            }
          }
        } else {
          // Fallback 2: check if jobId is an ad campaignId
          const adDoc = await db().collection("ad_campaigns").doc(jobId).get();
          if (adDoc.exists) {
            const adData = adDoc.data() || {};
            channelId = adData.channelId;
            if (!resolvedUserId) {
              resolvedUserId = adData.userId || adData.ownerId || "advertiser";
            }
          }
        }
      }

      // If channelId is present but ownerId wasn't found yet, resolve from channels
      if (channelId && !resolvedUserId) {
        try {
          const chDoc = await db().collection("channels").doc(channelId).get();
          if (chDoc.exists) {
            const chData = chDoc.data() || {};
            resolvedUserId = chData.ownerId || chData.userId || "";
            channelType = (chData.type || chData.channelType || channelType) as ChannelType;
          }
        } catch (_) {}
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
      await this.updateRollup(resolvedUserId, channelId, channelType, stage, amount);

      // 3. Update channel infrastructure and bandwidth metering
      if (channelId) {
        const channelRef = db().collection("channels").doc(channelId);
        const channelUpdates: Record<string, any> = {
          "infraConfig.currentMonthInfraCost": admin.firestore.FieldValue.increment(amount),
          updatedAt: Date.now(),
        };

        // If bandwidth egress, increment bandwidthUsedBytesThisMonth
        if (stage === "cdn_egress") {
          const egressBytes = Math.round(quantity * 1024 * 1024 * 1024);
          if (egressBytes > 0) {
            channelUpdates["infraConfig.bandwidthUsedBytesThisMonth"] = admin.firestore.FieldValue.increment(egressBytes);
          }
        }

        // If Pro Channel, increment outstandingCosts and verify surge hold
        const isCustomOrPro = channelType === 'custom' || (channelType as string) === 'pro';
        if (isCustomOrPro) {
          channelUpdates.outstandingCosts = admin.firestore.FieldValue.increment(amount);

          try {
            const chSnap = await channelRef.get();
            if (chSnap.exists) {
              const chData = chSnap.data() || {};
              const infra = chData.infraConfig || {};
              const currentBandwidth = Number(infra.bandwidthUsedBytesThisMonth || 0);
              const quotaBytes = Number(infra.bandwidthQuotaBytesThisMonth || 0);
              const egressBytes = stage === "cdn_egress" ? Math.round(quantity * 1024 * 1024 * 1024) : 0;
              const newBandwidth = currentBandwidth + egressBytes;

              if (quotaBytes > 0 && newBandwidth > quotaBytes && !infra.isWithdrawalHeld) {
                channelUpdates["infraConfig.isWithdrawalHeld"] = true;
                channelUpdates["infraConfig.withdrawalHoldReason"] =
                  "TruthWorld has fronted and paid 100% of your viral infrastructure surge costs. Withdrawals are temporarily on hold until your Pro Channel plan is upgraded to cover the surge bandwidth.";
              }
            }
          } catch (surgeErr) {
            logger.warn(`[CostEngine] Non-blocking surge check error for ${channelId}:`, surgeErr);
          }
        }

        await channelRef.update(channelUpdates);
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

  async recordSubtitleCost(
    jobId: string,
    userId: string,
    durationSeconds: number,
    languageCount: number,
    tier: "starter" | "pro" = "starter"
  ): Promise<void> {
    const cost = calculateSubtitleCost(languageCount, durationSeconds, "standard", 0, tier);
    await this.recordCost(
      jobId,
      userId,
      "subtitles",
      tier === "pro" ? "google-translate-v3+gemini-4-argon" : "google-translate-v3+gemini-flash",
      cost,
      "subtitles_job",
      languageCount
    );
  }

  async recordTTSCost(
    jobId: string,
    userId: string,
    chars: number,
    provider: "elevenlabs" | "google-tts-chirp3-hd" | "google-tts-neural2" | "google-tts-standard" = "google-tts-chirp3-hd"
  ): Promise<void> {
    const rateCard = (RATE_CARDS as any)[provider] ?? RATE_CARDS["google-tts-neural2"];
    const cost = chars * rateCard.perCharacter;
    await this.recordCost(jobId, userId, "tts", provider, cost, "characters", chars);
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
    modelTier: "flash" | "pro" | "flash-lite" | "reasoning",
    inputTokens: number,
    outputTokens: number,
    cachedTokens: number = 0
  ): Promise<void> {
    let rateCard;
    switch (modelTier) {
      case "flash-lite":
        rateCard = RATE_CARDS["gemini-flash-lite"];
        break;
      case "reasoning":
      case "argon" as any:
        rateCard = RATE_CARDS["gemini-4-argon"];
        break;
      case "pro":
        rateCard = RATE_CARDS["gemini-pro"];
        break;
      case "flash":
      default:
        rateCard = RATE_CARDS["gemini-flash"];
        break;
    }
    const nonCachedInputTokens = Math.max(0, inputTokens - cachedTokens);
    const cost = (nonCachedInputTokens * rateCard.perInputToken) +
                 (cachedTokens * RATE_CARDS["gemini-cached-read"].perToken) +
                 (outputTokens * rateCard.perOutputToken);
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

  private async updateRollup(
    userId: string,
    channelId: string | undefined,
    channelType: ChannelType,
    stage: string,
    amount: number
  ): Promise<void> {
    const monthKey = this.currentMonthKey();
    const rollupRef = db().collection("cost_rollups").doc(`${userId}_${monthKey}`);

    const rollupData: Record<string, any> = {
      userId,
      month: monthKey,
      channelType,
      totalCostUsd: admin.firestore.FieldValue.increment(amount),
      [`breakdown.${stage}`]: admin.firestore.FieldValue.increment(amount),
      lastUpdated: Date.now(),
    };

    if (channelId) {
      rollupData.channelId = channelId;
      rollupData.channelIds = admin.firestore.FieldValue.arrayUnion(channelId);
    }

    await rollupRef.set(rollupData, { merge: true });
  }

  private currentMonthKey(): string {
    const d = new Date();
    return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
  }

  // Quota check (Legacy but kept for EdgeLayer)
  async checkQuota(
    userId: string,
    channelType: string,
    estimatedMinutes: number,
    channelData?: any
  ): Promise<{ allowed: boolean; reason?: string }> {
    const customLimit = channelData?.customDailyUploadLimitMinutes
      || (channelData?.customDailyVideoDurationSeconds ? Math.floor(channelData.customDailyVideoDurationSeconds / 60) : null)
      || (channelData?.maxDailyVideoDurationSeconds ? Math.floor(channelData.maxDailyVideoDurationSeconds / 60) : null);

    const limitMinutes = customLimit || 10;

    if (channelType === "standard" && estimatedMinutes > limitMinutes) {
      return {
        allowed: false,
        reason: `Standard channel video duration cannot exceed ${limitMinutes} minutes`,
      };
    }
    return { allowed: true };
  }
}

export const costEngine = new CostEngine();
