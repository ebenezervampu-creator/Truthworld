import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { onRequest } from "firebase-functions/v2/https";
import { Request, Response } from "express";

import { applySecurityHeaders } from "../utils/securityHeaders";
import { getCache, setCache } from "../shared/memory-cache";

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * ⚡ PUBLIC FEED SERVER (Edge-Cached Cloud Function)
 *
 * Provides sub-50ms global cold-start responses for read-heavy public feeds
 * (Home, Trending, Explore, Category filters) backed by Firebase Hosting Global CDN.
 *
 * Headers enforced:
 *   - Cache-Control: public, max-age=60, s-maxage=300, stale-while-revalidate=600
 *   - ETag: RFC 9110 representation hash with standards-compliant weak comparison
 *   - Scale-to-zero (minInstances: 0) for zero idle cost
 *   - Concurrency: 50, Memory: 256MiB
 */

const CURSOR_SECRET = process.env.FEED_CURSOR_SECRET || "truthworld-edge-feed-secret-salt-2026";

export interface CursorPayload {
  lastId: string;
  timestamp: number;
  feedType: string;
  category: string;
  lang: string;
  limit: number;
  issuedAt: number;
  expiresAt: number;
  version: number;
}

export interface FeedResponsePayload {
  feed: Record<string, any>[];
  count: number;
  nextCursor?: string | null;
  hasMore: boolean;
  category: string;
  lang: string;
  cachedAt?: string;
  edgeServed?: boolean;
  fromL1Cache?: boolean;
}

/**
 * RFC 9110 Compliant ETag Parser
 * Correctly parses entity tags handling commas enclosed within quoted strings,
 * weak tags (W/"..."), and wildcards (*).
 */
const ETAG_TOKEN_REGEX = /\*|(?:W\/)?"(?:[^"\\]|\\.)*"/gi;

export function parseETags(header: string | undefined): string[] {
  if (!header || typeof header !== "string") return [];
  const matches = header.match(ETAG_TOKEN_REGEX);
  if (!matches) return [];
  return matches.map((tag) => tag.trim());
}

export function isWeakETagMatch(ifNoneMatchHeader: string | undefined, computedETag: string): boolean {
  if (!ifNoneMatchHeader) return false;
  const tags = parseETags(ifNoneMatchHeader);
  if (tags.length === 0) return false;

  const normalize = (tag: string) => tag.replace(/^W\//i, "").replace(/^"|"$/g, "");
  const target = normalize(computedETag);

  for (const tag of tags) {
    if (tag === "*") return true;
    if (normalize(tag) === target) return true;
  }
  return false;
}

/**
 * HMAC-SHA256 Signed Opaque Cursor (Option A)
 * Enforces pagination integrity and binds cursor strictly to query parameters.
 */
function createSignedCursor(payload: CursorPayload): string {
  const jsonStr = JSON.stringify(payload);
  const payloadB64 = Buffer.from(jsonStr, "utf8").toString("base64url");
  const signature = crypto
    .createHmac("sha256", CURSOR_SECRET)
    .update(payloadB64)
    .digest("base64url");
  return `${payloadB64}.${signature}`;
}

export function verifyAndDecodeCursor(
  token: string | undefined,
  expectedFeedType: string,
  expectedCategory: string,
  expectedLang: string,
  expectedLimit?: number
): CursorPayload | null {
  if (!token || typeof token !== "string" || !token.includes(".")) {
    return null;
  }
  const [payloadB64, providedSig] = token.split(".");
  if (!payloadB64 || !providedSig) return null;

  const expectedSig = crypto
    .createHmac("sha256", CURSOR_SECRET)
    .update(payloadB64)
    .digest("base64url");

  // Constant-time comparison to prevent timing attacks
  if (
    providedSig.length !== expectedSig.length ||
    !crypto.timingSafeEqual(Buffer.from(providedSig), Buffer.from(expectedSig))
  ) {
    console.warn("[publicFeedServer] Cursor signature verification failed.");
    return null;
  }

  try {
    const jsonStr = Buffer.from(payloadB64, "base64url").toString("utf8");
    const payload = JSON.parse(jsonStr) as CursorPayload;

    if (
      !payload.lastId ||
      typeof payload.lastId !== "string" ||
      !/^[a-zA-Z0-9_-]{3,64}$/.test(payload.lastId) ||
      typeof payload.timestamp !== "number" ||
      payload.timestamp <= 0
    ) {
      return null;
    }

    // Expiration check (24h validity window)
    if (typeof payload.expiresAt === "number" && Date.now() > payload.expiresAt) {
      console.warn("[publicFeedServer] Expired cursor token received.");
      return null;
    }

    // Cursor must match exact feed parameters
    if (
      payload.feedType !== expectedFeedType ||
      payload.category !== expectedCategory ||
      payload.lang !== expectedLang
    ) {
      console.warn("[publicFeedServer] Cursor parameter mismatch. Rejecting cross-query cursor.");
      return null;
    }

    if (expectedLimit !== undefined && typeof payload.limit === "number" && payload.limit !== expectedLimit) {
      console.warn("[publicFeedServer] Cursor limit mismatch. Rejecting mismatched limit cursor.");
      return null;
    }

    return payload;
  } catch {
    return null;
  }
}

/**
 * Normalizes Firestore Timestamp, Date, string, or number to epoch milliseconds
 */
function toEpochMs(value: any, fallback: number): number {
  if (!value) return fallback;
  if (typeof value === "number") return value;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return isNaN(parsed) ? fallback : parsed;
  }
  return fallback;
}

