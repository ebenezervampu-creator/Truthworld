import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

export function sanitizePublicChannel(d: admin.firestore.QueryDocumentSnapshot, rank: number) {
  const data = d.data();
  return {
    id: d.id,
    rank,
    displayName: data.displayName || data.name || "",
    handle: data.handle || data.slug || "",
    photoUrl: data.profile?.photoUrl || data.photoUrl || data.avatarUrl || "",
    tier: data.tier || "standard",
    category: data.profile?.category || data.category || "General",
    avgTrustIndex: data.stats?.avgTrustIndex || data.reputation?.avgTrustIndex || 0,
    subscriberCount: data.stats?.subscriberCount || data.subscriberCount || 0,
    trend30d: data.reputation?.trend30d || 0,
    videosCount: data.stats?.videosCount || data.videoCount || 0,
    isVerified: data.isVerified === true || data.verification === "verified" || data.verification === "elite",
  };
}

export function isPublicActive(d: admin.firestore.QueryDocumentSnapshot): boolean {
  const status = d.data()?.status;
  return status !== "suspended" && status !== "banned" && status !== "deleted";
}

import { applySecurityHeaders } from "../utils/securityHeaders";

/**
 * 🏆 GET LEADERBOARDS (HTTPS)
 * Specialized rankings for prestige and aspiration.
 */
export const getLeaderboards = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    applySecurityHeaders(res);

    if (req.method !== "GET") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    const category = req.query.category as string; // Optional category filter

    try {
      // 1. GLOBAL TOP 100 (By Trust Index)
      let globalQuery = db().collection("channels")
        .where("tier", "in", ["advanced", "elite"])
        .orderBy("stats.avgTrustIndex", "desc")
        .limit(50);

      if (category) {
        globalQuery = globalQuery.where("category", "==", category);
      }

      const globalSnap = await globalQuery.get();

      // 2. RISING STARS (Highest trend30d)
      let risingQuery = db().collection("channels")
        .where("reputation.trend30d", ">", 0.0)
        .orderBy("reputation.trend30d", "desc")
        .limit(20);

      if (category) {
        risingQuery = risingQuery.where("category", "==", category);
      }

      const risingSnap = await risingQuery.get();

      // 3. MOST CONSISTENT (High TI, high video count)
      const consistentSnap = await db().collection("channels")
        .where("stats.videosCount", ">=", 20)
        .where("stats.avgTrustIndex", ">=", 8.0)
        .orderBy("stats.avgTrustIndex", "desc")
        .limit(20)
        .get();

      const global = globalSnap.docs
        .filter(isPublicActive)
        .map((d, index) => sanitizePublicChannel(d, index + 1));

      const rising = risingSnap.docs
        .filter(isPublicActive)
        .map((d, index) => sanitizePublicChannel(d, index + 1));

      const consistent = consistentSnap.docs
        .filter(isPublicActive)
        .map((d, index) => sanitizePublicChannel(d, index + 1));

      res.status(200).json({
        global,
        rising,
        consistent,
      });
    } catch (err) {
      logger.error("[getLeaderboards] Error:", err);
      res.status(500).json({ error: "Failed to fetch leaderboards" });
    }
  }
);
