import { ChannelType } from "../pipeline/types";

// ─── Phase 2: Public Channel Profile + Reputation Layer ──────────────────────

// ─── Verification ─────────────────────────────────────────────────────────────

export type VerificationState =
  | "unverified"
  | "verified"       // identity confirmed
  | "trusted"        // high trust index over time
  | "institutional"  // org / media entity
  | "newsroom"       // official professional news entity
  | "suspended";

// ─── Profile ──────────────────────────────────────────────────────────────────

export interface ChannelProfile {
  about: string;                // max 280 chars
  photoUrl: string | null;
  coverUrl: string | null;
  category: ChannelCategory;
  country: string | null;     // ISO 3166-1 alpha-2
  links: SocialLink[];        // max 5
  languagesReached: string[]; // ISO 639-1 codes derived from video locales
}

export type ChannelCategory =
  | "news"
  | "politics"
  | "science"
  | "health"
  | "finance"
  | "technology"
  | "environment"
  | "education"
  | "culture"
  | "other";

export interface SocialLink {
  platform: "youtube" | "twitter" | "instagram" | "website" | "linkedin";
  url: string;
}

// ─── Reputation ───────────────────────────────────────────────────────────────

export interface ChannelReputation {
  channelRating?: number;     // 0.0 - 10.0, public reputation score
  avgTrustIndex: number;      // 0.0 - 10.0, rolling weighted avg
  trend30d: number;           // delta in last 30 days, e.g. +0.3 or -0.1
  totalVideos: number;
  factCheckedVideos: number;  // % = factCheckedVideos / totalVideos
  appealRate: number;         // 0.0 – 1.0; lower = more credible
  topCategoryScore: number;   // trust index within category
  videosThisMonth: number;    // Count of videos processed in current month
  inactiveMonths: number;     // Count of consecutive months with 0 uploads
  weakMonths: number;         // Count of consecutive months below current tier threshold
  recoveryStreak: number;     // Consecutive videos with TI >= 9.0 since last downgrade
  lastUpdatedAt: number;      // epoch ms
}

// ─── Full Extended Channel Document ───────────────────────────────────────────

export interface ChannelV2 {
  // ── Existing core fields (unchanged) ──
  id: string;
  ownerId: string;
  handle: string;
  displayName: string;
  about: string;
  type: ChannelType;
  outstandingCosts: number;
  hasPaidSubscriptionBuyout: boolean;
  createdAt: number;
  updatedAt: number;

  stats: {
    videoCount: number;
    channelRating?: number;
    avgTrustIndex: number;
    subscriberCount: number;
    viewCount: number;
  };

  settings: {
    adsEnabled: boolean;
    adsRevenueShare: number;
    memberRevenueShare: number;
    locale: string;
    defaultPlatform: string;
  };

  limits: {
    maxDurationSec: number;
    maxChannels: number;
  };

  // ── Phase 2 additions ──
  profile: ChannelProfile;
  reputation: ChannelReputation;
  verification: VerificationState;
}

// ─── Type History ─────────────────────────────────────────────────────────────

export interface TypeHistory {
  id: string;
  channelId: string;
  userId: string;
  oldType: ChannelType;
  newType: ChannelType;
  reason: "manual" | "settlement" | "maintenance";
  timestamp: number;
  processedAt: string; // ISO string for human readability
}

// ─── Validation ───────────────────────────────────────────────────────────────

export const VALID_CATEGORIES: ChannelCategory[] = [
  "news", "politics", "science", "health", "finance",
  "technology", "environment", "education", "culture", "other",
];

export const VALID_PLATFORMS = ["youtube", "twitter", "instagram", "website", "linkedin"];

// ─── Phase 3: Discovery & Social Constants ───────────────────────────────────

export const RANK_WEIGHTS = {
  TRUST_INDEX: 0.60,
  SUBSCRIBERS:   0.15, // log-scaled
  TREND_30D:   0.15,
  COVERAGE:    0.10, // fact-checked coverage percentage
};

export const BADGE_TIERS = {
  ELITE:    { minTrust: 9.5, minVideos: 10, color: "#fbbf24", label: "Elite" },
  ADVANCED: { minTrust: 9.0, minVideos: 5,  color: "#9333ea", label: "Advanced" },
  CREATOR:  { minTrust: 8.0, minVideos: 3,  color: "#3b82f6", label: "Creator" },
  BASIC:    { minTrust: 0.0, minVideos: 0,  color: "#10b981", label: "Basic" },
};
