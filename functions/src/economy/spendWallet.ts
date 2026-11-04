import { isCallableAdmin } from "../utils/auth";
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

export interface SpendChannelWalletData {
  channelId: string;
  amount: number;
  category: string;
  description: string;
  metadata?: Record<string, any>;
}

export interface SpendChannelWalletResult {
  success: boolean;
  transactionId: string;
  channelId: string;
  amount: number;
  balanceBefore: number;
  balanceAfter: number;
  rolloverDeducted: number;
  fundedDeducted: number;
  revenueDeducted: number;
  timestamp: number;
}

/**
 * 🔒 ATOMIC TRANSACTIONAL CHANNEL WALLET SPEND
 *
 * Guarantees 100% server-enforced atomic execution with OCC (Optimistic Concurrency Control):
 * 1. Requires authenticated user (channel owner or verified admin).
 * 2. Runs inside an atomic Firestore transaction (`db.runTransaction`).
 * 3. Re-reads fresh channel document and recalculates spendable balance (Zero-Waste priority: rollover -> funded -> revenue).
 * 4. Strictly prevents overdraw, race conditions, and concurrent double spending.
 * 5. Commits ledger entry to `channel_wallet_transactions` and updates channel atomically.
 */
export const spendChannelWallet = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request): Promise<SpendChannelWalletResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated to spend wallet funds.");
    }

    const data = request.data as SpendChannelWalletData;
    if (!data) {
      throw new HttpsError("invalid-argument", "Missing request payload.");
    }

    const { channelId, amount, category, description, metadata } = data;

    if (!channelId || typeof channelId !== "string") {
      throw new HttpsError("invalid-argument", "Missing or invalid channelId.");
    }

    const spendAmount = Number(amount);
    if (!spendAmount || isNaN(spendAmount) || spendAmount <= 0) {
      throw new HttpsError("invalid-argument", "Spend amount must be greater than zero.");
    }

    const channelRef = db().collection("channels").doc(channelId);
    const txDocRef = db().collection("channel_wallet_transactions").doc();
    const txId = txDocRef.id;
    const nowMs = Date.now();

    try {
      const result = await db().runTransaction(async (transaction) => {
        // ── 1. ALL READS ──
        const channelSnap = await transaction.get(channelRef);
        if (!channelSnap.exists) {
          throw new HttpsError("not-found", `Channel ${channelId} not found.`);
        }

        const channelData = channelSnap.data() || {};
        const isOwner = channelData.ownerId === uid || channelData.userId === uid;
        const isAdmin = isCallableAdmin(request.auth);

        if (!isOwner && !isAdmin) {
          throw new HttpsError(
            "permission-denied",
            "Only channel owners or platform admins can spend channel wallet funds."
          );
        }

        // Calculate live spendable balance
        const infraConfig = channelData.infraConfig || {};
        const rolloverCredit = Number(infraConfig.rolloverCreditUSD || 0);
        const fundedBalance = Number(channelData.walletBalanceUSD || channelData.walletBalance || 0);

        // Revenue balances
        const adsRev = Number(channelData.adsRevenueTotal || 0);
        const premRev = Number(channelData.premiumSubsRevenueTotal || 0);
        const memRev = Number(channelData.membershipRevenueTotal || 0);
        const superRev = Number(channelData.superchatRevenueTotal || 0);
        const totalRevenueINR = adsRev + premRev + memRev + superRev;
        const withdrawnINR = Number(channelData.withdrawnRevenueTotal || 0);
        const availableRevINR = Math.max(0, totalRevenueINR - withdrawnINR);
        const availableRevUSD = availableRevINR / 84.0;

        const totalSpendable = rolloverCredit + fundedBalance + availableRevUSD;

        if (spendAmount > totalSpendable) {
          throw new HttpsError(
            "failed-precondition",
            `Insufficient spendable balance. Required: $${spendAmount.toFixed(2)}, Available: $${totalSpendable.toFixed(2)}`
          );
        }

        const balanceBefore = totalSpendable;

        // ── 2. ZERO-WASTE DEDUCTION BREAKDOWN ──
        // 1. Rollover credits first
        // 2. Funded wallet balance second
        // 3. Unwithdrawn revenue third
        let remaining = spendAmount;

        let rolloverDeducted = 0;
        if (remaining > 0 && rolloverCredit > 0) {
          rolloverDeducted = Number(Math.min(rolloverCredit, remaining).toFixed(2));
          remaining = Number((remaining - rolloverDeducted).toFixed(2));
        }

        let fundedDeducted = 0;
        if (remaining > 0 && fundedBalance > 0) {
          fundedDeducted = Number(Math.min(fundedBalance, remaining).toFixed(2));
          remaining = Number((remaining - fundedDeducted).toFixed(2));
        }

        const revenueDeductedUSD = Number(remaining.toFixed(2));
        const revenueDeductedINR = Number((revenueDeductedUSD * 84.0).toFixed(2));

        const newRollover = Math.max(0, Number((rolloverCredit - rolloverDeducted).toFixed(2)));
        const newFundedBalance = Math.max(0, Number((fundedBalance - fundedDeducted).toFixed(2)));
        const balanceAfter = Math.max(0, Number((balanceBefore - spendAmount).toFixed(2)));

        // ── 3. ATOMIC WRITES ──
        const channelUpdates: Record<string, any> = {
          "infraConfig.rolloverCreditUSD": newRollover,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (fundedDeducted > 0) {
          channelUpdates.walletBalanceUSD = newFundedBalance;
          channelUpdates.walletBalance = newFundedBalance;
        }

        if (revenueDeductedINR > 0) {
          channelUpdates.withdrawnRevenueTotal = admin.firestore.FieldValue.increment(revenueDeductedINR);
        }

        // ── 4. ATOMIC QUOTA & PLAN UPGRADES (SERVER ENFORCED & COST VERIFIED) ──
        if (category === "storageTopup") {
          const STORAGE_PACK_COSTS: Record<string, { gb: number; costUSD: number }> = {
            storage_25gb: { gb: 25, costUSD: 2.50 },
            storage_50gb: { gb: 50, costUSD: 5.00 },
            storage_100gb: { gb: 100, costUSD: 10.00 },
            storage_500gb: { gb: 500, costUSD: 50.00 },
          };
          const packId = String(metadata?.packId || "");
          let allowedGB = 0;
          if (packId && STORAGE_PACK_COSTS[packId]) {
            const pack = STORAGE_PACK_COSTS[packId];
            if (spendAmount < pack.costUSD) {
              throw new HttpsError(
                "invalid-argument",
                `Storage pack ${packId} requires $${pack.costUSD.toFixed(2)}, but spendAmount was $${spendAmount.toFixed(2)}.`
              );
            }
            allowedGB = pack.gb;
          } else {
            // Standard rate: $0.10 per GB
            allowedGB = Math.floor(spendAmount / 0.10);
          }

          if (allowedGB <= 0) {
            throw new HttpsError("invalid-argument", "Spend amount insufficient to purchase storage quota ($0.10/GB minimum).");
          }
          const addBytes = allowedGB * 1024 * 1024 * 1024;
          channelUpdates["infraConfig.storageQuotaBytes"] = admin.firestore.FieldValue.increment(addBytes);
        } else if (category === "bandwidthTopup") {
          const BANDWIDTH_PACK_COSTS: Record<string, { gb: number; costUSD: number }> = {
            bandwidth_100gb: { gb: 100, costUSD: 5.00 },
            bandwidth_250gb: { gb: 250, costUSD: 12.50 },
            bandwidth_500gb: { gb: 500, costUSD: 25.00 },
            bandwidth_1tb: { gb: 1000, costUSD: 50.00 },
          };
          const packId = String(metadata?.packId || "");
          let allowedGB = 0;
          if (packId && BANDWIDTH_PACK_COSTS[packId]) {
            const pack = BANDWIDTH_PACK_COSTS[packId];
            if (spendAmount < pack.costUSD) {
              throw new HttpsError(
                "invalid-argument",
                `Bandwidth pack ${packId} requires $${pack.costUSD.toFixed(2)}, but spendAmount was $${spendAmount.toFixed(2)}.`
              );
            }
            allowedGB = pack.gb;
          } else {
            // Standard rate: $0.05 per GB
            allowedGB = Math.floor(spendAmount / 0.05);
          }

          if (allowedGB <= 0) {
            throw new HttpsError("invalid-argument", "Spend amount insufficient to purchase bandwidth quota ($0.05/GB minimum).");
          }
          const addBytes = allowedGB * 1024 * 1024 * 1024;
          channelUpdates["infraConfig.bandwidthQuotaBytesThisMonth"] = admin.firestore.FieldValue.increment(addBytes);
        } else if (category === "customChannelPlan") {
          const PLAN_TIER_CONFIG: Record<string, { fee: number; storageGB: number; bandwidthGB: number }> = {
            starter_15: { fee: 15.0, storageGB: 50, bandwidthGB: 250 },
            growth_30: { fee: 30.0, storageGB: 100, bandwidthGB: 500 },
            pro_45: { fee: 45.0, storageGB: 150, bandwidthGB: 750 },
            scale_100: { fee: 100.0, storageGB: 400, bandwidthGB: 1600 },
            premier_200: { fee: 200.0, storageGB: 800, bandwidthGB: 3200 },
          };
          const planTier = String(metadata?.planTier || "starter_15");
          const planConfig = PLAN_TIER_CONFIG[planTier] || PLAN_TIER_CONFIG["starter_15"];

          // Enforce that spendAmount strictly covers the plan tier platform fee
          if (spendAmount < planConfig.fee) {
            throw new HttpsError(
              "invalid-argument",
              `Pro channel plan ${planTier} requires a platform fee of $${planConfig.fee.toFixed(2)}, but spendAmount was $${spendAmount.toFixed(2)}.`
            );
          }

          const autoPay = metadata?.autoPay !== false;
          channelUpdates.channelType = "custom";
          channelUpdates["infraConfig.planTier"] = planTier;
          channelUpdates["infraConfig.flatPlatformFee"] = planConfig.fee;
          channelUpdates["infraConfig.autoPay"] = autoPay;
          channelUpdates["infraConfig.planStatus"] = "active";
          channelUpdates["infraConfig.lastBilledAt"] = admin.firestore.FieldValue.serverTimestamp();
          channelUpdates["infraConfig.storageQuotaBytes"] = planConfig.storageGB * 1024 * 1024 * 1024;
          channelUpdates["infraConfig.bandwidthQuotaBytesThisMonth"] = planConfig.bandwidthGB * 1024 * 1024 * 1024;
          channelUpdates["infraConfig.isWithdrawalHeld"] = false;
          channelUpdates["infraConfig.withdrawalHoldReason"] = "";
        }

        transaction.update(channelRef, channelUpdates);

        transaction.set(txDocRef, {
          id: txId,
          channelId,
          userId: uid,
          amount: spendAmount,
          trialCreditDeducted: 0,
          rolloverDeducted,
          fundedDeducted,
          revenueDeducted: revenueDeductedUSD,
          category: category || "aiBundle",
          description: description || `Wallet Spend: $${spendAmount.toFixed(2)}`,
          balanceBefore,
          balanceAfter,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          metadata: metadata || {},
        });

        return {
          success: true,
          transactionId: txId,
          channelId,
          amount: spendAmount,
          balanceBefore,
          balanceAfter,
          rolloverDeducted,
          fundedDeducted,
          revenueDeducted: revenueDeductedUSD,
          timestamp: nowMs,
        };
      });

      logger.info(`[SpendWallet] Success: Channel ${channelId} spent $${spendAmount.toFixed(2)} (Tx: ${result.transactionId})`);
      return result;
    } catch (err: any) {
      if (err instanceof HttpsError) {
        throw err;
      }
      logger.error(`[SpendWallet] Error executing atomic transaction for channel ${channelId}:`, err);
      throw new HttpsError("internal", "Unable to process wallet transaction. Please try again later.");
    }
  }
);
