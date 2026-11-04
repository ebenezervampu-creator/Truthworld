import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { requireAdmin, requireRecentAdmin } from "../utils/auth";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { logger } from "firebase-functions/v2";
import { purgeAllUserData } from "../users/userLifecycle";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const searchUsers = onRequest(
  {
    cors: false,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    applySecurityHeaders(res);
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
      let users = snapshot.docs.map(doc => {
        const d = doc.data();
        return {
          id: doc.id,
          displayName: d.displayName || "",
          email: d.email || "",
          role: d.role || "user",
          accountStatus: d.accountStatus || "ACTIVE",
          hasChannel: d.hasChannel || false,
          createdAt: d.createdAt || null,
        };
      });

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
      res.status(500).json({ error: "Unable to search users. Please try again." });
    }
  }
);

export const getUserSafetyProfile = onRequest(
  {
    cors: false,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    applySecurityHeaders(res);
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
      res.status(500).json({ error: "Unable to retrieve user safety profile." });
    }
  }
);

export const moderateUser = onRequest(
  {
    cors: false,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const adminUser = await requireAdmin(req, res);
      if (!adminUser) return;

      const { userId, action, reason, duration, durationDays } = req.body;
      if (
        !userId ||
        !action ||
        typeof userId !== "string" ||
        typeof action !== "string" ||
        !userId.trim() ||
        !action.trim()
      ) {
        res.status(400).json({ error: "Missing required fields (userId, action)" });
        return;
      }

      const normalizedAction = (action || "").trim().toLowerCase();

      // Block moderation or deletion actions if target user has admin === true or entry in admin_members
      const db = admin.firestore();
      const targetUserDoc = await db.collection("users").doc(userId).get();
      const targetUserData = targetUserDoc.data();
      const targetEmail = (targetUserData?.email || "").toLowerCase();

      let isTargetAdmin = false;
      if (
        targetUserData?.admin === true ||
        targetUserData?.role === "admin" ||
        targetUserData?.role === "Super Admin" ||
        targetUserData?.role === "Owner"
      ) {
        isTargetAdmin = true;
      }

      if (!isTargetAdmin) {
        const uidMemberDoc = await db.collection("admin_members").doc(userId).get();
        if (uidMemberDoc.exists && uidMemberDoc.data()?.status !== "suspended") {
          isTargetAdmin = true;
        }
      }

      if (!isTargetAdmin && targetEmail) {
        const emailMemberDoc = await db.collection("admin_members").doc(targetEmail).get();
        if (emailMemberDoc.exists && emailMemberDoc.data()?.status !== "suspended") {
          isTargetAdmin = true;
        }
      }

      if (!isTargetAdmin) {
        try {
          const authUser = await admin.auth().getUser(userId);
          const claims = authUser.customClaims || {};
          if (claims.admin === true || claims.role === "admin" || claims.isSuperAdmin === true || claims.isDirector === true) {
            isTargetAdmin = true;
          }
          if (!isTargetAdmin && authUser.email) {
            const authEmailMember = await db.collection("admin_members").doc(authUser.email.toLowerCase()).get();
            if (authEmailMember.exists && authEmailMember.data()?.status !== "suspended") {
              isTargetAdmin = true;
            }
          }
        } catch {
          // Auth user lookup notice
        }
      }

      if (isTargetAdmin) {
        logger.warn(`[moderateUser] Blocked moderation action against administrator: ${userId}`);
        res.status(403).json({ error: "Cannot moderate or delete an administrator account." });
        return;
      }

      // Require step-up re-authentication for high-impact destructive operations
      if (
        normalizedAction === "delete" ||
        normalizedAction === "delete user" ||
        normalizedAction === "delete account" ||
        normalizedAction === "ban" ||
        normalizedAction === "ban user"
      ) {
        const recentAdmin = await requireRecentAdmin(req, res, 1800);
        if (!recentAdmin) return;
      }

      const actionReason = reason || `Admin moderation action: ${action}`;
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
        await purgeAllUserData(userId).catch((err) => {
          logger.warn(`[moderateUser] purgeAllUserData error for ${userId}:`, err);
        });
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
      res.status(500).json({ error: "Unable to process moderation action. Please try again." });
    }
  }
);

