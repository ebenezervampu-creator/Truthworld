import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import { Channel, ChannelType } from "../pipeline/types";
import { EmailService } from "../services/emailService";
import { getDynamicPlatformLimits } from "../config/platformLimits";
import { normalizeLanguageCode } from "../shared/language-normalizer";

const db = () => admin.firestore();

// ─── Constants ────────────────────────────────────────────────────────────────

const RATE_LIMIT_COLLECTION = "channel_creation_rate_limits";
const CHANNELS_COLLECTION = "channels";
const USERS_COLLECTION = "users";
const SLUGS_COLLECTION = "channel_slugs";

const FORBIDDEN_NAMES = [
  "admin", "truthworld", "official", "support", "help",
  "moderator", "staff", "verify", "verified"
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function validateName(name: string): string | null {
  if (!name || name.trim().length < 3 || name.trim().length > 50) {
    return "Channel name must be between 3 and 50 characters.";
  }
  const lower = name.toLowerCase();
  if (FORBIDDEN_NAMES.some(f => lower.includes(f))) {
    return "This channel name is reserved or contains forbidden words.";
  }
  return null;
}

function validateSlug(slug: string): string | null {
  if (!slug) return "Slug is required.";
  if (!slug.startsWith("@")) return "Slug must start with '@'.";
  const content = slug.slice(1);
  if (!/^[a-zA-Z0-9_-]{3,30}$/.test(content)) {
    return "Slug must be 3-30 alphanumeric characters (underscores and hyphens allowed).";
  }
  return null;
}

async function checkRateLimit(userId: string): Promise<void> {
  const now = Date.now();
  const docId = `${userId}_hourly`;
  const ref = db().collection(RATE_LIMIT_COLLECTION).doc(docId);

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, { userId, count: 1, resetAt: now + 3600 * 1000 });
      return;
    }
    const data = snap.data() as any;
    if (now > data.resetAt) {
      tx.set(ref, { userId, count: 1, resetAt: now + 3600 * 1000 });
      return;
    }
    if (data.count >= 5) {
      throw new HttpsError("resource-exhausted", "Rate limit exceeded (5 channels/hour).");
    }
    tx.update(ref, { count: data.count + 1 });
  });
}

/**
 * 🚀 CREATE CHANNEL (Callable)
 * Atomic creation of a channel enforcing strictly ONE channel per Google account.
 */
