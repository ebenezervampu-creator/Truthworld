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

export type ThinkingLevel = "MINIMAL" | "LOW" | "MEDIUM" | "HIGH" | "XHIGH";

export interface ModelTierConfig {
  model: string;
  defaultThinkingLevel: ThinkingLevel;
  temperature: number;
  maxOutputTokens: number;
}

export const PIPELINE_PHASE: "PHASE_1_PROMO" | "PHASE_2_UNIFIED" =
  (process.env.PIPELINE_PHASE as "PHASE_1_PROMO" | "PHASE_2_UNIFIED") || "PHASE_1_PROMO";

export const GEMINI_MODELS: Record<"extraction" | "verification" | "reasoning", ModelTierConfig> = {
  extraction: {
    model: process.env.GEMINI_MODEL_EXTRACTION || "gemini-3.5-flash-lite",
    defaultThinkingLevel: "MINIMAL",
    temperature: 0.0,
    maxOutputTokens: 8192,
  },
  verification: {
    model:
      PIPELINE_PHASE === "PHASE_2_UNIFIED"
        ? (process.env.GEMINI_MODEL_VERIFICATION_PHASE_2 || "gemini-4-hydrogen")
        : (process.env.GEMINI_MODEL_VERIFICATION || "gemini-3.8-flash"),
    defaultThinkingLevel: "LOW",
    temperature: 0.1,
    maxOutputTokens: 4096,
  },
  reasoning: {
    model: process.env.GEMINI_MODEL_REASONING || "gemini-4-hydrogen",
    defaultThinkingLevel: "MEDIUM",
    temperature: 0.1,
    maxOutputTokens: 8192,
  },
};

