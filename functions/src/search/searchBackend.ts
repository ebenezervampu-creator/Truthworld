import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { computeTextEmbedding } from "./embeddingService";

// ─── Shared Types ────────────────────────────────────────────────────────────

interface SearchRequest {
  query: string;
  filter?: string; // 'All' | 'Videos' | 'Channels' | 'Playlists' | 'Topics' | 'Watched' | 'Unwatched' | 'Recently uploaded'
  limit?: number;
  page?: number;
}

export interface SearchResultItem {
  id: string;
  title: string;
  thumbnail: string;
  views: number;
  channelName: string;
  channelImage: string;
  createdAt: string;
  type: string;
  durationMs?: number;
  language?: string;
  category?: string;
  relevanceScore?: number;
}

// ─── L1: In-Process LRU Cache (per-container, 5-min TTL, 200 entries) ───────
// Purpose: Sub-1ms hits for hot repeated queries within the same container instance.

interface L1Entry { data: SearchResultItem[]; expiresAt: number }
const l1Cache = new Map<string, L1Entry>();
const L1_TTL_MS  = 5 * 60 * 1000; // 5 minutes
const L1_MAX     = 200;

function l1Get(key: string): SearchResultItem[] | null {
  const entry = l1Cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) { l1Cache.delete(key); return null; }
  // Refresh recency for LRU eviction
  l1Cache.delete(key);
  l1Cache.set(key, entry);
  return entry.data;
}

function l1Set(key: string, data: SearchResultItem[]): void {
  if (l1Cache.size >= L1_MAX) {
    const oldest = l1Cache.keys().next().value;
    if (oldest) l1Cache.delete(oldest);
  }
  l1Cache.set(key, { data, expiresAt: Date.now() + L1_TTL_MS });
}

// ─── L2: Firestore Distributed Cache (cross-container, 15-min TTL) ──────────
// Purpose: Shared cache across ALL container instances — fixes the per-container
// cache miss problem identified in the scalability audit.
// Cost: 1 Firestore read per unique query per 15 min window. Near-zero vs Vertex AI savings.

const CACHE_COLLECTION = "search_cache";
const L2_TTL_MS        = 15 * 60 * 1000; // 15 minutes

/**
 * Sanitizes a cache key to a valid Firestore document ID.
 * Replaces non-alphanumeric characters (except `-`) with `_` and caps at 1,400 bytes.
 */
function toCacheDocId(key: string): string {
  return key.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 1400);
}

async function l2Get(key: string): Promise<SearchResultItem[] | null> {
  try {
    const snap = await admin.firestore()
      .collection(CACHE_COLLECTION)
      .doc(toCacheDocId(key))
      .get();

    if (!snap.exists) return null;

    const d = snap.data()!;
    const expiresAt = (d.expiresAt as admin.firestore.Timestamp | undefined)?.toMillis();
    if (!expiresAt || Date.now() > expiresAt) {
      snap.ref.delete().catch(() => {}); // purge asynchronously
      return null;
    }

    const results = d.results as SearchResultItem[] | undefined;
    return Array.isArray(results) && results.length > 0 ? results : null;
  } catch (err) {
    // L2 read failure is non-fatal — falls through to live search
    logger.warn("[searchTruthWorld] L2 cache read failed", {
      error: err instanceof Error ? err.message : String(err),
    });
    return null;
  }
}

function l2Set(key: string, data: SearchResultItem[]): void {
  // Fire-and-forget — we never await this to avoid adding latency to the response
  admin.firestore()
    .collection(CACHE_COLLECTION)
    .doc(toCacheDocId(key))
    .set({
      results: data,
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + L2_TTL_MS),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    })
    .catch((err) => {
      logger.warn("[searchTruthWorld] L2 cache write failed", {
        error: err instanceof Error ? err.message : String(err),
      });
    });
}

// ─── Per-User Sliding-Window Rate Limiter ───────────────────────────────────
// Prevents a single authenticated user from exhausting the shared Vertex AI quota.
// Limit: 30 searches per UID per 60-second window (in-process, per-container).

interface RateEntry { count: number; windowStart: number }
const rateLimitMap = new Map<string, RateEntry>();
const RATE_WINDOW_MS  = 60 * 1000; // 1 minute
const RATE_MAX        = 30;        // max searches per window

