import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { 
  ChannelV2, 
  RANK_WEIGHTS, 
  ChannelCategory, 
  VALID_CATEGORIES 
} from "./types";
import { applySecurityHeaders } from "../utils/securityHeaders";

const db = () => admin.firestore();

/**
 * Ã¢Å¡â€“Ã¯Â¸Â CALCULATE RANK SCORE
 * Internal helper to weight trust, scale, and momentum.
 */
function calculateRankScore(channel: ChannelV2): number {
  const { TRUST_INDEX, SUBSCRIBERS, TREND_30D, COVERAGE } = RANK_WEIGHTS;
  
  const ti = channel.reputation.channelRating ?? channel.reputation.avgTrustIndex;
  const fol = Math.log10(Math.max(1, channel.stats.subscriberCount));
  const trend = channel.reputation.trend30d;
  const coverage = channel.reputation.totalVideos > 0 
    ? (channel.reputation.factCheckedVideos / channel.reputation.totalVideos) * 10
    : 0;
  
  return (ti * TRUST_INDEX) + (fol * SUBSCRIBERS) + (trend * TREND_30D) + (coverage * COVERAGE);
}

/**
 * Ã°Å¸Ââ€  GET LEADERBOARD (HTTPS)
 * Returns top creators by category or global.
 */
export const getLeaderboard = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const category = req.query.category as ChannelCategory;
      const limit = Math.min(Number(req.query.limit) || 20, 100);

      let query: admin.firestore.Query = db().collection("channels");

      if (category && VALID_CATEGORIES.includes(category)) {
        query = query.where("profile.category", "==", category);
      }

      // We sort by avgTrustIndex in Firestore first to get the most relevant
      const snap = await query
        .orderBy("reputation.avgTrustIndex", "desc")
        .limit(limit * 2) // Fetch more to allow re-ranking by weighted score
        .get();

      const channels = snap.docs
        .map((doc: admin.firestore.QueryDocumentSnapshot) => {
          const data = doc.data() as ChannelV2;
          return {
            ...data,
            discoveryScore: calculateRankScore(data)
          };
        })
        .filter((c: any) => c.status !== "suspended" && c.status !== "banned" && c.status !== "deleted");

      // Re-rank by weighted discovery score
      const ranked = channels
        .sort((a, b) => b.discoveryScore - a.discoveryScore)
        .slice(0, limit)
        .map(c => ({
          id: c.id,
          name: c.displayName,
          slug: c.handle,
          avatarUrl: c.profile.photoUrl,
          category: c.profile.category,
          channelRating: c.reputation.channelRating ?? c.reputation.avgTrustIndex,
          trend: c.reputation.trend30d,
          subscribers: c.stats.subscriberCount,
          verification: c.verification
        }));

      res.status(200).json({ category: category || "global", count: ranked.length, creators: ranked });
    } catch (err) {
      logger.error("[getLeaderboard] Error:", err);
      res.status(500).json({ error: "Failed to fetch leaderboard" });
    }
  }
);

/**
 * 📈 GET RISING CREATORS (HTTPS)
 * Focuses on creators with high trend30d.
 */
export const getRisingCreators = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const limit = Math.min(Number(req.query.limit) || 10, 50);

      const snap = await db().collection("channels")
        .where("reputation.trend30d", ">", 0)
        .orderBy("reputation.trend30d", "desc")
        .limit(limit * 2)
        .get();

      const creators = snap.docs
        .map((doc: admin.firestore.QueryDocumentSnapshot) => {
          const data = doc.data() as ChannelV2;
          return {
            id: data.id,
            status: (data as any).status,
            name: data.displayName,
            slug: data.handle,
            avatarUrl: data.profile.photoUrl,
            channelRating: data.reputation.channelRating ?? data.reputation.avgTrustIndex,
            trend: data.reputation.trend30d,
            subscribers: data.stats.subscriberCount
          };
        })
        .filter(c => c.status !== "suspended" && c.status !== "banned" && c.status !== "deleted")
        .slice(0, limit)
        .map(c => ({
          id: c.id,
          name: c.name,
          slug: c.slug,
          avatarUrl: c.avatarUrl,
          channelRating: c.channelRating,
          trend: c.trend,
          subscribers: c.subscribers
        }));

      res.status(200).json({ creators });
    } catch (err) {
      logger.error("[getRisingCreators] Error:", err);
      res.status(500).json({ error: "Failed to fetch rising creators" });
    }
  }
);
