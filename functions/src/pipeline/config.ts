/**
 * 🛠️ PIPELINE CONFIGURATION (HARDCODED FOR DEPLOYMENT STABILITY)
 * 
 * NOTE: These keys are added directly to bypass Secret Manager cold-start 
 * issues or health check failures. We will move these back to secrets
 * once the deployment is stable.
 */

export const PIPELINE_CONFIG = {
  ASSEMBLYAI_KEY: "e8ed1bad856e4c329e856b32ffdd7fdf",
  ELEVENLABS_API_KEY: "sk_387da0e729167eb8d919e10ac232c763f76023c6dcb673a0",
  GEMINI_API_KEY: "AIzaSyBocU6vG96jzfLaZiXyoM60n1_BxISNT9I",
  GOOGLE_TRANSLATION_API_KEY: "AIzaSyCCWwSuUAB-9-1VkyBQ_vMY6gK2D-ifF_U",
  FFMPEG_SERVICE_URL: "https://placeholder.run",
  PUBLIC_FUNCTION_BASE_URL: "https://asia-south1-truthworld-1.cloudfunctions.net",
  VIDEO_BUCKET: "truthworld-1.firebasestorage.app", // Fallback default

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
