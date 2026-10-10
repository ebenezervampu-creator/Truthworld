import * as admin from "firebase-admin";

/**
 * 🔒 TRUTHWORLD PLATFORM CAPACITY & PHASE QUOTAS
 *
 * Central configuration for platform rollout phases.
 * 
 * ============================================================================
 * 🚀 TO SWITCH PHASES:
 * Simply change `ACTIVE_PHASE` below, OR set the `PLATFORM_PHASE` environment
 * variable (e.g. PLATFORM_PHASE=2).
 * 
 * Example:
 *   export const ACTIVE_PHASE = 2; // Switches to Phase 2
 * ============================================================================
 */

export interface PhaseConfig {
  phase: number;
  name: string;
  maxStandardUsers: number;
  maxStandardChannels: number;
  isCustomChannelUnlimited: boolean;
  description: string;
}

/** Pre-configured phase blueprints */
export const PHASE_CONFIGS: Record<number, PhaseConfig> = {
  1: {
    phase: 1,
    name: "Phase 1: Alpha / Early Creators",
    maxStandardUsers: 10000,
    maxStandardChannels: 100,
    isCustomChannelUnlimited: true,
    description: "Phase 1 capacity: 10,000 standard users and 100 standard creator channels.",
  },
  2: {
    phase: 2,
    name: "Phase 2: Beta Scale & Ecosystem Expansion",
    maxStandardUsers: 100000,
    maxStandardChannels: 1000,
    isCustomChannelUnlimited: true,
    description: "Phase 2 capacity: 100,000 standard users and 1,000 standard creator channels.",
  },
  3: {
    phase: 3,
    name: "Phase 3: Public General Availability",
    maxStandardUsers: 1000000,
    maxStandardChannels: 10000,
    isCustomChannelUnlimited: true,
    description: "Phase 3 capacity: 1,000,000 standard users and 10,000 standard creator channels.",
  },
};

/**
 * 🎯 ACTIVE PHASE SWITCH
 * Change this single number to 1, 2, or 3 (or override via process.env.PLATFORM_PHASE).
 */
export const ACTIVE_PHASE: number = Number(process.env.PLATFORM_PHASE) || 1;

// Resolve preset according to active phase
const activeConfig: PhaseConfig = PHASE_CONFIGS[ACTIVE_PHASE] || PHASE_CONFIGS[1];

export const PLATFORM_LIMITS = {
  CURRENT_PHASE: activeConfig.phase,
  PHASE_NAME: activeConfig.name,

  /** Maximum registered users allowed in active phase (supports env override) */
  MAX_STANDARD_USERS: Number(process.env.MAX_STANDARD_USERS) || activeConfig.maxStandardUsers,

  /** Maximum standard creator channels allowed in active phase (supports env override) */
  MAX_STANDARD_CHANNELS: Number(process.env.MAX_STANDARD_CHANNELS) || activeConfig.maxStandardChannels,

  /** Custom channels have custom dedicated infrastructure and zero limits */
  IS_CUSTOM_CHANNEL_UNLIMITED: activeConfig.isCustomChannelUnlimited,

  DESCRIPTION: activeConfig.description,
};

export type PlatformLimitsConfig = typeof PLATFORM_LIMITS;

/**
 * Helper to get the limits configuration for any specific phase.
 */
export function getPhaseConfig(phaseNumber: number = ACTIVE_PHASE): PhaseConfig {
  return PHASE_CONFIGS[phaseNumber] || PHASE_CONFIGS[1];
}

// In-memory cache for dynamic Firestore limits with 30-second TTL
let cachedDynamicLimits: PlatformLimitsConfig | null = null;
let cacheExpiryTimestamp = 0;

/**
 * Asynchronously retrieves active platform limits:
 * 1. Returns in-memory cached config if fresh (< 30s)
 * 2. Fetches live config from Firestore `system_settings/platform_limits`
 * 3. Falls back to static PLATFORM_LIMITS / preset
 */
export async function getDynamicPlatformLimits(): Promise<PlatformLimitsConfig> {
  const now = Date.now();
  if (cachedDynamicLimits && now < cacheExpiryTimestamp) {
    return cachedDynamicLimits;
  }

  try {
    const docSnap = await admin.firestore().collection("system_settings").doc("platform_limits").get();
    if (docSnap.exists) {
      const data = docSnap.data();
      const phaseNum = Number(data?.currentPhase) || ACTIVE_PHASE;
      const preset = PHASE_CONFIGS[phaseNum] || PHASE_CONFIGS[1];

      cachedDynamicLimits = {
        CURRENT_PHASE: phaseNum,
        PHASE_NAME: data?.phaseName || preset.name,
        MAX_STANDARD_USERS: Number(data?.maxStandardUsers) || preset.maxStandardUsers,
        MAX_STANDARD_CHANNELS: Number(data?.maxStandardChannels) || preset.maxStandardChannels,
        IS_CUSTOM_CHANNEL_UNLIMITED: data?.isCustomChannelUnlimited !== false,
        DESCRIPTION: data?.description || preset.description,
      };
      cacheExpiryTimestamp = now + 30000;
      return cachedDynamicLimits;
    }
  } catch (err) {
    // Graceful fallback to static PLATFORM_LIMITS
  }

  return PLATFORM_LIMITS;
}

/**
 * Manually invalidates the in-memory limits cache so updates take effect immediately.
 */
export function clearLimitsCache(): void {
  cachedDynamicLimits = null;
  cacheExpiryTimestamp = 0;
}


