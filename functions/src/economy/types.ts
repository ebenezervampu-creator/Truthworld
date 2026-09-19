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
 * ⚖️ REVENUE SHARE MATRIX
 * Defines the percentage the CREATOR keeps based on their channel type:
 * - Standard Channels: 70% from ads & premium subscriptions (30% Platform), 100% from superchats & memberships (0% Platform).
 * - Custom Channels: 100% from all sources (0% Platform share); Custom channels take subscription/infrastructure plans ($15, $30, $45/mo etc.).
 */
export const TYPE_REVENUE_SHARE = {
  standard: { ads: 0.70, premiumSubs: 0.70, superchats: 1.00, members: 1.00 },
  custom: { ads: 1.00, premiumSubs: 1.00, superchats: 1.00, members: 1.00 },
};

