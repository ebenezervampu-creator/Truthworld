import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/drafts_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';

/// Binding for the Creator Dashboard feature.
///
/// All dashboard controllers are lazily registered — they are only
/// instantiated when the specific dashboard sub-page is navigated to.
/// Controllers requiring channelId resolve it dynamically from AuthService
/// at instantiation time, never from empty placeholder strings.
class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    // Core controllers
    Get.lazyPut<HomeController>(HomeController.new, fenix: true);
    Get.lazyPut<ChannelController>(ChannelController.new, fenix: true);
    Get.lazyPut<ChannelSubscriptionController>(
      ChannelSubscriptionController.new,
      fenix: true,
    );
    Get.lazyPut<ChannelWizardViewController>(
      ChannelWizardViewController.new,
      fenix: true,
    );

    // Core dashboard controllers
    // NOTE: DashboardController is NOT registered here — it is created
    // by DashboardViewController.onInit() with the resolved channelId,
    // preventing split-state from dual registration.
    Get.lazyPut(DashboardCommentsController.new, fenix: true);
    Get.lazyPut(SubtitlesController.new, fenix: true);
    Get.lazyPut(ChaptersController.new, fenix: true);
    Get.lazyPut(AudioTracksController.new, fenix: true);
    Get.lazyPut(() {
      final channelId = _resolveChannelId();
      final ownerId = _resolveOwnerId();
      return CustomizationController(channelId: channelId, ownerId: ownerId);
    }, fenix: true);
    Get.lazyPut(TopicManagementController.new, fenix: true);
    Get.lazyPut(AudienceController.new, fenix: true);
    Get.lazyPut(DashboardViewController.new, fenix: true);
    Get.lazyPut(() {
      final channelId = _resolveChannelId();
      final creatorId = _resolveOwnerId();
      return ChannelNotificationsController(
        channelId: channelId,
        creatorId: creatorId,
      );
    }, fenix: true);
    Get.lazyPut(MultiAudioPlayerController.new, fenix: true);
    Get.lazyPut(StudioSettingsController.new, fenix: true);
    Get.lazyPut(DraftsController.new, fenix: true);
    Get.lazyPut(PlaylistsManagementController.new, fenix: true);
    Get.lazyPut(() {
      final channelId = _resolveChannelId();
      return TrashRestoreController(channelId: channelId);
    }, fenix: true);
  }

  /// Resolves the active channel ID from AuthService at binding instantiation
  /// time. Returns empty string only as a last resort; consumers must handle
  /// that edge-case gracefully.
  static String _resolveChannelId() {
    if (Get.isRegistered<DashboardController>()) {
      final id = Get.find<DashboardController>().channelId;
      if (id.isNotEmpty) return id;
    }
    if (Get.isRegistered<AuthService>()) {
      final channel = AuthService.to.userChannel ?? AuthService.to.rxUserChannel.value;
      if (channel != null && channel.id.isNotEmpty) {
        return channel.id;
      }
    }
    return '';
  }

  /// Resolves the active user/owner ID from AuthService.
  static String _resolveOwnerId() {
    if (Get.isRegistered<AuthService>()) {
      final uid = AuthService.to.uid;
      if (uid.isNotEmpty) return uid;
    }
    return '';
  }
}
