import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { RevenueStatement, TYPE_REVENUE_SHARE } from "./types";
import { ChannelType } from "../pipeline/types";

const db = () => admin.firestore();

/**
 * 💰 CALCULATE REVENUE SHARE
 * Internal utility to compute creator's cut based on channel type and buyout status.
 */
export function calculateShare(
  gross: number,
  sourceType: "ads" | "members",
  channelType: ChannelType,
  hasPaidSubscriptionBuyout: boolean = false
): number {
  if (sourceType === "members" && channelType === "custom" && hasPaidSubscriptionBuyout) {
    return gross; // 100% for custom channels with buyout
  }

  const share = TYPE_REVENUE_SHARE[channelType][sourceType];
  return gross * share;
}

/**
 * 📈 GET CREATOR REVENUE (Callable)
 * Returns current month estimates and past statements for the dashboard.
 */
export const getCreatorRevenue = onCall(
  { region: "asia-south1", memory: "256MiB" },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Auth required.");

    try {
      const statementsSnap = await db().collection("revenue_statements")
        .where("userId", "==", userId)
        .orderBy("month", "desc")
        .limit(6)
        .get();

      const statements = statementsSnap.docs.map(doc => doc.data() as RevenueStatement);

      const currentMonth = new Date().toISOString().slice(0, 7);

      // Mocked data for current month estimate
      return {
        currentMonth,
        estimate: {
          grossRevenue: 12450.50,
          creatorShare: 9337.80,
          views: 45000
        },
        statements
      };
    } catch (err) {
      logger.error("[getCreatorRevenue] Error:", err);
      throw new HttpsError("internal", "Failed to fetch revenue data.");
    }
  }
);

/**
 * 🔄 SYNC CHANNEL STATEMENTS (Internal/Stub)
 */
export async function syncChannelStatements(channel: any, userId: string): Promise<void> {
  logger.info(`[Economy] Syncing channel statements for creator: ${userId}, channel: ${channel?.id || 'unknown'}`);
}

/**
 * 📝 GENERATE MONTHLY STATEMENT (Internal/Admin)
 */
export async function generateMonthlyStatement(userId: string, month: string) {
  logger.info(`[Economy] Generating statement for ${userId} for ${month}`);
  // Implementation would involve summing real-time earnings and deducting costs for Custom channels
}
