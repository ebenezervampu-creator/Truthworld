import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { reconcileChannelSettlement } from "./settlementService";

const db = () => admin.firestore();

// Payout policy constants (industry standard)
const NEW_CHANNEL_HOLD_DAYS = 30;          // 30-day hold on first payout for new channels
const VELOCITY_HOLD_MULTIPLIER = 3;        // Withdraw > 3× 3-month average → hold for review
const MIN_MONTHS_FOR_VELOCITY_CHECK = 2;   // Need at least 2 prior months to compute baseline
export const MIN_AUTO_PAYOUT_THRESHOLD_INR = 100; // Zero-charm minimum monthly auto-payout threshold

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
    memory: "256MiB",
    maxInstances: 2,
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

    // ── 2a. Monthly Payout Schedule Gate (1st Day + 1-Day Grace Period on 2nd) ───
    // Accommodates all global time zones (IST, UTC, and US Americas) so international creators
    // on Day 1 or Day 2 in their local timezone are seamlessly accepted.
    const nowIST = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
    const nowUS = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Los_Angeles" }));
    const nowUTC = new Date();
    const dayIST = nowIST.getDate();
    const dayUTC = nowUTC.getUTCDate();
    const dayUS = nowUS.getDate();

    const isPayoutWindow =
      dayIST === 1 || dayIST === 2 ||
      dayUTC === 1 || dayUTC === 2 ||
      dayUS === 1 || dayUS === 2;

    const bypassScheduleCheck = channelData.allowAnytimePayout === true || data.bypassScheduleCheck === true;
    if (!isPayoutWindow && !bypassScheduleCheck) {
      await reject(
        "Creator revenue withdrawals are only permitted during the monthly payout window (1st of the month, with a 1-day grace period on the 2nd). Any unwithdrawn earnings safely roll over to next month's payout window.",
        `request outside payout window: IST day ${dayIST}, UTC day ${dayUTC}, US day ${dayUS}`
      );
      return;
    }

    // ── 2b. Anti-overdraft & Two-Phase Settlement Gate ──────────────────────
    // Industry Standard: Only cleared earnings (cleared Superchats/Memberships past 7-day hold + finalized monthly Ads/Subs + funded wallet) are withdrawable.
    const adsRev = Number(channelData.adsRevenueTotal || 0);
    const premRev = Number(channelData.premiumSubsRevenueTotal || 0);
    const memRev = Number(channelData.membershipRevenueTotal || 0);
    const superRev = Number(channelData.superchatRevenueTotal || 0);
    const withdrawnTotal = Number(channelData.withdrawnRevenueTotal || 0);
    const walletUSD = Number(channelData.walletBalanceUSD || 0);
    const walletINR = walletUSD * 84.0;

    const clearedRev = Number(channelData.clearedWithdrawableRevenueTotal ?? (adsRev + premRev + memRev + superRev));
    const totalClearedINR = clearedRev + walletINR;
    const availableWithdrawableINR = Math.max(0, totalClearedINR - withdrawnTotal);

    if (Number(amount) > availableWithdrawableINR) {
      await reject(
        `Insufficient cleared withdrawable balance. Requested ₹${Number(amount).toFixed(2)}, but cleared balance available for payout is ₹${availableWithdrawableINR.toFixed(2)}. In-flight earnings remain in the 7-day anti-chargeback clearing window or month-end finalization.`,
        `insufficient cleared balance: requested ₹${amount} > cleared available ₹${availableWithdrawableINR}`
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
        "Identity verification (KYC) is required before withdrawing funds. Please complete your identity verification (PAN / Passport / Government ID).",
        `KYC status: ${channelData?.kycStatus ?? "missing"}`
      );
      return;
    }

    // ── 3b. Authentic View Qualification Gate (Anti-Bot Farming) ──────────────
    // A channel must meet the authentic qualification threshold (minimum 1,000 qualified views
    // and 10 hours / 600 mins watch time on authentic content) to unlock revenue cash withdrawals.
    const isChannelMonetized =
      channelData.isMonetized === true ||
      channelData.monetizationEnabled === true ||
      channelData.monetizationStatus === "active";

    const qualifiedViews = Number(
      channelData.qualifiedViewCount ??
      channelData.metrics?.qualifiedViews ??
      channelData.viewCount ??
      0
    );
    const watchMinutes = Number(
      channelData.totalWatchTimeMinutes ??
      channelData.metrics?.totalWatchTimeMinutes ??
      (Number(channelData.totalWatchTimeSeconds ?? 0) / 60)
    );

    if (!isChannelMonetized && (qualifiedViews < 1000 || watchMinutes < 600)) {
      await reject(
        "Channel has not met authentic view qualification (minimum 1,000 qualified views and 10 hours watch time required for monetization payouts).",
        `unqualified channel: qualifiedViews=${qualifiedViews} < 1000 or watchMinutes=${Math.round(watchMinutes)} < 600`
      );
      return;
    }

    // ── 3c. Bot Click-Farm Anomaly Ratio Check ──────────────────────────────
    // If raw views are high (>= 1,000) but qualified views are < 20% of raw views, hold for bot farm review
    const rawViews = Number(
      channelData.viewCount ??
      channelData.views ??
      channelData.metrics?.totalViews ??
      0
    );
    if (rawViews >= 1000 && qualifiedViews > 0 && (qualifiedViews / rawViews) < 0.20) {
      await hold(
        "Your account is undergoing authentic view verification due to an abnormal ratio of bounced or unverified views. Funds will be reviewed within 7 business days.",
        `bot farm suspected: qualifiedViews ${qualifiedViews} is < 20% of rawViews ${rawViews}`
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

    if (
      channelData.fraudReviewFlag === true ||
      channelData.viewFraudReviewFlag === true ||
      channelData.botViewSuspected === true
    ) {
      await hold(
        "Your account is undergoing a routine revenue integrity review. Funds will be released within 7 business days if no issues are found. No action is required from you.",
        `fraudReviewFlag=${channelData.fraudReviewFlag} | viewFraudReviewFlag=${channelData.viewFraudReviewFlag} | reason: ${channelData.revenueHoldReason ?? "unknown"}`
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
          const currentClearedRev = Number(freshChannelData.clearedWithdrawableRevenueTotal ?? (currentAds + currentPrem + currentMem + currentSuper));
          const currentClearedTotal = currentClearedRev + currentWalletINR;
          const currentAvailable = Math.max(0, currentClearedTotal - currentWithdrawn);

          if (payoutAmount > currentAvailable) {
            throw new Error(`Insufficient cleared balance during atomic debit: requested ₹${payoutAmount} > cleared available ₹${currentAvailable}`);
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
        const isPayPal = paymentMethod === "PayPal";
        const isUpi = paymentMethod === "UPI";
        const methodDesc = isPayPal
          ? "PayPal"
          : (isUpi ? "UPI" : (bankName || "Bank Account"));
        const railDesc = isPayPal
          ? "PayPal Direct Payout"
          : (isUpi ? "UPI Instant Payout" : "NEFT / IMPS / SWIFT Wire");

        await db().collection("notifications").add({
          userId,
          title: "Withdrawal Processing",
          body: `Your withdrawal of ₹${payoutAmount.toFixed(2)} to ${methodDesc} (${accountNumberMasked || ""}) is being processed via ${railDesc}.`,
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

export interface AutoPayoutResult {
  channelsProcessed: number;
  payoutsInitiated: number;
  rolledOverChannels: number;
  skippedNoBankDetails: number;
  skippedBlockedOrUnverified: number;
  totalDisbursedINR: number;
}

/**
 * 🚀 PROCESS MONTHLY AUTO-DISBURSEMENT
 * Core engine for YouTube AdSense-style automatic monthly bank deposits.
 *
 * Rules:
 * 1. Runs on the 1st of every month.
 * 2. Only processes verified monetized channels with autoPayoutEnabled !== false.
 * 3. Reconciles settlements (T+7 holds + monthly statements) first.
 * 4. Verifies cleared withdrawable balance >= ₹100.
 * 5. Pulls saved bank details and posts an idempotent payout_request.
 */
export async function processMonthlyAutoDisbursement(
  options: { dryRun?: boolean; targetChannelId?: string } = {}
): Promise<AutoPayoutResult> {
  const now = new Date();
  const currentMonthKey = now.toISOString().slice(0, 7); // "YYYY-MM"
  const result: AutoPayoutResult = {
    channelsProcessed: 0,
    payoutsInitiated: 0,
    rolledOverChannels: 0,
    skippedNoBankDetails: 0,
    skippedBlockedOrUnverified: 0,
    totalDisbursedINR: 0,
  };

  let channelsQuery: admin.firestore.Query = db().collection("channels");
  if (options.targetChannelId) {
    channelsQuery = db().collection("channels").where(admin.firestore.FieldPath.documentId(), "==", options.targetChannelId);
  } else {
    channelsQuery = channelsQuery.where("monetizationEnabled", "==", true);
  }

  const channelsSnap = await channelsQuery.get();
  if (channelsSnap.empty) {
    logger.info("[AutoPayout] No monetized channels found for auto-disbursement.");
    return result;
  }

  logger.info(`[AutoPayout] Scanning ${channelsSnap.size} channels for monthly disbursement (${currentMonthKey})...`);

  for (const doc of channelsSnap.docs) {
    result.channelsProcessed++;
    const channelId = doc.id;
    const channelData = doc.data() || {};

    // 1. Opt-out check (creator can prefer keeping funds in channel wallet)
    if (channelData.autoPayoutEnabled === false) {
      logger.info(`[AutoPayout] Channel ${channelId} has autoPayoutEnabled === false. Preserving wallet funds.`);
      continue;
    }

    // 2. Identity Verification & Fraud Gate
    if (channelData.kycStatus !== "verified") {
      logger.info(`[AutoPayout] Channel ${channelId} KYC not verified (${channelData.kycStatus ?? "none"}). Skipping.`);
      result.skippedBlockedOrUnverified++;
      continue;
    }

    if (
      channelData.payoutsBlocked === true ||
      channelData.fraudReviewFlag === true ||
      channelData.viewFraudReviewFlag === true
    ) {
      logger.warn(`[AutoPayout] Channel ${channelId} has payouts blocked or fraud flag active. Skipping.`);
      result.skippedBlockedOrUnverified++;
      continue;
    }

    // 3. Reconcile settlement to ensure mature T+7 superchats/memberships and statements are fresh
    try {
      await reconcileChannelSettlement(channelId);
    } catch (recErr) {
      logger.warn(`[AutoPayout] Could not reconcile channel ${channelId} prior to auto-payout:`, recErr);
    }

    // 4. Fetch fresh channel data to compute cleared withdrawable balance
    const freshSnap = await doc.ref.get();
    const freshData = freshSnap.data() || {};

    const adsRev = Number(freshData.adsRevenueTotal || 0);
    const premRev = Number(freshData.premiumSubsRevenueTotal || 0);
    const memRev = Number(freshData.membershipRevenueTotal || 0);
    const superRev = Number(freshData.superchatRevenueTotal || 0);
    const withdrawnTotal = Number(freshData.withdrawnRevenueTotal || 0);
    const walletUSD = Number(freshData.walletBalanceUSD || 0);
    const walletINR = walletUSD * 84.0;

    const clearedRev = Number(freshData.clearedWithdrawableRevenueTotal ?? (adsRev + premRev + memRev + superRev));
    const totalClearedINR = clearedRev + walletINR;
    const availableWithdrawableINR = Math.max(0, totalClearedINR - withdrawnTotal);

    // 5. Zero-charm Minimum Threshold Gate (₹100)
    if (availableWithdrawableINR < MIN_AUTO_PAYOUT_THRESHOLD_INR) {
      logger.info(`[AutoPayout] Channel ${channelId} cleared balance ₹${availableWithdrawableINR.toFixed(2)} < ₹${MIN_AUTO_PAYOUT_THRESHOLD_INR}. Rolling over safely.`);
      result.rolledOverChannels++;
      continue;
    }

    // 6. Idempotency Check — Ensure no payout request already generated this month
    const existingPayoutSnap = await db().collection("payout_requests")
      .where("channelId", "==", channelId)
      .where("month", "==", currentMonthKey)
      .where("isAutoPayout", "==", true)
      .limit(1)
      .get();

    if (!existingPayoutSnap.empty) {
      logger.info(`[AutoPayout] Channel ${channelId} already has an auto-payout for month ${currentMonthKey}. Skipping duplicate.`);
      continue;
    }

    // 7. Resolve Creator Saved Bank Account
    const ownerId = (freshData.ownerId || freshData.userId || "").toString();
    let bankData: any = null;

    // A. Check channel payout_settings
    try {
      const channelBankSnap = await doc.ref.collection("payout_settings").doc("bank_account").get();
      if (channelBankSnap.exists && channelBankSnap.data()?.accountNumber) {
        bankData = channelBankSnap.data();
      }
    } catch (_) {}

    // B. Check user fallback payout_settings
    if (!bankData && ownerId) {
      try {
        const userBankSnap = await db().collection("users").doc(ownerId).collection("payout_settings").doc("bank_account").get();
        if (userBankSnap.exists && userBankSnap.data()?.accountNumber) {
          bankData = userBankSnap.data();
        }
      } catch (_) {}
    }

    // C. Check savedBankAccount field on channel doc
    if (!bankData && freshData.savedBankAccount && freshData.savedBankAccount.accountNumber) {
      bankData = freshData.savedBankAccount;
    }

    if (!bankData || !bankData.accountNumber || !bankData.ifscCode) {
      logger.warn(`[AutoPayout] Channel ${channelId} has ₹${availableWithdrawableINR.toFixed(2)} cleared, but no bank account configured.`);
      result.skippedNoBankDetails++;

      // Send non-technical actionable guidance to creator
      if (ownerId && !options.dryRun) {
        try {
          await db().collection("notifications").add({
            userId: ownerId,
            title: "Bank Account Required for Payout",
            body: `You have ₹${availableWithdrawableINR.toFixed(2)} in cleared earnings ready for monthly auto-payout! Please link your bank account in Studio > Analytics > Revenue to receive direct bank deposits.`,
            type: "monetization_payout",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            data: {
              channelId,
              amount: availableWithdrawableINR,
            },
          });
        } catch (_) {}
      }
      continue;
    }

    // 8. Generate Payout Request (invokes onPayoutRequestCreated for atomic debit & transfer)
    const amountToDisburse = Math.round(availableWithdrawableINR * 100) / 100;
    if (options.dryRun) {
      logger.info(`[AutoPayout] [DRY RUN] Would initiate ₹${amountToDisburse} to ${bankData.bankName} (${bankData.accountNumber}) for channel ${channelId}`);
      result.payoutsInitiated++;
      result.totalDisbursedINR += amountToDisburse;
      continue;
    }

    const payoutRef = db().collection("payout_requests").doc();
    const maskedNumber = bankData.accountNumberMasked || `•••• •••• ${String(bankData.accountNumber).slice(-4)}`;

    await payoutRef.set({
      id: payoutRef.id,
      userId: ownerId,
      channelId,
      channelName: freshData.name || freshData.channelName || freshData.title || "Creator Channel",
      amount: amountToDisburse,
      currency: "INR",
      currencySymbol: "₹",
      paymentMethod: "direct_bank_transfer",
      payoutDestination: "Direct Bank Account (NEFT/IMPS)",
      beneficiaryName: (bankData.accountHolderName || "").trim(),
      bankName: (bankData.bankName || "Direct Bank").trim(),
      accountNumber: (bankData.accountNumber || "").trim(),
      accountNumberMasked: maskedNumber,
      ifscCode: (bankData.ifscCode || "").trim().toUpperCase(),
      accountType: bankData.accountType || "Savings",
      status: "pending",
      isAutoPayout: true,
      payoutSource: "monthly_auto_disbursement",
      month: currentMonthKey,
      bypassScheduleCheck: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    result.payoutsInitiated++;
    result.totalDisbursedINR += amountToDisburse;
    logger.info(`[AutoPayout] Successfully queued auto-payout ${payoutRef.id} of ₹${amountToDisburse} for channel ${channelId} (${bankData.bankName})`);
  }

  return result;
}

/**
 * ⏰ AUTOMATIC MONTHLY PAYOUT SCHEDULER
 * Runs at 06:00 AM IST on the 1st of every month to automatically disburse
 * cleared revenue to verified creators' bank accounts (YouTube AdSense model).
 */
export const autoDisburseMonthlyPayoutsScheduler = onSchedule(
  {
    schedule: "0 6 1 * *",
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    logger.info("[AutoPayoutScheduler] Starting automated monthly creator payout disbursement...");
    try {
      const result = await processMonthlyAutoDisbursement();
      logger.info("[AutoPayoutScheduler] Automated monthly creator payout completed successfully:", result);
    } catch (err) {
      logger.error("[AutoPayoutScheduler] Error during automated monthly payout execution:", err);
    }
  }
);

/**
 * 🛠️ MANUAL AUTO-DISBURSEMENT TRIGGER (Callable)
 * Admin-only utility for running or dry-running the monthly payout disbursement on demand.
 */
export const triggerMonthlyAutoDisbursementManual = onCall(
  { region: "asia-south1", memory: "512MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    const isAdmin = request.auth?.token?.admin === true;
    if (!userId || !isAdmin) {
      throw new HttpsError("permission-denied", "Admin privileges required.");
    }

    const { targetChannelId, dryRun } = (request.data || {}) as { targetChannelId?: string; dryRun?: boolean };

    try {
      const result = await processMonthlyAutoDisbursement({
        targetChannelId,
        dryRun: dryRun === true,
      });
      return { success: true, result };
    } catch (err: any) {
      logger.error("[triggerMonthlyAutoDisbursementManual] Error:", err);
      throw new HttpsError("internal", err?.message || "Failed to trigger auto disbursement.");
    }
  }
);
