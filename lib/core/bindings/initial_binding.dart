import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/impression_tracking_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/session_interest_tracker.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/services/algorithm/feed_algorithm_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/bindings/miniplayer_binding.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    /// ❌ DO NOT put AuthService here anymore
    /// It must be initialized in main() using Get.putAsync()

    // Initialize miniplayer
    MiniplayerBinding().dependencies();

    // Core analytics services (lazy, fenix for recreation if needed)
    Get.lazyPut(GeolocationService.new, fenix: true);
    Get.lazyPut(VideoAnalyticsService.new, fenix: true);
    Get.lazyPut(ViewerIdentityService.new, fenix: true);
    Get.lazyPut(ImpressionTrackingService.new, fenix: true);
    Get.lazyPut(WatchHistoryService.new, fenix: true);

    // Truthworld Personalization Engine Services
    Get.lazyPut(FlipCoinService.new, fenix: true);
    Get.lazyPut(SessionInterestTracker.new, fenix: true);
    Get.lazyPut(UserInterestProfileService.new, fenix: true);
    Get.lazyPut(AlgorithmRemoteConfig.new, fenix: true);
    Get.lazyPut(TruthworldAlgorithm.new, fenix: true);
    Get.lazyPut(UserSignalTracker.new, fenix: true);
    Get.lazyPut(FeedAlgorithmService.new, fenix: true);

    // Controllers (lazy for performance)
    Get.lazyPut(MainController.new, fenix: true);
    Get.lazyPut(PlaylistController.new, fenix: true);
  }
}
