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
        const isAdmin = request.auth?.token?.admin === true;

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

        // ── 4. ATOMIC QUOTA & PLAN UPGRADES (SERVER ENFORCED) ──
        if (category === "storageTopup") {
          const addBytes = Number(metadata?.bytes) || (Number(metadata?.gigabytes) || 0) * 1024 * 1024 * 1024;
          if (addBytes > 0) {
            channelUpdates["infraConfig.storageQuotaBytes"] = admin.firestore.FieldValue.increment(addBytes);
          }
        } else if (category === "bandwidthTopup") {
          const addBytes = Number(metadata?.bytes) || (Number(metadata?.gigabytes) || 0) * 1024 * 1024 * 1024;
          if (addBytes > 0) {
            channelUpdates["infraConfig.bandwidthQuotaBytesThisMonth"] = admin.firestore.FieldValue.increment(addBytes);
          }
        } else if (category === "customChannelPlan") {
          const planTier = String(metadata?.planTier || "starter_15");
          const autoPay = metadata?.autoPay !== false;
          let storageGB = 50;
          let bandwidthGB = 250;
          let fee = spendAmount;

          if (planTier === "growth_30") {
            storageGB = 100;
            bandwidthGB = 500;
            fee = 30.0;
          } else if (planTier === "pro_45") {
            storageGB = 150;
            bandwidthGB = 750;
            fee = 45.0;
          } else if (planTier === "scale_100") {
            storageGB = 400;
            bandwidthGB = 1600;
            fee = 100.0;
          } else if (planTier === "premier_200") {
            storageGB = 800;
            bandwidthGB = 3200;
            fee = 200.0;
          }

          channelUpdates.channelType = "custom";
          channelUpdates["infraConfig.planTier"] = planTier;
          channelUpdates["infraConfig.flatPlatformFee"] = fee;
          channelUpdates["infraConfig.autoPay"] = autoPay;
          channelUpdates["infraConfig.storageQuotaBytes"] = storageGB * 1024 * 1024 * 1024;
          channelUpdates["infraConfig.bandwidthQuotaBytesThisMonth"] = bandwidthGB * 1024 * 1024 * 1024;
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
      throw new HttpsError("internal", err?.message || "Failed to process wallet transaction.");
    }
  }
);
