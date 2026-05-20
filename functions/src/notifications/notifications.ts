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
    
    // Trigger push notification via FCM if user has active tokens
    try {
      const tokensSnap = await db.collection("users").doc(params.userId).collection("fcm_tokens").get();
      const tokens = tokensSnap.docs
        .map(doc => doc.data().token || doc.id)
        .filter(t => typeof t === "string" && t.length > 0);

      if (tokens.length > 0) {
        const messagePayload = {
          tokens: tokens,
          notification: {
            title: params.title,
            body: params.message,
          },
          data: {
            actionUrl: params.actionUrl || "",
            type: params.type,
            severity: params.severity,
            ...(params.metadata ? { metadata: JSON.stringify(params.metadata) } : {}),
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
          android: {
            notification: {
              sound: "default",
            },
          },
        };

        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        logger.info(`[notifyUser FCM] Dispatched to ${tokens.length} tokens. Success: ${response.successCount}, Failure: ${response.failureCount}`);

        // Cleanup invalid/expired tokens to keep the database tidy
        if (response.failureCount > 0) {
          const batchCleanup = db.batch();
          let needsCleanup = false;
          response.responses.forEach((resp, idx) => {
            if (!resp.success && resp.error) {
              const code = resp.error.code;
              if (
                code === "messaging/invalid-registration-token" ||
                code === "messaging/registration-token-not-registered"
              ) {
                const badToken = tokens[idx];
                const tokenRef = db.collection("users").doc(params.userId).collection("fcm_tokens").doc(badToken);
                batchCleanup.delete(tokenRef);
                needsCleanup = true;
              }
            }
          });
          if (needsCleanup) {
            await batchCleanup.commit();
            logger.info(`[notifyUser FCM] Cleaned up failed registration tokens`);
          }
        }
      }
    } catch (fcmErr) {
      logger.error("[notifyUser FCM] Push delivery error:", fcmErr);
    }
    
    return notificationId;
  } catch (err) {
    logger.error("[notifyUser] Error:", err);
    return null;
  }
}

/**
 * 📥 GET NOTIFICATIONS (Callable)
 * Retrieves latest notifications for the logged-in user.
 */
export const getNotifications = onCall(
  { region: "asia-south1", memory: "256MiB" },
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
  { region: "asia-south1", memory: "256MiB" },
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
