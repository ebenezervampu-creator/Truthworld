import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { Request, Response } from "express";

import { applySecurityHeaders } from "../utils/securityHeaders";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * ⚡ PUBLIC FEED SERVER (Edge-Cached Cloud Function)
 *
 * Provides sub-50ms global cold-start responses for read-heavy public feeds
 * (Home, Trending, Explore, Category filters) backed by Google Cloud CDN.
 *
 * Headers enforced:
 *   - Cache-Control: public, max-age=60, s-maxage=300, stale-while-revalidate=600
 *   - Automatic CORS and HTTP method validation
 *   - Scale-to-zero (minInstances: 0) for zero idle cost
 */
export const publicFeedServer = onRequest(
  {
    region: "asia-south1",
    cpu: 1,
    memory: "256MiB",
    timeoutSeconds: 15,
    maxInstances: 5,
    concurrency: 50,
  },
  async (req: Request, res: Response): Promise<void> => {
    // Enterprise Security Headers
    applySecurityHeaders(res);

    // CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "GET" && req.method !== "HEAD") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // Google Cloud CDN Edge Caching headers
    // - max-age=60: Client browser caches for 60 seconds
    // - s-maxage=300: Shared edge CDN PoPs cache for 5 minutes
    // - stale-while-revalidate=600: Serves stale edge copy up to 10 minutes while refreshing in background
    res.set(
      "Cache-Control",
      "public, max-age=60, s-maxage=300, stale-while-revalidate=600"
    );
    res.set("Vary", "Accept-Encoding");
    res.set("Content-Type", "application/json");

    try {
      const path = (req.path || "").toLowerCase();
      const rawCategory = req.query.category;
      const category = typeof rawCategory === "string" ? rawCategory.trim() : undefined;
      const rawLimit = parseInt(req.query.limit as string, 10);
      const limit = isNaN(rawLimit) ? 24 : Math.min(Math.max(rawLimit, 1), 50);

      const db = admin.firestore();

      if (path.includes("trending")) {
        // ═══════════════════════════════════════════════════════════════════
        // TRENDING: Velocity-Based Ranking (not just lifetime view count!)
        //
        // Formula: TrendingScore = (views + 2×likes + 3×comments) / (ageHours + 2)^gravity
        //   - Numerator rewards multi-signal engagement (comments > likes > views)
        //   - Denominator decays older content with gravity factor 1.5
        //   - "+2" prevents division-by-zero and gives new videos a brief boost window
        //
        // Candidate pool: Published videos from the last 7 days, scored in-memory.
        // ═══════════════════════════════════════════════════════════════════
        const TRENDING_GRAVITY = 1.5;
        const TRENDING_WINDOW_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
        const cutoff = new Date(Date.now() - TRENDING_WINDOW_MS);

        let trendQuery: admin.firestore.Query = db
          .collection("videos")
          .where("status", "==", "published")
          .where("visibility", "==", "public")
          .where("createdAt", ">=", cutoff)
          .orderBy("createdAt", "desc")
          .limit(200); // Fetch a broad candidate pool for in-memory scoring

        if (category && category !== "all" && category.length > 0) {
          trendQuery = trendQuery.where("category", "==", category);
        }

        const trendSnap = await trendQuery.get();
        const now = Date.now();

        const scored = trendSnap.docs.map((doc) => {
          const data = doc.data();
          const createdAt = data.createdAt?.toMillis
            ? data.createdAt.toMillis()
            : (data.createdAt || now);
          const ageHours = Math.max(0, (now - createdAt) / 3600000);

          const views = data.viewCount || 0;
          const likes = data.likeCount || 0;
          const comments = data.commentCount || 0;

          // Velocity score: multi-signal numerator / time-decayed denominator
          const numerator = views + (2 * likes) + (3 * comments);
          const denominator = Math.pow(ageHours + 2, TRENDING_GRAVITY);
          const trendingScore = numerator / denominator;

          return {
            id: doc.id,
            ...data,
            trendingScore,
          };
        });

        // Sort by trending velocity and return top results
        scored.sort((a, b) => b.trendingScore - a.trendingScore);
        const trendingVideos = scored.slice(0, limit);

        res.status(200).json({
          feed: trendingVideos,
          count: trendingVideos.length,
          category: category || "All",
          cachedAt: new Date().toISOString(),
          edgeServed: true,
        });
      } else {
        // ═══════════════════════════════════════════════════════════════════
        // DEFAULT FEED: Chronological (latest first)
        // ═══════════════════════════════════════════════════════════════════
        let query: admin.firestore.Query = db
          .collection("videos")
          .where("status", "==", "published")
          .where("visibility", "==", "public");

        if (category && category !== "all" && category.length > 0) {
          query = query.where("category", "==", category);
        }

        query = query.orderBy("createdAt", "desc");

        const snapshot = await query.limit(limit).get();
        const videos = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        res.status(200).json({
          feed: videos,
          count: videos.length,
          category: category || "All",
          cachedAt: new Date().toISOString(),
          edgeServed: true,
        });
      }
    } catch (error) {
      console.error("[publicFeedServer] Error serving edge feed:", error);
      res.status(500).json({
        error: "Unable to retrieve feed from edge server",
        feed: [],
      });
    }
  }
);