function isRateLimited(uid: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(uid);

  if (!entry || now - entry.windowStart > RATE_WINDOW_MS) {
    rateLimitMap.set(uid, { count: 1, windowStart: now });
    return false;
  }

  if (entry.count >= RATE_MAX) return true;

  entry.count += 1;
  return false;
}

// Periodic cleanup to prevent rate-limit map from growing unboundedly.
// Safe in Cloud Run 2nd Gen containers which persist across requests.
setInterval(() => {
  const cutoff = Date.now() - RATE_WINDOW_MS * 2;
  for (const [uid, entry] of rateLimitMap.entries()) {
    if (entry.windowStart < cutoff) rateLimitMap.delete(uid);
  }
}, 5 * 60 * 1000); // every 5 minutes

// ─── Typed Firestore Vector Query Helper ────────────────────────────────────
// The @google-cloud/firestore Admin SDK exposes `findNearest` at runtime but does
// not yet export a VectorQuery TypeScript type. The `as any` cast is intentional
// and isolated here. When the SDK exports the type, remove the cast from this
// single location rather than hunting for it throughout the codebase.
function runVectorQuery(
  col: admin.firestore.CollectionReference,
  queryVector: number[],
  limit: number,
): Promise<admin.firestore.QuerySnapshot> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const vectorQuery = (col as any).findNearest({
    vectorField: "embedding",
    queryVector,
    limit,
    distanceMeasure: "COSINE",
    distanceResultField: "_distance",
  });
  return vectorQuery.get() as Promise<admin.firestore.QuerySnapshot>;
}

