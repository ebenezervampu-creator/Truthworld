import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import { cosineSimilarity } from "./fingerprintService";

const db = () => admin.firestore();

// 5 minutes retrieval cache TTL
const CANDIDATE_CACHE_TTL_MS = 5 * 60 * 1000;

interface CacheEntry<T> {
  data: T;
  timestamp: number;
}

const candidateCache = new Map<string, CacheEntry<any[]>>();

export class VectorRetrievalService {
  /**
   * Abstracted method to search for nearest protected assets.
   * Leverages native Firestore Vector Search when indexed, falling back to brute force.
   */
  async searchAssets(
    queryEmbedding: number[],
    excludeVideoId: string,
    minSimilarity: number = 0.75,
    limit: number = 20
  ): Promise<any[]> {
    // Generate a simple cache key using first few dimensions of embedding to prevent memory explosion
    const cacheKey = `assets_${excludeVideoId}_${queryEmbedding.slice(0, 5).map(v => v.toFixed(3)).join(",")}`;
    const cached = candidateCache.get(cacheKey);

    if (cached && Date.now() - cached.timestamp < CANDIDATE_CACHE_TTL_MS) {
      logger.info("[VectorRetrieval] Cache hit for copyright asset candidates search", { excludeVideoId });
      return cached.data;
    }

    try {
      const collectionRef = db().collection("copyright_assets");
      const vectorQuery = collectionRef.findNearest({
        vectorField: "summaryEmbedding",
        queryVector: admin.firestore.FieldValue.vector(queryEmbedding),
        limit: limit,
        distanceMeasure: "COSINE",
      });

      const snap = await vectorQuery.get();
      const candidates: any[] = [];

      for (const doc of snap.docs) {
        if (doc.id === excludeVideoId) continue;
        
        const data = doc.data();
        const storedEmbedding = data.summaryEmbedding?.toArray?.() || data.summaryEmbedding || [];
        if (storedEmbedding.length === 0) continue;

        const similarity = cosineSimilarity(queryEmbedding, storedEmbedding);
        if (similarity >= minSimilarity) {
          candidates.push({
            assetId: doc.id,
            ...data,
            similarity,
          });
        }
      }

      candidates.sort((a, b) => b.similarity - a.similarity);
      candidateCache.set(cacheKey, { data: candidates, timestamp: Date.now() });
      return candidates;
    } catch (error) {
      logger.warn("[VectorRetrieval] Native vector search failed, utilizing brute-force fallback", {
        error: error instanceof Error ? error.message : String(error),
      });
      return this.bruteForceAssets(queryEmbedding, excludeVideoId, minSimilarity, limit);
    }
  }

  private async bruteForceAssets(
    queryEmbedding: number[],
    excludeVideoId: string,
    minSimilarity: number,
    limit: number
  ): Promise<any[]> {
    try {
      // Limit search to the last year of registered assets to avoid scanning excessive number of documents
      const oneYearAgo = Date.now() - 365 * 24 * 60 * 60 * 1000;
      const snap = await db()
        .collection("copyright_assets")
        .where("registeredAt", ">", oneYearAgo)
        .limit(5000)
        .get();

      const candidates: any[] = [];
      for (const doc of snap.docs) {
        if (doc.id === excludeVideoId) continue;

        const data = doc.data();
        const storedEmbedding = data.summaryEmbedding?.toArray?.() || data.summaryEmbedding || [];
        if (storedEmbedding.length === 0) continue;

        const similarity = cosineSimilarity(queryEmbedding, storedEmbedding);
        if (similarity >= minSimilarity) {
          candidates.push({
            assetId: doc.id,
            ...data,
            similarity,
          });
        }
      }

      candidates.sort((a, b) => b.similarity - a.similarity);
      return candidates.slice(0, limit);
    } catch (err) {
      logger.error("[VectorRetrieval] Brute-force search failed", { err });
      return [];
    }
  }
}

export const vectorRetrievalService = new VectorRetrievalService();
