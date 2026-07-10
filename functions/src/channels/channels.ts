import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { Channel, ChannelType } from "../pipeline/types";

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
 * Atomic creation of a channel with the new economic model.
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
    const defaultPlatform = data.defaultPlatform || "youtube";
    const category = data.category || "other";

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
        const userData = userSnap.exists ? userSnap.data() as any : { channelsCount: 0 };
        const currentCount = userData.channelsCount || 0;

        // Standard limit: one channel per user
        const maxChannels = 1;
        const maxDuration = 10800; // 3 hr

        if (currentCount >= maxChannels) {
          throw new HttpsError("failed-precondition", "Only one channel per user is allowed in the basic tier. Upgrade to create more.");
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
        const channelType = data.type || 'standard';
        
        // Revenue shares based on type
        const adsRevShare = channelType === 'custom' ? 1.0 : 0.75;
        const memberRevShare = channelType === 'custom' ? 0.75 : 1.0;

                const channelDoc: any = {
          id: channelId,
          ownerId: userId,
          handle: normalizedSlug,
          displayName: name.trim(),
          about: description || "",
          type: channelType, 
          outstandingCosts: 0,
          hasPaidSubscriptionBuyout: false,
          createdAt: now,
          updatedAt: now,
          status: "underReview",
          moderationReason: "",
          profile: {
            photoUrl: avatarUrl || "",
            coverUrl: bannerUrl || "",
            category: category || "other",
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
            maxDurationSec: maxDuration,
            maxChannels: maxChannels,
          }
        };

        tx.set(channelRef, channelDoc);
        tx.set(slugRef, { channelId, ownerId: userId, createdAt: now });
        
        if (!userSnap.exists) {
          tx.set(userRef, { 
            channelsCount: 1,
            createdAt: now,
            updatedAt: now
          });
        } else {
          tx.set(userRef, { 
            channelsCount: admin.firestore.FieldValue.increment(1),
            updatedAt: now
          }, { merge: true });
        }

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
          };
        } else {
          update.settings = {
            ...channel.settings,
            adsRevenueShare: 0.75, // Standard share
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
