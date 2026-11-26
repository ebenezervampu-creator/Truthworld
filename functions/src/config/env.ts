/**
 * 🌐 TRUTHWORLD CLOUD FUNCTIONS — CENTRAL ENVIRONMENT CONFIGURATION
 *
 * Industry Standard, Type-Safe Configuration Layer.
 *
 * All environment variables and cloud runtime configurations are declared,
 * validated, and documented in this central module.
 *
 * Developers should import `env` from `@config/env` or `@config` instead of
 * scattering raw `process.env` lookups throughout the codebase.
 */

export interface FirebaseConfig {
  projectId: string;
  databaseUrl: string;
  storageBucket: string;
  region: string;
  isEmulator: boolean;
}

export interface AIServiceConfig {
  geminiApiKey: string;
  fastTierModel: string;
  verificationModel: string;
  reasoningModel: string;
  extractionModel: string;
  consistencyModel: string;
  profilingModel: string;
  nextGenModel: string;
  enableNextGenModel: boolean;
  enableContextCaching: boolean;
  enableFusedGrounding: boolean;
}

export interface DubbingServiceConfig {
  elevenLabsApiKey: string;
  elevenLabsMaxConcurrency: number;
  enableDistributedTtsLeasing: boolean;
  assemblyAiKey: string;
  assemblyAiWebhookSecret: string;
  assemblyAiWebhookUrl?: string;
  translationProvider: string;
  translationLocation: string;
  dubbingTimeoutMs: number;
  dubbingReelThresholdMs: number;
}

export interface PaymentServiceConfig {
  cashfreeAppId: string;
  cashfreeSecretKey: string;
  cashfreeEnv: "TEST" | "SANDBOX" | "PRODUCTION";
}

export interface SearchServiceConfig {
  typesenseHost: string;
  typesensePort: number;
  typesenseProtocol: "http" | "https";
  typesenseAdminApiKey: string;
  typesenseSearchApiKey: string;
}

export interface SmtpConfig {
  host: string;
  port: number;
  email: string;
  appPassword: string;
  fromName: string;
  secure: boolean;
}

export interface AnalyticsConfig {
  enableBigQueryAnalytics: boolean;
  bigQueryDataset: string;
  bigQueryLocation: string;
}

export interface EnvironmentConfig {
  nodeEnv: "development" | "test" | "production";
  isProduction: boolean;
  isDevelopment: boolean;
  isTest: boolean;
  firebase: FirebaseConfig;
  ai: AIServiceConfig;
  dubbing: DubbingServiceConfig;
  payment: PaymentServiceConfig;
  search: SearchServiceConfig;
  smtp: SmtpConfig;
  analytics: AnalyticsConfig;
}

const nodeEnv = (process.env.NODE_ENV || "development").toLowerCase() as "development" | "test" | "production";
const isProduction = nodeEnv === "production";
const isTest = nodeEnv === "test";
const isDevelopment = !isProduction && !isTest;
const isEmulator = Boolean(process.env.FUNCTIONS_EMULATOR || process.env.FIREBASE_EMULATOR_HUB);

export const env: EnvironmentConfig = {
  nodeEnv,
  isProduction,
  isDevelopment,
  isTest,

  firebase: {
    projectId: process.env.GCP_PROJECT_ID || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "truthworld-1",
    databaseUrl: process.env.FIREBASE_DATABASE_URL || "https://truthworld-1-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: process.env.STORAGE_BUCKET || process.env.FIREBASE_STORAGE_BUCKET || "truthworld-1.firebasestorage.app",
    region: process.env.GCP_LOCATION || "asia-south1",
    isEmulator,
  },

  ai: {
    geminiApiKey: process.env.GEMINI_API_KEY || "",
    fastTierModel: process.env.GEMINI_FAST_TIER_MODEL || "gemini-3.5-flash-lite",
    verificationModel: process.env.GEMINI_MODEL_VERIFICATION || "gemini-3.8-flash",
    reasoningModel: process.env.GEMINI_MODEL_REASONING || "gemini-3.8-flash",
    extractionModel: process.env.GEMINI_MODEL_EXTRACTION || "gemini-3.5-flash-lite",
    consistencyModel: process.env.GEMINI_CONSISTENCY_MODEL || "gemini-3.8-flash",
    profilingModel: process.env.GEMINI_PROFILING_MODEL || "gemini-3.5-flash-lite",
    nextGenModel: process.env.GEMINI_NEXT_GEN_MODEL || "gemini-4-hydrogen",
    enableNextGenModel: process.env.GEMINI_ENABLE_NEXT_GEN_MODEL === "true",
    enableContextCaching: process.env.ENABLE_CONTEXT_CACHING !== "false",
    enableFusedGrounding: process.env.ENABLE_FUSED_GROUNDING !== "false",
  },

  dubbing: {
    elevenLabsApiKey: process.env.ELEVENLABS_API_KEY || "",
    elevenLabsMaxConcurrency: Number(process.env.ELEVENLABS_MAX_CONCURRENCY) || 4,
    enableDistributedTtsLeasing: process.env.ENABLE_DISTRIBUTED_TTS_LEASING === "true",
    assemblyAiKey: process.env.ASSEMBLYAI_KEY || "",
    assemblyAiWebhookSecret: process.env.ASSEMBLYAI_WEBHOOK_SECRET || process.env.ASSEMBLYAI_WEBHOOK_SECRET_FALLBACK || "",
    assemblyAiWebhookUrl: process.env.ASSEMBLYAI_WEBHOOK_URL,
    translationProvider: process.env.TRANSLATION_PROVIDER || "google-translate-v3",
    translationLocation: process.env.TRANSLATION_LOCATION || "asia-south1",
    dubbingTimeoutMs: Number(process.env.DUBBING_TIMEOUT_MS) || 900000,
    dubbingReelThresholdMs: Number(process.env.DUBBING_REEL_THRESHOLD_MS) || 60000,
  },

  payment: {
    cashfreeAppId: process.env.CASHFREE_APP_ID || "",
    cashfreeSecretKey: process.env.CASHFREE_SECRET_KEY || "",
    cashfreeEnv: ((process.env.CASHFREE_ENV || "SANDBOX").toUpperCase() as "TEST" | "SANDBOX" | "PRODUCTION"),
  },

  search: {
    typesenseHost: process.env.TYPESENSE_HOST || "localhost",
    typesensePort: Number(process.env.TYPESENSE_PORT) || 8108,
    typesenseProtocol: (process.env.TYPESENSE_PROTOCOL === "https" ? "https" : "http"),
    typesenseAdminApiKey: process.env.TYPESENSE_ADMIN_API_KEY || "",
    typesenseSearchApiKey: process.env.TYPESENSE_SEARCH_API_KEY || "",
  },

  smtp: {
    host: process.env.SMTP_HOST || "smtp.gmail.com",
    port: Number(process.env.SMTP_PORT) || 587,
    email: process.env.SMTP_EMAIL || "",
    appPassword: process.env.SMTP_APP_PASSWORD || "",
    fromName: process.env.SMTP_FROM_NAME || "TruthWorld",
    secure: process.env.SMTP_SECURE === "true",
  },

  analytics: {
    enableBigQueryAnalytics: process.env.ENABLE_BIGQUERY_ANALYTICS === "true",
    bigQueryDataset: process.env.BIGQUERY_DATASET || "truthworld_analytics",
    bigQueryLocation: process.env.BIGQUERY_LOCATION || "asia-south1",
  },
};
