/**
 * 🗑️ USER LIFECYCLE & GDPR DELETION SERVICE
 *
 * Automatically triggered when a Firebase Auth user is deleted.
 * Performs a comprehensive, irreversible purge across:
 *   1. Firebase Storage: avatars, banners, videos, audio variants, thumbnails.
 *   2. Cloud Firestore: recursive deletion of user document and all subcollections
 *      (playlists, likedVideos, clips, etc.), channel docs and subcollections,
 *      uploaded videos, subscriptions, comments, notifications, userTrust, userCache.
 *   3. Realtime Database: user presence, session logs.
 */

import { logger, region } from "firebase-functions/v1";
import { onRequest, onCall } from "firebase-functions/v2/https";
import type { UserRecord } from "firebase-admin/auth";
import * as admin from "firebase-admin";
import { verifyAuth, setCorsHeaders } from "../utils/auth";
import { isSessionRecent, applySecurityHeaders } from "../utils/securityHeaders";
import { EmailService } from "../services/emailService";
import { getDynamicPlatformLimits } from "../config/platformLimits";

const db = () => admin.firestore();
const storage = () => admin.storage();

/**
 * Purges all storage files associated with a given directory prefix.
 */
async function purgeStoragePrefix(prefix: string): Promise<number> {
  try {
    const bucket = storage().bucket();
    const [files] = await bucket.getFiles({ prefix });
    if (files.length === 0) return 0;

    await bucket.deleteFiles({ prefix });
    return files.length;
  } catch (error) {
    logger.warn(`[UserLifecycle] Storage purge error for prefix "${prefix}":`, error);
    return 0;
  }
}

/**
 * Purges all database and storage records belonging to a user ID.
 */
