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
    };

    await db.collection(COL_NOTIFICATIONS).doc(notificationId).set(notification);
    
    // Fire-and-forget: Push notification delivery is non-blocking.
    // The Firestore write above is the critical path; FCM delivery can
    // happen asynchronously without delaying the caller. This is critical
    // during fan-out where hundreds of notifyUser() calls run in parallel.
    _sendPushNotification(params, notificationId).catch(pushErr => {
      logger.warn("[notifyUser] FCM push failed (non-critical):", { userId: params.userId, err: String(pushErr) });
    });
    
    return notificationId;
  } catch (err) {
    logger.error("[notifyUser] Error:", err);
    return null;
  }
}

/**
 * 🔔 INTERNAL: Send FCM push notification to user's registered devices.
 * Separated from notifyUser to enable fire-and-forget pattern.
 */
async function _sendPushNotification(
  params: { userId: string; type: string; severity: string; title: string; message: string; actionUrl?: string },
  notificationId: string
): Promise<void> {
  const userDoc = await db.collection("users").doc(params.userId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const fcmTokensMap = userData?.fcmTokens as Record<string, string> | undefined;
  if (!fcmTokensMap) return;

  const tokens = Object.values(fcmTokensMap).filter(t => typeof t === "string" && t.length > 0);
  if (tokens.length === 0) return;

  const payload = {
    tokens,
    notification: {
      title: params.title,
      body: params.message,
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      actionUrl: params.actionUrl || "",
      type: String(params.type),
      severity: String(params.severity),
      notificationId: String(notificationId),
    },
    android: {
      priority: "high" as const,
      ttl: 0, // 0s TTL requests immediate delivery or discard (low latency)
      notification: {
        sound: "default",
        channelId: "truthworld_notifications",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
        priority: "max" as const, // MAX system priority for heads-up alert
        notificationPriority: "PRIORITY_MAX" as const,
        visibility: "public" as const,
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
      },
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "mutable-content": 1, // iOS notification service extension trigger
        },
      },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(payload);
  logger.info(`[FCM] Sent to ${tokens.length} devices for user ${params.userId}. OK: ${response.successCount}, Fail: ${response.failureCount}`);
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
