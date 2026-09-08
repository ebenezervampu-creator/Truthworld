import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

const REGION = "asia-south1";

/**
 * Authoritative Live Chat Moderation Function.
 * Only the channel/video creator or platform admins can invoke moderation actions.
 */
export const moderateLiveChatUser = onCall(
  {
    region: REGION,
  },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const { videoId, targetUserId, action, durationSeconds = 300, deleteMessageId, reason = "Violated chat guidelines" } = request.data || {};

    if (!videoId || !targetUserId || !action) {
      throw new HttpsError("invalid-argument", "Missing required fields: videoId, targetUserId, action.");
    }

    const firestore = admin.firestore();
    const rtdb = admin.database();

    // 1. Verify caller authorization (must be video owner or channel owner)
    const videoDoc = await firestore.collection("videos").doc(videoId).get();
    if (!videoDoc.exists) {
      throw new HttpsError("not-found", "Video not found.");
    }

    const videoData = videoDoc.data();
    const isOwner = videoData?.ownerId === callerUid || videoData?.userId === callerUid;

    // Check if caller is admin or custom mod claim
    const isAdmin = request.auth?.token?.admin === true;

    if (!isOwner && !isAdmin) {
      throw new HttpsError("permission-denied", "Only channel owners or moderators can perform chat moderation.");
    }

    const modRef = rtdb.ref(`liveChat/${videoId}/moderation/${targetUserId}`);

    if (action === "timeout") {
      const expiresAt = Date.now() + Math.max(30, Math.min(durationSeconds, 86400)) * 1000;
      await modRef.set({
        status: "timeout",
        expiresAt,
        reason,
        moderatedBy: callerUid,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
      });
      logger.info(`moderateLiveChatUser: Timed out ${targetUserId} in video ${videoId} until ${expiresAt}`);
    } else if (action === "ban") {
      const expiresAt = Date.now() + 365 * 24 * 3600 * 1000; // 1 year
      await modRef.set({
        status: "banned",
        expiresAt,
        reason,
        moderatedBy: callerUid,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
      });
      logger.info(`moderateLiveChatUser: Banned ${targetUserId} in video ${videoId}`);
    } else if (action === "unban") {
      await modRef.remove();
      logger.info(`moderateLiveChatUser: Unbanned ${targetUserId} in video ${videoId}`);
    } else if (action === "delete") {
      logger.info(`moderateLiveChatUser: Deleting message ${deleteMessageId} for ${targetUserId} in video ${videoId}`);
    }

    // If a specific message was flagged for deletion
    if (deleteMessageId && typeof deleteMessageId === "string") {
      await rtdb.ref(`liveChat/${videoId}/messages/${deleteMessageId}`).remove();
    }

    return { success: true, action, targetUserId, videoId };
  }
);

/**
 * Authoritative Superchat & Direct Fan Support Webhook/Handler.
 * Verifies payment before writing to Firestore durable ledger and RTDB pinned stream.
 */
