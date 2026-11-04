export type NotificationLifecycle = "NEW" | "DELIVERED" | "UNREAD" | "READ" | "ARCHIVED" | "DELETED";

export type NotificationPriority = "critical" | "high" | "medium" | "low";

export type NotificationSeverity = "info" | "success" | "warning" | "priority";

export type NotificationCategory =
  | "growth"
  | "analytics"
  | "verification"
  | "policy"
  | "monetization"
  | "community"
  | "education"
  | "system"
  | "collaboration"
  | "sponsorship"
  | "beta"
  | "security";

export type NotificationType =
  | "sub_milestone"
  | "view_milestone"
  | "performance_insight"
  | "retention_spike"
  | "verification_result"
  | "batch_verification_result"
  | "copyright_claim"
  | "creator_coach_insight"
  | "creator_motivation"
  | "monetization_revenue"
  | "monetization_payout"
  | "monetization_refund"
  | "lip_sync_credit"
  | "membership_milestone"
  | "ranking_change"
  | "new_video_followed"
  | "new_community_post"
  | "new_video_topic"
  | "trust_score_change"
  | "tier_promotion"
  | "tier_downgrade"
  | "inactivity_warning"
  | "performance_warning"
  | "milestone_achieved"
  | "system_announcement"
  | "new_follower"
  | "weekly_digest"
  | "comment"
  | "comment_like"
  | "comment_reply"
  | "mention"
  | "channel_health"
  | "channel_notifications"
  | "studio_notifications"
  | "video_processing"
  | "video_processing_started"
  | "video_processing_completed"
  | "video_processing_failed"
  | "channel_policy"
  | "video_policy";

export interface CreatorEvent {
  eventId: string;
  creatorId: string;
  type: string;
  source: string;
  occurredAt: number;
  payload: Record<string, any>;
  version: number;
}

export interface RichAnalyticsSnapshot {
  views: number;
  subscribers: number;
  likes: number;
  comments: number;
  shares: number;
  watchHours: number;
  ctr: number;
  avd: number;
  subscriberDelta: number;
  snapshotAt: number;
}

export interface DeliveryChannels {
  studio: boolean;
  push: boolean;
  email: boolean;
  mobile: boolean;
}

export interface NotificationAction {
  id: string;
  label: string;
  type:
    | "OPEN_ANALYTICS"
    | "OPEN_VIDEO"
    | "APPEAL_VERIFICATION"
    | "EDIT_METADATA"
    | "SHARE_ACHIEVEMENT"
    | "OPEN_REVENUE"
    | "VIEW_REPORT";
  payload?: Record<string, any>;
}

export interface VerificationMetadata {
  videoId: string;
  videoTitle: string;
  status: "approved" | "flagged" | "rejected";
  primaryReason: string;
  confidenceScore: number;
  flaggedFrames?: string[];
  recommendedFix?: string;
  reportId?: string;
  estimatedReviewMinutes?: number;
}

export interface MilestoneMetadata {
  milestoneType: "subscribers" | "views";
  currentValue: number;
  previousValue: number;
  deltaSinceLastMilestone: number;
  videoTitle?: string;
  videoId?: string;
  badgeUrl?: string;
}

export interface CoachMetadata {
  adviceCategory: "consistency" | "retention" | "thumbnail" | "seo" | "general";
  headline: string;
  suggestedAction: string;
  confidenceScore: number;
  memorySummary?: string;
}

export interface RevenueMetadata {
  estimatedEarnings: number;
  currency: string;
  period: string;
  payoutStatus?: string;
}

export interface AnalyticsMetadata {
  metricName: string;
  growthPercentage: number;
  comparisonRatio: number;
  videoId?: string;
  videoTitle?: string;
}

export interface UserNotification {
  id: string;
  userId: string;
  type: NotificationType;
  severity: NotificationSeverity;
  title: string;
  message: string;
  actionUrl?: string;
  metadata?: Record<string, any>;
  read: boolean;
  createdAt: number;
  pushSent?: boolean;
}

export interface StudioNotification {
  id: string;
  eventId: string;
  schemaVersion: number;
  creatorId: string;
  type: NotificationType;
  category: NotificationCategory;
  priority: NotificationPriority;
  rankingScore: number;
  status: NotificationLifecycle;
  title: string;
  message: string;
  thumbnailUrl?: string;
  createdAt: number;
  readAt?: number;
  expiresAt?: number;
  delivery: DeliveryChannels;
  actions: NotificationAction[];
  analyticsSnapshot?: RichAnalyticsSnapshot;
  verificationReportId?: string;
  metadata?: Record<string, any>;
}
