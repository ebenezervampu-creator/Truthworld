import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = admin.firestore();

/**
 * ⚡ TRACK ACTIVITY (Callable)
 * Records implicit signals (clicks, views, follows) to refine interest mapping.
 * This powers the 'For You' personalized feed.
 *
 * Enhanced with:
 * - Topic-level interest tracking (topic:{slug} keys)
 * - Negative signal tracking (skip, earlyExit, dislike)
 * - Channel-level tracking (lastWatchedChannels)
 * - Search query tracking
 * - Session continuation awareness
 */
export const trackActivity = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) return { success: false, reason: "Unauthenticated" };

    const rawEvents = Array.isArray(request.data.events) ? request.data.events : [request.data];
    if (rawEvents.length === 0) {
      return { success: false, reason: "Empty events payload" };
    }

    const userRef = db.collection("users").doc(userId);
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(userRef);
        const data = snap.exists ? (snap.data() as any) : {};
        const interests = data.interests || {};
        const updates: Record<string, any> = { lastActiveAt: Date.now() };

        for (const evt of rawEvents) {
          const { category, type, durationSec, topicSlug, channelId, searchQuery, videoId } = evt;

          let weight = 0.05;
          if (type === "follow") weight = 0.50;
          if (type === "view" && (durationSec || 0) > 60) weight = 0.20;
          if (type === "view" && (durationSec || 0) > 20) weight = 0.10;
          if (type === "like") weight = 0.15;
          if (type === "subscribe") weight = 0.40;
          if (type === "search") weight = 0.08;

          if (type === "skip") weight = -0.05;
          if (type === "earlyExit") weight = -0.10;
          if (type === "dislike") weight = -0.15;
          if (type === "notInterested") weight = -0.30;

          if (category) {
            const current = interests[category] || 0;
            interests[category] = Math.max(0, Math.min(current + weight, 1.0));
            for (const cat in interests) {
              if (cat !== category && !cat.startsWith("topic:")) {
                interests[cat] = Math.max(interests[cat] * 0.98, 0);
              }
            }
          }

          if (topicSlug && weight > 0) {
            const topicKey = `topic:${topicSlug}`;
            const currentTopic = interests[topicKey] || 0;
            interests[topicKey] = Math.min(currentTopic + weight, 1.0);
            for (const key in interests) {
              if (key.startsWith("topic:") && key !== topicKey) {
                interests[key] = Math.max(interests[key] * 0.98, 0);
              }
            }
          }

          if (channelId && (type === "view" || type === "subscribe")) {
            const lastChannels: string[] = updates.lastWatchedChannels || data.lastWatchedChannels || [];
            const filtered = lastChannels.filter((c: string) => c !== channelId);
            filtered.unshift(channelId);
            updates.lastWatchedChannels = filtered.slice(0, 20);
          }

          if (topicSlug && (type === "view" || type === "follow")) {
            const lastTopics: string[] = updates.lastWatchedTopics || data.lastWatchedTopics || [];
            const filtered = lastTopics.filter((t: string) => t !== topicSlug);
            filtered.unshift(topicSlug);
            updates.lastWatchedTopics = filtered.slice(0, 20);
          }

          if (searchQuery && type === "search") {
            const recentSearches: string[] = updates.recentSearchQueries || data.recentSearchQueries || [];
            recentSearches.unshift(searchQuery.toLowerCase().trim());
            updates.recentSearchQueries = [...new Set(recentSearches)].slice(0, 30);
          }

          if (type === "notInterested" && videoId) {
            updates.notInterestedVideoIds = admin.firestore.FieldValue.arrayUnion(videoId);
          }

          if (type === "skip" && category) {
            const skipped = updates.skippedCategories || data.skippedCategories || {};
            skipped[category] = (skipped[category] || 0) + 1;
            updates.skippedCategories = skipped;
          }

          if (type === "earlyExit" && category) {
            const earlyExits = updates.earlyExitCategories || data.earlyExitCategories || {};
            earlyExits[category] = (earlyExits[category] || 0) + 1;
            updates.earlyExitCategories = earlyExits;
          }
        }

        updates.interests = interests;

        if (!snap.exists) {
          tx.set(userRef, updates);
        } else {
          tx.update(userRef, updates);
        }
      });

      return { success: true };
    } catch (err) {
      logger.error("[trackActivity] Error:", err);
      return { success: false, error: "Internal error" };
    }
  }
);
