import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { UserNotification, NotificationType, NotificationSeverity } from "./types";

const db = admin.firestore();
const COL_NOTIFICATIONS = "user_notifications";

export type AppFlavorTarget = "app" | "studio" | "admin" | "advertiser" | "all";

/**
 * 🧭 RESOLVE TARGET APP
 * Determines with strict accuracy which of the 4 Truthworld applications
 * ('app' | 'studio' | 'admin' | 'advertiser') a notification is meant for.
 */
export function resolveTargetApp(params: {
  type: string;
  category?: string;
  actionUrl?: string;
  metadata?: Record<string, any>;
  targetApp?: AppFlavorTarget;
  title?: string;
  message?: string;
}): AppFlavorTarget {
  // 1. Explicit targetApp parameter or metadata override
  if (params.targetApp && ["app", "studio", "admin", "advertiser", "all"].includes(params.targetApp)) {
    return params.targetApp;
  }
  if (params.metadata?.targetApp && ["app", "studio", "admin", "advertiser", "all"].includes(params.metadata.targetApp)) {
    return params.metadata.targetApp as AppFlavorTarget;
  }
  if (params.metadata?.app && ["app", "studio", "admin", "advertiser", "all"].includes(params.metadata.app)) {
    return params.metadata.app as AppFlavorTarget;
  }

  const actionUrl = (params.actionUrl || "").trim().toLowerCase();
  // 2. Action URL matching
  if (actionUrl.startsWith("/studio") || actionUrl.includes("studio")) {
    return "studio";
  }
  if (actionUrl.startsWith("/admin") || actionUrl.includes("admin")) {
    return "admin";
  }
  if (actionUrl.startsWith("/advertiser") || actionUrl.startsWith("/ads") || actionUrl.includes("advertiser")) {
    return "advertiser";
  }

  const type = (params.type || "").trim().toLowerCase();
  const category = (params.category || (params.metadata?.category as string) || "").trim().toLowerCase();

  // 3. Studio-specific event types and categories
  const studioTypes = [
    "fact_check_pending",
    "fact_check_ready",
    "fact_check_completed",
    "verification_result",
    "batch_verification_result",
    "copyright_claim",
    "claim_dispute",
    "creator_coach_insight",
    "creator_motivation",
    "coach_growth_tip",
    "coach_growth_tip_v1",
    "analytics_alert",
    "monetization",
    "monetization_revenue",
    "monetization_payout",
    "membership_milestone",
    "sub_milestone",
    "subscribers_milestone",
    "subscribers_milestone_v1",
    "new_subscriber",
    "subscriber",
    "subscription",
    "view_milestone",
    "performance_insight",
    "retention_spike",
    "ranking_change",
    "trust_score_change",
    "tier_promotion",
    "tier_downgrade",
    "inactivity_warning",
    "performance_warning",
    "milestone_achieved",
    "new_follower", // In Studio: creator getting subscriber alert
    "weekly_digest",
    "channel_notifications",
    "studio_notifications",
  ];

  const title = (params.title || (params.metadata?.title as string) || "").trim().toLowerCase();
  const message = (params.message || (params.metadata?.message as string) || "").trim().toLowerCase();

  const isStudioContent =
    title.includes("truth verification") ||
    title.includes("fact-checking") ||
    title.includes("fact check") ||
    title.includes("video moderation") ||
    title.includes("thumbnail verification") ||
    title.includes("video not accepted") ||
    title.includes("video under manual review") ||
    title.includes("video processing") ||
    title.includes("video approved & published") ||
    title.includes("new subscriber") ||
    title.includes("creator studio") ||
    title.includes("channel policy") ||
    title.includes("copyright claim") ||
    title.includes("claim dispute") ||
    message.includes("studio notifications") ||
    message.includes("creator studio") ||
    message.includes("fact-checking for") ||
    message.includes("held in studio") ||
    message.includes("subscribed to your channel");

  if (
    studioTypes.includes(type) ||
    type.includes("studio") ||
    type.includes("fact_check") ||
    type.includes("verification") ||
    type.includes("milestone") ||
    type.includes("monetization") ||
    type.includes("coach") ||
    category === "verification" ||
    category === "monetization" ||
    category === "analytics" ||
    category === "growth" ||
    category === "education" ||
    isStudioContent
  ) {
    return "studio";
  }

  // 4. Admin-specific types
  if (type.startsWith("admin_") || category === "security" || category === "policy_enforcement") {
    return "admin";
  }

  // 5. Advertiser-specific types
  if (type.startsWith("campaign_") || category === "sponsorship" || type.includes("advertiser")) {
    return "advertiser";
  }

  // 6. Default to Consumer App ("app")
  return "app";
}

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
  targetApp?: AppFlavorTarget;
}) {
  if (!params.userId || typeof params.userId !== "string" || !params.userId.trim()) {
    logger.warn("[notifyUser] Skipped notification with missing or invalid userId", { title: params.title });
    return null;
  }

  try {
    const notificationId = db.collection(COL_NOTIFICATIONS).doc().id;
    const channelId = params.metadata?.channelId || "";
    const priority = params.metadata?.priority || (params.severity === "priority" ? "critical" : (params.severity === "warning" ? "high" : "low"));
    const category = params.metadata?.category || (params.type.includes("verification") || params.type.includes("fact_check") ? "verification" : "system");
    const thumbnailUrl = params.metadata?.thumbnailUrl || "";
    const targetApp = resolveTargetApp(params);

    const notification: any = {
      id: notificationId,
      userId: params.userId,
      ...(channelId ? { channelId } : {}),
      type: params.type,
      severity: params.severity,
      priority,
      category,
      targetApp,
      ...(thumbnailUrl ? { thumbnailUrl } : {}),
      title: params.title,
      message: params.message,
      actionUrl: params.actionUrl,
      metadata: {
        ...(params.metadata || {}),
        targetApp,
      },
      read: false,
      createdAt: Date.now(),
      pushSent: true,
    };

    const batch = db.batch();
    batch.set(db.collection(COL_NOTIFICATIONS).doc(notificationId), notification);
    batch.set(
      db.collection("users").doc(params.userId).collection("notifications_active").doc(notificationId),
      notification
    );
    await batch.commit();
    
    // Fire-and-forget: Push notification delivery is non-blocking.
    // The Firestore write above is the critical path; FCM delivery can
    // happen asynchronously without delaying the caller. This is critical
    // during fan-out where hundreds of notifyUser() calls run in parallel.
    sendPushNotificationForUser({ ...params, targetApp }, notificationId).catch(pushErr => {
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
    targetApp?: AppFlavorTarget;
  },
  notificationId: string
): Promise<void> {
  const userDoc = await db.collection("users").doc(params.userId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const fcmTokensMap = userData?.fcmTokens as Record<string, any> | undefined;
  if (!fcmTokensMap) return;

  const targetApp = resolveTargetApp(params);

  // Extract and deduplicate tokens safely (plain string or object format)
  // Maps unique token string -> primary deviceId to prevent duplicate push deliveries
  const tokenToDeviceMap = new Map<string, string>();
  const duplicateDeviceIdsToRemove: string[] = [];

  for (const [deviceId, val] of Object.entries(fcmTokensMap)) {
    let tokenStr = "";
    let tokenApp = "";

    if (typeof val === "string") {
      tokenStr = val.trim();
    } else if (val && typeof val === "object") {
      if (typeof val.token === "string") {
        tokenStr = val.token.trim();
      }
      if (typeof val.app === "string") {
        tokenApp = val.app.trim().toLowerCase();
      } else if (typeof val.appFlavor === "string") {
        tokenApp = val.appFlavor.trim().toLowerCase();
      }
    }

    if (!tokenApp) {
      if (deviceId.startsWith("studio_")) tokenApp = "studio";
      else if (deviceId.startsWith("admin_")) tokenApp = "admin";
      else if (deviceId.startsWith("advertiser_")) tokenApp = "advertiser";
      else if (deviceId.startsWith("app_")) tokenApp = "app";
    }

    if (tokenStr.length === 0) continue;

    // ── FLAVOR ISOLATION GATE ──
    // Strictly separate push notifications between all four Truthworld apps:
    // - Consumer App: 'app'
    // - Creator Studio: 'studio'
    // - Admin & Moderation: 'admin'
    // - Advertiser Portal: 'advertiser'
    if (targetApp !== "all") {
      if (tokenApp) {
        if (tokenApp !== targetApp) {
          logger.info(`[FCM] Filtered out device '${deviceId}' (app: '${tokenApp}') because targetApp is '${targetApp}'`);
          continue;
        }
      } else {
        // Untagged legacy tokens:
        // Studio, Admin, and Advertiser notifications MUST NOT be pushed to untagged tokens
        // to strictly prevent Studio notifications from bleeding into the Consumer app.
        if (targetApp !== "app") {
          logger.info(`[FCM] Suppressed untagged device '${deviceId}' for '${targetApp}' notification to prevent Consumer app leakage`);
          continue;
        }
      }
    }

    if (tokenToDeviceMap.has(tokenStr)) {
      // Redundant entry holding the identical token - mark for background cleanup
      duplicateDeviceIdsToRemove.push(deviceId);
    } else {
      tokenToDeviceMap.set(tokenStr, deviceId);
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
  if (tokens.length === 0) {
    logger.info(`[FCM] No registered devices matching targetApp '${targetApp}' for user ${params.userId}. Push skipped.`);
    return;
  }

  const dataPayload: Record<string, string> = {
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    actionUrl: params.actionUrl || "",
    type: String(params.type),
    severity: String(params.severity),
    notificationId: String(notificationId),
    targetApp: String(targetApp),
  };

  // Forward metadata fields (e.g. videoId, commentId, replyId, channelId)
  if (params.metadata && typeof params.metadata === "object") {
    for (const [key, val] of Object.entries(params.metadata)) {
      if (val !== undefined && val !== null) {
        dataPayload[key] = typeof val === "object" ? JSON.stringify(val) : String(val);
      }
    }
  }

  // Rich media image handling:
  // Only attach an image attachment URL if an authentic content thumbnail or avatar exists.
  // Never pass the app logo / icon URL as imageUrl, which forces Android OS into BigPictureStyle
  // displaying a large square photo card instead of the clean native system notification.
  const rawImageUrl = (
    params.metadata?.thumbnailUrl ||
    params.metadata?.imageUrl ||
    params.metadata?.userAvatar ||
    params.metadata?.avatarUrl ||
    ""
  );
  const mediaImageUrl = (
    typeof rawImageUrl === "string" &&
    rawImageUrl.trim().startsWith("http") &&
    !rawImageUrl.includes("Icon-512.png") &&
    !rawImageUrl.includes("Icon-192.png") &&
    !rawImageUrl.includes("app_logo") &&
    !rawImageUrl.includes("play_icon")
  ) ? rawImageUrl.trim() : undefined;

  const payload: admin.messaging.MulticastMessage = {
    tokens,
    notification: {
      title: params.title,
      body: params.message,
      ...(mediaImageUrl ? { imageUrl: mediaImageUrl } : {}),
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
        visibility: "public" as const,
        tag: String(notificationId), // OS-level collapse/deduplication tag
        icon: "ic_notification",
        color: "#14EAB2",
        ...(mediaImageUrl ? { imageUrl: mediaImageUrl } : {}),
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
      ...(mediaImageUrl ? { fcmOptions: { imageUrl: mediaImageUrl } } : {}),
    },
    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        icon: "https://www.truthworld.in/icons/Icon-192.png",
        badge: "https://www.truthworld.in/icons/Icon-192.png",
        ...(mediaImageUrl ? { image: mediaImageUrl } : {}),
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

