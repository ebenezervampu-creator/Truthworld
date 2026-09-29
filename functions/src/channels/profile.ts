import * as admin from "firebase-admin";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { 
  ChannelV2, 
  validateProfile, 
  defaultProfile, 
  defaultReputation 
} from "./types";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { isCallableRecentAdmin } from "../utils/auth";

const db = () => admin.firestore();

// ─── Cloud Functions ──────────────────────────────────────────────────────────

/**
 * 🛠️ UPDATE CHANNEL PROFILE (Callable)
 * Allows owners to update their channel bio, links, and category.
 * Backfills missing V2 fields on write.
 */
export const updateChannelProfile = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    const { channelId, profile } = request.data;
    if (!channelId || !profile) throw new HttpsError("invalid-argument", "Missing data.");

    const err = validateProfile(profile);
    if (err) throw new HttpsError("invalid-argument", err);

    const channelRef = db().collection("channels").doc(channelId);
    
    try {
      return await db().runTransaction(async (tx) => {
        const snap = await tx.get(channelRef);
        if (!snap.exists) throw new HttpsError("not-found", "Channel not found.");
        
        const data = snap.data() as any;
        if (data.ownerId !== userId) {
          throw new HttpsError("permission-denied", "You do not own this channel.");
        }

        // Merge Phase 2 defaults if missing (Backfill)
        const updatedDoc = {
          ...data,
          profile: {
            ...(data.profile || defaultProfile()),
            ...profile,
          },
          reputation: data.reputation || defaultReputation(),
          verification: data.verification || "unverified",
          updatedAt: Date.now(),
        };

        tx.update(channelRef, updatedDoc);
        return { success: true, channelId };
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[updateChannelProfile] Error:", err);
      throw new HttpsError("internal", "Update failed.");
    }
  }
);

/**
 * 🌍 GET PUBLIC CHANNEL PROFILE (HTTPS)
 * Powers the public /@slug URL.
 * Resolves slug -> channelId, strips private fields.
 */
export const getPublicChannelProfile = onRequest(
  { region: "asia-south1", cors: true, memory: "256MiB" },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const slug = (req.query.slug as string)?.toLowerCase();
      if (!slug) {
        res.status(400).json({ error: "Missing slug" });
        return;
      }

      // 1. Resolve slug
      const slugSnap = await db().collection("channel_slugs").doc(slug).get();
      if (!slugSnap.exists) {
        res.status(404).json({ error: "Channel not found" });
        return;
      }

      const { channelId } = slugSnap.data() as { channelId: string };

      // 2. Fetch channel
      const channelSnap = await db().collection("channels").doc(channelId).get();
      if (!channelSnap.exists) {
        res.status(404).json({ error: "Channel document missing" });
        return;
      }

      const data = channelSnap.data() as ChannelV2;
      const status = (data as any).status;

      if (status === "suspended" || status === "banned" || status === "deleted") {
        res.status(403).json({ error: "This channel has been suspended or is unavailable." });
        return;
      }

      // 3. Strip private fields & prepare public response
      const publicProfile = {
        id: data.id,
        slug: data.handle,
        name: data.displayName,
        description: data.about,
        type: data.type,
        createdAt: data.createdAt,
        profile: data.profile || defaultProfile(),
        reputation: data.reputation || defaultReputation(),
        verification: data.verification || "unverified",
        stats: {
          videosCount: data.stats.videoCount,
          avgTrustIndex: data.stats.avgTrustIndex,
          subscribers: data.stats.subscriberCount,
          views: data.stats.viewCount,
        }
      };

      res.status(200).json(publicProfile);
    } catch (err) {
      logger.error("[getPublicChannelProfile] Error:", err);
      res.status(500).json({ error: "Internal error" });
    }
  }
);

/**
 * ⚡ MIGRATE CHANNELS TO V2 (Callable / Admin Only)
 * Batch migrates existing channels to include Phase 2 fields.
 */
export const migrateChannelsToV2 = onCall(
  { region: "asia-south1", memory: "512MiB" },
  async (request) => {
    const callerUid = request.auth?.uid;
    const isAdmin = isCallableRecentAdmin(request.auth, 3600);
    if (!callerUid || !isAdmin) {
      throw new HttpsError("permission-denied", "Only platform administrators with recent authentication can perform batch migrations.");
    }
    const isDryRun = request.data?.dryRun !== false;

    const snap = await db().collection("channels").get();
    const batch = db().batch();
    let count = 0;

    snap.forEach((doc) => {
      const data = doc.data() as any;
      if (!data.profile || !data.reputation) {
        const updates = {
          profile: data.profile || defaultProfile(),
          reputation: data.reputation || defaultReputation(),
          verification: data.verification || "unverified",
          updatedAt: Date.now(),
        };
        if (!isDryRun) batch.update(doc.ref, updates);
        count++;
      }
    });

    if (!isDryRun && count > 0) await batch.commit();

    return { 
      status: isDryRun ? "Dry run complete" : "Migration complete", 
      migratedCount: count,
      totalCount: snap.size
    };
  }
);
