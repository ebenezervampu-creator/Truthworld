import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/drafts_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';

/// Binding for the Creator Dashboard feature.
///
/// All dashboard controllers are lazily registered — they are only
/// instantiated when the specific dashboard sub-page is navigated to.
class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    // Core dashboard controllers
    Get.lazyPut(DashboardCommentsController.new, fenix: true);
    Get.lazyPut(SubtitlesController.new, fenix: true);
    Get.lazyPut(ChaptersController.new, fenix: true);
    Get.lazyPut(AudioTracksController.new, fenix: true);
    Get.lazyPut(() => CustomizationController(channelId: '', ownerId: ''), fenix: true);
    Get.lazyPut(TopicManagementController.new, fenix: true);
    Get.lazyPut(AudienceController.new, fenix: true);
    Get.lazyPut(CategoryInsightsController.new, fenix: true);
    Get.lazyPut(() => CreatorIntelligenceController(channelId: '', creatorId: ''), fenix: true);
    Get.lazyPut(MultiAudioPlayerController.new, fenix: true);
    Get.lazyPut(StudioSettingsController.new, fenix: true);
    Get.lazyPut(DraftsController.new, fenix: true);
    Get.lazyPut(PlaylistsManagementController.new, fenix: true);
    Get.lazyPut(() => TrashRestoreController(channelId: ''), fenix: true);
  }
}
