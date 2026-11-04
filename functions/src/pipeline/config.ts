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
  get SARVAM_API_KEY(): string {
    return process.env.SARVAM_API_KEY || "";
  },
  get ASSEMBLYAI_KEY(): string {
    return requireEnv("ASSEMBLYAI_KEY");
  },
  get ELEVENLABS_API_KEY(): string {
    return requireEnv("ELEVENLABS_API_KEY");
  },
  get GEMINI_API_KEY(): string {
    // Vertex AI runs on Google Cloud IAM (Application Default Credentials).
    // GEMINI_API_KEY is only optional for legacy Google AI Studio fallbacks.
    return process.env.GEMINI_API_KEY || "";
  },
  get GOOGLE_TRANSLATION_API_KEY(): string {
    return requireEnv("GOOGLE_TRANSLATION_API_KEY");
  },
  get GOOGLE_TTS_API_KEY(): string {
    return process.env.GOOGLE_TTS_API_KEY || process.env.GOOGLE_TRANSLATION_API_KEY || "";
  },
  FFMPEG_SERVICE_URL: process.env.FFMPEG_SERVICE_URL || "https://placeholder.run",
  LIPSYNC_SERVICE_URL: process.env.LIPSYNC_SERVICE_URL || "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run",
  PUBLIC_FUNCTION_BASE_URL: "https://asia-south1-truthworld-1.cloudfunctions.net",
  VIDEO_BUCKET: "truthworld-1.firebasestorage.app",

  /**
   * 🧠 ROLE-BASED MODEL SELECTION (Vertex AI Hybrid Cost-Effective Architecture)
   *
   * Cost strategy:
   * Workers (Flash-Lite: gemini-2.0-flash-lite)  → ultra-low-cost (~$0.075/1M in), high-throughput
   * Baseline Workhorse (Gemini 2.5 Flash)       → fast, reliable multimodal pipeline (~$0.15/1M in)
   * Truth Arbiter / Reasoning (3.8 Flash / 4)   → deep verification for sensitive/disputed domains
   *
   * Saves ~50% on worker spend while ensuring frontier truth verification on sensitive claims.
   */
  GEMINI_MODELS: {
    extraction: process.env.GEMINI_EXTRACTION_MODEL || "gemini-2.5-flash",   // Fast, cost-effective claim extraction (Flash-Lite)
    verification: process.env.GEMINI_VERIFICATION_MODEL || "gemini-2.5-flash", // Truth arbiter (Gemini 2.5 Flash)
    reasoning: process.env.GEMINI_REASONING_MODEL || "gemini-2.5-flash",       // Vertex AI Frontier Reasoning Model (Gemini 2.5 Flash)
    synthesis: process.env.GEMINI_SYNTHESIS_MODEL || "gemini-2.5-flash",    // Intelligence summaries & video metadata (Flash-Lite)
    consistency: process.env.GEMINI_CONSISTENCY_MODEL || "gemini-2.5-flash",  // Contradiction detection (Flash-Lite)
    translation: process.env.GEMINI_TRANSLATION_MODEL || "gemini-2.5-flash",  // Translation lane (worker)
    profiling: process.env.GEMINI_PROFILING_MODEL || "gemini-2.5-flash", // Speaker profiling (worker: Flash-Lite)
    moderation: process.env.GEMINI_MODERATION_MODEL || "gemini-2.5-flash",   // Multimodal video, channel, and topic moderation (Flash)
    fastTier: process.env.GEMINI_FAST_TIER_MODEL || "gemini-2.5-flash",     // Instant lightweight verification (Flash-Lite)
    queryDecomposition: process.env.GEMINI_QUERY_MODEL || "gemini-2.5-flash", // Search query decomposition (Flash-Lite)
  },

  /**
   * ⚡ VERTEX AI CONTEXT CACHING ARCHITECTURE
   * Automatic and implicit context caching is supported on Vertex AI when prompt prefixes exceed 32k tokens.
   */
  CONTEXT_CACHING: {
    ENABLED: process.env.ENABLE_CONTEXT_CACHING !== "false",
    MIN_TOKEN_THRESHOLD: 32768,
    PREFIX_STABILITY_ENFORCED: true,
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

