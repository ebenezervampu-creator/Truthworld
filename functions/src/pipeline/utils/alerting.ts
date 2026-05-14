/**
 * 🚨 Alerting utility for critical system events
 *
 * Sends alerts to monitoring/observability systems.
 * Includes cost-specific alert types for unit economics governance.
 */

import * as admin from "firebase-admin";
import { logger } from "./logger";

const db = () => admin.firestore();

/** Known alert types and their severity mapping */
const ALERT_SEVERITY_MAP: Record<string, "critical" | "high" | "medium" | "low"> = {
  // Cost alerts
  "cost-per-job-exceeded":     "high",
  "monthly-burn-exceeded":     "critical",
  "free-tier-abuse":           "high",
  "negative-margin-detected":  "critical",
  // Infrastructure alerts
  "pubsub-circuit-open":       "critical",
  "dlq-failure":               "critical",
  "cache-write-failure":       "medium",
  "batch-cache-failure":       "medium",
  // Generic
  "high-cost-job":             "high",
};

export const alerting = {
  /**
   * Send alert about critical system issue.
   *
   * Cost-specific alert types:
   *   - `cost-per-job-exceeded` — single job exceeded per-job budget
   *   - `monthly-burn-exceeded` — platform monthly spend over threshold
   *   - `free-tier-abuse` — single free user consuming disproportionate resources
   *   - `negative-margin-detected` — estimated revenue < actual cost for a job
   */
  notify: async (alertType: string, data: any) => {
    try {
      const severity = ALERT_SEVERITY_MAP[alertType] ?? getSeverityFallback(alertType);

      // Log alert
      if (severity === "critical") {
        logger.error(`[ALERT][CRITICAL] ${alertType}`, data);
      } else {
        logger.error(`[ALERT] ${alertType}`, data);
      }

      // Write to Firestore for monitoring dashboards
      await db().collection("system_alerts").add({
        type: alertType,
        severity,
        data,
        timestamp: Date.now(),
        resolved: false,
        acknowledgedBy: null,
        acknowledgedAt: null,
      });
    } catch (err) {
      logger.error("[Alert] Failed to send alert", { alertType, err });
    }
  },

  /**
   * Resolve an alert (mark as handled).
   */
  resolve: async (alertId: string, resolvedBy: string = "system") => {
    try {
      await db().collection("system_alerts").doc(alertId).update({
        resolved: true,
        resolvedBy,
        resolvedAt: Date.now(),
      });
    } catch (err) {
      logger.error("[Alert] Failed to resolve alert", { alertId, err });
    }
  },

  /**
   * Get unresolved alerts count by type.
   */
  getUnresolvedCount: async (alertType?: string): Promise<number> => {
    try {
      let query = db().collection("system_alerts")
        .where("resolved", "==", false) as any;

      if (alertType) {
        query = query.where("type", "==", alertType);
      }

      const snap = await query.get();
      return snap.size;
    } catch (err) {
      logger.error("[Alert] Failed to count alerts", { err });
      return 0;
    }
  },
};

function getSeverityFallback(alertType: string): "critical" | "high" | "medium" | "low" {
  if (alertType.includes("circuit")) return "critical";
  if (alertType.includes("cost") || alertType.includes("burn")) return "high";
  if (alertType.includes("firestore")) return "high";
  return "medium";
}