export async function purgeAllUserData(uid: string): Promise<{
  success: boolean;
  purgedVideosCount: number;
  purgedChannelsCount: number;
}> {
  logger.info(`[UserLifecycle] Starting comprehensive data purge for UID: ${uid}`);

  const firestore = db();
  let purgedVideosCount = 0;
  let purgedChannelsCount = 0;

  try {
    // ─── 1. Retrieve User & Associated Channel Identifiers ─────────────────────
    const userRef = firestore.collection("users").doc(uid);
    const userSnap = await userRef.get().catch(() => null);
    const userData = userSnap?.exists ? userSnap.data() : null;
    const userChannelId = userData?.channelId as string | undefined;

    // Collect all channel IDs owned by this user
    const channelIds = new Set<string>();
    if (userChannelId) channelIds.add(userChannelId);

    const ownedChannelsSnap = await firestore
      .collection("channels")
      .where("ownerId", "==", uid)
      .get()
      .catch(() => ({ docs: [] } as any));

    for (const doc of ownedChannelsSnap.docs) {
      channelIds.add(doc.id);
    }

    const userIdChannelsSnap = await firestore
      .collection("channels")
      .where("userId", "==", uid)
      .get()
      .catch(() => ({ docs: [] } as any));

    for (const doc of userIdChannelsSnap.docs) {
      channelIds.add(doc.id);
    }

    // ─── 2. Clean Up Videos Owned by User / Channels ───────────────────────────
    const videoDocsToPurge = new Map<string, FirebaseFirestore.DocumentReference>();

    const userVideosSnap = await firestore
      .collection("videos")
      .where("ownerId", "==", uid)
      .get()
      .catch(() => ({ docs: [] } as any));

    for (const doc of userVideosSnap.docs) {
      videoDocsToPurge.set(doc.id, doc.ref);
    }

    const uploaderVideosSnap = await firestore
      .collection("videos")
      .where("uploaderId", "==", uid)
      .get()
      .catch(() => ({ docs: [] } as any));

    for (const doc of uploaderVideosSnap.docs) {
      videoDocsToPurge.set(doc.id, doc.ref);
    }

    for (const chId of channelIds) {
      const chVideosSnap = await firestore
        .collection("videos")
        .where("channelId", "==", chId)
        .get()
        .catch(() => ({ docs: [] } as any));

      for (const doc of chVideosSnap.docs) {
        videoDocsToPurge.set(doc.id, doc.ref);
      }
    }

    // Delete each video's Storage assets and Firestore document + subcollections
    for (const [videoId, videoRef] of videoDocsToPurge.entries()) {
      await purgeStoragePrefix(`videos/${videoId}/`);
      await firestore.recursiveDelete(videoRef).catch((e) => {
        logger.warn(`[UserLifecycle] Error recursive deleting video ${videoId}:`, e);
      });
      purgedVideosCount++;
    }

    // ─── 3. Clean Up Channels & Channel Handles ────────────────────────────────
    for (const chId of channelIds) {
      // Purge channel storage assets (banners, logos, etc.)
      await purgeStoragePrefix(`channels/${chId}/`);

      // Recursive delete channel document and subcollections (members, tiers, kyc, etc.)
      const chRef = firestore.collection("channels").doc(chId);
      await firestore.recursiveDelete(chRef).catch((e) => {
        logger.warn(`[UserLifecycle] Error recursive deleting channel ${chId}:`, e);
      });
      purgedChannelsCount++;
    }

    // Delete channel handles owned by this user
    const handlesSnap = await firestore
      .collection("channel_handles")
      .where("ownerId", "==", uid)
      .get()
      .catch(() => ({ docs: [] } as any));

    for (const doc of handlesSnap.docs) {
      await doc.ref.delete().catch(() => {});
    }

    // ─── 4. Clean Up User Storage (Avatars, Uploads, Clips) ────────────────────
    await purgeStoragePrefix(`users/${uid}/`);
    await purgeStoragePrefix(`avatars/${uid}`);

    // ─── 5. Recursive Deletion of User Doc and Subcollections ──────────────────
    // Deletes users/{uid} and all subcollections: watch_history, playlists, likedVideos, etc.
    const knownSubcollections = [
      "watch_history",
      "liked_videos",
      "likedVideos",
      "disliked_videos",
      "dislikedVideos",
      "watch_later",
      "playlists",
      "saved_playlists",
      "clips",
      "liked_clips",
      "feed_inbox",
      "savedTopics",
      "likedTopics",
      "liked_topic_comments",
      "liked_topic_replies",
      "comment_interactions",
      "reply_interactions",
      "savedCommunityPosts",
      "savedComments",
      "hiddenCommunityPosts",
      "mutedCommunityChannels",
      "reportedCommunityPosts",
      "subscriptions",
      "userSubscriptions",
      "channelMemberships",
      "channel_memberships",
      "notifications_active",
      "notifications_archive",
      "saved_ads",
    ];

    // Discover any subcollections dynamically
    try {
      const collections = await userRef.listCollections();
      for (const col of collections) {
        await firestore.recursiveDelete(col).catch((err) => {
          logger.warn(`[UserLifecycle] Error recursive deleting collection ${col.id} for ${uid}:`, err);
        });
      }
    } catch (e) {
      logger.warn(`[UserLifecycle] listCollections warning for ${uid}:`, e);
    }

    // Explicitly delete known subcollections in case parent doc was already deleted
    for (const subName of knownSubcollections) {
      await firestore.recursiveDelete(userRef.collection(subName)).catch(() => {});
    }

    // Finally recursively delete the user document reference itself
    await firestore.recursiveDelete(userRef).catch((e) => {
      logger.warn(`[UserLifecycle] Error recursive deleting users/${uid}:`, e);
    });

    // ─── 6. Clean Up Auxiliary User Records ────────────────────────────────────
    // userTrust
    await firestore.collection("userTrust").doc(uid).delete().catch(() => {});

    // userCache (and subcollections)
    const userCacheRef = firestore.collection("userCache").doc(uid);
    await firestore.recursiveDelete(userCacheRef).catch(() => {});

    // Subscriptions created by the user
    const subsSnap = await firestore
      .collection("subscriptions")
      .where("userId", "==", uid)
      .limit(200)
      .get()
      .catch(() => ({ docs: [] } as any));

    const batch = firestore.batch();
    for (const doc of subsSnap.docs) {
      batch.delete(doc.ref);
    }

    // User notifications
    const notifsSnap = await firestore
      .collection("notifications")
      .where("userId", "==", uid)
      .limit(200)
      .get()
      .catch(() => ({ docs: [] } as any));

    for (const doc of notifsSnap.docs) {
      batch.delete(doc.ref);
    }

    // Community posts authored by the user
    const postsSnap = await firestore
      .collection("community_posts")
      .where("authorId", "==", uid)
      .limit(100)
      .get()
      .catch(() => ({ docs: [] } as any));

    for (const doc of postsSnap.docs) {
      batch.delete(doc.ref);
    }

    await batch.commit().catch((e) => {
      logger.warn("[UserLifecycle] Batch delete auxiliary records error:", e);
    });

    // ─── 7. Realtime Database Cleanup (Presence & Sessions) ────────────────────
    try {
      await admin.database().ref(`status/${uid}`).remove();
    } catch {
      // RTDB cleanup is optional / non-fatal
    }

    logger.info(
      `[UserLifecycle] Successfully purged all data for UID: ${uid} (Videos: ${purgedVideosCount}, Channels: ${purgedChannelsCount})`
    );

    return {
      success: true,
      purgedVideosCount,
      purgedChannelsCount,
    };
  } catch (error) {
    logger.error(`[UserLifecycle] Fatal error during user data purge for UID: ${uid}`, error);
    return {
      success: false,
      purgedVideosCount,
      purgedChannelsCount,
    };
  }
}