export const createChannel = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    let data = request.data || {};
    if (data && typeof data === 'object' && 'data' in data) {
      data = (data as any).data;
    }
    
    let displayName = data.displayName || data.name || data.channelName;
    let handle = data.handle || data.slug || data.customUrl;
    let about = data.about || data.description || data.bio;
    let photoUrl = data.photoUrl || data.avatarUrl;
    let coverUrl = data.coverUrl || data.bannerUrl || data.bannerImageUrl;
    
    const locale = data.locale || "en";
    const rawLanguage = data.language || data.channelLanguage || locale;
    const normalizedLocale = normalizeLanguageCode(locale);
    const normalizedLanguage = normalizeLanguageCode(rawLanguage);

    // 🔒 Language Policy Enforcement: Truthworld is accepting only English channels as of now
    if (normalizedLocale !== "en" || normalizedLanguage !== "en") {
      throw new HttpsError(
        "failed-precondition",
        "Truthworld is accepting only English channels as of now. All other world languages are invite-only at this stage."
      );
    }

    const defaultPlatform = data.defaultPlatform || "youtube";
    const category = data.category || "other";
    const rawCategories = data.categories || data.category;
    let categoriesList: string[] = [];
    if (Array.isArray(rawCategories)) {
      categoriesList = rawCategories.map((c: any) => String(c).trim()).filter(Boolean);
    } else if (typeof rawCategories === "string" && rawCategories.trim()) {
      categoriesList = rawCategories.split(",").map((c) => c.trim()).filter(Boolean);
    }
    if (categoriesList.length === 0) {
      categoriesList = [category];
    }

    let name = displayName || "";
    let slug = handle || "";
    let description = about || "";
    let avatarUrl = photoUrl || "";
    let bannerUrl = coverUrl || "";

    const nameErr = validateName(name);
    if (nameErr) throw new HttpsError("invalid-argument", nameErr);

    if (slug && !slug.startsWith("@")) {
      slug = `@${slug}`;
    }

    const slugErr = validateSlug(slug);
    if (slugErr) throw new HttpsError("invalid-argument", slugErr);

    if (!name || !slug) {
      throw new HttpsError("invalid-argument", "Name and slug are required.");
    }

    try {
      await checkRateLimit(userId);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[createChannel] Rate limit check failed:", err);
      throw new HttpsError("internal", "Failed to check rate limits.");
    }

    try {
      const result = await db().runTransaction(async (tx) => {
        const userRef = db().collection(USERS_COLLECTION).doc(userId);
        const userSnap = await tx.get(userRef);
        const userData = userSnap.exists ? (userSnap.data() as any) : {};
        const currentCount = userData.channelsCount || 0;

        // Strict Enforcement: Strictly ONE channel per Google account in Truthworld
        if (currentCount >= 1 || userData.channelId || userData.hasChannel === true) {
          throw new HttpsError(
            "failed-precondition",
            "Only one channel per Google account is allowed in Truthworld. You already have an active channel."
          );
        }

        // Query channels collection inside transaction to prevent race condition duplicates
        const existingByOwner = await tx.get(
          db().collection(CHANNELS_COLLECTION).where("ownerId", "==", userId).limit(1)
        );
        if (!existingByOwner.empty) {
          const chData = existingByOwner.docs[0].data();
          if (chData.status !== "deleted") {
            throw new HttpsError(
              "failed-precondition",
              "Only one channel per Google account is allowed in Truthworld. You already have an active channel."
            );
          }
        }

        const normalizedSlug = slug.toLowerCase();
        const slugRef = db().collection(SLUGS_COLLECTION).doc(normalizedSlug);
        const slugSnap = await tx.get(slugRef);
        if (slugSnap.exists) {
          throw new HttpsError("already-exists", "This slug is already taken.");
        }

        const channelId = db().collection(CHANNELS_COLLECTION).doc().id;
        const channelRef = db().collection(CHANNELS_COLLECTION).doc(channelId);

        const now = Date.now();
        const rawType = data.channelType || data.type || 'standard';
        const channelType: ChannelType = rawType === 'custom' ? 'custom' : 'standard';

        // 🔒 Phase Capacity Enforcement:
        // - Standard channels: Strictly capped at MAX_STANDARD_CHANNELS
        // - Custom channels: ZERO RESTRICTION (Unlimited)
        if (channelType === 'standard') {
          const limits = await getDynamicPlatformLimits();
          const [allChannelsSnap, customChannelsSnap] = await Promise.all([
            db().collection(CHANNELS_COLLECTION).where("status", "!=", "deleted").count().get(),
            db().collection(CHANNELS_COLLECTION).where("channelType", "==", "custom").where("status", "!=", "deleted").count().get(),
          ]);
          const totalActive = allChannelsSnap.data().count;
          const totalCustom = customChannelsSnap.data().count;
          const activeStandardCount = Math.max(0, totalActive - totalCustom);

          if (activeStandardCount >= limits.MAX_STANDARD_CHANNELS) {
            throw new HttpsError(
              "resource-exhausted",
              `Phase ${limits.CURRENT_PHASE} standard channel capacity (${limits.MAX_STANDARD_CHANNELS}) has been reached. Custom channels have no restriction and can be created immediately, or you can apply for the standard creator waitlist.`
            );
          }
        }
        
        // Unified Revenue shares based on channel type:
        // - Standard: 70% Creator on Ads & Premium Subs (30% Platform), 100% on Memberships & Superchats (0% Platform).
        // - Custom: 100% Creator on all streams (0% Platform cut). Custom channels take plans ($15, $30, $45/mo etc.).
        const adsRevShare = channelType === 'custom' ? 1.0 : 0.70;
        const memberRevShare = 1.0;


        const channelDoc: any = {
          id: channelId,
          ownerId: userId,
          userId: userId,
          handle: normalizedSlug,
          displayName: name.trim(),
          name: name.trim(),
          channelName: name.trim(),
          about: description || "",
          description: description || "",
          type: channelType, 
          language: "en",
          outstandingCosts: 0,
          hasPaidSubscriptionBuyout: false,
          createdAt: now,
          updatedAt: now,
          status: "underReview",
          moderationReason: "",
          category: categoriesList.join(", "),
          categories: categoriesList,
          avatarUrl: avatarUrl || "",
          bannerUrl: bannerUrl || "",
          profile: {
            photoUrl: avatarUrl || "",
            coverUrl: bannerUrl || "",
            category: categoriesList[0] || "other",
            categories: categoriesList,
            about: description || "",
            links: {},
          },
          stats: {
            videoCount: 0,
            avgTrustIndex: 0,
            subscriberCount: 0,
            viewCount: 0,
          },
          settings: {
            adsEnabled: true,
            adsRevenueShare: adsRevShare,
            memberRevenueShare: memberRevShare,
            locale,
            defaultPlatform,
          },
          limits: {
            maxDurationSec: channelType === "custom" ? 86400 : 600,
            maxChannels: 1,
          }
        };

        tx.set(channelRef, channelDoc);
        tx.set(slugRef, { channelId, ownerId: userId, createdAt: now });
        
        tx.set(userRef, { 
          channelId: channelId,
          hasChannel: true,
          channelsCount: 1,
          updatedAt: now
        }, { merge: true });

        return { channelId, handle: channelDoc.handle };
      });

      return result;
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[createChannel] Transaction failed:", err);
      throw new HttpsError("internal", "Failed to create channel.");
    }
  }
);

