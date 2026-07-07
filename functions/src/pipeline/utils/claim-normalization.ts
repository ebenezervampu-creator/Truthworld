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
 * Generates a stable SHA-256 hash of normalized claim text.
 * Used by: claim cache (Firestore doc ID), dedup guard, telemetry.
 */
export function hashClaimText(text: string): string {
  const normalized = normalizeClaimText(text);
  return crypto.createHash("sha256").update(normalized).digest("hex");
}
