import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

const STOP_WORDS = new Set([
  "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
  "has", "he", "in", "is", "it", "its", "of", "on", "that", "the",
  "to", "was", "were", "will", "with", "video", "how", "what", "where"
]);

function tokenize(text: string): Set<string> {
  if (!text) return new Set();
  const cleaned = text.toLowerCase().replace(/[^a-z0-9\s]/g, " ");
  const words = cleaned.split(/\s+/).filter(w => w.length > 2 && !STOP_WORDS.has(w));
  return new Set(words);
}

export interface RecommendedTopicResult {
  id: string;
  slug: string;
  title: string;
  handle: string;
  description: string;
  category: string;
  thumbnailUrl?: string;
  coverImage?: string;
  videoCount: number;
  followerCount: number;
  matchScore: number;
  matchPercentage: number;
  recommendationReason: string;
}

/**
 * 🤖 Smart Topic Recommendation Cloud Function
 * Analyzes video title, description, category, and tags against available topics,
 * returning ranked topic recommendations with match percentages and explanations.
 */
export const recommendTopicsForVideo = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
    concurrency: 80,
    timeoutSeconds: 15,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const { videoTitle = "", videoDescription = "", category = "", tags = [] } = req.body || {};

      const videoTokens = tokenize(`${videoTitle} ${videoDescription} ${category} ${(tags || []).join(" ")}`);
      const titleTokens = tokenize(videoTitle);
      const videoCatClean = (category || "").trim().toLowerCase();

      const snapshot = await db().collection("topics").get();
      if (snapshot.empty) {
        res.status(200).json({ status: "success", recommendedTopic: null, rankedTopics: [] });
        return;
      }

      const scoredTopics: RecommendedTopicResult[] = [];

      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        const id = doc.id;
        const slug = data.slug || id;
        const title = data.title || "";
        const handle = data.handle || "";
        const description = data.description || "";
        const topicCat = (data.category || "").trim().toLowerCase();
        const topicTags: string[] = data.tags || [];

        let score = 10; // Baseline score
        const reasons: string[] = [];

        // 1. Category Matching Weight
        if (videoCatClean && topicCat && (videoCatClean === topicCat || videoCatClean.includes(topicCat) || topicCat.includes(videoCatClean))) {
          score += 45;
          reasons.push(`Direct category match (${data.category})`);
        }

        // 2. Title Tokens Matching
        const topicTitleTokens = tokenize(`${title} ${handle}`);
        let titleMatches = 0;
        titleTokens.forEach((token) => {
          if (topicTitleTokens.has(token)) {
            titleMatches++;
            score += 15;
          }
        });
        if (titleMatches > 0) {
          reasons.push(`Matches ${titleMatches} title keywords`);
        }

        // 3. Tag Overlap
        let tagMatches = 0;
        const topicTagTokens = tokenize(topicTags.join(" "));
        videoTokens.forEach((token) => {
          if (topicTagTokens.has(token)) {
            tagMatches++;
            score += 10;
          }
        });
        if (tagMatches > 0) {
          reasons.push(`${tagMatches} matching tags`);
        }

        // 4. Description Overlap
        const topicDescTokens = tokenize(description);
        let descMatches = 0;
        videoTokens.forEach((token) => {
          if (topicDescTokens.has(token)) {
            descMatches++;
            score += 4;
          }
        });

        // 5. Popularity weight bonus
        const videoCount = data.videoCount || 0;
        const followerCount = data.followerCount || 0;
        const popBonus = Math.min(10, Math.log10(videoCount + followerCount + 1) * 3);
        score += popBonus;

        // Calculate final percentage score bounded between 60% and 99%
        const maxExpectedScore = 120;
        const rawPct = Math.min(99, Math.max(62, Math.round((score / maxExpectedScore) * 100)));

        const recommendationReason = reasons.length > 0
          ? reasons.join(" • ")
          : `Relevant topic in ${data.category || "TruthWorld"}`;

        scoredTopics.push({
          id,
          slug,
          title,
          handle,
          description,
          category: data.category || "General",
          thumbnailUrl: data.thumbnailUrl || "",
          coverImage: data.coverImage || "",
          videoCount,
          followerCount,
          matchScore: score,
          matchPercentage: rawPct,
          recommendationReason,
        });
      });

      // Sort by match score descending
      scoredTopics.sort((a, b) => b.matchScore - a.matchScore);

      const recommendedTopic = scoredTopics.length > 0 ? scoredTopics[0] : null;

      logger.info("[TopicRecommendations] Computed recommendations for video", {
        videoTitle,
        category,
        totalTopics: scoredTopics.length,
        topMatch: recommendedTopic?.title,
        topScore: recommendedTopic?.matchPercentage,
      });

      res.status(200).json({
        status: "success",
        recommendedTopic,
        rankedTopics: scoredTopics,
      });
    } catch (e: any) {
      logger.error("[TopicRecommendations] Error calculating recommendations", e);
      res.status(500).json({ error: e?.message || "Internal server error" });
    }
  }
);
