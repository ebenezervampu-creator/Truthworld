import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
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
    Get.lazyPut<DashboardController>(DashboardController.new, fenix: true);

    // Core dashboard controllers
    Get.lazyPut(DashboardCommentsController.new, fenix: true);
    Get.lazyPut(SubtitlesController.new, fenix: true);
    Get.lazyPut(ChaptersController.new, fenix: true);
    Get.lazyPut(AudioTracksController.new, fenix: true);
    Get.lazyPut(() => CustomizationController(channelId: '', ownerId: ''), fenix: true);
    Get.lazyPut(TopicManagementController.new, fenix: true);
    Get.lazyPut(AudienceController.new, fenix: true);
    Get.lazyPut(DashboardViewController.new, fenix: true);
    Get.lazyPut(() => ChannelNotificationsController(channelId: '', creatorId: ''), fenix: true);
    Get.lazyPut(MultiAudioPlayerController.new, fenix: true);
    Get.lazyPut(StudioSettingsController.new, fenix: true);
    Get.lazyPut(DraftsController.new, fenix: true);
    Get.lazyPut(PlaylistsManagementController.new, fenix: true);
    Get.lazyPut(() => TrashRestoreController(channelId: ''), fenix: true);
  }
}
