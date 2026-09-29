export type PayoutStatus = "pending" | "processing" | "paid" | "failed" | "held";

export interface RevenueStatement {
  id: string;          // month_userId (e.g. 2026-04_user123)
  userId: string;
  month: string;       // YYYY-MM
  grossAdsRevenue: number;
  grossSubsRevenue: number;
  platformFee: number;
  infrastructureCosts: number; // For Custom channels
  creatorShare: number;
  payoutStatus: PayoutStatus;
  payoutMethod?: string;
  paidAt?: number;
  createdAt: number;
  updatedAt: number;
  metadata?: {
    totalViews: number;
    avgRPM: number;
    trustBonus: number;
  };
}

export interface PayoutSettings {
  userId: string;
  method: "upi" | "bank_transfer";
  details: Record<string, any>;
  autoPayout: boolean;
  minThreshold: number;
}

/**
 * 💎 PREMIUM REVENUE ALLOCATION
 * Records each subscriber's watch-time-weighted share to a specific channel for a billing month.
 * Written by the distributePremiumRevenue scheduler. Full transparent audit trail.
 */
export interface PremiumRevenueAllocation {
  id: string;                          // "{month}_{userId}_{channelId}"
  month: string;                       // "YYYY-MM"
  userId: string;                      // Premium subscriber who paid
  channelId: string;                   // Channel that earned
  channelOwnerId: string;             // Channel owner's userId (for security rules)
  subscriptionPlanId: string;          // e.g. "individual_monthly"
  subscriptionAmountINR: number;       // e.g. 169
  overlapDays: number;                 // Days active in billing month (1-30)
  proratedContributionINR: number;    // subscriptionAmountINR × (overlapDays / 30)
  watchSeconds: number;               // Seconds watched on this channel in the period
  totalWatchSeconds: number;          // Total seconds watched across ALL channels
  sharePercent: number;               // 0-100 (channelWatchSeconds / totalWatchSeconds * 100)
  grossAllocationINR: number;         // proratedContribution × 0.70 × (sharePercent / 100)
  creatorShareINR: number;            // = grossAllocationINR (70% already applied)
  platformFeeINR: number;             // proratedContribution × 0.30 × (sharePercent / 100)
  processedAt: number;               // epoch ms
  distributionRunId: string;          // month string identifying the run
}

/**
 * 📊 PREMIUM DISTRIBUTION RUN
 * Audit record for each monthly distribution job. Written to distribution_runs/{month}.
 */
export interface PremiumDistributionRun {
  month: string;                       // "YYYY-MM"
  status: "running" | "completed" | "failed";
  totalSubscribersProcessed: number;
  totalChannelsAllocated: number;
  grossPoolINR: number;               // Total premium revenue collected this month
  creatorPoolINR: number;             // 70% of gross
  platformPoolINR: number;            // 30% of gross
  unallocatedGrossINR?: number;       // Gross revenue from subscribers with no watch time
  unallocatedCreatorPoolINR?: number; // Creator pool portion (70%) of unallocated gross revenue
  startedAt: number;                  // epoch ms
  completedAt?: number;               // epoch ms
  triggeredBy: "scheduler" | "admin";
  error?: string;
}

/**
 * ⚖️ REVENUE SHARE MATRIX
 * Defines the percentage the CREATOR keeps based on their channel type:
 * - Standard Channels: 70% from ads & premium subscriptions (30% Platform), 100% from superchats & memberships (0% Platform).
 * - Custom Channels: 100% from all sources (0% Platform share); Custom channels take subscription/infrastructure plans ($15, $30, $45/mo etc.).
 */
export const TYPE_REVENUE_SHARE = {
  standard: { ads: 0.70, premiumSubs: 0.70, superchats: 1.00, members: 1.00 },
  custom: { ads: 1.00, premiumSubs: 1.00, superchats: 1.00, members: 1.00 },
};

