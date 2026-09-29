import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { TYPE_REVENUE_SHARE } from "../economy/types";

const REGION = "asia-south1";
const CREATOR_SHARE_RATE = TYPE_REVENUE_SHARE.standard.ads; // 0.70
const PLATFORM_SHARE_RATE = 1 - CREATOR_SHARE_RATE; // 0.30

// Default pricing rates (industry standard IAB India CPM/CPV/CPC baselines)
const DEFAULT_CPM_INR = 15.0;   // ₹15 per 1000 display impressions → ₹0.015 each
const DEFAULT_CPV_INR = 0.50;   // ₹0.50 per qualified video view (30s+)
const DEFAULT_CPC_INR = 2.00;   // ₹2.00 per click

// Anti-abuse: max impressions per user per campaign per 24h
const MAX_IMPRESSIONS_PER_USER_PER_DAY = 10;
// IP rate limiting: max 50 settlement calls per public IP per hour
const MAX_IMPRESSIONS_PER_IP_PER_HOUR = 50;
// Subnet clustering: max 20 distinct users from same /24 subnet per campaign per hour
const MAX_USERS_PER_SUBNET_PER_CAMPAIGN_PER_HOUR = 20;

/**
 * Resolves the per-event gross charge in INR based on charge model.
 * Reads rates from the campaign document, falls back to platform defaults.
 */
function resolveChargeINR(
  chargeModel: "cpm" | "cpv" | "cpc",
  campaignData: admin.firestore.DocumentData
): number {
  if (chargeModel === "cpm") {
    // CPM = cost per 1000 impressions; per-impression = CPM / 1000
    const cpm = Number(campaignData.cpmRate || DEFAULT_CPM_INR);
    return cpm / 1000;
  }
  if (chargeModel === "cpv") {
    return Number(campaignData.cpvRate || DEFAULT_CPV_INR);
  }
  if (chargeModel === "cpc") {
    return Number(campaignData.cpcRate || DEFAULT_CPC_INR);
  }
  return DEFAULT_CPM_INR / 1000;
}

