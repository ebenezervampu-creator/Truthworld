import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import axios from "axios";

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

// â”€â”€â”€ Anti-spam â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Max 5 raw writes per sessionId per minute.
async function isSpam(sessionId: string): Promise<boolean> {
  const oneMinAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 60_000)
  );
  const snap = await db
    .collection("watch_events")
    .where("sessionId", "==", sessionId)
    .where("createdAt", ">=", oneMinAgo)
    .limit(6)
    .get();
  return snap.size >= 5;
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
    // Explicit CORS handling for preflight
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
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
      });

      // ── Maintain 'one user, one video' log ──
      // This solves the 'permission-denied' issue by using the Admin SDK
      const { userId, videoId, sessionId } = body;
      const isAuth = userId && userId !== "anonymous";
      const docId = isAuth ? `${userId}_${videoId}` : sessionId!;

      await db.collection("watch_sessions").doc(docId).set({
        videoId,
        userId,
        sessionId,
        watchTimeSeconds: admin.firestore.FieldValue.increment(body.watchTimeSecondsDelta ? Number(body.watchTimeSecondsDelta) : 0),
        videoDurationSeconds: duration,
        watchPercentage: Math.min(1.0, position / duration),
        issubscriber: body.issubscriber === true || body.issubscriber === "true",
        isNotsubscriber: body.isNotsubscriber === true || body.isNotsubscriber === "true",
        state,
        playbackQuality: body.playbackQuality ?? "auto",
        playbackRate: body.playbackRate ?? 1.0,
        trafficSource: body.trafficSource ?? "direct",
        playerState: body.playerState ?? "normal",
        deviceModel: body.deviceModel ?? "unknown",
        platform: body.platform ?? "unknown",
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // Transactional Idempotency & Real-Time Channel Watch Time Increment
      const secondsDelta = body.watchTimeSecondsDelta ? Math.max(0, Math.round(Number(body.watchTimeSecondsDelta))) : 0;
      let targetChannelId = body.channelId;

      if (!targetChannelId && body.videoId) {
        const videoSnap = await db.collection("videos").doc(body.videoId).get();
        if (videoSnap.exists) {
          targetChannelId = videoSnap.data()?.channelId;
        }
      }

      const eventId = body.eventId || `${body.sessionId}_${body.position}_${body.eventType}`;
      const eventRef = db.collection("processedWatchEvents").doc(eventId);
      let isDuplicate = false;

      if (secondsDelta > 0 && targetChannelId) {
        const channelRef = db.collection("channels").doc(targetChannelId);

        await db.runTransaction(async (transaction) => {
          const eventSnap = await transaction.get(eventRef);
          if (eventSnap.exists) {
            isDuplicate = true;
            return;
          }

          transaction.set(eventRef, {
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            sessionId: body.sessionId,
            videoId: body.videoId,
            channelId: targetChannelId,
            secondsDelta,
          });

          transaction.set(
            channelRef,
            {
              totalWatchTimeSeconds: admin.firestore.FieldValue.increment(secondsDelta),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        });
      }

      if (isDuplicate) {
        res.status(200).send({ success: true, processed: false, reason: "duplicate_event", trackingId: docId });
        return;
      }

      res.status(200).send({ success: true, processed: true, trackingId: docId });
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
          // â”€â”€ FIX 3: True watch time via delta â”€â”€
          // Client sends prevPosition. If missing, fall back to ping interval cap.
          const prev =
            e.prevPosition !== undefined
              ? Number(e.prevPosition)
              : s.lastPingPos;
          const delta = Math.max(0, e.position - prev);
          // Cap delta at 20 s to discard tab-background / seek jumps
          const safeDelta = Math.min(delta, 20);
          s.deltaSeconds += safeDelta;
          s.lastPingPos = e.position;
          s.maxPosition = Math.max(s.maxPosition, e.position);
          break;
        }

        case "complete":
          s.completed = true;
          s.maxPosition = e.duration;
          // Add final segment
          const finalDelta = Math.max(0, e.duration - s.lastPingPos);
          s.deltaSeconds += Math.min(finalDelta, 20);
          break;

        case "seek":
          // On seek: reset delta baseline without counting gap
          s.lastPingPos = e.position;
          s.maxPosition = Math.max(s.maxPosition, e.position);
          break;
      }
    });

    // â”€â”€ Accumulate into per-video stats â”€â”€
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

    for (const s of sessions.values()) {
      // ── Qualified View Threshold ──
      // A session is only counted as a Qualified View if playback reached at least 10 seconds,
      // 30% of video duration, or video completion.
      const isQualifiedView = s.started && (
        s.deltaSeconds >= 10 || 
        (s.duration > 0 && (s.deltaSeconds / s.duration) >= 0.3) || 
        s.completed
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

      const pct = s.duration > 0 ? (s.maxPosition / s.duration) * 100 : 0;

      if (pct >= 95 || s.completed) v.full++;
      else if (pct >= 50) v.half++;
      if (s.maxPosition < 20) v.under20++;

      // Retention curve: mark which decile buckets this session reached
      for (let i = 0; i < 10; i++) {
        const threshold = ((i + 1) / 10) * 100;
        if (pct >= threshold) v.retentionBuckets[i]++;
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

      await addOp(db.collection("video_stats").doc(vid), {
        ...statsDoc,
        stateTraffic: stateTrafficObj,
        cityTraffic: cityTrafficObj,
        countryTraffic: countryTrafficObj,
        urbanViewers: acc.urbanViewers,
        ruralViewers: acc.ruralViewers,
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