export const consolidateUserAccounts = onRequest(
  {
    cors: false,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
      if (!adminUser) return;

      const { email, phoneNumber, primaryUid } = req.body;
      if (!email && !phoneNumber) {
        res.status(400).json({ error: "Missing required field: email or phoneNumber" });
        return;
      }

      const db = admin.firestore();
      const docsMap = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();

      if (email) {
        const emailSnap = await db.collection("users").where("email", "==", email).get();
        for (const doc of emailSnap.docs) {
          docsMap.set(doc.id, doc);
        }
      }

      if (phoneNumber) {
        const phoneSnapRoot = await db.collection("users").where("phoneNumber", "==", phoneNumber).get();
        for (const doc of phoneSnapRoot.docs) {
          docsMap.set(doc.id, doc);
        }
        const phoneSnapMeta = await db.collection("users").where("metadata.phoneNumber", "==", phoneNumber).get();
        for (const doc of phoneSnapMeta.docs) {
          docsMap.set(doc.id, doc);
        }
      }

      const allDocs = Array.from(docsMap.values());

      if (allDocs.length < 2) {
        res.status(200).json({
          message: "No duplicate user documents found.",
          count: allDocs.length,
        });
        return;
      }

      if (primaryUid && !allDocs.some((d) => d.id === primaryUid)) {
        res.status(400).json({
          error: "The provided primaryUid does not match any duplicate user document.",
        });
        return;
      }

      // Select primary document (prefer document with explicit primaryUid, non-empty displayName or completed onboarding)
      let primaryDoc = primaryUid
        ? allDocs.find((d) => d.id === primaryUid)
        : allDocs.reduce((best, curr) => {
            const bestName = (best.data().displayName as string) || "";
            const currName = (curr.data().displayName as string) || "";
            const bestScore = (bestName.trim().length > 0 ? 2 : 0) + (best.data().hasCompletedOnboarding ? 1 : 0);
            const currScore = (currName.trim().length > 0 ? 2 : 0) + (curr.data().hasCompletedOnboarding ? 1 : 0);
            if (currScore !== bestScore) return currScore > bestScore ? curr : best;

            const bestTime = (best.data().updatedAt as number) || (best.data().createdAt as number) || 0;
            const currTime = (curr.data().updatedAt as number) || (curr.data().createdAt as number) || 0;
            return currTime > bestTime ? curr : best;
          });

      if (!primaryDoc) {
        primaryDoc = allDocs[0];
      }

      const primaryId = primaryDoc.id;
      const legacyDocs = allDocs.filter((d) => d.id !== primaryId);

      let channelRestored = null;
      const primaryData = primaryDoc.data();
      const updateObj: Record<string, any> = {};

      const fieldsToMerge = [
        "channelId",
        "displayName",
        "name",
        "username",
        "handle",
        "bio",
        "photoURL",
        "photoUrl",
        "avatarUrl",
        "avatarFileId",
        "avatarStatus",
        "avatarStatusReason",
        "gender",
        "age",
        "ageGroup",
        "birthdate",
        "location",
        "city",
        "state",
        "country",
        "profession",
        "interests",
        "topicAffinities",
        "topicExploreCounts",
        "exploredTopicSlugs",
      ];

      for (const legacyDoc of legacyDocs) {
        const legacyData = legacyDoc.data();
        const legacyChannelId = legacyData.channelId as string | undefined;

        if (legacyChannelId) {
          // Require verified email on both accounts before transferring channel ownership
          let primaryEmailVerified = false;
          let legacyEmailVerified = false;

          try {
            const primaryAuth = await admin.auth().getUser(primaryId);
            primaryEmailVerified = primaryAuth.emailVerified === true;
          } catch (authErr) {
            logger.warn(`[consolidateUserAccounts] Primary auth lookup notice for ${primaryId}:`, authErr);
          }

          try {
            const legacyAuth = await admin.auth().getUser(legacyDoc.id);
            legacyEmailVerified = legacyAuth.emailVerified === true;
          } catch (authErr) {
            logger.warn(`[consolidateUserAccounts] Legacy auth lookup notice for ${legacyDoc.id}:`, authErr);
          }

          if (!primaryEmailVerified || !legacyEmailVerified) {
            logger.warn(
              `[consolidateUserAccounts] Channel transfer blocked for channel ${legacyChannelId}: both primary (${primaryId}, verified=${primaryEmailVerified}) and secondary (${legacyDoc.id}, verified=${legacyEmailVerified}) accounts must have verified email addresses.`
            );
            res.status(403).json({
              error: "Both primary and secondary accounts must have verified email addresses before channel ownership can be transferred.",
            });
            return;
          }

          channelRestored = legacyChannelId;
          await db.collection("channels").doc(legacyChannelId).update({
            ownerId: primaryId,
            userId: primaryId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        for (const field of fieldsToMerge) {
          const currentVal = primaryData[field] ?? updateObj[field];
          const legacyVal = legacyData[field];
          if (
            (currentVal === undefined || currentVal === null || (typeof currentVal === "string" && currentVal.trim() === "")) &&
            legacyVal !== undefined && legacyVal !== null && (typeof legacyVal !== "string" || legacyVal.trim() !== "")
          ) {
            updateObj[field] = legacyVal;
          }
        }

        if (legacyData.hasCompletedOnboarding && !primaryData.hasCompletedOnboarding) {
          updateObj.hasCompletedOnboarding = true;
        }

        await legacyDoc.ref.delete();
      }

      if (Object.keys(updateObj).length > 0) {
        updateObj.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await primaryDoc.ref.update(updateObj);
      }

      await db.collection("admin_actions_log").add({
        adminId: adminUser.uid,
        action: "consolidate_duplicate_users",
        email: email || null,
        phoneNumber: phoneNumber || null,
        primaryUid: primaryId,
        mergedUids: legacyDocs.map((d) => d.id),
        channelRestored,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).json({
        success: true,
        primaryUid: primaryId,
        mergedCount: legacyDocs.length,
        channelRestored,
      });
    } catch (error) {
      logger.error("[consolidateUserAccounts] Error:", error);
      res.status(500).json({ error: "Unable to consolidate accounts. Please try again." });
    }
  }
);