/**
 * 🔄 SWITCH CHANNEL TYPE
 * Handles transition between Standard and Custom economic models.
 */
export const switchChannelType = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "User must be logged in.");

    const { channelId, targetType } = request.data;
    if (!channelId || !['standard', 'custom'].includes(targetType)) {
      throw new HttpsError("invalid-argument", "Invalid parameters.");
    }

    try {
      return await db().runTransaction(async (tx) => {
        const channelRef = db().collection(CHANNELS_COLLECTION).doc(channelId);
        const snap = await tx.get(channelRef);
        if (!snap.exists) throw new HttpsError("not-found", "Channel not found.");
        
        const channel = snap.data() as Channel;
        if (channel.ownerId !== userId) throw new HttpsError("permission-denied", "Not owner.");

        if (channel.type === targetType) return { success: true, message: "Already that type." };

        // Logic for Custom -> Standard
        if (channel.type === 'custom' && targetType === 'standard') {
          if (channel.outstandingCosts > 0) {
            throw new HttpsError("failed-precondition", `Please settle outstanding costs ($${channel.outstandingCosts.toFixed(2)}) first.`);
          }
        }

        const update: Partial<Channel> = {
          type: targetType as ChannelType,
          updatedAt: Date.now(),
        };

        if (targetType === 'custom') {
          update.settings = {
            ...channel.settings,
            adsRevenueShare: 1.0, // Custom channels keep 100% ads
            memberRevenueShare: 1.0, // Custom channels keep 100% memberships
          };
          update.limits = {
            ...channel.limits,
            maxDurationSec: 86400,
            maxChannels: 1,
          };
        } else {
          update.settings = {
            ...channel.settings,
            adsRevenueShare: 0.70, // Standard share (30% platform fee)
            memberRevenueShare: 1.0, // Standard channels keep 100% memberships
          };
          update.limits = {
            ...channel.limits,
            maxDurationSec: 600, // Standard channels capped at 10 minutes (600s)
            maxChannels: 1,
          };
        }


        tx.update(channelRef, update);
        return { success: true, newType: targetType };
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "Failed to switch type.");
    }
  }
);

/**
 * 📧 DISPATCH CHANNEL WELCOME EMAIL
 * Dispatches a branded HTML welcome email to the channel creator via native Google/Gmail SMTP,
 * guarded by Firestore idempotency to prevent duplicate emails on retries.
 */
