import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { UserNotification, NotificationType, NotificationSeverity } from "./types";

const db = admin.firestore();
const COL_NOTIFICATIONS = "user_notifications";

/**
 * 📣 NOTIFY USER
 * Internal utility to send a notification.
 */
export async function notifyUser(params: {
  userId: string;
  type: NotificationType;
  severity: NotificationSeverity;
  title: string;
  message: string;
  actionUrl?: string;
  metadata?: Record<string, any>;
}) {
  if (!params.userId || typeof params.userId !== "string" || !params.userId.trim()) {
    logger.warn("[notifyUser] Skipped notification with missing or invalid userId", { title: params.title });
    return null;
  }

  try {
    const notificationId = db.collection(COL_NOTIFICATIONS).doc().id;
    const notification: UserNotification = {
      id: notificationId,
      userId: params.userId,
      type: params.type,
      severity: params.severity,
      title: params.title,
      message: params.message,
      actionUrl: params.actionUrl,
      metadata: params.metadata,
      read: false,
      createdAt: Date.now(),
      pushSent: true,
    };

    await db.collection(COL_NOTIFICATIONS).doc(notificationId).set(notification);
    
    // Fire-and-forget: Push notification delivery is non-blocking.
    // The Firestore write above is the critical path; FCM delivery can
    // happen asynchronously without delaying the caller. This is critical
    // during fan-out where hundreds of notifyUser() calls run in parallel.
    sendPushNotificationForUser(params, notificationId).catch(pushErr => {
      logger.warn("[notifyUser] FCM push failed (non-critical):", { userId: params.userId, err: String(pushErr) });
    });
    
    return notificationId;
  } catch (err) {
    logger.error("[notifyUser] Error:", err);
    return null;
  }
}

/**
 * 🔔 INTERNAL / EXPORTED: Send FCM push notification to user's registered devices.
 * Separated from notifyUser to enable fire-and-forget pattern.
 */
