import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";

export type QuotaMetric =
  | "transcriptionMinutes"
  | "dubbingMinutes"
  | "credibilityChecks"
  | "fastVerifications"
  | "translationCharacters";

export interface QuotaLimits {
  transcriptionMinutes: number;
  dubbingMinutes: number;
  credibilityChecks: number;
  fastVerifications: number;
  translationCharacters: number;
}

export type SubscriptionTier = "free" | "creator" | "enterprise";

export const TIER_LIMITS: Record<SubscriptionTier, QuotaLimits> = {
  free: {
    transcriptionMinutes: 30,
    dubbingMinutes: 10,
    credibilityChecks: 50,
    fastVerifications: 50,
    translationCharacters: 20000,
  },
  creator: {
    transcriptionMinutes: 300,
    dubbingMinutes: 120,
    credibilityChecks: 500,
    fastVerifications: 500,
    translationCharacters: 200000,
  },
  enterprise: {
    transcriptionMinutes: 3000,
    dubbingMinutes: 1200,
    credibilityChecks: 5000,
    fastVerifications: 5000,
    translationCharacters: 2000000,
  },
};

/**
 * Helper to obtain the current YYYY-MM-DD string in UTC.
 */
function getTodayString(): string {
  const d = new Date();
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

interface TierCacheEntry {
  tier: SubscriptionTier;
  expiresAt: number;
}

const tierCache = new Map<string, TierCacheEntry>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Resolves a user's subscription tier by checking their channels and profile.
 * Employs an in-memory cache to avoid duplicate database queries.
 */
export async function getUserTier(uid: string): Promise<SubscriptionTier> {
  if (!uid || uid === "system_automated") {
    return "enterprise"; // System automation has custom enterprise limits
  }

  const now = Date.now();
  const cached = tierCache.get(uid);
  if (cached && cached.expiresAt > now) {
    return cached.tier;
  }

  try {
    const db = admin.firestore();
    let resolvedTier: SubscriptionTier = "free";
    
    // 1. Check user document directly
    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      const uTier = userDoc.data()?.subscriptionTier || userDoc.data()?.tier;
      if (uTier === "enterprise") {
        resolvedTier = "enterprise";
      } else if (uTier === "premium" || uTier === "pro" || uTier === "creator" || uTier === "elite") {
        resolvedTier = "creator";
      }
    }

    if (resolvedTier === "free") {
      // 2. Check channel monetization tier
      const channelSnap = await db
        .collection("channels")
        .where("ownerId", "==", uid)
        .limit(1)
        .get();

      if (!channelSnap.empty) {
        const tier = channelSnap.docs[0].data()?.monetizationTier;
        if (tier === "enterprise") {
          resolvedTier = "enterprise";
        } else if (tier === "premium" || tier === "pro" || tier === "elite") {
          resolvedTier = "creator";
        }
      }
    }

    tierCache.set(uid, {
      tier: resolvedTier,
      expiresAt: now + CACHE_TTL_MS
    });

    return resolvedTier;
  } catch (error) {
    logger.warn(`[QuotaEnforcer] Error resolving tier for user ${uid}, defaulting to free`, { error });
    return "free";
  }
}

/**
 * Validates whether a user has exceeded their daily quota for a given metric.
 * Throws a HttpsError if the quota is exhausted.
 */
export async function enforceQuota(
  uid: string,
  metric: QuotaMetric,
  requestedAmount: number = 1
): Promise<void> {
  if (!uid || uid === "system_automated") return;

  const todayStr = getTodayString();
  const db = admin.firestore();
  
  // 1. Resolve user tier and limits
  const tier = await getUserTier(uid);
  const limits = TIER_LIMITS[tier];
  const maxLimit = limits[metric];

  // 2. Get current daily usage
  const usageRef = db
    .collection("users")
    .doc(uid)
    .collection("usage")
    .doc(todayStr);

  const usageSnap = await usageRef.get();
  const currentUsage = usageSnap.exists ? (usageSnap.data()?.[metric] as number || 0) : 0;

  if (currentUsage + requestedAmount > maxLimit) {
    logger.error(`[QuotaEnforcer] Quota exhausted for user ${uid} on ${metric}`, {
      tier,
      metric,
      currentUsage,
      requestedAmount,
      limit: maxLimit,
    });

    throw new HttpsError(
      "resource-exhausted",
      `Daily quota exhausted for ${metric} (${currentUsage}/${maxLimit} limit under ${tier} tier). Please upgrade your subscription.`
    );
  }
}

/**
 * Records and increments daily metric usage for a user.
 */
export async function recordUsage(
  uid: string,
  metric: QuotaMetric,
  amount: number
): Promise<void> {
  if (!uid || uid === "system_automated") return;

  const todayStr = getTodayString();
  const db = admin.firestore();

  try {
    const usageRef = db
      .collection("users")
      .doc(uid)
      .collection("usage")
      .doc(todayStr);

    await usageRef.set(
      {
        [metric]: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info(`[QuotaEnforcer] Recorded ${amount} for ${metric} (user: ${uid})`);
  } catch (error) {
    logger.error(`[QuotaEnforcer] Failed to record usage for user ${uid}`, { error });
  }
}