export async function dispatchChannelWelcomeEmail(
  channelId: string,
  channelData: any
): Promise<{ success: boolean; skipped?: boolean; error?: string; messageId?: string } | null> {
  if (!channelData || channelData.status === "deleted") {
    return null;
  }

  // Idempotency: Skip if already marked sent in data
  if (channelData.welcomeEmailSent === true) {
    logger.info(`[dispatchChannelWelcomeEmail] Channel ${channelId} already received welcome email; skipping.`);
    return { success: true, skipped: true };
  }

  const channelRef = db().collection(CHANNELS_COLLECTION).doc(channelId);

  // 1. Double check current document in Firestore for idempotency
  const channelSnap = await channelRef.get().catch(() => null);
  if (channelSnap?.exists && channelSnap.data()?.welcomeEmailSent === true) {
    logger.info(`[dispatchChannelWelcomeEmail] Channel ${channelId} already received welcome email in Firestore; skipping.`);
    return { success: true, skipped: true };
  }

  // 2. Resolve recipient email and creator details
  const ownerId = channelData.ownerId || channelData.userId;
  let targetEmail: string | null = null;
  let resolvedOwnerName: string | null = null;

  // Priority 1: Check contactEmail on channel doc if valid
  if (
    channelData.contactEmail &&
    typeof channelData.contactEmail === "string" &&
    channelData.contactEmail.includes("@")
  ) {
    targetEmail = channelData.contactEmail.trim();
  }

  // Priority 2: Query Firestore users collection
  if (ownerId) {
    try {
      const userSnap = await db().collection(USERS_COLLECTION).doc(ownerId).get();
      if (userSnap.exists) {
        const userData = userSnap.data();
        if (
          !targetEmail &&
          userData?.email &&
          typeof userData.email === "string" &&
          userData.email.includes("@")
        ) {
          targetEmail = userData.email.trim();
        }
        resolvedOwnerName = userData?.displayName || userData?.name || null;
      }
    } catch (userErr) {
      logger.debug(`[dispatchChannelWelcomeEmail] Could not query user doc for ${ownerId}:`, userErr);
    }
  }

  // Priority 3: Fallback to Firebase Auth user record
  if (!targetEmail && ownerId) {
    try {
      const authUser = await admin.auth().getUser(ownerId);
      if (authUser?.email && authUser.email.includes("@")) {
        targetEmail = authUser.email.trim();
      }
      if (!resolvedOwnerName && authUser?.displayName) {
        resolvedOwnerName = authUser.displayName;
      }
    } catch (authErr) {
      logger.debug(`[dispatchChannelWelcomeEmail] Could not query auth record for ${ownerId}:`, authErr);
    }
  }

  if (!targetEmail) {
    logger.info(
      `[dispatchChannelWelcomeEmail] Channel ${channelId} (owner: ${ownerId}) has no valid email; welcome email skipped.`
    );
    return { success: false, skipped: true, error: "No recipient email found" };
  }

  const channelName =
    channelData.channelName ||
    channelData.displayName ||
    channelData.name ||
    "TruthWorld Creator";
  const handle = channelData.handle || channelData.customUrl || channelData.slug || null;

  // 3. Dispatch Channel Welcome Email via EmailService
  const result = await EmailService.sendChannelWelcomeEmail({
    to: targetEmail,
    channelName,
    ownerDisplayName: resolvedOwnerName,
    handle,
  });

  if (result.success) {
    // 4. Mark idempotency flag in Firestore channel doc
    await channelRef.set(
      {
        welcomeEmailSent: true,
        welcomeEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        welcomeEmailMessageId: result.messageId || null,
        welcomeEmailRecipient: targetEmail,
      },
      { merge: true }
    );
    logger.info(
      `[dispatchChannelWelcomeEmail] Successfully sent welcome email to ${targetEmail} for channel ${channelId}.`
    );
  } else if (result.skipped) {
    logger.info(
      `[dispatchChannelWelcomeEmail] Channel welcome email skipped for channel ${channelId} (${result.error}).`
    );
  } else {
    logger.warn(
      `[dispatchChannelWelcomeEmail] Channel welcome email could not be delivered to ${targetEmail}: ${result.error}`
    );
  }

  return result;
}

/**
 * 🔒 ON CHANNEL WRITTEN SYNC USER (Firestore Trigger)
 * Automatically keeps user document in sync and enforces the strict 1-channel rule in Firestore.
 * Also dispatches a branded HTML welcome email via native Google/Gmail SMTP when a new channel is created,
 * guarded by Firestore idempotency to prevent duplicate emails on retries.
 */
