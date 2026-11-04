import { isCallableAdmin } from "../utils/auth";
import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { SETTLEMENT_CLEARING_MS } from "./types";

const REGION = "asia-south1";
const db = () => admin.firestore();

export interface ChannelSettlementBreakdown {
  channelId: string;
  totalEstimatedRevenueINR: number;
  clearedWithdrawableRevenueINR: number;
  pendingClearingRevenueINR: number;
  withdrawnRevenueINR: number;
  availableWithdrawableINR: number;
  clearedSuperchatsINR: number;
  pendingSuperchatsINR: number;
  clearedMembershipsINR: number;
  pendingMembershipsINR: number;
  finalizedStatementsINR: number;
  unfinalizedStatementsINR: number;
  lastReconciledAt: number;
}

/**
 * ⚖️ RECONCILE CHANNEL SETTLEMENT
 *
 * Industry-Standard Two-Phase Settlement Reconciler:
 * 1. Scans Superchats and Memberships with settlementStatus === "clearing".
 * 2. Unlocks items older than T+7 days (SETTLEMENT_CLEARING_MS) to settlementStatus = "cleared".
 * 3. Audits finalized monthly revenue statements vs. in-flight (accruing) statements.
 * 4. Atomically updates `clearedWithdrawableRevenueTotal` and `pendingRevenueTotal` on the channel document.
 */
