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
 * Defines the percentage the CREATOR keeps based on their channel type.
 */
export const TYPE_REVENUE_SHARE = {
  standard: { ads: 0.75, members: 1.00 },
  custom: { ads: 1.00, members: 0.75 }, // 25% platform cut from memberships
};