export const onChannelCreatedSyncUser = onDocumentWritten(
  {
    document: "channels/{channelId}",
    region: "asia-south1",
    retry: false,
    maxInstances: 5,
    secrets: ["SMTP_USER", "SMTP_PASS"],
  },
  async (event) => {
    const channelId = event.params.channelId;
    const afterData = event.data?.after.data();

    if (!afterData) {
      // Channel was deleted
      const beforeData = event.data?.before.data();
      const ownerId = beforeData?.ownerId || beforeData?.userId;
      if (ownerId) {
        const remainingChannels = await db()
          .collection(CHANNELS_COLLECTION)
          .where("ownerId", "==", ownerId)
          .get();

        const activeChannels = remainingChannels.docs
          .filter((d) => d.id !== channelId && d.data().status !== "deleted");

        if (activeChannels.length === 0) {
          await db().collection(USERS_COLLECTION).doc(ownerId).set(
            {
              hasChannel: false,
              channelId: null,
              channelsCount: 0,
              updatedAt: Date.now(),
            },
            { merge: true }
          );
        } else {
          await db().collection(USERS_COLLECTION).doc(ownerId).set(
            {
              hasChannel: true,
              channelId: activeChannels[0].id,
              channelsCount: activeChannels.length,
              updatedAt: Date.now(),
            },
            { merge: true }
          );
        }
      }
      return;
    }

    const ownerId = afterData.ownerId || afterData.userId;
    if (!ownerId) return;

    const isDeleted = afterData.status === "deleted";

    if (!isDeleted) {
      // Strict 1-Channel Check: verify whether user already has another active channel
      const allUserChannels = await db()
        .collection(CHANNELS_COLLECTION)
        .where("ownerId", "==", ownerId)
        .get();

      const activeChannels = allUserChannels.docs.filter(
        (d) => d.data().status !== "deleted"
      );

      // If more than 1 active channel is detected for this Google account, mark duplicate as deleted
      if (activeChannels.length > 1) {
        // Sort by createdAt ascending to preserve the original channel
        activeChannels.sort(
          (a, b) => (a.data().createdAt || 0) - (b.data().createdAt || 0)
        );
        const originalChannel = activeChannels[0];

        if (channelId !== originalChannel.id) {
          logger.warn(
            `[onChannelCreatedSyncUser] Duplicate channel detected (${channelId}) for user ${ownerId}. Marking as duplicate/deleted.`
          );
          await db().collection(CHANNELS_COLLECTION).doc(channelId).update({
            status: "deleted",
            moderationReason: "Strict rule violation: Only one channel per Google account is allowed.",
            updatedAt: Date.now(),
          });
          return;
        }
      }

      // Sync primary user doc
      await db().collection(USERS_COLLECTION).doc(ownerId).set(
        {
          channelId: channelId,
          hasChannel: true,
          channelsCount: 1,
          updatedAt: Date.now(),
        },
        { merge: true }
      );

      // ─── Welcome Email for New Channel ─────────────────────────────────────
      // Exactly like onUserCreated for new users:
      // Dispatches branded HTML welcome email via native Google/Gmail SMTP,
      // guarded by Firestore idempotency to prevent duplicate emails on retries.
      if (afterData.welcomeEmailSent !== true) {
        try {
          await dispatchChannelWelcomeEmail(channelId, afterData);
        } catch (emailErr) {
          // Non-fatal: Log error so Cloud Function does not crash lifecycle pipeline
          logger.error(
            `[onChannelCreatedSyncUser] Unexpected error sending welcome email for channel ${channelId}:`,
            emailErr
          );
        }
      }
    }
  }
);

/**
 * 🧹 30-DAY CHANNEL DELETION GRACE PERIOD PURGE SCHEDULER
 *
 * Runs daily to permanently delete channels whose 30-day grace period has expired.
 * Permanently deletes video files and docs, storage assets, handles, channel subcollections,
 * and clears user document channel associations.
 */
