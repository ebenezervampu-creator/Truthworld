/**
 * 📊 UNIT ECONOMICS & CONTRIBUTION MARGIN DASHBOARD (ADMIN API)
 *
 * Provides real-time financial reporting by joining:
 *   1. cost_rollups (Gemini AI, Google Cloud CDN, ElevenLabs, AssemblyAI, FFmpeg, Compute)
 *   2. revenue_statements (Gross revenue, 70/30 platform/creator splits, ad/premium pools)
 *   3. channels (Standard vs. Pro channel economics & SaaS fee offsets)
 *   4. premium_subscriptions (Per-tier margin analysis: Free, Audio, Premium, 4K Fact-Checked)
 *
 * Solves the 3 core business model equations:
 *   - Cost per active user across subscription tiers
 *   - Contribution per monetized view
 *   - Creator lifetime economics (Standard vs. Pro channels & revenue leak analysis)
 */

import * as admin from "firebase-admin";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { applySecurityHeaders } from "../utils/securityHeaders";
import { requireRecentAdmin, isCallableAdmin, isCallableSuperAdmin } from "../utils/auth";
import { ChannelType } from "../pipeline/types";

const db = () => admin.firestore();
const USD_INR_RATE = 84.0; // Standardized platform exchange rate (matches payouts.ts)

// ─── Interfaces ─────────────────────────────────────────────────────────────

export interface UserTierEconomics {
  tierId: string;
  tierName: string;
  monthlyPriceINR: number;
  monthlyPriceUSD: number;
  activeSubscribers: number;
  grossRevenueUSD: number;
  creatorPoolUSD: number;
  platformShareUSD: number;
  estimatedDeliveryInfraUSD: number;
  netContributionUSD: number;
  contributionMarginPercent: number;
  isProfitable: boolean;
}

export interface ChannelTypeEconomics {
  channelType: ChannelType;
  channelCount: number;
  totalGrossRevenueUSD: number;
  creatorEarningsUSD: number;
  platformCutUSD: number;
  saasFeesCollectedUSD: number;
  totalPlatformRevenueUSD: number;
  totalInfraCostUSD: number;
  budgetedInfraCostUSD?: number; // 1/3 of SaaS plan fee covers all infrastructure costs (33.3%)
  budgetedPlatformProfitUSD?: number; // 2/3 of SaaS plan fee is TruthWorld profit margin (66.7%)
  budgetedDeliveryCostUSD?: number; // Storage + CDN egress within the 1/3 infra budget (~95%)
  budgetedFirestoreAndOtherCostUSD?: number; // Remaining amount of 1/3 infra budget for Firestore ops, Cloud Functions, and DB overhead (~5%)
  netPlatformContributionUSD: number;
  contributionMarginPercent: number;
  revenueLeakageUSD?: number; // For Custom: foregone 30% rev share minus SaaS fee
}

export interface UnitEconomicsReport {
  month: string;
  generatedAt: number;
  summary: {
    totalGrossRevenueUSD: number;
    totalCreatorPayoutsUSD: number;
    totalPlatformRevenueUSD: number;
    totalInfrastructureCostUSD: number;
    netPlatformProfitUSD: number;
    netPlatformMarginPercent: number;
    breakEvenCPM_INR: number;
  };
  infraCostBreakdown: {
    geminiAI_USD: number;
    searchGroundingUSD: number;
    googleCloudCDN_USD: number;
    transcriptionUSD: number;
    translationUSD: number;
    elevenLabsTTS_USD: number;
    mediaTranscodeUSD: number;
    cloudFunctionsComputeUSD: number;
    firestoreOpsUSD: number;
    totalUSD: number;
  };
  channelEconomics: {
    standard: ChannelTypeEconomics;
    custom: ChannelTypeEconomics;
    customArbitrageAnalysis: {
      foregonePlatformShareUSD: number;
      saasFeesCollectedUSD: number;
      netPlatformLeakUSD: number;
      recommendation: string;
    };
  };
  userTierEconomics: UserTierEconomics[];
  perViewEconomics: {
    benchmarkCPM_INR: number;
    grossRevenuePerViewUSD: number;
    creatorSharePerViewUSD: number;
    platformSharePerViewUSD: number;
    cdnEgressCostPerViewUSD: number;
    computeCostPerViewUSD: number;
    netContributionPerViewUSD: number;
    isViewProfitableAtCurrentCPM: boolean;
  };
}

