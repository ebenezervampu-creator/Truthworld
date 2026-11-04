import * as admin from "firebase-admin";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { requireAuth } from "../utils/auth";
import { applySecurityHeaders } from "../utils/securityHeaders";

const db = () => admin.firestore();

/**
 * 🤝 FOLLOW CHANNEL (Callable)
 * Atomically links user to channel, sets default notificationOption to 'personalized', and updates counts.
 */
export const followChannel = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId, notificationOption: rawOption, notificationPreference } = request.data || {};
    if (!channelId) throw new HttpsError("invalid-argument", "Missing channelId.");

    // Default to 'personalized' notification setting on subscribe first
    const inputOption = (rawOption || notificationPreference || "personalized").toLowerCase();
    const notificationOption = ["all", "personalized", "none"].includes(inputOption)
      ? inputOption
      : "personalized";
    const notificationsEnabled = notificationOption !== "none";

    // L-31: Prevent self-follow to block subscriber count inflation
    const channelSnap = await db().collection("channels").doc(channelId).get();
    if (!channelSnap.exists) throw new HttpsError("not-found", "Channel not found.");
    if (channelSnap.data()?.ownerId === userId) {
      throw new HttpsError("invalid-argument", "You cannot follow your own channel.");
    }

    const subscriberRef = db().collection("channel_subscribers").doc(`${channelId}_${userId}`);
    const legacySubRef = db().collection("subscriptions").doc(`${channelId}_${userId}`);
    const channelSubRef = db().collection("channels").doc(channelId).collection("channelSubscribers").doc(userId);
    const standardChannelSubRef = db().collection("channels").doc(channelId).collection("subscribers").doc(userId);
    const userSubRef = db().collection("users").doc(userId).collection("userSubscriptions").doc(channelId);
    const standardUserSubRef = db().collection("users").doc(userId).collection("subscriptions").doc(channelId);
    const channelRef = db().collection("channels").doc(channelId);
    const userRef = db().collection("users").doc(userId);

    try {
      return await db().runTransaction(async (tx) => {
        const followSnap = await tx.get(subscriberRef);
        if (followSnap.exists) {
          return {
            success: true,
            alreadyFollowing: true,
            channelId,
            notificationOption: followSnap.data()?.notificationOption || "personalized",
          };
        }

        const chSnap = await tx.get(channelRef);
        if (!chSnap.exists) throw new HttpsError("not-found", "Channel not found.");

        const now = Date.now();
        const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

        const subPayload = {
          channelId,
          userId,
          createdAt: now,
          subscribedAt: serverTimestamp,
          notificationsEnabled,
          notificationOption,
          notificationPreference: notificationOption,
        };

        tx.set(subscriberRef, subPayload);
        tx.set(legacySubRef, subPayload);
        tx.set(channelSubRef, subPayload);
        tx.set(standardChannelSubRef, subPayload);
        tx.set(userSubRef, subPayload);
        tx.set(standardUserSubRef, subPayload);

        tx.update(channelRef, {
          "stats.subscribersCount": admin.firestore.FieldValue.increment(1),
          subscriberCount: admin.firestore.FieldValue.increment(1),
        });

        tx.update(userRef, {
          following: admin.firestore.FieldValue.arrayUnion(channelId),
          updatedAt: now,
        });

        return {
          success: true,
          channelId,
          notificationOption,
          notificationPreference: notificationOption,
          notificationsEnabled,
        };
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[followChannel] Error:", err);
      throw new HttpsError("internal", "Failed to follow channel.");
    }
  }
);

/**
 * 👋 UNFOLLOW CHANNEL (Callable)
 */