/**
 * ⚡ ON USER CREATED (Auth Trigger)
 * Automatically triggers when any new user registers via Firebase Auth
 * (Email/Password, Google Sign-in, Apple ID, etc.).
 *
 * Dispatches a branded HTML welcome email via native Google/Gmail SMTP,
 * guarded by Firestore idempotency to prevent duplicate emails on retries.
 */
export const onUserCreated = region("asia-south1")
  .runWith({
    secrets: ["SMTP_USER", "SMTP_PASS"],
  })
  .auth.user()
  .onCreate(async (user: UserRecord) => {
  const uid = user.uid;
  const email = user.email;
  const displayName = user.displayName || null;

  logger.info(`[onUserCreated] Triggered for user: ${uid} (email: ${email || "no-email"})`);

  const firestore = db();

  // 🎁 Directly credit 1,000 Free Characters to every new user (Test Before Pay)
  try {
    const walletRef = firestore.collection("dubbing_wallets").doc(uid);
    const walletSnap = await walletRef.get().catch(() => null);
    if (!walletSnap || !walletSnap.exists) {
      const now = Date.now();
      const welcomeTx = {
        id: `tx_welcome_${now}`,
        type: "trial_credit",
        amountCredits: 1000,
        amountUsd: 0.50,
        description: "Welcome: 1,000 Free Characters (Test Before Pay)",
        timestamp: now,
      };
      await walletRef.set({
        userId: uid,
        balanceCredits: 1000,
        balanceUsd: 0.50,
        trialClaimed: true,
        trialClaimedAt: now,
        totalCharactersUsed: 0,
        totalSpentUsd: 0,
        transactions: [welcomeTx],
        updatedAt: now,
      });
      logger.info(`[onUserCreated] Successfully granted 1,000 free test characters to new user ${uid}`);
    }
  } catch (walletErr) {
    logger.warn(`[onUserCreated] Error provisioning 1k test characters for user ${uid}:`, walletErr);
  }

  if (!email) {
    logger.info(`[onUserCreated] User ${uid} registered without an email; welcome email skipped.`);
    return;
  }

  const userRef = firestore.collection("users").doc(uid);

  try {
    // 1. Idempotency Check: Verify if welcome email has already been dispatched
    const userSnap = await userRef.get().catch(() => null);
    if (userSnap?.exists && userSnap.data()?.welcomeEmailSent === true) {
      logger.info(`[onUserCreated] User ${uid} already received welcome email; skipping.`);
      return;
    }

    // 🔒 Phase Capacity Enforcement: Cap registrations when active phase limit is reached
    const limits = await getDynamicPlatformLimits();
    const usersCountSnap = await firestore.collection("users").count().get();
    const totalUsers = usersCountSnap.data().count;
    if (totalUsers > limits.MAX_STANDARD_USERS) {
      await userRef.set(
        {
          accountStatus: "waitlisted",
          isWaitlisted: true,
          waitlistReason: `Phase ${limits.CURRENT_PHASE} user capacity (${limits.MAX_STANDARD_USERS.toLocaleString()}) reached.`,
          waitlistPosition: totalUsers,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      logger.warn(
        `[onUserCreated] User ${uid} registered after Phase ${limits.CURRENT_PHASE} capacity limit reached (${totalUsers}/${limits.MAX_STANDARD_USERS} users). Account marked as waitlisted.`
      );
      return;
    }

    // 2. Dispatch Welcome Email via EmailService (Google SMTP)
    const result = await EmailService.sendWelcomeEmail({
      to: email,
      displayName,
    });

    if (result.success) {
      // 3. Mark idempotency flag in Firestore
      await userRef.set(
        {
          welcomeEmailSent: true,
          welcomeEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
          welcomeEmailMessageId: result.messageId || null,
        },
        { merge: true }
      );
      logger.info(`[onUserCreated] Successfully sent welcome email to ${email} for user ${uid}.`);
    } else if (result.skipped) {
      logger.info(`[onUserCreated] Welcome email skipped for user ${uid} (${result.error}).`);
    } else {
      logger.warn(`[onUserCreated] Welcome email could not be delivered to ${email}: ${result.error}`);
    }
  } catch (error) {
    // Non-fatal: Log error so Cloud Function does not crash the lifecycle pipeline
    logger.error(`[onUserCreated] Unexpected error sending welcome email for ${uid}:`, error);
  }
});

/**
 * ⚡ ON USER DELETED (Auth Trigger)
 * Automatically triggers when any user account is permanently deleted in Firebase Auth.
 */
export const onUserDeleted = region("asia-south1").auth.user().onDelete(async (user: UserRecord) => {
  logger.info(`[onUserDeleted] Triggered for user: ${user.uid} (${user.email || "no-email"})`);
  await purgeAllUserData(user.uid);
});

/**
 * 🗑️ PURGE USER ACCOUNT (HTTP Endpoint)
 * Can be invoked by authenticated users to purge their own account data,
 * or by system administrators to purge any user account data (including orphaned users).
 */
export const purgeUserAccount = onRequest(
  {
    cors: true,
    region: "asia-south1",
    minInstances: 0,
    maxInstances: 5,
  },
  async (req, res) => {
    applySecurityHeaders(res);
    setCorsHeaders(req, res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const user = await verifyAuth(req);
      if (!user) {
        res.status(401).json({ error: "Unauthorized. Bearer token required." });
        return;
      }

      const targetUid = req.body?.userId || req.query?.userId || user.uid;
      if (!targetUid || typeof targetUid !== "string") {
        res.status(400).json({ error: "Missing userId" });
        return;
      }

      if (user.uid !== targetUid && !user.isAdmin) {
        res.status(403).json({ error: "Forbidden: insufficient permissions" });
        return;
      }

      // Step-up authentication and verified email required for admin purging another user
      if (user.uid !== targetUid && user.isAdmin) {
        if (!user.emailVerified) {
          res.status(403).json({ error: "Forbidden: verified email required for administrative actions." });
          return;
        }
        if (!user.authTime || !isSessionRecent(user.authTime, 3600)) {
          res.status(403).json({
            error: "Step-up authentication required. Please re-authenticate to purge another user's data.",
            code: "AUTH_STEP_UP_REQUIRED",
          });
          return;
        }
      }

      // Prohibit purging administrative accounts
      const targetUserDoc = await admin.firestore().collection("users").doc(targetUid).get();
      if (targetUserDoc.exists) {
        const targetData = targetUserDoc.data();
        if (targetData?.role === "admin" || targetData?.role === "superadmin" || targetData?.isAdmin === true) {
          res.status(403).json({
            error: "Administrative accounts cannot be deleted or purged via this endpoint.",
          });
          return;
        }
      }

      logger.info(`[purgeUserAccount] Initiated purge for UID: ${targetUid} by ${user.uid} (isAdmin: ${user.isAdmin})`);
      const result = await purgeAllUserData(targetUid);
      res.status(200).json({ ...result });
    } catch (error) {
      logger.error("[purgeUserAccount] Error:", error);
      res.status(500).json({ error: "Unable to complete account purge. Please try again." });
    }
  }
);

/**
 * 🔒 CHECK USER REGISTRATION CAPACITY
 * Allows clients to query whether registration in current phase is open or waitlisted.
 */
export const checkUserRegistrationCapacity = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 20,
  },
  async () => {
    const limits = await getDynamicPlatformLimits();
    const usersSnap = await db().collection("users").count().get();
    const count = usersSnap.data().count;
    const isCapped = count >= limits.MAX_STANDARD_USERS;
    return {
      phase: limits.CURRENT_PHASE,
      phaseName: limits.PHASE_NAME,
      allowed: !isCapped,
      currentUsers: count,
      maxUsers: limits.MAX_STANDARD_USERS,
      isWaitlisted: isCapped,
      remainingSlots: Math.max(0, limits.MAX_STANDARD_USERS - count),
    };
  }
);

