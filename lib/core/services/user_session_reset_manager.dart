import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/copyright_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/drafts_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/edit_video_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/notifications/presentation/controllers/notification_view_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';

/// Centralized manager to safely wipe and reset all user-scoped and Studio-scoped
/// controller state and caches across sign-out and account-switching operations.
class UserSessionResetManager {
  UserSessionResetManager._();

  static void resetAllUserSessions() {
    try {
      // 1. Studio Dashboard Core Controllers
      if (Get.isRegistered<DashboardController>()) {
        try {
          final ctrl = Get.find<DashboardController>();
          ctrl.setSelectedIndex(1);
          ctrl.clearData();
        } catch (_) {}
        Get.delete<DashboardController>(force: true);
      }
      if (Get.isRegistered<DashboardViewController>()) {
        try {
          Get.find<DashboardViewController>().clearChannelSession();
        } catch (_) {}
        Get.delete<DashboardViewController>(force: true);
      }

      // 2. Studio Sub-Feature Controllers
      if (Get.isRegistered<StudioSettingsController>()) {
        try {
          Get.find<StudioSettingsController>().clearSettings();
        } catch (_) {}
        Get.delete<StudioSettingsController>(force: true);
      }
      if (Get.isRegistered<DashboardCommentsController>()) {
        try {
          Get.find<DashboardCommentsController>().clearData();
        } catch (_) {}
        Get.delete<DashboardCommentsController>(force: true);
      }
      if (Get.isRegistered<DraftsController>()) {
        try {
          Get.find<DraftsController>().clearDrafts();
        } catch (_) {}
        Get.delete<DraftsController>(force: true);
      }
      if (Get.isRegistered<PlaylistsManagementController>()) {
        try {
          Get.find<PlaylistsManagementController>().clearData();
        } catch (_) {}
        Get.delete<PlaylistsManagementController>(force: true);
      }
      if (Get.isRegistered<TrashRestoreController>()) {
        try {
          Get.find<TrashRestoreController>().clearData();
        } catch (_) {}
        Get.delete<TrashRestoreController>(force: true);
      }
      if (Get.isRegistered<VideoManagementController>()) {
        try {
          Get.find<VideoManagementController>().clearData();
        } catch (_) {}
        Get.delete<VideoManagementController>(force: true);
      }
      if (Get.isRegistered<TopicManagementController>()) {
        try {
          Get.find<TopicManagementController>().clearData();
        } catch (_) {}
        Get.delete<TopicManagementController>(force: true);
      }
      if (Get.isRegistered<AudienceController>()) {
        try {
          Get.find<AudienceController>().clearData();
        } catch (_) {}
        Get.delete<AudienceController>(force: true);
      }
      if (Get.isRegistered<AudioTracksController>()) {
        Get.delete<AudioTracksController>(force: true);
      }
      if (Get.isRegistered<ChaptersController>()) {
        Get.delete<ChaptersController>(force: true);
      }
      if (Get.isRegistered<SubtitlesController>()) {
        Get.delete<SubtitlesController>(force: true);
      }
      if (Get.isRegistered<CustomizationController>()) {
        Get.delete<CustomizationController>(force: true);
      }
      if (Get.isRegistered<ChannelNotificationsController>()) {
        try {
          Get.find<ChannelNotificationsController>().clearData();
        } catch (_) {}
        Get.delete<ChannelNotificationsController>(force: true);
      }
      if (Get.isRegistered<MultiAudioPlayerController>()) {
        Get.delete<MultiAudioPlayerController>(force: true);
      }
      if (Get.isRegistered<MembershipsController>()) {
        try {
          Get.find<MembershipsController>().clearData();
        } catch (_) {}
        Get.delete<MembershipsController>(force: true);
      }
      if (Get.isRegistered<CopyrightController>()) {
        Get.delete<CopyrightController>(force: true);
      }
      if (Get.isRegistered<EditVideoController>()) {
        Get.delete<EditVideoController>(force: true);
      }

      // 3. Analytics Controllers
      if (Get.isRegistered<AnalyticsController>()) {
        Get.delete<AnalyticsController>(force: true);
      }
      if (Get.isRegistered<CreatorAnalyticsController>()) {
        try {
          Get.find<CreatorAnalyticsController>().clearData();
        } catch (_) {}
        Get.delete<CreatorAnalyticsController>(force: true);
      }
      if (Get.isRegistered<RevenueAnalyticsController>()) {
        try {
          Get.find<RevenueAnalyticsController>().clearData();
        } catch (_) {}
        Get.delete<RevenueAnalyticsController>(force: true);
      }

      // 4. Channel Controllers
      if (Get.isRegistered<ChannelController>()) {
        Get.delete<ChannelController>(force: true);
      }
      if (Get.isRegistered<ChannelWizardViewController>()) {
        Get.delete<ChannelWizardViewController>(force: true);
      }
      if (Get.isRegistered<ChannelSubscriptionController>()) {
        Get.delete<ChannelSubscriptionController>(force: true);
      }
      if (Get.isRegistered<ChannelMonetizationController>()) {
        Get.delete<ChannelMonetizationController>(force: true);
      }

      // 5. Consumer & User-Scoped Controllers
      if (Get.isRegistered<WatchHistoryController>()) {
        try {
          Get.find<WatchHistoryController>().historyVideos.clear();
        } catch (_) {}
        Get.delete<WatchHistoryController>(force: true);
      }
      if (Get.isRegistered<WatchLaterController>()) {
        try {
          Get.find<WatchLaterController>().watchLaterVideos.clear();
        } catch (_) {}
        Get.delete<WatchLaterController>(force: true);
      }
      if (Get.isRegistered<UserNotificationController>()) {
        try {
          Get.find<UserNotificationController>().notifications.clear();
        } catch (_) {}
        Get.delete<UserNotificationController>(force: true);
      }
      if (Get.isRegistered<NotificationViewController>()) {
        Get.delete<NotificationViewController>(force: true);
      }
      if (Get.isRegistered<VideoFeedNotificationController>()) {
        Get.delete<VideoFeedNotificationController>(force: true);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UserSessionResetManager.resetAllUserSessions',
      );
    }
  }
}