// ─── Core Analytics Engine ──────────────────────────────────────────────────

export async function computeUnitEconomics(monthInput?: string): Promise<UnitEconomicsReport> {
  const currentMonth = monthInput || new Date().toISOString().slice(0, 7);

  // 1. Fetch cost rollups for the target month
  const costRollupsSnap = await db()
    .collection("cost_rollups")
    .where("month", "==", currentMonth)
    .get();

  let geminiAI_USD = 0;
  let searchGroundingUSD = 0;
  let googleCloudCDN_USD = 0;
  let transcriptionUSD = 0;
  let translationUSD = 0;
  let elevenLabsTTS_USD = 0;
  let mediaTranscodeUSD = 0;
  let cloudFunctionsComputeUSD = 0;
  let firestoreOpsUSD = 0;
  let totalInfraCostUSD = 0;

  let standardInfraCostUSD = 0;
  let customInfraCostUSD = 0;

  costRollupsSnap.forEach((doc) => {
    const data = doc.data() as any;
    const total = Number(data.totalCostUsd || 0);
    totalInfraCostUSD += total;

    const isCustom = data.channelType === "custom";
    if (isCustom) {
      customInfraCostUSD += total;
    } else {
      standardInfraCostUSD += total;
    }

    const b = data.breakdown || {};
    geminiAI_USD += Number(b.extraction || 0) + Number(b.verification || 0) + Number(b.synthesis || 0) + Number(b.ad_moderation || 0);
    searchGroundingUSD += Number(b.grounding || 0);
    googleCloudCDN_USD += Number(b.cdn_egress || 0);
    transcriptionUSD += Number(b.transcription || 0);
    translationUSD += Number(b.translation || 0);
    elevenLabsTTS_USD += Number(b.tts || 0);
    mediaTranscodeUSD += Number(b.media || 0);
    cloudFunctionsComputeUSD += Number(b.compute || 0);
    firestoreOpsUSD += Number(b.firestore || 0);
  });

  // 2. Fetch revenue statements for the month
  const revenueSnap = await db()
    .collection("revenue_statements")
    .where("month", "==", currentMonth)
    .get();

  let standardGrossINR = 0;
  let standardCreatorINR = 0;
  let standardPlatformINR = 0;
  let standardChannelsCount = 0;

  let customGrossINR = 0;
  let customCreatorINR = 0;
  let customPlatformINR = 0;
  let customChannelsCount = 0;
  let totalReportedViews = 0;

  revenueSnap.forEach((doc) => {
    const data = doc.data() as any;
    totalReportedViews += Number(data.views || data.totalViews || data.periodViews || 0);
    const isCustom = data.channelType === "custom" || data.channelType === "pro" || data.type === "custom" || data.type === "pro";
    const gross = Number(data.grossINR || 0);
    const creator = Number(data.creatorShareINR || 0);
    const platform = Number(data.platformShareINR || 0);

    if (isCustom) {
      customGrossINR += gross;
      customCreatorINR += creator;
      customPlatformINR += platform;
      customChannelsCount++;
    } else {
      standardGrossINR += gross;
      standardCreatorINR += creator;
      standardPlatformINR += platform;
      standardChannelsCount++;
    }
  });

  // 3. Fetch active Pro Channels to dynamically calculate SaaS fees collected
  const customChannelsSnap = await db()
    .collection("channels")
    .where("channelType", "in", ["custom", "pro"])
    .get();

  let customSaaSFeesUSD = 0;
  customChannelsSnap.forEach((doc) => {
    const cData = doc.data() || {};
    const infra = cData.infraConfig || {};
    const fee = Number(infra.flatPlatformFee || infra.planPriceUSD || 30.0);
    customSaaSFeesUSD += fee;
  });

  const totalCustomChannels = Math.max(customChannelsSnap.size, customChannelsCount);
  if (customSaaSFeesUSD === 0 && totalCustomChannels > 0) {
    customSaaSFeesUSD = totalCustomChannels * 30.0;
  }

  const standardGrossUSD = standardGrossINR / USD_INR_RATE;
  const standardCreatorUSD = standardCreatorINR / USD_INR_RATE;
  const standardPlatformUSD = standardPlatformINR / USD_INR_RATE;

  const customGrossUSD = customGrossINR / USD_INR_RATE;
  const customCreatorUSD = customCreatorINR / USD_INR_RATE;
  const customPlatformRevenueUSD = (customPlatformINR / USD_INR_RATE) + customSaaSFeesUSD;

  // Pro channel revenue leakage: foregone 30% rev share minus SaaS fee collected
  const foregonePlatformShareUSD = customGrossUSD * 0.30;
  const netPlatformLeakUSD = Math.max(0, foregonePlatformShareUSD - customSaaSFeesUSD);

  // 4. Fetch Active Premium Subscriptions by Tier
  const subsSnap = await db()
    .collection("premium_subscriptions")
    .where("isPremium", "==", true)
    .get();

  const tierCounts: Record<string, number> = {
    audio_monthly: 0,
    individual_monthly: 0,
    "4k_factchecked_monthly": 0,
    family_monthly: 0,
  };

  subsSnap.forEach((doc) => {
    const plan = doc.data().planId || "individual_monthly";
    if (tierCounts[plan] !== undefined) {
      tierCounts[plan]++;
    } else {
      tierCounts.individual_monthly++;
    }
  });

  const tierPricesINR: Record<string, { name: string; inr: number; estInfraUSD: number }> = {
    audio_monthly: { name: "Audio Premium", inr: Math.round(0.50 * USD_INR_RATE), estInfraUSD: 0.02 }, // Recalibrated for 128 kbps pure audio stream
    individual_monthly: { name: "Individual Premium", inr: Math.round(2.0 * USD_INR_RATE), estInfraUSD: 0.65 },
    "4k_factchecked_monthly": { name: "4K + Fact-Checked", inr: Math.round(3.0 * USD_INR_RATE), estInfraUSD: 1.10 },
    family_monthly: { name: "Family Plan", inr: Math.round(5.0 * USD_INR_RATE), estInfraUSD: 1.80 },
  };

  const userTierEconomics: UserTierEconomics[] = Object.entries(tierPricesINR).map(([tierId, meta]) => {
    const active = tierCounts[tierId] || 0;
    const priceUSD = meta.inr / USD_INR_RATE;
    const gross = active * priceUSD;
    // Industry-standard Net Receipts split: deduct direct payment processing / app store commissions before 70/30 split.
    // Audio Premium is primarily routed through low-fee UPI AutoPay (~1.8-2%), higher tiers blended card/IAP (~8%).
    const blendedCommissionRate = tierId === "audio_monthly" ? 0.02 : 0.08;
    const storeAndGatewayCommissions = gross * blendedCommissionRate;
    const netReceipts = Math.max(0, gross - storeAndGatewayCommissions);
    const creatorCut = netReceipts * 0.70;
    const platformCut = netReceipts * 0.30;
    const deliveryInfra = active * meta.estInfraUSD;
    const net = platformCut - deliveryInfra;
    const marginPct = platformCut > 0 ? (net / platformCut) * 100 : 0;

    return {
      tierId,
      tierName: meta.name,
      monthlyPriceINR: meta.inr,
      monthlyPriceUSD: Math.round(priceUSD * 100) / 100,
      activeSubscribers: active,
      grossRevenueUSD: Math.round(gross * 100) / 100,
      creatorPoolUSD: Math.round(creatorCut * 100) / 100,
      platformShareUSD: Math.round(platformCut * 100) / 100,
      estimatedDeliveryInfraUSD: Math.round(deliveryInfra * 100) / 100,
      netContributionUSD: Math.round(net * 100) / 100,
      contributionMarginPercent: Math.round(marginPct * 10) / 10,
      isProfitable: net > 0,
    };
  });

  // 5. Per-View Unit Economics (Dynamic from actual reported views or benchmark ₹15 CPM)
  const BENCHMARK_CPM_INR = 15.0;
  let grossRevPerViewUSD = (BENCHMARK_CPM_INR / 1000) / USD_INR_RATE;
  let creatorPerViewUSD = grossRevPerViewUSD * 0.70;
  let platformPerViewUSD = grossRevPerViewUSD * 0.30;
  let cdnEgressPerViewUSD = 0.0017;
  let computeCostPerViewUSD = 0.00015;

  if (totalReportedViews > 0) {
    grossRevPerViewUSD = (standardGrossUSD + customGrossUSD) / totalReportedViews;
    creatorPerViewUSD = (standardCreatorUSD + customCreatorUSD) / totalReportedViews;
    platformPerViewUSD = (standardPlatformUSD + (customPlatformINR / USD_INR_RATE)) / totalReportedViews;
    if (googleCloudCDN_USD > 0) {
      cdnEgressPerViewUSD = googleCloudCDN_USD / totalReportedViews;
    }
    if (cloudFunctionsComputeUSD > 0 || geminiAI_USD > 0) {
      computeCostPerViewUSD = (cloudFunctionsComputeUSD + geminiAI_USD) / totalReportedViews;
    }
  }

  const netContributionPerViewUSD = platformPerViewUSD - (cdnEgressPerViewUSD + computeCostPerViewUSD);

  // Break-even CPM: CPM needed so platform 30% cut covers delivery
  const breakEvenCPM_INR = ((cdnEgressPerViewUSD + computeCostPerViewUSD) / 0.30) * 1000 * USD_INR_RATE;

  // 6. Aggregate Platform Totals
  const totalGrossRevenueUSD = standardGrossUSD + customGrossUSD;
  const totalCreatorPayoutsUSD = standardCreatorUSD + customCreatorUSD;
  const totalPlatformRevenueUSD = standardPlatformUSD + customPlatformRevenueUSD;
  const netPlatformProfitUSD = totalPlatformRevenueUSD - totalInfraCostUSD;
  const netPlatformMarginPercent = totalPlatformRevenueUSD > 0
    ? (netPlatformProfitUSD / totalPlatformRevenueUSD) * 100
    : 0;

  const standardNetContribution = standardPlatformUSD - standardInfraCostUSD;
  const customNetContribution = customPlatformRevenueUSD - customInfraCostUSD;

  return {
    month: currentMonth,
    generatedAt: Date.now(),
    summary: {
      totalGrossRevenueUSD: Math.round(totalGrossRevenueUSD * 100) / 100,
      totalCreatorPayoutsUSD: Math.round(totalCreatorPayoutsUSD * 100) / 100,
      totalPlatformRevenueUSD: Math.round(totalPlatformRevenueUSD * 100) / 100,
      totalInfrastructureCostUSD: Math.round(totalInfraCostUSD * 100) / 100,
      netPlatformProfitUSD: Math.round(netPlatformProfitUSD * 100) / 100,
      netPlatformMarginPercent: Math.round(netPlatformMarginPercent * 10) / 10,
      breakEvenCPM_INR: Math.round(breakEvenCPM_INR * 10) / 10,
    },
    infraCostBreakdown: {
      geminiAI_USD: Math.round(geminiAI_USD * 100) / 100,
      searchGroundingUSD: Math.round(searchGroundingUSD * 100) / 100,
      googleCloudCDN_USD: Math.round(googleCloudCDN_USD * 100) / 100,
      transcriptionUSD: Math.round(transcriptionUSD * 100) / 100,
      translationUSD: Math.round(translationUSD * 100) / 100,
      elevenLabsTTS_USD: Math.round(elevenLabsTTS_USD * 100) / 100,
      mediaTranscodeUSD: Math.round(mediaTranscodeUSD * 100) / 100,
      cloudFunctionsComputeUSD: Math.round(cloudFunctionsComputeUSD * 100) / 100,
      firestoreOpsUSD: Math.round(firestoreOpsUSD * 100) / 100,
      totalUSD: Math.round(totalInfraCostUSD * 100) / 100,
    },
    channelEconomics: {
      standard: {
        channelType: "standard",
        channelCount: Math.max(1, standardChannelsCount),
        totalGrossRevenueUSD: Math.round(standardGrossUSD * 100) / 100,
        creatorEarningsUSD: Math.round(standardCreatorUSD * 100) / 100,
        platformCutUSD: Math.round(standardPlatformUSD * 100) / 100,
        saasFeesCollectedUSD: 0,
        totalPlatformRevenueUSD: Math.round(standardPlatformUSD * 100) / 100,
        totalInfraCostUSD: Math.round(standardInfraCostUSD * 100) / 100,
        netPlatformContributionUSD: Math.round(standardNetContribution * 100) / 100,
        contributionMarginPercent: standardPlatformUSD > 0
          ? Math.round((standardNetContribution / standardPlatformUSD) * 1000) / 10
          : 0,
      },
      custom: {
        channelType: "custom",
        channelCount: totalCustomChannels,
        totalGrossRevenueUSD: Math.round(customGrossUSD * 100) / 100,
        creatorEarningsUSD: Math.round(customCreatorUSD * 100) / 100,
        platformCutUSD: 0,
        saasFeesCollectedUSD: Math.round(customSaaSFeesUSD * 100) / 100,
        totalPlatformRevenueUSD: Math.round(customPlatformRevenueUSD * 100) / 100,
        totalInfraCostUSD: Math.round(customInfraCostUSD * 100) / 100,
        budgetedInfraCostUSD: Math.round((customSaaSFeesUSD / 3) * 100) / 100,
        budgetedPlatformProfitUSD: Math.round(((customSaaSFeesUSD * 2) / 3) * 100) / 100,
        budgetedDeliveryCostUSD: Math.round(((customSaaSFeesUSD / 3) * 0.95) * 100) / 100,
        budgetedFirestoreAndOtherCostUSD: Math.round(((customSaaSFeesUSD / 3) * 0.05) * 100) / 100,
        netPlatformContributionUSD: Math.round(customNetContribution * 100) / 100,
        contributionMarginPercent: customPlatformRevenueUSD > 0
          ? Math.round((customNetContribution / customPlatformRevenueUSD) * 1000) / 10
          : 0,
        revenueLeakageUSD: Math.round(netPlatformLeakUSD * 100) / 100,
      },
      customArbitrageAnalysis: {
        foregonePlatformShareUSD: Math.round(foregonePlatformShareUSD * 100) / 100,
        saasFeesCollectedUSD: Math.round(customSaaSFeesUSD * 100) / 100,
        netPlatformLeakUSD: Math.round(netPlatformLeakUSD * 100) / 100,
        recommendation: netPlatformLeakUSD > 0
          ? `Pro channels caused a $${Math.round(netPlatformLeakUSD)} net revenue leakage this month. Introduce Option B ($30/mo + 10% rev share) to capture upside.`
          : "Pro channels are currently accretive under the SaaS fee structure.",
      },
    },
    userTierEconomics,
    perViewEconomics: {
      benchmarkCPM_INR: BENCHMARK_CPM_INR,
      grossRevenuePerViewUSD: Math.round(grossRevPerViewUSD * 1000000) / 1000000,
      creatorSharePerViewUSD: Math.round(creatorPerViewUSD * 1000000) / 1000000,
      platformSharePerViewUSD: Math.round(platformPerViewUSD * 1000000) / 1000000,
      cdnEgressCostPerViewUSD: Math.round(cdnEgressPerViewUSD * 1000000) / 1000000,
      computeCostPerViewUSD: Math.round(computeCostPerViewUSD * 1000000) / 1000000,
      netContributionPerViewUSD: Math.round(netContributionPerViewUSD * 1000000) / 1000000,
      isViewProfitableAtCurrentCPM: netContributionPerViewUSD > 0,
    },
  };
}

