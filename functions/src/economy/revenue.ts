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
  sourceType: "ads" | "premiumSubs" | "superchats" | "members",
  channelType: ChannelType,
  hasPaidSubscriptionBuyout: boolean = false
): number {
  if (channelType === "custom") {
    return gross; // 100% for custom channels across all streams (0% platform cut)
  }

  const share = (TYPE_REVENUE_SHARE.standard as Record<string, number>)[sourceType] ?? 0.70;
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

      // Aggregate authentic channel performance metrics for current month
      const channelsSnap = await db().collection("channels")
        .where("ownerId", "==", userId)
        .get();

      let currentMonthViews = 0;
      let currentMonthGross = 0;
      let currentMonthEstimatedCreatorShare = 0;

      for (const chDoc of channelsSnap.docs) {
        const chData = chDoc.data() || {};
        const isCustom = chData.type === "custom" || chData.channelType === "custom";
        const chViews = Number(chData.stats?.views || chData.views || 0);
        const chSuperchats = Number(chData.superchatRevenueTotal || 0);
        const chAds = Number(chData.adsRevenueTotal || 0);
        const chPremiumSubs = Number(chData.premiumSubsRevenueTotal || 0);
        let chMembers = Number(chData.membershipRevenueTotal || chData.membershipsRevenueTotal || 0);

        currentMonthViews += chViews;
        if (chMembers === 0) {
          try {
            const membersSnap = await chDoc.ref.collection("members").where("status", "==", "active").get();
            for (const mDoc of membersSnap.docs) {
              chMembers += Number(mDoc.data().price || 0);
            }
          } catch (_) {}
        }

        const chGross = chSuperchats + chAds + chMembers + chPremiumSubs;
        currentMonthGross += chGross;

        if (isCustom) {
          currentMonthEstimatedCreatorShare += chGross;
        } else {
          // chAds and chPremiumSubs are already net creator shares credited by settlement functions
          currentMonthEstimatedCreatorShare += chAds + chSuperchats + chMembers + chPremiumSubs;
        }
      }

      // If a current-month statement exists, prefer its audited values
      const currentMonthDoc = statements.find(s => s.month === currentMonth);
      const grossRevenue = currentMonthDoc
        ? (currentMonthDoc.grossAdsRevenue + currentMonthDoc.grossSubsRevenue)
        : currentMonthGross;
      const creatorShare = currentMonthDoc ? currentMonthDoc.creatorShare : currentMonthEstimatedCreatorShare;
      const views = currentMonthDoc ? (currentMonthDoc.metadata?.totalViews ?? currentMonthViews) : currentMonthViews;


      return {
        currentMonth,
        estimate: {
          grossRevenue: Math.round(grossRevenue * 100) / 100,
          creatorShare: Math.round(creatorShare * 100) / 100,
          views,
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
 * 🔄 SYNC CHANNEL STATEMENTS (Internal)
 * Synchronizes authentic channel earnings into monthly revenue_statements.
 */
export async function syncChannelStatements(channel: any, userId: string): Promise<void> {
  logger.info(`[Economy] Syncing channel statements for creator: ${userId}, channel: ${channel?.id || 'unknown'}`);
  if (!userId || !channel) return;

  const currentMonth = new Date().toISOString().slice(0, 7);
  const channelId = channel.id || "default";
  const statementDocId = `${currentMonth}_${userId}_${channelId}`;
  const statementRef = db().collection("revenue_statements").doc(statementDocId);

  const existingSnap = await statementRef.get();

  // Calculate earnings from authentic channel metrics
  const views = Number(channel.stats?.views || channel.views || 0);
  const superchatRevenue = Number(channel.superchatRevenueTotal || 0);
  const adsRevenue = Number(channel.adsRevenueTotal || 0);
  const premiumSubsRevenue = Number(channel.premiumSubsRevenueTotal || 0);

  // Calculate authentic channel memberships revenue (100% direct creator share)
  let membershipsRevenue = Number(channel.membershipRevenueTotal || channel.membershipsRevenueTotal || 0);
  if (membershipsRevenue === 0) {
    try {
      const membersSnap = await db().collection("channels").doc(channelId).collection("members")
        .where("status", "==", "active").get();
      for (const mDoc of membersSnap.docs) {
        membershipsRevenue += Number(mDoc.data().price || 0);
      }
    } catch (mErr) {
      logger.warn(`[Economy] Could not fetch members for ${channelId}:`, mErr);
    }
  }

  const channelType: "standard" | "custom" =
    (channel.type === "custom" || channel.channelType === "custom") ? "custom" : "standard";

  const grossRevenue = superchatRevenue + adsRevenue + membershipsRevenue + premiumSubsRevenue;
  // Unified Revenue Share Rule:
  // - Standard: 70% Creator / 30% Platform on Ads & Premium Subs, 100% Creator / 0% Platform on Superchats & Memberships.
  // - Custom: 100% Creator / 0% Platform on all sources (Custom channels take plans $15, $30, $45/mo etc.).
  let creatorShare = 0;
  let platformFee = 0;

  if (channelType === "custom") {
    creatorShare = Math.round(grossRevenue * 100) / 100;
    platformFee = 0;
  } else {
    // adsRevenue and premiumSubsRevenue are already net creator shares credited by settlement functions
    creatorShare = Math.round((adsRevenue + superchatRevenue + membershipsRevenue + premiumSubsRevenue) * 100) / 100;
    const grossAds = adsRevenue > 0 ? adsRevenue / 0.70 : 0;
    const grossPremium = premiumSubsRevenue > 0 ? premiumSubsRevenue / 0.70 : 0;
    platformFee = Math.round(((grossAds + grossPremium) * 0.30) * 100) / 100;
  }


  if (!existingSnap.exists) {
    await statementRef.set({
      id: statementDocId,
      userId,
      channelId,
      month: currentMonth,
      grossAdsRevenue: adsRevenue,
      grossSubsRevenue: superchatRevenue + membershipsRevenue + premiumSubsRevenue,
      grossPremiumSubsRevenue: premiumSubsRevenue,
      platformFee,
      infrastructureCosts: 0,
      creatorShare,
      withdrawableShare: creatorShare,
      paidOutShare: 0,
      payoutStatus: "pending",
      createdAt: Date.now(),
      updatedAt: Date.now(),
      metadata: {
        totalViews: views,
        avgRPM: views > 0 ? (grossRevenue / views) * 1000 : 0,
        trustBonus: 0,
      },
    });
  } else {
    await statementRef.update({
      grossAdsRevenue: adsRevenue,
      grossSubsRevenue: superchatRevenue + membershipsRevenue + premiumSubsRevenue,
      grossPremiumSubsRevenue: premiumSubsRevenue,
      creatorShare,
      withdrawableShare: creatorShare,
      updatedAt: Date.now(),
      "metadata.totalViews": views,
    });
  }
}

/**
 * 📝 GENERATE MONTHLY STATEMENT (Internal/Admin)
 */
export async function generateMonthlyStatement(userId: string, month: string) {
  logger.info(`[Economy] Generating statement for ${userId} for ${month}`);
  // Implementation would involve summing real-time earnings and deducting costs for Custom channels
}
