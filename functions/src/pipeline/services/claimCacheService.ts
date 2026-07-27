import * as admin from "firebase-admin";
import { VerifiedClaim, ClaimStatus, RichSource } from "../types";
import { logger } from "../utils/logger";
import { hashClaimText } from "../utils/claim-normalization";

/**
 * 🏛 v12.0: Institutional Claim Cache (Tier 1)
 * 
 * Stores and retrieves verified claims to bypass expensive AI/Search calls.
 * Uses SHA-256 hashing of normalized claim text for stable lookup.
 */
export class ClaimCacheService {
  private static readonly COLLECTION = "claim_cache";
  private static readonly CACHE_ENABLED = true;

  /**
   * Generates a stable hash for a claim after normalization.
   */
  private generateHash(text: string): string {
    return hashClaimText(text);
  }

  /**
   * Retrieves a verified claim from the persistent cache.
   */
  async get(text: string): Promise<Partial<VerifiedClaim> | null> {
    if (!ClaimCacheService.CACHE_ENABLED) return null;

    try {
      const hash = this.generateHash(text);
      const doc = await admin.firestore().collection(ClaimCacheService.COLLECTION).doc(hash).get();

      if (!doc.exists) return null;

      const data = doc.data();
      if (!data) return null;

      // Check TTL (default 180 days for historical, 30 days for general)
      const now = Date.now();
      if (data.expiresAt && now > data.expiresAt) {
        logger.info(`[ClaimCache] Cache expired for: ${text.substring(0, 50)}...`);
        return null;
      }

      // Record hit
      await doc.ref.update({
        hitCount: admin.firestore.FieldValue.increment(1),
        lastHitAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return {
        status: data.status as ClaimStatus,
        reasoning: data.reasoning,
        richSources: data.richSources as RichSource[],
        verificationConfidence: data.confidence,
        displayLabel: data.displayLabel,
        evidenceLevel: data.evidenceLevel,
        evidenceDetails: data.evidenceDetails,
        consensusDetails: data.consensusDetails,
        classificationConfidence: data.classificationConfidence,
        historicalEvidenceConfidence: data.historicalEvidenceConfidence,
        isGrounded: true,
        verificationMethod: 'cache_hit'
      };
    } catch (error) {
      logger.error("[ClaimCache] Failed to retrieve from cache", { error });
      return null;
    }
  }

  /**
   * Stores a verified claim in the persistent cache.
   */
  async set(claim: VerifiedClaim): Promise<void> {
    if (!ClaimCacheService.CACHE_ENABLED) return;
    
    // Do not cache timed-out or unverified claims
    if (!claim.status || claim.status === 'verification_timeout' || claim.status === 'unverified') return;

    try {
      const hash = this.generateHash(claim.text);
      const now = Date.now();
      
      // Dynamic TTL based on claim importance and nature (180 days for facts, 90 days for others)
      let ttlDays = 90;
      if (claim.nature === 'VERIFIABLE_FACT' || claim.nature === 'HISTORICAL_FACT') ttlDays = 180;
      
      const expiresAt = now + (ttlDays * 24 * 60 * 60 * 1000);

      await admin.firestore().collection(ClaimCacheService.COLLECTION).doc(hash).set({
        originalText: claim.text,
        normalizedText: claim.text.toLowerCase().trim(),
        status: claim.status,
        reasoning: claim.reasoning,
        richSources: claim.richSources || [],
        confidence: claim.verificationConfidence || 0.8,
        nature: claim.nature,
        displayLabel: claim.displayLabel,
        evidenceLevel: claim.evidenceLevel,
        evidenceDetails: claim.evidenceDetails,
        consensusDetails: claim.consensusDetails,
        classificationConfidence: claim.classificationConfidence,
        historicalEvidenceConfidence: claim.historicalEvidenceConfidence,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
        hitCount: 1,
        lastHitAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      logger.info(`[ClaimCache] Cached verified claim: "${claim.text.substring(0, 50)}..."`);
    } catch (error) {
      logger.error("[ClaimCache] Failed to set cache", { error });
    }
  }

  /**
   * Batch retrieval for performance.
   */
  async getBatch(texts: string[]): Promise<Map<string, Partial<VerifiedClaim>>> {
    const results = new Map<string, Partial<VerifiedClaim>>();
    if (!ClaimCacheService.CACHE_ENABLED || texts.length === 0) return results;

    try {
      const hashes = texts.map(t => this.generateHash(t));
      
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
            logger.info(`[ClaimCache] Batch cache expired for doc: ${doc.id}`);
            return;
          }
          const idx = hashes.indexOf(doc.id);
          if (idx !== -1) {
            const originalText = texts[idx];
            results.set(originalText, {
              status: data.status as ClaimStatus,
              reasoning: data.reasoning,
              richSources: data.richSources as RichSource[],
              verificationConfidence: data.confidence,
              displayLabel: data.displayLabel,
              evidenceLevel: data.evidenceLevel,
              evidenceDetails: data.evidenceDetails,
              consensusDetails: data.consensusDetails,
              classificationConfidence: data.classificationConfidence,
              historicalEvidenceConfidence: data.historicalEvidenceConfidence,
              isGrounded: true,
              verificationMethod: 'cache_hit'
            });
          }
        });
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
}

export const claimCacheService = new ClaimCacheService();
