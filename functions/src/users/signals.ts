import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = admin.firestore();

/**
 * ⚡ TRACK ACTIVITY (Callable)
 * Records implicit signals (clicks, views, follows) to refine interest mapping.
 * This powers the 'For You' personalized feed.
 */
export const trackActivity = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) return { success: false, reason: "Unauthenticated" };

    const { category, type, durationSec } = request.data;
    if (!category) return { success: false, reason: "Missing category" };

    const userRef = db.collection("users").doc(userId);

    // ⚖️ Weighting Logic
    // Follows are the strongest signal, followed by long watches
    let weight = 0.05; // Base signal (click/short view)
    if (type === "follow") weight = 0.5;
    if (type === "view" && (durationSec || 0) > 60) weight = 0.2;
    if (type === "like") weight = 0.15;

    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(userRef);
        if (!snap.exists) {
          tx.set(userRef, { interests: { [category]: weight }, lastActiveAt: Date.now() });
          return;
        }

        const data = snap.data() as any;
        const interests = data.interests || {};
        
        // Update weight with a simple cap
        const current = interests[category] || 0;
        interests[category] = Math.min(current + weight, 1.0);
        
        // Decay other interests slightly to ensure the feed evolves
        for (const cat in interests) {
          if (cat !== category) {
            interests[cat] = Math.max(interests[cat] * 0.98, 0);
          }
        }

        tx.update(userRef, { interests, lastActiveAt: Date.now() });
      });
      
      return { success: true };
    } catch (err) {
      logger.error("[trackActivity] Error:", err);
      return { success: false, error: "Internal error" };
    }
  }
);