// ─── Cloud Function Endpoints ───────────────────────────────────────────────

/**
 * 🔒 Callable Cloud Function: getUnitEconomicsDashboard
 * Secure, authenticated endpoint for the Admin Portal dashboard.
 */
export const getUnitEconomicsDashboard = onCall(
  {
    region: "asia-south1",
    memory: "512MiB",
    timeoutSeconds: 60,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required to access admin analytics.");
    }

    const isAdmin = isCallableAdmin(request.auth);
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Verified admin access required.");
    }

    const month = (request.data?.month as string) || undefined;
    if (month && !/^\d{4}-\d{2}$/.test(month)) {
      throw new HttpsError("invalid-argument", "Invalid month format. Expected YYYY-MM.");
    }
    return await computeUnitEconomics(month);
  }
);

/**
 * 🔒 HTTP Endpoint: getUnitEconomicsReport
 * Secured with requireRecentAdmin for external BI / REST integrations.
 */
export const getUnitEconomicsReport = onRequest(
  {
    cors: true,
    region: "asia-south1",
    memory: "512MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
    applySecurityHeaders(res);
    try {
      const adminUser = await requireRecentAdmin(req, res, 3600);
      if (!adminUser) return;

      const month = req.query.month as string | undefined;
      if (month && !/^\d{4}-\d{2}$/.test(month)) {
        res.status(400).json({ error: "Invalid month format. Expected YYYY-MM." });
        return;
      }
      const report = await computeUnitEconomics(month);

      res.status(200).json(report);
    } catch (err: any) {
      logger.error("[getUnitEconomicsReport] Failed to generate report:", err);
      res.status(500).json({ error: "Failed to generate unit economics report." });
    }
  }
);

