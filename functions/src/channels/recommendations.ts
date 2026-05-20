import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../pipeline/utils/logger";

const db = () => admin.firestore();

/**
 * âš–ï¸ CALCULATE FEED SCORE (Multiplicative)
 * Balances Trust, Freshness, Relevance, and Social Proof.
 */
/**
 * âš–ï¸ CALCULATE DISCOVERY SCORE (Additive + Tier Boost)
 * Normalized to 0-10 scale + Tier Baseline.
 */
function calculateDiscoveryScore(params: {
  videoRating: number;      // 0.0 - 10.0
  createdAt: number;       // epoch ms
  engagementRate: number;  // 0.0 - 1.0 (likes/views)
  isSubscribed: boolean;
  momentum: number;        // 0.0 - 1.0 (trend)
  tier: "basic" | "creator" | "advanced" | "elite";
  inactiveDays: number;    // Days since last upload
  trustDelta: number;      // trust delta in last 7 days (negative = drop)
}): number {
  const now = Date.now();
  const ageHours = (now - params.createdAt) / 3600000;
  
  // 1. Component Normalization (0-10)
  const trustScore = params.videoRating;
  const engagementScore = Math.min(10, params.engagementRate * 100); 
  const recencyScore = 10 * Math.exp(-ageHours / 72); 
  const followScore = params.isSubscribed ? 10 : 0;
  const momentumScore = params.momentum * 10;

  // 2. Additive Weighting
  let baseScore = (trustScore * 0.45) + 
                  (engagementScore * 0.20) + 
                  (recencyScore * 0.15) + 
                  (followScore * 0.10) + 
                  (momentumScore * 0.10);

  // 3. Tier Baseline Boosts (The Moat)
  let tierBoost = {
    elite: 2.0,
    advanced: 1.0,
    creator: 0.5,
    basic: 0.0
  }[params.tier] || 0;

  // Hardening A: Soft Decay for Inactive Channels (60+ days)
  if (params.inactiveDays >= 60 && tierBoost > 0) {
    tierBoost *= 0.5; // Halve the prestige boost if dead
  }

  // Hardening B: Negative Penalty for Sharp Trust Drops (Trust Suppression)
  if (params.trustDelta < -1.0) {
    baseScore *= 0.7; // 30% reach suppression for credibility crisis
  }

  return baseScore + tierBoost;
}

/**
 * ðŸ  GET HOME FEED (HTTPS)
 * Returns a personalized, trust-first content mix with meritocratic discovery.
 */
