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

// ─── Constants ────────────────────────────────────────────────────────────────

const SUPPORTED_LANGUAGES = [
  "en", "es", "fr", "de", "it", "pt", "ru",
  "ja", "zh", "ko", "hi", "ar", "tr", "nl",
  "pl", "sv", "da", "no", "fi",
];

interface ChannelLimits {
  maxLanguages: number;
  maxClaims:    number;
  voiceCloning: boolean;
  auxiliary:    boolean;
  priority:     "low" | "normal" | "high";
}

const TYPE_LIMITS: Record<ChannelType, ChannelLimits> = {
  standard: {
    maxLanguages: 5,
    maxClaims:    20,
    voiceCloning: true,
    auxiliary:    false,
    priority:     "normal",
  },
  custom: {
    maxLanguages: 50,
    maxClaims:    100,
    voiceCloning: true,
    auxiliary:    true,
    priority:     "high",
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
    const limits = TYPE_LIMITS[channelType];

    const rawLangs = [...new Set(partial.languages ?? ["en"])];
    const langs = rawLangs.slice(0, limits.maxLanguages);

    return {
      userId,
      channelType,
      languages: langs,
      dubbingMode: partial.dubbingMode ?? "none",
      genLangSubs: partial.genLangSubs ?? true,
      generateDubbing: partial.generateDubbing ?? false,
      enableFactCheck: partial.enableFactCheck ?? true,
      priority: limits.priority,
    };
  }

  /**
   * Validate a normalised config.
   */
  validateConfig(config: UserConfig): { valid: boolean; errors: string[] } {
    const errors: string[] = [];
    const limits = TYPE_LIMITS[config.channelType];

    if (!config.languages || config.languages.length === 0) {
      errors.push("At least one language is required");
    }

    const unsupported = config.languages.filter(
      (l) => !SUPPORTED_LANGUAGES.includes(l)
    );
    if (unsupported.length > 0) {
      errors.push(`Unsupported languages: ${unsupported.join(", ")}`);
    }

    if (config.languages.length > limits.maxLanguages) {
      errors.push(
        `${config.channelType} channel supports max ${limits.maxLanguages} languages (got ${config.languages.length})`
      );
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
    const limits = TYPE_LIMITS[config.channelType];

    return {
      jobId,
      enablePath1: config.enableFactCheck,
      enablePath2: config.generateDubbing || config.genLangSubs,
      enableTruthEngine: config.enableFactCheck,
      enableReachEngine: config.generateDubbing || config.genLangSubs,
      enableAuxiliary: limits.auxiliary && config.enableFactCheck,
      languages: config.languages.slice(0, limits.maxLanguages),
      dubbingMode: config.generateDubbing ? config.dubbingMode : "none",
      generateDubbing: config.generateDubbing,
      genLangSubs: config.genLangSubs,
      channelType: config.channelType,
      maxClaims: limits.maxClaims,
      priority: limits.priority,
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

      const foreignLangs = plan.languages.filter((l) => l !== "en").length;
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
    const l = TYPE_LIMITS[type];
    switch (feature) {
      case "voice_cloning": return l.voiceCloning;
      case "auxiliary": return l.auxiliary;
      case "high_priority": return type === "custom";
      default: return true;
    }
  }

  getSupportedLanguages(): string[] {
    return [...SUPPORTED_LANGUAGES];
  }
}

export const inputLayer = new InputLayer();