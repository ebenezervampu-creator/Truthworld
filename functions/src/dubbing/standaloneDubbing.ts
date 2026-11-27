import { DUBBING_REGION } from "../config/regions";
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { isCallableAdmin } from "../utils/auth";
import {
  DubbingJob,
  DubbingWallet,
  DubbingWalletTransaction,
  DubbingMode,
  DubbingDemuxOptions,
  DubbingSpeakerProfile,
} from "./types";
import { checkDubbingRequest, dubbingLanguageMessage } from "../pipeline/services/dubbing-launch-languages";
import {
  channelDubbingDiscountPercent,
  DubbingQuote,
} from "../pipeline/services/dubbing-pricing";
import { characterPricingEnabled, quoteFromTranscript } from "../pipeline/services/dubbing-quote-service";
import { recordDubbingOrder, buildOrderPrices, refundDubbingFeeOnFailure } from "../pipeline/services/refundService";
import { normalizeLanguageCode } from "../shared/language-normalizer";
import { dubbingEditorService } from "../pipeline/services/dubbingEditorService";
import { parseAnyStorageUrl } from "../pipeline/services/media";
import { probeStudioMediaDurationMs } from "./studio-media-probe";
import { ExecutionPlan } from "../pipeline/types";
import {
  decideStudioVoiceCloning,
  decideStudioDuration,
  studioCharge,
  studioSegmentIndex,
  isDubbedVideoUrl,
} from "./studio-order";
import { isVideoId, safeMergeExistingVideo } from "../utils/videosCollectionGuard";
import { audioIdentityService } from "../pipeline/services/audio-identity";
import { saveDubbingReportArtifact, saveTranslationArtifact } from "../pipeline/services/dubbing-report";

const db = () => admin.firestore();
const REGION = DUBBING_REGION;
const CREATE_JOB_REGION = DUBBING_REGION;
export const STUDIO_JOBS_COLLECTION = "studio_dubbing_jobs";

/**
 * 🔍 Verifies whether a Google Cloud Storage object actually exists on disk.
 */
export async function checkStorageObjectExists(
  urlOrPath?: string | null,
  bucketOverride?: any
): Promise<boolean> {
  if (!urlOrPath || typeof urlOrPath !== "string" || urlOrPath.trim().length === 0) {
    return false;
  }
  try {
    const trimmed = urlOrPath.trim();
    if (bucketOverride) {
      const [exists] = await bucketOverride.file(trimmed).exists();
      return exists;
    }
    if (trimmed.startsWith("gs://")) {
      const parts = trimmed.substring(5).split("/");
      const bucketName = parts[0];
      const filePath = parts.slice(1).join("/");
      const [exists] = await admin.storage().bucket(bucketName).file(filePath).exists();
      return exists;
    }
    const info = parseAnyStorageUrl(trimmed);
    if (!info) return false;
    const bucket = admin.storage().bucket(info.bucketName || undefined);
    const [exists] = await bucket.file(info.filePath).exists();
    return exists;
  } catch (err) {
    logger.warn("[Dubbing:checkStorageObjectExists] Notice inspecting object existence", {
      urlOrPath,
      error: String(err),
    });
    return false;
  }
}

/**
 * 🎁 Claim Free Dubbing Credits.
 * Per TruthWorld platform policy (.agents/rules/engineering.md:70 and .agents/rules/project.md:47):
 * Promotional creator trial credits are completely discontinued to prevent promotional farming.
 */
export const claimFreeDubbingCredits = onCall(
  { cors: true, region: REGION, memory: "256MiB", maxInstances: 10 },
  async () => {
    return {
      success: false,
      message: "Promotional creator trial credits have been discontinued to ensure platform integrity.",
    };
  }
);

/**
 * 💳 Retrieve user's Dubbing Wallet status and history.
 * Unconditionally initializes with clean 0-credit balance (zero promotional free credit grant).
 */
export const getDubbingWallet = onCall(
  { cors: true, region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Please sign in to access your wallet.");
    }

    const doc = await db().collection("dubbing_wallets").doc(uid).get();
    if (!doc.exists) {
      const initialWallet: DubbingWallet = {
        userId: uid,
        balanceCredits: 0,
        balanceUsd: 0.0,
        trialClaimed: false,
        totalCharactersUsed: 0,
        totalSpentUsd: 0,
        transactions: [],
        updatedAt: Date.now(),
      };
      await db().collection("dubbing_wallets").doc(uid).set(initialWallet);
      return initialWallet;
    }

    const data = doc.data() as DubbingWallet;
    let currentWallet = data;

    // Check if user owns a channel with freeDubbingCredits or admin free waiver
    try {
      const chanSnap = await db()
        .collection("channels")
        .where("ownerId", "==", uid)
        .limit(1)
        .get();

      if (!chanSnap.empty) {
        const cData = chanSnap.docs[0].data();
        const chanCredits = Number(cData?.freeDubbingCredits || 0);
        const isFree =
          cData?.isDubbingFree === true ||
          cData?.dubbingDiscountType === "free" ||
          Number(cData?.dubbingDiscountPercent || 0) >= 100;
        const discountPct = Number(cData?.dubbingDiscountPercent || 0);

        if (chanCredits > 0 || isFree || discountPct > 0) {
          const now = Date.now();
          const hasGrantTx = (currentWallet.transactions || []).some((t) =>
            t.description?.includes("Super Admin Grant to Channel")
          );

          if (!hasGrantTx || (isFree && !currentWallet.isDubbingFree)) {
            const grantTx: DubbingWalletTransaction = {
              id: `tx_chan_sync_${now}`,
              type: "trial_credit",
              amountCredits: chanCredits,
              amountUsd: 0.0,
              description: `Super Admin Grant to Channel (${chanCredits.toLocaleString()} characters)`,
              timestamp: now,
            };

            currentWallet = {
              ...currentWallet,
              balanceCredits: Math.max(
                Number(currentWallet.balanceCredits || 0),
                Number(currentWallet.balanceCredits || 0) + (hasGrantTx ? 0 : chanCredits)
              ),
              isDubbingFree: isFree || currentWallet.isDubbingFree,
              specialDiscountPercent: Math.max(
                discountPct,
                Number(currentWallet.specialDiscountPercent || 0)
              ),
              specialDiscountType: isFree
                ? "free"
                : (cData?.dubbingDiscountType || currentWallet.specialDiscountType || "none"),
              transactions: hasGrantTx
                ? currentWallet.transactions
                : [grantTx, ...(currentWallet.transactions || [])],
              updatedAt: now,
            };
            await db()
              .collection("dubbing_wallets")
              .doc(uid)
              .set(currentWallet, { merge: true });
          }
        }
      }
    } catch (e) {
      logger.warn("[Dubbing:getDubbingWallet] Notice while syncing channel credits", { uid, error: e });
    }

    return currentWallet;
  }
);

/**
 * 🎙️ Create a Dubbing Job with Real Pipeline & Channel Wallet Wiring.
 * Option B: Charges the creator's channel wallet through the same order path
 * as triggerVideoAIFeatures (dubbingCharge, dubbing_orders ledger, per-language refunds).
 * Writes the Studio job to studio_dubbing_jobs/{id}, referencing videoId and the pipeline jobId.
 */
