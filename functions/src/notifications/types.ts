export type NotificationType =
  | "ranking_change"
  | "milestone_achieved"
  | "new_video_followed"
  | "trust_score_change"
  | "new_follower"
  | "weekly_digest"
  | "tier_promotion"
  | "tier_downgrade"
  | "inactivity_warning"
  | "performance_warning"
  | "system_announcement"
  | "comment_like"
  | "comment_reply";

export type NotificationSeverity = "info" | "success" | "warning" | "priority";

export interface UserNotification {
  id: string;
  userId: string;
  type: NotificationType;
  severity: NotificationSeverity;
  title: string;
  message: string;
  actionUrl?: string; // Link to profile, video, or leaderboard
  metadata?: Record<string, any>;
  read: boolean;
  createdAt: number;
}

export interface Milestone {
  id: string;
  type: "trust_score" | "follower_count" | "ranking";
  value: number;
  label: string;
  badgeColor: string;
}
