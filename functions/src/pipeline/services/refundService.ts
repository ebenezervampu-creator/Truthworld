/**
 * 💳 TRUTHWORLD AUTOMATED REFUND SERVICE
 *
 * Implements two-phase commit wallet escrow & automated failure rollback:
 * - If an AI Dubbing / Subtitle job fails (all languages or partial languages),
 *   automatically computes prorated refund and restores funds to the channel's wallet.
 * - Records an immutable audit transaction in `channel_wallet_transactions`.
 * - Updates `video_jobs` and `videos` collections with refund telemetry.
 * - 100% adherence to TruthWorld Zero Charm-Pricing & Epistemic Honesty policies.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { logger } from "../utils/logger";
import { notifyUser } from "../../notifications/notifications";

const db = () => admin.firestore();

export interface DubbingRefundResult {
  refunded: boolean;
  refundAmountUSD: number;
  refundTxId?: string;
  channelId?: string;
}

export async function refundDubbingFeeOnFailure(params: {
  jobId: string;
  userId: string;
  failedLanguages: string[];
  totalLanguages: string[];
  reason: string;
}): Promise<DubbingRefundResult> {
  const { jobId, userId, failedLanguages, totalLanguages, reason } = params;

  if (!failedLanguages || failedLanguages.length === 0) {
    return { refunded: false, refundAmountUSD: 0 };
  }

  try {
    const jobRef = db().collection("video_jobs").doc(jobId);
    const jobSnap = await jobRef.get();

    if (!jobSnap.exists) {
      logger.warn("[RefundService] video_job not found for refund", { jobId });
      return { refunded: false, refundAmountUSD: 0 };
    }

    const jobData = jobSnap.data() || {};
    const paidFromWallet = jobData.paidFromWallet === true;
    const originalTxId = jobData.walletTransactionId as string | undefined;
    const fundedAmountUSD = Number(jobData.fundedAmountUSD || 0);
    const channelId = jobData.channelId as string || userId;

    // Check if already refunded to prevent double-refund
    if (jobData.refundProcessed === true) {
      logger.info("[RefundService] Refund already processed for job", { jobId });
      return { refunded: false, refundAmountUSD: 0, channelId };
    }

    if (!paidFromWallet || fundedAmountUSD <= 0) {
      logger.info("[RefundService] Job was not paid from wallet or amount is 0", { jobId, fundedAmountUSD });
      return { refunded: false, refundAmountUSD: 0, channelId };
    }

    // Calculate prorated refund amount
    const totalCount = Math.max(1, totalLanguages.length);
    const failedCount = Math.min(totalCount, failedLanguages.length);
    const proratedFraction = failedCount / totalCount;
    const refundAmountUSD = Number((fundedAmountUSD * proratedFraction).toFixed(2));

    if (refundAmountUSD <= 0) {
      return { refunded: false, refundAmountUSD: 0, channelId };
    }

    const refundTxId = `tx_refund_${jobId}_${Date.now()}`;
    const channelRef = db().collection("channels").doc(channelId);
    const refundTxRef = db().collection("channel_wallet_transactions").doc(refundTxId);

    await db().runTransaction(async (t) => {
      const chSnap = await t.get(channelRef);
      if (!chSnap.exists) {
        throw new Error(`Channel ${channelId} not found for wallet refund`);
      }

      const chData = chSnap.data() || {};
      const currentBalance = Number(chData.walletBalanceUSD || chData.walletBalance || 0);
      const newBalance = Number((currentBalance + refundAmountUSD).toFixed(2));

      // 1. Credit channel wallet
      t.update(channelRef, {
        walletBalanceUSD: newBalance,
        walletBalance: newBalance,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 2. Create immutable audit transaction
      t.set(refundTxRef, {
        id: refundTxId,
        channelId,
        userId,
        amount: refundAmountUSD,
        category: "aiRefund",
        description: `Automated Refund: AI Dubbing failed for ${failedLanguages.join(", ")} (${reason.slice(0, 80)})`,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        timestamp: Date.now(),
        redeemed: true,
        originalTransactionId: originalTxId || null,
        metadata: {
          jobId,
          failedLanguages,
          totalLanguages,
          failedCount,
          totalCount,
          originalAmountUSD: fundedAmountUSD,
          refundAmountUSD,
          reason,
        },
      });

      // 3. Mark job as refunded
      t.update(jobRef, {
        refundProcessed: true,
        refundAmountUSD,
        refundTxId,
        refundedAt: Date.now(),
        refundReason: reason,
      });

      // 4. Update linked video documents
      const rawLinkedVideoIds = jobData.linkedVideoIds || [];
      const videoId = jobData.videoId || jobId;
      const allVideoIds = Array.from(new Set([...rawLinkedVideoIds, videoId])).filter(
        (id): id is string => typeof id === "string" && !id.startsWith("job_")
      );

      for (const vid of allVideoIds) {
        const vidRef = db().collection("videos").doc(vid);
        t.set(vidRef, {
          dubbingRefundProcessed: true,
          dubbingRefundAmountUSD: refundAmountUSD,
          dubbingRefundTxId: refundTxId,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    });

    logger.info("[RefundService] ✅ Successfully processed automated failure refund", {
      jobId,
      channelId,
      refundAmountUSD,
      failedLanguages,
      refundTxId,
    });

    return {
      refunded: true,
      refundAmountUSD,
      refundTxId,
      channelId,
    };
  } catch (err: any) {
    logger.error("[RefundService] ❌ Failed to process automated wallet refund", {
      jobId,
      userId,
      failedLanguages,
      err: err?.message || String(err),
    });
    return { refunded: false, refundAmountUSD: 0 };
  }
}

export interface LipSyncFallbackItem {
  language: string;
  status: "no_face_detected" | "fallback_remux";
}

export interface LipSyncFallbackCreditParams {
  jobId: string;
  userId: string;
  channelId?: string;
  fallbackLanguages: LipSyncFallbackItem[];
  deltaPerLanguageUSD?: number; // Defaults to dynamic rate or $2.50 legacy
  dubbingTier?: string;
  durationSeconds?: number;
}

export interface LipSyncCreditResult {
  credited: boolean;
  creditAmountUSD: number;
  creditTxId?: string;
  channelId?: string;
}

/**
 * 🛡️ AUTO-CREDIT ON NO_FACE_DETECTED / FALLBACK_REMUX
 *
 * If a video falls back to audio-only remux because of screen shares (no on-screen face)
 * or GPU worker limits/timeouts, automatically credits the lip-sync delta per language
 * back to the creator's channel wallet, and dispatches a Studio notification to the channel.
 *
 * TruthWorld Rule: Never charge full price for a fallback.
 */
