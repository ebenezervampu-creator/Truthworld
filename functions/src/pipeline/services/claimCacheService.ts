import * as admin from "firebase-admin";
import { VerifiedClaim, ClaimStatus, RichSource } from "../types";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { hashClaimText, hashSemanticClaimText } from "../utils/claim-normalization";
import { sanitizeClaimResponse } from "../utils/claim-response-sanitizer";
import {
  enforceClosedWorldCitationFirewall,
  isClosedWorldCacheEntryValid,
  isVerifiedRichSource,
} from "./urlVerificationService";

interface L1CacheEntry {
  claim: Partial<VerifiedClaim>;
  expiresAt: number;
}

/**
 * 🏛 Institutional Cross-Video Global Claim Cache (v15.0)
 * 
 * Provides ultra-fast, two-tier claim deduplication:
 * - Tier 1: In-Memory L1 LRU Cache (0ms, $0.00 cost)
 * - Tier 2: Persistent Firestore L2 Cache (collection: "claim_cache", $0.0000006 per read)
 * 
 * Slashes pipeline costs by up to 99.9% on recurring news, trending events,
 * and cross-video viral claims by bypassing LLM token generation & Google Search grounding.
 */
export class ClaimCacheService {
  private static readonly COLLECTION = "claim_cache";
  private static readonly CACHE_ENABLED = true;
  private static readonly L1_MAX_SIZE = 5000;
  private static readonly l1Cache = new Map<string, L1CacheEntry>();

  /**
   * Generates a stable hash for a claim after normalization.
   */
  private generateHash(text: string): string {
    return hashClaimText(text);
  }

  /**
   * Generates a semantic hash for a claim based on canonical entities.
   */
  private generateSemanticHash(text: string): string {
    return hashSemanticClaimText(text);
  }