/**
 * Strips internal moderation decisions, private storage paths, and raw audio references.
 */
function sanitizePublicVideoItem(data: Record<string, any>, id: string): Record<string, any> | null {
  if (
    data.isDeleted === true ||
    data.status === "suspended" ||
    data.status === "blocked" ||
    data.moderationStatus === "rejected" ||
    data.copyrightStrike === true
  ) {
    return null;
  }
  const clean: Record<string, any> = { id, ...data };
  delete clean.internalModerationDecision;
  delete clean.internalNotes;
  delete clean.privateStorageBucketUrl;
  delete clean.rawAudioUrl;
  delete clean.storagePath;
  delete clean.moderatorUid;
  return clean;
}

// In-flight Promise coalescing map to eliminate thundering-herd Firestore reads
const inFlightRequests = new Map<string, Promise<FeedResponsePayload>>();

async function executeSingleFlight(
  cacheKey: string,
  loader: () => Promise<FeedResponsePayload>
): Promise<FeedResponsePayload> {
  const existing = inFlightRequests.get(cacheKey);
  if (existing) {
    return existing;
  }

  const promise = (async () => {
    try {
      const data = await loader();
      // Populate in-process cache before resolving to ensure all awaiters get the cached copy
      setCache(cacheKey, data, 60);
      return data;
    } finally {
      inFlightRequests.delete(cacheKey);
    }
  })();

  inFlightRequests.set(cacheKey, promise);
  return promise;
}

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
    applySecurityHeaders(res);

    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, If-None-Match");
    res.set("Access-Control-Expose-Headers", "ETag, Cache-Control");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "GET" && req.method !== "HEAD") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // Resolve docId sentinel safely across environments
    const docIdField = (admin.firestore as any)?.FieldPath?.documentId
      ? (admin.firestore as any).FieldPath.documentId()
      : "__name__";

    // Firebase Hosting / Edge CDN Caching headers
    res.set("Cache-Control", "public, max-age=60, s-maxage=300, stale-while-revalidate=600");
    res.set("Vary", "Accept-Encoding");
    res.set("Content-Type", "application/json; charset=utf-8");

    try {
      const path = (req.path || "").toLowerCase();
      const feedType = path.includes("trending") ? "trending" : "home";

      // 1. Parameter Normalization
      const rawCategory = typeof req.query.category === "string" ? req.query.category.trim().toLowerCase() : "all";
      const category = rawCategory.length > 0 ? rawCategory : "all";

      const rawLang = typeof req.query.lang === "string" ? req.query.lang.trim().toLowerCase() : "all";
      const lang = rawLang.length > 0 ? rawLang : "all";

      const rawLimit = parseInt(req.query.limit as string, 10);
      const limit = isNaN(rawLimit) ? 24 : Math.min(Math.max(rawLimit, 1), 50);

      const rawCursor = typeof req.query.cursor === "string" ? req.query.cursor.trim() : undefined;

      // Validate cursor if provided
      let validatedCursor: CursorPayload | null = null;
      if (rawCursor) {
        validatedCursor = verifyAndDecodeCursor(rawCursor, feedType, category, lang, limit);
        if (!validatedCursor) {
          // If invalid, expired, or tampered cursor, return bad request
          res.status(400).json({ error: "Invalid, expired, or mismatched pagination cursor" });
          return;
        }
      }

      // Build normalized cache key (excludes all tracking parameters like utm_*, fbclid)
      const cursorKey = validatedCursor ? `_c_${validatedCursor.lastId}_${validatedCursor.timestamp}` : "_p1";
      const cacheKey = `edge_feed_${feedType}_${category}_${lang}_${limit}${cursorKey}`;

      // Check L1 In-Process Memory Cache
      const cached = getCache<FeedResponsePayload>(cacheKey);
      let payload: FeedResponsePayload;
      let isL1Hit = false;

      if (cached && Array.isArray(cached.feed)) {
        payload = cached;
        isL1Hit = true;
      } else {
        // Execute single-flight coalesced Firestore fetch
        payload = await executeSingleFlight(cacheKey, async () => {
          const db = admin.firestore();
          const now = Date.now();

          if (feedType === "trending") {
            const TRENDING_GRAVITY = 1.5;
            const TRENDING_WINDOW_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
            const cutoff = new Date(now - TRENDING_WINDOW_MS);

            let trendQuery: admin.firestore.Query = db
              .collection("videos")
              .where("status", "==", "published")
              .where("visibility", "==", "public")
              .where("createdAt", ">=", cutoff)
              .orderBy("createdAt", "desc")
              .orderBy(docIdField, "desc");

            if (category !== "all") {
              trendQuery = trendQuery.where("category", "==", category);
            }

            if (lang !== "all") {
              trendQuery = trendQuery.where("language", "==", lang);
            }

            if (validatedCursor) {
              trendQuery = trendQuery.startAfter(
                admin.firestore.Timestamp.fromMillis(validatedCursor.timestamp),
                validatedCursor.lastId
              );
            }

            // Fetch +1 to determine hasMore accurately
            const snap = await trendQuery.limit(limit + 1).get();
            const docs = snap.docs;
            const hasMore = docs.length > limit;
            const slice = hasMore ? docs.slice(0, limit) : docs;

            const scored = slice
              .map((doc) => {
                const clean = sanitizePublicVideoItem(doc.data(), doc.id);
                if (!clean) return null;
                const createdAt = toEpochMs(clean.createdAt, now);
                const ageHours = Math.max(0, (now - createdAt) / 3600000);
                const views = clean.viewCount || clean.views || 0;
                const likes = clean.likeCount || clean.likes || 0;
                const comments = clean.commentCount || 0;

                const numerator = views + 2 * likes + 3 * comments;
                const denominator = Math.pow(ageHours + 2, TRENDING_GRAVITY);
                const trendingScore = numerator / denominator;

                return { ...clean, trendingScore, _rawTimestamp: createdAt, _docId: doc.id };
              })
              .filter((v): v is NonNullable<typeof v> => v !== null);

            scored.sort((a, b) => b.trendingScore - a.trendingScore);

            const lastItem = scored.length > 0 ? scored[scored.length - 1] : null;
            let nextCursor: string | null = null;
            if (hasMore && lastItem) {
              nextCursor = createSignedCursor({
                lastId: lastItem._docId,
                timestamp: lastItem._rawTimestamp,
                feedType,
                category,
                lang,
                limit,
                issuedAt: now,
                expiresAt: now + 24 * 60 * 60 * 1000, // 24 hours
                version: 1,
              });
            }

            // Strip internal helper fields before serializing
            const cleanFeed = scored.map((item) => {
              const { _rawTimestamp, _docId, ...rest } = item;
              return rest;
            });

            return {
              feed: cleanFeed,
              count: cleanFeed.length,
              nextCursor,
              hasMore,
              category,
              lang,
              cachedAt: new Date().toISOString(),
              edgeServed: true,
            };
          } else {
            // Default Chronological Home Feed
            let query: admin.firestore.Query = db
              .collection("videos")
              .where("status", "==", "published")
              .where("visibility", "==", "public");

            if (category !== "all") {
              query = query.where("category", "==", category);
            }

            if (lang !== "all") {
              query = query.where("language", "==", lang);
            }

            // Deterministic Compound Ordering: createdAt desc, docId desc
            query = query
              .orderBy("createdAt", "desc")
              .orderBy(docIdField, "desc");

            if (validatedCursor) {
              query = query.startAfter(
                admin.firestore.Timestamp.fromMillis(validatedCursor.timestamp),
                validatedCursor.lastId
              );
            }

            // Fetch +1 to check hasMore
            const snap = await query.limit(limit + 1).get();
            const docs = snap.docs;
            const hasMore = docs.length > limit;
            const slice = hasMore ? docs.slice(0, limit) : docs;

            let lastTimestamp = now;
            let lastDocId = "";

            const cleanFeed = slice
              .map((doc) => {
                const clean = sanitizePublicVideoItem(doc.data(), doc.id);
                if (clean) {
                  lastTimestamp = toEpochMs(clean.createdAt, now);
                  lastDocId = doc.id;
                }
                return clean;
              })
              .filter((v): v is NonNullable<typeof v> => v !== null);

            let nextCursor: string | null = null;
            if (hasMore && lastDocId) {
              nextCursor = createSignedCursor({
                lastId: lastDocId,
                timestamp: lastTimestamp,
                feedType,
                category,
                lang,
                limit,
                issuedAt: now,
                expiresAt: now + 24 * 60 * 60 * 1000, // 24 hours
                version: 1,
              });
            }

            return {
              feed: cleanFeed,
              count: cleanFeed.length,
              nextCursor,
              hasMore,
              category,
              lang,
              cachedAt: new Date().toISOString(),
              edgeServed: true,
            };
          }
        });
      }

      // 2. Serialized Payload & RFC 9110 ETag Generation
      const serializedJson = JSON.stringify(payload);
      const computedETag =
        'W/"' +
        crypto.createHash("sha256").update(serializedJson).digest("hex").substring(0, 24) +
        '"';

      res.set("ETag", computedETag);
      res.set("X-Cache-L1", isL1Hit ? "HIT" : "MISS");

      // 3. Conditional Request Evaluation (Weak Comparison)
      const ifNoneMatch = req.headers["if-none-match"];
      if (ifNoneMatch && isWeakETagMatch(ifNoneMatch, computedETag)) {
        res.status(304).end();
        return;
      }

      res.status(200).send(serializedJson);
    } catch (error) {
      console.error("[publicFeedServer] Error serving edge feed:", error);
      res.status(500).json({
        error: "Unable to retrieve feed from edge server",
        feed: [],
        hasMore: false,
      });
    }
  }
);
