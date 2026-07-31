import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../pipeline/utils/logger";

const db = () => admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════════
// TRUTHWORLD ALGORITHM — Server-Side Scoring Engine
// ═══════════════════════════════════════════════════════════════════════════════

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
 *
 * Normalized to 0-10 scale + Tier Baseline.
 */
function calculateDiscoveryScore(params: {
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
}): number {
  // ── Credibility Gate ─────────────────────────────────────────────────────
  // If video has low trust score AND is flagged → GATE IT OUT completely
  if (params.isFlagged && (params.trustScore ?? 10) < 2.0) {
    return 0;
  }

  // ── Not Interested Gate ────────────────────────────────────────────────
  if (params.isNotInterested) {
    return 0;
  }

  const now = Date.now();
  const ageHours = (now - params.createdAt) / 3600000;

  // ── Component Normalization (0-10) ────────────────────────────────────
  const credibilityBonus = params.isCredibilityVerified ? 10 : 0;
  const engagementScore = Math.min(10, params.engagementRate * 100);
  const recencyScore = 10 * Math.exp(-ageHours / 72); // 72h half-life
  const followScore = params.isSubscribed ? 10 : 0;
  const momentumScore = Math.min(10, params.momentum * 10);
  const topicScore = Math.min(10, params.topicAffinityScore);
  const completionScore = Math.min(10, (params.watchCompletion ?? 0.5) * 10);

  // ── Additive Weighting (Enhanced with Topic Affinity) ──────────────────
  let baseScore =
    (engagementScore * 0.20) +
    (recencyScore * 0.15) +
    (followScore * 0.12) +
    (topicScore * 0.20) +        // Topic Affinity: highest weight
    (momentumScore * 0.10) +
    (credibilityBonus * 0.08) +
    (completionScore * 0.05);

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

  // ── Penalties ─────────────────────────────────────────────────────────
  let penalty = 0;

  // Already watched → significant derank
  if (params.isAlreadyWatched) {
    penalty += 3.0;
  }

  // Novelty penalty → exponential for same sub-topic spam
  penalty += params.noveltyPenalty;

  return Math.max(0, baseScore + tierBoost - penalty);
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
    const userId = req.query.userId as string;
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

      if (userId) {
        try {
          const [userSnap, savedTopicsSnap, watchHistorySnap] = await Promise.all([
            db().collection("users").doc(userId).get(),
            db().collection("users").doc(userId).collection("savedTopics").limit(20).get(),
            db().collection("users").doc(userId).collection("watch_history")
              .orderBy("watchedAt", "desc")
              .limit(100)
              .get()
          ]);

          if (userSnap.exists) {
            const userData = userSnap.data() as any;
            following = userData?.following || [];
            userInterests = userData?.interests || {};
            notInterestedVideoIds = new Set(userData?.notInterestedVideoIds || []);
          }

          followedTopicSlugs = savedTopicsSnap.docs.map(d => d.id);

          watchedVideoIds = new Set(watchHistorySnap.docs.map(d => d.id));
        } catch (err) {
          logger.warn("[getHomeFeed] Failed to fetch user data:", err);
        }
      }

      // ══════════════════════════════════════════════════════════════════════
      // 2. Multi-Pool Candidate Selection (7 Pools)
      // ══════════════════════════════════════════════════════════════════════

      const poolPromises: Promise<admin.firestore.QuerySnapshot>[] = [];

      // Pool A: Trust Pool (Verified videos)
      poolPromises.push(
        db().collection("videos")
          .where("credibilityVerified", "==", true)
          .orderBy("createdAt", "desc")
          .limit(40)
          .get()
      );

      // Pool B: Recency Pool (Latest videos)
      poolPromises.push(
        db().collection("videos")
          .orderBy("createdAt", "desc")
          .limit(40)
          .get()
      );

      // Pool C: Newcomer Pool (Verified, Low Views)
      poolPromises.push(
        db().collection("videos")
          .where("credibilityVerified", "==", true)
          .where("viewCount", "<=", 1000)
          .orderBy("viewCount", "asc")
          .limit(10)
          .get()
      );

      // Pool D: Following Pool (If user logged in)
      if (userId && following.length > 0) {
        poolPromises.push(
          db().collection("videos")
            .where("channelId", "in", following.slice(0, 10))
            .orderBy("createdAt", "desc")
            .limit(20)
            .get()
        );
      }

      // Pool E: Topic Pool (Videos matching user's followed topics) — NEW
      if (followedTopicSlugs.length > 0) {
        poolPromises.push(
          db().collection("videos")
            .where("topics", "array-contains-any", followedTopicSlugs.slice(0, 10))
            .orderBy("createdAt", "desc")
            .limit(20)
            .get()
        );
      }

      // Pool F: Long-tail Creators (< 500 views, quality content) — NEW
      poolPromises.push(
        db().collection("videos")
          .where("viewCount", "<=", 500)
          .orderBy("viewCount", "asc")
          .limit(10)
          .get()
      );

      // Pool G: Exploding Creators (via channel trend) — handled in scoring phase

      const poolResults = await Promise.all(poolPromises);

      // ══════════════════════════════════════════════════════════════════════
      // 3. Apply Category Filter In-Memory (if needed)
      // ══════════════════════════════════════════════════════════════════════
      const filterByCategory = (docs: admin.firestore.DocumentSnapshot[]): admin.firestore.DocumentSnapshot[] => {
        if (!category) return docs;
        return docs.filter(d => d.data()?.category === category);
      };

      const allCandidateDocs = poolResults.flatMap(snap => filterByCategory(snap.docs));

      // ══════════════════════════════════════════════════════════════════════
      // 4. Batch Fetch Channel Metadata (Tier, Trend, Inactivity)
      // ══════════════════════════════════════════════════════════════════════
      const channelIds = [...new Set(allCandidateDocs.map(d => d.data()?.channelId).filter((id): id is string => !!id))];
      const channelsMap: Record<string, any> = {};

      if (channelIds.length > 0) {
        const chunks = [];
        for (let i = 0; i < channelIds.length; i += 10) {
          chunks.push(channelIds.slice(i, i + 10));
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
            snap.docs.forEach(d => { channelsMap[d.id] = d.data(); });
          });
        } catch (err) {
          logger.warn("[getHomeFeed] Failed to fetch channels:", err);
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

        // ── Calculate Discovery Score ───────────────────────────────
        const now = Date.now();
        const discoveryScore = calculateDiscoveryScore({
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

        if (isSubscribed) {
          recommendationReason = "Following";
          recommendationExplanation = `From a creator you follow`;
        } else if (hasFollowedTopic) {
          recommendationReason = "In Your Topics";
          const matchedTopic = videoTopics.find((t: string) => followedTopicSlugs.includes(t));
          recommendationExplanation = `Because you follow ${matchedTopic || videoCat}`;
        } else if (data.credibilityVerified) {
          recommendationReason = "Fact-Checked";
          recommendationExplanation = "Highly trusted source";
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
          thumbnailUrl: v.thumbnailUrl,
          category: v.category,
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
          createdAt: v.createdAt?.toMillis ? v.createdAt.toMillis() : v.createdAt,
          uploadedAt: v.uploadedAt?.toMillis ? v.uploadedAt.toMillis() : v.uploadedAt,
          tier: v.tier,
        }));

      res.status(200).json({
        feed: response,
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
    try {
      // 1. Elite Spotlight (Elite tier creators)
      const eliteSnap = await db().collection("channels")
        .where("tier", "==", "elite")
        .limit(10)
        .get();

      // 2. Verified Today (Fact Checked videos within 24h)
      const trustedVideosSnap = await db().collection("videos")
        .where("credibilityVerified", "==", true)
        .orderBy("createdAt", "desc")
        .limit(30)
        .get();

      const oneDayAgo = Date.now() - 86400000;
      const trustedTodaySnap = trustedVideosSnap.docs.filter(d => {
        const createdAt = d.data().createdAt?.toMillis?.() || d.data().createdAt || 0;
        return createdAt >= oneDayAgo;
      }).slice(0, 10);

      // 3. Rising Fast (Channels with positive momentum)
      const channelsSnap = await db().collection("channels")
        .where("tier", "in", ["creator", "advanced", "elite"])
        .limit(50)
        .get();

      const risingSnap = channelsSnap.docs
        .filter(d => {
          const trend = d.data().reputation?.trend30d || 0;
          return trend > 0;
        })
        .sort((a, b) => {
          const trendA = a.data().reputation?.trend30d || 0;
          const trendB = b.data().reputation?.trend30d || 0;
          return trendB - trendA;
        })
        .slice(0, 10);

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
          const likes = data.likeCount || 0;
          const views = data.viewCount || 1;
          // Only include if engagement rate is above average
          return (likes / views) > 0.1;
        })
        .slice(0, 10);

      res.status(200).json({
        modules: {
          "Elite Spotlight": eliteSnap.docs.map(d => ({ id: d.id, ...d.data() })),
          "Verified Today": trustedTodaySnap.map(d => ({ id: d.id, ...d.data() })),
          "Rising Fast": risingSnap.map(d => ({ id: d.id, ...d.data() })),
          "Long-tail Gems": longTailGems.map(d => ({ id: d.id, ...d.data() })),
        }
      });
    } catch (err) {
      logger.error("[getDiscoveryModules] Error:", err);
      res.status(500).json({
        error: "Internal error: " + (err instanceof Error ? err.message : String(err)),
      });
    }
  }
);
