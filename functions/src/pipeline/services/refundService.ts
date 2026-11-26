/**
 * 💳 TRUTHWORLD AUTOMATED REFUND SERVICE
 *
 * Every paid dubbing / subtitle order is recorded in `dubbing_orders/{orderId}` (orderId = the wallet
 * transaction that paid it) with the price of each language. When languages fail, each failed
 * language of that order is refunded at the price paid for it, once:
 * - the check "already refunded?" and the wallet credit happen in the same Firestore transaction,
 *   so two concurrent refunds can't both pay;
 * - refunds are tracked per language, so a second failure on the same order refunds only the
 *   languages not refunded yet, and a later order on the same video is refunded on its own;
 * - an immutable audit entry is written to `channel_wallet_transactions`.
 *
 * Jobs paid before order records existed fall back to the earlier per-job proration (now also checked
 * inside the transaction).
 * 100% adherence to TruthWorld Zero Charm-Pricing & Epistemic Honesty policies.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { logger } from "../utils/logger";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import { filterVideoIds } from "../../utils/videosCollectionGuard";

const db = () => admin.firestore();

export const DUBBING_ORDERS = "dubbing_orders";

export interface DubbingRefundResult {
  refunded: boolean;
  refundAmountUSD: number;
  refundTxId?: string;
  channelId?: string;
  refundedLanguages?: string[];
}

export interface DubbingOrderRecord {
  orderId: string;
  jobId: string;
  videoId: string;
  userId: string;
  /** Channel whose wallet was debited (and is credited on refund). */
  channelId: string;
  paidUSD: number;
  dubbingUSD: number;
  subtitleUSD: number;
  /** Languages this order paid for (normalized codes). */
  languages: string[];
  /** Price paid per language (normalized code → USD). Sums to paidUSD. */
  priceByLanguage: Record<string, number>;
  refundedByLanguage: Record<string, number>;
  refundedUSD: number;
  createdAt: number;
  source: string;
}

const cents = (usd: number) => Math.round(usd * 100);
const usd = (c: number) => Number((c / 100).toFixed(2));

/**
 * Price per language for one order, in whole cents, summing exactly to the amount paid.
 * Dubbing languages use the charged per-language price when known; otherwise the dubbing amount is
 * split evenly. Subtitle-only languages share the subtitle amount evenly. Remainders go to the
 * first languages (largest-remainder), so the parts always add up to what was paid.
 */
export function buildOrderPrices(params: {
  dubbingLanguages: string[];
  dubbingUSD: number;
  dubbingPriceByLanguage?: Record<string, number>;
  subtitleLanguages: string[];
  subtitleUSD: number;
}): Record<string, number> {
  const out: Record<string, number> = {};
  const split = (langs: string[], totalCents: number, weights?: number[]) => {
    if (langs.length === 0 || totalCents <= 0) return;
    const w = weights && weights.every((x) => x >= 0) && weights.some((x) => x > 0) ? weights : langs.map(() => 1);
    const wSum = w.reduce((a, b) => a + b, 0);
    const raw = w.map((x) => (totalCents * x) / wSum);
    const base = raw.map(Math.floor);
    let rem = totalCents - base.reduce((a, b) => a + b, 0);
    const order = raw.map((r, i) => ({ i, f: r - Math.floor(r) })).sort((a, b) => b.f - a.f || a.i - b.i);
    for (let k = 0; rem > 0; k = (k + 1) % order.length, rem--) base[order[k].i]++;
    langs.forEach((l, i) => { out[l] = usd((cents(out[l] ?? 0)) + base[i]); });
  };

  const dub = Array.from(new Set(params.dubbingLanguages.map((l) => normalizeLanguageCode(l)).filter(Boolean)));
  const priceMap: Record<string, number> = {};
  for (const [k, v] of Object.entries(params.dubbingPriceByLanguage || {})) priceMap[normalizeLanguageCode(k)] = Number(v) || 0;
  const weights = dub.every((l) => typeof priceMap[l] === "number") ? dub.map((l) => priceMap[l]) : undefined;
  split(dub, cents(params.dubbingUSD), weights);

  const subs = Array.from(new Set(params.subtitleLanguages.map((l) => normalizeLanguageCode(l)).filter(Boolean)));
  split(subs, cents(params.subtitleUSD));
  return out;
}