// ─── Channel-Level Spendings & Revenue (Super Admin Only) ───────────────────

export interface ChannelSpendingsAndRevenueReport {
  channelId: string;
  channelName: string;
  ownerId: string;
  channelType: string;
  currency: string;
  usdInrRate: number;
  revenue: {
    grossINR: number;
    grossUSD: number;
    creatorShareINR: number;
    creatorShareUSD: number;
    platformShareINR: number;
    platformShareUSD: number;
    breakdown: {
      adsINR: number;
      premiumINR: number;
      membershipsINR: number;
      superchatsINR: number;
    };
    payouts: {
      walletBalanceUSD: number;
      clearedWithdrawableINR: number;
      pendingINR: number;
      withdrawnINR: number;
    };
  };
  spendings: {
    totalInfraUSD: number;
    totalInfraINR: number;
    currentMonthInfraCostUSD: number;
    breakdown: {
      geminiAI: number;
      cdnEgress: number;
      transcription: number;
      translationDubbing: number;
      mediaTranscoding: number;
      compute: number;
      firestoreOps: number;
    };
    creatorWalletSpendUSD: number;
  };
  economics: {
    netPlatformContributionUSD: number;
    netPlatformContributionINR: number;
    marginPercent: number;
    isProfitable: boolean;
  };
  transactions: Array<{
    id: string;
    amount: number;
    category: string;
    description: string;
    timestamp: number;
    balanceAfter: number;
    fundedDeducted: number;
    rolloverDeducted: number;
    revenueDeducted: number;
  }>;
  monthlyStatements: Array<{
    month: string;
    grossAdsRevenue: number;
    grossSubsRevenue: number;
    creatorShare: number;
    platformFee: number;
    infrastructureCosts: number;
    payoutStatus: string;
  }>;
}

