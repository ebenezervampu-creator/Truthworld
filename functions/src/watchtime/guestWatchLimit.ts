import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { createHash } from "crypto";
import { applySecurityHeaders } from "../utils/securityHeaders";

const db = admin.firestore();
const REGION = "asia-south1";

/**
 * 10-minute maximum preview limit for guest / unsigned users (in seconds).
 */
export const GUEST_WATCH_LIMIT_SECONDS = 600;

export function hashIP(ip: string): string {
  if (!ip || ip === "::1" || ip.startsWith("127.") || ip.startsWith("::ffff:127.")) {
    return "local_dev_ip";
  }
  return createHash("sha256").update(ip).digest("hex").substring(0, 16);
}

/**
 * Checks whether an IP string is loopback, internal, or RFC1918/RFC4193 private range.
 */
export function isInternalOrPrivateIp(ip: string): boolean {
  if (!ip) return true;
  const clean = ip.replace(/^::ffff:/, "").trim();
  if (clean === "::1" || clean === "127.0.0.1" || clean.startsWith("127.")) return true;
  if (clean.startsWith("10.") || clean.startsWith("192.168.")) return true;
  if (clean.startsWith("169.254.")) return true;
  if (clean.startsWith("172.")) {
    const secondOctet = parseInt(clean.split(".")[1], 10);
    if (!Number.isNaN(secondOctet) && secondOctet >= 16 && secondOctet <= 31) return true;
  }
  if (
    clean.toLowerCase().startsWith("fc") ||
    clean.toLowerCase().startsWith("fd") ||
    clean.toLowerCase().startsWith("fe80")
  ) {
    return true;
  }
  return false;
}

/**
 * Checks whether an IP belongs to internal infrastructure or reverse proxy hops (e.g. Google Front End, CGNAT).
 */
export function isInfrastructureProxyIp(ip: string): boolean {
  if (!ip) return true;
  const clean = ip.replace(/^::ffff:/, "").trim();
  if (isInternalOrPrivateIp(clean)) return true;
  // Carrier-grade NAT (RFC 6598: 100.64.0.0/10)
  if (clean.startsWith("100.")) {
    const octet = parseInt(clean.split(".")[1], 10);
    if (!Number.isNaN(octet) && octet >= 64 && octet <= 127) return true;
  }
  // Google Cloud infrastructure / Load Balancer reverse proxy ranges
  if (clean.startsWith("35.191.") || clean.startsWith("130.211.") || clean.startsWith("35.190.")) return true;
  if (clean.startsWith("34.96.") || clean.startsWith("34.127.") || clean.startsWith("34.118.")) return true;
  return false;
}

/**
 * Robust, spoof-resistant client IP extractor.
 * Behind GCP / Cloud Run reverse proxies, untrusted client-supplied headers
 * (like cf-connecting-ip or fastly-client-ip) are ignored to prevent header spoofing.
 * Standard verified GCP proxy IP resolution searches X-Forwarded-For from right to left,
 * skipping internal, private, and GCP infrastructure proxy IPs to find the authentic client IP.
 */
export function getClientIp(req: any): string {
  const forwarded = req.headers?.["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) {
    const parts = forwarded.split(",").map((p: string) => p.trim()).filter(Boolean);
    if (parts.length === 1) {
      return parts[0];
    }
    // Search from right to left, skipping internal, private, and GCP infrastructure proxy IPs
    for (let i = parts.length - 1; i >= 0; i--) {
      const part = parts[i];
      if (!isInfrastructureProxyIp(part)) {
        return part;
      }
    }
    // If all on the right were infrastructure proxies, return the client IP on the left
    return parts[0];
  }
  if (typeof req.ip === "string" && req.ip.length > 0) {
    return req.ip;
  }
  return req.socket?.remoteAddress || "";
}

/**
 * Generates rolling daily partition key for guest IP limits.
 * Protects shared CGNAT, university, and public Wi-Fi IPs from permanent lockout.
 */
export function getGuestLimitDocId(ipHash: string, customDateKey?: string): string {
  const dateKey = customDateKey || new Date().toISOString().slice(0, 10);
  return `${ipHash}_${dateKey}`;
}

interface CachedGuestQuota {
  totalWatchSeconds: number;
  remainingSeconds: number;
  isLimitExceeded: boolean;
  cachedAt: number;
}

// Instance-level in-memory cache for warm Cloud Function instances (4s TTL)
// Drastically cuts Firestore read IOPS under viral spikes / millions of concurrent guest checks.
const guestQuotaMemoryCache = new Map<string, CachedGuestQuota>();
const CACHE_TTL_MS = 4000; // 4-second microcache