export async function reconcileChannelSettlement(
  channelId: string
): Promise<ChannelSettlementBreakdown> {
  const channelRef = db().collection("channels").doc(channelId);
  const now = Date.now();
  const nowTimestamp = admin.firestore.Timestamp.fromMillis(now);

  const channelSnap = await channelRef.get();
  if (!channelSnap.exists) {
    throw new Error(`Channel ${channelId} not found`);
  }

  const channelData = channelSnap.data() || {};
  const batch = db().batch();
  let batchOps = 0;

  const commitBatchIfNeeded = async () => {
    if (batchOps >= 450) {
      await batch.commit();
      batchOps = 0;
    }
  };

  // ── 1. Reconcile Superchats (T+7 clearing hold & Hybrid Model Revenue Split) ──
  const isCustomChannel = channelData.channelType === "custom" || channelData.type === "custom" || channelData.channelType === "pro" || channelData.type === "pro";
  const superchatRate = isCustomChannel ? 1.00 : 0.90;
  const membershipRate = isCustomChannel ? 1.00 : 0.90;

  let clearedSuperchatsINR = 0;
  let pendingSuperchatsINR = 0;

  try {
    const superchatsSnap = await channelRef.collection("superchats").get();
    for (const doc of superchatsSnap.docs) {
      const data = doc.data();
      const amount = Number(data.amount || 0);
      const creatorAmount = amount * superchatRate;
      const createdAt = data.createdAt?.toMillis?.() ?? (data.clearAt?.toMillis?.() ? data.clearAt.toMillis() - SETTLEMENT_CLEARING_MS : now);
      const isMature = (now - createdAt) >= SETTLEMENT_CLEARING_MS;
      const currentStatus = data.settlementStatus || (isMature ? "cleared" : "clearing");

      if (isMature && currentStatus !== "cleared") {
        batch.update(doc.ref, {
          settlementStatus: "cleared",
          clearedAt: nowTimestamp,
        });
        batchOps++;
        clearedSuperchatsINR += creatorAmount;
      } else if (currentStatus === "cleared" || isMature) {
        clearedSuperchatsINR += creatorAmount;
      } else {
        pendingSuperchatsINR += creatorAmount;
      }
      await commitBatchIfNeeded();
    }
  } catch (err) {
    logger.warn(`[Settlement] Error reading superchats for channel ${channelId}:`, err);
  }

  // ── 2. Reconcile Channel Memberships (T+7 clearing hold & Hybrid Model Revenue Split) ──
  let clearedMembershipsINR = 0;
  let pendingMembershipsINR = 0;

  try {
    const membersSnap = await channelRef.collection("members").get();
    for (const doc of membersSnap.docs) {
      const data = doc.data();
      const price = Number(data.price || 0);
      const creatorPrice = price * membershipRate;
      const joinedAt = data.joinedAt?.toMillis?.() ?? (data.clearAt?.toMillis?.() ? data.clearAt.toMillis() - SETTLEMENT_CLEARING_MS : now);
      const isMature = (now - joinedAt) >= SETTLEMENT_CLEARING_MS;
      const currentStatus = data.settlementStatus || (isMature ? "cleared" : "clearing");

      if (isMature && currentStatus !== "cleared") {
        batch.update(doc.ref, {
          settlementStatus: "cleared",
          clearedAt: nowTimestamp,
        });
        batchOps++;
        clearedMembershipsINR += creatorPrice;
      } else if (currentStatus === "cleared" || isMature) {
        clearedMembershipsINR += creatorPrice;
      } else {
        pendingMembershipsINR += creatorPrice;
      }
      await commitBatchIfNeeded();
    }
  } catch (err) {
    logger.warn(`[Settlement] Error reading members for channel ${channelId}:`, err);
  }

  // ── 3. Reconcile Monthly Statements (Ads & Premium Subs) ──
  // Current calendar month is unfinalized/accruing; past closed months are finalized.
  const currentMonthKey = new Date().toISOString().slice(0, 7); // "YYYY-MM"
  let finalizedStatementsINR = 0;
  let unfinalizedStatementsINR = 0;

  try {
    const stmtsSnap = await db().collection("revenue_statements")
      .where("channelId", "==", channelId)
      .get();

    for (const doc of stmtsSnap.docs) {
      const data = doc.data();
      const stmtMonth = data.month || "";
      const isPastMonth = stmtMonth !== currentMonthKey;
      const share = Number(data.creatorShare || 0);

      // Auto-finalize past month statements if not explicitly finalized
      if (isPastMonth && data.status !== "finalized") {
        batch.update(doc.ref, {
          status: "finalized",
          finalizedAt: now,
          updatedAt: now,
        });
        batchOps++;
        finalizedStatementsINR += share;
      } else if (data.status === "finalized" || isPastMonth) {
        finalizedStatementsINR += share;
      } else {
        unfinalizedStatementsINR += share;
      }
      await commitBatchIfNeeded();
    }
  } catch (err) {
    logger.warn(`[Settlement] Error reading revenue_statements for channel ${channelId}:`, err);
  }

  if (batchOps > 0) {
    await batch.commit();
  }

  // ── 4. Compute Totals ──
  const lifetimeAds = Number(channelData.adsRevenueTotal || 0);
  const lifetimePrem = Number(channelData.premiumSubsRevenueTotal || 0);
  const lifetimeSuper = Number(channelData.superchatRevenueTotal || 0) * superchatRate;
  const lifetimeMem = Number(channelData.membershipRevenueTotal || 0) * membershipRate;
  const walletUSD = Number(channelData.walletBalanceUSD || 0);
  const walletINR = walletUSD * 84.0;
  const withdrawnTotal = Number(channelData.withdrawnRevenueTotal || 0);

  // If statements were not created yet, past mature portion of ads/prem is derived safely
  const resolvedFinalizedAdsAndSubs = Math.max(finalizedStatementsINR, 0);
  const currentMonthInFlightAdsAndSubs = Math.max(0, (lifetimeAds + lifetimePrem) - resolvedFinalizedAdsAndSubs);

  const totalClearedRevenue = clearedSuperchatsINR + clearedMembershipsINR + resolvedFinalizedAdsAndSubs + walletINR;
  const totalPendingRevenue = pendingSuperchatsINR + pendingMembershipsINR + currentMonthInFlightAdsAndSubs;
  const totalEstimatedRevenue = lifetimeAds + lifetimePrem + lifetimeSuper + lifetimeMem + walletINR;
  const availableWithdrawableINR = Math.max(0, totalClearedRevenue - withdrawnTotal);

  // Update Channel Document with synchronized two-phase balances
  await channelRef.update({
    clearedWithdrawableRevenueTotal: Math.round(totalClearedRevenue * 100) / 100,
    pendingRevenueTotal: Math.round(totalPendingRevenue * 100) / 100,
    lastSettlementReconciliationAt: now,
    updatedAt: nowTimestamp,
  });

  return {
    channelId,
    totalEstimatedRevenueINR: Math.round(totalEstimatedRevenue * 100) / 100,
    clearedWithdrawableRevenueINR: Math.round(totalClearedRevenue * 100) / 100,
    pendingClearingRevenueINR: Math.round(totalPendingRevenue * 100) / 100,
    withdrawnRevenueINR: Math.round(withdrawnTotal * 100) / 100,
    availableWithdrawableINR: Math.round(availableWithdrawableINR * 100) / 100,
    clearedSuperchatsINR: Math.round(clearedSuperchatsINR * 100) / 100,
    pendingSuperchatsINR: Math.round(pendingSuperchatsINR * 100) / 100,
    clearedMembershipsINR: Math.round(clearedMembershipsINR * 100) / 100,
    pendingMembershipsINR: Math.round(pendingMembershipsINR * 100) / 100,
    finalizedStatementsINR: Math.round(finalizedStatementsINR * 100) / 100,
    unfinalizedStatementsINR: Math.round(unfinalizedStatementsINR * 100) / 100,
    lastReconciledAt: now,
  };
}

