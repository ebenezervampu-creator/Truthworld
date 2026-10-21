import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { CashfreeService } from "../services/cashfreeService";
import { applySecurityHeaders } from "../utils/securityHeaders";

if (!admin.apps.length) {
  admin.initializeApp();
}

const REGION = "asia-south1";


/**
 * Fulfills an order idempotently based on its purpose and metadata
 */
async function fulfillOrder(
  orderId: string,
  userId: string,
  purpose: string,
  amount: number,
  metadata: Record<string, any> = {},
  currency: string = "INR"
) {
  const firestore = admin.firestore();
  const orderRef = firestore.collection("payment_orders").doc(orderId);

  let didFulfill = false;
  let effectiveCurrency = "INR";
  await firestore.runTransaction(async (transaction) => {
    // -------------------------------------------------------------
    // 1. ALL READ OPERATIONS MUST BE EXECUTED BEFORE ANY WRITES
    // -------------------------------------------------------------
    const orderDoc = await transaction.get(orderRef);
    if (!orderDoc.exists) return;

    const currentData = orderDoc.data() || {};
    if (currentData.status === "FULFILLED") {
      // Already fulfilled, avoid duplicate operations
      return;
    }

    const orderCurrency = (currentData.currency || currency || metadata?.currency || "INR").toUpperCase();
    effectiveCurrency = orderCurrency;

    let wasActiveMember = false;
    let oldTierRef: admin.firestore.DocumentReference | null = null;
    let memberRef: admin.firestore.DocumentReference | null = null;
    let tierRef: admin.firestore.DocumentReference | null = null;
    let channelRef: admin.firestore.DocumentReference | null = null;
    let userMembershipRef: admin.firestore.DocumentReference | null = null;
    let legacyMembershipRef: admin.firestore.DocumentReference | null = null;
    let receiptRef: admin.firestore.DocumentReference | null = null;

    if (purpose === "channel_membership") {
      const { channelId, tierId } = metadata;
      if (channelId && tierId) {
        memberRef = firestore
          .collection("channels")
          .doc(channelId)
          .collection("members")
          .doc(userId);

        const memberDoc = await transaction.get(memberRef);
        wasActiveMember = memberDoc.exists && memberDoc.data()?.status === "active";
        const previousTierId = memberDoc.exists ? memberDoc.data()?.tierId : null;
        if (previousTierId && previousTierId !== tierId) {
          oldTierRef = firestore
            .collection("channels")
            .doc(channelId)
            .collection("membership_tiers")
            .doc(previousTierId);
        }

        tierRef = firestore
          .collection("channels")
          .doc(channelId)
          .collection("membership_tiers")
          .doc(tierId);

        channelRef = firestore.collection("channels").doc(channelId);

        userMembershipRef = firestore
          .collection("users")
          .doc(userId)
          .collection("channel_memberships")
          .doc(channelId);

        legacyMembershipRef = firestore
          .collection("users")
          .doc(userId)
          .collection("channelMemberships")
          .doc(channelId);

        receiptRef = firestore.collection("payment_receipts").doc(orderId);
      }
    }

    // -------------------------------------------------------------
    // 2. ALL WRITES COMMENCE AFTER ALL READS ARE COMPLETE
    // -------------------------------------------------------------
    didFulfill = true;
    transaction.update(orderRef, {
      status: "FULFILLED",
      fulfilledAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const now = Date.now();

    if (purpose === "premium_subscription") {
      const planId = metadata.planId || "individual_monthly";
      const isYearly = planId.includes("yearly");
      const durationDays = isYearly ? 365 : 30;
      const expiresAt = now + durationDays * 24 * 60 * 60 * 1000;

      const userRef = firestore.collection("users").doc(userId);
      transaction.set(
        userRef,
        {
          isPremium: true,
          premiumPlanId: planId,
          premiumStartedAt: now,
          premiumExpiresAt: expiresAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      const receiptRef = firestore.collection("payment_receipts").doc(orderId);
      transaction.set(receiptRef, {
        orderId,
        userId,
        planId,
        amount,
        currency: orderCurrency,
        status: "verified",
        paymentGateway: "cashfree",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const subRef = firestore.collection("premium_subscriptions").doc(userId);
      transaction.set(
        subRef,
        {
          userId,
          planId,
          amount,
          currency: orderCurrency,
          isPremium: true,
          paymentGateway: "cashfree",
          orderId,
          subscribedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
        },
        { merge: true }
      );
    } else if (purpose === "advertiser_wallet") {
      const isExclusive = Boolean(metadata.isNet || metadata.gstInclusive === false);
      let net: number;
      let tax: number;

      if (isExclusive) {
        net = Number(amount.toFixed(2));
        tax = Number((amount * 0.18).toFixed(2));
      } else if (metadata.netAmount !== undefined && !isNaN(Number(metadata.netAmount)) && Number(metadata.netAmount) > 0) {
        net = Number(Number(metadata.netAmount).toFixed(2));
        tax = metadata.taxAmount !== undefined && !isNaN(Number(metadata.taxAmount))
          ? Number(Number(metadata.taxAmount).toFixed(2))
          : Number((amount - net).toFixed(2));
      } else {
        // GST is inclusive in gross amount paid (e.g. ₹1,180 gross = ₹1,000 ad credit + ₹180 GST)
        net = Number((amount * (100 / 118)).toFixed(2));
        tax = Number((amount - net).toFixed(2));
      }

      const spendableCredit = net;

      const advertiserRef = firestore.collection("advertiser_profiles").doc(userId);
      transaction.set(
        advertiserRef,
        {
          walletBalance: admin.firestore.FieldValue.increment(spendableCredit),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      const txRef = advertiserRef.collection("billing_transactions").doc(orderId);
      transaction.set(txRef, {
        id: `INV-${Date.now().toString().slice(5)}`,
        orderId,
        date: new Date().toISOString(),
        description: `Wallet Recharge (Cashfree) - Ad Credit: ₹${spendableCredit.toFixed(2)}, GST (18%): ₹${tax.toFixed(2)}`,
        amount,
        spendableCredit,
        tax,
        net,
        status: "Paid",
        paymentMethod: "Cashfree PG",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (purpose === "advertiser_campaign") {
      const campaignId = metadata.campaignId;
      const isTopup = metadata.isTopup === true;
      if (campaignId) {
        const campaignRef = firestore.collection("ad_campaigns").doc(campaignId);
        if (isTopup) {
          // Top-up to existing campaign: increment budget and preserve active status
          transaction.set(
            campaignRef,
            {
              isPaid: true,
              orderId,
              budgetAmount: admin.firestore.FieldValue.increment(amount),
              paidAmount: admin.firestore.FieldValue.increment(amount),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } else {
          // Initial creation of campaign: set underReview
          transaction.set(
            campaignRef,
            {
              isPaid: true,
              status: "underReview",
              orderId,
              paidAmount: amount,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }
    } else if (purpose === "channel_topup" || purpose === "channel_wallet_topup" || purpose === "custom_channel_plan") {
      const channelId = metadata.channelId;
      if (channelId) {
        const channelRef = firestore.collection("channels").doc(channelId);
        const packType = metadata.packType;
        const amountUSD = metadata.amountUSD || (amount > 0 ? Number((amount / 84.0).toFixed(2)) : 0);

        if (purpose === "custom_channel_plan") {
          const planTier = String(metadata.planTier || "starter_15");
          const autoPay = metadata.autoPay !== false;
          let storageGB = 50;
          let bandwidthGB = 250;
          let fee = metadata.priceUSD || 15.0;

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

          transaction.set(
            channelRef,
            {
              channelType: "custom",
              "infraConfig.planTier": planTier,
              "infraConfig.flatPlatformFee": fee,
              "infraConfig.autoPay": autoPay,
              "infraConfig.storageQuotaBytes": storageGB * 1024 * 1024 * 1024,
              "infraConfig.bandwidthQuotaBytesThisMonth": bandwidthGB * 1024 * 1024 * 1024,
              "infraConfig.isWithdrawalHeld": false,
              "infraConfig.withdrawalHoldReason": "",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } else if (packType === "storage") {
          const additionalBytes = (metadata.gigabytes || 0) * 1024 * 1024 * 1024;
          transaction.set(
            channelRef,
            {
              "infraConfig.storageQuotaBytes": admin.firestore.FieldValue.increment(additionalBytes),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } else if (packType === "bandwidth") {
          const additionalBytes = (metadata.gigabytes || 0) * 1024 * 1024 * 1024;
          transaction.set(
            channelRef,
            {
              "infraConfig.bandwidthQuotaBytesThisMonth": admin.firestore.FieldValue.increment(additionalBytes),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } else if (packType === "balance" || purpose === "channel_wallet_topup") {
          transaction.set(
            channelRef,
            {
              walletBalanceUSD: admin.firestore.FieldValue.increment(amountUSD),
              walletBalance: admin.firestore.FieldValue.increment(amountUSD),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }

        const txRef = firestore.collection("channel_wallet_transactions").doc(orderId);
        transaction.set(txRef, {
          id: orderId,
          channelId,
          userId,
          amount: amountUSD,
          trialCreditDeducted: 0,
          fundedDeducted: 0,
          revenueDeducted: 0,
          category: metadata.category || "walletTopup",
          description: metadata.description || `Wallet Deposit (+$${amountUSD.toFixed(2)}) via Cashfree`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          paymentGateway: "cashfree",
          metadata: {
            ...metadata,
            inrAmount: amount,
          },
        });
      }
    } else if (purpose === "superchat" || purpose === "super_thanks") {
      const { channelId, videoId, text, userName, userProfilePicUrl, tierColor } = metadata;
      if (channelId) {
        const superchatRef = firestore
          .collection("channels")
          .doc(channelId)
          .collection("superchats")
          .doc(orderId);

        transaction.set(superchatRef, {
          superchatId: orderId,
          videoId: videoId || "",
          channelId,
          userId,
          userName: userName || "Supporter",
          userProfilePicUrl: userProfilePicUrl || "",
          text: text || "",
          amount,
          currency: orderCurrency,
          tierColor: tierColor || "#1E88E5",
          paymentIntentId: "cashfree",
          orderId,
          status: "completed",
          type: purpose,
          settlementStatus: "clearing",
          clearAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (purpose === "super_thanks") {
          const donationRef = firestore
            .collection("channels")
            .doc(channelId)
            .collection("donations")
            .doc(orderId);

          transaction.set(donationRef, {
            id: orderId,
            amount,
            currency: orderCurrency,
            donorId: userId,
            donorName: userName || "Supporter",
            videoId: videoId || "",
            orderId,
            commentText: text || "",
            donatedAt: admin.firestore.FieldValue.serverTimestamp(),
            type: "super_thanks",
            status: "completed",
          });
        }

        const receiptRef = firestore.collection("payment_receipts").doc(orderId);
        transaction.set(receiptRef, {
          orderId,
          userId,
          channelId,
          videoId: videoId || "",
          amount,
          currency: orderCurrency,
          purpose,
          status: "verified",
          paymentGateway: "cashfree",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const channelRef = firestore.collection("channels").doc(channelId);
        transaction.set(
          channelRef,
          {
            superchatRevenueTotal: admin.firestore.FieldValue.increment(amount),
            pendingRevenueTotal: admin.firestore.FieldValue.increment(amount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    } else if (purpose === "channel_membership") {
      const { channelId, tierId, tierName, channelName, userName, userAvatarUrl } = metadata;
      if (memberRef && tierRef && channelRef && userMembershipRef && receiptRef) {
        transaction.set(memberRef, {
          userId,
          userName: userName || "Channel Supporter",
          userAvatarUrl: userAvatarUrl || "",
          tierId,
          tierName: tierName || "Member",
          price: amount,
          orderId,
          paymentGateway: "cashfree",
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "active",
          settlementStatus: "clearing",
          clearAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
        });

        // Only increment member count if this user was not already active in the tier
        if (!wasActiveMember) {
          transaction.set(
            tierRef,
            {
              memberCount: admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        } else if (oldTierRef) {
          transaction.set(
            oldTierRef,
            {
              memberCount: admin.firestore.FieldValue.increment(-1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
          transaction.set(
            tierRef,
            {
              memberCount: admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }

        transaction.set(
          channelRef,
          {
            membershipRevenueTotal: admin.firestore.FieldValue.increment(amount),
            pendingRevenueTotal: admin.firestore.FieldValue.increment(amount),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        const membershipData = {
          channelId,
          channelName: channelName || "",
          tierId,
          tierName: tierName || "Member",
          price: amount,
          status: "active",
          orderId,
          paymentGateway: "cashfree",
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        transaction.set(userMembershipRef, membershipData, { merge: true });
        if (legacyMembershipRef) {
          transaction.set(legacyMembershipRef, membershipData, { merge: true });
        }

        transaction.set(receiptRef, {
          orderId,
          userId,
          channelId,
          tierId,
          amount,
          currency: orderCurrency,
          status: "verified",
          paymentGateway: "cashfree",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  });

  // Post Superchat event to Realtime Database stream for live chat overlay (only on genuine fulfillment)
  if (didFulfill && purpose === "superchat" && metadata.videoId) {
    try {
      const rtdb = admin.database();
      const videoId = metadata.videoId;
      const userName = metadata.userName || "Supporter";
      const userProfilePicUrl = metadata.userProfilePicUrl || "";
      const text = metadata.text || "";
      const tierColor = metadata.tierColor || "#1E88E5";
      const now = Date.now();

      let displayDurationMs = 60 * 1000;
      if (amount >= 4000) {
        displayDurationMs = 10 * 60 * 1000;
      } else if (amount >= 1500) {
        displayDurationMs = 5 * 60 * 1000;
      } else if (amount >= 800) {
        displayDurationMs = 2 * 60 * 1000;
      } else if (amount >= 400) {
        displayDurationMs = 90 * 1000;
      }
      const expiresAt = now + displayDurationMs;

      const messageRef = rtdb.ref(`liveChat/${videoId}/messages`).push();
      const messageId = messageRef.key;

      await messageRef.set({
        id: messageId,
        videoId,
        userId,
        userName,
        userProfilePicUrl,
        text,
        isSuperchat: true,
        superchatAmount: amount,
        superchatCurrency: effectiveCurrency,
        superchatTierColor: tierColor,
        timestamp: admin.database.ServerValue.TIMESTAMP,
      });

      await rtdb.ref(`liveChat/${videoId}/pinned`).set({
        superchatId: orderId,
        messageId,
        userId,
        userName,
        userProfilePicUrl,
        text,
        amount,
        currency: effectiveCurrency,
        tierColor,
        expiresAt,
        createdAt: now,
      });
    } catch (rtdbErr) {
      console.warn("[fulfillOrder] Failed to post superchat to RTDB:", rtdbErr);
    }
  }
}

/**
 * 1. Create Cashfree Order
 */
export const createCashfreeOrder = onCall(
  {
    region: REGION,
    secrets: ["CASHFREE_APP_ID", "CASHFREE_SECRET_KEY"],
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      const callerUid = request.auth?.uid;
      if (!callerUid) {
        throw new HttpsError("unauthenticated", "User must be authenticated to initiate payment.");
      }

    const {
      amount,
      currency: rawCurrency = "INR",
      purpose,
      orderNote,
      customerPhone,
      metadata = {},
    } = request.data || {};

    const currency = String(rawCurrency || "INR").trim().toUpperCase();
    if (!CashfreeService.isCurrencySupported(currency)) {
      throw new HttpsError(
        "invalid-argument",
        `The selected currency (${currency}) is not currently supported by Cashfree Payment Gateway.`
      );
    }

    const minAmount = CashfreeService.getMinimumAmount(currency);
    if (
      typeof amount !== "number" ||
      isNaN(amount) ||
      !isFinite(amount) ||
      amount < minAmount
    ) {
      const formattedMin = CashfreeService.formatCurrencyAmount(minAmount, currency);
      throw new HttpsError(
        "invalid-argument",
        `Payment amount must be at least ${formattedMin}.`
      );
    }

    const maxAmount = currency === "INR" ? 500000 : (CashfreeService.isZeroDecimalCurrency(currency) ? 1000000 : 10000);
    if (amount > maxAmount) {
      const formattedMax = CashfreeService.formatCurrencyAmount(maxAmount, currency);
      throw new HttpsError(
        "invalid-argument",
        `Payment amount exceeds the maximum allowable limit of ${formattedMax} per transaction.`
      );
    }

    if (!purpose) {
      throw new HttpsError("invalid-argument", "Payment purpose is required.");
    }

    const ALLOWED_PURPOSES = [
      "premium_subscription",
      "channel_membership",
      "advertiser_wallet",
      "advertiser_campaign",
      "channel_topup",
      "channel_wallet_topup",
      "superchat",
      "super_thanks",
      "custom_channel_plan",
    ];

    if (!ALLOWED_PURPOSES.includes(purpose)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid or unsupported payment purpose."
      );
    }

    if (purpose === "user_wallet_topup" || purpose === "user_topup") {
      throw new HttpsError(
        "failed-precondition",
        "User wallet services have been discontinued. Wallet services are exclusively available for creator channels."
      );
    }

    if (!CashfreeService.isConfigured()) {
      console.warn("[createCashfreeOrder] Cashfree credentials (CASHFREE_APP_ID / CASHFREE_SECRET_KEY) are not set in Secret Manager.");
      throw new HttpsError(
        "failed-precondition",
        "Payment gateway is not currently configured. Please configure Cashfree API keys in Google Cloud Secret Manager."
      );
    }

    const firestore = admin.firestore();
    const userDoc = await firestore.collection("users").doc(callerUid).get();
    const userData = userDoc.data() || {};
    const customerEmail = userData.email || request.auth?.token.email || "user@truthworld.tv";
    const customerName = userData.displayName || userData.name || "TruthWorld User";

    const countryToCheck = String(metadata?.userCountry || userData.country || userData.countryCode || "").trim().toUpperCase();
    if (countryToCheck && CashfreeService.isRestrictedCountry(countryToCheck)) {
      throw new HttpsError(
        "failed-precondition",
        "Payment services are currently unavailable in your region due to regulatory compliance restrictions."
      );
    }

    const cleanPurpose = String(purpose).replace(/[^a-zA-Z0-9_]/g, "");
    const randomHex = crypto.randomBytes(4).toString("hex");
    const orderId = `cf_${cleanPurpose}_${Date.now()}_${randomHex}`;
    const isAutoPay = Boolean(metadata?.autoPay === true || metadata?.autoPay === "true");

    const ALLOWED_METADATA_KEYS = [
      "planId",
      "channelId",
      "campaignId",
      "billingCycle",
      "amountUSD",
      "adId",
      "creatorId",
      "tierId",
      "autoPay",
      "videoId",
      "userCountry",
      "currency",
      "text",
      "userName",
      "userProfilePicUrl",
      "tierColor",
      "chargeAmount",
      "originalAmount",
      "originalCurrency",
      "isDebug",
    ];
    const safeMetadata: Record<string, any> = {};
    if (metadata && typeof metadata === "object") {
      for (const k of ALLOWED_METADATA_KEYS) {
        if (k in metadata) {
          safeMetadata[k] = metadata[k];
        }
      }
    }

    const sanitizedTags = CashfreeService.sanitizeOrderTags({
      userId: callerUid,
      purpose: cleanPurpose,
      autoPay: isAutoPay ? "true" : "false",
      ...safeMetadata,
    });

    // ─── Cashfree Subscriptions / Auto Pay Mandate Flow ────────────────────
    if (isAutoPay) {
      try {
        let planId = "";
        let planName = "";
        let intervalType: "MONTH" | "YEAR" = "MONTH";

        if (cleanPurpose === "premium_subscription") {
          const rawPlan = String(metadata?.planId || "individual_monthly").toLowerCase().replace(/[^a-z0-9_]/g, "");
          intervalType = rawPlan.includes("yearly") ? "YEAR" : "MONTH";
          planId = `plan_tw_prem_${rawPlan}_${Math.round(amount)}`;
          planName = `TruthWorld Premium ${rawPlan.toUpperCase()}`;
        } else if (cleanPurpose === "channel_membership") {
          const chanKey = String(metadata?.channelId || "chan").substring(0, 10).replace(/[^a-zA-Z0-9_]/g, "");
          const tierKey = String(metadata?.tierId || "tier").substring(0, 10).replace(/[^a-zA-Z0-9_]/g, "");
          planId = `plan_tw_mbr_${chanKey}_${tierKey}`;
          planName = `${metadata?.channelName || "Channel"} Membership ${metadata?.tierName || "Tier"}`.replace(/[()]/g, "").trim();
          intervalType = "MONTH";
        } else if (cleanPurpose === "custom_channel_plan" || cleanPurpose === "channel_infra_plan") {
          const tierKey = String(metadata?.planTier || "starter_15").replace(/[^a-zA-Z0-9_]/g, "");
          planId = `plan_tw_infra_${tierKey}_${Math.round(amount)}`;
          planName = `TruthWorld Studio Infrastructure ${metadata?.planName || tierKey}`.replace(/[()]/g, "").trim();
          intervalType = "MONTH";
        } else {
          planId = `plan_tw_${cleanPurpose}_${Math.round(amount)}`;
          planName = `TruthWorld ${cleanPurpose}`;
          intervalType = "MONTH";
        }

        // 1. Ensure recurring plan exists on Cashfree
        await CashfreeService.createSubscriptionPlan({
          planId,
          planName,
          planType: "PERIODIC",
          planCurrency: currency,
          planAmount: amount,
          planMaxAmount: Math.max(15000, amount * 2),
          planIntervalType: intervalType,
          planIntervals: 1,
          planMaxCycles: intervalType === "YEAR" ? 10 : 120,
          planNote: orderNote || `TruthWorld ${purpose} recurring subscription plan`,
        });

        // 2. Create subscription mandate with customer details
        const subId = `sub_${cleanPurpose}_${Date.now()}_${callerUid.substring(0, 5)}`;
        const returnUrl = `https://www.truthworld.in/payment-result?subscription_id=${encodeURIComponent(subId)}&order_id=${encodeURIComponent(orderId)}`;

        const cfSub = await CashfreeService.createSubscription({
          subscriptionId: subId,
          planId,
          customerDetails: {
            customer_id: callerUid,
            customer_name: customerName,
            customer_email: customerEmail,
            customer_phone: customerPhone || userData.phone || "9999999999",
          },
          returnUrl,
          authorizationAmount: amount,
          paymentMethods: ["upi", "card", "enach"],
          subscriptionTags: sanitizedTags,
          subscriptionNote: orderNote || `TruthWorld ${purpose} recurring subscription mandate`,
        });

        const authLink = cfSub.auth_link || "";
        const paymentSessionId = cfSub.payment_session_id || "";

        // Record in Firestore payment_subscriptions collection
        await firestore.collection("payment_subscriptions").doc(subId).set({
          subscriptionId: subId,
          subReferenceId: cfSub.sub_reference_id || "",
          planId,
          userId: callerUid,
          amount,
          currency,
          purpose,
          status: cfSub.subscription_status || "INITIALIZED",
          authLink,
          paymentSessionId,
          metadata: {
            ...metadata,
            autoPay: true,
            orderId,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Mirror in payment_orders for unified ledger and tracking
        await firestore.collection("payment_orders").doc(orderId).set({
          orderId,
          userId: callerUid,
          amount,
          currency,
          purpose,
          status: "ACTIVE",
          isSubscription: true,
          subscriptionId: subId,
          authLink,
          paymentSessionId,
          paymentLink: authLink,
          metadata: {
            ...metadata,
            autoPay: true,
            subscriptionId: subId,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return {
          success: true,
          orderId,
          subscriptionId: subId,
          subReferenceId: cfSub.sub_reference_id || "",
          isSubscription: true,
          authLink,
          paymentSessionId,
          orderAmount: amount,
          orderCurrency: currency,
          paymentLink: authLink,
          environment: CashfreeService.PublicEnvironment,
        };
      } catch (subErr: any) {
        console.warn(
          "[createCashfreeOrder] Subscriptions API fallback to standard PG order:",
          subErr?.response?.data || subErr?.message || subErr
        );
        // Fall back gracefully to standard PG order below with Auto Pay metadata tags
      }
    }

    try {
      const cfOrder = await CashfreeService.createOrder({
        orderId,
        orderAmount: amount,
        orderCurrency: currency,
        customerDetails: {
          customer_id: callerUid,
          customer_name: customerName,
          customer_email: customerEmail,
          customer_phone: customerPhone || userData.phone || "9999999999",
        },
        orderNote: orderNote || `TruthWorld ${purpose} payment`,
        orderTags: sanitizedTags,
      });

      // Direct Web / Desktop checkouts to TruthWorld's secure hosted checkout container
      const envParam = CashfreeService.PublicEnvironment.toLowerCase();
      const paymentLink = `https://www.truthworld.in/checkout?session_id=${encodeURIComponent(cfOrder.payment_session_id || "")}&order_id=${encodeURIComponent(orderId)}&env=${envParam}`;

      await firestore.collection("payment_orders").doc(orderId).set({
        orderId,
        cfOrderId: cfOrder.cf_order_id,
        userId: callerUid,
        amount,
        currency,
        purpose,
        status: "ACTIVE",
        paymentSessionId: cfOrder.payment_session_id || "",
        paymentLink: paymentLink || "",
        metadata,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        orderId,
        paymentSessionId: cfOrder.payment_session_id || "",
        orderAmount: amount,
        orderCurrency: currency,
        paymentLink: paymentLink || "",
        environment: CashfreeService.PublicEnvironment,
      };
    } catch (err: any) {
      console.error("[createCashfreeOrder] PG order error:", err?.response?.data || err?.message || err);
      const errData = err?.response?.data;
      const rawMsg = (errData?.message || err?.message || "").toLowerCase();
      if (
        errData?.type === "authentication_error" ||
        rawMsg.includes("authentication failed") ||
        rawMsg.includes("unauthorized")
      ) {
        throw new HttpsError(
          "unavailable",
          "The payment gateway is temporarily unavailable. Please try again shortly or contact support."
        );
      }
      throw new HttpsError(
        "unavailable",
        "Unable to initialize payment session. Please try again in a few moments."
      );
    }
  } catch (topErr: any) {
    if (topErr instanceof HttpsError) {
      throw topErr;
    }
    console.error("[createCashfreeOrder] Unhandled error:", topErr?.response?.data || topErr?.message || topErr);
    throw new HttpsError(
      "unavailable",
      "Unable to initialize payment session. Please try again in a few moments."
    );
  }
}
);

/**
 * 2. Authoritative Verification of Cashfree Payment Order
 */
export const verifyCashfreePayment = onCall(
  {
    region: REGION,
    secrets: ["CASHFREE_APP_ID", "CASHFREE_SECRET_KEY"],
    enforceAppCheck: false,
  },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const { orderId } = request.data || {};
    if (!orderId || typeof orderId !== "string") {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }

    const firestore = admin.firestore();
    const orderDoc = await firestore.collection("payment_orders").doc(orderId).get();

    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Payment order record not found.");
    }

    const orderData = orderDoc.data() || {};
    if (orderData.userId !== callerUid) {
      throw new HttpsError("permission-denied", "Unauthorized order verification access.");
    }

    if (orderData.status === "PAID" || orderData.status === "FULFILLED") {
      return {
        success: true,
        orderStatus: "PAID",
        orderId,
      };
    }

    if (!CashfreeService.isConfigured()) {
      throw new HttpsError(
        "failed-precondition",
        "Payment gateway is not currently configured."
      );
    }

    try {
      // Query Cashfree authoritatively
      const cfOrder = await CashfreeService.getOrder(orderId);

      if (cfOrder.order_status === "PAID") {
        await firestore.collection("payment_orders").doc(orderId).update({
          status: "PAID",
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          cfOrderStatus: cfOrder.order_status,
        });

        // Fulfill business requirement
        await fulfillOrder(
          orderId,
          orderData.userId,
          orderData.purpose,
          orderData.amount,
          orderData.metadata || {}
        );

        return {
          success: true,
          orderStatus: "PAID",
          orderId,
        };
      } else {
        return {
          success: false,
          orderStatus: cfOrder.order_status,
          orderId,
        };
      }
    } catch (err: any) {
      console.error("[verifyCashfreePayment] Error:", err?.response?.data || err?.message || err);
      throw new HttpsError("unavailable", "Unable to verify payment status with the gateway. Please try again shortly.");
    }
  }
);

/**
 * 3. Authoritative Verification of Cashfree Subscription Mandate (Auto Pay)
 */
export const verifyCashfreeSubscription = onCall(
  {
    region: REGION,
    secrets: ["CASHFREE_APP_ID", "CASHFREE_SECRET_KEY"],
    enforceAppCheck: false,
  },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const { subscriptionId } = request.data || {};
    if (!subscriptionId || typeof subscriptionId !== "string") {
      throw new HttpsError("invalid-argument", "subscriptionId is required.");
    }

    const firestore = admin.firestore();
    const subDoc = await firestore.collection("payment_subscriptions").doc(subscriptionId).get();

    if (!subDoc.exists) {
      throw new HttpsError("not-found", "Subscription record not found.");
    }

    const subData = subDoc.data() || {};
    if (subData.userId !== callerUid) {
      throw new HttpsError("permission-denied", "Unauthorized subscription access.");
    }

    if (subData.status === "ACTIVE" || subData.status === "FULFILLED") {
      return {
        success: true,
        subscriptionStatus: "ACTIVE",
        subscriptionId,
      };
    }

    if (!CashfreeService.isConfigured()) {
      throw new HttpsError(
        "failed-precondition",
        "Payment gateway is not currently configured."
      );
    }

    try {
      const cfSub = await CashfreeService.getSubscription(subscriptionId);
      const status = (cfSub.subscription_status || "").toUpperCase();
      const isSuccess = status === "ACTIVE";
      const isPending = status === "BANK_APPROVAL_PENDING";

      if (isPending) {
        await firestore.collection("payment_subscriptions").doc(subscriptionId).update({
          status: "BANK_APPROVAL_PENDING",
          cfStatus: status,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {
          success: false,
          pending: true,
          subscriptionStatus: "BANK_APPROVAL_PENDING",
          message: "Subscription mandate is pending bank approval. Benefits will activate once approved.",
        };
      }

      if (isSuccess) {
        await firestore.collection("payment_subscriptions").doc(subscriptionId).update({
          status: "ACTIVE",
          cfStatus: status,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Fulfill associated order and activate benefits
        const orderId = subData.metadata?.orderId || `cf_sub_${subscriptionId}`;
        await fulfillOrder(
          orderId,
          subData.userId,
          subData.purpose,
          subData.amount,
          {
            ...subData.metadata,
            subscriptionId,
            autoPay: true,
          }
        );

        return {
          success: true,
          subscriptionStatus: "ACTIVE",
          subscriptionId,
        };
      } else {
        return {
          success: false,
          subscriptionStatus: status || "PENDING",
          subscriptionId,
        };
      }
    } catch (err: any) {
      console.error("[verifyCashfreeSubscription] Error:", err?.response?.data || err?.message || err);
      throw new HttpsError("unavailable", "Unable to verify subscription mandate status with the gateway.");
    }
  }
);

/**
 * 4. Cancel Cashfree Recurring Auto Pay Subscription
 */
export const cancelCashfreeSubscription = onCall(
  {
    region: REGION,
    secrets: ["CASHFREE_APP_ID", "CASHFREE_SECRET_KEY"],
    enforceAppCheck: false,
  },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const { subscriptionId, reason } = request.data || {};
    if (!subscriptionId || typeof subscriptionId !== "string") {
      throw new HttpsError("invalid-argument", "subscriptionId is required.");
    }

    const firestore = admin.firestore();
    const subDoc = await firestore.collection("payment_subscriptions").doc(subscriptionId).get();

    if (!subDoc.exists) {
      throw new HttpsError("not-found", "Subscription record not found.");
    }

    const subData = subDoc.data() || {};
    if (subData.userId !== callerUid) {
      throw new HttpsError("permission-denied", "Unauthorized subscription access.");
    }

    try {
      if (CashfreeService.isConfigured()) {
        try {
          await CashfreeService.cancelSubscription(
            subscriptionId,
            reason || "Cancelled by user in TruthWorld"
          );
        } catch (cfErr: any) {
          console.warn("[cancelCashfreeSubscription] Gateway cancel notice:", cfErr?.message || cfErr);
        }
      }

      await firestore.collection("payment_subscriptions").doc(subscriptionId).update({
        status: "CANCELLED",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancellationReason: reason || "User request",
      });

      // Update user or channel autoPay state in database
      if (subData.purpose === "premium_subscription") {
        await firestore.collection("users").doc(callerUid).update({
          isAutoPay: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await firestore.collection("premium_subscriptions").doc(callerUid).update({
          autoPay: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else if (subData.purpose === "channel_membership") {
        const channelId = subData.metadata?.channelId;
        if (channelId) {
          await firestore
            .collection("channels")
            .doc(channelId)
            .collection("members")
            .doc(callerUid)
            .update({
              autoPay: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          await firestore
            .collection("users")
            .doc(callerUid)
            .collection("channel_memberships")
            .doc(channelId)
            .update({
              autoPay: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
      } else if (subData.purpose === "custom_channel_plan" || subData.purpose === "channel_infra_plan") {
        const channelId = subData.metadata?.channelId;
        if (channelId) {
          await firestore.collection("channels").doc(channelId).update({
            "infraConfig.autoPay": false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      return {
        success: true,
        subscriptionId,
        status: "CANCELLED",
      };
    } catch (err: any) {
      console.error("[cancelCashfreeSubscription] Error:", err?.message || err);
      throw new HttpsError("unavailable", "Unable to cancel auto pay subscription. Please try again.");
    }
  }
);

/**
 * 5. Cashfree Asynchronous Webhook Listener (Orders & Recurring Subscriptions)
 */
export const cashfreeWebhook = onRequest(
  {
    region: REGION,
    cors: false,
    secrets: ["CASHFREE_APP_ID", "CASHFREE_SECRET_KEY"],
  },
  async (req, res) => {
    applySecurityHeaders(res);
    // 1. Support test pings, healthchecks, and CORS preflights (GET / HEAD / OPTIONS)
    if (req.method === "GET" || req.method === "HEAD" || req.method === "OPTIONS") {
      res.status(200).json({ status: "ok", message: "TruthWorld Cashfree Webhook Active" });
      return;
    }

    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // 2. Cryptographic Webhook HMAC-SHA256 Verification & Replay Protection
    const signature = (req.headers["x-webhook-signature"] as string) || "";
    const timestamp = (req.headers["x-webhook-timestamp"] as string) || "";

    if (timestamp) {
      const tsNum = parseInt(timestamp, 10);
      const nowSec = Math.floor(Date.now() / 1000);
      const effectiveTs = tsNum > 1000000000000 ? Math.floor(tsNum / 1000) : tsNum;
      if (Math.abs(nowSec - effectiveTs) > 300) {
        console.warn(`[cashfreeWebhook] Rejected webhook with expired timestamp: ${timestamp}`);
        res.status(400).send("Expired webhook timestamp");
        return;
      }
    }

    if (signature && timestamp) {
      const rawBody = (req as any).rawBody ? (req as any).rawBody.toString("utf8") : JSON.stringify(req.body);
      const isValid = CashfreeService.verifyWebhookSignature(signature, rawBody, timestamp);
      if (!isValid) {
        console.warn("[cashfreeWebhook] Rejected webhook with invalid HMAC signature");
        res.status(401).send("Invalid webhook signature");
        return;
      }
    } else if (CashfreeService.isConfigured()) {
      // Unconditionally reject webhooks missing signature headers when Cashfree is configured
      console.warn("[cashfreeWebhook] Rejected webhook: missing x-webhook-signature / x-webhook-timestamp");
      res.status(401).send("Missing webhook signature headers");
      return;
    }

    try {
      const firestore = admin.firestore();

      // ─── A. Check for Subscription Events ───────────────────────────
      const subscriptionId =
        req.body?.data?.subscription?.subscription_id ||
        req.body?.subscription?.subscription_id ||
        req.body?.subscription_id ||
        req.body?.data?.subscription_id;

      if (subscriptionId) {
        try {
          const verifiedSub = await CashfreeService.getSubscription(subscriptionId);
          const status = (verifiedSub.subscription_status || "").toUpperCase();

          if (status === "ACTIVE") {
            const subDoc = await firestore.collection("payment_subscriptions").doc(subscriptionId).get();
            if (subDoc.exists) {
              const subData = subDoc.data() || {};
              await firestore.collection("payment_subscriptions").doc(subscriptionId).update({
                status: "ACTIVE",
                cfStatus: status,
                verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              const orderId = subData.metadata?.orderId || `cf_sub_${subscriptionId}`;
              await fulfillOrder(
                orderId,
                subData.userId,
                subData.purpose,
                subData.amount,
                {
                  ...subData.metadata,
                  subscriptionId,
                  autoPay: true,
                }
              );
            }
          } else if (status === "CANCELLED") {
            await firestore.collection("payment_subscriptions").doc(subscriptionId).update({
              status: "CANCELLED",
              cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        } catch (subErr: any) {
          console.error(`[cashfreeWebhook] Error processing subscription ${subscriptionId}:`, subErr?.message || subErr);
        }

        res.status(200).json({ status: "acknowledged", subscription_id: subscriptionId });
        return;
      }

      // ─── B. Check for One-Time / Standard Order Events ──────────────
      const orderId =
        req.body?.data?.order?.order_id ||
        req.body?.order?.order_id ||
        req.body?.orderId ||
        req.body?.data?.orderId;

      // Handle Cashfree Dashboard "Test" button / verification ping
      if (!orderId) {
        console.log("[cashfreeWebhook] Test ping received from Cashfree:", {
          type: req.body?.type,
          event_time: req.body?.event_time,
        });
        res.status(200).json({ status: "acknowledged", message: "Cashfree test ping received successfully" });
        return;
      }

      // Query Cashfree directly to prevent any forged webhook payloads
      try {
        const verifiedOrder = await CashfreeService.getOrder(orderId);
        if (verifiedOrder.order_status === "PAID") {
          const orderDoc = await firestore.collection("payment_orders").doc(orderId).get();

          if (orderDoc.exists) {
            const orderData = orderDoc.data() || {};
            await fulfillOrder(
              orderId,
              orderData.userId,
              orderData.purpose,
              orderData.amount,
              orderData.metadata || {}
            );
          }
        }
      } catch (orderErr: any) {
        // If Cashfree dashboard tests with a mock/test orderId that does not exist in gateway API
        if (orderErr?.response?.status === 404) {
          console.log(`[cashfreeWebhook] Test order ${orderId} not found in gateway (test ping)`);
          res.status(200).json({ status: "acknowledged", message: "Test order acknowledged" });
          return;
        }
        throw orderErr;
      }

      res.status(200).json({ status: "acknowledged" });
    } catch (err: any) {
      console.error("[cashfreeWebhook] Error:", err);
      res.status(500).json({ error: "Internal processing error" });
    }
  }
);

/**
 * 4. Cashfree Hosted Web Checkout Container
 * Used by Web and Desktop platforms to render Cashfree JS SDK v3 checkout and display branded payment results.
 */
export const cashfreeHostedCheckout = onRequest(
  {
    region: REGION,
    cors: [
      "https://www.truthworld.in",
      "https://truthworld.in",
      "https://www.truthworld.app",
      "https://truthworld.app",
    ],
    secrets: ["CASHFREE_APP_ID", "CASHFREE_SECRET_KEY"],
  },
  async (req, res) => {
    applySecurityHeaders(res);
    const action = ((req.query.action as string) || (req.body?.action as string) || "").toLowerCase();
    const rawOrderId = (
      (req.query.order_id as string) ||
      (req.query.orderId as string) ||
      (req.query.cf_order_id as string) ||
      (req.body?.order_id as string) ||
      (req.body?.orderId as string) ||
      (req.body?.cf_order_id as string) ||
      ""
    ).trim();
    const orderId = rawOrderId === "{order_id}" ? "" : rawOrderId;
    const sessionId = (
      (req.query.session_id as string) ||
      (req.query.sessionId as string) ||
      (req.body?.session_id as string) ||
      (req.body?.sessionId as string) ||
      ""
    ).trim();
    const rawEnv = ((req.query.env as string) || (req.body?.env as string) || "production").toLowerCase().trim();
    const env = rawEnv === "sandbox" ? "sandbox" : "production";

    // 1. Result confirmation view (Cashfree return_url target or direct /payment-result route)
    const isResultView =
      action === "result" ||
      req.path.includes("payment-result") ||
      (req.originalUrl && req.originalUrl.includes("payment-result")) ||
      (req.url && req.url.includes("payment-result"));

    if (isResultView) {
      if (!orderId) {
        res.setHeader("Content-Type", "text/html");
        res.status(400).send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Payment Verification - TruthWorld</title>
  <style>
    body { background:#0d0d0e; color:#ffffff; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }
    .card { background:#161618; border:1px solid #27272a; border-radius:16px; padding:36px 28px; max-width:440px; text-align:center; }
  </style>
</head>
<body>
  <div class="card">
    <h2 style="margin:0 0 12px;font-size:18px;">Order Not Specified</h2>
    <p style="color:#a1a1aa;font-size:14px;line-height:1.5;">Missing order reference. Please return to the TruthWorld app.</p>
  </div>
</body>
</html>`);
        return;
      }

      try {
        const firestore = admin.firestore();
        const orderDoc = await firestore.collection("payment_orders").doc(orderId).get();
        const orderData = orderDoc.exists ? (orderDoc.data() || {}) : null;

        let cfOrder: any = null;
        if (CashfreeService.isConfigured()) {
          try {
            cfOrder = await CashfreeService.getOrder(orderId);
          } catch (err: any) {
            console.error(`[cashfreeHostedCheckout] Error querying order ${orderId}:`, err?.message || err);
          }
        }

        const gatewayStatus = (cfOrder?.order_status || orderData?.status || "UNKNOWN").toUpperCase();
        const isPaid = gatewayStatus === "PAID" || orderData?.status === "PAID" || orderData?.status === "FULFILLED";

        if (isPaid && orderData && orderData.status !== "FULFILLED") {
          await firestore.collection("payment_orders").doc(orderId).update({
            status: "PAID",
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            cfOrderStatus: "PAID",
          });

          await fulfillOrder(
            orderId,
            orderData.userId,
            orderData.purpose,
            orderData.amount,
            orderData.metadata || {}
          );
        }

        const currencyCode = (cfOrder?.order_currency || orderData?.currency || "INR").toUpperCase();
        const amountVal = cfOrder?.order_amount ?? orderData?.amount;
        const amountDisplay = amountVal != null ? CashfreeService.formatCurrencyAmount(Number(amountVal), currencyCode) : "";
        const sanitizedOrderId = orderId.replace(/[^\w-]/g, "");

        let statusTitle = "Payment Successful";
        let statusSubtitle = "Your payment has been successfully processed. You may now return to TruthWorld.";
        let badgeColor = "#10b981";
        let badgeIcon = `<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>`;
        let isPending = false;

        if (!isPaid) {
          if (gatewayStatus === "ACTIVE" || gatewayStatus === "PENDING") {
            statusTitle = "Payment Pending Confirmation";
            statusSubtitle = "We are waiting for final confirmation from your bank. This page will update automatically.";
            badgeColor = "#3b82f6";
            badgeIcon = `<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`;
            isPending = true;
          } else {
            statusTitle = "Payment Incomplete";
            statusSubtitle = "The transaction could not be confirmed or was cancelled. If debited, funds will be refunded by your bank.";
            badgeColor = "#ef4444";
            badgeIcon = `<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`;
          }
        }

        const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${statusTitle} - TruthWorld</title>
  ${isPending ? '<meta http-equiv="refresh" content="4">' : ""}
  <style>
    * { box-sizing: border-box; }
    body {
      background-color: #0d0d0e;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 24px;
      text-align: center;
    }
    .card {
      background: #161618;
      border: 1px solid #27272a;
      border-radius: 16px;
      padding: 36px 28px;
      max-width: 440px;
      width: 100%;
      box-shadow: 0 8px 32px rgba(0,0,0,0.5);
    }
    .icon-badge {
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: ${badgeColor};
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 20px;
    }
    .title { font-size: 20px; font-weight: 700; margin-bottom: 8px; color: #ffffff; }
    .subtitle { font-size: 13px; color: #a1a1aa; line-height: 1.5; margin-bottom: 24px; }
    .details {
      background: #1e1e22;
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 24px;
      text-align: left;
      font-size: 13px;
    }
    .detail-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 8px;
    }
    .detail-row:last-child { margin-bottom: 0; }
    .detail-label { color: #a1a1aa; }
    .detail-val { color: #ffffff; font-weight: 600; }
    .action-btn {
      width: 100%;
      background: #ffffff;
      color: #000000;
      border: none;
      padding: 13px 24px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    .action-btn:hover { background: #e4e4e7; }
    .note { margin-top: 14px; font-size: 12px; color: #71717a; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-badge">${badgeIcon}</div>
    <div class="title">${statusTitle}</div>
    <div class="subtitle">${statusSubtitle}</div>

    <div class="details">
      ${amountDisplay ? `<div class="detail-row"><span class="detail-label">Amount</span><span class="detail-val">${amountDisplay}</span></div>` : ""}
      <div class="detail-row"><span class="detail-label">Order Reference</span><span class="detail-val" style="font-family:monospace;font-size:11px;">${sanitizedOrderId}</span></div>
      <div class="detail-row"><span class="detail-label">Status</span><span class="detail-val" style="color:${badgeColor};">${gatewayStatus}</span></div>
    </div>

    <button class="action-btn" onclick="returnToApp()">Return to TruthWorld</button>
    <div class="note">You may also safely close this tab or window.</div>
  </div>

  <script>
    function returnToApp() {
      try {
        window.location.href = "truthworld://payment-result?order_id=" + encodeURIComponent("${sanitizedOrderId}") + "&status=" + encodeURIComponent("${gatewayStatus}");
      } catch (e) {}
      setTimeout(function() {
        window.close();
      }, 400);
    }
  </script>
</body>
</html>`;

        res.setHeader("Content-Type", "text/html");
        res.status(200).send(html);
        return;
      } catch (err: any) {
        console.error(`[cashfreeHostedCheckout] Unhandled result error for order ${orderId}:`, err);
        const sanitizedOrderId = orderId.replace(/[^\w-]/g, "");
        const fallbackHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Payment Completed - TruthWorld</title>
  <style>
    * { box-sizing: border-box; }
    body { background-color: #0d0d0e; color: #ffffff; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; text-align: center; }
    .card { background: #161618; border: 1px solid #27272a; border-radius: 16px; padding: 36px 28px; max-width: 440px; width: 100%; box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
    .icon-badge { width: 64px; height: 64px; border-radius: 50%; background: #10b981; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; }
    .title { font-size: 20px; font-weight: 700; margin-bottom: 8px; color: #ffffff; }
    .subtitle { font-size: 13px; color: #a1a1aa; line-height: 1.5; margin-bottom: 24px; }
    .action-btn { width: 100%; background: #ffffff; color: #000000; border: none; padding: 13px 24px; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
    .action-btn:hover { background: #e4e4e7; }
    .note { margin-top: 14px; font-size: 12px; color: #71717a; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-badge">
      <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>
    </div>
    <div class="title">Payment Completed</div>
    <div class="subtitle">Your payment has been received by Cashfree. You can return to TruthWorld to access your channel membership.</div>
    <button class="action-btn" onclick="returnToApp()">Return to TruthWorld</button>
    <div class="note">Order: ${sanitizedOrderId}</div>
  </div>
  <script>
    function returnToApp() {
      try {
        window.location.href = "truthworld://payment-result?order_id=" + encodeURIComponent("${sanitizedOrderId}") + "&status=PAID";
      } catch (e) {}
      setTimeout(function() { window.close(); }, 400);
    }
  </script>
</body>
</html>`;
        res.setHeader("Content-Type", "text/html");
        res.status(200).send(fallbackHtml);
        return;
      }
    }

    // 2. Checkout Container View (Direct Form Post with SDK v3 fallback)
    if (orderId) {
      console.log(`[cashfreeHostedCheckout] Launching session for order ${orderId}`);
    }

    if (!sessionId || !/^[a-zA-Z0-9_\-]+$/.test(sessionId)) {
      res.status(400).send("<h3>Missing or invalid session_id parameter.</h3>");
      return;
    }

    res.setHeader("Permissions-Policy", "payment=*");
    res.setHeader(
      "Content-Security-Policy",
      "default-src 'self' 'unsafe-inline' https: data: blob:; " +
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://sdk.cashfree.com https://*.cashfree.com https:; " +
      "connect-src 'self' https: wss:; " +
      "frame-src 'self' https: data: blob:; " +
      "form-action 'self' https:; " +
      "img-src 'self' data: blob: https: https://*.cashfree.com;"
    );

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TruthWorld Secure Checkout</title>
  <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
  <style>
    * { box-sizing: border-box; }
    body {
      background-color: #0d0d0e;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 24px;
      text-align: center;
    }
    .card {
      background: #161618;
      border: 1px solid #27272a;
      border-radius: 16px;
      padding: 36px 28px;
      max-width: 440px;
      width: 100%;
      box-shadow: 0 8px 32px rgba(0,0,0,0.5);
    }
    .spinner {
      width: 44px;
      height: 44px;
      border: 3px solid rgba(255, 255, 255, 0.1);
      border-radius: 50%;
      border-top-color: #ffffff;
      animation: spin 0.8s linear infinite;
      margin: 0 auto 20px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .title { font-size: 18px; font-weight: 600; margin-bottom: 8px; color: #ffffff; }
    .subtitle { font-size: 13px; color: #a1a1aa; line-height: 1.5; margin-bottom: 0; }
    .action-btn {
      margin-top: 24px;
      background: #ffffff;
      color: #000000;
      border: none;
      padding: 12px 24px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      display: none;
      transition: background 0.2s;
    }
    .action-btn:hover {
      background: #e4e4e7;
    }
  </style>
</head>
<body>
  <div class="card">
    <div id="loader" class="spinner"></div>
    <div id="title" class="title">Redirecting to Secure Payment...</div>
    <div id="subtitle" class="subtitle">Connecting to Cashfree Payment Gateway. Please do not refresh.</div>
    <button id="proceedBtn" class="action-btn" onclick="retryCheckout()">Continue to Cashfree</button>
  </div>

  <script>
    let hasInitiated = false;
    const clientEnv = ${JSON.stringify(env)};
    const clientSessionId = ${JSON.stringify(sessionId)};
    const directCheckoutUrl = (clientEnv === 'sandbox'
      ? 'https://payments-test.cashfree.com/order/#'
      : 'https://payments.cashfree.com/order/#') + encodeURIComponent(clientSessionId);

    function initiateCheckout() {
      if (hasInitiated) return;
      try {
        if (typeof window.Cashfree === 'function') {
          hasInitiated = true;
          const cf = window.Cashfree({ mode: clientEnv });
          cf.checkout({
            paymentSessionId: clientSessionId,
            redirectTarget: "_self"
          }).then(function(result) {
            if (result && result.error) {
              console.warn("[Cashfree SDK result error, redirecting directly]:", result.error);
              window.location.replace(directCheckoutUrl);
            }
          }).catch(function(err) {
            console.warn("[Cashfree SDK catch error, redirecting directly]:", err);
            window.location.replace(directCheckoutUrl);
          });
          return;
        }
      } catch (e) {
        console.warn("[Cashfree Init Exception, redirecting directly]:", e);
        window.location.replace(directCheckoutUrl);
      }
    }

    function showError(msg) {
      document.getElementById('loader').style.display = 'none';
      document.getElementById('title').textContent = 'Opening Payment Gateway...';
      document.getElementById('subtitle').textContent = msg || 'If redirect does not start automatically, please tap Continue below.';
      const btn = document.getElementById('proceedBtn');
      btn.style.display = 'inline-block';
      btn.textContent = 'Continue to Cashfree';
    }

    function retryCheckout() {
      window.location.replace(directCheckoutUrl);
    }

    let checks = 0;
    function checkSdkReady() {
      if (typeof window.Cashfree === 'function') {
        initiateCheckout();
      } else if (checks < 20) {
        checks++;
        setTimeout(checkSdkReady, 100);
      } else {
        // Automatically direct-fallback to Cashfree hosted portal without blocking
        console.warn("[Cashfree JS SDK timeout, auto-redirecting to portal]");
        window.location.replace(directCheckoutUrl);
      }
    }

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      checkSdkReady();
    } else {
      window.addEventListener('DOMContentLoaded', checkSdkReady);
      window.addEventListener('load', checkSdkReady);
    }
  </script>
</body>
</html>`;

    res.setHeader("Content-Type", "text/html");
    res.status(200).send(html);
  }
);