export async function sendPushNotificationForUser(
  params: {
    userId: string;
    type: string;
    severity: string;
    title: string;
    message: string;
    actionUrl?: string;
    metadata?: Record<string, any>;
  },
  notificationId: string
): Promise<void> {
  const userDoc = await db.collection("users").doc(params.userId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const fcmTokensMap = userData?.fcmTokens as Record<string, any> | undefined;
  if (!fcmTokensMap) return;

  // Extract and deduplicate tokens safely (plain string or object format)
  // Maps unique token string -> primary deviceId to prevent duplicate push deliveries
  const tokenToDeviceMap = new Map<string, string>();
  const duplicateDeviceIdsToRemove: string[] = [];

  for (const [deviceId, val] of Object.entries(fcmTokensMap)) {
    let tokenStr = "";
    if (typeof val === "string") {
      tokenStr = val.trim();
    } else if (val && typeof val === "object" && typeof val.token === "string") {
      tokenStr = val.token.trim();
    }
    if (tokenStr.length > 0) {
      if (tokenToDeviceMap.has(tokenStr)) {
        // Redundant entry holding the identical token - mark for background cleanup
        duplicateDeviceIdsToRemove.push(deviceId);
      } else {
        tokenToDeviceMap.set(tokenStr, deviceId);
      }
    }
  }

  // Asynchronously prune redundant duplicate token device keys from Firestore
  if (duplicateDeviceIdsToRemove.length > 0) {
    const pruneUpdates: Record<string, any> = {};
    for (const dId of duplicateDeviceIdsToRemove) {
      pruneUpdates[`fcmTokens.${dId}`] = admin.firestore.FieldValue.delete();
    }
    db.collection("users").doc(params.userId).update(pruneUpdates).catch(err => {
      logger.warn("[FCM] Failed to prune redundant duplicate token keys:", { userId: params.userId, err: String(err) });
    });
  }

  const tokens = Array.from(tokenToDeviceMap.keys());
  if (tokens.length === 0) return;

  const dataPayload: Record<string, string> = {
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    actionUrl: params.actionUrl || "",
    type: String(params.type),
    severity: String(params.severity),
    notificationId: String(notificationId),
  };

  // Forward metadata fields (e.g. videoId, commentId, replyId, channelId)
  if (params.metadata && typeof params.metadata === "object") {
    for (const [key, val] of Object.entries(params.metadata)) {
      if (val !== undefined && val !== null) {
        dataPayload[key] = typeof val === "object" ? JSON.stringify(val) : String(val);
      }
    }
  }

  const fallbackIconUrl = "https://www.truthworld.in/icons/Icon-512.png";
  const notificationImageUrl = (params.metadata?.thumbnailUrl ||
    params.metadata?.imageUrl ||
    params.metadata?.userAvatar ||
    params.metadata?.avatarUrl ||
    fallbackIconUrl) as string;

  const payload = {
    tokens,
    notification: {
      title: params.title,
      body: params.message,
      imageUrl: notificationImageUrl,
    },
    data: dataPayload,
    android: {
      priority: "high" as const,
      collapseKey: String(notificationId),
      notification: {
        sound: "default",
        channelId: "truthworld_notifications",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
        priority: "max" as const, // MAX system priority for heads-up alert
        notificationPriority: "PRIORITY_MAX" as const,
        visibility: "public" as const,
        tag: String(notificationId), // OS-level collapse/deduplication tag
        icon: "ic_notification",
        color: "#14EAB2",
        imageUrl: notificationImageUrl,
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
        "apns-collapse-id": String(notificationId),
      },
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "mutable-content": 1, // iOS notification service extension trigger
        },
      },
      fcmOptions: {
        imageUrl: notificationImageUrl,
      },
    },
    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        icon: "https://www.truthworld.in/icons/Icon-192.png",
        badge: "https://www.truthworld.in/icons/Icon-192.png",
        image: notificationImageUrl,
      },
      fcmOptions: {
        link: params.actionUrl || "https://www.truthworld.in",
      },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(payload);
  logger.info(`[FCM] Sent to ${tokens.length} devices for user ${params.userId}. OK: ${response.successCount}, Fail: ${response.failureCount}`);

  // Cleanup invalid or unregistered FCM tokens
  if (response.failureCount > 0) {
    const tokensToRemove: Record<string, any> = {};
    response.responses.forEach((res, index) => {
      if (!res.success && res.error) {
        const errCode = res.error.code;
        if (
          errCode === "messaging/invalid-registration-token" ||
          errCode === "messaging/registration-token-not-registered"
        ) {
          const failedToken = tokens[index];
          const deviceId = failedToken ? tokenToDeviceMap.get(failedToken) : undefined;
          if (deviceId) {
            tokensToRemove[`fcmTokens.${deviceId}`] = admin.firestore.FieldValue.delete();
          }
        }
      }
    });

    if (Object.keys(tokensToRemove).length > 0) {
      await db.collection("users").doc(params.userId).update(tokensToRemove).catch(err => {
        logger.warn("[FCM] Failed to cleanup stale tokens:", { userId: params.userId, err: String(err) });
      });
    }
  }
}

/**
 * 📥 GET NOTIFICATIONS (Callable)
 * Retrieves latest notifications for the logged-in user.
 */
export const getNotifications = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 2 },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const limit = Math.min(Number(request.data?.limit) || 20, 50);

    try {
      const snap = await db.collection(COL_NOTIFICATIONS)
        .where("userId", "==", userId)
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get();

      const notifications = snap.docs.map(doc => doc.data() as UserNotification);
      return { notifications };
    } catch (err) {
      logger.error("[getNotifications] Error:", err);
      throw new HttpsError("internal", "Failed to fetch notifications.");
    }
  }
);

/**
 * ✅ MARK NOTIFICATION AS READ (Callable)
 */
