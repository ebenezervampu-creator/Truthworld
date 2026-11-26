import { ChannelType } from "../pipeline/types";

// ─── Phase 2: Public Channel Profile ─────────────────────────────────────────

// ─── Verification ─────────────────────────────────────────────────────────────

export type VerificationState =
  | "unverified"
  | "verified"       // identity confirmed
  | "trusted"        // legacy verification level
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
  verification: VerificationState;
  reputation?: {
    avgTrustIndex: number;
    score?: number;
    badgeTier?: string;
    totalEvaluations?: number;
    [key: string]: any;
  };
}

export const BADGE_TIERS = {
  ELITE: { minTrust: 9.0, color: "#38bdf8", label: "Platinum" },
  ADVANCED: { minTrust: 8.0, color: "#fbbf24", label: "Gold" },
  CREATOR: { minTrust: 7.0, color: "#94a3b8", label: "Silver" },
  BASIC: { minTrust: 0.0, color: "#64748b", label: "Standard" },
};

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

