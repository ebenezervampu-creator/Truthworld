import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin } from "../utils/auth";
import { logger } from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const searchUsers = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { query, limit = 50, startAfter } = req.body;
      
      let firestoreQuery = admin.firestore().collection("users").limit(Math.min(limit, 50));
      
      if (startAfter) {
          const doc = await admin.firestore().collection("users").doc(startAfter).get();
          if (doc.exists) {
              firestoreQuery = firestoreQuery.startAfter(doc);
          }
      }
      
      const snapshot = await firestoreQuery.get();
      let users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      if (query) {
        const qLower = query.toLowerCase();
        users = users.filter((u: any) => 
            (u.email && u.email.toLowerCase().includes(qLower)) || 
            (u.displayName && u.displayName.toLowerCase().includes(qLower))
        );
      }

      let nextCursor = null;
      if (snapshot.docs.length === limit) {
          nextCursor = snapshot.docs[snapshot.docs.length - 1].id;
      }

      res.status(200).json({ users, nextCursor });
    } catch (error) {
      logger.error("[searchUsers] Error:", error);
      res.status(500).json({ error: error instanceof Error ? error.message : "Internal error" });
    }
  }
);

export const getUserSafetyProfile = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { userId } = req.query;
      if (!userId || typeof userId !== "string") {
        res.status(400).json({ error: "Missing userId" });
        return;
      }

      const db = admin.firestore();
      
      const [userTrustSnap, imageVerifCountSnap, videoJobsCountSnap, channelsSnap] = await Promise.all([
          db.collection("userTrust").doc(userId).get(),
          db.collection("image_verification").where("userId", "==", userId).count().get(),
          db.collection("video_jobs").where("userId", "==", userId).count().get(),
          db.collection("channels").where("ownerId", "==", userId).limit(20).get()
      ]);

      const profile = {
          trustScore: userTrustSnap.data()?.score || 0,
          strikeCount: userTrustSnap.data()?.strikes || 0,
          uploadStats: {
              images: imageVerifCountSnap.data().count,
              videos: videoJobsCountSnap.data().count
          },
          channels: channelsSnap.docs.map(d => ({id: d.id, ...d.data()})),
          accountStatus: userTrustSnap.data()?.accountStatus || "ACTIVE"
      };

      res.status(200).json(profile);
    } catch (error) {
      logger.error("[getUserSafetyProfile] Error:", error);
      res.status(500).json({ error: error instanceof Error ? error.message : "Internal error" });
    }
  }
);

export const moderateUser = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { userId, action, reason, duration, durationDays } = req.body;
      if (!userId || !action) {
        res.status(400).json({ error: "Missing required fields (userId, action)" });
        return;
      }

      const normalizedAction = (action || "").trim().toLowerCase();
      const actionReason = reason || `Admin moderation action: ${action}`;
      const db = admin.firestore();
      const updates: Record<string, any> = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (normalizedAction === "ban" || normalizedAction === "ban user") {
        updates.isBanned = true;
        updates.role = "banned";
        updates.accountStatus = "BANNED";
        updates.status = "banned";
        updates.banReason = actionReason;
        updates.bannedAt = admin.firestore.FieldValue.serverTimestamp();
      } else if (
        normalizedAction === "unban" ||
        normalizedAction === "unban user" ||
        normalizedAction === "reactivate" ||
        normalizedAction === "reactivate user"
      ) {
        updates.isBanned = false;
        updates.role = "user";
        updates.accountStatus = "ACTIVE";
        updates.status = "active";
        updates.banReason = admin.firestore.FieldValue.delete();
        updates.suspendedUntil = admin.firestore.FieldValue.delete();
      } else if (normalizedAction.startsWith("suspend")) {
        const days = Number(durationDays || duration || 7);
        const until = Date.now() + (days * 24 * 60 * 60 * 1000);
        updates.isBanned = false;
        updates.accountStatus = "SUSPENDED";
        updates.status = "suspended";
        updates.suspendedUntil = until;
        updates.banReason = actionReason;
      } else if (normalizedAction === "warn" || normalizedAction === "warn user") {
        updates.strikes = admin.firestore.FieldValue.increment(1);
        updates.lastWarningReason = actionReason;
        updates.lastWarningAt = admin.firestore.FieldValue.serverTimestamp();
      } else if (
        normalizedAction === "reset_trust" ||
        normalizedAction === "reset trust" ||
        normalizedAction === "reset"
      ) {
        updates.trustScore = 100;
        updates.strikes = 0;
        try {
          await db.collection("userTrust").doc(userId).set({
            score: 100,
            strikes: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        } catch (trustErr) {
          logger.warn("[moderateUser] Could not update userTrust doc:", trustErr);
        }
      } else if (
        normalizedAction === "delete" ||
        normalizedAction === "delete user" ||
        normalizedAction === "delete account"
      ) {
        updates.isDeleted = true;
        updates.status = "deleted";
        updates.accountStatus = "DELETED";
      }

      await db.collection("users").doc(userId).set(updates, { merge: true });

      await db.collection("admin_actions_log").add({
        adminId: adminUser.uid,
        adminEmail: adminUser.email || "",
        userId,
        action: normalizedAction,
        reason: actionReason,
        durationDays: durationDays || duration || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).json({ success: true, action: normalizedAction, userId });
    } catch (error) {
      logger.error("[moderateUser] Error:", error);
      res.status(500).json({ error: error instanceof Error ? error.message : "Internal error" });
    }
  }
);

