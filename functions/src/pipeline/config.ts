/**
 * 🛠️ PIPELINE CONFIGURATION (SECURE — Environment Variables Only)
 *
 * All API keys MUST be provided via Firebase Functions secrets or environment
 * variables. Never hardcode keys in source code.
 *
 * Setup: firebase functions:secrets:set ASSEMBLYAI_KEY
 *        firebase functions:secrets:set ELEVENLABS_API_KEY
 *        firebase functions:secrets:set GEMINI_API_KEY
 *        firebase functions:secrets:set GOOGLE_TRANSLATION_API_KEY
 */

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    // Warn at import time rather than crash — allows deployment health checks
    // to pass. The actual key absence will fail at call time with a clear error.
    console.warn(`[PIPELINE_CONFIG] ⚠️ Missing required env var: ${name}`);
    return "";
  }
  return value;
}

export const PIPELINE_CONFIG = {
  get ASSEMBLYAI_KEY(): string {
    return requireEnv("ASSEMBLYAI_KEY");
  },
  get ELEVENLABS_API_KEY(): string {
    return requireEnv("ELEVENLABS_API_KEY");
  },
  get GEMINI_API_KEY(): string {
    return requireEnv("GEMINI_API_KEY");
  },
  get GOOGLE_TRANSLATION_API_KEY(): string {
    const value = process.env.GOOGLE_TRANSLATION_API_KEY || process.env.GOOGLE_TRANSLATION_API_KEEY;
    if (!value) {
      console.warn("[PIPELINE_CONFIG] ⚠️ Missing required env var: GOOGLE_TRANSLATION_API_KEY (or GOOGLE_TRANSLATION_API_KEEY)");
      return "";
    }
    return value;
  },
  FFMPEG_SERVICE_URL: process.env.FFMPEG_SERVICE_URL || "https://placeholder.run",
  PUBLIC_FUNCTION_BASE_URL: "https://asia-south1-truthworld-1.cloudfunctions.net",
  VIDEO_BUCKET: "truthworld-1.firebasestorage.app",

  /**
   * 🧠 ROLE-BASED MODEL SELECTION (Multi-Model Architecture v1)
   *
   * Workers (Flash) → fast, cheap, high-throughput
   * Judges (Pro)    → nuanced, accurate, truth arbitration
   *
   * Cost strategy: ~85% Flash, ~15% Pro (sensitive claims only)
   */
  GEMINI_MODELS: {
    extraction: "gemini-2.5-flash",     // Fast claim extraction (worker)
    verification: "gemini-2.5-flash",   // Truth arbiter — Pro unavailable, using Flash
    synthesis: "gemini-2.5-flash",     // Intelligence summaries (worker)
    consistency: "gemini-2.5-flash",     // Internal contradiction detection (worker)
    translation: "gemini-2.5-flash",     // Premium translation lane (worker)
    profiling: "gemini-2.5-flash",     // Speaker profiling (worker)
  },

  /** @deprecated Use GEMINI_MODELS[role] instead. Kept for backward compat. */
  GEMINI_MODEL: "gemini-2.5-flash",

  GROUNDING_MODE: "auto", // 'auto' | 'always' | 'never'
  CONSTRAINT_BASED_VERIFICATION: true, // v10.0: Prohibit AI training data in fact checks
  BATCH_SIZE_GROUNDING: 6,
  BATCH_SIZE_STANDARD: 12,

  /**
   * 🎯 SENSITIVE CLAIM DOMAINS (Risk-Based Dynamic Routing)
   *
   * Claims in these domains are ALWAYS routed to Pro for verification,
   * even when the global routing would use Flash.
   */
  SENSITIVE_DOMAINS: [
    "war", "election", "health", "death", "finance",
    "sanctions", "terrorism", "genocide", "nuclear",
    "pandemic", "assassination", "coup",
  ] as string[],
};

// Deep Research Mode (v10.5)
export const DEEP_RESEARCH_CONFIG = {
  GROUNDING_MODE: "always" as "always" | "sensitive_only" | "never",
  BATCH_SIZE_GROUNDING: 10,         // parallel claims per Gemini call
  MAX_CLAIMS_INSTITUTIONAL: 50,     // raised from 12/20
  MAX_CLAIMS_STANDARD: 20,          // unchanged for standard tier
  FORCE_PRO_MODEL: true,            // always use gemini-2.5-pro for verification
  MIN_SOURCES_PER_CLAIM: 2,         // minimum sources required to mark a claim as grounded
  SOURCE_DIVERSITY_REQUIRED: true,  // reject results where all sources are the same domain
} as const;

/**
 * v10.5: Determine if Deep Research should be active for this job.
 */
export function isDeepResearchEnabled(synthesisTier: string, forcedByConfig?: boolean): boolean {
  return forcedByConfig === true || synthesisTier === 'deep' || synthesisTier === 'podcast';
}

/**
 * v11.0: Fast Tier — lightweight signal for real-time use cases.
 * Config is in fastVerification.ts. This re-export ensures central discoverability.
 */
export { FAST_TIER_CONFIG } from './services/fastVerification';
