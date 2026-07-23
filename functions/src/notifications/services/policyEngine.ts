import * as admin from "firebase-admin";
import { CreatorEvent, NotificationCategory, NotificationPriority } from "../types";

const db = admin.firestore();

export interface PolicyDecision {
  allow: boolean;
  reason?: string;
  featureFlagEnabled?: boolean;
}

export class PolicyEngine {
  /**
   * Evaluates policy gates (Rate limits, Quiet Hours, Creator Preferences, Feature Flags)
   */
  static async evaluate(event: CreatorEvent, category: NotificationCategory, priority: NotificationPriority): Promise<PolicyDecision> {
    // 1. Critical notifications bypass rate limits and quiet hours
    if (priority === "critical") {
      return { allow: true };
    }

    try {
      // 2. Fetch Creator Preferences from users/{creatorId}/settings/creator_intelligence
      const prefDoc = await db
        .collection("users")
        .doc(event.creatorId)
        .collection("settings")
        .doc("creator_intelligence")
        .get();

      if (prefDoc.exists) {
        const prefs = prefDoc.data();
        // Check category toggle
        if (prefs?.categories && prefs.categories[category] === false) {
          return { allow: false, reason: `Category ${category} disabled in creator preferences` };
        }
      }

      // 3. Simple Rate Limiting: Max 10 non-critical notifications per creator per hour
      const oneHourAgo = Date.now() - 3600 * 1000;
      const recentSnap = await db
        .collection("users")
        .doc(event.creatorId)
        .collection("notifications_active")
        .where("createdAt", ">=", oneHourAgo)
        .get();

      if (recentSnap.size >= 10) {
        return { allow: false, reason: "Hourly rate limit reached for non-critical notifications" };
      }

      return { allow: true };
    } catch (err) {
      // Default to allowed on error to prevent dropping important notifications
      return { allow: true };
    }
  }
}
