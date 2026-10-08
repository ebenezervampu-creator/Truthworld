import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import axios from "axios";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { createHash } from "crypto";
import { costEngine, CostEngine, CDN_RATE_CARDS } from "../pipeline/services/cost-engine";

// â”€â”€â”€ Init â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const db = admin.firestore();

const REGION = "asia-south1";

// â”€â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

type EventType =
  | "video_start"
  | "watch_ping"
  | "pause"
  | "resume"
  | "seek"
  | "complete"
  | "exit";

interface WatchEventPayload {
  videoId: string;
  channelId?: string;
  eventId?: string;
  userId: string;
  sessionId: string;
  eventType: EventType;
  position: number;   // current playback position in seconds
  duration: number;   // total video length in seconds
  prevPosition?: number; // client sends previous ping position for delta math
  issubscriber?: boolean | string;
  isNotsubscriber?: boolean | string;
  watchTimeSecondsDelta?: number | string;
  playbackQuality?: string;
  playbackRate?: number;
  trafficSource?: string;
  playerState?: string;
  isMuted?: boolean;
  volume?: number;
  deviceModel?: string;
  platform?: string;
  networkType?: string;
  language?: string;
  viewerHash?: string;
}

interface RawEvent extends WatchEventPayload {
  state: string;
  city?: string;
  country?: string;
  areaType?: string;
  issubscriber?: boolean;
  isNewsubscriber?: boolean;
  createdAt: admin.firestore.Timestamp;
}

// Per-session accumulator used during aggregation
interface SessionAcc {
  userId: string;
  videoId: string;
  state: string;
  city?: string;
  country?: string;
  areaType?: string;
  maxPosition: number;   // furthest point reached (for retention)
  duration: number;
  deltaSeconds: number;  // sum of deltas — true watch time
  started: boolean;
  completed: boolean;
  lastPingPos: number;
  issubscriber: boolean;
  isNewsubscriber: boolean;
}

// Stored in video_stats/{videoId}
interface VideoStats {
  totalViews: number;          // unique session starts
  uniqueUsers: number;
  totalWatchSeconds: number;   // sum of true delta watch time
  avgWatchSeconds: number;
  completionRate: number;      // 0â€“100
  fullWatched: number;         // sessions â‰¥ 95 %
  halfWatched: number;         // sessions â‰¥ 50 %
  under20Sec: number;          // sessions that never reached 20 s
  totalSubscribers: number;
  totalNewSubscribers: number;
  retentionCurve: number[];    // 10 buckets, each = % of sessions still watching at that decile
  updatedAt: admin.firestore.FieldValue;
}

// â”€â”€â”€ IP â†’ Indian State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Simple in-memory cache (valid for function instance lifetime ~15 min).
const geoCache = new Map<string, string>();

async function resolveState(rawIp: string): Promise<string> {
  const ip = rawIp.split(",")[0].trim();
  if (!ip || ip === "::1" || ip.startsWith("127.") || ip.startsWith("::ffff:127.")) {
    return "Unknown";
  }
  if (geoCache.has(ip)) return geoCache.get(ip)!;
  try {
    const { data } = await axios.get(`https://ipapi.co/${ip}/json/`, { timeout: 2000 });
    const state =
      data.country_code === "IN"
        ? (data.region ?? "Unknown")
        : "Other";
    geoCache.set(ip, state);
    return state;
  } catch {
    return "Unknown";
  }
}

// Anti-spam: In-memory sliding window rate-limiter (0ms, 0 Firestore reads).
// Normal playback sends ~1-2 pings/min (video_start, 60s pings, milestones). Max 30 writes per sessionId per minute.
const sessionRateMap = new Map<string, { count: number; resetAt: number }>();

function isSpam(sessionId: string): boolean {
  const now = Date.now();
  const entry = sessionRateMap.get(sessionId);

  if (!entry || now > entry.resetAt) {
    sessionRateMap.set(sessionId, { count: 1, resetAt: now + 60_000 });
    if (sessionRateMap.size > 10_000) {
      for (const [k, v] of sessionRateMap.entries()) {
        if (now > v.resetAt) sessionRateMap.delete(k);
      }
    }
    return false;
  }

  entry.count++;
  return entry.count > 30;
}

// ─── Bot Farm Defense: IP Hashing ──────────────────────────────────────────────
function hashIP(ip: string): string {
  return createHash("sha256").update(ip).digest("hex").substring(0, 16);
}

