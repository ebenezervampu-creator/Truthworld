/**
 * Unified Claim Normalization & Hashing
 *
 * SINGLE SOURCE OF TRUTH for all claim text normalization and hashing
 * across the pipeline. Previously, claimCacheService used SHA-256 with
 * partial punctuation removal while claimVerification used MD5 with full
 * Unicode normalization — causing cache misses for identical claims.
 *
 * Rules:
 *   1. Lowercase
 *   2. Remove ALL non-letter/non-number characters (Unicode-safe)
 *   3. Collapse whitespace
 *   4. Trim
 *   5. SHA-256 hash
 */

import * as crypto from "crypto";

/**
 * Normalizes claim text for comparison and hashing.
 * Used by: cache, dedup guard, Jaccard dedup, and anywhere claims are compared.
 */
export function normalizeClaimText(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Common entity and abbreviation synonyms for semantic cache deduplication.
 */
const CANONICAL_SYNONYMS: Record<string, string> = {
  "fed": "federal reserve",
  "bps": "basis points",
  "covid19": "covid",
  "covid-19": "covid",
  "coronavirus": "covid",
  "gdp": "gross domestic product",
  "pres": "president",
  "pm": "prime minister",
  "sec": "securities and exchange commission",
  "rbi": "reserve bank of india",
  "pct": "percent",
  "%": "percent",
  "bn": "billion",
  "mn": "million",
  "hiked": "raised",
  "hike": "raise",
  "hikes": "raises",
  "increased": "raised",
  "fallen": "fell",
};

const STOP_WORDS = new Set([
  "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
  "has", "have", "had", "do", "does", "did",
  "in", "on", "at", "by", "for", "with", "about", "against", "between",
  "into", "through", "during", "before", "after", "above", "below",
  "to", "from", "up", "down", "of", "off", "over", "under", "again",
  "further", "then", "once", "that", "this", "these", "those", "and", "or",
]);

/**
 * Generates a canonical semantic token set for a claim, stripping stop words
 * and normalizing synonyms. Allows matching paraphrased claims.
 */
export function semanticCanonicalizeClaim(text: string): string {
  let cleaned = text.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, " ");
  // Replace synonyms
  for (const [abbr, expanded] of Object.entries(CANONICAL_SYNONYMS)) {
    const regex = new RegExp(`\\b${abbr}\\b`, "g");
    cleaned = cleaned.replace(regex, expanded);
  }
  const tokens = cleaned
    .split(/\s+/)
    .filter(t => (t.length > 1 || /\d/.test(t)) && !STOP_WORDS.has(t));
  
  // Return sorted unique tokens joined by space
  return Array.from(new Set(tokens)).sort().join(" ");
}

/**
 * Generates a stable SHA-256 hash of normalized claim text.
 * Used by: claim cache (Firestore doc ID), dedup guard, telemetry.
 */
export function hashClaimText(text: string): string {
  const normalized = normalizeClaimText(text);
  return crypto.createHash("sha256").update(normalized).digest("hex");
}

/**
 * Generates a semantic hash based on canonical entity tokens.
 * Matches paraphrased statements expressing the same core factual relationship.
 */
export function hashSemanticClaimText(text: string): string {
  const canonical = semanticCanonicalizeClaim(text);
  return crypto.createHash("sha256").update(canonical).digest("hex");
}

const LIVE_TIME_SENSITIVE_MARKER_RX =
  /\b(today|yesterday|this morning|this afternoon|tonight|just now|just in|breaking|recently|this week|this month|this year|right now|currently|presently|current|as of now|at present)\b/i;

const YEAR_TOKEN_RX =
  /\b(1[0-9]{3}|20[0-9]{2}|21[0-9]{2})\b(?!\s*(?:km|kilometers|kilometres|m|meters|metres|cm|mm|kg|g|mg|mcg|ml|l|liters|litres|ft|feet|mi|miles|mph|kph|watts|w|hz|khz|mhz|ghz|rpm|bps|calories|kcal|crore|lakh|million|billion|trillion|dollars|usd|inr|eur|gbp|rupees)\b)/gi;

export function hasLiveTimeMarker(claimText: string): boolean {
  if (!claimText) return false;
  return LIVE_TIME_SENSITIVE_MARKER_RX.test(claimText);
}

export function extractFourDigitYears(claimText: string): number[] {
  if (!claimText) return [];
  const matches = claimText.match(YEAR_TOKEN_RX) || [];
  return matches.map((m) => Number(m)).filter((y) => Number.isFinite(y));
}

/**
 * Returns true when a claim references strictly settled past calendar years (< current UTC year)
 * and carries no live/breaking present-tense markers.
 */
export function isSettledPastYearClaim(claimText: string, now: Date = new Date()): boolean {
  if (!claimText || hasLiveTimeMarker(claimText)) return false;
  const years = extractFourDigitYears(claimText);
  if (years.length === 0) return false;
  const currentUtcYear = now.getUTCFullYear();
  return years.every((y) => y < currentUtcYear);
}

/**
 * Detects volatile/breaking assertions that require fresh short-TTL verification.
 * Settled past years (< current UTC year) are NOT marked volatile unless paired with live markers.
 */
export function isTimeSensitiveClaim(claimText: string, now: Date = new Date()): boolean {
  if (!claimText) return false;
  if (hasLiveTimeMarker(claimText)) return true;
  const currentUtcYear = now.getUTCFullYear();
  const years = extractFourDigitYears(claimText);
  return years.some((y) => y >= currentUtcYear);
}