  /**
   * Check in-memory L1 cache.
   */
  private getFromL1(hash: string): Partial<VerifiedClaim> | null {
    const entry = ClaimCacheService.l1Cache.get(hash);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt || !isClosedWorldCacheEntryValid(entry.claim)) {
      ClaimCacheService.l1Cache.delete(hash);
      return null;
    }
    // Refresh LRU order
    ClaimCacheService.l1Cache.delete(hash);
    ClaimCacheService.l1Cache.set(hash, entry);
    if (entry.claim && typeof entry.claim.reasoning === "string") {
      return {
        ...entry.claim,
        reasoning: sanitizeClaimResponse(entry.claim.reasoning, entry.claim.status),
      };
    }
    return entry.claim;
  }

  /**
   * Save to in-memory L1 cache with LRU eviction.
   */
  private setToL1(hash: string, claim: Partial<VerifiedClaim>, expiresAt: number): void {
    if (ClaimCacheService.l1Cache.size >= ClaimCacheService.L1_MAX_SIZE) {
      const oldestKey = ClaimCacheService.l1Cache.keys().next().value;
      if (oldestKey) ClaimCacheService.l1Cache.delete(oldestKey);
    }
    ClaimCacheService.l1Cache.set(hash, { claim, expiresAt });
  }

  /**
   * Retrieves a verified claim from the persistent cache.
   * Performs exact hash lookup first, with semantic entity hash fallback.
   */
  async get(text: string): Promise<Partial<VerifiedClaim> | null> {
    if (!ClaimCacheService.CACHE_ENABLED || !text) return null;

    const exactHash = this.generateHash(text);

    // 1. Check L1 Memory Cache (0ms)
    const l1Hit = this.getFromL1(exactHash);
    if (l1Hit) {
      return l1Hit;
    }

    try {
      // 2. Check L2 Firestore Cache
      let doc = await admin.firestore().collection(ClaimCacheService.COLLECTION).doc(exactHash).get();

      // Semantic entity hash fallback if exact hash misses
      if (!doc.exists) {
        const semanticHash = this.generateSemanticHash(text);
        const semQuery = await admin.firestore().collection(ClaimCacheService.COLLECTION)
          .where("semanticHash", "==", semanticHash)
          .limit(1)
          .get();
        if (!semQuery.empty) {
          doc = semQuery.docs[0];
        }
      }

      if (!doc.exists) return null;

      const data = doc.data();
      if (!data) return null;

      // Check TTL (default 180 days for historical, 30 days for general)
      const now = Date.now();
      if (data.expiresAt && now > data.expiresAt) {
        logger.info(`[ClaimCache] Cache expired for: ${text.substring(0, 50)}...`);
        return null;
      }

      // Closed-World Read Gate: reject legacy v1 or unverified URL cache entries so Claim re-verifies cleanly
      if (!isClosedWorldCacheEntryValid(data)) {
        logger.info(`[ClaimCache] Cache miss (stale/unverified schema) for: ${text.substring(0, 50)}...`);
        doc.ref.delete().catch(() => {});
        return null;
      }

      // Record hit asynchronously
      doc.ref.update({
        hitCount: admin.firestore.FieldValue.increment(1),
        lastHitAt: admin.firestore.FieldValue.serverTimestamp()
      }).catch(() => {});

      const verifiedRichSources = ((data.richSources || []) as RichSource[]).filter((s) => isVerifiedRichSource(s));
      if (verifiedRichSources.length === 0) {
        doc.ref.delete().catch(() => {});
        return null;
      }

      const cleanReasoning = sanitizeClaimResponse(data.reasoning, data.status as ClaimStatus);
      const cachedClaim: Partial<VerifiedClaim> = {
        status: data.status as ClaimStatus,
        reasoning: cleanReasoning,
        richSources: verifiedRichSources,
        verifiedAcademicMetadata: Array.isArray(data.verifiedAcademicMetadata) ? data.verifiedAcademicMetadata : undefined,
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        verificationConfidence: data.confidence || 0.85,
        displayLabel: data.displayLabel,
        evidenceLevel: data.evidenceLevel,
        evidenceDetails: data.evidenceDetails,
        consensusDetails: data.consensusDetails,
        classificationConfidence: data.classificationConfidence,
        historicalEvidenceConfidence: data.historicalEvidenceConfidence,
        isGrounded: true,
        verificationMethod: 'cache_hit'
      };

      // Populate L1 cache
      this.setToL1(exactHash, cachedClaim, data.expiresAt || (now + 30 * 24 * 60 * 60 * 1000));

      return cachedClaim;
    } catch (error) {
      logger.error("[ClaimCache] Failed to retrieve from cache", { error });
      return null;
    }
  }

  /**
   * Stores a verified claim in the persistent cache.
   * Closed-World Write Gate: rejects any claim without live HTTP-200 verified sources.
   */
  async set(claim: VerifiedClaim): Promise<void> {
    if (!ClaimCacheService.CACHE_ENABLED || !claim || !claim.text) return;

    const firewalled = enforceClosedWorldCitationFirewall(claim);
    const verifiedSources = (firewalled.richSources || []).filter((s) => isVerifiedRichSource(s));

    // Strict Quality + Closed-World Guard: Do NOT cache ungrounded timeouts, unverified stubs, missing sources, or unverified URLs
    if (
      !firewalled.status ||
      firewalled.status === 'verification_timeout' ||
      firewalled.status === 'unverified' ||
      firewalled.verificationMethod === 'llm_training' ||
      firewalled.sourceStatus === 'missing' ||
      verifiedSources.length === 0 ||
      (firewalled as any).processingMetadata?.requiresCitationRetry === true ||
      (firewalled.verificationConfidence !== undefined && firewalled.verificationConfidence < 0.65)
    ) {
      return;
    }

    try {
      const exactHash = this.generateHash(firewalled.text);
      const semanticHash = this.generateSemanticHash(firewalled.text);
      const now = Date.now();

      // Dynamic TTL based on claim importance and nature (180 days for facts/constants, 45 days for dynamic news)
      let ttlDays = 45;
      if (firewalled.nature === 'VERIFIABLE_FACT' || firewalled.nature === 'HISTORICAL_FACT') {
        ttlDays = 180;
      }

      const expiresAt = now + (ttlDays * 24 * 60 * 60 * 1000);

      const sanitizedReasoning = sanitizeClaimResponse(firewalled.reasoning, firewalled.status);
      const cachePayload: Partial<VerifiedClaim> = {
        status: firewalled.status,
        reasoning: sanitizedReasoning,
        richSources: verifiedSources,
        verifiedAcademicMetadata: firewalled.verifiedAcademicMetadata,
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        verificationConfidence: firewalled.verificationConfidence || 0.85,
        displayLabel: firewalled.displayLabel,
        evidenceLevel: firewalled.evidenceLevel,
        evidenceDetails: firewalled.evidenceDetails,
        consensusDetails: firewalled.consensusDetails,
        classificationConfidence: firewalled.classificationConfidence,
        historicalEvidenceConfidence: firewalled.historicalEvidenceConfidence,
        isGrounded: true,
        verificationMethod: 'cache_hit'
      };

      // 1. Populate L1 Memory Cache immediately
      this.setToL1(exactHash, cachePayload, expiresAt);

      // 2. Persist to L2 Firestore in background
      await admin.firestore().collection(ClaimCacheService.COLLECTION).doc(exactHash).set({
        originalText: firewalled.text,
        normalizedText: firewalled.text.toLowerCase().trim(),
        exactHash,
        semanticHash,
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        status: firewalled.status,
        reasoning: sanitizedReasoning,
        richSources: verifiedSources,
        verifiedAcademicMetadata: firewalled.verifiedAcademicMetadata || null,
        confidence: firewalled.verificationConfidence || 0.85,
        nature: firewalled.nature || "VERIFIABLE_FACT",
        displayLabel: firewalled.displayLabel || null,
        evidenceLevel: firewalled.evidenceLevel || null,
        evidenceDetails: firewalled.evidenceDetails || null,
        consensusDetails: firewalled.consensusDetails || null,
        classificationConfidence: firewalled.classificationConfidence || null,
        historicalEvidenceConfidence: firewalled.historicalEvidenceConfidence || null,
        isGrounded: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
        hitCount: 1,
        lastHitAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      logger.info(`[ClaimCache] Cached verified grounded claim (${PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION}): "${firewalled.text.substring(0, 50)}..." (TTL: ${ttlDays}d)`);
    } catch (error) {
      logger.error("[ClaimCache] Failed to set cache", { error });
    }
  }

  /**
   * Batch retrieval for maximum performance.
   * Checks L1 memory cache first, then batches Firestore reads with semantic fallback.
   */
  async getBatch(texts: string[]): Promise<Map<string, Partial<VerifiedClaim>>> {
    const results = new Map<string, Partial<VerifiedClaim>>();
    if (!ClaimCacheService.CACHE_ENABLED || texts.length === 0) return results;

    const remainingTexts: string[] = [];
    const textToHash = new Map<string, string>();

    // Step 1: Check L1 memory cache first
    for (const text of texts) {
      if (!text) continue;
      const hash = this.generateHash(text);
      textToHash.set(text, hash);
      const l1Hit = this.getFromL1(hash);
      if (l1Hit) {
        results.set(text, l1Hit);
      } else {
        remainingTexts.push(text);
      }
    }

    if (remainingTexts.length === 0) {
      return results;
    }

    try {
      const hashes = remainingTexts.map(t => textToHash.get(t)!);

      // Firestore 'in' queries are limited to 30 items
      const chunks: string[][] = [];
      for (let i = 0; i < hashes.length; i += 30) {
        chunks.push(hashes.slice(i, i + 30));
      }

      for (const chunk of chunks) {
        const query = await admin.firestore()
          .collection(ClaimCacheService.COLLECTION)
          .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
          .get();

        query.forEach(doc => {
          const data = doc.data();
          if (data && data.expiresAt && Date.now() > data.expiresAt) {
            return;
          }
          if (!isClosedWorldCacheEntryValid(data)) {
            doc.ref.delete().catch(() => {});
            return;
          }
          const verifiedRichSources = ((data.richSources || []) as RichSource[]).filter((s) => isVerifiedRichSource(s));
          if (verifiedRichSources.length === 0) {
            doc.ref.delete().catch(() => {});
            return;
          }
          const idx = hashes.indexOf(doc.id);
          if (idx !== -1) {
            const originalText = remainingTexts[idx];
            const cleanReasoning = sanitizeClaimResponse(data.reasoning, data.status as ClaimStatus);
            const cachedClaim: Partial<VerifiedClaim> = {
              status: data.status as ClaimStatus,
              reasoning: cleanReasoning,
              richSources: verifiedRichSources,
              verifiedAcademicMetadata: Array.isArray(data.verifiedAcademicMetadata) ? data.verifiedAcademicMetadata : undefined,
              evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
              verificationConfidence: data.confidence || 0.85,
              displayLabel: data.displayLabel,
              evidenceLevel: data.evidenceLevel,
              evidenceDetails: data.evidenceDetails,
              consensusDetails: data.consensusDetails,
              classificationConfidence: data.classificationConfidence,
              historicalEvidenceConfidence: data.historicalEvidenceConfidence,
              isGrounded: true,
              verificationMethod: 'cache_hit'
            };

            results.set(originalText, cachedClaim);
            this.setToL1(doc.id, cachedClaim, data.expiresAt || (Date.now() + 30 * 24 * 60 * 60 * 1000));
          }
        });
      }

      // Step 2: Semantic fallback for remaining misses (up to 5 items to avoid excessive queries)
      const semanticCandidates = remainingTexts.filter(t => !results.has(t)).slice(0, 5);
      for (const text of semanticCandidates) {
        const semHash = this.generateSemanticHash(text);
        const semSnap = await admin.firestore()
          .collection(ClaimCacheService.COLLECTION)
          .where("semanticHash", "==", semHash)
          .limit(1)
          .get();

        if (!semSnap.empty) {
          const doc = semSnap.docs[0];
          const data = doc.data();
          if (data && (!data.expiresAt || Date.now() <= data.expiresAt) && isClosedWorldCacheEntryValid(data)) {
            const verifiedRichSources = ((data.richSources || []) as RichSource[]).filter((s) => isVerifiedRichSource(s));
            if (verifiedRichSources.length === 0) {
              doc.ref.delete().catch(() => {});
              continue;
            }
            const cleanReasoning = sanitizeClaimResponse(data.reasoning, data.status as ClaimStatus);
            const cachedClaim: Partial<VerifiedClaim> = {
              status: data.status as ClaimStatus,
              reasoning: cleanReasoning,
              richSources: verifiedRichSources,
              verifiedAcademicMetadata: Array.isArray(data.verifiedAcademicMetadata) ? data.verifiedAcademicMetadata : undefined,
              evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
              verificationConfidence: data.confidence || 0.85,
              displayLabel: data.displayLabel,
              evidenceLevel: data.evidenceLevel,
              evidenceDetails: data.evidenceDetails,
              consensusDetails: data.consensusDetails,
              classificationConfidence: data.classificationConfidence,
              historicalEvidenceConfidence: data.historicalEvidenceConfidence,
              isGrounded: true,
              verificationMethod: 'cache_hit'
            };
            results.set(text, cachedClaim);
            const exactHash = textToHash.get(text)!;
            this.setToL1(exactHash, cachedClaim, data.expiresAt || (Date.now() + 30 * 24 * 60 * 60 * 1000));
          }
        }
      }
    } catch (error) {
      logger.error("[ClaimCache] Batch retrieval failed", { error });
    }

    return results;
  }

  /**
   * Batch save verified claims to cache.
   */
  async setBatch(claims: VerifiedClaim[]): Promise<void> {
    if (!ClaimCacheService.CACHE_ENABLED || claims.length === 0) return;
    await Promise.allSettled(claims.map(c => this.set(c)));
  }

  /**
   * Clears the L1 in-memory cache (useful for testing or cache invalidation).
   */
  static clearL1Cache(): void {
    ClaimCacheService.l1Cache.clear();
  }
}

export const claimCacheService = new ClaimCacheService();