// ─── Bot Farm Defense: IP Rate Tracking ────────────────────────────────────────
// Tracks IP activity in Firestore for clustering detection.
// Returns true if the IP should be BLOCKED.
async function trackAndCheckIP(
  ipHash: string,
  videoId: string,
  isAnonymous: boolean
): Promise<{ blocked: boolean; reason?: string }> {
  if (!ipHash || ipHash === "unknown") return { blocked: false };

  const now = Date.now();
  const hourKey = new Date(now).toISOString().slice(0, 13); // "2026-10-01T09"
  const trackerDocId = `${ipHash}_${hourKey}`;
  const trackerRef = db.collection("view_ip_tracker").doc(trackerDocId);

  try {
    // Check if IP is already blocked
    const blockRef = db.collection("blocked_ips").doc(ipHash);
    const blockSnap = await blockRef.get();
    if (blockSnap.exists) {
      const blockData = blockSnap.data();
      if (blockData?.expiresAt?.toMillis?.() > now) {
        return { blocked: true, reason: "ip_blocked" };
      }
    }

    // Increment counters atomically
    const updateData: Record<string, any> = {
      ipHash,
      totalSessions: admin.firestore.FieldValue.increment(1),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      [`videoSessions.${videoId}`]: admin.firestore.FieldValue.increment(1),
    };
    if (isAnonymous) {
      updateData.anonymousSessions = admin.firestore.FieldValue.increment(1);
    }
    await trackerRef.set(updateData, { merge: true });

    // Read back to check thresholds
    const trackerSnap = await trackerRef.get();
    const trackerData = trackerSnap.data();
    if (!trackerData) return { blocked: false };

    const totalSessions = Number(trackerData.totalSessions || 0);
    const videoSessionCount = Number(trackerData.videoSessions?.[videoId] || 0);
    const anonymousSessions = Number(trackerData.anonymousSessions || 0);

    // RULE: > 500 sessions from same IP across ALL videos in 1hr → BLOCK
    if (totalSessions > 500) {
      await blockRef.set({
        ipHash,
        reason: `global_session_flood_${totalSessions}_sessions_in_1hr`,
        blockedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(now + 3600000), // 1hr block
      });
      logger.warn(`[FraudDefense] BLOCKED IP ${ipHash}: ${totalSessions} global sessions in 1hr`);
      return { blocked: true, reason: "ip_global_flood" };
    }

    // RULE: > 50 sessions from same IP watching SAME video in 1hr → BLOCK
    if (videoSessionCount > 50) {
      await blockRef.set({
        ipHash,
        reason: `video_session_cluster_${videoSessionCount}_sessions_on_${videoId}`,
        blockedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(now + 3600000),
      });
      logger.warn(`[FraudDefense] BLOCKED IP ${ipHash}: ${videoSessionCount} sessions on video ${videoId}`);
      return { blocked: true, reason: "ip_video_cluster" };
    }

    // RULE: > 20 anonymous sessions from same IP in 10 min → BLOCK
    if (isAnonymous && anonymousSessions > 20) {
      await blockRef.set({
        ipHash,
        reason: `anonymous_flood_${anonymousSessions}_sessions`,
        blockedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(now + 3600000),
      });
      logger.warn(`[FraudDefense] BLOCKED anonymous IP ${ipHash}: ${anonymousSessions} anonymous sessions`);
      return { blocked: true, reason: "anonymous_flood" };
    }

    return { blocked: false };
  } catch (err) {
    // Fail open — don't block legitimate users if tracker fails
    logger.warn("[FraudDefense] IP tracking check failed, failing open:", err);
    return { blocked: false };
  }
}

// ─── Bot Farm Defense: Concurrent Session Limiter ──────────────────────────────
// A single user should not be watching more than 3 videos simultaneously.
async function checkConcurrentSessions(userId: string): Promise<{ exceeded: boolean; activeCount: number }> {
  if (!userId || userId === "anonymous") return { exceeded: false, activeCount: 0 };

  try {
    const rtdb = admin.database();
    const activeViewersSnap = await rtdb.ref("activeViewers").once("value");
    if (!activeViewersSnap.exists()) return { exceeded: false, activeCount: 0 };

    let activeVideoCount = 0;
    const now = Date.now();
    const STALE_MS = 120_000; // 2 minutes — sessions older than this are stale

    activeViewersSnap.forEach((videoSnap) => {
      videoSnap.forEach((sessionSnap) => {
        const data = sessionSnap.val();
        if (data?.uid === userId && data?.updatedAt && (now - data.updatedAt) < STALE_MS) {
          activeVideoCount++;
        }
      });
    });

    return { exceeded: activeVideoCount > 3, activeCount: activeVideoCount };
  } catch (err) {
    logger.warn("[FraudDefense] Concurrent session check failed, failing open:", err);
    return { exceeded: false, activeCount: 0 };
  }
}

// ─── Bot Farm Defense: App Check Verification ──────────────────────────────────
// Verifies Firebase App Check token. Returns true if valid or if check is unavailable.
// Uses grace period: logs warnings but doesn't block if enforcement is disabled.
const APP_CHECK_ENFORCEMENT_ENABLED = true; // Feature flag for gradual rollout