export const PIPELINE_LIMITS = {
  BATCH_SIZE_GROUNDING: Number(process.env.BATCH_SIZE_GROUNDING) || 6,
  TIER3_DEFAULT_THINKING: "MEDIUM" as ThinkingLevel,
  TIER3_ESCALATION_THINKING: "HIGH" as ThinkingLevel,
  TIER3_CONFLICT_THINKING: "XHIGH" as ThinkingLevel,
  TIER3_CONFIDENCE_THRESHOLD: 0.85,
  MAX_ESCALATION_THINKING: "XHIGH" as ThinkingLevel,
  SENSITIVE_DOMAINS: new Set([
    "HEALTH_MEDICAL",
    "GEOPOLITICS_WAR",
    "ELECTIONS_GOVERNANCE",
    "MACROECONOMICS_FINANCE",
  ]),
} as const;

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
    // Vertex AI runs on Google Cloud IAM (Application Default Credentials).
    // GEMINI_API_KEY is only optional for legacy Google AI Studio fallbacks.
    return process.env.GEMINI_API_KEY || "";
  },
  get GOOGLE_TRANSLATION_API_KEY(): string {
    return requireEnv("GOOGLE_TRANSLATION_API_KEY");
  },
  FFMPEG_SERVICE_URL: process.env.FFMPEG_SERVICE_URL || "",
  DEMUX_SERVICE_URL: process.env.DEMUX_SERVICE_URL || "",
  PUBLIC_FUNCTION_BASE_URL: "https://asia-south1-truthworld-1.cloudfunctions.net",
  VIDEO_BUCKET: "truthworld-1.firebasestorage.app",

  // ─── World-Class Google Cloud Translation Configuration ───────────────────
  TRANSLATION_PROVIDER: process.env.TRANSLATION_PROVIDER || "google",
  TRANSLATION_API_VERSION: process.env.TRANSLATION_API_VERSION || "v3",
  TRANSLATION_MODEL: process.env.TRANSLATION_MODEL || "general/translation-llm",
  TRANSLATION_LOCATION: process.env.TRANSLATION_LOCATION || "global",

  // ─── AdaptiveMt Configuration (Real-Time Glossary/Terminology Consistency) ──
  /** AdaptiveMt requires a regional endpoint (NOT "global"). */
  ADAPTIVE_MT_LOCATION: process.env.ADAPTIVE_MT_LOCATION || "us-central1",
  /** Optional: pre-created AdaptiveMt dataset resource name for persistent terminology memory. */
  ADAPTIVE_MT_DATASET: process.env.ADAPTIVE_MT_DATASET || "",
  /** Required composite-translation stage; disabling it causes translation to fail. */
  ADAPTIVE_MT_ENABLED: process.env.ADAPTIVE_MT_ENABLED !== "false",

  /** Last-known-good configuration for automatic fallback / zero-downtime rollback */
  LAST_KNOWN_GOOD_TRANSLATION_CONFIG: {
    provider: "google",
    apiVersion: "v3",
    model: "general/translation-llm",
    location: "global",
  } as const,

  /**
   * 🧠 ROLE-BASED MODEL SELECTION (Vertex AI Hybrid Cost-Effective Architecture)
   *
   * Cost strategy:
   * Unified Workhorse (Gemini 3.5 Flash Lite)        → ultra-fast, high-throughput, low-cost multimodal engine
   * Baseline Workhorse (Gemini 3.5 Flash Lite)       → fast, reliable multimodal pipeline
   * Truth Arbiter / Reasoning (Gemini 3.5 Flash Lite) → deep, robust verification for sensitive/disputed domains
   *
   * Saves on worker spend while ensuring frontier truth verification on sensitive claims.
   */
  GEMINI_MODELS: {
    extraction: GEMINI_MODELS.extraction.model,
    verification: GEMINI_MODELS.verification.model,
    reasoning: GEMINI_MODELS.reasoning.model,
    synthesis: process.env.GEMINI_SYNTHESIS_MODEL || GEMINI_MODELS.extraction.model,
    consistency: process.env.GEMINI_CONSISTENCY_MODEL || GEMINI_MODELS.extraction.model,
    profiling: process.env.GEMINI_PROFILING_MODEL || GEMINI_MODELS.extraction.model,
    moderation: process.env.GEMINI_MODERATION_MODEL || GEMINI_MODELS.verification.model,
    fastTier: process.env.GEMINI_FAST_TIER_MODEL || GEMINI_MODELS.extraction.model,
    queryDecomposition: process.env.GEMINI_QUERY_MODEL || GEMINI_MODELS.extraction.model,
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
  GEMINI_MODEL: "gemini-3.5-flash-lite",

  GROUNDING_MODE: "auto", // 'auto' | 'always' | 'never'
  CONSTRAINT_BASED_VERIFICATION: true, // v10.0: Prohibit AI training data in fact checks
  BATCH_SIZE_GROUNDING: 6,
  BATCH_SIZE_STANDARD: 12,

  /**
   * ⚡ PHASE 1: FUSED GROUNDING VERIFICATION
   * Combines Google Search Grounding and Claim Adjudication into a single unified Gemini call,
   * eliminating the serial Double LLM Hop and reducing batch verification latency by ~50%.
   */
  ENABLE_FUSED_GROUNDING: process.env.ENABLE_FUSED_GROUNDING !== "false",

  /**
   * Closed-World Citation & URL Verification Safeguards
   * - LLM never generates URLs; cites only verified EvidenceCatalog IDs (E1, E2, ...)
   * - Newer Gemini model rollout remains behind GEMINI_ENABLE_NEXT_GEN_MODEL flag
   */
  EVIDENCE_SCHEMA_VERSION: "v2_verified_urls",
  CLOSED_WORLD_CITATIONS: {
    ENFORCE_CITE_BY_ID: process.env.ENFORCE_CITE_BY_ID === "true", // Default false to enable native batch Google Search Grounding without rate-limit spikes
    ALLOW_UNVERIFIED_CACHE_SERVING: false,
    MAX_REDIRECT_HOPS: 5,
    URL_FETCH_TIMEOUT_MS: 4000,
    MAX_HTML_BYTES: 65536,
    MIN_RELEVANCE_SCORE: 0.12,
  },
  SEARCH_PROVIDERS: {
    ENABLE_GOOGLE_GROUNDING: true,
    ENABLE_PUBMED: true,
    ENABLE_EUROPE_PMC: true,
    ENABLE_CROSSREF: true,
    ENABLE_OPENALEX: true,
    ENABLE_WIKIPEDIA: true,
    // External regional SERP coverage remains disabled until SERPER_API_KEY + flag enabled
    ENABLE_SERPER_SEARCH: process.env.ENABLE_SERPER_SEARCH === "true",
    get SERPER_API_KEY(): string {
      return process.env.SERPER_API_KEY || "";
    },
  },
  MODEL_ROLLOUT: {
    ENABLE_NEXT_GEN_MODEL_EXPERIMENT: process.env.GEMINI_ENABLE_NEXT_GEN_MODEL === "true",
    NEXT_GEN_VERIFICATION_MODEL: process.env.GEMINI_NEXT_GEN_MODEL || "gemini-3.8-flash",
  },

  /**
   * 🎯 SENSITIVE CLAIM DOMAINS (Risk-Based Dynamic Routing)
   *
   * Claims in these domains are routed to verification model (gemini-3.5-flash-lite).
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
  FORCE_PRO_MODEL: false,           // cost-effective: uses gemini-3.5-flash-lite
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