export const markNotificationRead = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 2 },
  async (request) => {
    const userId = request.auth?.uid;
    const { notificationId } = request.data;
    if (!userId || !notificationId) throw new HttpsError("invalid-argument", "Missing data.");

    try {
      const ref = db.collection(COL_NOTIFICATIONS).doc(notificationId);
      const snap = await ref.get();
      
      if (!snap.exists) throw new HttpsError("not-found", "Notification not found.");
      if (snap.data()?.userId !== userId) throw new HttpsError("permission-denied", "Unauthorized.");

      await ref.update({ read: true });
      return { success: true };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[markNotificationRead] Error:", err);
      throw new HttpsError("internal", "Update failed.");
    }
  }
);

/**
 * 🔔 UPDATE TOPIC NOTIFICATION SETTINGS (Callable)
 * Updates user's notification preference ('all' | 'personalized' | 'none' | 'unfollow') for a topic.
 * When setting is 'unfollow', the topic is removed from savedTopics and topic followerCount is decremented.
 */
export const updateTopicNotificationSettings = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 2 },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { topicId, notificationSetting } = request.data || {};
    if (!topicId || typeof topicId !== "string" || !topicId.trim()) {
      throw new HttpsError("invalid-argument", "Missing or invalid topicId.");
    }
    if (!notificationSetting || typeof notificationSetting !== "string") {
      throw new HttpsError("invalid-argument", "Missing or invalid notificationSetting.");
    }

    const cleanTopicId = topicId.trim();
    const cleanSetting = notificationSetting.trim().toLowerCase();

    if (!["all", "personalized", "none", "unfollow"].includes(cleanSetting)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid notificationSetting value. Must be 'all', 'personalized', 'none', or 'unfollow'."
      );
    }

    try {
      const topicSavedRef = db.collection("users").doc(userId).collection("savedTopics").doc(cleanTopicId);
      const topicRef = db.collection("topics").doc(cleanTopicId);

      if (cleanSetting === "unfollow") {
        const [savedSnap, topicSnap] = await Promise.all([
          topicSavedRef.get(),
          topicRef.get(),
        ]);

        const batch = db.batch();
        batch.delete(topicSavedRef);

        if (savedSnap.exists && topicSnap.exists) {
          const currentCount = topicSnap.data()?.followerCount ?? 0;
          batch.set(
            topicRef,
            { followerCount: Math.max(0, currentCount - 1) },
            { merge: true }
          );
        }

        await batch.commit();

        return {
          success: true,
          topicId: cleanTopicId,
          unfollowed: true,
          notificationSetting: "none",
        };
      }

      // 'all' | 'personalized' | 'none'
      await topicSavedRef.set({
        topicId: cleanTopicId,
        notificationSetting: cleanSetting,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return {
        success: true,
        topicId: cleanTopicId,
        unfollowed: false,
        notificationSetting: cleanSetting,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[updateTopicNotificationSettings] Error:", err);
      throw new HttpsError("internal", "Failed to update notification settings.");
    }
  }
);

/**
 * ➕ FOLLOW TOPIC (Callable)
 * Follows a topic for the user with an initial notification preference ('all' | 'personalized' | 'none', default 'all').
 * Atomically increments topic followerCount.
 */
export const followTopic = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 2 },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { topicId, notificationSetting } = request.data || {};
    if (!topicId || typeof topicId !== "string" || !topicId.trim()) {
      throw new HttpsError("invalid-argument", "Missing or invalid topicId.");
    }

    const cleanTopicId = topicId.trim();
    const cleanSetting = (notificationSetting && typeof notificationSetting === "string")
      ? notificationSetting.trim().toLowerCase()
      : "personalized";

    if (!["all", "personalized", "none"].includes(cleanSetting)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid notificationSetting value. Must be 'all', 'personalized', or 'none'."
      );
    }

    try {
      const topicRef = db.collection("topics").doc(cleanTopicId);
      const [topicSnap, existingSaved] = await Promise.all([
        topicRef.get(),
        db.collection("users").doc(userId).collection("savedTopics").doc(cleanTopicId).get(),
      ]);

      if (!topicSnap.exists) {
        throw new HttpsError("not-found", "Topic does not exist.");
      }

      const topicSavedRef = db.collection("users").doc(userId).collection("savedTopics").doc(cleanTopicId);
      const batch = db.batch();

      batch.set(
        topicSavedRef,
        {
          topicId: cleanTopicId,
          savedAt: existingSaved.exists
            ? (existingSaved.data()?.savedAt || admin.firestore.FieldValue.serverTimestamp())
            : admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          notificationSetting: cleanSetting,
        },
        { merge: true }
      );

      if (!existingSaved.exists) {
        const currentCount = topicSnap.data()?.followerCount ?? 0;
        batch.set(
          topicRef,
          { followerCount: currentCount + 1 },
          { merge: true }
        );
      }

      await batch.commit();

      return {
        success: true,
        topicId: cleanTopicId,
        isFollowing: true,
        notificationSetting: cleanSetting,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[followTopic] Error:", err);
      throw new HttpsError("internal", "Failed to follow topic.");
    }
  }
);

