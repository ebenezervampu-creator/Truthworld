import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { PremiumRevenueAllocation, PremiumDistributionRun, TYPE_REVENUE_SHARE } from "./types";

const REGION = "asia-south1";
const CREATOR_SHARE_RATE = TYPE_REVENUE_SHARE.standard.premiumSubs; // 0.70
const PLATFORM_SHARE_RATE = 1 - CREATOR_SHARE_RATE; // 0.30

// Minimum watch seconds to qualify a channel for an allocation from this subscriber
const MIN_WATCH_SECONDS = 10;

// Monthly pro-rate denominator
const BILLING_DAYS = 30;

/**
 * Helper: returns YYYY-MM string for the previous calendar month in IST.
 */
function getPreviousBillingMonth(): string {
  const now = new Date();
  // Convert to IST (UTC+5:30)
  const istOffset = 5.5 * 60 * 60 * 1000;
  const ist = new Date(now.getTime() + istOffset);
  const prevMonth = new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth() - 1, 1));
  const y = prevMonth.getUTCFullYear();
  const m = String(prevMonth.getUTCMonth() + 1).padStart(2, "0");
  return `${y}-${m}`;
}

/**
 * Core distribution logic — processes all active subscribers for `billingMonth`.
 */
async function runDistribution(
  billingMonth: string,
  triggeredBy: "scheduler" | "admin"
): Promise<void> {
  const db = admin.firestore();
  const runRef = db.collection("distribution_runs").doc(billingMonth);

  // --- Idempotency: skip if already completed ---
  const existingRun = await runRef.get();
  if (existingRun.exists && existingRun.data()?.status === "completed" && triggeredBy !== "admin") {
    logger.info(`[PremiumRevenue] Run for ${billingMonth} already completed. Skipping.`);
    return;
  }

  const startedAt = Date.now();
  const runDoc: PremiumDistributionRun = {
    month: billingMonth,
    status: "running",
    totalSubscribersProcessed: 0,
    totalChannelsAllocated: 0,
    grossPoolINR: 0,
    creatorPoolINR: 0,
    platformPoolINR: 0,
    unallocatedGrossINR: 0,
    unallocatedCreatorPoolINR: 0,
    startedAt,
    triggeredBy,
  };
  await runRef.set(runDoc, { merge: true });

  logger.info(`[PremiumRevenue] Starting distribution for ${billingMonth} (triggered by: ${triggeredBy})`);

  try {
    // --- 1. Parse billing month boundaries ---
    const [year, monthNum] = billingMonth.split("-").map(Number);
    const monthStart = new Date(Date.UTC(year, monthNum - 1, 1)).getTime();
    const monthEnd = new Date(Date.UTC(year, monthNum, 1)).getTime() - 1; // last ms of month
    const monthDays = new Date(Date.UTC(year, monthNum, 0)).getUTCDate(); // actual days in month

    // --- 2. Fetch all premium subscriptions active during this billing month ---
    // Active = subscribedAt <= monthEnd AND expiresAt >= monthStart
    const subsSnap = await db.collection("premium_subscriptions")
      .where("isPremium", "==", true)
      .get();

    logger.info(`[PremiumRevenue] Found ${subsSnap.size} total premium subscription records.`);

    // Channel aggregation: channelId -> { ownerId, grossINR, creatorINR, platformINR, watchSeconds }
    const channelAgg = new Map<string, {
      ownerId: string;
      grossINR: number;
      creatorINR: number;
      platformINR: number;
      watchSeconds: number;
    }>();

    let totalSubscribersProcessed = 0;
    let totalAllocations = 0;
    let globalGrossPoolINR = 0;
    let unallocatedGrossINR = 0;
    let unallocatedCreatorPoolINR = 0;

    // --- Batched Firestore writes ---
    let batch = db.batch();
    let batchOps = 0;

    const flushBatch = async () => {
      if (batchOps > 0) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      }
    };

    const addBatchOp = async (
      ref: admin.firestore.DocumentReference,
      data: object,
      merge = true
    ) => {
      if (batchOps >= 490) await flushBatch();
      merge ? batch.set(ref, data, { merge: true }) : batch.set(ref, data);
      batchOps++;
    };

    // --- 3. Process each subscriber ---
    for (const subDoc of subsSnap.docs) {
      const subData = subDoc.data();
      const userId = subData.userId || subDoc.id;
      if (!userId) continue;

      // Determine subscription period overlap with billing month
      const subscribedAt: number =
        subData.subscribedAt instanceof admin.firestore.Timestamp
          ? subData.subscribedAt.toMillis()
          : Number(subData.subscribedAt || subData.premiumStartedAt || monthStart);

      const expiresAt: number =
        subData.expiresAt instanceof admin.firestore.Timestamp
          ? subData.expiresAt.toMillis()
          : Number(subData.expiresAt || subData.premiumExpiresAt || monthEnd);

      // Skip if subscription was not active at all during the billing month
      if (expiresAt < monthStart || subscribedAt > monthEnd) continue;

      // Calculate overlap days (capped to actual days in month)
      const overlapStart = Math.max(subscribedAt, monthStart);
      const overlapEnd = Math.min(expiresAt, monthEnd);
      const overlapMs = Math.max(0, overlapEnd - overlapStart);
      const overlapDays = Math.min(monthDays, Math.ceil(overlapMs / (24 * 60 * 60 * 1000)));
      if (overlapDays === 0) continue;

      // Determine subscription amount
      const planId: string = subData.planId || "individual_monthly";
      const planAmounts: Record<string, number> = {
        audio_monthly: 42,
        individual_monthly: 168,
        "4k_factchecked_monthly": 252,
        family_monthly: 420,
        individual_yearly: Math.round(1512 / 12),
      };
      const monthlyAmountINR = (typeof subData.amount === "number" && subData.amount > 0)
        ? subData.amount
        : (planAmounts[planId] ?? 168);

      // Pro-rate: if yearly plan, monthly amount is already divided above
      const proratedContributionINR = monthlyAmountINR * (overlapDays / BILLING_DAYS);
      globalGrossPoolINR += proratedContributionINR;

      // --- 4. Fetch this subscriber's watch sessions for the billing month ---
      // Query watch_sessions by userId + lastUpdated within month range
      // watch_sessions doc: {userId, channelId, watchTimeSeconds, lastUpdated}
      // docId format: "{userId}_{videoId}" for authed users
      // We query the videoId → channelId mapping via the videos collection
      let channelWatchMap = new Map<string, { seconds: number; ownerId: string; isCustom: boolean }>();

      try {
        // Strategy: query watch_sessions where userId == subscriber, filter by month via lastUpdated
        const sessionsSnap = await db.collection("watch_sessions")
          .where("userId", "==", userId)
          .get();

        for (const sessDoc of sessionsSnap.docs) {
          const sess = sessDoc.data();

          // Only count sessions updated within the billing month window
          const lastUpdated = sess.lastUpdated instanceof admin.firestore.Timestamp
            ? sess.lastUpdated.toMillis()
            : (sess.lastUpdated ? Number(sess.lastUpdated) : 0);

          if (lastUpdated < monthStart || lastUpdated > monthEnd) continue;

          // Skip sessions flagged for bot/heartbeat fraud
          if (sess.flagged === true) {
            logger.warn(`[PremiumRevenue] Skipping flagged watch session ${sessDoc.id} for user ${userId}`);
            continue;
          }

          const watchSecs = Math.max(0, Number(sess.watchTimeSeconds || 0));
          if (watchSecs < MIN_WATCH_SECONDS) continue;

          // Resolve channelId: prefer session.channelId, fallback to video doc lookup
          let channelId: string | undefined = sess.channelId;
          let ownerId = "";
          let isCustom = false;

          if (!channelId && sess.videoId) {
            try {
              const videoDoc = await db.collection("videos").doc(sess.videoId).get();
              if (videoDoc.exists) {
                channelId = videoDoc.data()?.channelId;
              }
            } catch (_) { /* ignore */ }
          }

          if (!channelId) continue;

          // Resolve channel owner and type for security rules and split calculation
          if (!ownerId) {
            try {
              const chDoc = await db.collection("channels").doc(channelId).get();
              if (chDoc.exists) {
                const chData = chDoc.data() || {};
                ownerId = chData.ownerId || "";
                isCustom = chData.type === "custom" || chData.channelType === "custom";
              }
            } catch (_) { /* ignore */ }
          }

          const existing = channelWatchMap.get(channelId);
          if (existing) {
            existing.seconds += watchSecs;
          } else {
            channelWatchMap.set(channelId, { seconds: watchSecs, ownerId, isCustom });
          }
        }
      } catch (err) {
        logger.warn(`[PremiumRevenue] Could not fetch watch sessions for ${userId}:`, err);
      }

      // Filter channels below minimum watch threshold
      if (channelWatchMap.size > 0) {
        channelWatchMap = new Map(
          [...channelWatchMap.entries()].filter(([, v]) => v.seconds >= MIN_WATCH_SECONDS)
        );
      }

      // Calculate total qualified watch seconds
      const totalWatchSeconds = channelWatchMap.size > 0
        ? [...channelWatchMap.values()].reduce((sum, v) => sum + v.seconds, 0)
        : 0;

      // --- 5. Handle subscriber with no qualifying watch activity ---
      if (channelWatchMap.size === 0 || totalWatchSeconds === 0) {
        const subscriberCreatorPoolINR = proratedContributionINR * CREATOR_SHARE_RATE;
        unallocatedGrossINR += proratedContributionINR;
        unallocatedCreatorPoolINR += subscriberCreatorPoolINR;
        totalSubscribersProcessed++;
        logger.info(
          `[PremiumRevenue] Subscriber ${userId} had zero qualified watch time. Tracked ₹${proratedContributionINR.toFixed(2)} gross (₹${subscriberCreatorPoolINR.toFixed(2)} creator pool) to unallocated.`
        );
        continue;
      }

      // --- 6. Write per-channel allocations ---
      for (const [channelId, { seconds: watchSeconds, ownerId, isCustom }] of channelWatchMap.entries()) {
        const sharePercent = (watchSeconds / totalWatchSeconds) * 100;
        const creatorRate = isCustom ? TYPE_REVENUE_SHARE.custom.premiumSubs : CREATOR_SHARE_RATE;
        const platformRate = isCustom ? 0.00 : PLATFORM_SHARE_RATE;
        const channelGrossINR = proratedContributionINR * (sharePercent / 100);
        const creatorShareINR = Math.round(channelGrossINR * creatorRate * 100) / 100;
        const platformFeeINR = Math.round(channelGrossINR * platformRate * 100) / 100;
        const grossAllocationINR = creatorShareINR;

        const allocId = `${billingMonth}_${userId}_${channelId}`;
        const allocRef = db.collection("premium_revenue_allocations").doc(allocId);

        const allocation: PremiumRevenueAllocation = {
          id: allocId,
          month: billingMonth,
          userId,
          channelId,
          channelOwnerId: ownerId,
          subscriptionPlanId: planId,
          subscriptionAmountINR: monthlyAmountINR,
          overlapDays,
          proratedContributionINR: Math.round(proratedContributionINR * 100) / 100,
          watchSeconds,
          totalWatchSeconds,
          sharePercent: Math.round(sharePercent * 100) / 100,
          grossAllocationINR: Math.round(grossAllocationINR * 100) / 100,
          creatorShareINR: Math.round(creatorShareINR * 100) / 100,
          platformFeeINR: Math.round(platformFeeINR * 100) / 100,
          processedAt: Date.now(),
          distributionRunId: billingMonth,
        };

        await addBatchOp(allocRef, allocation, false); // overwrite for idempotent reruns

        // Accumulate channel totals
        const existing = channelAgg.get(channelId);
        if (existing) {
          existing.grossINR += allocation.grossAllocationINR;
          existing.creatorINR += allocation.creatorShareINR;
          existing.platformINR += allocation.platformFeeINR;
          existing.watchSeconds += watchSeconds;
        } else {
          channelAgg.set(channelId, {
            ownerId,
            grossINR: allocation.grossAllocationINR,
            creatorINR: allocation.creatorShareINR,
            platformINR: allocation.platformFeeINR,
            watchSeconds,
          });
        }

        totalAllocations++;
      }

      totalSubscribersProcessed++;
    }

    // --- 6.5. Reallocate unallocated creator pool pro-rata OR assign to creator community fund ---
    const totalPlatformWatchSeconds = [...channelAgg.values()].reduce((sum, v) => sum + v.watchSeconds, 0);
    const hasActiveChannels = channelAgg.size > 0 && totalPlatformWatchSeconds > 0;

    let reallocatedAmountINR = 0;
    let retainedInFundINR = 0;

    if (unallocatedCreatorPoolINR > 0) {
      if (hasActiveChannels) {
        // Reallocate pro-rata across all channels that earned watch time this month
        logger.info(
          `[PremiumRevenue] Reallocating ₹${unallocatedCreatorPoolINR.toFixed(2)} unallocated creator revenue across ${channelAgg.size} active channels.`
        );

        let remainingCreatorRealloc = Math.round(unallocatedCreatorPoolINR * 100) / 100;
        let remainingGrossRealloc = Math.round(unallocatedGrossINR * 100) / 100;

        const channelEntries = [...channelAgg.entries()];
        for (let i = 0; i < channelEntries.length; i++) {
          const [channelId, agg] = channelEntries[i];
          const isLast = i === channelEntries.length - 1;
          const channelShare = agg.watchSeconds / totalPlatformWatchSeconds;

          const creatorShare = isLast
            ? remainingCreatorRealloc
            : Math.min(remainingCreatorRealloc, Math.round(unallocatedCreatorPoolINR * channelShare * 100) / 100);
          const grossShare = isLast
            ? remainingGrossRealloc
            : Math.min(remainingGrossRealloc, Math.round(unallocatedGrossINR * channelShare * 100) / 100);
          const platformFee = Math.round((grossShare - creatorShare) * 100) / 100;

          remainingCreatorRealloc = Math.round((remainingCreatorRealloc - creatorShare) * 100) / 100;
          remainingGrossRealloc = Math.round((remainingGrossRealloc - grossShare) * 100) / 100;

          agg.creatorINR += creatorShare;
          agg.grossINR += grossShare;
          agg.platformINR += platformFee;

          // Transparent allocation record for audit trail
          const reallocDocId = `${billingMonth}_unallocated_pool_${channelId}`;
          const reallocRef = db.collection("premium_revenue_allocations").doc(reallocDocId);
          const reallocAllocation: PremiumRevenueAllocation = {
            id: reallocDocId,
            month: billingMonth,
            userId: "unallocated_subscribers_pool",
            channelId,
            channelOwnerId: agg.ownerId,
            subscriptionPlanId: "unallocated_pool_reallocation",
            subscriptionAmountINR: Math.round(grossShare * 100) / 100,
            overlapDays: 30,
            proratedContributionINR: Math.round(grossShare * 100) / 100,
            watchSeconds: 0,
            totalWatchSeconds: totalPlatformWatchSeconds,
            sharePercent: Math.round(channelShare * 100 * 100) / 100,
            grossAllocationINR: Math.round(creatorShare * 100) / 100,
            creatorShareINR: Math.round(creatorShare * 100) / 100,
            platformFeeINR: Math.round(platformFee * 100) / 100,
            processedAt: Date.now(),
            distributionRunId: billingMonth,
          };
          await addBatchOp(reallocRef, reallocAllocation, false);
          totalAllocations++;
        }

        reallocatedAmountINR = Math.round(unallocatedCreatorPoolINR * 100) / 100;
      } else {
        // No active channels earned watch time this month: allocate to designated creator community fund
        logger.info(
          `[PremiumRevenue] No active channels with watch time this month. Allocating ₹${unallocatedCreatorPoolINR.toFixed(2)} to creator_community_fund.`
        );
        retainedInFundINR = Math.round(unallocatedCreatorPoolINR * 100) / 100;
      }

      // Record in designated creator_community_fund document in Firestore
      await db.collection("creator_community_fund").doc(billingMonth).set(
        {
          month: billingMonth,
          unallocatedGrossINR: Math.round(unallocatedGrossINR * 100) / 100,
          unallocatedCreatorPoolINR: Math.round(unallocatedCreatorPoolINR * 100) / 100,
          reallocatedToChannels: hasActiveChannels,
          reallocatedChannelsCount: hasActiveChannels ? channelAgg.size : 0,
          reallocatedAmountINR,
          retainedInFundINR,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Update cumulative creator community fund overview
      await db.collection("creator_community_fund").doc("overview").set(
        {
          totalUnallocatedGrossINR: admin.firestore.FieldValue.increment(Math.round(unallocatedGrossINR * 100) / 100),
          totalUnallocatedCreatorPoolINR: admin.firestore.FieldValue.increment(Math.round(unallocatedCreatorPoolINR * 100) / 100),
          totalReallocatedToChannelsINR: admin.firestore.FieldValue.increment(reallocatedAmountINR),
          currentFundBalanceINR: admin.firestore.FieldValue.increment(retainedInFundINR),
          lastUpdatedMonth: billingMonth,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    await flushBatch();

    // --- 7. Update revenue_statements & channel totals per channel ---
    logger.info(`[PremiumRevenue] Updating ${channelAgg.size} channel revenue statements.`);

    for (const [channelId, agg] of channelAgg.entries()) {
      // Get channel owner for statement doc ID
      let ownerId = agg.ownerId;
      if (!ownerId) {
        try {
          const chDoc = await db.collection("channels").doc(channelId).get();
          ownerId = chDoc.data()?.ownerId || channelId;
        } catch (_) { ownerId = channelId; }
      }

      const statementId = `${billingMonth}_${ownerId}_${channelId}`;
      const statementRef = db.collection("revenue_statements").doc(statementId);
      const existingStmt = await statementRef.get();

      const grossPremiumSubsINR = Math.round(agg.grossINR * 100) / 100;
      const creatorShareINR = Math.round(agg.creatorINR * 100) / 100;
      const platformFeeINR = Math.round(agg.platformINR * 100) / 100;

      if (!existingStmt.exists) {
        await statementRef.set({
          id: statementId,
          userId: ownerId,
          channelId,
          month: billingMonth,
          grossAdsRevenue: 0,
          grossSubsRevenue: grossPremiumSubsINR,
          grossPremiumSubsRevenue: grossPremiumSubsINR,
          platformFee: platformFeeINR,
          infrastructureCosts: 0,
          creatorShare: creatorShareINR,
          withdrawableShare: creatorShareINR,
          paidOutShare: 0,
          payoutStatus: "pending",
          createdAt: Date.now(),
          updatedAt: Date.now(),
          metadata: {
            totalViews: 0,
            avgRPM: 0,
            trustBonus: 0,
            premiumAllocations: totalAllocations,
            distributionRunId: billingMonth,
          },
        });
      } else {
        const existingData = existingStmt.data() || {};
        const existingCreatorShare = Number(existingData.creatorShare || 0);
        const existingGrossSubs = Number(existingData.grossSubsRevenue || 0);
        const existingPlatformFee = Number(existingData.platformFee || 0);
        const existingWithdrawable = Number(existingData.withdrawableShare || 0);

        await statementRef.update({
          grossSubsRevenue: existingGrossSubs + grossPremiumSubsINR,
          grossPremiumSubsRevenue: grossPremiumSubsINR,
          platformFee: existingPlatformFee + platformFeeINR,
          creatorShare: existingCreatorShare + creatorShareINR,
          withdrawableShare: existingWithdrawable + creatorShareINR,
          updatedAt: Date.now(),
          "metadata.distributionRunId": billingMonth,
        });
      }

      // Update channel's cumulative premium subs revenue total
      await db.collection("channels").doc(channelId).set(
        {
          premiumSubsRevenueTotal: admin.firestore.FieldValue.increment(creatorShareINR),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    // --- 8. Finalize distribution run ---
    const creatorPoolINR = Math.round(
      ([...channelAgg.values()].reduce((s, v) => s + v.creatorINR, 0) + retainedInFundINR) * 100
    ) / 100;
    const platformPoolINR = Math.round(
      (Math.round(globalGrossPoolINR * 100) / 100 - creatorPoolINR) * 100
    ) / 100;

    await runRef.set({
      month: billingMonth,
      status: "completed",
      totalSubscribersProcessed,
      totalChannelsAllocated: channelAgg.size,
      grossPoolINR: Math.round(globalGrossPoolINR * 100) / 100,
      creatorPoolINR,
      platformPoolINR,
      unallocatedGrossINR: Math.round(unallocatedGrossINR * 100) / 100,
      unallocatedCreatorPoolINR: Math.round(unallocatedCreatorPoolINR * 100) / 100,
      startedAt,
      completedAt: Date.now(),
      triggeredBy,
    } as PremiumDistributionRun);

    logger.info(
      `[PremiumRevenue] ✅ ${billingMonth} complete. Subscribers: ${totalSubscribersProcessed}, Channels: ${channelAgg.size}, GrossPool: ₹${globalGrossPoolINR.toFixed(2)}, CreatorPool: ₹${creatorPoolINR}, PlatformPool: ₹${platformPoolINR}`
    );
  } catch (err: any) {
    logger.error(`[PremiumRevenue] ❌ Distribution failed for ${billingMonth}:`, err);
    await runRef.set(
      { status: "failed", error: err?.message || String(err), completedAt: Date.now() },
      { merge: true }
    );
    throw err;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT 1: distributePremiumRevenue — Scheduled Monthly
// Runs on 1st of each month at 01:00 IST (19:30 UTC previous day)
// ─────────────────────────────────────────────────────────────────────────────
export const distributePremiumRevenue = onSchedule(
  {
    schedule: "0 1 1 * *", // 01:00 AM IST on 1st of every month
    timeZone: "Asia/Kolkata",
    region: REGION,
    timeoutSeconds: 540,
    memory: "2GiB",
  },
  async () => {
    const billingMonth = getPreviousBillingMonth();
    await runDistribution(billingMonth, "scheduler");
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT 2: getPremiumRevenueBreakdown — Creator-Facing Callable
// Returns a channel's premium subs breakdown for a given month.
// ─────────────────────────────────────────────────────────────────────────────
export const getPremiumRevenueBreakdown = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId, month } = request.data as { channelId?: string; month?: string };
    if (!channelId || !month) {
      throw new HttpsError("invalid-argument", "channelId and month are required.");
    }

    // Verify requester owns the channel
    const db = admin.firestore();
    const channelDoc = await db.collection("channels").doc(channelId).get();
    if (!channelDoc.exists || channelDoc.data()?.ownerId !== userId) {
      throw new HttpsError("permission-denied", "You do not own this channel.");
    }

    try {
      // Fetch all allocations for this channel + month
      const allocsSnap = await db.collection("premium_revenue_allocations")
        .where("channelId", "==", channelId)
        .where("month", "==", month)
        .get();

      const allocations = allocsSnap.docs.map(d => d.data());
      const totalCreatorShareINR = allocations.reduce((s, a) => s + Number(a.creatorShareINR || 0), 0);
      const totalGrossINR = allocations.reduce((s, a) => s + Number(a.grossAllocationINR || 0), 0);
      // Filter out system unallocated pool allocations for watch time & distinct subscriber counts
      const directAllocs = allocations.filter(a => a.userId !== "unallocated_subscribers_pool");
      const totalWatchSeconds = directAllocs.reduce((s, a) => s + Number(a.watchSeconds || 0), 0);
      const subscriberCount = new Set(directAllocs.map(a => a.userId)).size;

      // Get the distribution run metadata
      const runDoc = await db.collection("distribution_runs").doc(month).get();
      const runData = runDoc.exists ? runDoc.data() : null;

      return {
        channelId,
        month,
        totalCreatorShareINR: Math.round(totalCreatorShareINR * 100) / 100,
        totalGrossINR: Math.round(totalGrossINR * 100) / 100,
        totalWatchSeconds,
        totalWatchMinutes: Math.round(totalWatchSeconds / 60),
        subscriberCount,
        allocationCount: allocations.length,
        distributionStatus: runData?.status ?? "not_run",
        distributionCompletedAt: runData?.completedAt ?? null,
        creatorSharePercent: CREATOR_SHARE_RATE * 100,
        platformSharePercent: PLATFORM_SHARE_RATE * 100,
      };
    } catch (err) {
      logger.error("[getPremiumRevenueBreakdown] Error:", err);
      throw new HttpsError("internal", "Failed to fetch premium revenue breakdown.");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT 3: triggerPremiumDistributionManual — Admin-Only Callable
// Allows admins to rerun distribution for any past month.
// ─────────────────────────────────────────────────────────────────────────────
export const triggerPremiumDistributionManual = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    // Verify admin claim via server-minted token
    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { month } = request.data as { month?: string };
    if (!month || !/^\d{4}-\d{2}$/.test(month)) {
      throw new HttpsError("invalid-argument", "month must be in YYYY-MM format.");
    }

    logger.info(`[PremiumRevenue] Manual distribution triggered by admin ${userId} for month: ${month}`);

    try {
      await runDistribution(month, "admin");
      return { success: true, month };
    } catch (err: any) {
      throw new HttpsError("internal", err?.message || "Distribution failed.");
    }
  }
);