async function verifyAppCheck(appCheckToken: string | undefined): Promise<{ valid: boolean; reason?: string }> {
  // Test environment bypass when no token is explicitly sent
  if (process.env.NODE_ENV === "test" && !appCheckToken) {
    return { valid: true };
  }

  if (!appCheckToken) {
    if (APP_CHECK_ENFORCEMENT_ENABLED) {
      return { valid: false, reason: "missing_app_check_token" };
    }
    logger.warn("[FraudDefense] Missing App Check token (enforcement disabled, allowing)");
    return { valid: true };
  }

  try {
    await admin.appCheck().verifyToken(appCheckToken);
    return { valid: true };
  } catch (err) {
    if (APP_CHECK_ENFORCEMENT_ENABLED) {
      logger.warn("[FraudDefense] Invalid App Check token:", err);
      return { valid: false, reason: "invalid_app_check_token" };
    }
    logger.warn("[FraudDefense] Invalid App Check token (enforcement disabled, allowing)");
    return { valid: true };
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// FUNCTION 1 â€” trackWatchEvent  (Gen 2 HTTP)
// POST /trackWatchEvent
// Body: WatchEventPayload
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export const trackWatchEvent = onRequest(
  {
    region: REGION,
    timeoutSeconds: 10,
    minInstances: 0,
    maxInstances: 100,
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    applySecurityHeaders(res);
    // ── CORS: Set headers on EVERY response (not just OPTIONS) ──
    // Without these on error responses, the browser blocks them as opaque
    // "Failed to fetch" errors, hiding the actual error from the client.
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");

    // Handle preflight
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
      const body = req.body as Partial<WatchEventPayload>;

      // ——— Field validation ———
      const required = ["videoId", "userId", "sessionId", "eventType", "position", "duration"] as const;
      for (const f of required) {
        if (body[f] === undefined || body[f] === null || body[f] === "") {
          res.status(400).send({ error: `Missing field: ${f}` });
          return;
        }
      }

      const position = Number(body.position);
      const duration = Number(body.duration);
      const prevPosition = body.prevPosition !== undefined ? Number(body.prevPosition) : undefined;

      if (isNaN(position) || isNaN(duration) || duration <= 0) {
        res.status(400).send({ error: "Invalid position or duration" });
        return;
      }

      // L-33: Override client-supplied userId with verified auth token
      // Prevents view count inflation by spoofing another user's ID
      const authHeader = req.headers.authorization;
      if (authHeader && authHeader.startsWith("Bearer ")) {
        try {
          const token = authHeader.split("Bearer ")[1];
          const decoded = await admin.auth().verifyIdToken(token);
          body.userId = decoded.uid; // Trust server-verified UID only
        } catch {
          // Invalid token — treat as anonymous
          body.userId = "anonymous";
        }
      } else if (body.userId !== "anonymous") {
        // No auth header but claimed a userId — reject the claim
        body.userId = "anonymous";
      }

      // ——— Ignore pings that haven't reached 3 s yet ———
      if (body.eventType === "watch_ping" && position < 3) {
        res.status(200).send({ success: true, skipped: true });
        return;
      }

      // ——— Anti-spam ———
      if (await isSpam(body.sessionId!)) {
        res.status(429).send({ error: "Rate limit" });
        return;
      }

      // ─── Bot Farm Defense Layer ──────────────────────────────────────────
      // LAYER 1: App Check — reject requests without valid app attestation
      const appCheckToken = req.headers["x-firebase-appcheck"] as string | undefined;
      const appCheckResult = await verifyAppCheck(appCheckToken);
      if (!appCheckResult.valid) {
        logger.warn(`[FraudDefense] Rejected: ${appCheckResult.reason} userId=${body.userId} videoId=${body.videoId}`);
        res.status(403).send({ error: "Request validation failed" });
        return;
      }

      // LAYER 2: IP fraud detection — track IP and block known bot IPs
      const clientIP = (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim()
        ?? req.socket.remoteAddress ?? "";
      const ipHash = (clientIP && clientIP !== "::1" && !clientIP.startsWith("127."))
        ? hashIP(clientIP) : "unknown";
      const isAnonymous = body.userId === "anonymous";
      const ipCheck = await trackAndCheckIP(ipHash, body.videoId!, isAnonymous);
      if (ipCheck.blocked) {
        logger.warn(`[FraudDefense] Blocked IP ${ipHash}: ${ipCheck.reason} videoId=${body.videoId}`);
        res.status(429).send({ error: "Rate limit" });
        return;
      }

      // LAYER 3: Concurrent session limit — max 3 simultaneous videos per user
      if (body.eventType === "video_start" && body.userId !== "anonymous") {
        const concurrentCheck = await checkConcurrentSessions(body.userId!);
        if (concurrentCheck.exceeded) {
          logger.warn(`[FraudDefense] Concurrent session limit exceeded: userId=${body.userId} active=${concurrentCheck.activeCount}`);
          res.status(429).send({ error: "Too many simultaneous streams" });
          return;
        }
      }

      // â”€â”€ Geo â”€â”€
      const rawIp =
        (req.headers["x-forwarded-for"] as string) ??
        req.socket.remoteAddress ??
        "";
      const state = await resolveState(rawIp);

      // ── Write ──
      await db.collection("watch_events").add({
        videoId: body.videoId,
        userId: body.userId,
        sessionId: body.sessionId,
        eventType: body.eventType,
        position,
        duration,
        prevPosition,
        issubscriber: body.issubscriber === true || body.issubscriber === "true",
        isNotsubscriber: body.isNotsubscriber === true || (body.isNotsubscriber === "true"),
        state,
        playbackQuality: body.playbackQuality ?? "auto",
        playbackRate: body.playbackRate ?? 1.0,
        trafficSource: body.trafficSource ?? "direct",
        playerState: body.playerState ?? "normal",
        isMuted: body.isMuted ?? false,
        volume: body.volume ?? 1.0,
        deviceModel: body.deviceModel ?? "unknown",
        platform: body.platform ?? "unknown",
        networkType: body.networkType ?? "unknown",
        language: body.language ?? "en",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // ── Maintain 'one user, one video' log ──
      // This solves the 'permission-denied' issue by using the Admin SDK
      const { userId, videoId, sessionId } = body;
      const isAuth = userId && userId !== "anonymous";
      const identityKey = isAuth ? userId : (body.viewerHash || sessionId!);
      const docId = `${identityKey}_${videoId}`;

      // Check premium subscriber status for revenue distribution (server-side, cannot be spoofed)
      let isPremiumSubscriber = false;
      if (body.userId && body.userId !== "anonymous") {
        try {
          const userSnap = await db.collection("users").doc(body.userId).get();
          isPremiumSubscriber = userSnap.exists && userSnap.data()?.isPremium === true;
        } catch (_) { /* non-blocking */ }
      }

      // Check existing session document to prevent duplicate watch time for re-watching
      const sessionRef = db.collection("watch_sessions").doc(docId);
      const sessionSnap = await sessionRef.get();
      const existingSessionData = sessionSnap.exists ? sessionSnap.data() : null;

      const currentWatchSeconds = Math.max(0, Number(existingSessionData?.watchTimeSeconds || 0));
      const isAlreadyWatched = existingSessionData?.isAlreadyWatched === true ||
        existingSessionData?.hasCompleted === true ||
        (duration > 0 && currentWatchSeconds >= duration * 0.90);

      if (isAlreadyWatched) {
        // Transparent epistemic standard: If user already watched this video, never count watch time again!
        logger.info(`[WatchTime] User ${identityKey} already watched video ${videoId}. Rejecting duplicate watch time.`);
        res.status(200).send({
          success: true,
          processed: false,
          reason: "already_watched",
          trackingId: docId,
        });
        return;
      }

      // ── LAYER 2: Heartbeat Delta Validation & Clamping (Anti-bot Watch Time Inflation) ─
      // Standard heartbeat interval is 60 seconds with 30s network buffer = max 90s legitimate delta.
      // Clamping prevents spoofed payloads from injecting millions of fake watch seconds.
      const MAX_LEGITIMATE_DELTA_SECONDS = 90;
      const rawDelta = body.watchTimeSecondsDelta ? Number(body.watchTimeSecondsDelta) : 0;
      const secondsDelta = Math.max(0, Math.round(rawDelta));
      const clampedDelta = Math.min(secondsDelta, MAX_LEGITIMATE_DELTA_SECONDS);
      const isSuspiciousHeartbeat = secondsDelta > MAX_LEGITIMATE_DELTA_SECONDS;

      // Anti-inflation & transparency: Cap delta to remaining duration so a user can NEVER contribute more than the video duration!
      const remainingSeconds = Math.max(0, duration - currentWatchSeconds);
      const effectiveDelta = Math.min(clampedDelta, remainingSeconds);
      const creditedDelta = isSuspiciousHeartbeat ? 0 : effectiveDelta;

      const newTotalWatchSeconds = currentWatchSeconds + creditedDelta;
      // Watch percentage MUST be based on true watched time, NEVER on scrub/drag position!
      const actualWatchPercentage = duration > 0 ? Math.min(1.0, newTotalWatchSeconds / duration) : 0;
      const hasWatchedEntireVideo = (newTotalWatchSeconds >= duration * 0.90);

      await sessionRef.set({
        videoId,
        userId,
        sessionId,
        channelId: body.channelId || null,
        watchTimeSeconds: newTotalWatchSeconds,
        videoDurationSeconds: duration,
        watchPercentage: actualWatchPercentage,
        hasCompleted: hasWatchedEntireVideo,
        isAlreadyWatched: hasWatchedEntireVideo,
        lastPlaybackPosition: position, // Preserves scrub position for cross-device resume ONLY
        issubscriber: body.issubscriber === true || body.issubscriber === "true",
        isNotsubscriber: body.isNotsubscriber === true || body.isNotsubscriber === "true",
        isPremiumSubscriber,
        state,
        playbackQuality: body.playbackQuality ?? "auto",
        playbackRate: body.playbackRate ?? 1.0,
        trafficSource: body.trafficSource ?? "direct",
        playerState: body.playerState ?? "normal",
        deviceModel: body.deviceModel ?? "unknown",
        platform: body.platform ?? "unknown",
        estimatedCDNEgressGB: admin.firestore.FieldValue.increment(CostEngine.estimateEgressGB(creditedDelta, body.playbackQuality ?? "auto")),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      if (isSuspiciousHeartbeat) {
        logger.warn(`[WatchTime] Suspicious heartbeat delta: ${secondsDelta}s > ${MAX_LEGITIMATE_DELTA_SECONDS}s limit. userId=${body.userId} videoId=${body.videoId}`);

        // Increment suspicious counter on session doc (non-blocking)
        try {
          await sessionRef.set(
            { suspiciousHeartbeatCount: admin.firestore.FieldValue.increment(1) },
            { merge: true }
          );

          // Flag session if > 3 suspicious pulses in a row
          const refreshedSnap = await sessionRef.get();
          const suspiciousCount = Number(refreshedSnap.data()?.suspiciousHeartbeatCount || 0);
          if (suspiciousCount >= 3) {
            await sessionRef.set({ flagged: true, flagReason: "excessive_heartbeat_delta" }, { merge: true });
            logger.warn(`[WatchTime] Session ${docId} flagged for excessive suspicious heartbeats (${suspiciousCount}).`);
          }
        } catch (flagErr) {
          logger.warn("[WatchTime] Failed to update suspicious heartbeat count:", flagErr);
        }
      }

      let targetChannelId = body.channelId;

      if (!targetChannelId && body.videoId) {
        const videoSnap = await db.collection("videos").doc(body.videoId).get();
        if (videoSnap.exists) {
          targetChannelId = videoSnap.data()?.channelId;
        }
      }

      // Security: always generate eventId server-side to prevent client bypass of idempotency.
      // Never trust body.eventId — a malicious client could supply random IDs to defeat the duplicate check.
      const eventId = `${body.sessionId}_${body.position}_${body.eventType}`;
      const eventRef = db.collection("processedWatchEvents").doc(eventId);
      let isDuplicate = false;

      // Credit channel and video watch time based strictly on valid, capped true watch delta
      if (creditedDelta > 0 && targetChannelId) {
        // Atomic Idempotency via create() without acquiring cross-document transaction locks
        try {
          await eventRef.create({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            sessionId: body.sessionId,
            videoId: body.videoId,
            channelId: targetChannelId,
            secondsDelta: creditedDelta,
          });
        } catch (createErr: any) {
          if (createErr.code === 6 || createErr.code === "already-exists" || createErr.message?.includes("ALREADY_EXISTS")) {
            isDuplicate = true;
          } else {
            logger.warn("[WatchTime] Idempotency doc check failed, proceeding best-effort:", createErr);
          }
        }

        if (!isDuplicate) {
          // Distributed 20-shard subcollection writes (eliminates single-document contention on viral videos)
          const shardId = Math.floor(Math.random() * 20).toString();

          if (body.videoId) {
            const videoShardRef = db
              .collection("videos")
              .doc(body.videoId)
              .collection("shards")
              .doc(shardId);

            videoShardRef
              .set(
                {
                  watchTimeSeconds: admin.firestore.FieldValue.increment(creditedDelta),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
              )
              .catch((err) => logger.warn("[WatchTime] Video shard write warning:", err));

            // Best-effort update on parent video document for immediate UI reads without transaction lock
            db.collection("videos")
              .doc(body.videoId)
              .update({
                totalWatchTimeSeconds: admin.firestore.FieldValue.increment(creditedDelta),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              })
              .catch(() => {});
          }

          const channelShardRef = db
            .collection("channels")
            .doc(targetChannelId)
            .collection("shards")
            .doc(shardId);

          channelShardRef
            .set(
              {
                watchTimeSeconds: admin.firestore.FieldValue.increment(creditedDelta),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            )
            .catch((err) => logger.warn("[WatchTime] Channel shard write warning:", err));

          // Best-effort update on parent channel document for immediate UI reads without transaction lock
          db.collection("channels")
            .doc(targetChannelId)
            .update({
              totalWatchTimeSeconds: admin.firestore.FieldValue.increment(creditedDelta),
              "metrics.totalWatchTimeMinutes": admin.firestore.FieldValue.increment(creditedDelta / 60),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            })
            .catch(() => {});
        }
      }

      if (isDuplicate) {
        res.status(200).send({ success: true, processed: false, reason: "duplicate_event", trackingId: docId });
        return;
      }

      res.status(200).send({ success: true, processed: true, trackingId: docId, creditedDelta });
    } catch (err) {
      logger.error("trackWatchEvent", err);
      res.status(500).send({ error: "Internal server error" });
    }
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// FUNCTION 2 â€” aggregateWatchStats  (Gen 2 scheduled)
// Runs every 60 minutes â€” INCREMENTAL (only processes new events).
//
// FIX 1: Reads only events since lastProcessedAt (not the entire collection).
// FIX 2: Views = unique session starts (eventType == "video_start").
// FIX 3: Watch time = sum of positional deltas (true time, not position value).
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export const aggregateWatchStats = onSchedule(
  {
    schedule: "every 60 minutes",
    region: REGION,
    timeoutSeconds: 540,
    memory: "1GiB",   // larger for heavy Set operations
  },
  async () => {
    logger.info("aggregateWatchStats: start");

    // â”€â”€ Read last processed cursor â”€â”€
    const metaRef = db.collection("system_meta").doc("analytics");
    const meta = await metaRef.get();
    const lastProcessedAt: admin.firestore.Timestamp =
      meta.exists && meta.data()?.lastProcessedAt
        ? meta.data()!.lastProcessedAt
        : admin.firestore.Timestamp.fromDate(new Date(0));

    const runStartedAt = admin.firestore.Timestamp.now();

    // â”€â”€ Fetch only NEW events â”€â”€
    const snapshot = await db
      .collection("watch_events")
      .where("createdAt", ">", lastProcessedAt)
      .orderBy("createdAt", "asc")
      .get();

    if (snapshot.empty) {
      logger.info("aggregateWatchStats: no new events");
      await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });
      return;
    }

    logger.info(`aggregateWatchStats: processing ${snapshot.size} new events`);

    // â”€â”€ Group events by sessionId â”€â”€
    // Each session represents one uninterrupted viewing attempt.
    const sessions = new Map<string, SessionAcc>();

    snapshot.forEach((doc) => {
      const e = doc.data() as RawEvent;
      const sid = e.sessionId;

      if (!sessions.has(sid)) {
        sessions.set(sid, {
          userId: e.userId,
          videoId: e.videoId,
          state: e.state ?? "Unknown",
          city: e.city ?? "Unknown",
          country: e.country ?? "IN",
          areaType: e.areaType ?? "unknown",
          maxPosition: 0,
          duration: e.duration,
          deltaSeconds: 0,
          started: false,
          completed: false,
          lastPingPos: 0,
          issubscriber: false,
          isNewsubscriber: false,
        });
      }

      const s = sessions.get(sid)!;

      // Keep most-recent duration in case it was trimmed
      if (e.duration > 0) s.duration = e.duration;

      // Track subscriber status (if any event in session says subscriber, they are)
      if (e.issubscriber) s.issubscriber = true;
      if (e.isNewsubscriber) s.isNewsubscriber = true;

      switch (e.eventType) {
        case "video_start":
          s.started = true;
          s.lastPingPos = 0;
          break;

        case "watch_ping":
        case "pause":
        case "exit": {
          // ── FIX 3: True watch time via delta ──
          // Client sends watchTimeSecondsDelta or prevPosition. If missing, fall back to ping interval cap.
          const clientDelta = e.watchTimeSecondsDelta !== undefined ? Number(e.watchTimeSecondsDelta) : undefined;
          let safeDelta = 0;
          if (clientDelta !== undefined && !isNaN(clientDelta)) {
            safeDelta = Math.min(Math.max(0, clientDelta), 20);
          } else {
            const prev =
              e.prevPosition !== undefined
                ? Number(e.prevPosition)
                : s.lastPingPos;
            const delta = Math.max(0, e.position - prev);
            // Cap delta at 20 s to discard tab-background / seek jumps
            safeDelta = Math.min(delta, 20);
          }
          s.deltaSeconds += safeDelta;
          s.lastPingPos = e.position;
          s.maxPosition = Math.max(s.maxPosition, e.position);
          break;
        }

        case "complete":
          // A completion is only legitimate if the session accumulated >= 85% of duration
          if (s.duration > 0 && s.deltaSeconds >= s.duration * 0.85) {
            s.completed = true;
          }
          s.lastPingPos = e.position;
          break;

        case "seek":
          // On seek: reset delta baseline without adding gap
          s.lastPingPos = e.position;
          break;
      }
    });

    // ── Accumulate into per-video stats ──
    const videoAcc = new Map<
      string,
      {
        views: number;            // unique started sessions
        watchSeconds: number;
        users: Set<string>;
        full: number;
        half: number;
        under20: number;
        // Retention: track for each of 10 deciles how many sessions reached it
        retentionBuckets: number[];
        duration: number;
        Subscribers: number;
        newSubscribers: number;
        stateTraffic: Map<string, number>;
        cityTraffic: Map<string, number>;
        countryTraffic: Map<string, number>;
        urbanViewers: number;
        ruralViewers: number;
      }
    >();

    const stateAcc = new Map<
      string,   // `${videoId}__${state}`
      { 
        views: number; 
        users: Set<string>; 
        watchSeconds: number;
        Subscribers: number;
        newSubscribers: number;
      }
    >();

    // User-video watch time tracker to prevent repeat viewings in same window from double/triple counting
    const userWatchTimeMap = new Map<string, number>();

    for (const s of sessions.values()) {
      // Transparent watch time deduplication: a user can only contribute up to the video's duration
      if (s.userId && s.userId !== "anonymous" && s.duration > 0) {
        const userVidKey = `${s.videoId}__${s.userId}`;
        const previousUserSeconds = userWatchTimeMap.get(userVidKey) || 0;
        if (previousUserSeconds >= s.duration * 0.90) {
          // User already watched this video; never count watch time again!
          s.deltaSeconds = 0;
        } else {
          const allowableSeconds = Math.max(0, s.duration - previousUserSeconds);
          const credited = Math.min(s.deltaSeconds, allowableSeconds);
          userWatchTimeMap.set(userVidKey, previousUserSeconds + credited);
          s.deltaSeconds = credited;
        }
      }

      // ── Qualified View Threshold ──
      // A session is only counted as a Qualified View if true elapsed playback reached at least 10 seconds,
      // 30% of video duration, or genuine video completion (>= 85%).
      const isQualifiedView = s.started && (
        s.deltaSeconds >= 10 || 
        (s.duration > 0 && (s.deltaSeconds / s.duration) >= 0.3) || 
        (s.completed && s.duration > 0 && s.deltaSeconds >= s.duration * 0.85)
      );

      if (!isQualifiedView) continue;

      const vid = s.videoId;

      if (!videoAcc.has(vid)) {
        videoAcc.set(vid, {
          views: 0,
          watchSeconds: 0,
          users: new Set(),
          full: 0,
          half: 0,
          under20: 0,
          retentionBuckets: new Array(10).fill(0),
          duration: s.duration,
          Subscribers: 0,
          newSubscribers: 0,
          stateTraffic: new Map(),
          cityTraffic: new Map(),
          countryTraffic: new Map(),
          urbanViewers: 0,
          ruralViewers: 0,
        });
      }

      const v = videoAcc.get(vid)!;
      v.views += 1;
      v.watchSeconds += s.deltaSeconds;
      v.users.add(s.userId);
      if (s.issubscriber) v.Subscribers += 1;
      if (s.isNewsubscriber) v.newSubscribers += 1;

      // Accumulate geographic breakdowns
      const stateVal = s.state ?? "Unknown";
      v.stateTraffic.set(stateVal, (v.stateTraffic.get(stateVal) || 0) + 1);
      if (s.city && s.city !== "Unknown") {
        v.cityTraffic.set(s.city, (v.cityTraffic.get(s.city) || 0) + 1);
      }
      const countryVal = s.country ?? "IN";
      v.countryTraffic.set(countryVal, (v.countryTraffic.get(countryVal) || 0) + 1);
      if (s.areaType === "urban") v.urbanViewers += 1;
      else if (s.areaType === "rural") v.ruralViewers += 1;

      // True watch completion and retention based on REAL watch time, NOT scrub position!
      const actualPct = s.duration > 0 ? (s.deltaSeconds / s.duration) * 100 : 0;
      const isFull = actualPct >= 90 || (s.completed && actualPct >= 85);

      if (isFull) v.full++;
      else if (actualPct >= 50) v.half++;
      if (s.deltaSeconds < 20) v.under20++;

      // Retention curve: mark which decile buckets this session reached based on actual watch percentage
      for (let i = 0; i < 10; i++) {
        const threshold = ((i + 1) / 10) * 100;
        if (actualPct >= threshold) v.retentionBuckets[i]++;
      }

      // Per-state
      const stateKey = `${vid}__${s.state}`;
      if (!stateAcc.has(stateKey)) {
        stateAcc.set(stateKey, { 
          views: 0, 
          users: new Set(), 
          watchSeconds: 0,
          Subscribers: 0,
          newSubscribers: 0,
        });
      }
      const st = stateAcc.get(stateKey)!;
      st.views += 1;
      st.users.add(s.userId);
      st.watchSeconds += s.deltaSeconds;
      if (s.issubscriber) st.Subscribers += 1;
      if (s.isNewsubscriber) st.newSubscribers += 1;
    }

    // â”€â”€ Batched writes â”€â”€
    let batch = db.batch();
    let ops = 0;

    const flush = async () => {
      if (ops > 0) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    };

    const addOp = async (ref: admin.firestore.DocumentReference, data: object, merge = true) => {
      if (ops >= 490) await flush();
      merge ? batch.set(ref, data, { merge: true }) : batch.set(ref, data);
      ops++;
    };

    // Write video_stats
    for (const [vid, acc] of videoAcc) {
      const completionRate =
        acc.views > 0 ? Math.round((acc.full / acc.views) * 100) : 0;
      const retentionCurve = acc.retentionBuckets.map((count) =>
        acc.views > 0 ? Math.round((count / acc.views) * 100) : 0
      );

      // Convert geo Maps to plain objects for Firestore
      const stateTrafficObj: Record<string, number> = {};
      acc.stateTraffic.forEach((count: number, key: string) => { stateTrafficObj[key] = count; });
      const cityTrafficObj: Record<string, number> = {};
      acc.cityTraffic.forEach((count: number, key: string) => { cityTrafficObj[key] = count; });
      const countryTrafficObj: Record<string, number> = {};
      acc.countryTraffic.forEach((count: number, key: string) => { countryTrafficObj[key] = count; });

      const statsDoc: VideoStats = {
        totalViews: acc.views,
        uniqueUsers: acc.users.size,
        totalWatchSeconds: Math.round(acc.watchSeconds),
        avgWatchSeconds: acc.views > 0 ? Math.round(acc.watchSeconds / acc.views) : 0,
        completionRate,
        fullWatched: acc.full,
        halfWatched: acc.half,
        under20Sec: acc.under20,
        totalSubscribers: acc.Subscribers,
        totalNewSubscribers: acc.newSubscribers,
        retentionCurve,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // ── Google Cloud CDN Egress Cost Attribution ──────────────────────────
      // Calculate data transfer egress for watch time served in this hourly cycle.
      let topCountry = "IN";
      let topCount = 0;
      acc.countryTraffic.forEach((count, cCode) => {
        if (count > topCount) {
          topCount = count;
          topCountry = cCode;
        }
      });

      const egressGB = CostEngine.estimateEgressGB(acc.watchSeconds, "auto");
      const cdnRegion = CostEngine.mapCountryToCDNRegion(topCountry);
      const cdnRate = CDN_RATE_CARDS[cdnRegion] ?? CDN_RATE_CARDS.default;
      const cdnCostUSD = Math.round(egressGB * cdnRate * 1000000) / 1000000;

      await addOp(db.collection("video_stats").doc(vid), {
        ...statsDoc,
        stateTraffic: stateTrafficObj,
        cityTraffic: cityTrafficObj,
        countryTraffic: countryTrafficObj,
        urbanViewers: acc.urbanViewers,
        ruralViewers: acc.ruralViewers,
        cdnMetrics: {
          periodWatchSeconds: Math.round(acc.watchSeconds),
          periodEgressGB: Math.round(egressGB * 10000) / 10000,
          periodCostUSD: cdnCostUSD,
          predominantRegion: cdnRegion,
          lastCalculatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        cumulativeCDNEgressGB: admin.firestore.FieldValue.increment(egressGB),
        cumulativeCDNCostUSD: admin.firestore.FieldValue.increment(cdnCostUSD),
      });

      // Record in CostEngine for creator and platform unit economics accounting
      costEngine.recordCDNCost(vid, "system", egressGB, cdnRegion).catch((cdnErr) => {
        logger.warn(`[WatchTime] Non-blocking CDN cost attribution failed for ${vid}:`, cdnErr);
      });
    }

    // Write video_state_stats
    for (const [key, acc] of stateAcc) {
      const [vid, state] = key.split("__");
      const ref = db
        .collection("video_state_stats")
        .doc(vid)
        .collection("states")
        .doc(state);

      await addOp(ref, {
        views: acc.views,
        uniqueUsers: acc.users.size,
        totalWatchSeconds: Math.round(acc.watchSeconds),
        totalSubscribers: acc.Subscribers,
        totalNewSubscribers: acc.newSubscribers,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await flush();

    // â”€â”€ Advance cursor â”€â”€
    await metaRef.set({ lastProcessedAt: runStartedAt }, { merge: true });

    logger.info(
      `aggregateWatchStats: done. sessions=${sessions.size} videos=${videoAcc.size}`
    );
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// FUNCTION 3 â€” cleanupOldEvents  (Gen 2 scheduled)
// Runs daily. Deletes raw watch_events older than 7 days.
// Queries by createdAt (indexed) â€” never does a full collection scan.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export const cleanupOldEvents = onSchedule(
  {
    schedule: "every 24 hours",
    region: REGION,
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  async () => {
    logger.info("cleanupOldEvents: start");

    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    // Process in pages to avoid loading millions of docs into memory at once
    let totalDeleted = 0;
    let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;

    while (true) {
      let query = db
        .collection("watch_events")
        .where("createdAt", "<", cutoff)
        .orderBy("createdAt")
        .limit(400);

      if (lastDoc) query = query.startAfter(lastDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      totalDeleted += snap.size;
      lastDoc = snap.docs[snap.docs.length - 1];

      // All pages done
      if (snap.size < 400) break;
    }

    logger.info(`cleanupOldEvents: deleted ${totalDeleted} events`);
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// FUNCTION 4 â€” getCreatorStats  (Gen 2 HTTP)
// GET /getCreatorStats?creatorId=xxx
// Returns aggregated stats across all videos owned by a creator.
// Reads only summary collections â€” never raw events.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export const getCreatorStats = onRequest(
  {
    region: REGION,
    timeoutSeconds: 15,
    maxInstances: 50,
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    applySecurityHeaders(res);
    // ── CORS headers on every response ──
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (req.method === "OPTIONS") {
      res.set("Access-Control-Max-Age", "3600");
      res.status(204).send("");
      return;
    }

    const creatorId = req.query.creatorId as string;
    if (!creatorId) {
      res.status(400).send({ error: "Missing creatorId" });
      return;
    }

    try {
      // Get all video IDs for this creator from a creator_videos index
      const videosSnap = await db
        .collection("creator_videos")
        .where("creatorId", "==", creatorId)
        .get();

      if (videosSnap.empty) {
        res.status(200).send({ creatorId, totalViews: 0, videos: [] });
        return;
      }

      const videoIds = videosSnap.docs.map((d) => d.id);

      // Fetch stats for each video in parallel (batches of 10)
      const results: VideoStats[] = [];
      for (let i = 0; i < videoIds.length; i += 10) {
        const chunk = videoIds.slice(i, i + 10);
        const statsSnaps = await Promise.all(
          chunk.map((vid) => db.collection("video_stats").doc(vid).get())
        );
        statsSnaps.forEach((s) => {
          if (s.exists) results.push(s.data() as VideoStats);
        });
      }

      // Aggregate across all videos
      const totals = results.reduce(
        (acc, s) => ({
          totalViews: acc.totalViews + s.totalViews,
          totalWatchSeconds: acc.totalWatchSeconds + s.totalWatchSeconds,
          uniqueUsers: acc.uniqueUsers + s.uniqueUsers,
          totalSubscribers: acc.totalSubscribers + (s.totalSubscribers || 0),
          totalNewSubscribers: acc.totalNewSubscribers + (s.totalNewSubscribers || 0),
        }),
        { 
          totalViews: 0, 
          totalWatchSeconds: 0, 
          uniqueUsers: 0, 
          totalSubscribers: 0, 
          totalNewSubscribers: 0 
        }
      );

      res.status(200).send({
        creatorId,
        ...totals,
        avgWatchSeconds:
          totals.totalViews > 0
            ? Math.round(totals.totalWatchSeconds / totals.totalViews)
            : 0,
        videoCount: results.length,
        videos: videoIds,
      });
    } catch (err) {
      logger.error("getCreatorStats", err);
      res.status(500).send({ error: "Internal server error" });
    }
  }
);