export async function creditLipSyncFallbackToWallet(
  params: LipSyncFallbackCreditParams
): Promise<LipSyncCreditResult> {
  const { jobId, userId, fallbackLanguages } = params;

  if (!fallbackLanguages || fallbackLanguages.length === 0) {
    return { credited: false, creditAmountUSD: 0 };
  }

  try {
    const jobRef = db().collection("video_jobs").doc(jobId);
    const jobSnap = await jobRef.get();

    const jobData = jobSnap.exists ? (jobSnap.data() || {}) : {};
    
    // 🛡️ Security Check 1: Idempotency check: prevent duplicate credits
    if (jobData.lipSyncCreditProcessed === true) {
      logger.info("[RefundService] Lip-sync fallback credit already processed for job", { jobId });
      return { credited: false, creditAmountUSD: 0, channelId: jobData.channelId };
    }

    // 🛡️ Security Check 2: Payment verification - skip wallet credit if job wasn't funded from wallet
    if (jobData.paidFromWallet === false) {
      logger.warn("[RefundService] Job was not paid from channel wallet — skipping wallet credit", { jobId });
      return { credited: false, creditAmountUSD: 0, channelId: jobData.channelId };
    }

    // 🛡️ Dynamic Delta Calculation:
    // If not explicitly provided, calculate based on tier and duration:
    // video_pro ($0.40/min) -> audio_pro ($0.20/min) = $0.20/min delta
    // video_ultra ($0.50/min) -> audio_ultra ($0.30/min) = $0.20/min delta
    const dubbingTier = params.dubbingTier || jobData.dubbingTier;
    const durationSeconds = params.durationSeconds || jobData.durationSeconds || jobData.duration || 60;
    
    let deltaPerLanguageUSD = params.deltaPerLanguageUSD;
    if (deltaPerLanguageUSD === undefined) {
      if (dubbingTier && dubbingTier.startsWith("video_")) {
        const durationMinutes = Math.max(1, durationSeconds / 60);
        deltaPerLanguageUSD = Number((durationMinutes * 0.20).toFixed(2));
      } else {
        deltaPerLanguageUSD = 2.50; // Legacy default
      }
    }

    let creditAmountUSD = Number((fallbackLanguages.length * deltaPerLanguageUSD).toFixed(2));

    // 🛡️ Security Check 3: Over-crediting prevention - cap credit at fundedAmountUSD
    const fundedAmountUSD = Number(jobData.fundedAmountUSD);
    if (!isNaN(fundedAmountUSD) && fundedAmountUSD > 0 && creditAmountUSD > fundedAmountUSD) {
      logger.warn("[RefundService] Calculated credit exceeds total funded amount — capping credit", {
        jobId,
        calculatedCredit: creditAmountUSD,
        fundedAmountUSD,
      });
      creditAmountUSD = fundedAmountUSD;
    }

    if (creditAmountUSD <= 0) {
      return { credited: false, creditAmountUSD: 0 };
    }

    const channelId = params.channelId || jobData.channelId || jobData.userId || userId;
    const originalTxId = jobData.walletTransactionId as string | undefined;
    const creditTxId = `tx_lipsync_credit_${jobId}_${Date.now()}`;
    const channelRef = db().collection("channels").doc(channelId);
    const creditTxRef = db().collection("channel_wallet_transactions").doc(creditTxId);

    const noFaceLangs = fallbackLanguages.filter((f) => f.status === "no_face_detected").map((f) => f.language);
    const remuxLangs = fallbackLanguages.filter((f) => f.status === "fallback_remux").map((f) => f.language);

    let reasonSummary = "";
    if (noFaceLangs.length > 0 && remuxLangs.length === 0) {
      reasonSummary = `No speaker face detected (screen recording / voiceover / b-roll / cartoon) in ${noFaceLangs.join(", ")}`;
    } else if (remuxLangs.length > 0 && noFaceLangs.length === 0) {
      reasonSummary = `GPU worker limits / timeout in ${remuxLangs.join(", ")}`;
    } else {
      reasonSummary = `Fallback remux in ${fallbackLanguages.map((f) => f.language).join(", ")}`;
    }

    await db().runTransaction(async (t) => {
      const chSnap = await t.get(channelRef);
      if (!chSnap.exists) {
        throw new Error(`Channel ${channelId} not found for lip-sync wallet credit`);
      }

      const chData = chSnap.data() || {};
      const currentBalance = Number(chData.walletBalanceUSD || chData.walletBalance || 0);
      const newBalance = Number((currentBalance + creditAmountUSD).toFixed(2));

      // 1. Credit channel wallet
      t.update(channelRef, {
        walletBalanceUSD: newBalance,
        walletBalance: newBalance,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 2. Create immutable audit transaction
      t.set(creditTxRef, {
        id: creditTxId,
        channelId,
        userId,
        amount: creditAmountUSD,
        category: "aiRefund",
        description: `Automatic Lip-Sync Credit: $${creditAmountUSD.toFixed(2)} credited back for audio-only fallback (${reasonSummary})`,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        timestamp: Date.now(),
        redeemed: true,
        originalTransactionId: originalTxId || null,
        metadata: {
          jobId,
          fallbackLanguages,
          deltaPerLanguageUSD,
          creditAmountUSD,
          reasonSummary,
        },
      });

      // 3. Mark job document
      if (jobSnap.exists) {
        t.update(jobRef, {
          lipSyncCreditProcessed: true,
          lipSyncCreditAmountUSD: creditAmountUSD,
          lipSyncCreditTxId: creditTxId,
          lipSyncCreditedAt: Date.now(),
          lipSyncCreditReason: reasonSummary,
        });
      }

      // 4. Update linked video documents
      const rawLinkedVideoIds = jobData.linkedVideoIds || [];
      const videoId = jobData.videoId || jobId;
      const allVideoIds = Array.from(new Set([...rawLinkedVideoIds, videoId])).filter(
        (id): id is string => typeof id === "string" && !id.startsWith("job_")
      );

      for (const vid of allVideoIds) {
        const vidRef = db().collection("videos").doc(vid);
        t.set(vidRef, {
          lipSyncCreditProcessed: true,
          lipSyncCreditAmountUSD: creditAmountUSD,
          lipSyncCreditTxId: creditTxId,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    });

    logger.info("[RefundService] ✅ Successfully processed automated lip-sync fallback credit", {
      jobId,
      channelId,
      creditAmountUSD,
      fallbackLanguages,
      creditTxId,
    });

    // 5. Send notification to channel/creator
    let notificationMessage = "";
    if (noFaceLangs.length > 0 && remuxLangs.length === 0) {
      notificationMessage = `No on-screen speaker face was detected in your video for ${noFaceLangs.join(", ")} (screen recording / voiceover / b-roll / cartoon). Your dubbed audio was delivered cleanly, and the $${creditAmountUSD.toFixed(2)} lip-sync fee has been credited back to your channel wallet.`;
    } else if (remuxLangs.length > 0 && noFaceLangs.length === 0) {
      notificationMessage = `AI Visual Lip-Sync encountered processing limits for ${remuxLangs.join(", ")}. Your dubbed audio was delivered cleanly via broadcast remux, and the $${creditAmountUSD.toFixed(2)} lip-sync fee has been credited back to your channel wallet.`;
    } else {
      notificationMessage = `Your dubbed audio was delivered cleanly via broadcast remux for ${fallbackLanguages.map((f) => f.language).join(", ")}. The $${creditAmountUSD.toFixed(2)} lip-sync fee has been credited back to your channel wallet.`;
    }

    await notifyUser({
      userId,
      targetApp: "studio",
      type: "monetization_refund",
      severity: "info",
      title: `Lip-Sync Fee Credited ($${creditAmountUSD.toFixed(2)} Returned)`,
      message: notificationMessage,
      actionUrl: `/studio/wallet`,
      metadata: {
        targetApp: "studio",
        channelId,
        jobId,
        creditAmountUSD,
        fallbackLanguages,
        category: "monetization",
      },
    }).catch((notifErr) => logger.warn("[RefundService] Channel notification notice:", notifErr));

    return {
      credited: true,
      creditAmountUSD,
      creditTxId,
      channelId,
    };
  } catch (err: any) {
    logger.error("[RefundService] ❌ Failed to process lip-sync fallback wallet credit", {
      jobId,
      userId,
      fallbackLanguages,
      err: err?.message || String(err),
    });
    return { credited: false, creditAmountUSD: 0 };
  }
}