export const consolidateUserAccounts = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { email, primaryUid } = req.body;
      if (!email) {
        res.status(400).json({ error: "Missing required field: email" });
        return;
      }

      const db = admin.firestore();
      const usersSnap = await db.collection("users").where("email", "==", email).get();

      if (usersSnap.empty || usersSnap.docs.length < 2) {
        res.status(200).json({ message: "No duplicate user documents found for this email.", count: usersSnap.docs.length });
        return;
      }

      let primaryDoc = primaryUid 
        ? usersSnap.docs.find(d => d.id === primaryUid)
        : usersSnap.docs.reduce((latest, current) => {
            const latestTime = (latest.data().updatedAt as number) || 0;
            const currentTime = (current.data().updatedAt as number) || 0;
            return currentTime > latestTime ? current : latest;
          });

      if (!primaryDoc) {
        primaryDoc = usersSnap.docs[0];
      }

      const primaryId = primaryDoc.id;
      const legacyDocs = usersSnap.docs.filter(d => d.id !== primaryId);

      let channelRestored = null;

      for (const legacyDoc of legacyDocs) {
        const legacyData = legacyDoc.data();
        const legacyChannelId = legacyData.channelId;

        if (legacyChannelId) {
          channelRestored = legacyChannelId;
          await db.collection("channels").doc(legacyChannelId).update({
            ownerId: primaryId,
            userId: primaryId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }

        const updateObj: Record<string, any> = {};
        if (!primaryDoc.data().channelId && legacyChannelId) {
          updateObj.channelId = legacyChannelId;
        }
        if (!primaryDoc.data().ageGroup && legacyData.ageGroup) {
          updateObj.ageGroup = legacyData.ageGroup;
        }
        if (!primaryDoc.data().gender && legacyData.gender) {
          updateObj.gender = legacyData.gender;
        }

        if (Object.keys(updateObj).length > 0) {
          await primaryDoc.ref.update(updateObj);
        }

        await legacyDoc.ref.delete();
      }

      await db.collection("admin_actions_log").add({
        adminId: adminUser.uid,
        action: "consolidate_duplicate_users",
        email,
        primaryUid: primaryId,
        mergedUids: legacyDocs.map(d => d.id),
        channelRestored,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      res.status(200).json({
        success: true,
        primaryUid: primaryId,
        mergedCount: legacyDocs.length,
        channelRestored
      });
    } catch (error) {
      logger.error("[consolidateUserAccounts] Error:", error);
      res.status(500).json({ error: error instanceof Error ? error.message : "Internal error" });
    }
  }
);