export const cleanupExpiredDeletedChannelsScheduled = onSchedule(
  {
    schedule: "0 2 * * *", // Daily at 02:00 UTC (07:30 IST)
    region: "asia-south1",
    memory: "512MiB",
    timeoutSeconds: 300,
    minInstances: 0,
    maxInstances: 1,
  },
  async () => {
    logger.info("[ChannelCleanup] Checking for channels with expired 30-day deletion grace period...");
    const thirtyDaysAgoMs = Date.now() - 30 * 24 * 60 * 60 * 1000;

    const snapshot = await db()
      .collection(CHANNELS_COLLECTION)
      .where("status", "==", "deleted")
      .limit(50)
      .get();

    if (snapshot.empty) {
      logger.info("[ChannelCleanup] No deleted channels found.");
      return;
    }

    const bucket = admin.storage().bucket();
    let purgedCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const expiry = data.deletionGracePeriodExpiresAt;
      const scheduled = data.deletionScheduledAt || data.updatedAt;

      const isExpired =
        (expiry && expiry.toMillis && expiry.toMillis() <= Date.now()) ||
        (scheduled && scheduled.toMillis && scheduled.toMillis() <= thirtyDaysAgoMs);

      if (!isExpired) {
        continue;
      }

      const channelId = doc.id;
      const ownerId = data.ownerId || data.userId;
      logger.info(`[ChannelCleanup] 30-day grace period expired for channel ${channelId}. Permanently purging all assets...`);

      // 1. Purge channel videos from storage and Firestore
      const videosSnap = await db()
        .collection("videos")
        .where("channelId", "==", channelId)
        .get()
        .catch(() => ({ docs: [] } as any));

      for (const vDoc of videosSnap.docs) {
        await bucket.deleteFiles({ prefix: `videos/${vDoc.id}/` }).catch(() => {});
        await db().recursiveDelete(vDoc.ref).catch((e) => {
          logger.warn(`[ChannelCleanup] Error recursive deleting video ${vDoc.id}:`, e);
        });
      }

      // 2. Purge channel storage assets (avatars, banners)
      await bucket.deleteFiles({ prefix: `channels/${channelId}/` }).catch(() => {});

      // 3. Purge channel handle reservation
      if (data.handle) {
        const handleDoc = await db().collection("channel_handles").doc(data.handle.toLowerCase()).get().catch(() => null);
        if (handleDoc && handleDoc.exists) {
          await handleDoc.ref.delete().catch(() => {});
        }
      }

      // 4. Recursive delete channel document and subcollections
      await db().recursiveDelete(doc.ref).catch((e) => {
        logger.warn(`[ChannelCleanup] Error recursive deleting channel ${channelId}:`, e);
      });

      // 5. Update owner user doc to clear channel references permanently
      if (ownerId) {
        await db().collection(USERS_COLLECTION).doc(ownerId).set(
          {
            hasChannel: false,
            channelId: null,
            deletedChannelId: null,
            channelsCount: 0,
            updatedAt: Date.now(),
          },
          { merge: true }
        ).catch(() => {});
      }

      purgedCount++;
    }

    logger.info(`[ChannelCleanup] Completed grace period purge: ${purgedCount} expired channels permanently deleted.`);
  }
);

/**
 * 📊 GET PLATFORM CAPACITY STATUS
 * Returns real-time capacity and quota headroom for the active platform phase.
 */
export const getPlatformCapacity = onCall(
  {
    region: "asia-south1",
    memory: "256MiB",
    maxInstances: 20,
  },
  async () => {
    const limits = await getDynamicPlatformLimits();
    const [usersSnap, allChannelsSnap, customChannelsSnap] = await Promise.all([
      db().collection(USERS_COLLECTION).count().get(),
      db().collection(CHANNELS_COLLECTION).where("status", "!=", "deleted").count().get(),
      db().collection(CHANNELS_COLLECTION).where("channelType", "==", "custom").where("status", "!=", "deleted").count().get(),
    ]);

    const totalUsers = usersSnap.data().count;
    const totalActiveChannels = allChannelsSnap.data().count;
    const customChannels = customChannelsSnap.data().count;
    const standardChannels = Math.max(0, totalActiveChannels - customChannels);

    return {
      phase: limits.CURRENT_PHASE,
      phaseName: limits.PHASE_NAME,
      users: {
        current: totalUsers,
        limit: limits.MAX_STANDARD_USERS,
        isCapped: totalUsers >= limits.MAX_STANDARD_USERS,
        remainingSlots: Math.max(0, limits.MAX_STANDARD_USERS - totalUsers),
      },
      standardChannels: {
        current: standardChannels,
        limit: limits.MAX_STANDARD_CHANNELS,
        isCapped: standardChannels >= limits.MAX_STANDARD_CHANNELS,
        remainingSlots: Math.max(0, limits.MAX_STANDARD_CHANNELS - standardChannels),
      },
      customChannels: {
        current: customChannels,
        isUnlimited: true,
      },
    };
  }
);

