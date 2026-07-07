/**
 * 🛡️ HYBRID RATE LIMITING MIDDLEWARE FOR CLOUD FUNCTIONS
 *
 * Performance-optimized rate limiter combining zero-cost local sliding window checks
 * with transaction-safe distributed Firestore tracking.
 *
 * Design:
 *   - Layer 1 (Local Map): Check instance memory first (0ms overhead, completely free).
 *   - Layer 2 (Distributed Firestore): If local hits are significant (>= 40% of limit),
 *     synchronize counts under `/rate_limits/{ip}_{minute_timestamp}` via Firestore Transaction.
 *   - Billing Safety: Standard traffic (< 40% of limits) triggers 0% database reads/writes.
 *   - Autocleanup: Documents are stored with a 10-minute expireAt TTL field.
 */

import * as admin from "firebase-admin";
import type { Request } from "firebase-functions/v2/https";

// Firebase Functions uses express under the hood
type Response = {
  set: (key: string, value: string) => void;
  status: (code: number) => { json: (body: any) => void; send: (body: any) => void };
};

interface RateLimitConfig {
  /** Time window in milliseconds (default: 60000 = 1 minute) */
  windowMs?: number;
  /** Max requests per IP within the window (default: 60) */
  maxRequests?: number;
  /** Message returned on 429 (default: "Too many requests") */
  message?: string;
}

interface WindowEntry {
  timestamps: number[];
  lastCleanup: number;
}

/**
 * Creates an asynchronous hybrid rate limiter function.
 * Returns a Promise that resolves to `true` if rate-limited, `false` if OK to proceed.
 */
export function createRateLimiter(config: RateLimitConfig = {}) {
  const {
    windowMs = 60_000,
    maxRequests = 60,
    message = "Too many requests, please try again later",
  } = config;

  const store = new Map<string, WindowEntry>();

  // Periodic cleanup of stale IPs (every 5 minutes)
  let lastGlobalCleanup = Date.now();
  const CLEANUP_INTERVAL = 5 * 60_000;

  function getClientIp(req: Request): string {
    const forwarded = req.headers["x-forwarded-for"];
    if (typeof forwarded === "string") return forwarded.split(",")[0].trim();
    if (Array.isArray(forwarded) && forwarded.length > 0) return forwarded[0];
    return req.ip || "unknown";
  }

  return async function rateLimitCheck(req: Request, res: Response): Promise<boolean> {
    // Skip preflight
    if (req.method === "OPTIONS") return false;

    const now = Date.now();
    const ip = getClientIp(req);

    // Global cleanup pass
    if (now - lastGlobalCleanup > CLEANUP_INTERVAL) {
      lastGlobalCleanup = now;
      for (const [key, entry] of store) {
        if (now - entry.lastCleanup > windowMs * 2) {
          store.delete(key);
        }
      }
    }

    // ─── LAYER 1: In-Memory Sliding Window (0ms, Local check) ───
    let entry = store.get(ip);
    if (!entry) {
      entry = { timestamps: [], lastCleanup: now };
      store.set(ip, entry);
    }

    const windowStart = now - windowMs;
    entry.timestamps = entry.timestamps.filter((t) => t > windowStart);
    entry.lastCleanup = now;

    if (entry.timestamps.length >= maxRequests) {
      // Local instance limit reached synchronously
      const retryAfterSec = Math.ceil(windowMs / 1000);
      res.set("Retry-After", String(retryAfterSec));
      res.status(429).json({
        error: `${message} (Local)`,
        retryAfterSeconds: retryAfterSec,
      });
      return true;
    }

    entry.timestamps.push(now);

    // ─── LAYER 2: Distributed Firestore Counter (Instance Coordination) ───
    // Billing Guard: Skip database hits entirely if local rate is well below bounds (e.g. < 40%)
    const firestoreThreshold = Math.max(1, Math.ceil(maxRequests * 0.4));
    if (entry.timestamps.length >= firestoreThreshold) {
      try {
        const db = admin.firestore();
        const sanitizedIp = ip.replace(/[^a-zA-Z0-9-._]/g, "_");
        const truncatedWindow = Math.floor(now / windowMs) * windowMs;
        const docRef = db.collection("rate_limits").doc(`${sanitizedIp}_${truncatedWindow}`);

        const limitExceeded = await db.runTransaction(async (transaction) => {
          const doc = await transaction.get(docRef);
          const currentCount = doc.exists ? (doc.data()?.count || 0) : 0;

          if (currentCount >= maxRequests) {
            return true;
          }

          // Increment and set TTL expireAt (10 minute lifecycle)
          const ttl = new Date(now + 10 * 60 * 1000);
          transaction.set(docRef, {
            count: currentCount + 1,
            ip,
            windowStart: truncatedWindow,
            expireAt: ttl
          }, { merge: true });

          return false;
        });

        if (limitExceeded) {
          const retryAfterSec = Math.ceil(windowMs / 1000);
          res.set("Retry-After", String(retryAfterSec));
          res.status(429).json({
            error: `${message} (Distributed)`,
            retryAfterSeconds: retryAfterSec,
          });
          return true; // Exceeded limit
        }
      } catch (err) {
        // Fallback gracefully to local Map tracking if Firestore fails or is offline
        console.error("[RateLimiter] Distributed window sync failed, falling back to local memory map:", err);
      }
    }

    // Add standard rate limit headers
    res.set("X-RateLimit-Limit", String(maxRequests));
    res.set("X-RateLimit-Remaining", String(Math.max(0, maxRequests - entry.timestamps.length)));
    res.set("X-RateLimit-Reset", String(Math.ceil((windowStart + windowMs) / 1000)));

    return false;
  };
}

// ─── Pre-built limiters for common use cases ─────────────────────────────────

/** Standard limiter: 60 requests per minute per IP */
export const standardLimiter = createRateLimiter({
  windowMs: 60_000,
  maxRequests: 60,
});

/** Strict limiter: 10 requests per minute per IP (write-heavy endpoints) */
export const strictLimiter = createRateLimiter({
  windowMs: 60_000,
  maxRequests: 10,
  message: "Rate limit exceeded for this action",
});

/** Relaxed limiter: 120 requests per minute per IP (public read endpoints) */
export const relaxedLimiter = createRateLimiter({
  windowMs: 60_000,
  maxRequests: 120,
});
