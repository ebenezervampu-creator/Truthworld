import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "../pipeline/utils/logger";
import * as https from "https";

/**
 * 🖼️ IMAGE PROXY SERVICE
 * Caches and serves profile images to reduce rate limiting from Google
 * Reduces direct requests to lh3.googleusercontent.com
 */

const db = () => admin.firestore();
const storage = admin.storage();
const CACHE_COLLECTION = "image_cache";
const CACHE_DURATION_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

interface CacheEntry {
  originalUrl: string;
  gsUrl: string;
  cachedAt: number;
  expiresAt: number;
}

/**
 * Download image from URL and store in Cloud Storage
 */
async function downloadAndCacheImage(
  imageUrl: string,
  cacheKey: string
): Promise<string> {
  try {
    // Fetch image from original URL
    const imageData = await new Promise<Buffer>((resolve, reject) => {
      https.get(imageUrl, { timeout: 10000 }, (res) => {
        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode}: ${imageUrl}`));
          return;
        }
        const chunks: Buffer[] = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => resolve(Buffer.concat(chunks)));
        res.on("error", reject);
      }).on("error", reject);
    });

    // Store in Cloud Storage under cache bucket path
    const bucket = storage.bucket();
    const file = bucket.file(`image-cache/${cacheKey}.jpg`);
    await file.save(imageData, {
      metadata: {
        contentType: "image/jpeg",
        cacheControl: "public, max-age=604800", // 7 days
      },
    });

    // Get public URL
    const gsUrl = `gs://truthworld-default.appspot.com/image-cache/${cacheKey}.jpg`;

    // Cache metadata in Firestore
    await db().collection(CACHE_COLLECTION).doc(cacheKey).set({
      originalUrl: imageUrl,
      gsUrl,
      cachedAt: Date.now(),
      expiresAt: Date.now() + CACHE_DURATION_MS,
    } as CacheEntry);

    logger.info(`[image-proxy] Cached image: ${cacheKey}`);
    return gsUrl;
  } catch (err) {
    logger.error(`[image-proxy] Failed to cache image: ${imageUrl}`, err);
    throw err;
  }
}

/**
 * Get cached image URL or fetch and cache if not exists
 */
async function getCachedImageUrl(imageUrl: string): Promise<string> {
  if (!imageUrl) return "";

  const cacheKey = Buffer.from(imageUrl).toString("base64").slice(0, 32);

  try {
    // Check if already cached
    const cacheDoc = await db()
      .collection(CACHE_COLLECTION)
      .doc(cacheKey)
      .get();

    if (cacheDoc.exists) {
      const cache = cacheDoc.data() as CacheEntry;
      if (cache.expiresAt > Date.now()) {
        logger.info(`[image-proxy] Cache hit: ${cacheKey}`);
        return cache.gsUrl;
      }
      // Cache expired, delete and re-fetch
      await db().collection(CACHE_COLLECTION).doc(cacheKey).delete();
    }

    // Not cached or expired - fetch and cache
    return await downloadAndCacheImage(imageUrl, cacheKey);
  } catch (err) {
    logger.warn(`[image-proxy] Cache lookup failed, returning original URL:`, err);
    // Fall back to original URL if caching fails
    return imageUrl;
  }
}

/**
 * ðŸ" GET CACHED IMAGE (HTTPS)
 * Proxies image URL to a cached version, reducing rate limiting
 */
export const getCachedImage = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    const imageUrl = req.query.url as string;

    if (!imageUrl) {
      res.status(400).json({ error: "Missing 'url' query parameter" });
      return;
    }

    try {
      const cachedUrl = await getCachedImageUrl(imageUrl);
      res.status(200).json({ cachedUrl });
    } catch (err) {
      logger.error("[getCachedImage] Error:", err);
      res.status(500).json({ error: "Failed to cache image" });
    }
  }
);

/**
 * Clean up expired image cache (scheduled)
 */
export async function cleanupExpiredImageCache() {
  try {
    const now = Date.now();
    const expiredSnap = await db()
      .collection(CACHE_COLLECTION)
      .where("expiresAt", "<", now)
      .limit(100)
      .get();

    for (const doc of expiredSnap.docs) {
      await doc.ref.delete();
    }

    logger.info(
      `[image-proxy] Cleaned up ${expiredSnap.size} expired cache entries`
    );
  } catch (err) {
    logger.error("[cleanupExpiredImageCache] Error:", err);
  }
}
