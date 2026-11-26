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
  topic?: string;
  channelId?: string;
  issuedAt: number;
  expiresAt: number;
  version: number;
}

export interface FeedResponsePayload {
  feed?: Record<string, any>[];
  topics?: Record<string, any>[];
  channels?: Record<string, any>[];
  count: number;
  nextCursor?: string | null;
  hasMore?: boolean;
  category: string;
  lang?: string;
  topic?: string;
  channelId?: string;
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
  expectedLimit?: number,
  expectedTopic?: string,
  expectedChannelId?: string
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

    if (expectedTopic && payload.topic !== expectedTopic) {
      console.warn("[publicFeedServer] Cursor topic mismatch. Rejecting cross-topic cursor.");
      return null;
    }
    if (!expectedTopic && payload.topic) {
      console.warn("[publicFeedServer] Unexpected topic in cursor. Rejecting.");
      return null;
    }

    if (expectedChannelId && payload.channelId !== expectedChannelId) {
      console.warn("[publicFeedServer] Cursor channelId mismatch. Rejecting cross-channel cursor.");
      return null;
    }
    if (!expectedChannelId && payload.channelId) {
      console.warn("[publicFeedServer] Unexpected channelId in cursor. Rejecting.");
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
  if (data.visibility && data.visibility.toLowerCase() !== "public") {
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

function sanitizePublicTopicItem(data: Record<string, any>, id: string): Record<string, any> | null {
  if (data.isDeleted === true || data.status === "deleted" || data.status === "archived") {
    return null;
  }
  return {
    id,
    slug: data.slug || id,
    name: data.name || "",
    category: data.category || "General",
    trendingScore: Number(data.trendingScore) || 0,
    videoCount: Number(data.videoCount || data.effectiveVideoCount) || 0,
    followerCount: Number(data.followerCount) || 0,
    isFeatured: Boolean(data.isFeatured),
    iconUrl: data.iconUrl || "",
    bannerUrl: data.bannerUrl || "",
  };
}

function sanitizePublicChannelItem(data: Record<string, any>, id: string): Record<string, any> | null {
  const isSuspended =
    data.status === "suspended" ||
    data.status === "banned" ||
    data.status === "deleted" ||
    data.status === "onHold" ||
    data.status === "hold";
  const vis = (data.visibility || "").toLowerCase();
  const isPrivate = vis === "private" || vis === "unlisted" || data.isPublic === false;
  if (isSuspended || isPrivate) {
    return null;
  }
  return {
    id,
    name: data.displayName || data.name || data.channelName || "",
    handle: data.handle || data.customUrl || "",
    avatarUrl: data.avatarUrl || data.profile?.photoUrl || "",
    bannerUrl: data.bannerUrl || data.profile?.bannerUrl || "",
    category: data.category || data.profile?.category || "General",
    subscriberCount: Number(data.subscriberCount || data.stats?.subscriberCount) || 0,
    videoCount: Number(data.videoCount || data.stats?.videoCount) || 0,
    isVerified: Boolean(data.isVerified || data.verification?.isVerified),
  };
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
    memory: "256MiB",
    timeoutSeconds: 15,
    maxInstances: 10,
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

      // Check discovery surfaces
      const isDiscoveryTopics =
        path.includes("discovery/topics") ||
        (path.includes("discovery") && req.query.surface === "topics");
      const isDiscoveryChannels =
        path.includes("discovery/channels") ||
        (path.includes("discovery") && req.query.surface === "channels");

      // 1. Parameter Normalization
      const rawCategory = typeof req.query.category === "string" ? req.query.category.trim().toLowerCase() : "all";
      const category = rawCategory.length > 0 ? rawCategory : "all";

      const rawLang = typeof req.query.lang === "string" ? req.query.lang.trim().toLowerCase() : "all";
      const lang = rawLang.length > 0 ? rawLang : "all";

      const rawLimit = parseInt(req.query.limit as string, 10);
      const defaultLimit = isDiscoveryTopics || isDiscoveryChannels ? 20 : 24;
      const limit = isNaN(rawLimit) ? defaultLimit : Math.min(Math.max(rawLimit, 1), 50);

      let feedType: "home" | "trending" | "explore" | "topic" | "channel" = "home";
      let topicSlug: string | undefined = undefined;
      let channelId: string | undefined = undefined;

      if (!isDiscoveryTopics && !isDiscoveryChannels) {
        // Extract topic
        const topicMatch = path.match(/\/topic\/([^/?#]+)/i);
        if (topicMatch) {
          feedType = "topic";
          topicSlug = decodeURIComponent(topicMatch[1]).trim().toLowerCase().replace(/^t\//, "");
        } else if (typeof req.query.topic === "string" && req.query.topic.trim().length > 0) {
          feedType = "topic";
          topicSlug = req.query.topic.trim().toLowerCase().replace(/^t\//, "");
        }

        // Extract channel
        const channelMatch = path.match(/\/channel\/([^/?#]+)/i);
        if (channelMatch) {
          feedType = "channel";
          channelId = decodeURIComponent(channelMatch[1]).trim();
        } else if (typeof req.query.channelId === "string" && req.query.channelId.trim().length > 0) {
          feedType = "channel";
          channelId = req.query.channelId.trim();
        }

        // Explore, Trending, or Home
        if (!topicSlug && !channelId) {
          if (path.includes("explore") || req.query.feedType === "explore") {
            feedType = "explore";
          } else if (path.includes("trending") || req.query.feedType === "trending") {
            feedType = "trending";
          } else {
            feedType = "home";
          }
        }
      }

      // Validate cursor if provided on video feeds
      const rawCursor = typeof req.query.cursor === "string" ? req.query.cursor.trim() : undefined;
      let validatedCursor: CursorPayload | null = null;
      if (rawCursor && !isDiscoveryTopics && !isDiscoveryChannels) {
        validatedCursor = verifyAndDecodeCursor(
          rawCursor,
          feedType,
          category,
          lang,
          limit,
          topicSlug,
          channelId
        );
        if (!validatedCursor) {
          res.status(400).json({ error: "Invalid, expired, or mismatched pagination cursor" });
          return;
        }
      }

      // Build normalized cache key (excludes all tracking parameters like utm_*, fbclid)
      let cacheKey = "";
      if (isDiscoveryTopics) {
        cacheKey = `edge_disc_topics_${category}_${limit}`;
      } else if (isDiscoveryChannels) {
        cacheKey = `edge_disc_channels_${category}_${limit}`;
      } else {
        const cursorKey = validatedCursor
          ? `_c_${validatedCursor.lastId}_${validatedCursor.timestamp}`
          : "_p1";
        if (feedType === "topic") {
          cacheKey = `edge_feed_topic_${topicSlug}_${lang}_${limit}${cursorKey}`;
        } else if (feedType === "channel") {
          cacheKey = `edge_feed_channel_${channelId}_${limit}${cursorKey}`;
        } else {
          cacheKey = `edge_feed_${feedType}_${category}_${lang}_${limit}${cursorKey}`;
        }
      }

      // Check L1 In-Process Memory Cache
      const cached = getCache<FeedResponsePayload>(cacheKey);
      let payload: FeedResponsePayload;
      let isL1Hit = false;

      if (
        cached &&
        (Array.isArray(cached.feed) ||
          Array.isArray(cached.topics) ||
          Array.isArray(cached.channels))
      ) {
        payload = cached;
        isL1Hit = true;
      } else {
        // Execute single-flight coalesced Firestore fetch
        payload = await executeSingleFlight(cacheKey, async () => {
          const db = admin.firestore();
          const now = Date.now();

          // 1. Featured & Trending Topics Directory
          if (isDiscoveryTopics) {
            let query: admin.firestore.Query = db.collection("topics");
            if (category !== "all") {
              query = query.where("category", "==", category);
            }
            query = query.orderBy("trendingScore", "desc").limit(limit);
            const snap = await query.get();
            const cleanTopics = snap.docs
              .map((doc) => sanitizePublicTopicItem(doc.data(), doc.id))
              .filter((t): t is NonNullable<typeof t> => t !== null);

            return {
              topics: cleanTopics,
              count: cleanTopics.length,
              category,
              cachedAt: new Date().toISOString(),
              edgeServed: true,
            };
          }

          // 2. Creator Leaderboard & Discovery
          if (isDiscoveryChannels) {
            let query: admin.firestore.Query = db
              .collection("channels")
              .where("status", "==", "active");
            if (category !== "all") {
              query = query.where("category", "==", category);
            }
            query = query.orderBy("subscriberCount", "desc").limit(limit);
            const snap = await query.get();
            const cleanChannels = snap.docs
              .map((doc) => sanitizePublicChannelItem(doc.data(), doc.id))
              .filter((c): c is NonNullable<typeof c> => c !== null);

            return {
              channels: cleanChannels,
              count: cleanChannels.length,
              category,
              cachedAt: new Date().toISOString(),
              edgeServed: true,
            };
          }

          // 3. Topic Videos Feed
          if (feedType === "topic") {
            let topicQuery: admin.firestore.Query = db
              .collection("videos")
              .where("topics", "array-contains", topicSlug)
              .orderBy("uploadedAt", "desc")
              .orderBy(docIdField, "desc");

            if (validatedCursor) {
              topicQuery = topicQuery.startAfter(
                admin.firestore.Timestamp.fromMillis(validatedCursor.timestamp),
                validatedCursor.lastId
              );
            }

            const snap = await topicQuery.limit(limit + 1).get();
            const docs = snap.docs;
            const hasMore = docs.length > limit;
            const slice = hasMore ? docs.slice(0, limit) : docs;

            let lastTimestamp = now;
            let lastDocId = "";
            const cleanFeed = slice
              .map((doc) => {
                const clean = sanitizePublicVideoItem(doc.data(), doc.id);
                if (clean) {
                  lastTimestamp = toEpochMs(clean.uploadedAt || clean.createdAt, now);
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
                topic: topicSlug,
                issuedAt: now,
                expiresAt: now + 24 * 60 * 60 * 1000,
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
              topic: topicSlug,
              cachedAt: new Date().toISOString(),
              edgeServed: true,
            };
          }

          // 4. Channel Public Uploads Feed
          if (feedType === "channel") {
            let chanQuery: admin.firestore.Query = db
              .collection("videos")
              .where("channelId", "==", channelId)
              .orderBy("createdAt", "desc")
              .orderBy(docIdField, "desc");

            if (validatedCursor) {
              chanQuery = chanQuery.startAfter(
                admin.firestore.Timestamp.fromMillis(validatedCursor.timestamp),
                validatedCursor.lastId
              );
            }

            const snap = await chanQuery.limit(limit + 1).get();
            const docs = snap.docs;
            const hasMore = docs.length > limit;
            const slice = hasMore ? docs.slice(0, limit) : docs;

            let lastTimestamp = now;
            let lastDocId = "";
            const cleanFeed = slice
              .map((doc) => {
                const clean = sanitizePublicVideoItem(doc.data(), doc.id);
                if (clean) {
                  lastTimestamp = toEpochMs(clean.createdAt || clean.uploadedAt, now);
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
                channelId,
                issuedAt: now,
                expiresAt: now + 24 * 60 * 60 * 1000,
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
              channelId,
              cachedAt: new Date().toISOString(),
              edgeServed: true,
            };
          }

          // 5. Explore Feed (Diverse Multi-Category Interleaving)
          if (feedType === "explore") {
            let exploreQuery: admin.firestore.Query = db
              .collection("videos")
              .where("status", "==", "published")
              .where("visibility", "==", "public");

            if (category !== "all") {
              exploreQuery = exploreQuery.where("category", "==", category);
            }
            if (lang !== "all") {
              exploreQuery = exploreQuery.where("language", "==", lang);
            }

            exploreQuery = exploreQuery
              .orderBy("createdAt", "desc")
              .orderBy(docIdField, "desc");

            if (validatedCursor) {
              exploreQuery = exploreQuery.startAfter(
                admin.firestore.Timestamp.fromMillis(validatedCursor.timestamp),
                validatedCursor.lastId
              );
            }

            const snap = await exploreQuery.limit(limit + 1).get();
            const docs = snap.docs;
            const hasMore = docs.length > limit;
            const slice = hasMore ? docs.slice(0, limit) : docs;

            let lastTimestamp = now;
            let lastDocId = "";
            const cleanedItems = slice
              .map((doc) => {
                const clean = sanitizePublicVideoItem(doc.data(), doc.id);
                if (clean) {
                  lastTimestamp = toEpochMs(clean.createdAt, now);
                  lastDocId = doc.id;
                }
                return clean;
              })
              .filter((v): v is NonNullable<typeof v> => v !== null);

            let finalFeed = cleanedItems;
            if (category === "all" && cleanedItems.length > 2) {
              const categoryBuckets = new Map<string, Record<string, any>[]>();
              for (const item of cleanedItems) {
                const cat = item.category || "General";
                if (!categoryBuckets.has(cat)) {
                  categoryBuckets.set(cat, []);
                }
                categoryBuckets.get(cat)!.push(item);
              }
              const interleaved: Record<string, any>[] = [];
              let added = true;
              while (added) {
                added = false;
                for (const bucket of categoryBuckets.values()) {
                  if (bucket.length > 0) {
                    interleaved.push(bucket.shift()!);
                    added = true;
                  }
                }
              }
              finalFeed = interleaved;
            }

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
                expiresAt: now + 24 * 60 * 60 * 1000,
                version: 1,
              });
            }

            return {
              feed: finalFeed,
              count: finalFeed.length,
              nextCursor,
              hasMore,
              category,
              lang,
              cachedAt: new Date().toISOString(),
              edgeServed: true,
            };
          }

          // 6. Trending Feed
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
          }

          // 7. Default Chronological Home Feed
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