/**
 * The refund owed per failed language of an order: the price paid for it, minus anything already
 * refunded for it. Languages the order did not pay for get nothing. When the refund completes the
 * order, the last language takes any rounding remainder so total refunds never exceed the payment
 * and a fully failed order is refunded exactly.
 */
export function computeLanguageRefunds(
  order: Pick<DubbingOrderRecord, "paidUSD" | "priceByLanguage" | "refundedByLanguage" | "refundedUSD">,
  failedLanguages: string[]
): { byLanguage: Record<string, number>; totalUSD: number } {
  const byLanguage: Record<string, number> = {};
  const failed = Array.from(new Set(failedLanguages.map((l) => normalizeLanguageCode(l)).filter(Boolean)));
  let totalCents = 0;
  for (const lang of failed) {
    const price = order.priceByLanguage[lang];
    if (typeof price !== "number" || price <= 0) continue;
    const owed = cents(price) - cents(order.refundedByLanguage?.[lang] ?? 0);
    if (owed <= 0) continue;
    byLanguage[lang] = usd(owed);
    totalCents += owed;
  }
  const remainingCents = cents(order.paidUSD) - cents(order.refundedUSD || 0);
  if (totalCents > remainingCents) {
    // Never refund more than is left on the order.
    totalCents = Math.max(0, remainingCents);
  } else {
    const allLangs = Object.keys(order.priceByLanguage);
    const willBeFull = allLangs.every((l) =>
      cents(order.refundedByLanguage?.[l] ?? 0) + cents(byLanguage[l] ?? 0) >= cents(order.priceByLanguage[l])
    );
    if (willBeFull && totalCents > 0) totalCents = remainingCents;
  }
  return { byLanguage, totalUSD: usd(totalCents) };
}

/** Records a paid order and points the job at it. Called right after the wallet debit. */
export async function recordDubbingOrder(order: Omit<DubbingOrderRecord, "refundedByLanguage" | "refundedUSD">): Promise<void> {
  const record: DubbingOrderRecord = { ...order, refundedByLanguage: {}, refundedUSD: 0 };
  await db().collection(DUBBING_ORDERS).doc(order.orderId).set(record, { merge: true });
}