/**
 * ⏰ SCHEDULED SETTLEMENT RECONCILIATION
 * Runs every 6 hours to mature in-flight transactions (T+7 days)
 * and update channel cleared withdrawable balances.
 */
export const reconcilePendingSettlementsScheduler = onSchedule(
  {
    schedule: "0 */6 * * *",
    timeZone: "Asia/Kolkata",
    region: REGION,
    memory: "512MiB",
  },
  async () => {
    logger.info("[SettlementScheduler] Starting automated pending settlement reconciliation...");
    try {
      // Find channels with pending revenue or recent updates
      const channelsSnap = await db().collection("channels")
        .where("pendingRevenueTotal", ">", 0)
        .limit(100)
        .get();

      if (channelsSnap.empty) {
        logger.info("[SettlementScheduler] No channels with pending revenue. Sweep complete.");
        return;
      }

      logger.info(`[SettlementScheduler] Reconciling ${channelsSnap.size} channels with pending funds...`);
      for (const chDoc of channelsSnap.docs) {
        try {
          await reconcileChannelSettlement(chDoc.id);
        } catch (chErr) {
          logger.warn(`[SettlementScheduler] Failed to reconcile channel ${chDoc.id}:`, chErr);
        }
      }
      logger.info("[SettlementScheduler] Sweep finished successfully.");
    } catch (err) {
      logger.error("[SettlementScheduler] Error during scheduled reconciliation:", err);
    }
  }
);

/**
 * 🔄 RECONCILE CHANNEL SETTLEMENT (Callable)
 * Allows creator or admin to trigger a settlement reconciliation before submitting a withdrawal.
 */
export const reconcileChannelSettlementCallable = onCall(
  { region: REGION, memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { channelId } = (request.data || {}) as { channelId?: string };
    if (!channelId) {
      throw new HttpsError("invalid-argument", "channelId is required.");
    }

    const channelSnap = await db().collection("channels").doc(channelId).get();
    if (!channelSnap.exists) {
      throw new HttpsError("not-found", "Channel not found.");
    }

    const chData = channelSnap.data() || {};
    const isOwner = chData.ownerId === userId || chData.userId === userId;
    const isAdmin = isCallableAdmin(request.auth);

    if (!isOwner && !isAdmin) {
      throw new HttpsError("permission-denied", "Unauthorized access to channel settlement.");
    }

    try {
      const breakdown = await reconcileChannelSettlement(channelId);
      return { success: true, breakdown };
    } catch (err: any) {
      logger.error(`[reconcileChannelSettlementCallable] Error for ${channelId}:`, err);
      throw new HttpsError("internal", "Unable to reconcile channel settlement. Please try again later.");
    }
  }
);
