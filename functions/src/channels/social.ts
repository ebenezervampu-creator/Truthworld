import * as admin from "firebase-admin";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = () => admin.firestore();

/**
 * 🤝 SUBSCRIBE CHANNEL (Callable)
 * Atomically links user to channel, updates counts.
 */
export const subscribeChannel = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId } = request.data;
    if (!channelId) throw new HttpsError("invalid-argument", "Missing channelId.");

    const subscriberRef = db().collection("channel_subscribers").doc(`${channelId}_${userId}`);
    const channelRef = db().collection("channels").doc(channelId);
    const userRef = db().collection("users").doc(userId);

    try {
      return await db().runTransaction(async (tx) => {
        const followSnap = await tx.get(subscriberRef);
        if (followSnap.exists) return { success: true, alreadySubscribed: true };

        const channelSnap = await tx.get(channelRef);
        if (!channelSnap.exists) throw new HttpsError("not-found", "Channel not found.");

        tx.set(subscriberRef, {
          channelId,
          userId,
          createdAt: Date.now()
        });

        tx.update(channelRef, {
          "stats.subscribersCount": admin.firestore.FieldValue.increment(1)
        });

        tx.update(userRef, {
          subscriptions: admin.firestore.FieldValue.arrayUnion(channelId),
          updatedAt: Date.now()
        });

        return { success: true };
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[subscribeChannel] Error:", err);
      throw new HttpsError("internal", "Failed to subscribe to channel.");
    }
  }
);

/**
 * 👋 UNSUBSCRIBE CHANNEL (Callable)
 */
export const unsubscribeChannel = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId } = request.data;
    if (!channelId) throw new HttpsError("invalid-argument", "Missing channelId.");

    const subscriberRef = db().collection("channel_subscribers").doc(`${channelId}_${userId}`);
    const channelRef = db().collection("channels").doc(channelId);
    const userRef = db().collection("users").doc(userId);

    try {
      return await db().runTransaction(async (tx) => {
        const followSnap = await tx.get(subscriberRef);
        if (!followSnap.exists) return { success: true, notSubscribed: true };

        tx.delete(subscriberRef);

        tx.update(channelRef, {
          "stats.subscribersCount": admin.firestore.FieldValue.increment(-1)
        });

        tx.update(userRef, {
          subscriptions: admin.firestore.FieldValue.arrayRemove(channelId),
          updatedAt: Date.now()
        });

        return { success: true };
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[unsubscribeChannel] Error:", err);
      throw new HttpsError("internal", "Failed to unsubscribe from channel.");
    }
  }
);

/**
 * 📰 GET SUBSCRIPTIONS FEED (HTTPS)
 * Fetches latest content from channels the user is subscribed to.
 */
export const getSubscriptionsFeed = onRequest(
  { region: "asia-south1", cors: true, memory: "512MiB" },
  async (req, res) => {
    const userId = req.query.userId as string; // Ideally from session
    if (!userId) {
      res.status(400).json({ error: "Missing userId" });
      return;
    }

    try {
      // 1. Get subscribed channel IDs
      const userSnap = await db().collection("users").doc(userId).get();
      const subscriptions = (userSnap.data()?.subscriptions || []) as string[];

      if (subscriptions.length === 0) {
        res.status(200).json({ videos: [], message: "You are not subscribed to anyone yet." });
        return;
      }

      // 2. Fetch latest videos from these channels
      // Note: Firestore 'in' query limited to 10 IDs. For larger sets, 
      // we'd need a different feed strategy (precomputed or parallel queries).
      const videoSnap = await db().collection("videos")
        .where("channelId", "in", subscriptions.slice(0, 10))
        .orderBy("createdAt", "desc")
        .limit(20)
        .get();

      const videos = videoSnap.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.status(200).json({ videos });
    } catch (err) {
      logger.error("[getSubscriptionsFeed] Error:", err);
      res.status(500).json({ error: "Internal error" });
    }
  }
);