// ────────────────────────────────────────────────────────────────────────────
// EXPORT 1: recordAdImpression — Real-time atomic settlement
// Called from Flutter when a qualified ad impression/click is served.
// Runs a Firestore transaction: deducts advertiser budget → credits channel.
// ────────────────────────────────────────────────────────────────────────────
export const recordAdImpression = onCall(
  { region: REGION, memory: "256MiB", enforceAppCheck: false },
  async (request) => {
    const userId = request.auth?.uid ?? "guest";

    const {
      campaignId,
      channelId,   // context channel where ad was served (empty for platform-wide)
      videoId,     // specific video where ad was served
      adType,      // "homepage" | "scroll" | "skippable" | "comment"
      chargeModel, // "cpm" | "cpv" | "cpc"
    } = (request.data ?? {}) as {
      campaignId?: string;
      channelId?: string;
      videoId?: string;
      adType?: string;
      chargeModel?: string;
    };

    if (!campaignId) {
      throw new HttpsError("invalid-argument", "campaignId is required.");
    }

    const validChargeModel = (["cpm", "cpv", "cpc"].includes(chargeModel ?? "") ? chargeModel : "cpm") as "cpm" | "cpv" | "cpc";

    const db = admin.firestore();
    const campaignRef = db.collection("ad_campaigns").doc(campaignId);
    const month = new Date().toISOString().slice(0, 7); // YYYY-MM

    // ── LAYER 1: IP-based Rate Limiting ──────────────────────────────────────
    // Caps impression settlements at 50 per public IP per hour across all traffic (including guests).
    const rawIp: string =
      (request.rawRequest?.headers?.["x-forwarded-for"] as string)?.split(",")?.[0]?.trim() ||
      (request.rawRequest?.ip as string) ||
      "unknown";
    // Hash IP to avoid storing raw PII in Firestore
    const ipHash = Buffer.from(rawIp).toString("base64").replace(/[^a-zA-Z0-9]/g, "").slice(0, 24);
    const hourKey = new Date().toISOString().slice(0, 13); // "2026-09-23T14"

    if (rawIp !== "unknown") {
      const ipLimitRef = db.collection("ad_impression_ip_limits").doc(`${ipHash}_${hourKey}`);
      const ipLimitSnap = await ipLimitRef.get();
      const ipCount = ipLimitSnap.exists ? Number(ipLimitSnap.data()?.count ?? 0) : 0;

      if (ipCount >= MAX_IMPRESSIONS_PER_IP_PER_HOUR) {
        logger.warn(`[AdRevenue] IP rate limit hit: ipHash=${ipHash} count=${ipCount} campaignId=${campaignId}`);
        return { settled: false, reason: "ip_rate_limit_exceeded" };
      }

      // Increment IP counter (non-blocking — runs outside transaction to avoid contention)
      await ipLimitRef.set(
        {
          count: admin.firestore.FieldValue.increment(1),
          ipHash,
          hourKey,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    // ── LAYER 5: Subnet Clustering Detection ─────────────────────────────────
    // Detects click farms that split across a /24 subnet (e.g. 192.168.1.*).
    let suppressChannelCredit = false;
    if (rawIp !== "unknown" && validChargeModel !== "cpc") {
      const subnetPrefix = rawIp.includes(".")
        ? rawIp.split(".").slice(0, 3).join(".")
        : rawIp.slice(0, 6);
      const subnetHash = Buffer.from(subnetPrefix).toString("base64").replace(/[^a-zA-Z0-9]/g, "").slice(0, 16);
      const subnetKey = `${subnetHash}_${campaignId}_${hourKey}`;
      const subnetRef = db.collection("ad_impression_subnet_counts").doc(subnetKey);
      const subnetSnap = await subnetRef.get();
      const subnetData = subnetSnap.exists ? subnetSnap.data()! : { userIds: [], count: 0 };
      const subnetUserIds: string[] = Array.isArray(subnetData.userIds) ? subnetData.userIds : [];

      const clientIdentifier = userId !== "guest" ? userId : `guest_${ipHash}`;
      if (!subnetUserIds.includes(clientIdentifier)) {
        const newUserIds = [...subnetUserIds, clientIdentifier].slice(-50); // cap list size
        await subnetRef.set(
          {
            count: admin.firestore.FieldValue.increment(1),
            userIds: newUserIds,
            subnetHash,
            campaignId,
            hourKey,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        if (newUserIds.length > MAX_USERS_PER_SUBNET_PER_CAMPAIGN_PER_HOUR) {
          logger.warn(`[AdRevenue] Subnet cluster detected: subnet=${subnetHash} users=${newUserIds.length} campaign=${campaignId}. Suppressing channel credit.`);
          suppressChannelCredit = true;
        }
      } else if (subnetUserIds.length > MAX_USERS_PER_SUBNET_PER_CAMPAIGN_PER_HOUR) {
        suppressChannelCredit = true;
      }
    }

    // Anti-abuse check: rate-limit per user (or IP for guests) per campaign per day
    const userLimitKey = userId !== "guest" ? userId : `ip_${ipHash}`;
    const abuseKey = `${userLimitKey}_${campaignId}_${new Date().toISOString().slice(0, 10)}`;
    const abuseRef = db.collection("ad_impression_ratelimits").doc(abuseKey);

    try {
      const result = await db.runTransaction(async (transaction) => {
        // 1. Read campaign
        const campaignSnap = await transaction.get(campaignRef);
        if (!campaignSnap.exists) {
          throw new HttpsError("not-found", "Ad campaign not found.");
        }
        const campaignData = campaignSnap.data()!;

        // 2. Verify campaign is active AND verified paid
        if (campaignData.status !== "active" || campaignData.isPaid !== true) {
          logger.warn(`[AdRevenue] Campaign ${campaignId} rejected: status=${campaignData.status}, isPaid=${campaignData.isPaid}`);
          return { settled: false, reason: "campaign_not_active_or_unpaid" };
        }

        // 3. Rate limit check
        const abuseSnap = await transaction.get(abuseRef);
        const dailyCount = abuseSnap.exists ? Number(abuseSnap.data()?.count ?? 0) : 0;
        if (dailyCount >= MAX_IMPRESSIONS_PER_USER_PER_DAY) {
          return { settled: false, reason: "rate_limit_exceeded" };
        }

        // 4. Resolve Channel details (ALL READS BEFORE ANY WRITES)
        const resolvedChannelId = channelId?.trim() || "";
        let channelOwnerId = "";
        let isCustomChannel = false;
        let channelRef: admin.firestore.DocumentReference | null = null;
        if (resolvedChannelId) {
          channelRef = db.collection("channels").doc(resolvedChannelId);
          const chSnap = await transaction.get(channelRef);
          if (chSnap.exists) {
            const chData = chSnap.data() || {};
            channelOwnerId = chData.ownerId || chData.userId || "";
            isCustomChannel = chData.type === "custom" || chData.channelType === "custom";
          }

          // Anti-fraud: Verify video belongs to this channel if videoId provided
          const trimmedVideoId = videoId?.trim();
          if (trimmedVideoId) {
            const videoSnap = await transaction.get(db.collection("videos").doc(trimmedVideoId));
            if (videoSnap.exists) {
              const vData = videoSnap.data() || {};
              const actualChannelId = vData.channelId || vData.creatorChannelId;
              if (actualChannelId && actualChannelId !== resolvedChannelId) {
                logger.warn(`[AdRevenue] Channel attribution mismatch: video ${trimmedVideoId} belongs to ${actualChannelId} but claim was for ${resolvedChannelId}`);
                suppressChannelCredit = true;
              }
            } else {
              logger.warn(`[AdRevenue] Claimed video ${trimmedVideoId} does not exist. Suppressing channel credit.`);
              suppressChannelCredit = true;
            }
          } else if (adType !== "homepage" && resolvedChannelId) {
            // For video player ad formats, a verified videoId is mandatory for channel credit
            logger.warn(`[AdRevenue] Missing videoId for adType ${adType} on channel ${resolvedChannelId}. Suppressing channel credit.`);
            suppressChannelCredit = true;
          }

          // Anti-fraud: Suppress channel credit if channel owner is watching/clicking their own ads
          if (channelOwnerId && userId !== "guest" && channelOwnerId === userId) {
            logger.warn(`[AdRevenue] Self-click/view fraud detected: owner ${userId} viewing ads on channel ${resolvedChannelId}. Suppressing channel credit.`);
            suppressChannelCredit = true;
          }
        }

        // 5. Calculate charge & split based on channel type
        const grossChargeINR = resolveChargeINR(validChargeModel, campaignData);
        const creatorShareRate = isCustomChannel ? TYPE_REVENUE_SHARE.custom.ads : CREATOR_SHARE_RATE;
        const platformShareRate = isCustomChannel ? 0 : PLATFORM_SHARE_RATE;
        const channelShareINR = Math.round(grossChargeINR * creatorShareRate * 10000) / 10000;
        const platformShareINR = Math.round(grossChargeINR * platformShareRate * 10000) / 10000;

        // 6. Check budget
        const budgetAmount = Number(campaignData.budgetAmount || 0);
        const spentAmount = Number(campaignData.spentAmount || 0);
        const remaining = budgetAmount - spentAmount;

        if (remaining <= 0) {
          // Auto-pause exhausted campaign
          transaction.update(campaignRef, { status: "paused", updatedAt: admin.firestore.FieldValue.serverTimestamp() });
          return { settled: false, reason: "budget_exhausted" };
        }

        const willExhaust = remaining - grossChargeINR <= 0;

        // 7. Deduct from campaign.spentAmount + increment impressions/clicks (ALL WRITES BEGIN)
        const campaignUpdate: Record<string, unknown> = {
          spentAmount: admin.firestore.FieldValue.increment(grossChargeINR),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (validChargeModel === "cpc") {
          campaignUpdate.clicks = admin.firestore.FieldValue.increment(1);
        } else {
          campaignUpdate.impressions = admin.firestore.FieldValue.increment(1);
        }
        if (willExhaust) {
          campaignUpdate.status = "paused";
          campaignUpdate.pausedReason = "budget_exhausted";
        }
        transaction.update(campaignRef, campaignUpdate);

        // 8. Credit channel adsRevenueTotal (only if a valid channel is provided)
        if (resolvedChannelId && channelRef && !suppressChannelCredit) {
          transaction.set(
            channelRef,
            {
              adsRevenueTotal: admin.firestore.FieldValue.increment(channelShareINR),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }

        // 9. Write impression event (audit trail)
        const impressionId = `${campaignId}_${userId}_${Date.now()}`;
        const impressionRef = db.collection("ad_impression_events").doc(impressionId);
        const advertiserUserId = campaignData.userId || "";

        transaction.set(impressionRef, {
          id: impressionId,
          campaignId,
          advertiserUserId,
          channelId: resolvedChannelId,
          channelOwnerId,
          adType: adType || "homepage",
          chargeModel: validChargeModel,
          grossChargeINR: Math.round(grossChargeINR * 10000) / 10000,
          channelShareINR,
          platformShareINR,
          userId: userId === "guest" ? "" : userId,
          month,
          clusterSuppressed: suppressChannelCredit,
          servedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 9. Increment rate-limit counter
        if (userId !== "guest") {
          transaction.set(
            abuseRef,
            {
              count: admin.firestore.FieldValue.increment(1),
              expiresAt: admin.firestore.Timestamp.fromDate(
                new Date(Date.now() + 24 * 60 * 60 * 1000)
              ),
            },
            { merge: true }
          );
        }

        return {
          settled: true,
          impressionId,
          grossChargeINR: Math.round(grossChargeINR * 10000) / 10000,
          channelShareINR,
          platformShareINR,
          campaignPaused: willExhaust,
        };
      });

      return result;
    } catch (err: unknown) {
      if (err instanceof HttpsError) throw err;
      logger.error("[recordAdImpression] Transaction failed:", err);
      throw new HttpsError("internal", "Failed to settle ad impression.");
    }
  }
);

// ────────────────────────────────────────────────────────────────────────────
// EXPORT 2: getAdRevenueBreakdown — Creator-facing breakdown
// Returns a channel's monthly ad revenue: impressions served, total earned, RPM.
// ────────────────────────────────────────────────────────────────────────────
export const getAdRevenueBreakdown = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId, month } = (request.data ?? {}) as { channelId?: string; month?: string };
    if (!channelId || !month) {
      throw new HttpsError("invalid-argument", "channelId and month are required.");
    }

    const db = admin.firestore();

    // Verify channel ownership
    const channelDoc = await db.collection("channels").doc(channelId).get();
    if (!channelDoc.exists || channelDoc.data()?.ownerId !== userId) {
      throw new HttpsError("permission-denied", "You do not own this channel.");
    }

    try {
      const eventsSnap = await db.collection("ad_impression_events")
        .where("channelId", "==", channelId)
        .where("month", "==", month)
        .get();

      const events = eventsSnap.docs.map(d => d.data());
      const totalImpressions = events.filter(e => e.chargeModel !== "cpc").length;
      const totalClicks = events.filter(e => e.chargeModel === "cpc").length;
      const totalChannelShareINR = events.reduce((s, e) => s + Number(e.channelShareINR || 0), 0);
      const totalGrossINR = events.reduce((s, e) => s + Number(e.grossChargeINR || 0), 0);

      // RPM = (revenue / impressions) * 1000
      const rpm = totalImpressions > 0 ? (totalChannelShareINR / totalImpressions) * 1000 : 0;

      const byAdType: Record<string, number> = {};
      for (const e of events) {
        const t = String(e.adType || "unknown");
        byAdType[t] = (byAdType[t] ?? 0) + Number(e.channelShareINR || 0);
      }

      const chData = channelDoc.data() || {};
      const isCustomChannel = chData.type === "custom" || chData.channelType === "custom";

      return {
        channelId,
        month,
        totalImpressions,
        totalClicks,
        totalChannelShareINR: Math.round(totalChannelShareINR * 100) / 100,
        totalGrossINR: Math.round(totalGrossINR * 100) / 100,
        rpmINR: Math.round(rpm * 100) / 100,
        creatorSharePercent: (isCustomChannel ? 1.00 : CREATOR_SHARE_RATE) * 100,
        platformSharePercent: (isCustomChannel ? 0.00 : PLATFORM_SHARE_RATE) * 100,
        byAdType,
        eventCount: events.length,
      };
    } catch (err) {
      logger.error("[getAdRevenueBreakdown] Error:", err);
      throw new HttpsError("internal", "Failed to fetch ad revenue breakdown.");
    }
  }
);

// ────────────────────────────────────────────────────────────────────────────
// EXPORT 3: getAdImpressionAudit — Admin/Advertiser transparency
// Returns impression events for a campaign (paginated, max 500 per call).
// ────────────────────────────────────────────────────────────────────────────
export const getAdImpressionAudit = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const db = admin.firestore();

    const { campaignId, month } = (request.data ?? {}) as { campaignId?: string; month?: string };
    if (!campaignId) throw new HttpsError("invalid-argument", "campaignId is required.");

    // Verify: requester owns the campaign OR is admin
    const campaignDoc = await db.collection("ad_campaigns").doc(campaignId).get();
    if (!campaignDoc.exists) throw new HttpsError("not-found", "Campaign not found.");

    const campaignData = campaignDoc.data()!;
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data() || {};
    const isAdmin = request.auth?.token?.admin === true || userData.role === "admin" || userData.role === "superadmin";

    if (campaignData.userId !== userId && !isAdmin) {
      throw new HttpsError("permission-denied", "You do not own this campaign.");
    }

    try {
      let query = db.collection("ad_impression_events")
        .where("campaignId", "==", campaignId)
        .orderBy("servedAt", "desc")
        .limit(500);

      if (month) {
        query = db.collection("ad_impression_events")
          .where("campaignId", "==", campaignId)
          .where("month", "==", month)
          .orderBy("servedAt", "desc")
          .limit(500);
      }

      const snap = await query.get();
      const events = snap.docs.map(d => {
        const data = d.data();
        return {
          id: data.id,
          channelId: data.channelId,
          adType: data.adType,
          chargeModel: data.chargeModel,
          grossChargeINR: data.grossChargeINR,
          channelShareINR: data.channelShareINR,
          platformShareINR: data.platformShareINR,
          month: data.month,
          servedAt: data.servedAt,
          // userId intentionally OMITTED for viewer privacy
        };
      });

      const totalGross = events.reduce((s, e) => s + Number(e.grossChargeINR || 0), 0);
      const totalChannelShare = events.reduce((s, e) => s + Number(e.channelShareINR || 0), 0);

      return {
        campaignId,
        month: month || "all",
        eventCount: events.length,
        totalGrossINR: Math.round(totalGross * 100) / 100,
        totalChannelShareINR: Math.round(totalChannelShare * 100) / 100,
        events,
      };
    } catch (err) {
      logger.error("[getAdImpressionAudit] Error:", err);
      throw new HttpsError("internal", "Failed to fetch impression audit.");
    }
  }
);