export function clearGuestLimitCache(): void {
  guestQuotaMemoryCache.clear();
}

/**
 * Checks if the request carries a verified, non-anonymous Firebase Auth token.
 */
export async function verifyAuthUser(req: any): Promise<{ isAuth: boolean; uid?: string }> {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    try {
      const token = authHeader.split("Bearer ")[1];
      const decoded = await admin.auth().verifyIdToken(token);
      if (decoded && decoded.uid && decoded.firebase?.sign_in_provider !== "anonymous") {
        return { isAuth: true, uid: decoded.uid };
      }
    } catch {
      // Invalid token — treated as anonymous guest
    }
  }
  return { isAuth: false };
}

/**
 * Retrieves the guest watch time stats for a given IP hash.
 * Checks warm in-memory cache, then daily date partition, falling back to legacy doc.
 */
export async function getGuestWatchUsage(ipHash: string): Promise<{
  totalWatchSeconds: number;
  remainingSeconds: number;
  isLimitExceeded: boolean;
}> {
  if (!ipHash) {
    return {
      totalWatchSeconds: 0,
      remainingSeconds: GUEST_WATCH_LIMIT_SECONDS,
      isLimitExceeded: false,
    };
  }

  const dailyDocId = getGuestLimitDocId(ipHash);

  // Fast path: Check warm instance microcache (production only, bypassed in test environment)
  const isTest = process.env.NODE_ENV === "test";
  const cached = isTest ? undefined : guestQuotaMemoryCache.get(dailyDocId);
  const now = Date.now();
  if (cached && (now - cached.cachedAt) < CACHE_TTL_MS) {
    return {
      totalWatchSeconds: cached.totalWatchSeconds,
      remainingSeconds: cached.remainingSeconds,
      isLimitExceeded: cached.isLimitExceeded,
    };
  }

  const docRef = db.collection("guest_ip_watch_limits").doc(dailyDocId);
  let snap = await docRef.get();

  // Backward compatibility: check legacy unpartitioned doc if daily doc does not exist
  if (!snap.exists) {
    const legacyRef = db.collection("guest_ip_watch_limits").doc(ipHash);
    const legacySnap = await legacyRef.get();
    if (legacySnap.exists) {
      snap = legacySnap;
    }
  }

  if (!snap.exists) {
    const freshUsage = {
      totalWatchSeconds: 0,
      remainingSeconds: GUEST_WATCH_LIMIT_SECONDS,
      isLimitExceeded: false,
    };
    if (guestQuotaMemoryCache.size > 10000) guestQuotaMemoryCache.clear();
    guestQuotaMemoryCache.set(dailyDocId, { ...freshUsage, cachedAt: now });
    return freshUsage;
  }

  const data = snap.data();
  const totalWatchSeconds = Math.max(0, Number(data?.totalWatchSeconds || 0));
  const remainingSeconds = Math.max(0, GUEST_WATCH_LIMIT_SECONDS - totalWatchSeconds);
  const isLimitExceeded = totalWatchSeconds >= GUEST_WATCH_LIMIT_SECONDS;

  const result = {
    totalWatchSeconds,
    remainingSeconds,
    isLimitExceeded,
  };

  if (guestQuotaMemoryCache.size > 10000) guestQuotaMemoryCache.clear();
  guestQuotaMemoryCache.set(dailyDocId, { ...result, cachedAt: now });

  return result;
}

/**
 * Atomically records watch time delta against a guest IP hash with date partitioning.
 * Includes NaN / Infinity sanitization, automatic TTL, and instance cache synchronization.
 */
export async function recordGuestWatchDelta(
  ipHash: string,
  deltaSeconds: number,
  videoId?: string
): Promise<{
  totalWatchSeconds: number;
  remainingSeconds: number;
  isLimitExceeded: boolean;
}> {
  if (!ipHash || typeof deltaSeconds !== "number" || !Number.isFinite(deltaSeconds) || Number.isNaN(deltaSeconds) || deltaSeconds <= 0) {
    return getGuestWatchUsage(ipHash);
  }

  const safeDelta = Math.min(Math.max(0, Math.round(deltaSeconds)), 30);
  if (safeDelta <= 0) {
    return getGuestWatchUsage(ipHash);
  }

  const dateKey = new Date().toISOString().slice(0, 10);
  const dailyDocId = getGuestLimitDocId(ipHash, dateKey);
  const docRef = db.collection("guest_ip_watch_limits").doc(dailyDocId);
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 2 * 86400 * 1000); // 48h TTL

  await docRef.set(
    {
      ipHash,
      dateKey,
      expiresAt,
      totalWatchSeconds: admin.firestore.FieldValue.increment(safeDelta),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(videoId ? { lastVideoId: videoId } : {}),
    },
    { merge: true }
  );

  const snap = await docRef.get();
  const totalWatchSeconds = Math.max(0, Number(snap.data()?.totalWatchSeconds || 0));
  const remainingSeconds = Math.max(0, GUEST_WATCH_LIMIT_SECONDS - totalWatchSeconds);
  const isLimitExceeded = totalWatchSeconds >= GUEST_WATCH_LIMIT_SECONDS;

  const result = {
    totalWatchSeconds,
    remainingSeconds,
    isLimitExceeded,
  };

  // Synchronize warm instance cache
  guestQuotaMemoryCache.set(dailyDocId, { ...result, cachedAt: Date.now() });

  return result;
}