export const getHomeFeed = onRequest(
  { region: "asia-south1", cors: true, memory: "512MiB" },
  async (req, res) => {
    const userId = req.query.userId as string;
    const limit = Math.min(Number(req.query.limit) || 24, 60);
    const category = req.query.category as string;
    // const now = Date.now();

    try {
      // 1. Fetch user context (Subscriptions & Interests)
      let subscriptions: string[] = [];

      if (userId) {
        try {
          const userSnap = await db().collection("users").doc(userId).get();
          if (userSnap.exists) {
            subscriptions = userSnap.data()?.subscriptions || [];
          }
        } catch (err) {
          logger.warn("[getHomeFeed] Failed to fetch user data:", err);
        }
      }

      // 2. Multi-Pool Candidate Selection (Simplified to avoid composite indexes)
      // Pool A: High Trust videos - no category filter to avoid composite index
      const trustPool = await db().collection("videos")
        .where("trustScore", ">=", 7.0)
        .orderBy("trustScore", "desc")
        .limit(40)
        .get();

      // Pool B: Latest videos - no category filter
      const recencyPool = await db().collection("videos")
        .orderBy("createdAt", "desc")
        .limit(40)
        .get();

      // Pool C: Newcomers (High Trust, Low Views, Recent)
      const newcomerPool = await db().collection("videos")
        .where("trustScore", ">=", 8.0)
        .where("viewCount", "<=", 1000)
        .orderBy("viewCount", "asc")
        .limit(10)
        .get();

      // Pool D: Subscriptions (If user logged in)
      // Highest priority retention pool
      let followingPool: admin.firestore.QuerySnapshot | null = null;
      if (userId && subscriptions.length > 0) {
        followingPool = await db().collection("videos")
          .where("channelId", "in", subscriptions.slice(0, 10))
          .orderBy("createdAt", "desc")
          .limit(20)
          .get();
      }

      // Apply category filter in-memory if needed
      const filterByCategory = (docs: admin.firestore.DocumentSnapshot[]): admin.firestore.DocumentSnapshot[] => {
        if (!category) return docs;
        return docs.filter(d => d.data()?.category === category);
      };

      const trustPoolFiltered = filterByCategory(trustPool.docs);
      const recencyPoolFiltered = filterByCategory(recencyPool.docs);
      const newcomerPoolFiltered = filterByCategory(newcomerPool.docs);
      const followingPoolFiltered = filterByCategory(followingPool?.docs || []);

      // 3. Batch Fetch Channel Tiers (Performance Optimization)
      const allCandidateDocs = [
        ...trustPoolFiltered, 
        ...recencyPoolFiltered, 
        ...newcomerPoolFiltered,
        ...followingPoolFiltered
      ];
      
      const channelIds = [...new Set(allCandidateDocs.map(d => d.data()?.channelId).filter((id): id is string => !!id))];
      const channelsMap: Record<string, any> = {};
      
      if (channelIds.length > 0) {
        // Chunk channel queries (Firestore limit 30 in 'in' query)
        const chunks = [];
        for (let i = 0; i < channelIds.length; i += 10) {
          chunks.push(channelIds.slice(i, i + 10));
        }
        
        try {
          const channelSnaps = await Promise.all(
            chunks.map(chunk => db().collection("channels").where(admin.firestore.FieldPath.documentId(), "in", chunk).get())
          );
          
          channelSnaps.forEach(snap => {
            snap.docs.forEach(d => { channelsMap[d.id] = d.data(); });
          });
        } catch (err) {
          logger.warn("[getHomeFeed] Failed to fetch channels:", err);
        }
      }

      // 4. Scoring & Deduplication
      const scoredCandidates = new Map<string, any>();
      
      allCandidateDocs.forEach(doc => {
        if (scoredCandidates.has(doc.id)) return;
        
        const data = doc.data();
        if (!data) return; // Skip if document has no data
        
        const channel = channelsMap[data.channelId] || {};
        const isSubscribed = subscriptions.includes(data.channelId || "");
        
        // Calculate engagement (Likes/Views)
        const views = data.viewCount || 1;
        const likes = data.likeCount || 0;
        const engagementRate = likes / views;

        const now = Date.now();
        const discoveryScore = calculateDiscoveryScore({
          videoRating: data.videoRating ?? data.trustScore ?? 5.0,
          createdAt: data.createdAt?.toMillis ? data.createdAt.toMillis() : (data.createdAt || Date.now()),
          engagementRate,
          isSubscribed,
          momentum: channel.reputation?.trend30d || 0,
          tier: channel.tier || "basic",
          inactiveDays: channel.updatedAt ? (now - channel.updatedAt) / 86400000 : 0,
          trustDelta: channel.reputation?.trend30d || 0
        });

        scoredCandidates.set(doc.id, {
          id: doc.id,
          ...data,
          discoveryScore,
          tier: channel.tier || "basic",
          recommendationReason: isSubscribed ? "Subscribed" : 
                               (data.viewCount <= 1000 && data.trustScore >= 8.0 ? "Rising Star" :
                               (data.trustScore >= 9.0 ? "Elite Credibility" : 
                               (data.momentum > 0.5 ? "Rising Fast" : "For You")))
        });
      });

      // 5. Final Sort & Return
      const feed = Array.from(scoredCandidates.values())
        .sort((a, b) => b.discoveryScore - a.discoveryScore)
        .slice(0, limit)
        .map(v => ({
          id: v.id,
          title: v.title,
          creatorName: v.channelName,
          channelId: v.channelId,
          videoRating: v.videoRating ?? v.trustScore,
          thumbnailUrl: v.thumbnailUrl,
          category: v.category,
          recommendationReason: v.recommendationReason,
          createdAt: v.createdAt?.toMillis ? v.createdAt.toMillis() : v.createdAt,
          tier: v.tier
        }));

      res.status(200).json({ feed });
    } catch (err) {
      logger.error("[getHomeFeed] Error:", err);
      res.status(500).json({ error: "Failed to generate feed: " + (err instanceof Error ? err.message : String(err)) });
    }
  }
);

/**
 * ðŸŒŸ GET DISCOVERY MODULES (HTTPS)
 * Specialized carousels for the home page.
 */
export const getDiscoveryModules = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    try {
      // 1. Elite Spotlight (Elite tier creators) - No composite index needed
      const eliteSnap = await db().collection("channels")
        .where("tier", "==", "elite")
        .limit(10)
        .get();

      // 2. Trusted Today (High Trust Index videos) - Simplified to avoid composite index
      // Fetch high trust videos, then filter by date in-memory
      const trustedVideosSnap = await db().collection("videos")
        .where("trustScore", ">=", 8.0)
        .orderBy("trustScore", "desc")
        .limit(30)
        .get();

      const oneDayAgo = Date.now() - 86400000;
      const trustedTodaySnap = trustedVideosSnap.docs.filter(d => {
        const createdAt = d.data().createdAt?.toMillis?.() || d.data().createdAt || 0;
        return createdAt >= oneDayAgo;
      }).slice(0, 10);

      // 3. Rising Fast (Channels with positive momentum) - Simplified query
      // Fetch channels with high trust, sort in-memory by trend
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

      res.status(200).json({
        modules: {
          "Elite Spotlight": eliteSnap.docs.map(d => ({ id: d.id, ...d.data() })),
          "Trusted Today": trustedTodaySnap.map(d => ({ id: d.id, ...d.data() })),
          "Rising Fast": risingSnap.map(d => ({ id: d.id, ...d.data() }))
        }
      });
    } catch (err) {
      logger.error("[getDiscoveryModules] Error:", err);
      res.status(500).json({ error: "Internal error: " + (err instanceof Error ? err.message : String(err)) });
    }
  }
);
