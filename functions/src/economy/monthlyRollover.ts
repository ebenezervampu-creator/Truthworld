import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

/**
 * 📅 AUTOMATED MONTHLY ZERO-WASTE PLAN BALANCE ROLLOVER
 *
 * Runs automatically at 00:00 IST on the 1st day of each month.
 * Scans all Pro Channels, computes unspent infra budget from the previous month,
 * and rolls over 100% of the unspent balance into `rolloverCreditUSD` down to the exact cent.
 *
 * All operations are server-governed inside atomic transactions.
 */
export const monthlyZeroWasteRollover = onSchedule(
  {
    schedule: "0 0 1 * *", // Midnight on 1st of every month
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
    memory: "512MiB",
  },
  async (event) => {
    logger.info("[MonthlyRollover] Starting Zero-Waste unspent plan rollover execution...");

    try {
      const channelsSnap = await db()
        .collection("channels")
        .where("channelType", "==", "custom")
        .get();

      if (channelsSnap.empty) {
        logger.info("[MonthlyRollover] No pro channels found.");
        return;
      }

      logger.info(`[MonthlyRollover] Processing ${channelsSnap.size} pro channels...`);

      let totalRolledOverUSD = 0;
      let channelsProcessed = 0;

      for (const channelDoc of channelsSnap.docs) {
        const channelId = channelDoc.id;
        const channelRef = channelDoc.ref;

        await db().runTransaction(async (transaction) => {
          const freshSnap = await transaction.get(channelRef);
          if (!freshSnap.exists) return;

          const data = freshSnap.data() || {};
          const infra = data.infraConfig || {};

          // 🛡️ Security Invariant (TW-ECON-07): Only active, paid custom plans are eligible for rollover credits
          const isPlanActive = infra.planStatus === "active" && !data.fraudReviewFlag && !data.payoutsBlocked;
          const planBudget = isPlanActive ? Number(infra.flatPlatformFee || 0) : 0;
          const currentSpent = Number(infra.currentMonthInfraCost || 0);

          const unspent = Math.max(0, Number((planBudget - currentSpent).toFixed(2)));
          if (unspent <= 0) {
            // No unspent budget to roll over; just reset monthly counters
            transaction.update(channelRef, {
              "infraConfig.currentMonthInfraCost": 0,
              "infraConfig.bandwidthUsedBytesThisMonth": 0,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return;
          }

          const currentRollover = Number(infra.rolloverCreditUSD || 0);
          const newRolloverTotal = Number((currentRollover + unspent).toFixed(2));

          transaction.update(channelRef, {
            "infraConfig.rolloverCreditUSD": newRolloverTotal,
            "infraConfig.currentMonthInfraCost": 0,
            "infraConfig.bandwidthUsedBytesThisMonth": 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Ledger audit trail
          const txDocRef = db().collection("channel_wallet_transactions").doc();
          transaction.set(txDocRef, {
            id: txDocRef.id,
            channelId,
            userId: data.ownerId || data.userId || "",
            amount: unspent,
            trialCreditDeducted: 0,
            rolloverDeducted: 0,
            fundedDeducted: 0,
            revenueDeducted: 0,
            category: "walletTopup",
            description: `Zero-Waste Rollover: $${unspent.toFixed(2)} unspent plan balance preserved (0 cents wasted).`,
            balanceBefore: currentRollover,
            balanceAfter: newRolloverTotal,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            metadata: {
              type: "zero_waste_rollover",
              planBudget,
              currentSpent,
              unspentPreserved: unspent,
              scheduledExecution: event.scheduleTime || new Date().toISOString(),
            },
          });

          totalRolledOverUSD += unspent;
          channelsProcessed++;
        });
      }

      logger.info(
        `[MonthlyRollover] Complete. Rolled over $${totalRolledOverUSD.toFixed(2)} across ${channelsProcessed} channels.`
      );
    } catch (err) {
      logger.error("[MonthlyRollover] Fatal error during monthly rollover execution:", err);
    }
  }
);
