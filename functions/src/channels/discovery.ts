import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import {
  ChannelV2,
  ChannelCategory,
  VALID_CATEGORIES
} from "./types";
import { applySecurityHeaders } from "../utils/securityHeaders";

const db = () => admin.firestore();

/**
 * Ã°Å¸Ââ€  GET LEADERBOARD (HTTPS)
 * Returns the most-subscribed public creators, by category or global.
 */
export const getLeaderboard = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const category = req.query.category as ChannelCategory;
      const limit = Math.max(1, Math.min(Math.floor(Number(req.query.limit) || 20), 100));

      let query: admin.firestore.Query = db().collection("channels");

      if (category && VALID_CATEGORIES.includes(category)) {
        query = query.where("profile.category", "==", category);
      }

      const snap = await query
        .orderBy("stats.subscriberCount", "desc")
        .limit(limit * 2) // Fetch extra to make up for hidden channels filtered below
        .get();

      const channels = snap.docs
        .map((doc: admin.firestore.QueryDocumentSnapshot) => doc.data() as ChannelV2)
        .filter((c: any) => {
          const isSuspended = c.status === "suspended" || c.status === "banned" || c.status === "deleted" || c.status === "onHold" || c.status === "hold";
          const vis = (c.visibility || "").toLowerCase();
          const isPrivateOrUnlisted = vis === "private" || vis === "unlisted" || c.isPublic === false;
          return !isSuspended && !isPrivateOrUnlisted;
        });

      const ranked = channels
        .slice(0, limit)
        .map(c => ({
          id: c.id,
          name: c.displayName,
          slug: c.handle,
          avatarUrl: c.profile.photoUrl,
          category: c.profile.category,
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