// ─── Main Cloud Function ─────────────────────────────────────────────────────
export const searchTruthWorld = onCall(
  {
    region: "asia-south1",
    cpu: 1,
    memory: "512MiB",
    concurrency: 40,
    maxInstances: 50,
    timeoutSeconds: 15,
  },
  async (request): Promise<SearchResultItem[]> => {
    const startTime = Date.now();

    // ── Bug Fix #2: Authentication Guard ──────────────────────────────────
    if (!request.auth) {
      logger.warn("[searchTruthWorld] Unauthenticated call rejected");
      return [];
    }
    const uid = request.auth.uid;

    // ── Bug Fix #3: Per-User Rate Limiting ────────────────────────────────
    if (isRateLimited(uid)) {
      logger.warn("[searchTruthWorld] Rate limit hit", { uid });
      // Return empty — the client will show its own cached results
      return [];
    }

    const data = request.data as SearchRequest;
    const rawQuery      = data?.query?.trim() || "";
    const activeFilter  = data?.filter || "All";
    const requestedLimit = Math.min(Math.max(Number(data?.limit) || 20, 1), 50);

    if (!rawQuery) return [];

    const cleanQuery = rawQuery.replace(/[^\w\s@\-_]/g, "").trim();
    if (!cleanQuery) return [];

    const cacheKey = `${activeFilter.toLowerCase()}:::${cleanQuery.toLowerCase()}`;

    // ── Bug Fix #1: Two-Level Cache Lookup ────────────────────────────────

    // L1 — in-process (sub-1ms, same container)
    const l1Hit = l1Get(cacheKey);
    if (l1Hit) {
      logger.info("[searchTruthWorld] L1 cache hit", {
        query: cleanQuery, filter: activeFilter, latencyMs: Date.now() - startTime,
      });
      return l1Hit;
    }

    // L2 — Firestore distributed (cross-container, ~3ms, 1 read)
    const l2Hit = await l2Get(cacheKey);
    if (l2Hit) {
      l1Set(cacheKey, l2Hit); // promote to L1 for subsequent requests on same container
      logger.info("[searchTruthWorld] L2 cache hit", {
        query: cleanQuery, filter: activeFilter, latencyMs: Date.now() - startTime,
      });
      return l2Hit;
    }

    const db = admin.firestore();
    const resultsMap = new Map<string, SearchResultItem>();

    // ── Step 1: Hybrid Exact Channel / Handle Matching ────────────────────
    const isChannelSearch =
      activeFilter === "Channels" ||
      cleanQuery.startsWith("@") ||
      activeFilter === "All";

    if (isChannelSearch) {
      const handleQ = cleanQuery.replace(/^@/, "").toLowerCase();
      try {
        const channelSnap = await db
          .collection("channels")
          .where("handleLowercase", ">=", handleQ)
          .where("handleLowercase", "<=", handleQ + "\uf8ff")
          .limit(activeFilter === "Channels" ? requestedLimit : 3)
          .get();

        for (const doc of channelSnap.docs) {
          const cData = doc.data();
          const channelTitle =
            cData.channelName || cData.name || cData.displayName || "Channel";
          const avatar =
            cData.avatarUrl ||
            cData.photoUrl ||
            cData.channelImage ||
            cData.profileImageUrl ||
            "";
          const subs = Number(cData.subscriberCount || cData.subscribers || 0);
          const handle = cData.handle || cData.channelHandle || "";

          resultsMap.set(`channel_${doc.id}`, {
            id: doc.id,
            title: channelTitle,
            thumbnail: avatar,
            views: subs,
            channelName: handle
              ? handle.startsWith("@") ? handle : `@${handle}`
              : channelTitle,
            channelImage: avatar,
            createdAt:
              cData.createdAt?.toDate?.()?.toISOString?.() ||
              new Date().toISOString(),
            type: "ResultType.channel",
            language: cData.language,
            category: cData.category,
            relevanceScore: cleanQuery.toLowerCase() === handleQ ? 100 : 75,
          });
        }
      } catch (err) {
        logger.warn("[searchTruthWorld] Channel lookup warning", {
          error: err instanceof Error ? err.message : String(err),
        });
      }
    }

    // ── Step 2: Native Vector Search (findNearest) ────────────────────────
    const shouldSearchVideos =
      activeFilter === "All" ||
      activeFilter === "Videos" ||
      activeFilter === "Recently uploaded" ||
      activeFilter === "Watched" ||
      activeFilter === "Unwatched";

    if (shouldSearchVideos) {
      const queryEmbedding = await computeTextEmbedding(cleanQuery);
      let vectorSearchSuccessful = false;

      if (queryEmbedding && queryEmbedding.length > 0) {
        try {
          // Bug Fix #4: Use the typed helper instead of inline `as any`
          const vectorSnap = await runVectorQuery(
            db.collection("videos"),
            queryEmbedding,
            requestedLimit,
          );

          if (vectorSnap.docs.length > 0) {
            vectorSearchSuccessful = true;
            for (const doc of vectorSnap.docs) {
              const vData = doc.data();
              const vis    = (vData.visibility || "public").toLowerCase();
              const status = (vData.status || "ready").toLowerCase();

              if (vis === "private" || status === "draft" || status === "uploading") {
                continue;
              }

              const distance =
                vData._distance !== undefined ? Number(vData._distance) : 0.5;
              const relevanceScore = Math.max(0, (1 - distance) * 100);

              resultsMap.set(`video_${doc.id}`, {
                id: doc.id,
                title: vData.title || "Untitled",
                thumbnail: vData.thumbnailUrl || "",
                views: Number(vData.viewCount || vData.views || 0),
                channelName: vData.channelName || "Unknown",
                channelImage: vData.channelAvatarUrl || vData.channelImage || "",
                createdAt:
                  vData.uploadedAt?.toDate?.()?.toISOString?.() ||
                  vData.createdAt?.toDate?.()?.toISOString?.() ||
                  new Date().toISOString(),
                type: "ResultType.video",
                durationMs: Number(vData.durationMs) || undefined,
                language: vData.language,
                category: vData.category,
                relevanceScore,
              });
            }
          }
        } catch (vectorErr) {
          logger.warn(
            "[searchTruthWorld] Vector search failed or index building — using indexed fallback",
            { error: vectorErr instanceof Error ? vectorErr.message : String(vectorErr) },
          );
        }
      }

      // ── Step 3: Zero-Failure Indexed Fallback ─────────────────────────
      if (!vectorSearchSuccessful || resultsMap.size === 0) {
        try {
          const lowerQ = cleanQuery.toLowerCase();
          const keywordSnap = await db
            .collection("videos")
            .where("keywords", "array-contains", lowerQ)
            .where("visibility", "==", "public")
            .limit(requestedLimit)
            .get();

          for (const doc of keywordSnap.docs) {
            const vData = doc.data();
            const status = (vData.status || "ready").toLowerCase();
            if (status === "draft" || status === "uploading") continue;

            resultsMap.set(`video_${doc.id}`, {
              id: doc.id,
              title: vData.title || "Untitled",
              thumbnail: vData.thumbnailUrl || "",
              views: Number(vData.viewCount || vData.views || 0),
              channelName: vData.channelName || "Unknown",
              channelImage: vData.channelAvatarUrl || vData.channelImage || "",
              createdAt:
                vData.uploadedAt?.toDate?.()?.toISOString?.() ||
                vData.createdAt?.toDate?.()?.toISOString?.() ||
                new Date().toISOString(),
              type: "ResultType.video",
              durationMs: Number(vData.durationMs) || undefined,
              language: vData.language,
              category: vData.category,
              relevanceScore: 60.0,
            });
          }

          // Secondary prefix fallback when keywords yield few results
          if (resultsMap.size < 5) {
            const prefixSnap = await db
              .collection("videos")
              .where("title", ">=", cleanQuery)
              .where("title", "<=", cleanQuery + "\uf8ff")
              .where("visibility", "==", "public")
              .limit(10)
              .get();

            for (const doc of prefixSnap.docs) {
              const vData = doc.data();
              if (resultsMap.has(`video_${doc.id}`)) continue;
              resultsMap.set(`video_${doc.id}`, {
                id: doc.id,
                title: vData.title || "Untitled",
                thumbnail: vData.thumbnailUrl || "",
                views: Number(vData.viewCount || vData.views || 0),
                channelName: vData.channelName || "Unknown",
                channelImage: vData.channelAvatarUrl || vData.channelImage || "",
                createdAt:
                  vData.uploadedAt?.toDate?.()?.toISOString?.() ||
                  vData.createdAt?.toDate?.()?.toISOString?.() ||
                  new Date().toISOString(),
                type: "ResultType.video",
                durationMs: Number(vData.durationMs) || undefined,
                language: vData.language,
                category: vData.category,
                relevanceScore: 50.0,
              });
            }
          }
        } catch (fallbackErr) {
          logger.warn("[searchTruthWorld] Indexed fallback warning", {
            error: fallbackErr instanceof Error ? fallbackErr.message : String(fallbackErr),
          });
        }
      }
    }

    // ── Step 4: Topic Matching ─────────────────────────────────────────────
    if (
      activeFilter === "Topics" ||
      (activeFilter === "All" && resultsMap.size < requestedLimit)
    ) {
      try {
        const topicQ = cleanQuery.toLowerCase();
        const topicSnap = await db
          .collection("topics")
          .where("slug", ">=", topicQ)
          .where("slug", "<=", topicQ + "\uf8ff")
          .limit(5)
          .get();

        for (const doc of topicSnap.docs) {
          const tData = doc.data();
          const topicTitle =
            tData.title || tData.name || tData.slug || "Topic";
          resultsMap.set(`topic_${doc.id}`, {
            id: doc.id,
            title: topicTitle,
            thumbnail: tData.thumbnailUrl || tData.coverImage || "",
            views: Number(tData.videoCount || 0),
            channelName: `T/${tData.slug || doc.id}`,
            channelImage: "",
            createdAt:
              tData.createdAt?.toDate?.()?.toISOString?.() ||
              new Date().toISOString(),
            type: "ResultType.topic",
            category: tData.category,
            relevanceScore: 40.0,
          });
        }
      } catch (topicErr) {
        logger.warn("[searchTruthWorld] Topic query warning", {
          error: topicErr instanceof Error ? topicErr.message : String(topicErr),
        });
      }
    }

    // ── Step 5: Sort & Slice ───────────────────────────────────────────────
    const finalResults = Array.from(resultsMap.values());
    finalResults.sort((a, b) => {
      const scoreDiff = (b.relevanceScore || 0) - (a.relevanceScore || 0);
      if (scoreDiff !== 0) return scoreDiff;
      return b.views - a.views;
    });
    const sliced = finalResults.slice(0, requestedLimit);

    // ── Step 6: Populate Both Cache Levels ────────────────────────────────
    l1Set(cacheKey, sliced);    // L1: in-process (immediate)
    l2Set(cacheKey, sliced);    // L2: Firestore distributed (fire-and-forget)

    logger.info("[searchTruthWorld] Complete", {
      query: cleanQuery,
      filter: activeFilter,
      uid,
      count: sliced.length,
      latencyMs: Date.now() - startTime,
    });

    return sliced;
  },
);
