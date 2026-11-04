/**
 * 📣 BROADCAST & DIRECT PUSH NOTIFICATION (Super Admin Exclusive)
 *
 * Supports two powerful dispatch modes:
 *  1. 'broadcast' (Default): Dispatches high-impact, Zomato-style engaging push notifications
 *     to every installed device across Android and iOS via global FCM topics.
 *  2. 'direct_user' (1-to-1): Dispatches a direct, high-priority notification to a specific
 *     user (by UID, Email, or username) writing to their personal in-app inbox (`notifications_active`
 *     and `user_notifications`) AND pushing to all of their registered physical devices!
 *
 * Secured with strict Super Admin verification (`isCallableSuperAdmin`).
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { isCallableSuperAdmin } from "../utils/auth";
import { notifyUser } from "../notifications/notifications";

const db = admin.firestore();

export interface BroadcastPushPayload {
  title: string;
  body: string;
  imageUrl?: string;
  actionUrl?: string;
  targetPlatform?: "all" | "android" | "ios";
  targetApp?: "app" | "studio" | "all";
  presetTag?: string;
  dryRun?: boolean;
  // 1-to-1 Direct User fields
  targetMode?: "broadcast" | "direct_user";
  targetUser?: string; // UID, Email, or Username
}

export const sendBroadcastPushNotification = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 5,
  },
  async (request) => {
    const auth = request.auth;
    if (!auth || !auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication required to send notifications.");
    }

    // 🔒 Strictly enforce Super Admin access
    const isSuperAdmin = await isCallableSuperAdmin(auth);
    if (!isSuperAdmin) {
      logger.warn(`[PushNotification] Unauthorized dispatch attempt by user ${auth.uid} (${auth.token.email})`);
      throw new HttpsError(
        "permission-denied",
        "Permission denied. Only TruthWorld Super Admins can dispatch notifications."
      );
    }

    const data = (request.data || {}) as BroadcastPushPayload;
    const title = (data.title || "").trim();
    const body = (data.body || "").trim();
    const rawImageUrl = (data.imageUrl || "").trim();
    const rawActionUrl = (data.actionUrl || "").trim();
    const targetPlatform = data.targetPlatform || "all";
    const targetApp = data.targetApp || "app";
    const targetMode = data.targetMode === "direct_user" ? "direct_user" : "broadcast";
    const presetTag = (data.presetTag || "").trim();
    const isDryRun = Boolean(data.dryRun);

    // Common Validation
    if (!title) {
      throw new HttpsError("invalid-argument", "Notification title is required.");
    }
    if (title.length > 120) {
      throw new HttpsError("invalid-argument", "Notification title cannot exceed 120 characters.");
    }

    if (!body) {
      throw new HttpsError("invalid-argument", "Notification message body is required.");
    }
    if (body.length > 350) {
      throw new HttpsError("invalid-argument", "Notification body cannot exceed 350 characters.");
    }

    let validImageUrl: string | undefined;
    if (rawImageUrl) {
      try {
        const parsed = new URL(rawImageUrl);
        if (parsed.protocol === "https:" || parsed.protocol === "http:") {
          validImageUrl = rawImageUrl;
        }
      } catch {
        throw new HttpsError("invalid-argument", "Invalid image URL provided.");
      }
    }

    const broadcastId = db.collection("broadcast_notifications").doc().id;
    const senderEmail = (auth.token.email || "super_admin").toLowerCase();

    // ─────────────────────────────────────────────────────────────────────────────
    // 👤 MODE 1: 1-TO-1 DIRECT USER NOTIFICATION
    // ─────────────────────────────────────────────────────────────────────────────
    if (targetMode === "direct_user") {
      const targetQuery = (data.targetUser || "").trim();
      if (!targetQuery) {
        throw new HttpsError("invalid-argument", "Target user (UID, Email, or Username) is required for 1-to-1 direct notifications.");
      }

      let targetUid = "";
      let targetUserEmail = "";
      let targetDisplayName = "";

      // 1. Try finding by direct UID
      const docByUid = await db.collection("users").doc(targetQuery).get();
      if (docByUid.exists) {
        targetUid = docByUid.id;
        const d = docByUid.data() || {};
        targetUserEmail = (d.email || "").toLowerCase();
        targetDisplayName = d.displayName || d.username || "";
      } else {
        // 2. Try finding by email
        const snapByEmail = await db.collection("users").where("email", "==", targetQuery.toLowerCase()).limit(1).get();
        if (!snapByEmail.empty) {
          const doc = snapByEmail.docs[0];
          targetUid = doc.id;
          const d = doc.data() || {};
          targetUserEmail = (d.email || "").toLowerCase();
          targetDisplayName = d.displayName || d.username || "";
        } else {
          // 3. Try finding by username
          const snapByUsername = await db.collection("users").where("username", "==", targetQuery).limit(1).get();
          if (!snapByUsername.empty) {
            const doc = snapByUsername.docs[0];
            targetUid = doc.id;
            const d = doc.data() || {};
            targetUserEmail = (d.email || "").toLowerCase();
            targetDisplayName = d.displayName || d.username || "";
          }
        }
      }

      if (!targetUid) {
        throw new HttpsError("not-found", `No TruthWorld user found matching: "${targetQuery}". Please verify the UID or email.`);
      }

      let notificationId = "";
      if (!isDryRun) {
        notificationId = (await notifyUser({
          userId: targetUid,
          type: "system_announcement",
          severity: "priority",
          title,
          message: body,
          actionUrl: rawActionUrl,
          targetApp,
          metadata: {
            isDirectAdminMessage: true,
            senderEmail,
            senderUid: auth.uid,
            thumbnailUrl: validImageUrl,
            presetTag,
          },
        })) || "";

        logger.info(
          `[DirectPush] Successfully dispatched 1-to-1 direct message notification to user ${targetUid} (${targetUserEmail}) by ${senderEmail}. Notification ID: ${notificationId}`
        );
      } else {
        notificationId = `dry_run_direct_${Date.now()}`;
        logger.info(`[DirectPush] Dry run simulated for user ${targetUid} (${targetUserEmail})`);
      }

      // Persist campaign record in Firestore
      const directRecord = {
        id: broadcastId,
        title,
        body,
        imageUrl: validImageUrl || null,
        actionUrl: rawActionUrl || null,
        targetMode: "direct_user",
        targetPlatform,
        targetApp,
        presetTag: presetTag || null,
        targetUid,
        targetUserEmail,
        targetDisplayName,
        notificationId,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        sentByUid: auth.uid,
        senderEmail,
        isDryRun,
        status: "DELIVERED",
      };

      const batch = db.batch();
      batch.set(db.collection("broadcast_notifications").doc(broadcastId), directRecord);

      // Audit compliance log entry
      batch.set(db.collection("admin_actions_log").doc(), {
        action: "ADMIN_DIRECT_USER_NOTIFICATION_SENT",
        adminUid: auth.uid,
        adminEmail: senderEmail,
        broadcastId,
        targetUid,
        targetUserEmail,
        title,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          notificationId,
          hasImage: Boolean(validImageUrl),
          actionUrl: rawActionUrl,
        },
      });

      await batch.commit();

      return {
        success: true,
        broadcastId,
        targetMode: "direct_user",
        targetUid,
        targetUserEmail,
        targetDisplayName,
        notificationId,
        timestamp: Date.now(),
      };
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // 📢 MODE 2: PLATFORM-WIDE BROADCAST TO EVERY INSTALLED DEVICE
    // ─────────────────────────────────────────────────────────────────────────────
    let resolvedTopic = "all_devices";
    if (targetPlatform === "android") {
      resolvedTopic = "all_android";
    } else if (targetPlatform === "ios") {
      resolvedTopic = "all_ios";
    }

    const fcmMessage: admin.messaging.Message = {
      topic: resolvedTopic,
      notification: {
        title,
        body,
        ...(validImageUrl ? { imageUrl: validImageUrl } : {}),
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        actionUrl: rawActionUrl,
        type: "broadcast_push",
        category: "broadcast",
        notificationId: broadcastId,
        targetApp,
        presetTag,
        ...(validImageUrl ? { imageUrl: validImageUrl } : {}),
        timestamp: String(Date.now()),
      },
      android: {
        priority: "high" as const,
        notification: {
          channelId: "truthworld_notifications",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          priority: "max" as const,
          visibility: "public" as const,
          icon: "ic_notification",
          color: "#14EAB2",
          sound: "default",
          ...(validImageUrl ? { imageUrl: validImageUrl } : {}),
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
            "mutable-content": 1,
          },
        },
        ...(validImageUrl ? { fcmOptions: { imageUrl: validImageUrl } } : {}),
      },
      webpush: {
        headers: {
          Urgency: "high",
        },
        notification: {
          icon: "https://www.truthworld.in/icons/Icon-192.png",
          badge: "https://www.truthworld.in/icons/Icon-192.png",
          ...(validImageUrl ? { image: validImageUrl } : {}),
        },
        fcmOptions: {
          link: rawActionUrl.startsWith("/") ? `https://www.truthworld.in${rawActionUrl}` : "https://www.truthworld.in",
        },
      },
    };

    let fcmMessageId = "";
    if (!isDryRun) {
      try {
        fcmMessageId = await admin.messaging().send(fcmMessage);
        logger.info(
          `[BroadcastPush] Successfully sent broadcast ${broadcastId} to topic '${resolvedTopic}' by ${senderEmail}. Message ID: ${fcmMessageId}`
        );
      } catch (fcmErr) {
        logger.error(`[BroadcastPush] FCM dispatch failed for broadcast ${broadcastId}:`, fcmErr);
        throw new HttpsError("internal", "Failed to dispatch push notification through FCM gateway.");
      }
    } else {
      fcmMessageId = `dry_run_${Date.now()}`;
      logger.info(`[BroadcastPush] Dry run simulated for broadcast ${broadcastId} to topic '${resolvedTopic}'`);
    }

    // Persist campaign record in Firestore
    const broadcastRecord = {
      id: broadcastId,
      title,
      body,
      imageUrl: validImageUrl || null,
      actionUrl: rawActionUrl || null,
      targetMode: "broadcast",
      targetPlatform,
      targetApp,
      presetTag: presetTag || null,
      topic: resolvedTopic,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      sentByUid: auth.uid,
      senderEmail,
      fcmMessageId,
      isDryRun,
      status: "SENT",
    };

    const batch = db.batch();
    batch.set(db.collection("broadcast_notifications").doc(broadcastId), broadcastRecord);

    // Audit compliance log entry
    batch.set(db.collection("admin_actions_log").doc(), {
      action: "BROADCAST_PUSH_SENT",
      adminUid: auth.uid,
      adminEmail: senderEmail,
      broadcastId,
      title,
      targetPlatform,
      targetApp,
      topic: resolvedTopic,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        fcmMessageId,
        hasImage: Boolean(validImageUrl),
        actionUrl: rawActionUrl,
      },
    });

    await batch.commit();

    return {
      success: true,
      broadcastId,
      targetMode: "broadcast",
      messageId: fcmMessageId,
      topic: resolvedTopic,
      timestamp: Date.now(),
    };
  }
);
