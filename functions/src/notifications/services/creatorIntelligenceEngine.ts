import * as admin from "firebase-admin";
import { CreatorEvent, StudioNotification, DeliveryChannels, NotificationType } from "../types";
import { TEMPLATE_REGISTRY } from "../templates/notificationTemplates";
import { PolicyEngine } from "./policyEngine";
import { RankingEngine } from "./rankingEngine";

const db = admin.firestore();

export class CreatorIntelligenceEngine {
  /**
   * Main Stateless Event Bus Processor
   */
  static async processEvent(event: CreatorEvent): Promise<string | null> {
    const { eventId, creatorId, type, payload } = event;

    // 1. Idempotency Check: Write to creatorEvents/{eventId}
    const eventRef = db.collection("creatorEvents").doc(eventId);
    const eventSnap = await eventRef.get();
    if (eventSnap.exists) {
      console.log(`[CreatorIntelligenceEngine] Skipping duplicate eventId: ${eventId}`);
      return null;
    }
    await eventRef.set(event);

    // 2. Map Event to Template Definition
    let templateKey = "coach_growth_tip_v1";
    if (type === "verification_rejected" || type === "verification_flagged") {
      templateKey = "verification_rejected_v1";
    } else if (type === "sub_milestone") {
      templateKey = "subscribers_milestone_v1";
    } else if (type === "view_milestone") {
      templateKey = "views_milestone_v1";
    }

    const template = TEMPLATE_REGISTRY[templateKey] || TEMPLATE_REGISTRY["coach_growth_tip_v1"];

    // 3. Evaluate Policy Engine
    const policyDecision = await PolicyEngine.evaluate(event, template.category, template.priority);
    if (!policyDecision.allow) {
      console.log(`[CreatorIntelligenceEngine] Policy rejected event ${eventId}: ${policyDecision.reason}`);
      return null;
    }

    // 4. Render Title and Message templates
    let title = template.titleTemplate;
    let message = template.messageTemplate;

    for (const [key, value] of Object.entries(payload)) {
      const regex = new RegExp(`{{${key}}}`, "g");
      title = title.replace(regex, String(value));
      message = message.replace(regex, String(value));
    }

    // 5. Calculate Ranking Score
    const now = Date.now();
    const rankingScore = RankingEngine.calculateScore(template.priority, now, false);

    // 6. Build StudioNotification object
    const notificationId = db.collection("users").doc(creatorId).collection("notifications_active").doc().id;

    const delivery: DeliveryChannels = {
      studio: true,
      push: template.priority === "critical" || template.priority === "high",
      email: template.priority === "critical",
      mobile: true,
    };

    let expiresAt: number | undefined;
    if (template.ttlDays) {
      expiresAt = now + template.ttlDays * 24 * 3600 * 1000;
    }

    const notification: StudioNotification = {
      id: notificationId,
      eventId,
      schemaVersion: 1,
      creatorId,
      type: type as NotificationType,
      category: template.category,
      priority: template.priority,
      rankingScore,
      status: "UNREAD",
      title,
      message,
      createdAt: now,
      expiresAt,
      delivery,
      actions: template.defaultActions,
      verificationReportId: payload.reportId,
      metadata: payload,
    };

    // 7. Write to users/{creatorId}/notifications_active
    await db
      .collection("users")
      .doc(creatorId)
      .collection("notifications_active")
      .doc(notificationId)
      .set(notification);

    console.log(`[CreatorIntelligenceEngine] Dispatched notification ${notificationId} to creator ${creatorId}`);
    return notificationId;
  }
}