/**
 * ➖ UNFOLLOW TOPIC (Callable)
 * Unfollows a topic, removes savedTopics doc, and decrements topic followerCount.
 */
export const unfollowTopic = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 2 },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { topicId } = request.data || {};
    if (!topicId || typeof topicId !== "string" || !topicId.trim()) {
      throw new HttpsError("invalid-argument", "Missing or invalid topicId.");
    }

    const cleanTopicId = topicId.trim();

    try {
      const topicSavedRef = db.collection("users").doc(userId).collection("savedTopics").doc(cleanTopicId);
      const topicRef = db.collection("topics").doc(cleanTopicId);

      const [existingSaved, topicSnap] = await Promise.all([
        topicSavedRef.get(),
        topicRef.get(),
      ]);

      if (!existingSaved.exists) {
        return {
          success: true,
          topicId: cleanTopicId,
          unfollowed: true,
          message: "Topic was not followed.",
        };
      }

      const batch = db.batch();
      batch.delete(topicSavedRef);

      if (topicSnap.exists) {
        const currentCount = topicSnap.data()?.followerCount ?? 0;
        batch.set(
          topicRef,
          { followerCount: Math.max(0, currentCount - 1) },
          { merge: true }
        );
      }

      await batch.commit();

      return {
        success: true,
        topicId: cleanTopicId,
        unfollowed: true,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[unfollowTopic] Error:", err);
      throw new HttpsError("internal", "Failed to unfollow topic.");
    }
  }
);

/**
 * 🔍 GET TOPIC NOTIFICATION SETTING (Callable)
 * Retrieves user's notification preference ('all' | 'personalized' | 'none') for a specific topic.
 */
export const getTopicNotificationSetting = onCall(
  { region: "asia-south1", memory: "256MiB", maxInstances: 2 },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { topicId } = request.data || {};
    if (!topicId || typeof topicId !== "string" || !topicId.trim()) {
      throw new HttpsError("invalid-argument", "Missing or invalid topicId.");
    }

    const cleanTopicId = topicId.trim();

    try {
      const doc = await db.collection("users").doc(userId).collection("savedTopics").doc(cleanTopicId).get();
      if (!doc.exists) {
        return {
          success: true,
          topicId: cleanTopicId,
          isFollowing: false,
          notificationSetting: "none",
        };
      }

      const setting = doc.data()?.notificationSetting || "personalized";
      return {
        success: true,
        topicId: cleanTopicId,
        isFollowing: true,
        notificationSetting: setting,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[getTopicNotificationSetting] Error:", err);
      throw new HttpsError("internal", "Failed to get topic notification setting.");
    }
  }
);


export { updateChannelNotificationSettings } from "../channels/social";

