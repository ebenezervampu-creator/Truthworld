import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { VerifiedClaim, ExtractedClaim } from "../types";
import { logger } from "../utils/logger";
import { getCache, setCache } from "../utils/memory-cache";

const db = () => admin.firestore();

/**
 * 🏛 Claim Cache Provider Interface
 * Supports pluggable cache implementations (NoOp, Firestore, Redis, etc.)
 */
export interface ClaimCacheProvider {
  getVerifiedClaim(claimHash: string): Promise<VerifiedClaim | null>;
  cacheVerifiedClaim(claim: VerifiedClaim, ttlSeconds: number): Promise<void>;
  invalidateClaim(claim: ExtractedClaim): Promise<void>;
  checkClaimCache(claims: ExtractedClaim[], domainContext?: string): Promise<{
    cached: VerifiedClaim[];
    stale: VerifiedClaim[];
    uncached: ExtractedClaim[];
  }>;
}

/**
 * 🚫 NoOp Cache Provider (Current Default)
 * Intentionally bypasses persistent claim/citation caching to lower cost and database noise.
 */
export class NoOpClaimCacheProvider implements ClaimCacheProvider {
  async getVerifiedClaim(claimHash: string): Promise<VerifiedClaim | null> {
    return null;
  }

  async cacheVerifiedClaim(claim: VerifiedClaim, ttlSeconds: number): Promise<void> {
    // No-op
  }

  async invalidateClaim(claim: ExtractedClaim): Promise<void> {
    // No-op
  }

  async checkClaimCache(claims: ExtractedClaim[], domainContext?: string): Promise<{
    cached: VerifiedClaim[];
    stale: VerifiedClaim[];
    uncached: ExtractedClaim[];
  }> {
    return { cached: [], stale: [], uncached: claims };
  }
}

/**
 * 🔥 Firestore Cache Provider
 * Re-implements production-grade persistent cache checks using Firestore collection 'claim_cache'.
 */
export class FirestoreClaimCacheProvider implements ClaimCacheProvider {
  private static readonly COLLECTION = "claim_cache";

  private normalizeText(text: string): string {
    return text.toLowerCase()
      .replace(/[^\p{L}\p{N}\s]/gu, "")
      .replace(/\s{2,}/g, " ")
      .trim();
  }

  private hashClaim(claimText: string): string {
    const normalized = this.normalizeText(claimText);
    return crypto.createHash("md5").update(normalized).digest("hex");
  }

  async getVerifiedClaim(claimHash: string): Promise<VerifiedClaim | null> {
    const cacheKey = `claim_cache:${claimHash}`;
    
    // L1: memory-cache
    const mem = getCache(cacheKey);
    if (mem) return mem as VerifiedClaim;

    // L2: Firestore
    try {
      const doc = await db().collection(FirestoreClaimCacheProvider.COLLECTION).doc(claimHash).get();
      if (!doc.exists) return null;

      const data = doc.data()!;
      const now = Date.now();
      if (data.expiresAt && now > data.expiresAt) {
        await doc.ref.delete().catch(() => {});
        return null;
      }

      const claim = data.claim as VerifiedClaim;
      setCache(cacheKey, claim, 3600); // 1 hour memory backup
      return claim;
    } catch (err) {
      logger.error("[FirestoreCache] Failed to fetch claim from Firestore", { claimHash, err: String(err) });
      return null;
    }
  }

  async cacheVerifiedClaim(claim: VerifiedClaim, ttlSeconds: number): Promise<void> {
    const textHash = this.hashClaim(claim.text);
    const cacheKey = `claim_cache:${textHash}`;

    try {
      setCache(cacheKey, claim, ttlSeconds);

      await db().collection(FirestoreClaimCacheProvider.COLLECTION).doc(textHash).set({
        claim,
        expiresAt: Date.now() + ttlSeconds * 1000,
        cachedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      logger.info("[FirestoreCache] Cached claim", { textHash });
    } catch (err) {
      logger.error("[FirestoreCache] Failed to cache claim", { textHash, err: String(err) });
    }
  }

  async invalidateClaim(claim: ExtractedClaim): Promise<void> {
    const textHash = this.hashClaim(claim.text);
    const cacheKey = `claim_cache:${textHash}`;
    try {
      setCache(cacheKey, null, 0); // Invalidate memory cache
      await db().collection(FirestoreClaimCacheProvider.COLLECTION).doc(textHash).delete();
      logger.info("[FirestoreCache] Invalidated claim", { textHash });
    } catch (err) {
      logger.error("[FirestoreCache] Failed to invalidate claim", { textHash, err: String(err) });
    }
  }

  async checkClaimCache(claims: ExtractedClaim[], domainContext?: string): Promise<{
    cached: VerifiedClaim[];
    stale: VerifiedClaim[];
    uncached: ExtractedClaim[];
  }> {
    const cached: VerifiedClaim[] = [];
    const stale: VerifiedClaim[] = [];
    const uncached: ExtractedClaim[] = [];

    const now = Date.now();

    for (const claim of claims) {
      const textHash = this.hashClaim(claim.text);
      const cachedClaim = await this.getVerifiedClaim(textHash);

      if (cachedClaim) {
        const isStale = (cachedClaim as any).updatedAt && (now - (cachedClaim as any).updatedAt > 7 * 24 * 60 * 60 * 1000); // 7 days stale threshold
        if (isStale) {
          stale.push(cachedClaim);
        } else {
          cached.push(cachedClaim);
        }
      } else {
        uncached.push(claim);
      }
    }

    return { cached, stale, uncached };
  }
}

// Singleton Registry & Active Cache Provider management
let activeProvider: ClaimCacheProvider = new NoOpClaimCacheProvider();

export function getClaimCacheProvider(): ClaimCacheProvider {
  return activeProvider;
}

export function setClaimCacheProvider(provider: ClaimCacheProvider) {
  activeProvider = provider;
}