export const createDubbingJob = onCall(
  { cors: true, region: CREATE_JOB_REGION, memory: "512MiB", maxInstances: 10, secrets: ["ELEVENLABS_API_KEY"] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Please sign in to start dubbing.");
    }

    const token = (request.auth?.token || {}) as Record<string, any>;
    const isAdmin =
      token.admin === true ||
      token.role === "admin" ||
      token.role === "super_admin" ||
      token.isDirector === true ||
      token.isSuperAdmin === true;

    const {
      title = "Untitled Dubbing Project",
      mode = "dubbing",
      sourceMediaUrl,
      sourceMediaType = "video",
      durationSeconds = 60,
      sourceLanguage = "en",
      targetLanguages = ["te"],
      demuxOptions = {
        isolateVocals: true,
        preserveBgm: true,
        bgmDuckLevelPercent: 25,
        noiseSuppression: true,
      },
      // Voice cloning is never on by default: the creator must turn it on in the app and confirm consent.
      voiceCloningEnabled = false,
      voiceCloneConsent = false,
      saveVoiceProfile = false,
      speakers = [],
      twoStageReviewEnabled = true,
      publishToTruthworld = false,
      videoId: requestedVideoId,
      channelId: requestedChannelId,
      cashfreeOrderId: rawCashfreeOrderId,
      walletSource: requestedWalletSource,
    } = request.data || {};

    if (!sourceMediaUrl && !requestedVideoId) {
      throw new HttpsError("invalid-argument", "Please provide a valid source video or audio URL.");
    }
    if (!targetLanguages || !Array.isArray(targetLanguages) || targetLanguages.length === 0) {
      throw new HttpsError("invalid-argument", "Please select at least one target language.");
    }

    // Launch languages check (pipeline/services/dubbing-launch-languages.ts):
    // Refuses unavailable languages BEFORE anything is priced or charged.
    if (mode !== "subtitles_only") {
      const langCheck = checkDubbingRequest(sourceLanguage, targetLanguages);
      if (!langCheck.ok) {
        throw new HttpsError("invalid-argument", dubbingLanguageMessage(langCheck));
      }
    }

    // Voice cloning only when explicitly selected with consent (refused before anything is charged).
    const cloning = decideStudioVoiceCloning({
      voiceCloningEnabled: mode === "subtitles_only" ? false : voiceCloningEnabled,
      voiceCloneConsent,
      saveVoiceProfile,
    });
    if (!cloning.ok) {
      throw new HttpsError("failed-precondition", cloning.message);
    }

    const firestore = db();

    // 1. Resolve Optional Creator Channel (required only for channel video / Feed Publish)
    let resolvedChannelId: string | null =
      typeof requestedChannelId === "string" && requestedChannelId.trim().length > 0
        ? requestedChannelId.trim()
        : null;
    if (!resolvedChannelId) {
      try {
        const userChanSnap = await firestore
          .collection("channels")
          .where("ownerId", "==", uid)
          .limit(1)
          .get();
        if (!userChanSnap.empty) {
          resolvedChannelId = userChanSnap.docs[0].id;
        }
      } catch (_) {}
    }

    const channelRequired =
      Boolean(requestedChannelId) || Boolean(requestedVideoId) || Boolean(publishToTruthworld);
    if (channelRequired && !resolvedChannelId) {
      throw new HttpsError(
        "failed-precondition",
        publishToTruthworld
          ? "A TruthWorld creator channel is required to publish directly to your feed. Turn off Feed Publish to dub privately, or create a channel first."
          : "A creator channel is required for this video operation. Please set up your channel first."
      );
    }

    let channelRef: admin.firestore.DocumentReference | null = null;
    let channelData: Record<string, any> = {};
    if (resolvedChannelId) {
      channelRef = firestore.collection("channels").doc(resolvedChannelId);
      const channelSnap = await channelRef.get();
      if (!channelSnap.exists) {
        if (channelRequired) {
          throw new HttpsError("not-found", "Creator channel not found.");
        }
        resolvedChannelId = null;
        channelRef = null;
      } else {
        channelData = channelSnap.data() || {};
        const isOwner = channelData.ownerId === uid || channelData.userId === uid;
        if (!isOwner && !isAdmin) {
          throw new HttpsError("permission-denied", "You do not own this channel.");
        }
      }
    }

    // 2. Resolve or Create Video Document
    let resolvedVideoId = requestedVideoId || "";
    let resolvedMediaUrl = sourceMediaUrl || "";
    let storedDurationSeconds: unknown = 0;

    if (resolvedVideoId) {
      if (!isVideoId(resolvedVideoId)) {
        throw new HttpsError("invalid-argument", "Invalid video ID.");
      }
      const vSnap = await firestore.collection("videos").doc(resolvedVideoId).get();
      if (!vSnap.exists) {
        throw new HttpsError("not-found", "Video not found.");
      }
      const vData = vSnap.data() || {};
      if (vData.ownerId && vData.ownerId !== uid && !isAdmin) {
        throw new HttpsError("permission-denied", "You do not own this video.");
      }
      // The stored video is dubbed (a client-sent URL never replaces it for an existing video).
      resolvedMediaUrl = vData.videoUrl || vData.hlsUrl || resolvedMediaUrl;
      storedDurationSeconds =
        Number(vData.durationSeconds) > 0
          ? vData.durationSeconds
          : Number(vData.durationMs) > 0
            ? Number(vData.durationMs) / 1000
            : 0;
    } else {
      // A new upload must be a file in this project's storage bucket under the caller's dubbing_uploads/{uid}/ prefix.
      const info = parseAnyStorageUrl(resolvedMediaUrl);
      const defaultBucket = admin.storage().bucket().name;
      if (!info || info.bucketName !== defaultBucket || !(await checkStorageObjectExists(resolvedMediaUrl))) {
        throw new HttpsError(
          "invalid-argument",
          "We couldn't find your uploaded file. Please upload the video again."
        );
      }
      if (!isAdmin && !info.filePath.startsWith(`dubbing_uploads/${uid}/`)) {
        throw new HttpsError(
          "permission-denied",
          "You can only dub media files uploaded to your own workspace."
        );
      }
    }

    // The billed length is measured by the server, never taken from the app.
    let probedMs = 0;
    if (!(Number(storedDurationSeconds) > 0)) {
      probedMs = await probeStudioMediaDurationMs(resolvedMediaUrl);
    }
    const lengthDecision = decideStudioDuration(storedDurationSeconds, probedMs);
    if (!lengthDecision.ok) {
      throw new HttpsError("failed-precondition", lengthDecision.message);
    }
    const resolvedDuration = lengthDecision.seconds;
    if (Number(durationSeconds) > 0 && Math.abs(Number(durationSeconds) - resolvedDuration) > 5) {
      logger.warn("[DubbingStudio:Duration] App-sent length differs from the measured length; measured length is billed", {
        uid,
        appSeconds: Number(durationSeconds),
        measuredSeconds: resolvedDuration,
      });
    }

    // Standalone Dubbing Studio uploads must NEVER create documents in `videos`.
    // Only real user video uploads live in `videos`; standalone studio jobs use `pipelineJobId`.
    const pipelineJobId = resolvedVideoId
      ? resolvedVideoId
      : `dubjob_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    // 3. Server-side price: dubbing via dubbingCharge, "subtitles only" at the subtitle price (studio-order.ts)
    const isSubtitlesOnly = mode === "subtitles_only";
    let dubbingDiscountPercent = channelDubbingDiscountPercent(channelData, isAdmin);
    if (!isAdmin && dubbingDiscountPercent < 100) {
      try {
        const userSnap = await firestore.collection("users").doc(uid).get();
        if (userSnap.exists) {
          const uData = userSnap.data() || {};
          if (
            uData.isDubbingFree === true ||
            uData.dubbingDiscountType === "free" ||
            Number(uData.dubbingDiscountPercent) >= 100
          ) {
            dubbingDiscountPercent = 100;
          } else {
            const uPct = Number(uData.dubbingDiscountPercent || 0);
            if (uPct > dubbingDiscountPercent) {
              dubbingDiscountPercent = Math.min(100, uPct);
            }
          }
        }
      } catch (_) {}
    }

    let dubbingQuote: DubbingQuote | null = null;
    if (!isSubtitlesOnly) try {
      dubbingQuote = await quoteFromTranscript({
        transcriptIds: [resolvedVideoId || pipelineJobId],
        durationSec: resolvedDuration,
        fallbackSourceLanguage: sourceLanguage,
        targetLanguages,
        discountPercent: dubbingDiscountPercent,
        normalizeLanguage: normalizeLanguageCode,
      });
    } catch (quoteErr) {
      logger.warn("[DubbingStudio:Pricing] Quote from transcript unavailable — minute price applies", {
        pipelineJobId,
        resolvedVideoId: resolvedVideoId || null,
        error: String(quoteErr),
      });
    }

    const charge = studioCharge({
      mode,
      targetLanguages,
      durationSeconds: resolvedDuration,
      channelData,
      isAdmin,
      dubbingDiscountPercent,
      quote: dubbingQuote,
      characterPricing: characterPricingEnabled(),
    });

    const totalRequiredCost = charge.chargedUsd;

    if (!isSubtitlesOnly && targetLanguages.length > 0) {
      const { checkOrderCapacityAndAlert } = require("../pipeline/services/elevenlabs-capacity-guard");
      const capCheck = await checkOrderCapacityAndAlert({
        videoId: resolvedVideoId || pipelineJobId,
        userId: uid,
        durationSec: resolvedDuration,
        sourceChars: dubbingQuote?.sourceChars,
        sourceLang: sourceLanguage,
        targetLanguages,
        clonesNeeded: cloning.dubbingMode === "voice_clone" ? 1 : 0,
      });
      if (!capCheck.allowed) {
        throw new HttpsError("resource-exhausted", capCheck.message);
      }
    }

    const now = Date.now();
    const cleanCashfreeOrderId =
      typeof rawCashfreeOrderId === "string" ? rawCashfreeOrderId.trim() : "";
    const personalWalletRef = firestore.collection("dubbing_wallets").doc(uid);
    const channelTxDocRef = firestore.collection("channel_wallet_transactions").doc();
    const personalTxDocRef = firestore.collection("dubbing_wallet_transactions").doc();
    let effectiveTxId = cleanCashfreeOrderId || channelTxDocRef.id;
    let effectiveWalletSource: "channel" | "personal" | "cashfree_direct" = "personal";
    let capturedError: any = null;

    // 4. Atomic OCC Firestore Transaction: Cashfree direct order -> Channel Wallet -> Personal USD Wallet
    await firestore.runTransaction(async (tx) => {
      if (cleanCashfreeOrderId) {
        const orderRef = firestore.collection("payment_orders").doc(cleanCashfreeOrderId);
        const orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) {
          capturedError = new HttpsError("not-found", "Direct payment order not found.");
          throw capturedError;
        }
        const orderData = orderSnap.data() || {};
        if (orderData.userId !== uid) {
          capturedError = new HttpsError("permission-denied", "You do not own this payment order.");
          throw capturedError;
        }
        const orderStatus = String(orderData.status || "").toUpperCase();
        if (orderStatus !== "PAID" && orderStatus !== "FULFILLED") {
          capturedError = new HttpsError(
            "failed-precondition",
            "Payment order is not confirmed yet. Please complete payment first."
          );
          throw capturedError;
        }
        const expectedPurpose = isSubtitlesOnly ? "ai_subtitles" : "ai_dubbing";
        if (orderData.purpose !== expectedPurpose && orderData.purpose !== "ai_dubbing") {
          capturedError = new HttpsError("invalid-argument", "Payment order purpose does not match this job.");
          throw capturedError;
        }
        if (orderData.consumedByJobId) {
          capturedError = new HttpsError(
            "failed-precondition",
            "This payment order has already been used for another dubbing job."
          );
          throw capturedError;
        }
        const orderCurrency = String(orderData.currency || "INR").toUpperCase();
        const verifiedOrderUsd =
          typeof orderData.verifiedAmountUSD === "number"
            ? orderData.verifiedAmountUSD
            : (orderCurrency === "USD"
                ? Number(orderData.amount || 0)
                : Number((Number(orderData.amount || 0) / 84.0).toFixed(2)));
        if (verifiedOrderUsd + 0.01 < totalRequiredCost) {
          capturedError = new HttpsError(
            "failed-precondition",
            `Direct payment amount ($${verifiedOrderUsd.toFixed(2)}) is below the required cost ($${totalRequiredCost.toFixed(2)}).`
          );
          throw capturedError;
        }
        tx.update(orderRef, {
          consumedByJobId: pipelineJobId,
          consumedAt: now,
        });
        effectiveTxId = cleanCashfreeOrderId;
        effectiveWalletSource = "cashfree_direct";
        return;
      }

      const [liveChanSnap, personalSnap] = await Promise.all([
        channelRef ? tx.get(channelRef) : Promise.resolve(null),
        tx.get(personalWalletRef),
      ]);

      let channelSpendable = 0;
      let rolloverCredit = 0;
      let fundedBalance = 0;
      if (liveChanSnap && liveChanSnap.exists) {
        const chData = liveChanSnap.data() || {};
        const infraConfig = chData.infraConfig || {};
        rolloverCredit = Number(infraConfig.rolloverCreditUSD || 0);
        fundedBalance = Number(chData.walletBalanceUSD || chData.walletBalance || 0);
        const totalRevINR =
          Number(chData.adsRevenueTotal || 0) +
          Number(chData.premiumSubsRevenueTotal || 0) +
          Number(chData.membershipRevenueTotal || 0) +
          Number(chData.superchatRevenueTotal || 0);
        const withdrawnRevINR = Number(chData.withdrawnRevenueTotal || 0);
        const availableRevUSD = Math.max(0, totalRevINR - withdrawnRevINR) / 84.0;
        channelSpendable = Number((rolloverCredit + fundedBalance + availableRevUSD).toFixed(2));
      }

      const personalData = personalSnap.exists ? (personalSnap.data() || {}) : {};
      const personalUsd = Number(personalData.balanceUsd || 0);

      const preferChannel =
        Boolean(channelRef) &&
        liveChanSnap?.exists &&
        (requestedWalletSource === "channel"
          ? channelSpendable >= totalRequiredCost
          : (requestedWalletSource !== "personal"
              ? channelSpendable >= totalRequiredCost
              : (personalUsd < totalRequiredCost && channelSpendable >= totalRequiredCost)));

      if (preferChannel && channelRef) {
        let remaining = totalRequiredCost;
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
        const balanceAfter = Math.max(0, Number((channelSpendable - totalRequiredCost).toFixed(2)));

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
        tx.update(channelRef, channelUpdates);

        effectiveTxId = channelTxDocRef.id;
        effectiveWalletSource = "channel";
        tx.set(channelTxDocRef, {
          id: effectiveTxId,
          channelId: resolvedChannelId,
          userId: uid,
          amount: totalRequiredCost,
          trialCreditDeducted: 0,
          rolloverDeducted,
          fundedDeducted,
          revenueDeducted: revenueDeductedUSD,
          category: "aiDubbing",
          description: `Dubbing Studio order for "${title}" (${targetLanguages.join(", ").toUpperCase()})`,
          balanceBefore: channelSpendable,
          balanceAfter,
          timestamp: now,
          redeemed: true,
          redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
          redeemedByJobId: pipelineJobId,
          metadata: {
            videoId: resolvedVideoId || null,
            pipelineJobId,
            targetLanguages,
            durationSeconds: resolvedDuration,
            costUSD: totalRequiredCost,
            source: "DubbingStudio",
          },
        });
        return;
      }

      if (personalUsd < totalRequiredCost) {
        const bestAvailable = Math.max(personalUsd, channelSpendable);
        capturedError = new HttpsError(
          "failed-precondition",
          `Insufficient wallet balance ($${bestAvailable.toFixed(2)} available vs $${totalRequiredCost.toFixed(2)} required). Please top up your Dubbing Wallet or pay directly.`
        );
        throw capturedError;
      }

      effectiveTxId = personalTxDocRef.id;
      effectiveWalletSource = "personal";
      const nextPersonalUsd = Math.max(0, Number((personalUsd - totalRequiredCost).toFixed(2)));
      const prevTxs = Array.isArray(personalData.transactions) ? personalData.transactions : [];
      const debitDesc = `Dubbing Studio order for "${title}" (${targetLanguages.join(", ").toUpperCase()})`;
      const debitTx = {
        id: effectiveTxId,
        type: "job_debit",
        amountCredits: 0,
        amountUsd: totalRequiredCost,
        description: debitDesc,
        jobId: pipelineJobId,
        timestamp: now,
      };

      if (totalRequiredCost > 0 || !personalSnap.exists) {
        tx.set(
          personalWalletRef,
          {
            userId: uid,
            balanceCredits: Number(personalData.balanceCredits || 0),
            balanceUsd: nextPersonalUsd,
            trialClaimed: Boolean(personalData.trialClaimed),
            totalCharactersUsed: Number(personalData.totalCharactersUsed || 0),
            totalSpentUsd: Number((Number(personalData.totalSpentUsd || 0) + totalRequiredCost).toFixed(2)),
            transactions: totalRequiredCost > 0 ? [debitTx, ...prevTxs].slice(0, 100) : prevTxs,
            updatedAt: now,
          },
          { merge: true }
        );
      }

      if (totalRequiredCost > 0) {
        tx.set(personalTxDocRef, {
          id: effectiveTxId,
          orderId: effectiveTxId,
          jobId: pipelineJobId,
          userId: uid,
          type: "job_debit",
          amountUsd: totalRequiredCost,
          balanceBefore: personalUsd,
          balanceAfter: nextPersonalUsd,
          description: debitDesc,
          timestamp: now,
          metadata: {
            videoId: resolvedVideoId || null,
            pipelineJobId,
            targetLanguages,
            durationSeconds: resolvedDuration,
            source: "DubbingStudio",
          },
        });
      }
    });

    // 5. Per-order record for per-language refundability (refundService.ts)
    if (totalRequiredCost > 0) {
      await recordDubbingOrder({
        orderId: effectiveTxId,
        jobId: pipelineJobId,
        videoId: resolvedVideoId || pipelineJobId,
        userId: uid,
        channelId: resolvedChannelId || "",
        walletSource: effectiveWalletSource,
        ...(cleanCashfreeOrderId ? { cashfreeOrderId: cleanCashfreeOrderId } : {}),
        paidUSD: totalRequiredCost,
        dubbingUSD: charge.dubbingUsd,
        subtitleUSD: charge.subtitleUsd,
        languages: targetLanguages.map((l: string) => normalizeLanguageCode(l)),
        priceByLanguage: buildOrderPrices({
          dubbingLanguages: isSubtitlesOnly ? [] : targetLanguages,
          dubbingUSD: charge.dubbingUsd,
          dubbingPriceByLanguage: charge.dubbingPriceByLanguage,
          subtitleLanguages: isSubtitlesOnly ? targetLanguages : [],
          subtitleUSD: charge.subtitleUsd,
        }),
        createdAt: now,
        source: "DubbingStudio",
      }).catch((orderErr) =>
        logger.error("[DubbingStudio] Order record write failed — refunds fall back to job proration", {
          pipelineJobId,
          error: String(orderErr),
        })
      );
    }

    const sanitizedDemuxOptions: DubbingDemuxOptions = {
      isolateVocals: demuxOptions?.isolateVocals !== false,
      preserveBgm: demuxOptions?.preserveBgm !== false,
      bgmDuckLevelPercent: Math.max(0, Math.min(50, Number(demuxOptions?.bgmDuckLevelPercent ?? 25))),
      noiseSuppression: demuxOptions?.noiseSuppression !== false,
    };

    const speakerOverrides: ExecutionPlan["speakerOverrides"] = {};
    if (Array.isArray(speakers)) {
      for (const spk of speakers) {
        if (!spk || typeof spk !== "object") continue;
        const spkId = String((spk as any).speakerId || (spk as any).id || "").trim();
        if (!spkId) continue;
        const rawVoice = String((spk as any).assignedVoiceId || "").trim();
        const assignedVoiceId =
          rawVoice && rawVoice !== "default_voice" && rawVoice !== "voice_telugu_charan"
            ? rawVoice
            : undefined;
        const rawPitch = Number((spk as any).pitchAdjustment ?? 0);
        const rawSpeed = Number((spk as any).speedAdjustment ?? 1.0);
        const pitchAdjustment = Number.isFinite(rawPitch) ? Math.max(-12, Math.min(12, rawPitch)) : 0;
        const speedAdjustment = Number.isFinite(rawSpeed) ? Math.max(0.5, Math.min(2.0, rawSpeed)) : 1.0;
        if (assignedVoiceId || pitchAdjustment !== 0 || speedAdjustment !== 1.0) {
          speakerOverrides[spkId] = {
            ...(assignedVoiceId ? { assignedVoiceId } : {}),
            isClonedVoice: Boolean((spk as any).isClonedVoice),
            pitchAdjustment,
            speedAdjustment,
          };
        }
      }
    }

    // 6. Pipeline Execution: Setup video_jobs/{pipelineJobId} & dispatch to real pipeline
    const executionPlan: ExecutionPlan = {
      jobId: pipelineJobId,
      videoId: resolvedVideoId || "",
      ...(resolvedChannelId ? { channelId: resolvedChannelId } : {}),
      title,
      primaryLanguage: sourceLanguage || "en",
      sourceLanguage: sourceLanguage || "en",
      languages: targetLanguages,
      dubbingLanguages: isSubtitlesOnly ? [] : targetLanguages,
      subtitleLanguages: targetLanguages,
      enableDubbing: mode !== "subtitles_only",
      generateDubbing: mode !== "subtitles_only",
      enableSubtitles: true,
      generateSubtitles: true,
      enableAuxiliary: true,
      genLangSubs: true,
      enableDiarization: true,
      diarization: true,
      dubbingMode: cloning.dubbingMode,
      voiceCloneConsent: cloning.voiceCloneConsent,
      saveAsCreatorProfile: cloning.saveAsCreatorProfile,
      voiceGender: "auto",
      dubbingTier: "audio_track",
      // Studio exports a downloadable dubbed MP4 per language (built by the pipeline's remux step).
      deliverDubbedVideo: !isSubtitlesOnly,
      duration: resolvedDuration,
      durationSeconds: resolvedDuration,
      stemIsolation: Boolean(sanitizedDemuxOptions.isolateVocals),
      twoStageReviewEnabled: !isSubtitlesOnly && Boolean(twoStageReviewEnabled),
      publishToTruthworld: !isSubtitlesOnly && Boolean(publishToTruthworld) && Boolean(resolvedChannelId),
      demuxOptions: sanitizedDemuxOptions,
      ...(Object.keys(speakerOverrides).length > 0 ? { speakerOverrides } : {}),
      cinemaGrade: false,
      priority: "normal",
      priorityMode: "accuracy",
      channelType: "standard",
      maxClaims: 0,
      skipCache: false,
      ...(Object.keys(charge.dubbingPriceByLanguage).length > 0
        ? { dubbingPriceByLanguage: charge.dubbingPriceByLanguage, dubbingPricingBasis: charge.basis }
        : {}),
    };

    const studioJobId = `dub_${pipelineJobId}_${now}`;
    const targetTranscriptId = resolvedVideoId || pipelineJobId;
    let transcriptSnap = await firestore.collection("transcripts").doc(targetTranscriptId).get();
    const transcriptionCompleted = transcriptSnap.exists;

    await firestore.collection("video_jobs").doc(pipelineJobId).set(
      {
        jobId: pipelineJobId,
        studioJobId,
        videoId: resolvedVideoId || "",
        userId: uid,
        channelId: resolvedChannelId || "",
        walletSource: effectiveWalletSource,
        videoUrl: resolvedMediaUrl,
        fileName: title,
        status: "processing",
        sourceLanguage: sourceLanguage || "en",
        primaryLanguage: sourceLanguage || "en",
        paidFromWallet: totalRequiredCost > 0,
        walletTransactionId: effectiveTxId,
        fundedAmountUSD: totalRequiredCost,
        currentDubbingOrderId: effectiveTxId,
        executionPlan,
        updatedAt: now,
        createdAt: now,
        ...(resolvedVideoId
          ? { linkedVideoIds: admin.firestore.FieldValue.arrayUnion(resolvedVideoId) }
          : {}),
        stages: {
          transcription: {
            status: transcriptionCompleted ? "completed" : "running",
            progress: transcriptionCompleted ? 100 : 10,
            ...(transcriptionCompleted ? { completedAt: now } : { startedAt: now }),
          },
          dubbing: {
            status: isSubtitlesOnly ? "skipped" : "pending",
            progress: isSubtitlesOnly ? 100 : 0,
          },
          ...(isSubtitlesOnly
            ? {
                subtitles: {
                  status: "pending",
                  progress: 0,
                },
              }
            : {}),
          onDemandAI: {
            status: "running",
            progress: transcriptionCompleted ? 35 : 10,
            requestedFeatures: isSubtitlesOnly ? ["subtitles"] : ["dubbing", "subtitles"],
            requestedLanguages: targetLanguages,
            startedAt: now,
          },
        },
      },
      { merge: true }
    );

    // Update existing videos/{resolvedVideoId} aiFeatures only when attached to a real channel video
    if (resolvedVideoId) {
      await safeMergeExistingVideo(
        resolvedVideoId,
        {
          aiFeatures: {
            generateDubbing: mode !== "subtitles_only",
            generateSubtitles: true,
            ...(isSubtitlesOnly ? {} : { dubbingLanguages: admin.firestore.FieldValue.arrayUnion(...targetLanguages) }),
            translationLanguages: admin.firestore.FieldValue.arrayUnion(...targetLanguages),
            dubbingTier: "audio_track",
            voiceGender: "auto",
            dubbingMode: cloning.dubbingMode,
          },
          ...(isSubtitlesOnly ? { subtitlesPaid: true } : { dubbingPaid: true }),
          dubbingCostUSD: totalRequiredCost,
          dubbingWalletTxId: effectiveTxId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        "[DubbingStudio:createDubbingJob]"
      );
    }

    // Publish to Pub/Sub to trigger real worker
    try {
      const { DistributionLayer } = require("../pipeline/layers/04-distribution");
      const distribution = new DistributionLayer();
      if (!transcriptionCompleted) {
        await distribution.publish("video-uploaded", {
          eventId: `ondemand_${pipelineJobId}_${now}`,
          eventType: "video-uploaded",
          jobId: pipelineJobId,
          userId: uid,
          timestamp: now,
          data: { videoUrl: resolvedMediaUrl, executionPlan },
          retryCount: 0,
          source: "DubbingStudio",
        });
      } else {
        await distribution.publish("dubbing-processing", {
          eventId: `dub_ondemand_${pipelineJobId}_${now}`,
          eventType: "dubbing-processing",
          jobId: pipelineJobId,
          userId: uid,
          timestamp: now,
          data: { videoUrl: resolvedMediaUrl, executionPlan },
          retryCount: 0,
          source: "DubbingStudio",
        });
      }
    } catch (pubSubErr) {
      // Nothing will run, and the wallet is already debited: refund the whole order (same as
      // triggerVideoAIFeatures), mark the job failed, and tell the creator.
      logger.error("[DubbingStudio] Pub/Sub dispatch failed — refunding the order", {
        pipelineJobId,
        orderId: effectiveTxId,
        error: String(pubSubErr),
      });
      const dispatchErr = "The request could not be queued";
      let refunded = totalRequiredCost <= 0;
      if (totalRequiredCost > 0) {
        try {
          const languages = targetLanguages.map((l: string) => normalizeLanguageCode(l));
          const refund = await refundDubbingFeeOnFailure({
            jobId: pipelineJobId,
            userId: uid,
            orderId: effectiveTxId,
            failedLanguages: languages,
            totalLanguages: languages,
            reason: dispatchErr,
          });
          refunded = refund.refunded;
        } catch (refErr) {
          logger.error("[DubbingStudio] Dispatch-failure refund error", { pipelineJobId, error: String(refErr) });
        }
      }
      // update(), not set(): dotted keys address nested fields only in update().
      await firestore
        .collection("video_jobs")
        .doc(pipelineJobId)
        .update({
          status: "failed",
          "stages.dubbing.status": "failed",
          "stages.onDemandAI.status": "failed",
          updatedAt: Date.now(),
        })
        .catch(() => {});
      throw new HttpsError(
        "unavailable",
        refunded
          ? "We couldn't start your dub right now. Your payment has been refunded. Please try again in a few minutes."
          : "We couldn't start your dub right now. Please try again in a few minutes. If your wallet was charged, our team will refund it."
      );
    }

    // 7. Write to studio_dubbing_jobs/{studioJobId} (ZERO placeholder text!)
    const studioJobRef = firestore.collection(STUDIO_JOBS_COLLECTION).doc(studioJobId);

    const studioJob: DubbingJob = {
      id: studioJobId,
      userId: uid,
      userEmail: request.auth?.token.email || "",
      title,
      mode: mode as DubbingMode,
      status: "processing",
      progressPercent: transcriptionCompleted ? 35 : 10,
      currentStepMessage: transcriptionCompleted
        ? "Analyzing acoustics and preparing vocal synthesis..."
        : "Extracting dialogue and generating transcription...",
      sourceMediaUrl: resolvedMediaUrl,
      sourceMediaType,
      durationSeconds: resolvedDuration,
      characterCount: 0,
      sourceLanguage,
      targetLanguages,
      demuxOptions: demuxOptions as DubbingDemuxOptions,
      voiceCloningEnabled: cloning.dubbingMode === "voice_clone",
      speakers: speakers as DubbingSpeakerProfile[],
      twoStageReviewEnabled: Boolean(twoStageReviewEnabled),
      publishToTruthworld: Boolean(publishToTruthworld),
      chargeBasis: "characters",
      totalCharactersCharged: 0,
      costUsd: totalRequiredCost,
      videoId: resolvedVideoId || undefined,
      pipelineJobId,
      ...(resolvedChannelId ? { channelId: resolvedChannelId } : {}),
      walletSource: effectiveWalletSource,
      ...(cleanCashfreeOrderId ? { cashfreeOrderId: cleanCashfreeOrderId } : {}),
      segmentsByLanguage: {},
      createdAt: now,
      updatedAt: now,
    };

    await studioJobRef.set(studioJob);

    logger.info("[DubbingStudio:JobCreated]", {
      studioJobId,
      pipelineJobId,
      videoId: resolvedVideoId,
      uid,
      totalRequiredCost,
    });

    return {
      success: true,
      jobId: studioJobId,
      pipelineJobId,
      videoId: resolvedVideoId,
      costUsd: totalRequiredCost,
    };
  }
);

/**
 * ✍️ Pre-TTS Review: Update Dialogue Text
 */
export const updateDubbingTranscription = onCall(
  { cors: true, region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Please sign in to edit transcription.");
    }

    const { jobId, language, segments, approveForTTS = false } = request.data || {};
    if (!jobId || !language || !Array.isArray(segments)) {
      throw new HttpsError("invalid-argument", "Missing required segment updates.");
    }

    const firestore = db();
    let jobRef = firestore.collection(STUDIO_JOBS_COLLECTION).doc(jobId);
    let jobSnap = await jobRef.get();
    if (!jobSnap.exists) {
      jobRef = firestore.collection("dubbing_jobs").doc(jobId);
      jobSnap = await jobRef.get();
    }
    if (!jobSnap.exists) {
      throw new HttpsError("not-found", "Dubbing job not found.");
    }

    const jobData = jobSnap.data() as DubbingJob;
    if (jobData.userId !== uid) {
      throw new HttpsError("permission-denied", "You do not own this dubbing job.");
    }

    const updatedSegments = {
      ...(jobData.segmentsByLanguage || {}),
      [language]: segments,
    };

    const updatePayload: Partial<DubbingJob> = {
      segmentsByLanguage: updatedSegments,
      updatedAt: Date.now(),
    };

    if (approveForTTS) {
      const approvedJob = await firestore.runTransaction(async (tx) => {
        const liveSnap = await tx.get(jobRef);
        if (!liveSnap.exists) {
          throw new HttpsError("not-found", "Dubbing job not found.");
        }
        const liveData = liveSnap.data() as DubbingJob;
        if (liveData.userId !== uid) {
          throw new HttpsError("permission-denied", "You do not own this dubbing job.");
        }
        if (liveData.status !== "awaiting_transcription_review") {
          throw new HttpsError(
            "failed-precondition",
            "Script review is not currently awaiting approval for this job."
          );
        }
        tx.update(jobRef, {
          ...updatePayload,
          status: "synthesizing_speech",
          progressPercent: 60,
          currentStepMessage: "Script approved. Generating natural dubbed voices...",
        });
        return liveData;
      });

      const pipelineJobId = approvedJob.pipelineJobId || approvedJob.videoId || (approvedJob as any).jobId || jobId;
      const normLang = normalizeLanguageCode(language);
      if (pipelineJobId) {
        const videoJobRef = firestore.collection("video_jobs").doc(pipelineJobId);
        const videoJobSnap = await videoJobRef.get();
        if (videoJobSnap.exists) {
          const vData = videoJobSnap.data() || {};
          const nextPlan: ExecutionPlan = {
            ...(vData.executionPlan || {}),
            twoStageReviewCompleted: true,
            skipTranscription: true,
          };
          await videoJobRef.set(
            {
              executionPlan: nextPlan,
              reviewedSegmentsByLanguage: {
                ...(vData.reviewedSegmentsByLanguage || {}),
                [normLang]: segments,
              },
              stages: {
                ...(vData.stages || {}),
                dubbing: {
                  ...(vData.stages?.dubbing || {}),
                  status: "running",
                  progress: 50,
                  updatedAt: Date.now(),
                },
              },
              updatedAt: Date.now(),
            },
            { merge: true }
          );

          const { DistributionLayer } = require("../pipeline/layers/04-distribution");
          const distribution = new DistributionLayer();
          await distribution.publish("dubbing-processing", {
            eventId: `dub_resume_${pipelineJobId}_${Date.now()}`,
            eventType: "dubbing-processing",
            jobId: pipelineJobId,
            userId: uid,
            timestamp: Date.now(),
            data: { videoUrl: vData.videoUrl || approvedJob.sourceMediaUrl, executionPlan: nextPlan },
            retryCount: 0,
            source: "DubbingStudioReview",
          });
        }
      }
    } else {
      await jobRef.update(updatePayload);
    }

    return {
      success: true,
      message: approveForTTS
        ? "Transcription approved. Synthesizing neural speech..."
        : "Segments updated successfully.",
    };
  }
);

/**
 * 🎛️ Post-TTS Line Regeneration: Re-synthesize a specific line via real dubbingEditorService.
 */
export const regenerateDubbingSegment = onCall(
  {
    cors: true,
    region: REGION,
    memory: "512MiB",
    maxInstances: 10,
    secrets: ["ELEVENLABS_API_KEY"],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Please sign in to regenerate audio.");
    }

    const {
      jobId,
      language,
      segmentId,
      segmentIndex: rawIndex,
      newText,
      voiceId: targetVoiceId,
      speedMultiplier: rawSpeedMultiplier,
    } = request.data || {};
    if (!jobId || !language) {
      throw new HttpsError("invalid-argument", "Missing jobId or language.");
    }

    const firestore = db();
    const studioRef = firestore.collection(STUDIO_JOBS_COLLECTION).doc(jobId);
    let jobRef = studioRef;
    let jobSnap = await studioRef.get();
    if (!jobSnap.exists) {
      jobRef = firestore.collection("dubbing_jobs").doc(jobId);
      jobSnap = await jobRef.get();
    }
    if (!jobSnap.exists) {
      throw new HttpsError("not-found", "Dubbing job not found.");
    }

    const jobData = jobSnap.data() as any;
    if (jobData.userId !== uid) {
      throw new HttpsError("permission-denied", "You do not own this dubbing job.");
    }

    const pipelineJobId = jobData.pipelineJobId || jobData.videoId || jobData.jobId || jobId;
    const normLang = normalizeLanguageCode(language);

    // Which line: an explicit 0-based index, or the app's 1-based "seg_N" id (studio-order.ts).
    const resolvedIndex = studioSegmentIndex(rawIndex, segmentId);
    if (resolvedIndex === null) {
      throw new HttpsError("invalid-argument", "Please choose the line you want to regenerate.");
    }

    const speedMultiplier =
      typeof rawSpeedMultiplier === "number" && Number.isFinite(rawSpeedMultiplier)
        ? Math.max(0.5, Math.min(2.0, rawSpeedMultiplier))
        : 1.0;

    try {
      const res = await dubbingEditorService.updateSegmentAndResynthesize({
        jobId: pipelineJobId,
        language: normLang,
        segmentIndex: resolvedIndex,
        uid,
        isAdmin: isCallableAdmin(request.auth),
        editedText: newText,
        voiceId: targetVoiceId,
        speedMultiplier,
      });

      // Sync regenerated segment back to studio_dubbing_jobs so Studio UI updates immediately
      const existingSegmentsMap = (jobData.segmentsByLanguage || {}) as Record<string, any[]>;
      const langKey =
        Object.keys(existingSegmentsMap).find((k) => normalizeLanguageCode(k) === normLang) ||
        language;
      const existingList = Array.isArray(existingSegmentsMap[langKey])
        ? [...existingSegmentsMap[langKey]]
        : [];
      if (existingList[resolvedIndex]) {
        existingList[resolvedIndex] = {
          ...existingList[resolvedIndex],
          translatedText: res.segment.editedText || res.segment.translatedText || newText,
          audioStemUrl: res.playableAudioUrl || res.segment.synthesizedAudioUrl,
          speedMultiplier,
          status: "synthesized",
        };
        await jobRef
          .set(
            {
              segmentsByLanguage: {
                ...existingSegmentsMap,
                [langKey]: existingList,
              },
              updatedAt: Date.now(),
            },
            { merge: true }
          )
          .catch(() => {});
      }

      return {
        success: true,
        message: "Segment regenerated successfully.",
        updatedSegment: res.segment,
        playableAudioUrl: res.playableAudioUrl,
      };
    } catch (err: any) {
      logger.error("[DubbingStudio:regenerateSegment] Error:", { error: err?.message || String(err) });
      // The editor service's own HttpsErrors are written for users; anything else stays in the logs.
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "We couldn't regenerate this line right now. Please try again.");
    }
  }
);

/**
 * 📦 Export Dubbed Assets (Video, Audio Stems, and Subtitles in All Formats).
 * Real existence check: Omits any file that does not exist in Cloud Storage.
 * Never sets "completed" before the pipeline reports completion.
 */
export const exportDubbingAssets = onCall(
  {
    cors: true,
    region: REGION,
    memory: "1GiB",
    timeoutSeconds: 300,
    maxInstances: 10,
    secrets: ["ELEVENLABS_API_KEY", "DEMUX_WORKER_TOKEN"],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Please sign in to export assets.");
    }

    const { jobId } = request.data || {};
    if (!jobId) {
      throw new HttpsError("invalid-argument", "Missing jobId.");
    }

    const firestore = db();
    let jobSnap = await firestore.collection(STUDIO_JOBS_COLLECTION).doc(jobId).get();
    if (!jobSnap.exists) {
      jobSnap = await firestore.collection("dubbing_jobs").doc(jobId).get();
    }
    if (!jobSnap.exists) {
      throw new HttpsError("not-found", "Dubbing job not found.");
    }

    const job = jobSnap.data() as any;
    if (job.userId !== uid) {
      throw new HttpsError("permission-denied", "Permission denied.");
    }

    const pipelineJobId = job.pipelineJobId || job.videoId || job.jobId || jobId;
    const videoJobSnap = await firestore.collection("video_jobs").doc(pipelineJobId).get();
    const videoJobData = videoJobSnap.exists ? videoJobSnap.data() || {} : {};

    // Gate: Never report "completed" or export before the pipeline reports completion!
    const isSubtitlesOnly = job.mode === "subtitles_only";
    const dubbingStage = videoJobData.stages?.dubbing?.status;
    const subtitlesStage = videoJobData.stages?.subtitles?.status;
    const overallStatus = videoJobData.status;
    const isCompleted = isSubtitlesOnly
      ? (subtitlesStage === "completed" || overallStatus === "completed")
      : (dubbingStage === "completed" || overallStatus === "completed");

    if (!isCompleted) {
      throw new HttpsError(
        "failed-precondition",
        "Dubbing pipeline is still processing media. Please wait for completion before exporting."
      );
    }

    const targetLanguages: string[] = job.targetLanguages || [];
    const srtMap: Record<string, string> = {};
    const vttMap: Record<string, string> = {};
    const audioByLanguage: Record<string, string> = {};
    const videoByLanguage: Record<string, string> = {};
    const dialogueAudioByLanguage: Record<string, string> = {};
    const translationJsonByLanguage: Record<string, string> = {};
    let vocalsStemMp3 = "";
    let backgroundStemMp3 = "";
    let reportJson = "";

    // The original upload is never offered as a "dubbed video" (studio-order.ts isDubbedVideoUrl).
    const originalUrl = videoJobData.videoUrl || job.sourceMediaUrl || "";
    const isDubbedVideo = (url: string) => isDubbedVideoUrl(url, originalUrl);
    const resolveDownloadUrl = async (rawUrl: string): Promise<string> => {
      if (!rawUrl) return "";
      const resolved = await audioIdentityService.getAccessibleUrl(rawUrl).catch(() => rawUrl);
      if (resolved.startsWith("http://") || resolved.startsWith("https://")) {
        return resolved;
      }
      const info = parseAnyStorageUrl(resolved);
      if (info && info.bucketName && info.filePath) {
        return `https://firebasestorage.googleapis.com/v0/b/${info.bucketName}/o/${encodeURIComponent(info.filePath)}?alt=media`;
      }
      return resolved;
    };

    if (!isSubtitlesOnly) {
      for (const lang of targetLanguages) {
        try {
          const pkg = await dubbingEditorService.getDubbingExportPackage({
            jobId: pipelineJobId,
            videoId: job.videoId || undefined,
            language: lang,
            uid,
            isAdmin: isCallableAdmin(request.auth),
          });

          if (pkg.videoUrl && isDubbedVideo(pkg.videoUrl) && (await checkStorageObjectExists(pkg.videoUrl))) {
            videoByLanguage[lang] = await resolveDownloadUrl(pkg.videoUrl);
          }
          if (pkg.audioUrl && (await checkStorageObjectExists(pkg.audioUrl))) {
            audioByLanguage[lang] = await resolveDownloadUrl(pkg.audioUrl);
          }
          if (pkg.dialogueAudioUrl && (await checkStorageObjectExists(pkg.dialogueAudioUrl))) {
            dialogueAudioByLanguage[lang] = await resolveDownloadUrl(pkg.dialogueAudioUrl);
          }
          if (pkg.translationJsonUrl && (await checkStorageObjectExists(pkg.translationJsonUrl))) {
            translationJsonByLanguage[lang] = await resolveDownloadUrl(pkg.translationJsonUrl);
          }
          if (!vocalsStemMp3 && pkg.vocalsStemUrl && (await checkStorageObjectExists(pkg.vocalsStemUrl))) {
            vocalsStemMp3 = await resolveDownloadUrl(pkg.vocalsStemUrl);
          }
          if (!backgroundStemMp3 && pkg.backgroundStemUrl && (await checkStorageObjectExists(pkg.backgroundStemUrl))) {
            backgroundStemMp3 = await resolveDownloadUrl(pkg.backgroundStemUrl);
          }
          if (!reportJson && pkg.reportJsonUrl && (await checkStorageObjectExists(pkg.reportJsonUrl))) {
            reportJson = await resolveDownloadUrl(pkg.reportJsonUrl);
          }
          if (pkg.srtUrl && (await checkStorageObjectExists(pkg.srtUrl))) {
            srtMap[lang] = await resolveDownloadUrl(pkg.srtUrl);
          }
          if (pkg.vttUrl && (await checkStorageObjectExists(pkg.vttUrl))) {
            vttMap[lang] = await resolveDownloadUrl(pkg.vttUrl);
          }
        } catch (pkgErr) {
          logger.warn("[DubbingStudio:exportAssets] Notice inspecting export package for language:", {
            lang,
            error: String(pkgErr),
          });
        }
      }
    }

    const bucketName = admin.storage().bucket().name;
    const jobOutputsSnap = await firestore.collection("job_outputs").doc(pipelineJobId).get().catch(() => null);
    const jobOutputsData = jobOutputsSnap?.exists ? jobOutputsSnap.data() || {} : {};

    const firstExistingCandidate = async (candidates: unknown[]): Promise<string> => {
      for (const candidate of candidates) {
        if (typeof candidate === "string" && candidate.trim().length > 0 && (await checkStorageObjectExists(candidate))) {
          return candidate.trim();
        }
      }
      return "";
    };

    // Fill gaps from the pipeline's per-language outputs on video_jobs, job_outputs, dubbing_results, subtitle_results, and canonical GCS paths.
    for (const lang of targetLanguages) {
      const normLang = normalizeLanguageCode(lang);
      const dubResSnap = !isSubtitlesOnly
        ? await firestore.collection("dubbing_results").doc(`${pipelineJobId}_${normLang}`).get().catch(() => null)
        : null;
      const dubResData = dubResSnap?.exists ? dubResSnap.data() || {} : {};

      if (!isSubtitlesOnly) {
        const videoCandidates = [
          videoJobData.outputs?.dubbedVideos?.[lang],
          videoJobData.outputs?.dubbedVideos?.[normLang],
          videoJobData[`outputs.dubbedVideos.${lang}`],
          videoJobData[`outputs.dubbedVideos.${normLang}`],
          jobOutputsData.dubbed?.[lang]?.videoUrl || jobOutputsData.dubbed?.[lang]?.path,
          jobOutputsData.dubbed?.[normLang]?.videoUrl || jobOutputsData.dubbed?.[normLang]?.path,
          jobOutputsData[`dubbed.${lang}`]?.videoUrl || jobOutputsData[`dubbed.${lang}`]?.path,
          jobOutputsData[`dubbed.${normLang}`]?.videoUrl || jobOutputsData[`dubbed.${normLang}`]?.path,
          dubResData.videoUrl,
          `gs://${bucketName}/videos/${pipelineJobId}/${normLang}-dubbed.mp4`,
          `gs://${bucketName}/videos/${pipelineJobId}/video_with_${normLang}_dub.mp4`,
        ];
        if (!videoByLanguage[lang]) {
          for (const candidate of videoCandidates) {
            if (typeof candidate === "string" && isDubbedVideo(candidate) && (await checkStorageObjectExists(candidate))) {
              videoByLanguage[lang] = await resolveDownloadUrl(candidate);
              break;
            }
          }
        }

        const matchedTrackRaw = await firstExistingCandidate([
          videoJobData.outputs?.audioTracks?.[lang],
          videoJobData.outputs?.audioTracks?.[normLang],
          videoJobData[`outputs.audioTracks.${lang}`],
          videoJobData[`outputs.audioTracks.${normLang}`],
          jobOutputsData.audioTracks?.[lang],
          jobOutputsData.audioTracks?.[normLang],
          jobOutputsData[`audioTracks.${lang}`],
          jobOutputsData[`audioTracks.${normLang}`],
          jobOutputsData.dubbed?.[lang]?.audioUrl,
          jobOutputsData.dubbed?.[normLang]?.audioUrl,
          dubResData.audioUrl,
          `gs://${bucketName}/audio/${pipelineJobId}/${normLang}/master_delivery.mp3`,
          `gs://${bucketName}/audio/${pipelineJobId}/${normLang}/master_faithful.mp3`,
          `gs://${bucketName}/audio/${pipelineJobId}/${normLang}/master.mp3`,
          `gs://${bucketName}/audio/${pipelineJobId}/${normLang}/master_reels.mp3`,
          `gs://${bucketName}/audio/${pipelineJobId}/cinema_master.mp3`,
        ]);
        if (!audioByLanguage[lang] && matchedTrackRaw) {
          audioByLanguage[lang] = await resolveDownloadUrl(matchedTrackRaw);
        }
        // On-demand MP4 remux fallback if audio is ready for a video project but dubbed MP4 was deferred or missing
        if (
          !videoByLanguage[lang] &&
          job.sourceMediaType !== "audio" &&
          audioByLanguage[lang] &&
          originalUrl
        ) {
          try {
            const { mediaService } = require("../pipeline/services/media");
            const rawAudioForMux = matchedTrackRaw || audioByLanguage[lang];
            const muxedGsUrl = await mediaService.mergeAudioToVideo({
              jobId: pipelineJobId,
              videoUrl: originalUrl,
              audioUrl: rawAudioForMux,
              subtitleUrl: srtMap[lang],
              language: normLang,
              format: "mp4",
              isPreMastered: true,
            });
            if (muxedGsUrl && isDubbedVideo(muxedGsUrl) && (await checkStorageObjectExists(muxedGsUrl))) {
              const accessibleMuxedUrl = await resolveDownloadUrl(muxedGsUrl);
              videoByLanguage[lang] = accessibleMuxedUrl;
              await firestore
                .collection("video_jobs")
                .doc(pipelineJobId)
                .set(
                  {
                    outputs: {
                      dubbedVideos: {
                        [lang]: accessibleMuxedUrl,
                        ...(normLang !== lang ? { [normLang]: accessibleMuxedUrl } : {}),
                      },
                    },
                  },
                  { merge: true }
                )
                .catch(() => {});
              await firestore
                .collection("dubbing_results")
                .doc(`${pipelineJobId}_${normLang}`)
                .set({ videoUrl: muxedGsUrl }, { merge: true })
                .catch(() => {});
            }
          } catch (onDemandMuxErr) {
            logger.warn("[DubbingStudio:exportAssets] On-demand MP4 remux fallback notice:", {
              lang,
              error: String(onDemandMuxErr),
            });
          }
        }
        const dialogueTrack = await firstExistingCandidate([
          videoJobData.outputs?.dialogueTracks?.[lang],
          videoJobData.outputs?.dialogueTracks?.[normLang],
          videoJobData[`outputs.dialogueTracks.${lang}`],
          videoJobData[`outputs.dialogueTracks.${normLang}`],
          videoJobData.outputs?.stems?.dialogue?.[lang],
          videoJobData.outputs?.stems?.dialogue?.[normLang],
          dubResData.stems?.dialogue,
          `gs://${bucketName}/audio/${pipelineJobId}/${normLang}/stitched.mp3`,
        ]);
        if (!dialogueAudioByLanguage[lang] && dialogueTrack) {
          dialogueAudioByLanguage[lang] = await resolveDownloadUrl(dialogueTrack);
        }
        if (!vocalsStemMp3) {
          const vocalsCandidate = await firstExistingCandidate([
            videoJobData.outputs?.stems?.vocals,
            videoJobData["outputs.stems.vocals"],
            dubResData.stems?.vocals,
            `gs://${bucketName}/audio/${pipelineJobId}/vocals_demucs.mp3`,
          ]);
          if (vocalsCandidate) {
            vocalsStemMp3 = await resolveDownloadUrl(vocalsCandidate);
          }
        }
        if (!backgroundStemMp3) {
          const bgCandidate = await firstExistingCandidate([
            videoJobData.outputs?.stems?.background,
            videoJobData.outputs?.stems?.mne,
            videoJobData["outputs.stems.background"],
            videoJobData["outputs.stems.mne"],
            dubResData.stems?.mne,
            `gs://${bucketName}/audio/${pipelineJobId}/m_and_e.mp3`,
          ]);
          if (bgCandidate) {
            backgroundStemMp3 = await resolveDownloadUrl(bgCandidate);
          }
        }
      }

      if (!translationJsonByLanguage[lang]) {
        const transCandidate = await firstExistingCandidate([
          videoJobData.outputs?.translations?.[lang],
          videoJobData.outputs?.translations?.[normLang],
          videoJobData[`outputs.translations.${lang}`],
          videoJobData[`outputs.translations.${normLang}`],
          typeof dubResData.translationUrl === "string" && dubResData.translationUrl.includes("/translations/")
            ? dubResData.translationUrl
            : "",
          `gs://${bucketName}/translations/${pipelineJobId}/translation_${normLang}.json`,
        ]);
        if (transCandidate) {
          translationJsonByLanguage[lang] = await resolveDownloadUrl(transCandidate);
        } else {
          // Reconstruct translation_{lang}.json from checkpoint if available
          const cpSnap = await firestore
            .collection("video_jobs")
            .doc(pipelineJobId)
            .collection("dubbing_checkpoints")
            .doc(normLang)
            .get()
            .catch(() => null);
          const cpSegs = cpSnap?.exists ? cpSnap.data()?.translatedSegments : null;
          if (Array.isArray(cpSegs) && cpSegs.length > 0) {
            const createdTransUrl = await saveTranslationArtifact({
              jobId: pipelineJobId,
              videoId: job.videoId || undefined,
              sourceLanguage: job.sourceLanguage || videoJobData.sourceLanguage || "en",
              targetLanguage: normLang,
              segments: cpSegs,
            }).catch(() => "");
            if (createdTransUrl && (await checkStorageObjectExists(createdTransUrl))) {
              translationJsonByLanguage[lang] = await resolveDownloadUrl(createdTransUrl);
            }
          }
        }
      }

      if (!srtMap[lang]) {
        const rawSub =
          videoJobData.outputs?.subtitles?.[lang] ||
          videoJobData.outputs?.subtitles?.[normLang] ||
          videoJobData[`outputs.subtitles.${lang}`] ||
          videoJobData[`outputs.subtitles.${normLang}`] ||
          jobOutputsData.subtitles?.[lang] ||
          jobOutputsData.subtitles?.[normLang] ||
          jobOutputsData[`subtitles.${lang}`] ||
          jobOutputsData[`subtitles.${normLang}`];
        const candidateSrt = typeof rawSub === "string"
          ? rawSub
          : (rawSub?.srtPath || rawSub?.url || rawSub?.subtitleUrl || "");
        const resolvedSrtCandidate = await firstExistingCandidate([
          candidateSrt,
          `gs://${bucketName}/subtitles/${pipelineJobId}/${normLang}.srt`,
        ]);
        if (resolvedSrtCandidate) {
          srtMap[lang] = await resolveDownloadUrl(resolvedSrtCandidate);
        } else {
          const subSnap = await firestore.collection("subtitle_results").doc(`${pipelineJobId}_${normLang}`).get().catch(() => null);
          const subData = subSnap?.exists ? subSnap.data() : null;
          const fallbackSrt = subData?.srtPath || subData?.subtitleUrl || "";
          if (typeof fallbackSrt === "string" && fallbackSrt && (await checkStorageObjectExists(fallbackSrt))) {
            srtMap[lang] = await resolveDownloadUrl(fallbackSrt);
          }
          const fallbackVtt = subData?.vttPath || "";
          if (!vttMap[lang] && typeof fallbackVtt === "string" && fallbackVtt && (await checkStorageObjectExists(fallbackVtt))) {
            vttMap[lang] = await resolveDownloadUrl(fallbackVtt);
          }
        }
      }
      if (!vttMap[lang] && srtMap[lang]) {
        const candidateVtt = `gs://${bucketName}/subtitles/${pipelineJobId}/${normLang}.vtt`;
        if (await checkStorageObjectExists(candidateVtt)) {
          vttMap[lang] = await resolveDownloadUrl(candidateVtt);
        }
      }
    }

    if (!reportJson) {
      const reportCandidate =
        videoJobData.outputs?.dubbingReportUrl ||
        `gs://${bucketName}/dubbing/${pipelineJobId}/report.json`;
      if (typeof reportCandidate === "string" && (await checkStorageObjectExists(reportCandidate))) {
        reportJson = await resolveDownloadUrl(reportCandidate);
      } else {
        const reportResults = targetLanguages.map((l) => ({
          jobId: pipelineJobId,
          language: l,
          subtitleUrl: srtMap[l] || "",
          subtitleFormat: "srt" as const,
          audioUrl: audioByLanguage[l] || "",
          videoUrl: videoByLanguage[l] || "",
          translationUrl: translationJsonByLanguage[l] || "",
          segments: 0,
          processingTime: 0,
          stems: {
            dialogue: dialogueAudioByLanguage[l],
            master: audioByLanguage[l],
            vocals: vocalsStemMp3 || null,
            mne: backgroundStemMp3 || null,
          },
        }));
        const createdReport = await saveDubbingReportArtifact({
          jobId: pipelineJobId,
          videoId: job.videoId || undefined,
          sourceLanguage: job.sourceLanguage || videoJobData.sourceLanguage || "en",
          targetLanguages,
          durationSeconds: job.durationSeconds,
          vocalsStemUrl: vocalsStemMp3 || null,
          backgroundStemUrl: backgroundStemMp3 || null,
          results: reportResults,
          dialogueStems: dialogueAudioByLanguage,
          subtitlePaths: srtMap,
        });
        if (createdReport && (await checkStorageObjectExists(createdReport))) {
          reportJson = await resolveDownloadUrl(createdReport);
        }
      }
    }

    const firstLang = targetLanguages.find((l) => videoByLanguage[l] || audioByLanguage[l]);
    const exportUrls = {
      // Per language (new). The single fields below are kept for older app builds.
      dubbedVideoByLanguage: videoByLanguage,
      dubbedAudioByLanguage: audioByLanguage,
      ...(Object.keys(dialogueAudioByLanguage).length > 0 ? { dialogueAudioByLanguage } : {}),
      ...(Object.keys(translationJsonByLanguage).length > 0 ? { translationJsonByLanguage } : {}),
      ...(vocalsStemMp3 ? { vocalsStemMp3 } : {}),
      ...(backgroundStemMp3 ? { backgroundStemMp3 } : {}),
      ...(reportJson ? { reportJson } : {}),
      ...(firstLang && videoByLanguage[firstLang] ? { dubbedVideoMp4: videoByLanguage[firstLang] } : {}),
      ...(firstLang && audioByLanguage[firstLang] ? { dubbedAudioMp3: audioByLanguage[firstLang] } : {}),
      subtitlesSrt: srtMap,
      subtitlesVtt: vttMap,
    };

    const hasAnyAssets =
      Object.keys(videoByLanguage).length > 0 ||
      Object.keys(audioByLanguage).length > 0 ||
      Object.keys(dialogueAudioByLanguage).length > 0 ||
      Object.keys(translationJsonByLanguage).length > 0 ||
      Object.keys(srtMap).length > 0 ||
      Boolean(vocalsStemMp3) ||
      Boolean(backgroundStemMp3) ||
      Boolean(reportJson);
    if (!hasAnyAssets) {
      throw new HttpsError(
        "not-found",
        "Dubbing completed, but export assets are still being uploaded to cloud storage. Please retry in a few moments."
      );
    }

    // Populate segmentsByLanguage from dubbing_manifests if missing on the Studio job doc
    const nextSegmentsByLanguage: Record<string, any[]> =
      job.segmentsByLanguage && typeof job.segmentsByLanguage === "object"
        ? { ...job.segmentsByLanguage }
        : {};
    for (const lang of targetLanguages) {
      if (Array.isArray(nextSegmentsByLanguage[lang]) && nextSegmentsByLanguage[lang].length > 0) continue;
      const normLang = normalizeLanguageCode(lang);
      try {
        const mSnap = await firestore
          .collection("video_jobs")
          .doc(pipelineJobId)
          .collection("dubbing_manifests")
          .doc(normLang)
          .get();
        const mSegs = mSnap.exists ? mSnap.data()?.segments : null;
        if (Array.isArray(mSegs) && mSegs.length > 0) {
          nextSegmentsByLanguage[lang] = await Promise.all(
            mSegs.map(async (s: any, idx: number) => ({
              id: `seg_${(typeof s.index === "number" ? s.index : idx) + 1}`,
              speakerId: String(s.speaker || "speaker_0"),
              startTimeMs: Number(s.startMs || 0),
              endTimeMs: Number(s.endMs || 0),
              originalText: String(s.originalText || ""),
              translatedText: String(s.editedText || s.translatedText || ""),
              targetLanguage: lang,
              audioStemUrl: s.synthesizedAudioUrl ? await resolveDownloadUrl(String(s.synthesizedAudioUrl)) : undefined,
              status: "synthesized",
              speedMultiplier: 1.0,
            }))
          );
        }
      } catch (_) {}
    }

    await jobSnap.ref.update({
      exportUrls,
      ...(Object.keys(nextSegmentsByLanguage).length > 0 ? { segmentsByLanguage: nextSegmentsByLanguage } : {}),
      status: "completed",
      progressPercent: 100,
      completedAt: Date.now(),
      updatedAt: Date.now(),
    });

    return {
      success: true,
      exportUrls,
      ...(Object.keys(nextSegmentsByLanguage).length > 0 ? { segmentsByLanguage: nextSegmentsByLanguage } : {}),
    };
  }
);

/**
 * 💼 Purchase Dubbing Studio credits — switched off (2026-11-24).
 * Studio orders are charged from the channel wallet in USD (createDubbingJob); credits bought here were
 * never spent, and the app chose both the price and the number of credits. Kept as a callable so older
 * app builds get a clear answer instead of a missing-function error. Nothing is debited.
 */
export const purchaseDubbingCreditsWithStudioWallet = onCall(
  { cors: true, region: REGION, memory: "256MiB", maxInstances: 10 },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Please sign in to continue.");
    }
    return {
      success: false,
      message:
        "Dubbing credits are no longer sold. Dubbing is paid directly from your channel wallet when you start a project.",
    };
  }
);