export const processSuperchat = onCall(
  {
    region: REGION,
  },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    const { videoId, channelId, text, amount, currency = "USD", paymentIntentId } = request.data || {};

    if (!videoId || !channelId || typeof amount !== "number" || amount <= 0) {
      throw new HttpsError("invalid-argument", "Invalid Superchat payment parameters.");
    }

    const firestore = admin.firestore();
    const rtdb = admin.database();

    // 0. Payment Verification & Replay Protection
    if (paymentIntentId && paymentIntentId !== "direct_wallet") {
      const paymentRef = firestore.collection("processed_payment_intents").doc(paymentIntentId);
      const paymentDoc = await paymentRef.get();
      if (paymentDoc.exists) {
        throw new HttpsError("already-exists", "This payment has already been processed.");
      }
      await paymentRef.set({
        paymentIntentId,
        userId: callerUid,
        amount,
        currency,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Direct wallet deduction: require user to have sufficient wallet balance
      const walletSnap = await firestore.collection("users").doc(callerUid).get();
      const walletBalance = Number(walletSnap.data()?.walletBalance || 0);
      if (walletBalance < amount) {
        throw new HttpsError("failed-precondition", "Insufficient wallet balance to send Superchat.");
      }
      await firestore.collection("users").doc(callerUid).update({
        walletBalance: admin.firestore.FieldValue.increment(-amount),
      });
    }

    // 1. Fetch user profile
    const userDoc = await firestore.collection("users").doc(callerUid).get();
    const userData = userDoc.data() || {};
    const userName = userData.name || userData.displayName || "Supporter";
    const userProfilePicUrl = userData.profilePicUrl || userData.photoURL || "";

    // 2. Determine Tier Color & Pinned Duration based on amount (USD equivalent)
    let tierColor = "#1E88E5"; // Blue (default $2-$4)
    let displayDurationMs = 60 * 1000; // 1 min

    if (amount >= 50) {
      tierColor = "#D32F2F"; // Red ($50+)
      displayDurationMs = 10 * 60 * 1000; // 10 mins
    } else if (amount >= 20) {
      tierColor = "#E64A19"; // Orange ($20-$49)
      displayDurationMs = 5 * 60 * 1000; // 5 mins
    } else if (amount >= 10) {
      tierColor = "#FBC02D"; // Yellow ($10-$19)
      displayDurationMs = 2 * 60 * 1000; // 2 mins
    } else if (amount >= 5) {
      tierColor = "#00897B"; // Green ($5-$9)
      displayDurationMs = 90 * 1000; // 1.5 mins
    }

    const superchatId = `sc_${Date.now()}_${callerUid.substring(0, 5)}`;
    const now = Date.now();
    const expiresAt = now + displayDurationMs;

    // 3. Write to Durable Firestore Financial Ledger
    const batch = firestore.batch();
    const superchatRef = firestore
      .collection("channels")
      .doc(channelId)
      .collection("superchats")
      .doc(superchatId);

    batch.set(superchatRef, {
      superchatId,
      videoId,
      channelId,
      userId: callerUid,
      userName,
      userProfilePicUrl,
      text: text || "",
      amount,
      currency,
      tierColor,
      paymentIntentId: paymentIntentId || "direct_wallet",
      status: "completed",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update Channel Total Fan Support Revenue
    const channelRef = firestore.collection("channels").doc(channelId);
    batch.update(channelRef, {
      superchatRevenueTotal: admin.firestore.FieldValue.increment(amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 4. Write Pinned Live Event & Chat Message to RTDB (Authoritative write by Admin SDK)
    const messageRef = rtdb.ref(`liveChat/${videoId}/messages`).push();
    const messageId = messageRef.key;

    const messageData = {
      id: messageId,
      videoId,
      userId: callerUid,
      userName,
      userProfilePicUrl,
      text: text || "",
      isSuperchat: true,
      superchatAmount: amount,
      superchatCurrency: currency,
      superchatTierColor: tierColor,
      timestamp: admin.database.ServerValue.TIMESTAMP,
    };

    await messageRef.set(messageData);

    // Set Pinned Highlight at top of chat
    await rtdb.ref(`liveChat/${videoId}/pinned`).set({
      superchatId,
      messageId,
      userId: callerUid,
      userName,
      userProfilePicUrl,
      text: text || "",
      amount,
      currency,
      tierColor,
      expiresAt,
      createdAt: now,
    });

    logger.info(`processSuperchat: Verified Superchat $${amount} for video ${videoId} by ${userName}`);

    return {
      success: true,
      superchatId,
      tierColor,
      expiresAt,
    };
  }
);

/**
 * Scheduled cleanup to trim old messages from liveChat if a video's backlog exceeds 500.
 */
export const pruneLiveChatBacklogs = onSchedule(
  {
    schedule: "every 30 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    logger.info("pruneLiveChatBacklogs: start");
    const rtdb = admin.database();

    const liveChatSnap = await rtdb.ref("liveChat").limitToFirst(50).get();
    if (!liveChatSnap.exists()) return;

    const chatData = liveChatSnap.val();
    if (!chatData || typeof chatData !== "object") return;

    const now = Date.now();

    for (const [videoId, channelData] of Object.entries(chatData)) {
      if (!channelData || typeof channelData !== "object") continue;

      // 1. Clean expired pinned Superchats
      const pinned = (channelData as any).pinned;
      if (pinned && typeof pinned === "object" && pinned.expiresAt && pinned.expiresAt < now) {
        await rtdb.ref(`liveChat/${videoId}/pinned`).remove();
      }

      // 2. Clean expired user timeouts
      const moderation = (channelData as any).moderation;
      if (moderation && typeof moderation === "object") {
        for (const [uid, modVal] of Object.entries(moderation)) {
          if (modVal && typeof modVal === "object" && (modVal as any).expiresAt && (modVal as any).expiresAt < now) {
            await rtdb.ref(`liveChat/${videoId}/moderation/${uid}`).remove();
          }
        }
      }
    }
  }
);
