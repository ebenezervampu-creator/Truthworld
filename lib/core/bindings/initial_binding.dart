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
import 'package:truthworld/features/miniplayer/presentation/bindings/miniplayer_binding.dart';
import 'package:truthworld/data/repositories/channel_repository_impl.dart';
import 'package:truthworld/data/repositories/comment_repository_impl.dart';
import 'package:truthworld/data/repositories/community_repository_impl.dart';
import 'package:truthworld/data/repositories/notification_repository_impl.dart';
import 'package:truthworld/data/repositories/playlist_repository_impl.dart';
import 'package:truthworld/data/repositories/search_repository_impl.dart';
import 'package:truthworld/data/repositories/video_repository_impl.dart';
import 'package:truthworld/domain/repositories/channel_repository.dart';
import 'package:truthworld/domain/repositories/comment_repository.dart';
import 'package:truthworld/domain/repositories/community_repository.dart';
import 'package:truthworld/domain/repositories/notification_repository.dart';
import 'package:truthworld/domain/repositories/playlist_repository.dart';
import 'package:truthworld/domain/repositories/search_repository.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';

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

    // Repositories
    Get.lazyPut<VideoRepository>(() => VideoRepositoryImpl(), fenix: true);
    Get.lazyPut<ChannelRepository>(() => ChannelRepositoryImpl(), fenix: true);
    Get.lazyPut<CommentRepository>(() => CommentRepositoryImpl(), fenix: true);
    Get.lazyPut<CommunityRepository>(
      () => CommunityRepositoryImpl(),
      fenix: true,
    );
    Get.lazyPut<PlaylistRepository>(
      () => PlaylistRepositoryImpl(),
      fenix: true,
    );
    Get.lazyPut<NotificationRepository>(
      () => NotificationRepositoryImpl(),
      fenix: true,
    );
    Get.lazyPut<SearchRepository>(() => SearchRepositoryImpl(), fenix: true);
  }
}
