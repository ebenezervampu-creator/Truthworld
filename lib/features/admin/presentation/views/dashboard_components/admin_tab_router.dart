import 'package:flutter/material.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/ad_reports_tab.dart';
import 'package:truthworld/features/admin/presentation/views/ads_tab.dart';
import 'package:truthworld/features/admin/presentation/views/alerts_config_tab.dart';
import 'package:truthworld/features/admin/presentation/views/analytics_tab.dart';
import 'package:truthworld/features/admin/presentation/views/appeals_tab.dart';
import 'package:truthworld/features/admin/presentation/views/audit_logs_tab.dart';
import 'package:truthworld/features/admin/presentation/views/broadcast_push_tab.dart';
import 'package:truthworld/features/admin/presentation/views/channel_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/dubbing_management_tab.dart';
import 'package:truthworld/features/admin/presentation/views/feedbacks_tab.dart';
import 'package:truthworld/features/admin/presentation/views/help_support_tab.dart';
import 'package:truthworld/features/admin/presentation/views/image_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/overview_tab.dart';
import 'package:truthworld/features/admin/presentation/views/reports_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/security_tab.dart';
import 'package:truthworld/features/admin/presentation/views/team_management_tab.dart';
import 'package:truthworld/features/admin/presentation/views/topic_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/user_management_tab.dart';
import 'package:truthworld/features/admin/presentation/views/video_queue_tab.dart';

class AdminTabRouter {
  const AdminTabRouter._();

  static Widget buildTabForId(
    String tabId,
    BuildContext context,
    AdminController controller,
  ) {
    switch (tabId) {
      case 'videos':
        return VideoQueueTab(controller: controller);
      case 'topics':
        return TopicQueueTab(controller: controller);
      case 'images':
        return ImageQueueTab(controller: controller);
      case 'channels':
        return ChannelQueueTab(controller: controller);
      case 'reports':
        return ReportsQueueTab(controller: controller);
      case 'logs':
        return AuditLogsTab(controller: controller);
      case 'users':
        return UserManagementTab(controller: controller);
      case 'dubbing':
        return DubbingManagementTab(controller: controller);
      case 'ads':
        return AdsTab(controller: controller);
      case 'ad_reports':
        return AdReportsTab(controller: controller);
      case 'analytics':
        return AnalyticsTab(controller: controller);
      case 'alerts':
        return AlertsConfigTab(controller: controller);
      case 'appeals':
        return AppealsTab(controller: controller);
      case 'security':
        return SecurityTab(controller: controller);
      case 'feedbacks':
        return FeedbacksTab(controller: controller);
      case 'team':
        return TeamManagementTab(controller: controller);
      case 'help':
        return HelpSupportTab(controller: controller);
      case 'broadcast':
        return BroadcastPushTab(controller: controller);
      default:
        return OverviewTab(controller: controller);
    }
  }
}
