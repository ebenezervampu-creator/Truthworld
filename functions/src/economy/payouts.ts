import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

// Payout policy constants (industry standard)
const NEW_CHANNEL_HOLD_DAYS = 30;          // 30-day hold on first payout for new channels
const VELOCITY_HOLD_MULTIPLIER = 3;        // Withdraw > 3× 3-month average → hold for review
const MIN_MONTHS_FOR_VELOCITY_CHECK = 2;   // Need at least 2 prior months to compute baseline

/**
 * 🏦 PROCESS CREATOR PAYOUT REQUEST
 * Triggered automatically when a creator submits a withdrawal request.
 *
 * Defense layers applied:
 * 1. Minimum threshold (₹100)
 * 2. KYC verification required
 * 3. Fraud review flag check (blocks flagged channels)
 * 4. New channel 30-day hold (blocks day-0 cashout)
 * 5. Revenue velocity spike hold (blocks sudden 3× withdrawal attempts)
 */
export const onPayoutRequestCreated = onDocumentCreated(
  {
    document: "payout_requests/{requestId}",
    region: "asia-south1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const requestId = event.params.requestId;
    const { userId, channelId, amount, paymentMethod, beneficiaryName, bankName, accountNumberMasked } = data;

    logger.info(`[Payouts] Request ${requestId} | channel ${channelId} | user ${userId} | ₹${amount} via ${paymentMethod}`);

    const reject = async (reason: string, logMsg: string) => {
      logger.warn(`[Payouts] Rejecting ${requestId}: ${logMsg}`);
      await snap.ref.update({
        status: "rejected",
        rejectReason: reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    };

    const hold = async (reason: string, logMsg: string) => {
      logger.warn(`[Payouts] Placing ${requestId} on hold: ${logMsg}`);
      await snap.ref.update({
        status: "held",
        holdReason: reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    };

    // ── 1. Minimum threshold ─────────────────────────────────────────────────
    if (!amount || Number(amount) < 100) {
      await reject(
        "Minimum withdrawal threshold of ₹100 not met.",
        `amount ₹${amount} < ₹100`
      );
      return;
    }

    // ── 2. Channel & Ownership Verification ──────────────────────────────────
    if (!channelId) {
      await reject("Channel ID is required for creator payouts.", "missing channelId");
      return;
    }

    const channelSnap = await db().collection("channels").doc(channelId).get();
    const channelData = channelSnap.data();
    if (!channelData) {
      await reject("Channel record not found.", "channel not found");
      return;
    }

    // Anti-takeover check: caller must be the authentic channel owner
    const channelOwnerId = channelData.ownerId || channelData.userId;
    if (channelOwnerId !== userId) {
      await reject(
        "Unauthorized withdrawal request. The authenticated account does not match the channel owner.",
        `channelOwnerId ${channelOwnerId} !== userId ${userId}`
      );
      return;
    }

    // Anti-overdraft check: verified spendable balance must cover the requested amount
    const adsRev = Number(channelData.adsRevenueTotal || 0);
    const premRev = Number(channelData.premiumSubsRevenueTotal || 0);
    const memRev = Number(channelData.membershipRevenueTotal || 0);
    const superRev = Number(channelData.superchatRevenueTotal || 0);
    const withdrawnTotal = Number(channelData.withdrawnRevenueTotal || 0);
    const walletUSD = Number(channelData.walletBalanceUSD || 0);
    const walletINR = walletUSD * 84.0;

    const totalCreatorEarnedINR = adsRev + premRev + memRev + superRev + walletINR;
    const availableWithdrawableINR = Math.max(0, totalCreatorEarnedINR - withdrawnTotal);

    if (Number(amount) > availableWithdrawableINR) {
      await reject(
        `Insufficient withdrawable balance. Requested ₹${Number(amount).toFixed(2)}, but available balance is ₹${availableWithdrawableINR.toFixed(2)}.`,
        `insufficient balance: requested ₹${amount} > available ₹${availableWithdrawableINR}`
      );
      return;
    }

    // ── 2b. Custom Channel Viral Surge Withdrawal Hold ──────────────────────
    if (channelData.channelType === "custom") {
      const infra = channelData.infraConfig;
      const usedBytes = Number(infra?.bandwidthUsedBytesThisMonth || 0);
      const quotaBytes = Number(infra?.bandwidthQuotaBytesThisMonth || 0);
      const isSurgeHeld =
        infra?.isWithdrawalHeld === true ||
        (quotaBytes > 0 && usedBytes > quotaBytes);

      if (isSurgeHeld) {
        await hold(
          "TruthWorld has fronted and paid 100% of your viral infrastructure surge costs so your viewers enjoy uninterrupted streaming. Revenue withdrawals are temporarily on hold until your custom channel plan is upgraded to cover the surge bandwidth.",
          `custom channel ${channelId} exceeded bandwidth quota (${usedBytes} > ${quotaBytes}) - withdrawal held pending plan upgrade`
        );
        return;
      }
    }

    // ── 3. KYC must be verified ───────────────────────────────────────────────
    if (channelData.kycStatus !== "verified") {
      await reject(
        "Identity verification (KYC) is required before withdrawing funds. Please complete your PAN and ID verification.",
        `KYC status: ${channelData?.kycStatus ?? "missing"}`
      );
      return;
    }

    // ── 4. Fraud review flag — blocks confirmed or suspected fraud ─────────
      if (channelData.payoutsBlocked === true) {
        await reject(
          channelData.payoutsBlockedReason ||
          "Payouts are currently blocked on this account. Please contact support.",
          "payoutsBlocked=true (confirmed fraud)"
        );
        return;
      }

      if (channelData.fraudReviewFlag === true) {
        await hold(
          "Your account is undergoing a routine revenue integrity review. Funds will be released within 7 business days if no issues are found. No action is required from you.",
          `fraudReviewFlag=true | reason: ${channelData.revenueHoldReason ?? "unknown"}`
        );
        return;
      }

      // ── 4. New channel 30-day hold ────────────────────────────────────────
      const channelCreatedAt = channelData.createdAt?.toMillis?.() ?? Date.now();
      const channelAgeDays = (Date.now() - channelCreatedAt) / (1000 * 60 * 60 * 24);
      if (channelAgeDays < NEW_CHANNEL_HOLD_DAYS) {
        const daysRemaining = Math.ceil(NEW_CHANNEL_HOLD_DAYS - channelAgeDays);
        await hold(
          `New creator accounts require a ${NEW_CHANNEL_HOLD_DAYS}-day review period before the first withdrawal. Your funds will be available in approximately ${daysRemaining} day${daysRemaining !== 1 ? "s" : ""}. This is standard policy to protect the creator ecosystem.`,
          `channel age ${Math.round(channelAgeDays)} days < ${NEW_CHANNEL_HOLD_DAYS} day hold`
        );
        return;
      }

      // ── 5. Revenue velocity spike check ──────────────────────────────────
      try {
        const currentMonth = new Date().toISOString().slice(0, 7);
        const statementsSnap = await db().collection("revenue_statements")
          .where("channelId", "==", channelId)
          .orderBy("month", "desc")
          .limit(4)
          .get();

        const statements = statementsSnap.docs.map(d => d.data());
        // Exclude current month — use prior months only for baseline
        const priorStatements = statements.filter(s => s.month !== currentMonth);

        if (priorStatements.length >= MIN_MONTHS_FOR_VELOCITY_CHECK) {
          const avgPriorWithdrawable = priorStatements.reduce(
            (sum, s) => sum + Number(s.withdrawableShare || 0), 0
          ) / priorStatements.length;

          if (
            avgPriorWithdrawable > 0 &&
            Number(amount) > VELOCITY_HOLD_MULTIPLIER * avgPriorWithdrawable
          ) {
            await hold(
              `This withdrawal (₹${Number(amount).toFixed(2)}) is significantly higher than your recent monthly average (₹${avgPriorWithdrawable.toFixed(2)}). It has been flagged for a brief review to ensure account security. Funds will be released within 7 business days.`,
              `velocity spike: ₹${amount} > ${VELOCITY_HOLD_MULTIPLIER}× avg ₹${avgPriorWithdrawable.toFixed(2)}`
            );
            return;
          }
        }
      } catch (velErr) {
        // Non-blocking — if velocity check fails, allow payout to proceed
        logger.warn(`[Payouts] Velocity check failed for ${channelId}:`, velErr);
      }

    try {
      // ── 6. All checks passed — schedule payout & debit balance atomically ──
      const transferRef = `TW-PAYOUT-${requestId.slice(0, 8).toUpperCase()}`;
      const payoutAmount = Number(amount);

      let latestStmtRef: admin.firestore.DocumentReference | null = null;
      if (channelId) {
        try {
          const stmtSnap = await db().collection("revenue_statements")
            .where("channelId", "==", channelId)
            .orderBy("month", "desc")
            .limit(1)
            .get();
          if (!stmtSnap.empty) {
            latestStmtRef = stmtSnap.docs[0].ref;
          }
        } catch (stmtErr) {
          logger.warn(`[Payouts] Could not locate latest revenue_statement for ${channelId}:`, stmtErr);
        }
      }

      await db().runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(snap.ref);
        const currentReqStatus = freshSnap.data()?.status;
        if (!freshSnap.exists || (currentReqStatus && currentReqStatus !== "pending")) {
          throw new Error(`Payout request ${requestId} is no longer pending (status: ${currentReqStatus})`);
        }

        if (channelId) {
          const channelRef = db().collection("channels").doc(channelId);
          const freshChannelSnap = await transaction.get(channelRef);
          if (!freshChannelSnap.exists) {
            throw new Error(`Channel ${channelId} not found during payout transaction`);
          }
          const freshChannelData = freshChannelSnap.data() || {};
          const currentWithdrawn = Number(freshChannelData.withdrawnRevenueTotal || 0);
          const currentAds = Number(freshChannelData.adsRevenueTotal || 0);
          const currentPrem = Number(freshChannelData.premiumSubsRevenueTotal || 0);
          const currentMem = Number(freshChannelData.membershipRevenueTotal || 0);
          const currentSuper = Number(freshChannelData.superchatRevenueTotal || 0);
          const currentWalletUSD = Number(freshChannelData.walletBalanceUSD || 0);
          const currentWalletINR = currentWalletUSD * 84.0;
          const currentTotal = currentAds + currentPrem + currentMem + currentSuper + currentWalletINR;
          const currentAvailable = Math.max(0, currentTotal - currentWithdrawn);

          if (payoutAmount > currentAvailable) {
            throw new Error(`Insufficient balance during atomic debit: requested ₹${payoutAmount} > available ₹${currentAvailable}`);
          }

          transaction.set(
            channelRef,
            {
              withdrawnRevenueTotal: admin.firestore.FieldValue.increment(payoutAmount),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          const txRef = db().collection("channel_wallet_transactions").doc(requestId);
          transaction.set(txRef, {
            id: requestId,
            channelId,
            userId: userId || "",
            amount: payoutAmount,
            category: "payoutWithdrawal",
            description: `Payout Withdrawal (Ref: ${transferRef})`,
            revenueDeducted: payoutAmount,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: "processing",
          }, { merge: true });

          if (latestStmtRef) {
            transaction.update(latestStmtRef, {
              paidOutShare: admin.firestore.FieldValue.increment(payoutAmount),
              withdrawableShare: admin.firestore.FieldValue.increment(-payoutAmount),
              payoutStatus: "processing",
              updatedAt: Date.now(),
            });
          }
        }

        transaction.update(snap.ref, {
          status: "processing",
          transferReference: transferRef,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      if (userId) {
        await db().collection("notifications").add({
          userId,
          title: "Withdrawal Processing",
          body: `Your withdrawal of ₹${payoutAmount.toFixed(2)} to ${bankName || "Bank Account"} (${accountNumberMasked || ""}) is being processed via NEFT/IMPS.`,
          type: "monetization_payout",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          data: {
            requestId,
            channelId,
            amount: payoutAmount,
            transferReference: transferRef,
          },
        });
      }

      logger.info(`[Payouts] Scheduled payout ${transferRef} for ${beneficiaryName || "Creator"} — ₹${payoutAmount}`);
    } catch (err: any) {
      logger.error(`[Payouts] Error processing payout request ${requestId}:`, err);
    }
  }
);
