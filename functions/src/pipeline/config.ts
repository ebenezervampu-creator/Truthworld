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
    const msg = `[PIPELINE_CONFIG] Missing required environment variable: ${name}`;
    if (process.env.NODE_ENV === "production") {
      throw new Error(msg);
    }
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
    return requireEnv("GOOGLE_TRANSLATION_API_KEY");
  },
  FFMPEG_SERVICE_URL: process.env.FFMPEG_SERVICE_URL || "https://placeholder.run",
  PUBLIC_FUNCTION_BASE_URL: "https://asia-south1-truthworld-1.cloudfunctions.net",
  VIDEO_BUCKET: "truthworld-1.firebasestorage.app",

  /**
   * 🧠 ROLE-BASED MODEL SELECTION (Vertex AI Gemini 3 Cost-Effective Architecture)
   *
   * Cost strategy:
   * Workers (Flash-Lite: gemini-3.1-flash-lite)  → ultra-low-cost (~$0.25/1M in), high-throughput
   * Truth Arbiter (3.5 Flash: gemini-3.5-flash)  → near-Pro reasoning with search grounding at Flash pricing
   *
   * Saves ~85% on bulk worker token spend while ensuring robust truth verification.
   */
  GEMINI_MODELS: {
    extraction: "gemini-3.1-flash-lite",   // Ultra cost-effective claim extraction (worker)
    verification: "gemini-3.5-flash",       // Cost-effective Truth arbiter (near-Pro intelligence at Flash price)
    synthesis: "gemini-3.1-flash-lite",    // Ultra cost-effective intelligence summaries (worker)
    consistency: "gemini-3.1-flash-lite",  // Ultra cost-effective contradiction detection (worker)
    translation: "gemini-3.1-flash-lite",  // Cost-effective translation lane (worker)
    profiling: "gemini-3.1-flash-lite",    // Speaker profiling (worker)
    moderation: "gemini-2.5-flash",        // Multimodal video, channel, and topic moderation (Flash)
    fastTier: "gemini-3.1-flash-lite",     // Instant lightweight verification
  },

  /** @deprecated Use GEMINI_MODELS[role] instead. Kept for backward compat. */
  GEMINI_MODEL: "gemini-3.1-flash-lite",

  GROUNDING_MODE: "auto", // 'auto' | 'always' | 'never'
  CONSTRAINT_BASED_VERIFICATION: true, // v10.0: Prohibit AI training data in fact checks
  BATCH_SIZE_GROUNDING: 6,
  BATCH_SIZE_STANDARD: 12,

  /**
   * 🎯 SENSITIVE CLAIM DOMAINS (Risk-Based Dynamic Routing)
   *
   * Claims in these domains are routed to verification model (gemini-3.5-flash).
   */
  SENSITIVE_DOMAINS: [
    "war", "election", "health", "death", "finance",
    "sanctions", "terrorism", "genocide", "nuclear",
    "pandemic", "assassination", "coup",
  ] as string[],

  /**
   * 📊 VERTEX AI & GEMINI QUOTA ARCHITECTURE
   *
   * Baseline Quota: 4,000,000 TPM (Tokens Per Minute) -> Supports ~26 10-min videos/min.
   * Target High-Scale Quota: 20,000,000 TPM (5x Quota Request) -> Supports 130 10-min videos/min.
   */
  VERTEX_QUOTA: {
    BASELINE_TPM: 4_000_000,
    TARGET_HIGH_SCALE_TPM: 20_000_000,
    ESTIMATED_TOKENS_PER_VIDEO_SEC: 258,
    BURST_CAPACITY_VIDEOS_PER_MIN_AT_TARGET: 130,
  },
};

// Deep Research Mode (v10.5)
export const DEEP_RESEARCH_CONFIG = {
  GROUNDING_MODE: "always" as "always" | "sensitive_only" | "never",
  BATCH_SIZE_GROUNDING: 10,         // parallel claims per Gemini call
  MAX_CLAIMS_INSTITUTIONAL: 50,     // cost-conscious cap for institutional tier
  MAX_CLAIMS_STANDARD: 35,          // cost-conscious cap for standard tier
  FORCE_PRO_MODEL: false,           // cost-effective: uses gemini-3.5-flash
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
 * TruthWorld Core Epistemic Policy: "No Claim Left Unchecked"
 * Every verifiable empirical claim extracted from the video must be fact-checked.
 * We provide a generous system ceiling of 200 claims per video to protect against memory exhaustion,
 * ensuring no creator claims are truncated or dropped.
 */
export function calculateMaxClaimsForDuration(
  durationSec: number,
  isDeepResearch: boolean = false
): number {
  return 200;
}

/**
 * v11.0: Fast Tier — lightweight signal for real-time use cases.
 * Config is in fastVerification.ts. This re-export ensures central discoverability.
 */
export { FAST_TIER_CONFIG } from './services/fastVerification';

