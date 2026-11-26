/**
 * 🔍 SEARCH & DISCOVERY BARREL
 *
 * Provides Search Infrastructure for TruthWorld:
 * - AI Search Assistant (conversational factual answers)
 * - Full-text and vector search endpoints (Typesense)
 * - Real-time synchronization triggers (videos, channels, topics)
 * - Typesense cluster backfill utilities
 */

export * from "./aiSearch";
export * from "./searchBackend";
export * from "./typesense/typesenseTriggers";
export * from "./typesense/backfillTypesense";