/**
 * Cloud Function: checkGuestWatchQuota
 * Allows clients (especially in Incognito mode where local storage is cleared)
 * to verify their IP's remaining preview quota before or during playback.
 */
export const checkGuestWatchQuota = onRequest(
  {
    region: REGION,
    timeoutSeconds: 10,
    minInstances: 0,
    maxInstances: 10,
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    applySecurityHeaders(res);
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");

    if (req.method === "OPTIONS") {
      res.set("Access-Control-Max-Age", "3600");
      res.status(204).send("");
      return;
    }

    try {
      const authResult = await verifyAuthUser(req);
      if (authResult.isAuth) {
        // Authenticated users have unlimited access
        res.status(200).send({
          success: true,
          allowed: true,
          isLimitExceeded: false,
          remainingSeconds: -1,
          totalWatchSeconds: 0,
          limitSeconds: GUEST_WATCH_LIMIT_SECONDS,
          requireSignIn: false,
          isAuthenticated: true,
        });
        return;
      }

      const clientIp = getClientIp(req);
      const ipHash = hashIP(clientIp);
      const usage = await getGuestWatchUsage(ipHash);

      res.status(200).send({
        success: true,
        allowed: !usage.isLimitExceeded,
        isLimitExceeded: usage.isLimitExceeded,
        remainingSeconds: usage.remainingSeconds,
        totalWatchSeconds: usage.totalWatchSeconds,
        limitSeconds: GUEST_WATCH_LIMIT_SECONDS,
        requireSignIn: usage.isLimitExceeded,
        isAuthenticated: false,
      });
    } catch (err) {
      logger.error("[GuestWatchLimit] checkGuestWatchQuota error:", err);
      res.status(500).send({ error: "Internal server error" });
    }
  }
);

/**
 * Cloud Function: reportGuestWatchPulse
 * Lightweight heartbeat allowing clients to report unsigned playback pulses
 * so Incognito or multi-tab unsigned watching is continuously tracked by IP.
 */
export const reportGuestWatchPulse = onRequest(
  {
    region: REGION,
    timeoutSeconds: 10,
    minInstances: 0,
    maxInstances: 10,
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    applySecurityHeaders(res);
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");

    if (req.method === "OPTIONS") {
      res.set("Access-Control-Max-Age", "3600");
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).send({ error: "Method not allowed" });
      return;
    }

    try {
      const authResult = await verifyAuthUser(req);
      if (authResult.isAuth) {
        // Authenticated users have unlimited access
        res.status(200).send({
          success: true,
          allowed: true,
          isLimitExceeded: false,
          remainingSeconds: -1,
          requireSignIn: false,
          isAuthenticated: true,
        });
        return;
      }

      const body = req.body || {};
      const rawDelta = body?.deltaSeconds;
      let safeDelta = 0;
      const parsedNum = typeof rawDelta === "number" ? rawDelta : (typeof rawDelta === "string" ? parseFloat(rawDelta) : 0);
      if (Number.isFinite(parsedNum) && !Number.isNaN(parsedNum)) {
        safeDelta = Math.min(Math.max(0, Math.round(parsedNum)), 30);
      }
      const videoId = typeof body.videoId === "string" ? body.videoId : undefined;

      const clientIp = getClientIp(req);
      const ipHash = hashIP(clientIp);

      const usage = await recordGuestWatchDelta(ipHash, safeDelta, videoId);

      res.status(200).send({
        success: true,
        allowed: !usage.isLimitExceeded,
        isLimitExceeded: usage.isLimitExceeded,
        remainingSeconds: usage.remainingSeconds,
        totalWatchSeconds: usage.totalWatchSeconds,
        limitSeconds: GUEST_WATCH_LIMIT_SECONDS,
        requireSignIn: usage.isLimitExceeded,
        isAuthenticated: false,
      });
    } catch (err) {
      logger.error("[GuestWatchLimit] reportGuestWatchPulse error:", err);
      res.status(500).send({ error: "Internal server error" });
    }
  }
);