export async function refundDubbingFeeOnFailure(params: {
  jobId: string;
  userId: string;
  failedLanguages: string[];
  /** Kept for older callers; only the legacy (pre-order-record) path uses it. */
  totalLanguages: string[];
  reason: string;
  /** Defaults to the job's current order. */
  orderId?: string;
}): Promise<DubbingRefundResult> {
  const { jobId, userId, failedLanguages, reason } = params;

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
    const orderId = params.orderId || (jobData.currentDubbingOrderId as string | undefined);

    if (orderId) {
      return await refundOrderLanguages({ orderId, jobId, jobData, userId, failedLanguages, reason });
    }
    return await legacyJobRefund({ jobId, jobData, userId, failedLanguages, totalLanguages: params.totalLanguages, reason });
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

function linkedVideoIds(jobData: Record<string, any>, jobId: string): string[] {
  const raw = jobData.linkedVideoIds || [];
  const videoId = jobData.videoId || jobId;
  return Array.from(new Set([...raw, videoId])).filter(
    (id): id is string => typeof id === "string" && !id.startsWith("job_")
  );
}

async function refundOrderLanguages(p: {
  orderId: string;
  jobId: string;
  jobData: Record<string, any>;
  userId: string;
  failedLanguages: string[];
  reason: string;
}): Promise<DubbingRefundResult> {
  const orderRef = db().collection(DUBBING_ORDERS).doc(p.orderId);
  const jobRef = db().collection("video_jobs").doc(p.jobId);

  const result = await db().runTransaction(async (t) => {
    const orderSnap = await t.get(orderRef);
    if (!orderSnap.exists) {
      return { refunded: false, refundAmountUSD: 0 } as DubbingRefundResult;
    }
    const order = orderSnap.data() as DubbingOrderRecord;
    const refund = computeLanguageRefunds(order, p.failedLanguages);
    if (refund.totalUSD <= 0) {
      return { refunded: false, refundAmountUSD: 0, channelId: order.channelId } as DubbingRefundResult;
    }

    const channelRef = db().collection("channels").doc(order.channelId);
    const chSnap = await t.get(channelRef);
    if (!chSnap.exists) throw new Error(`Channel ${order.channelId} not found for wallet refund`);
    const chData = chSnap.data() || {};
    const currentBalance = Number(chData.walletBalanceUSD || chData.walletBalance || 0);
    const newBalance = Number((currentBalance + refund.totalUSD).toFixed(2));

    const validLinkedVids = p.jobData.currentDubbingOrderId === p.orderId
      ? filterVideoIds(linkedVideoIds(p.jobData, p.jobId), "[RefundService:Order]")
      : [];
    const existingVideoRefs: FirebaseFirestore.DocumentReference[] = [];
    if (validLinkedVids.length > 0) {
      const vSnaps = await Promise.all(
        validLinkedVids.map((vid) => t.get(db().collection("videos").doc(vid)))
      );
      vSnaps.forEach((s) => {
        if (s.exists) existingVideoRefs.push(s.ref);
      });
    }

    const refundedLanguages = Object.keys(refund.byLanguage);
    const refundTxId = `tx_refund_${p.orderId}_${refundedLanguages.join("-")}_${Date.now()}`.slice(0, 1400);
    const refundTxRef = db().collection("channel_wallet_transactions").doc(refundTxId);
    const newRefunded: Record<string, number> = { ...(order.refundedByLanguage || {}) };
    for (const [l, a] of Object.entries(refund.byLanguage)) newRefunded[l] = usd(cents(newRefunded[l] ?? 0) + cents(a));
    const refundedUSD = usd(cents(order.refundedUSD || 0) + cents(refund.totalUSD));
    const fullyRefunded = cents(refundedUSD) >= cents(order.paidUSD);

    t.update(channelRef, {
      walletBalanceUSD: newBalance,
      walletBalance: newBalance,
      updatedAt: FieldValue.serverTimestamp(),
    });
    t.set(refundTxRef, {
      id: refundTxId,
      channelId: order.channelId,
      userId: p.userId,
      amount: refund.totalUSD,
      category: "aiRefund",
      description: `Refund: dubbing could not be delivered for ${refundedLanguages.join(", ")}`,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      timestamp: Date.now(),
      redeemed: true,
      originalTransactionId: p.orderId,
      metadata: {
        jobId: p.jobId,
        orderId: p.orderId,
        refundByLanguage: refund.byLanguage,
        originalAmountUSD: order.paidUSD,
        refundAmountUSD: refund.totalUSD,
        reason: p.reason,
      },
    });
    t.update(orderRef, {
      refundedByLanguage: newRefunded,
      refundedUSD,
      lastRefundAt: Date.now(),
      lastRefundReason: p.reason.slice(0, 300),
    });
    // Job / video fields describe the job's current order (kept for existing readers).
    if (p.jobData.currentDubbingOrderId === p.orderId) {
      t.update(jobRef, {
        refundProcessed: fullyRefunded,
        refundAmountUSD: refundedUSD,
        refundTxId,
        refundedAt: Date.now(),
        refundReason: p.reason,
        refundedLanguages: Object.keys(newRefunded),
      });
      for (const vRef of existingVideoRefs) {
        t.set(vRef, {
          dubbingRefundProcessed: true,
          dubbingRefundAmountUSD: refundedUSD,
          dubbingRefundTxId: refundTxId,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }
    return {
      refunded: true,
      refundAmountUSD: refund.totalUSD,
      refundTxId,
      channelId: order.channelId,
      refundedLanguages,
    } as DubbingRefundResult;
  });

  if (result.refunded) {
    logger.info("[RefundService] ✅ Refunded failed languages of order", {
      jobId: p.jobId,
      orderId: p.orderId,
      refundAmountUSD: result.refundAmountUSD,
      refundedLanguages: result.refundedLanguages,
    });
  } else {
    logger.info("[RefundService] Nothing left to refund for these languages", { jobId: p.jobId, orderId: p.orderId, failedLanguages: p.failedLanguages });
  }
  return result;
}

/** Jobs paid before order records existed: prorated over the job, refunded at most once. */
async function legacyJobRefund(p: {
  jobId: string;
  jobData: Record<string, any>;
  userId: string;
  failedLanguages: string[];
  totalLanguages: string[];
  reason: string;
}): Promise<DubbingRefundResult> {
  const { jobId, jobData, userId, failedLanguages, totalLanguages, reason } = p;
  const paidFromWallet = jobData.paidFromWallet === true;
  const originalTxId = jobData.walletTransactionId as string | undefined;
  const fundedAmountUSD = Number(jobData.fundedAmountUSD || 0);
  const channelId = (jobData.channelId as string) || userId;

  if (!paidFromWallet || fundedAmountUSD <= 0) {
    logger.info("[RefundService] Job was not paid from wallet or amount is 0", { jobId, fundedAmountUSD });
    return { refunded: false, refundAmountUSD: 0, channelId };
  }

  const totalCount = Math.max(1, totalLanguages.length);
  const failedCount = Math.min(totalCount, failedLanguages.length);
  const refundAmountUSD = Number((fundedAmountUSD * (failedCount / totalCount)).toFixed(2));
  if (refundAmountUSD <= 0) return { refunded: false, refundAmountUSD: 0, channelId };

  const refundTxId = `tx_refund_${jobId}_${Date.now()}`;
  const jobRef = db().collection("video_jobs").doc(jobId);
  const channelRef = db().collection("channels").doc(channelId);
  const refundTxRef = db().collection("channel_wallet_transactions").doc(refundTxId);

  const done = await db().runTransaction(async (t) => {
    // Checked inside the transaction so two concurrent refunds cannot both pay.
    const freshJob = await t.get(jobRef);
    if (freshJob.data()?.refundProcessed === true) return false;
    const chSnap = await t.get(channelRef);
    if (!chSnap.exists) throw new Error(`Channel ${channelId} not found for wallet refund`);
    const chData = chSnap.data() || {};
    const currentBalance = Number(chData.walletBalanceUSD || chData.walletBalance || 0);
    const newBalance = Number((currentBalance + refundAmountUSD).toFixed(2));

    const validLinkedVids = filterVideoIds(linkedVideoIds(jobData, jobId), "[RefundService:Legacy]");
    const existingVideoRefs: FirebaseFirestore.DocumentReference[] = [];
    if (validLinkedVids.length > 0) {
      const vSnaps = await Promise.all(
        validLinkedVids.map((vid) => t.get(db().collection("videos").doc(vid)))
      );
      vSnaps.forEach((s) => {
        if (s.exists) existingVideoRefs.push(s.ref);
      });
    }

    t.update(channelRef, { walletBalanceUSD: newBalance, walletBalance: newBalance, updatedAt: FieldValue.serverTimestamp() });
    t.set(refundTxRef, {
      id: refundTxId,
      channelId,
      userId,
      amount: refundAmountUSD,
      category: "aiRefund",
      description: `Refund: dubbing could not be delivered for ${failedLanguages.join(", ")}`,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      timestamp: Date.now(),
      redeemed: true,
      originalTransactionId: originalTxId || null,
      metadata: { jobId, failedLanguages, totalLanguages, failedCount, totalCount, originalAmountUSD: fundedAmountUSD, refundAmountUSD, reason },
    });
    t.update(jobRef, { refundProcessed: true, refundAmountUSD, refundTxId, refundedAt: Date.now(), refundReason: reason });
    for (const vRef of existingVideoRefs) {
      t.set(vRef, {
        dubbingRefundProcessed: true,
        dubbingRefundAmountUSD: refundAmountUSD,
        dubbingRefundTxId: refundTxId,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return true;
  });

  if (!done) {
    logger.info("[RefundService] Refund already processed for job", { jobId });
    return { refunded: false, refundAmountUSD: 0, channelId };
  }
  logger.info("[RefundService] ✅ Successfully processed automated failure refund (legacy job)", { jobId, channelId, refundAmountUSD, failedLanguages, refundTxId });
  return { refunded: true, refundAmountUSD, refundTxId, channelId, refundedLanguages: failedLanguages };
}