export async function computeChannelSpendingsAndRevenue(channelId: string): Promise<ChannelSpendingsAndRevenueReport> {
  const chDoc = await db().collection("channels").doc(channelId).get();
  if (!chDoc.exists) {
    throw new HttpsError("not-found", `Channel with ID ${channelId} not found.`);
  }

  const data = chDoc.data() || {};
  const ownerId = (data.ownerId || data.userId || "").toString();
  const channelType = (data.channelType || "standard").toString().toLowerCase();
  const infraConfig = data.infraConfig || {};

  // 1. Revenue Streams
  const adsINR = Number(data.adsRevenueTotal || 0);
  const premiumINR = Number(data.premiumSubsRevenueTotal || 0);
  const membershipsINR = Number(data.membershipRevenueTotal || data.membershipsRevenueTotal || 0);
  const superchatsINR = Number(data.superchatRevenueTotal || 0);
  const grossRevenueINR = adsINR + premiumINR + membershipsINR + superchatsINR;
  const grossRevenueUSD = Math.round((grossRevenueINR / USD_INR_RATE) * 100) / 100;

  const walletBalanceUSD = Number(data.walletBalanceUSD || data.walletBalance || 0);
  const withdrawnINR = Number(data.withdrawnRevenueTotal || 0);
  const clearedWithdrawableINR = Number(data.clearedWithdrawableRevenueTotal ?? Math.max(0, grossRevenueINR - withdrawnINR));
  const pendingINR = Number(data.pendingRevenueTotal || 0);

  let creatorShareINR = 0;
  let creatorShareUSD = 0;
  let platformShareINR = 0;
  let platformShareUSD = 0;

  if (channelType === "custom" || channelType === "pro") {
    creatorShareINR = grossRevenueINR;
    creatorShareUSD = grossRevenueUSD;
    platformShareUSD = Number(infraConfig.flatPlatformFee || 15.0);
    platformShareINR = Math.round(platformShareUSD * USD_INR_RATE * 100) / 100;
  } else {
    creatorShareINR = Math.round(grossRevenueINR * 0.70 * 100) / 100;
    creatorShareUSD = Math.round(grossRevenueUSD * 0.70 * 100) / 100;
    platformShareINR = Math.round(grossRevenueINR * 0.30 * 100) / 100;
    platformShareUSD = Math.round(grossRevenueUSD * 0.30 * 100) / 100;
  }

  // 2. Platform Infrastructure & Cloud Processing Spendings for this channel
  let geminiAI = 0;
  let cdnEgress = 0;
  let transcription = 0;
  let translationDubbing = 0;
  let mediaTranscoding = 0;
  let compute = 0;
  let firestoreOps = 0;
  let totalInfraUSD = 0;

  if (ownerId) {
    try {
      const rollupsSnap = await db()
        .collection("cost_rollups")
        .where("userId", "==", ownerId)
        .get();

      rollupsSnap.forEach((doc) => {
        const rData = doc.data() as any;
        totalInfraUSD += Number(rData.totalCostUsd || 0);
        const b = rData.breakdown || {};
        geminiAI += Number(b.extraction || 0) + Number(b.verification || 0) + Number(b.synthesis || 0) + Number(b.ad_moderation || 0) + Number(b.grounding || 0);
        cdnEgress += Number(b.cdn_egress || 0);
        transcription += Number(b.transcription || 0);
        translationDubbing += Number(b.translation || 0) + Number(b.tts || 0);
        mediaTranscoding += Number(b.media || 0);
        compute += Number(b.compute || 0);
        firestoreOps += Number(b.firestore || 0);
      });
    } catch (e) {
      logger.warn(`[computeChannelSpendingsAndRevenue] cost_rollups query error for ${ownerId}:`, e);
    }
  }

  try {
    const channelRollupsSnap = await db()
      .collection("cost_rollups")
      .where("channelId", "==", channelId)
      .get();

    channelRollupsSnap.forEach((doc) => {
      if (!doc.data().userId || doc.data().userId !== ownerId) {
        const rData = doc.data() as any;
        totalInfraUSD += Number(rData.totalCostUsd || 0);
        const b = rData.breakdown || {};
        geminiAI += Number(b.extraction || 0) + Number(b.verification || 0) + Number(b.synthesis || 0) + Number(b.ad_moderation || 0) + Number(b.grounding || 0);
        cdnEgress += Number(b.cdn_egress || 0);
        transcription += Number(b.transcription || 0);
        translationDubbing += Number(b.translation || 0) + Number(b.tts || 0);
        mediaTranscoding += Number(b.media || 0);
        compute += Number(b.compute || 0);
        firestoreOps += Number(b.firestore || 0);
      }
    });
  } catch (e) {
    logger.warn(`[computeChannelSpendingsAndRevenue] channel rollups query error for ${channelId}:`, e);
  }

  const currentMonthInfraCost = Number(infraConfig.currentMonthInfraCost || 0);
  if (totalInfraUSD === 0 && currentMonthInfraCost > 0) {
    totalInfraUSD = currentMonthInfraCost;
  }
  totalInfraUSD = Math.round(totalInfraUSD * 100) / 100;
  const totalInfraINR = Math.round(totalInfraUSD * USD_INR_RATE * 100) / 100;

  // 3. Channel Economics & Net Contribution
  const netPlatformContributionUSD = Math.round((platformShareUSD - totalInfraUSD) * 100) / 100;
  const netPlatformContributionINR = Math.round(netPlatformContributionUSD * USD_INR_RATE * 100) / 100;
  const marginPercent = platformShareUSD > 0
    ? Math.round((netPlatformContributionUSD / platformShareUSD) * 10000) / 100
    : 0;

  // 4. Wallet Deductions & Spendings History
  let transactions: any[] = [];
  let creatorWalletSpendUSD = 0;
  try {
    const txSnap = await db()
      .collection("channel_wallet_transactions")
      .where("channelId", "==", channelId)
      .limit(50)
      .get();

    const rawTxList = txSnap.docs.map((d) => {
      const td = d.data();
      let ts = Date.now();
      if (td.timestamp?.toMillis) ts = td.timestamp.toMillis();
      else if (td.timestamp?.seconds) ts = td.timestamp.seconds * 1000;
      else if (typeof td.timestamp === "number") ts = td.timestamp;
      else if (td.createdAt?.toMillis) ts = td.createdAt.toMillis();

      const amt = Number(td.amount || 0);
      creatorWalletSpendUSD += amt;

      return {
        id: d.id,
        amount: amt,
        category: td.category || "ai_feature",
        description: td.description || "Wallet Transaction",
        timestamp: ts,
        balanceAfter: Number(td.balanceAfter || 0),
        fundedDeducted: Number(td.fundedDeducted || 0),
        rolloverDeducted: Number(td.rolloverDeducted || 0),
        revenueDeducted: Number(td.revenueDeducted || 0),
      };
    });

    rawTxList.sort((a, b) => b.timestamp - a.timestamp);
    transactions = rawTxList.slice(0, 15);
  } catch (err) {
    logger.warn(`[computeChannelSpendingsAndRevenue] Transactions fetch issue for ${channelId}:`, err);
  }

  // 5. Monthly Revenue Statements
  let monthlyStatements: any[] = [];
  if (ownerId) {
    try {
      const stmtsSnap = await db()
        .collection("revenue_statements")
        .where("userId", "==", ownerId)
        .limit(12)
        .get();

      const rawStmts = stmtsSnap.docs.map((d) => {
        const sd = d.data();
        return {
          month: sd.month || d.id,
          grossAdsRevenue: Number(sd.grossAdsRevenue || 0),
          grossSubsRevenue: Number(sd.grossSubsRevenue || 0),
          creatorShare: Number(sd.creatorShare || 0),
          platformFee: Number(sd.platformFee || 0),
          infrastructureCosts: Number(sd.infrastructureCosts || 0),
          payoutStatus: sd.payoutStatus || "pending",
        };
      });
      rawStmts.sort((a, b) => b.month.localeCompare(a.month));
      monthlyStatements = rawStmts.slice(0, 6);
    } catch (err) {
      logger.warn(`[computeChannelSpendingsAndRevenue] Statements fetch issue for user ${ownerId}:`, err);
    }
  }

  return {
    channelId,
    channelName: data.name || data.channelName || "Truthworld Channel",
    ownerId,
    channelType,
    currency: "INR",
    usdInrRate: USD_INR_RATE,
    revenue: {
      grossINR: grossRevenueINR,
      grossUSD: grossRevenueUSD,
      creatorShareINR,
      creatorShareUSD,
      platformShareINR,
      platformShareUSD,
      breakdown: {
        adsINR,
        premiumINR,
        membershipsINR,
        superchatsINR,
      },
      payouts: {
        walletBalanceUSD,
        clearedWithdrawableINR,
        pendingINR,
        withdrawnINR,
      },
    },
    spendings: {
      totalInfraUSD,
      totalInfraINR,
      currentMonthInfraCostUSD: currentMonthInfraCost,
      breakdown: {
        geminiAI: Math.round(geminiAI * 100) / 100,
        cdnEgress: Math.round(cdnEgress * 100) / 100,
        transcription: Math.round(transcription * 100) / 100,
        translationDubbing: Math.round(translationDubbing * 100) / 100,
        mediaTranscoding: Math.round(mediaTranscoding * 100) / 100,
        compute: Math.round(compute * 100) / 100,
        firestoreOps: Math.round(firestoreOps * 100) / 100,
      },
      creatorWalletSpendUSD: Math.round(creatorWalletSpendUSD * 100) / 100,
    },
    economics: {
      netPlatformContributionUSD,
      netPlatformContributionINR,
      marginPercent,
      isProfitable: netPlatformContributionUSD >= 0,
    },
    transactions,
    monthlyStatements,
  };
}

/**
 * 🔒 Callable Cloud Function: getChannelSpendingsAndRevenue
 * Exclusively accessible by Super Admin (and Owner / Director).
 * Aggregates all revenue, platform infrastructure costs, and wallet transactions for a specific channel.
 */
export const getChannelSpendingsAndRevenue = onCall(
  {
    region: "asia-south1",
    memory: "512MiB",
    timeoutSeconds: 60,
  },
  async (request): Promise<ChannelSpendingsAndRevenueReport> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required to access channel financial data.");
    }

    const isSuper = await isCallableSuperAdmin(request.auth);
    if (!isSuper) {
      throw new HttpsError("permission-denied", "Access Denied: Super Admin privileges are required to inspect channel spendings and revenue.");
    }

    const channelId = request.data?.channelId as string;
    if (!channelId || typeof channelId !== "string") {
      throw new HttpsError("invalid-argument", "Missing or invalid channelId parameter.");
    }

    return await computeChannelSpendingsAndRevenue(channelId);
  }
);

