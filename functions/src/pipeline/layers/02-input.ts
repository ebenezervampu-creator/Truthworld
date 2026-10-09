/**
 * 🎥 LAYER 02 — INPUT LAYER
 *
 * Validates and normalises all user configuration before pipeline entry.
 */

import {
  UserConfig,
  ExecutionPlan,
  ChannelType,
} from "../types";
import { normalizeLanguageCodes, normalizeLanguageCode } from "../../shared/language-normalizer";

// ─── Constants ────────────────────────────────────────────────────────────────

const SUPPORTED_LANGUAGES = [
  // 🇮🇳 Indian Languages
  "te", "hi", "ta", "kn", "ml", "bn", "mr", "gu", "pa", "or",
  "as", "ur", "ne", "sd", "sa", "ks", "gom", "mai", "doi", "mni-Mtei",
  "brx", "sat", "bho",

  // 🎙️ ElevenLabs Dubbing & Global Core (78+ Languages)
  "en", "es", "fr", "de", "pt", "ar", "ru", "ja", "ko", "zh",
  "it", "tr", "vi", "th", "id", "nl", "pl", "sv", "el", "he",
  "fa", "uk", "fil", "tl", "ms", "cs", "da", "fi", "ro", "hu",
  "no", "sk", "hr", "bg", "sr", "sl", "lt", "lv", "et", "si",
  "sw", "my", "kk", "uz", "az", "hy", "ka", "am", "so", "zu",
  "af", "sq", "eu", "be", "bs", "ca", "ceb", "ny", "gl", "ha",
  "is", "ga", "jv", "ky", "lb", "mk", "ps", "cy", "ln", "mt",
  "la",

  // 🌐 Google Cloud Translation Subtitle Languages (135+ Languages)
  "co", "eo", "fy", "ht", "haw", "hmn", "ig", "km", "rw", "ku",
  "lo", "mg", "mi", "mn", "sm", "gd", "st", "sn", "su", "tg",
  "tt", "tk", "ug", "xh", "yi", "yo", "ay", "bm", "dv", "ee",
  "gn", "ilo", "kri", "lg", "om", "qu", "nso", "ti", "ts", "ak",
  "chr", "yue", "lus", "tn", "hil", "war", "pam", "pag", "bcl", "cnh"
];

interface ChannelLimits {
  voiceCloning: boolean;
  maxVideoDurationSeconds: number;
  maxDailyDurationSeconds: number;
}

const TYPE_LIMITS: Record<ChannelType, ChannelLimits> = {
  standard: {
    voiceCloning: true,
    maxVideoDurationSeconds: 600, // 10 minutes
    maxDailyDurationSeconds: 600, // 10 minutes
  },
  custom: {
    voiceCloning: true,
    maxVideoDurationSeconds: 86400, // 24 hours
    maxDailyDurationSeconds: 86400, // 24 hours
  }
};

/** Rough per-unit cost constants (USD) — used for pre-flight estimates */
const COST_RATES = {
  geminiCallPerClaim:      0.0012,
  ttsPerCharacter:         0.000030,
  translationPerCharacter: 0.000020,
  avgWordsPerMinute:       120,
  avgCharsPerWord:         5.5,
  estimatedVideoDuration:  600,
};

// ─── InputLayer ───────────────────────────────────────────────────────────────

export class InputLayer {

  /**
   * Normalise a partial user config into a complete, safe UserConfig.
   */
  normalizeConfig(userId: string, partial: Partial<UserConfig>): UserConfig {
    const channelType = partial.channelType ?? "standard";
    const langs = normalizeLanguageCodes(partial.languages ?? ["en"]);

    let validatedDuration: number | undefined = undefined;
    if (partial.duration !== undefined) {
      const dur = Number(partial.duration);
      if (isFinite(dur) && dur > 0 && dur <= 7200) {
        validatedDuration = dur;
      }
    }

    return {
      userId,
      channelType,
      languages: langs.length > 0 ? langs : ["en"],
      dubbingMode: partial.dubbingMode ?? "none",
      genLangSubs: partial.genLangSubs ?? true,
      generateDubbing: partial.generateDubbing ?? false,
      enableFactCheck: partial.enableFactCheck ?? true,
      priority: partial.priority ?? "normal",
      duration: validatedDuration ?? partial.duration,
    };
  }

  /**
   * Validate a normalised config.
   */
  validateConfig(config: UserConfig): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (config.duration !== undefined) {
      const dur = Number(config.duration);
      if (!isFinite(dur) || dur <= 0 || dur > 7200) {
        errors.push("Video duration must be between 1 and 7200 seconds (2 hours)");
      }
    }

    if (config.channelType === "standard" && config.duration && config.duration > 600) {
      errors.push("Standard channel video duration cannot exceed 10 minutes (600 seconds)");
    }

    if (!config.languages || config.languages.length === 0) {
      errors.push("At least one language is required");
    }

    const unsupported = config.languages.filter(
      (l) => !SUPPORTED_LANGUAGES.includes(l)
    );
    if (unsupported.length > 0) {
      errors.push(`Unsupported languages: ${unsupported.join(", ")}`);
    }

    if (config.generateDubbing && config.languages.length === 0) {
      errors.push("Dubbing requires at least one target language");
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * Build an execution plan from a validated config.
   */
  createExecutionPlan(jobId: string, config: UserConfig): ExecutionPlan {
    return {
      jobId,
      enablePath1: config.enableFactCheck,
      enablePath2: config.generateDubbing || config.genLangSubs,
      enableTruthEngine: config.enableFactCheck,
      enableReachEngine: config.generateDubbing || config.genLangSubs,
      enableAuxiliary: config.enableFactCheck,
      languages: config.languages,
      dubbingMode: config.generateDubbing ? config.dubbingMode : "none",
      generateDubbing: config.generateDubbing,
      genLangSubs: config.genLangSubs,
      channelType: config.channelType,
      maxClaims: 200,
      priority: config.priority ?? "normal",
      skipCache: false,
    };
  }

  /**
   * Estimate USD cost of executing this plan.
   */
  estimateJobCost(plan: ExecutionPlan): number {
    let cost = 0;

    if (plan.enablePath1) {
      cost += plan.maxClaims * COST_RATES.geminiCallPerClaim;
    }

    if (plan.enablePath2) {
      const words = COST_RATES.estimatedVideoDuration / 60 * COST_RATES.avgWordsPerMinute;
      const chars = words * COST_RATES.avgCharsPerWord;
      const langCount = plan.languages.length;

      const sourceLang = normalizeLanguageCode(plan.primaryLanguage || "en");
      const foreignLangs = plan.languages.filter((l) => normalizeLanguageCode(l) !== sourceLang).length;
      cost += chars * COST_RATES.translationPerCharacter * foreignLangs;

      if (plan.generateDubbing) {
        cost += chars * COST_RATES.ttsPerCharacter * langCount;
      }
    }

    return Math.round(cost * 10000) / 10000;
  }

  getChannelLimits(type: ChannelType): ChannelLimits {
    return { ...TYPE_LIMITS[type] };
  }

  isFeatureAvailable(type: ChannelType, feature: string): boolean {
    switch (feature) {
      case "voice_cloning":
        return TYPE_LIMITS[type]?.voiceCloning ?? false;
      case "auxiliary":
        return true;
      case "high_priority":
        return type === "custom";
      case "unlimited_duration":
        return type === "custom";
      default:
        return false;
    }
  }

  getSupportedLanguages(): string[] {
    return [...SUPPORTED_LANGUAGES];
  }
}

export const inputLayer = new InputLayer();