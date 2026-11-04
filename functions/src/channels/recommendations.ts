import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../pipeline/utils/logger";
import { verifyAuth } from "../utils/auth";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { sanitizePublicChannel, isPublicActive } from "../economy/leaderboards";

export interface AlgorithmWeights {
  engagement: number;
  freshness: number;
  channelAffinity: number;
  topicAffinity: number;
  twoTowerAffinity: number;
  trending: number;
  credibility: number;
  watchCompletion: number;
}

export const DEFAULT_WEIGHTS: AlgorithmWeights = {
  engagement: 0.20,
  freshness: 0.15,
  channelAffinity: 0.15,
  topicAffinity: 0.15,
  twoTowerAffinity: 0.10,
  trending: 0.10,
  credibility: 0.10,
  watchCompletion: 0.05,
};

import { getCache, setCache } from "../shared/memory-cache";

const db = () => admin.firestore();

/**
 * High-performance candidate pool caching helper.
 * Eliminates redundant Firestore reads across concurrent user requests (scales to millions).
 */
async function fetchCachedPool(
  cacheKey: string,
  ttlSeconds: number,
  queryFn: () => Promise<admin.firestore.QuerySnapshot>
): Promise<admin.firestore.DocumentSnapshot[]> {
  const cached = getCache<admin.firestore.DocumentSnapshot[]>(cacheKey);
  if (cached && Array.isArray(cached) && cached.length > 0) {
    return cached;
  }
  try {
    const snap = await queryFn();
    if (snap && snap.docs && snap.docs.length > 0) {
      setCache(cacheKey, snap.docs, ttlSeconds);
      return snap.docs;
    }
  } catch (err) {
    logger.warn(`[fetchCachedPool] Query failed for ${cacheKey}:`, err);
  }
  return [];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRUTHWORLD ALGORITHM — Server-Side Scoring Engine
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 10 Fact-Checking & High-Credibility Categories in TruthWorld:
 * Business, History, News, Education, Science, Technology, Finance, Health, Documentary, Fitness.
 */
const FACT_CHECKING_CATEGORIES = new Set([
  "business",
  "history",
  "news",
  "education",
  "science",
  "technology",
  "finance",
  "health",
  "documentary",
  "fitness",
]);

function isFactCheckRelevantCategory(category?: string): boolean {
  if (!category) return false;
  const clean = category.toLowerCase().trim();
  if (FACT_CHECKING_CATEGORIES.has(clean)) return true;
  if (clean.includes("news") || clean.includes("politics")) return true;
  if (clean.includes("tech") || clean.includes("science")) return true;
  if (clean.includes("business") || clean.includes("finance") || clean.includes("economic")) return true;
  if (clean.includes("health") || clean.includes("fitness")) return true;
  if (clean.includes("history") || clean.includes("documentary")) return true;
  if (clean.includes("education")) return true;
  return false;
}

/**
 * ⚖️ CALCULATE DISCOVERY SCORE (Additive + Tier Boost + Topic Affinity)
 *
 * Enhanced with:
 * - Topic Affinity scoring (user's interests map + followed topics)
 * - Credibility as eligibility GATE (not small boost)
 * - Watched-video penalty
 * - Creator exposure tracking
 * - Session continuation awareness via recent watches
 * - Novelty penalty for repeated sub-topics
 * - Fact-Checking Priority Boost for the 10 High-Credibility Categories
 *
 * Normalized to 0-10 scale + Tier Baseline.
 */
function calculateDiscoveryScore(params: {
  category?: string;
  isFactChecked?: boolean;
  isCredibilityVerified: boolean;
  trustScore?: number;
  isFlagged?: boolean;
  createdAt: number;       // epoch ms
  engagementRate: number;  // 0.0 - 1.0 (likes/views)
  isSubscribed: boolean;
  momentum: number;        // 0.0 - 1.0 (trend)
  tier: "basic" | "creator" | "advanced" | "elite";
  inactiveDays: number;    // Days since last upload
  topicAffinityScore: number; // 0.0 - 10.0 (from user interests)
  isAlreadyWatched: boolean;
  isNotInterested: boolean;
  watchCompletion?: number; // 0.0 - 1.0 average completion rate
  noveltyPenalty: number;   // 0.0 - 5.0 penalty for same sub-topic spam
  twoTowerAffinity?: number; // 0.0 - 1.0 (Two-Tower neural semantic affinity)
  weights?: AlgorithmWeights; // A/B test variant weights (optional)
}): number {
  // ── Credibility Gate ─────────────────────────────────────────────────────
  // If video has proven low trust score (< 2.0 on 10 scale) or is flagged low trust → GATE IT OUT
  if (params.trustScore !== undefined && params.trustScore < 2.0) {
    return 0;
  }
  if (params.isFlagged && (params.trustScore ?? 10) < 3.0) {
    return 0;
  }

  // ── Not Interested Gate ────────────────────────────────────────────────
  if (params.isNotInterested) {
    return 0;
  }

  const now = Date.now();
  const ageHours = (now - params.createdAt) / 3600000;

  // ── Component Normalization (0-10) ────────────────────────────────────
  const credibilityBonus = params.trustScore !== undefined
    ? Math.min(10, Math.max(0, params.trustScore))
    : (params.isCredibilityVerified ? 7.5 : 5.0);
  const engagementScore = Math.min(10, params.engagementRate * 100);
  const recencyScore = 10 * Math.exp(-ageHours / 72); // 72h half-life
  const followScore = params.isSubscribed ? 10 : 0;
  const momentumScore = Math.min(10, params.momentum * 10);
  const topicScore = Math.min(10, params.topicAffinityScore);
  const completionScore = Math.min(10, (params.watchCompletion ?? 0.5) * 10);
  const twoTowerScore = Math.min(10, (params.twoTowerAffinity ?? 0.5) * 10);

  // ── Additive Weighting (A/B test-aware: uses variant weights if available) ──
  const w = params.weights || DEFAULT_WEIGHTS;

  let baseScore =
    (engagementScore * w.engagement) +
    (recencyScore * w.freshness) +
    (followScore * w.channelAffinity) +
    (topicScore * w.topicAffinity) +
    (twoTowerScore * w.twoTowerAffinity) +
    (momentumScore * w.trending) +
    (credibilityBonus * w.credibility) +
    (completionScore * w.watchCompletion);

  // ── Tier Baseline Boosts (The Moat) ────────────────────────────────────
  let tierBoost = {
    elite: 2.0,
    advanced: 1.0,
    creator: 0.5,
    basic: 0.0
  }[params.tier] || 0;

  // Hardening A: Soft Decay for Inactive Channels (60+ days)
  if (params.inactiveDays >= 60 && tierBoost > 0) {
    tierBoost *= 0.5;
  }

  // ── Fact-Checking Priority Boost (10 High-Credibility Categories) ───────
  let factCheckCategoryBoost = 0;
  if (isFactCheckRelevantCategory(params.category)) {
    if (params.isFactChecked || params.isCredibilityVerified || (params.trustScore !== undefined && params.trustScore >= 3.5)) {
      factCheckCategoryBoost += 3.5;
      if (params.trustScore !== undefined && params.trustScore >= 4.0) {
        factCheckCategoryBoost += 1.5;
      }
    }
  }

  // ── Penalties ─────────────────────────────────────────────────────────
  let penalty = 0;

  // Already watched → significant derank
  if (params.isAlreadyWatched) {
    penalty += 3.0;
  }

  // Novelty penalty → exponential for same sub-topic spam
  penalty += params.noveltyPenalty;

  const rawScore = baseScore + tierBoost + factCheckCategoryBoost - penalty;
  // If credibility gate passed and not marked "not interested", ensure a minimal positive baseline (0.1)
  // so valid videos are ranked lower rather than discarded entirely to prevent 0-video starvation.
  return Math.max(0.1, rawScore);
}

/**
 * 🏠 GET HOME FEED (HTTPS)
 * Returns a personalized, trust-first content mix with meritocratic discovery.
 *
 * Enhanced with:
 * - Pool E: Topic Pool (videos matching user's followed topics)
 * - Pool F: Long-tail creators (< 500 views, verified)
 * - Pool G: Exploding creators (high momentum channels)
 * - User interest scoring via interests map + savedTopics
 * - Credibility eligibility gate (low trust + flagged = excluded)
 * - Creator exposure budget (max 18% per creator)
 * - Watched-video penalty
 * - Richer response with more fields for client
 * - Recommendation reason explanations
 */
export const getHomeFeed = onRequest(
  { region: "asia-south1", cors: true, memory: "512MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    // L-39: Authenticate caller to resolve userId. Prevents probing other users' private watch history and saved topics.
    const authUser = await verifyAuth(req as any);
    const userId = authUser ? authUser.uid : null;
    const limit = Math.min(Number(req.query.limit) || 24, 60);
    const category = req.query.category as string;
    const startAfterTs = req.query.startAfter ? Number(req.query.startAfter) : null;

    try {
      // ══════════════════════════════════════════════════════════════════════
      // 1. Fetch User Context (Following, Interests, Watched, Topics)
      // ══════════════════════════════════════════════════════════════════════
      let following: string[] = [];
      let userInterests: Record<string, number> = {};
      let followedTopicSlugs: string[] = [];
      let watchedVideoIds: Set<string> = new Set();
      let notInterestedVideoIds: Set<string> = new Set();
      let userEmbedding: number[] | null = null;

      if (userId) {
        const userCtxCacheKey = `user_feed_ctx_${userId}`;
        const cachedCtx = getCache<{
          following: string[];
          userInterests: Record<string, number>;
          followedTopicSlugs: string[];
          watchedVideoIds: string[];
          notInterestedVideoIds: string[];
          userEmbedding: number[] | null;
        }>(userCtxCacheKey);

        if (cachedCtx) {
          following = cachedCtx.following;
          userInterests = cachedCtx.userInterests;
          followedTopicSlugs = cachedCtx.followedTopicSlugs;
          watchedVideoIds = new Set(cachedCtx.watchedVideoIds);
          notInterestedVideoIds = new Set(cachedCtx.notInterestedVideoIds);
          userEmbedding = cachedCtx.userEmbedding;
        } else {
          try {
            const [userSnap, savedTopicsSnap, watchHistorySnap] = await Promise.all([
              db().collection("users").doc(userId).get(),
              db().collection("users").doc(userId).collection("savedTopics").limit(20).get(),
              db().collection("users").doc(userId).collection("watch_history")
                .orderBy("watchedAt", "desc")
                .limit(40)
                .get()
            ]);

            if (userSnap.exists) {
              const userData = userSnap.data() as any;
              following = userData?.following || [];
              userInterests = userData?.interests || {};
              notInterestedVideoIds = new Set(userData?.notInterestedVideoIds || []);
              userEmbedding = userData?.userEmbedding || userData?.embedding || null;
            }

            followedTopicSlugs = savedTopicsSnap.docs.map(d => d.id);
            watchedVideoIds = new Set(watchHistorySnap.docs.map(d => d.id));

            setCache(userCtxCacheKey, {
              following,
              userInterests,
              followedTopicSlugs,
              watchedVideoIds: Array.from(watchedVideoIds),
              notInterestedVideoIds: Array.from(notInterestedVideoIds),
              userEmbedding,
            }, 45); // 45s TTL for active browsing sessions
          } catch (err) {
            logger.warn("[getHomeFeed] Failed to fetch user data:", err);
          }
        }
      }
      const poolPromises: Promise<admin.firestore.DocumentSnapshot[]>[] = [];
      const cleanCat = (category && category.toLowerCase() !== "all" && category.trim().length > 0) ? category.trim() : null;
      const catKey = cleanCat ? cleanCat.toLowerCase() : "all";

      // Pool A: Trust Pool (Verified videos, cached 60s for scale to millions)
      poolPromises.push(
        fetchCachedPool(`pool_trust_${catKey}`, 60, () => {
          let q: admin.firestore.Query = db().collection("videos")
            .where("credibilityVerified", "==", true);
          if (cleanCat) {
            q = q.where("category", "==", cleanCat);
          }
          return q.orderBy("createdAt", "desc").limit(40).get();
        })
      );

      // Pool B: Recency Pool (Latest videos, cached 60s)
      poolPromises.push(
        fetchCachedPool(`pool_recency_${catKey}`, 60, () => {
          let q: admin.firestore.Query = db().collection("videos");
          if (cleanCat) {
            q = q.where("category", "==", cleanCat);
          }
          return q.orderBy("createdAt", "desc").limit(40).get();
        })
      );

      // Pool B2: Recency Pool by uploadedAt (Fallback if createdAt missing, cached 60s)
      poolPromises.push(
        fetchCachedPool(`pool_uploaded_${catKey}`, 60, () => {
          let q: admin.firestore.Query = db().collection("videos");
          if (cleanCat) {
            q = q.where("category", "==", cleanCat);
          }
          return q.orderBy("uploadedAt", "desc").limit(40).get();
        })
      );

      // Pool C: Newcomer Pool (Verified, Low Views, cached 60s)
      poolPromises.push(
        fetchCachedPool(`pool_newcomer_${catKey}`, 60, () => {
          let q: admin.firestore.Query = db().collection("videos")
            .where("credibilityVerified", "==", true)
            .where("viewCount", "<=", 1000);
          if (cleanCat) {
            q = q.where("category", "==", cleanCat);
          }
          return q.orderBy("viewCount", "asc").limit(10).get();
        })
      );

      // Pool D: Following Pool (If user logged in, cached 45s)
      if (userId && following.length > 0) {
        poolPromises.push(
          fetchCachedPool(`pool_following_${userId}_${catKey}`, 45, () => {
            let q: admin.firestore.Query = db().collection("videos")
              .where("channelId", "in", following.slice(0, 10));
            if (cleanCat) {
              q = q.where("category", "==", cleanCat);
            }
            return q.orderBy("createdAt", "desc").limit(20).get();
          })
        );
      }

      // Pool E: Topic Pool (Videos matching user's followed topics, cached 45s)
      if (followedTopicSlugs.length > 0) {
        poolPromises.push(
          fetchCachedPool(`pool_topic_${userId}_${catKey}`, 45, () => {
            let q: admin.firestore.Query = db().collection("videos")
              .where("topics", "array-contains-any", followedTopicSlugs.slice(0, 10));
            if (cleanCat) {
              q = q.where("category", "==", cleanCat);
            }
            return q.orderBy("createdAt", "desc").limit(20).get();
          })
        );
      }

      // Pool F: Long-tail Creators (< 500 views, quality content, cached 60s)
      poolPromises.push(
        fetchCachedPool(`pool_longtail_${catKey}`, 60, () => {
          let q: admin.firestore.Query = db().collection("videos")
            .where("viewCount", "<=", 500);
          if (cleanCat) {
            q = q.where("category", "==", cleanCat);
          }
          return q.orderBy("viewCount", "asc").limit(10).get();
        })
      );

      // Pool H: Neural Two-Tower Vector Retrieval Pool (Firestore Vector Search / Vertex AI)
      if (userEmbedding && Array.isArray(userEmbedding) && userEmbedding.length > 0) {
        try {
          const colRef = db().collection("videos");
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const vectorQuery = (colRef as any).findNearest({
            vectorField: "embedding",
            queryVector: userEmbedding,
            limit: 30,
            distanceMeasure: "COSINE",
          });
          poolPromises.push(
            vectorQuery.get().then((snap: any) => snap.docs as admin.firestore.DocumentSnapshot[])
          );
        } catch (vectorErr) {
          logger.warn("[getHomeFeed] Pool H (Two-Tower Vector Search) query failed:", vectorErr);
        }
      }

      // Pool G: Exploding Creators (via channel trend) — handled in scoring phase

      const poolResults = await Promise.allSettled(poolPromises);
      const uniqueCandidateDocs = new Map<string, admin.firestore.DocumentSnapshot>();
      poolResults.forEach((result, idx) => {
        if (result.status === "fulfilled" && Array.isArray(result.value)) {
          result.value.forEach(doc => {
            if (doc && doc.id && !uniqueCandidateDocs.has(doc.id)) {
              uniqueCandidateDocs.set(doc.id, doc);
            }
          });
        } else if (result.status === "rejected") {
          logger.warn(`[getHomeFeed] Candidate pool ${idx} failed to load:`, result.reason);
        }
      });

      // ══════════════════════════════════════════════════════════════════════
      // 3. Category Validation & Resilient Fallback
      // ══════════════════════════════════════════════════════════════════════
      let allCandidateDocs = Array.from(uniqueCandidateDocs.values());
      if (cleanCat) {
        const filtered = allCandidateDocs.filter(d => {
          const c = (d.data()?.category || "").toString().trim().toLowerCase();
          return c === cleanCat.toLowerCase();
        });
        if (filtered.length >= 10) {
          allCandidateDocs = filtered;
        }
      }

      if (allCandidateDocs.length === 0) {
        try {
          let fallbackQuery: admin.firestore.Query = db().collection("videos").limit(40);
          if (cleanCat) {
            fallbackQuery = fallbackQuery.where("category", "==", cleanCat);
          }
          const fallbackSnap = await fallbackQuery.get();
          allCandidateDocs = fallbackSnap.docs.length > 0
            ? fallbackSnap.docs
            : (await db().collection("videos").limit(40).get()).docs;
        } catch (_) {}
      }

      // ══════════════════════════════════════════════════════════════════════
      // 4. Batch Fetch Channel Metadata (Tier, Trend, Inactivity) with L1 Cache
      // ══════════════════════════════════════════════════════════════════════
      const channelIds = [...new Set(allCandidateDocs.map(d => d.data()?.channelId).filter((id): id is string => !!id))];
      const channelsMap: Record<string, any> = {};

      if (channelIds.length > 0) {
        const uncachedChannelIds: string[] = [];
        for (const cid of channelIds) {
          const cached = getCache<any>(`channel_meta_${cid}`);
          if (cached) {
            channelsMap[cid] = cached;
          } else {
            uncachedChannelIds.push(cid);
          }
        }

        if (uncachedChannelIds.length > 0) {
          const chunks = [];
          for (let i = 0; i < uncachedChannelIds.length; i += 10) {
            chunks.push(uncachedChannelIds.slice(i, i + 10));
          }

          try {
            const channelSnaps = await Promise.all(
              chunks.map(chunk =>
                db().collection("channels")
                  .where(admin.firestore.FieldPath.documentId(), "in", chunk)
                  .get()
              )
            );

            channelSnaps.forEach(snap => {
              snap.docs.forEach(d => {
                const data = d.data();
                channelsMap[d.id] = data;
                setCache(`channel_meta_${d.id}`, data, 300); // 5-minute memory cache
              });
            });
          } catch (err) {
            logger.warn("[getHomeFeed] Failed to fetch channels:", err);
          }
        }
      }

      // ══════════════════════════════════════════════════════════════════════
      // 5. Scoring, Dedup, Creator Budget, & Novelty Penalty
      // ══════════════════════════════════════════════════════════════════════
      const scoredCandidates = new Map<string, any>();
      const creatorExposure: Record<string, number> = {};
      const topicExposure: Record<string, number> = {};
      const MAX_CREATOR_SHARE = 0.18; // Creator exposure budget: max 18% of feed

      allCandidateDocs.forEach(doc => {
        if (scoredCandidates.has(doc.id)) return;

        const data = doc.data();
        if (!data) return;

        // Skip private and draft videos from public recommendations feed
        const vis = (data.visibility || "").toString().trim().toLowerCase();
        if (vis === "private" || vis === "private_draft" || vis === "draft") return;

        const stat = (data.status || "").toString().trim().toLowerCase();
        if (stat === "deleted" || stat === "rejected" || stat === "draft" || stat === "uploading") return;

        const title = (data.title || "").toString().trim().toLowerCase();
        if (!title || title.startsWith("uploading") || title.startsWith("untitled")) return;

        const channel = channelsMap[data.channelId] || {};
        const isSubscribed = following.includes(data.channelId || "");
        const isAlreadyWatched = watchedVideoIds.has(doc.id);
        const isNotInterested = notInterestedVideoIds.has(doc.id);

        // ── Topic Affinity Score (NEW) ──────────────────────────────
        let topicAffinityScore = 0;

        // Direct category match from user interests
        const videoCat = data.category || "";
        topicAffinityScore += (userInterests[videoCat] || 0) * 8;

        // Topic slug match from followed topics
        const videoTopics: string[] = data.topics || [];
        const hasFollowedTopic = videoTopics.some((t: string) =>
          followedTopicSlugs.includes(t)
        );
        if (hasFollowedTopic) {
          topicAffinityScore = Math.max(topicAffinityScore, 8);
        }

        // Topic-level interest from user interests map
        for (const topic of videoTopics) {
          const topicKey = `topic:${topic}`;
          if (userInterests[topicKey]) {
            topicAffinityScore = Math.max(topicAffinityScore, userInterests[topicKey] * 10);
          }
        }

        topicAffinityScore = Math.min(10, topicAffinityScore);

        // ── Novelty Penalty ─────────────────────────────────────────
        let noveltyPenalty = 0;
        const videoMainTopic = videoTopics[0] || videoCat;
        const topicCount = topicExposure[videoMainTopic] || 0;
        if (topicCount >= 3) {
          noveltyPenalty = Math.min(5, (topicCount - 2) * 0.8);
        }

        // ── Calculate Engagement Rate ───────────────────────────────
        const views = data.viewCount || 1;
        const likes = data.likeCount || 0;
        const engagementRate = likes / views;

        // ── Two-Tower Neural Semantic Affinity ─────────────────────
        let twoTowerAffinity = 0.5;
        if (userEmbedding && Array.isArray(userEmbedding) && data.embedding) {
          const itemVec = Array.isArray(data.embedding)
            ? data.embedding
            : (data.embedding?.values || []);
          if (itemVec.length === userEmbedding.length && itemVec.length > 0) {
            let dot = 0;
            let normU = 0;
            let normV = 0;
            for (let i = 0; i < itemVec.length; i++) {
              dot += userEmbedding[i] * itemVec[i];
              normU += userEmbedding[i] * userEmbedding[i];
              normV += itemVec[i] * itemVec[i];
            }
            if (normU > 0 && normV > 0) {
              const cos = dot / (Math.sqrt(normU) * Math.sqrt(normV));
              twoTowerAffinity = Math.max(0, Math.min(1, (cos + 1) / 2));
            }
          }
        }

        // ── Calculate Discovery Score ───────────────────────────────
        const now = Date.now();
        const discoveryScore = calculateDiscoveryScore({
          category: data.category,
          isFactChecked: data.isFactChecked ?? data.credibilityVerified ?? false,
          isCredibilityVerified: data.credibilityVerified ?? false,
          trustScore: data.trustScore,
          isFlagged: data.isFlagged ?? false,
          createdAt: data.createdAt?.toMillis ? data.createdAt.toMillis() : (data.createdAt || Date.now()),
          engagementRate,
          isSubscribed,
          momentum: channel.reputation?.trend30d || 0,
          tier: channel.tier || "basic",
          inactiveDays: channel.updatedAt ? (now - channel.updatedAt) / 86400000 : 0,
          topicAffinityScore,
          isAlreadyWatched,
          isNotInterested,
          watchCompletion: data.avgWatchCompletion,
          noveltyPenalty,
          twoTowerAffinity,
        });

        // Skip if gated out (score = 0)
        if (discoveryScore <= 0) return;

        // ── Creator Exposure Budget ─────────────────────────────────
        const creatorId = data.channelId || "unknown";
        creatorExposure[creatorId] = (creatorExposure[creatorId] || 0) + 1;

        // Track topic exposure for novelty
        topicExposure[videoMainTopic] = (topicExposure[videoMainTopic] || 0) + 1;

        // ── Recommendation Reason ───────────────────────────────────
        let recommendationReason = "For You";
        let recommendationExplanation = "Recommended based on your interests";

        if (isFactCheckRelevantCategory(data.category) && (data.isFactChecked || data.credibilityVerified || (data.trustScore && data.trustScore >= 3.5))) {
          recommendationReason = "Fact-Checked";
          recommendationExplanation = `Fact-checked for verified accuracy in ${data.category || videoCat || "this topic"}`;
        } else if (isSubscribed) {
          recommendationReason = "Following";
          recommendationExplanation = `From a creator you follow`;
        } else if (hasFollowedTopic) {
          recommendationReason = "In Your Topics";
          const matchedTopic = videoTopics.find((t: string) => followedTopicSlugs.includes(t));
          recommendationExplanation = `Because you follow ${matchedTopic || videoCat}`;
        } else if (data.credibilityVerified) {
          recommendationReason = "Fact-Checked";
          recommendationExplanation = "Highly trusted source";
        } else if (twoTowerAffinity >= 0.8) {
          recommendationReason = "Deep Interest Match";
          recommendationExplanation = "High neural semantic resonance with your profile";
        } else if ((channel.reputation?.trend30d || 0) > 0.5) {
          recommendationReason = "Rising Fast";
          recommendationExplanation = "Trending in your interests";
        } else if ((data.viewCount || 0) <= 1000 && data.credibilityVerified) {
          recommendationReason = "New Creator";
          recommendationExplanation = "Discover fresh perspectives";
        } else if (topicAffinityScore > 5) {
          recommendationExplanation = `Similar to videos you watched in ${videoCat}`;
        }

        scoredCandidates.set(doc.id, {
          id: doc.id,
          ...data,
          discoveryScore,
          tier: channel.tier || "basic",
          channelAvatarUrl: channel.avatarUrl || "",
          channelName: channel.channelName || data.channelName || "",
          recommendationReason,
          recommendationExplanation,
          topicAffinityScore,
          twoTowerAffinity,
        });
      });

      // ══════════════════════════════════════════════════════════════════════
      // 6. Sort, Apply Creator Budget, & Return
      // ══════════════════════════════════════════════════════════════════════
      let feed = Array.from(scoredCandidates.values())
        .sort((a, b) => b.discoveryScore - a.discoveryScore);

      // Apply creator exposure budget: max 18% of feed per creator
      const maxPerCreator = Math.max(2, Math.ceil(limit * MAX_CREATOR_SHARE));
      const creatorCounts: Record<string, number> = {};
      feed = feed.filter(v => {
        const cid = v.channelId || "unknown";
        creatorCounts[cid] = (creatorCounts[cid] || 0) + 1;
        return creatorCounts[cid] <= maxPerCreator;
      });

      // Apply pagination via startAfter timestamp
      if (startAfterTs) {
        feed = feed.filter(v => {
          const ts = v.createdAt?.toMillis ? v.createdAt.toMillis() : v.createdAt;
          return ts < startAfterTs;
        });
      }

      // YouTube-style backfill: First prefer personalized videos (feed already contains them).
      // If candidate scoring or filters resulted in fewer than limit videos,
      // never leave feed_home low or facing a content crisis!
      // Fetch remaining available public videos from Firestore to fill up to limit.
      if (feed.length < limit) {
        const needed = limit - feed.length;
        logger.info(`[getHomeFeed] Personalized feed has ${feed.length} videos (< ${limit}). Backfilling remaining ${needed} videos from TruthWorld Firestore catalog...`);
        try {
          const existingIds = new Set(feed.map(v => v.id));
          let fallbackDocs: admin.firestore.DocumentSnapshot[] = [];
          try {
            const snap = await db().collection("videos").orderBy("createdAt", "desc").limit(limit * 2).get();
            fallbackDocs = snap.docs;
          } catch (_) {
            try {
              const snap = await db().collection("videos").orderBy("uploadedAt", "desc").limit(limit * 2).get();
              fallbackDocs = snap.docs;
            } catch (_) {
              const snap = await db().collection("videos").limit(limit * 2).get();
              fallbackDocs = snap.docs;
            }
          }

          if (fallbackDocs.length === 0) {
            const snap = await db().collection("videos").limit(limit * 2).get();
            fallbackDocs = snap.docs;
          }

          for (const doc of fallbackDocs) {
            if (feed.length >= limit) break;
            if (existingIds.has(doc.id)) continue;

            const data = doc.data();
            if (!data) continue;
            const vis = (data.visibility || "").toString().trim().toLowerCase();
            if (vis === "private" || vis === "private_draft" || vis === "draft") continue;
            const stat = (data.status || "").toString().trim().toLowerCase();
            if (stat === "deleted" || stat === "rejected") continue;

            const ch = channelsMap[data.channelId] || {};
            feed.push({
              id: doc.id,
              ...data,
              discoveryScore: 0.5,
              tier: ch.tier || "basic",
              channelAvatarUrl: ch.avatarUrl || data.channelAvatarUrl || "",
              channelName: ch.channelName || data.channelName || "",
              recommendationReason: "TruthWorld Catalog",
              recommendationExplanation: "Recommended for you on TruthWorld",
              topicAffinityScore: 0,
              twoTowerAffinity: 0.5,
            });
            existingIds.add(doc.id);
          }
        } catch (fallbackErr) {
          logger.warn("[getHomeFeed] Error backfilling fallback videos:", fallbackErr);
        }
      }

      // Trim to limit and format response
      const response = feed
        .slice(0, limit)
        .map(v => ({
          id: v.id,
          title: v.title,
          creatorName: v.channelName,
          channelId: v.channelId,
          channelAvatarUrl: v.channelAvatarUrl,
          credibilityVerified: v.credibilityVerified ?? false,
          isFactChecked: v.isFactChecked ?? v.credibilityVerified ?? false,
          thumbnailUrl: v.thumbnailUrl || v.media?.thumbnailUrl || "",
          videoUrl: v.videoUrl || v.originalUrl || v.media?.videoUrl || v.media?.originalUrl || "",
          originalUrl: v.originalUrl || v.videoUrl || v.media?.originalUrl || v.media?.videoUrl || "",
          hlsUrl: v.hlsUrl || v.media?.hlsUrl || "",
          dashUrl: v.dashUrl || v.media?.dashUrl || "",
          adaptiveResolutions: v.adaptiveResolutions || v.media?.adaptiveResolutions || [],
          status: v.status || "ready",
          visibility: v.visibility || "public",
          geminiApproved: v.geminiApproved ?? true,
          isApproved: v.isApproved ?? true,
          category: v.category || "",
          topics: v.topics || [],
          viewCount: v.viewCount || 0,
          likeCount: v.likeCount || 0,
          commentCount: v.commentCount || 0,
          duration: v.duration || 0,
          durationMs: v.durationMs || 0,
          isShort: v.isShort ?? false,
          trustScore: v.trustScore,
          recommendationReason: v.recommendationReason,
          recommendationExplanation: v.recommendationExplanation,
          discoveryScore: v.discoveryScore,
          topicAffinityScore: v.topicAffinityScore,
          twoTowerAffinity: v.twoTowerAffinity,
          embedding: v.embedding,
          createdAt: v.createdAt?.toMillis ? v.createdAt.toMillis() : v.createdAt,
          uploadedAt: v.uploadedAt?.toMillis ? v.uploadedAt.toMillis() : v.uploadedAt,
          tier: v.tier,
        }));

      res.status(200).json({
        feed: response,
        videos: response,
        hasMore: feed.length > limit,
        nextStartAfter: response.length > 0 ? response[response.length - 1].createdAt : null,
      });
    } catch (err) {
      logger.error("[getHomeFeed] Error:", err);
      res.status(500).json({
        error: "Failed to generate feed: " + (err instanceof Error ? err.message : String(err)),
      });
    }
  }
);

/**
 * 🌟 GET DISCOVERY MODULES (HTTPS)
 * Specialized carousels for the home page.
 *
 * Modules:
 * - Elite Spotlight (Elite tier creators)
 * - Verified Today (Fact-checked within 24h)
 * - Rising Fast (Channels with positive momentum)
 * - Long-tail Gems (Hidden quality content with < 500 views) — NEW
 */
export const getDiscoveryModules = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      // 1. Elite Spotlight (Elite tier creators)
      const eliteSnap = await db().collection("channels")
        .where("tier", "==", "elite")
        .limit(10)
        .get();

      const activeElite = eliteSnap.docs
        .filter(isPublicActive)
        .map((d, idx) => sanitizePublicChannel(d, idx + 1));

      // 2. Verified Today (Fact Checked videos within 24h)
      const trustedVideosSnap = await db().collection("videos")
        .where("credibilityVerified", "==", true)
        .orderBy("createdAt", "desc")
        .limit(30)
        .get();

      const oneDayAgo = Date.now() - 86400000;
      const trustedTodaySnap = trustedVideosSnap.docs.filter(d => {
        const data = d.data();
        const vis = (data.visibility || "").toString().trim().toLowerCase();
        if (vis === "private" || vis === "private_draft" || vis === "draft") return false;
        const createdAt = data.createdAt?.toMillis?.() || data.createdAt || 0;
        return createdAt >= oneDayAgo;
      }).slice(0, 10);

      // 3. Rising Fast (Channels with positive momentum)
      const channelsSnap = await db().collection("channels")
        .where("tier", "in", ["creator", "advanced", "elite"])
        .limit(50)
        .get();

      const risingSnap = channelsSnap.docs
        .filter(isPublicActive)
        .filter(d => {
          const trend = d.data().reputation?.trend30d || 0;
          return trend > 0;
        })
        .sort((a, b) => {
          const trendA = a.data().reputation?.trend30d || 0;
          const trendB = b.data().reputation?.trend30d || 0;
          return trendB - trendA;
        })
        .slice(0, 10)
        .map((d, idx) => sanitizePublicChannel(d, idx + 1));

      // 4. Long-tail Gems (High engagement, low view videos) — NEW
      const longTailSnap = await db().collection("videos")
        .where("credibilityVerified", "==", true)
        .where("viewCount", "<=", 500)
        .orderBy("viewCount", "asc")
        .limit(20)
        .get();

      const longTailGems = longTailSnap.docs
        .filter(d => {
          const data = d.data();
          const vis = (data.visibility || "").toString().trim().toLowerCase();
          if (vis === "private" || vis === "private_draft" || vis === "draft") return false;
          const likes = data.likeCount || 0;
          const views = data.viewCount || 1;
          // Only include if engagement rate is above average
          return (likes / views) > 0.1;
        })
        .slice(0, 10);

      res.status(200).json({
        modules: {
          "Elite Spotlight": activeElite,
          "Verified Today": trustedTodaySnap.map(d => ({ id: d.id, ...d.data() })),
          "Rising Fast": risingSnap,
          "Long-tail Gems": longTailGems.map(d => ({ id: d.id, ...d.data() })),
        }
      });
    } catch (err) {
      logger.error("[getDiscoveryModules] Error:", err);
      res.status(500).json({
        error: "Unable to retrieve discovery modules. Please try again later.",
      });
    }
  }
);
