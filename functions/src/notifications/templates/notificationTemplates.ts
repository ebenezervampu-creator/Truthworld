import { NotificationCategory, NotificationPriority, NotificationAction } from "../types";

export interface TemplateDefinition {
  templateId: string;
  version: number;
  category: NotificationCategory;
  priority: NotificationPriority;
  titleTemplate: string;
  messageTemplate: string;
  defaultActions: NotificationAction[];
  ttlDays?: number;
}

export const TEMPLATE_REGISTRY: Record<string, TemplateDefinition> = {
  "verification_rejected_v1": {
    templateId: "verification_rejected_v1",
    version: 1,
    category: "verification",
    priority: "critical",
    titleTemplate: "Truth Verification Action Required: {{videoTitle}}",
    messageTemplate: "Your video '{{videoTitle}}' was flagged by Truth Verification ({{confidencePercent}}% AI synthetic confidence). Primary reason: {{reason}}.",
    defaultActions: [
      { id: "act_audit", label: "View Audit Report", type: "VIEW_REPORT" },
      { id: "act_appeal", label: "Submit Appeal", type: "APPEAL_VERIFICATION" },
      { id: "act_edit", label: "Edit Metadata", type: "EDIT_METADATA" }
    ]
  },
  "subscribers_milestone_v1": {
    templateId: "subscribers_milestone_v1",
    version: 1,
    category: "growth",
    priority: "high",
    titleTemplate: "🎉 Milestone Achieved: {{targetValue}} Subscribers!",
    messageTemplate: "Congratulations! Your channel reached {{targetValue}} subscribers (+{{delta}} this week). Keep up the momentum!",
    defaultActions: [
      { id: "act_analytics", label: "View Channel Analytics", type: "OPEN_ANALYTICS" },
      { id: "act_share", label: "Share Achievement", type: "SHARE_ACHIEVEMENT" }
    ]
  },
  "views_milestone_v1": {
    templateId: "views_milestone_v1",
    version: 1,
    category: "growth",
    priority: "high",
    titleTemplate: "🚀 {{videoTitle}} Hit {{targetValue}} Views!",
    messageTemplate: "Your popular video '{{videoTitle}}' crossed {{targetValue}} total views!",
    defaultActions: [
      { id: "act_video", label: "Open Video", type: "OPEN_VIDEO" },
      { id: "act_analytics", label: "Analyze Performance", type: "OPEN_ANALYTICS" }
    ]
  },
  "coach_growth_tip_v1": {
    templateId: "coach_growth_tip_v1",
    version: 1,
    category: "education",
    priority: "medium",
    titleTemplate: "💡 AI Creator Coach: {{headline}}",
    messageTemplate: "{{suggestedAction}}",
    defaultActions: [
      { id: "act_analytics", label: "View Analytics", type: "OPEN_ANALYTICS" }
    ],
    ttlDays: 30
  }
};