export const unfollowChannel = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId } = request.data || {};
    if (!channelId) throw new HttpsError("invalid-argument", "Missing channelId.");

    const subscriberRef = db().collection("channel_subscribers").doc(`${channelId}_${userId}`);
    const legacySubRef = db().collection("subscriptions").doc(`${channelId}_${userId}`);
    const channelSubRef = db().collection("channels").doc(channelId).collection("channelSubscribers").doc(userId);
    const standardChannelSubRef = db().collection("channels").doc(channelId).collection("subscribers").doc(userId);
    const userSubRef = db().collection("users").doc(userId).collection("userSubscriptions").doc(channelId);
    const standardUserSubRef = db().collection("users").doc(userId).collection("subscriptions").doc(channelId);
    const channelRef = db().collection("channels").doc(channelId);
    const userRef = db().collection("users").doc(userId);

    try {
      return await db().runTransaction(async (tx) => {
        const followSnap = await tx.get(subscriberRef);
        const legacySnap = await tx.get(legacySubRef);
        if (!followSnap.exists && !legacySnap.exists) {
          return { success: true, notFollowing: true };
        }

        tx.delete(subscriberRef);
        tx.delete(legacySubRef);
        tx.delete(channelSubRef);
        tx.delete(standardChannelSubRef);
        tx.delete(userSubRef);
        tx.delete(standardUserSubRef);

        tx.update(channelRef, {
          "stats.subscribersCount": admin.firestore.FieldValue.increment(-1),
          subscriberCount: admin.firestore.FieldValue.increment(-1),
        });

        tx.update(userRef, {
          following: admin.firestore.FieldValue.arrayRemove(channelId),
          updatedAt: Date.now(),
        });

        return { success: true };
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[unfollowChannel] Error:", err);
      throw new HttpsError("internal", "Failed to unfollow channel.");
    }
  }
);

/**
 * 🔔 UPDATE CHANNEL NOTIFICATION SETTINGS (Callable)
 * Updates user's notification preference ('all' | 'personalized' | 'none') for a channel subscription.
 */
export const updateChannelNotificationSettings = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 5 },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId, notificationOption: rawOption, notificationPreference } = request.data || {};
    const option = (rawOption || notificationPreference || "").toLowerCase();

    if (!channelId || !["all", "personalized", "none"].includes(option)) {
      throw new HttpsError("invalid-argument", "Valid channelId and notificationOption ('all' | 'personalized' | 'none') required.");
    }

    const notificationsEnabled = option !== "none";
    const now = Date.now();
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

    const updates = {
      notificationsEnabled,
      notificationOption: option,
      notificationPreference: option,
      updatedAt: now,
      lastNotificationOptionChangedAt: serverTimestamp,
    };

    const subscriberRef = db().collection("channel_subscribers").doc(`${channelId}_${userId}`);
    const legacySubRef = db().collection("subscriptions").doc(`${channelId}_${userId}`);
    const channelSubRef = db().collection("channels").doc(channelId).collection("channelSubscribers").doc(userId);
    const standardChannelSubRef = db().collection("channels").doc(channelId).collection("subscribers").doc(userId);
    const userSubRef = db().collection("users").doc(userId).collection("userSubscriptions").doc(channelId);
    const standardUserSubRef = db().collection("users").doc(userId).collection("subscriptions").doc(channelId);

    try {
      const batch = db().batch();
      batch.set(subscriberRef, updates, { merge: true });
      batch.set(legacySubRef, updates, { merge: true });
      batch.set(channelSubRef, updates, { merge: true });
      batch.set(standardChannelSubRef, updates, { merge: true });
      batch.set(userSubRef, updates, { merge: true });
      batch.set(standardUserSubRef, updates, { merge: true });

      await batch.commit();

      return {
        success: true,
        channelId,
        notificationOption: option,
        notificationPreference: option,
        notificationsEnabled,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[updateChannelNotificationSettings] Error:", err);
      throw new HttpsError("internal", "Failed to update channel notification settings.");
    }
  }
);

/**
 * 📰 GET FOLLOWING FEED (HTTPS)
 * Fetches latest content from channels the user follows.
 */
export const getFollowingFeed = onRequest(
  { region: "asia-south1", cors: true, memory: "512MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    // L-32: Authenticate the caller instead of trusting client-supplied userId
    const authUser = await requireAuth(req, res);
    if (!authUser) return;
    const userId = authUser.uid;

    try {
      // 1. Get followed channel IDs
      const userSnap = await db().collection("users").doc(userId).get();
      const following = (userSnap.data()?.following || []) as string[];

      if (following.length === 0) {
        res.status(200).json({ videos: [], message: "You are not following anyone yet." });
        return;
      }

      // 2. Fetch latest videos from these channels
      // Note: Firestore 'in' query limited to 10 IDs. For larger sets, 
      // we'd need a different feed strategy (precomputed or parallel queries).
      const videoSnap = await db().collection("videos")
        .where("channelId", "in", following.slice(0, 10))
        .orderBy("createdAt", "desc")
        .limit(20)
        .get();

      const videos = videoSnap.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.status(200).json({ videos });
    } catch (err) {
      logger.error("[getFollowingFeed] Error:", err);
      res.status(500).json({ error: "Unable to load following feed. Please try again." });
    }
  }
);
