import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

/**
 * 🏆 GET LEADERBOARDS (HTTPS)
 * Specialized rankings for prestige and aspiration.
 */
export const getLeaderboards = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    const category = req.query.category as string; // Optional category filter
    // const timeframe = (req.query.timeframe as string) || "allTime"; // allTime, monthly

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

      res.status(200).json({
        global: globalSnap.docs.map((d, index) => ({ id: d.id, rank: index + 1, ...d.data() })),
        rising: risingSnap.docs.map((d, index) => ({ id: d.id, rank: index + 1, ...d.data() })),
        consistent: consistentSnap.docs.map((d, index) => ({ id: d.id, rank: index + 1, ...d.data() }))
      });
    } catch (err) {
      logger.error("[getLeaderboards] Error:", err);
      res.status(500).json({ error: "Failed to fetch leaderboards" });
    }
  }
);
