import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/feed_algorithm_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/session_interest_tracker.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/data/repositories/admin_repository_impl.dart';
import 'package:truthworld/data/repositories/advertiser_repository_impl.dart';
import 'package:truthworld/data/repositories/analytics_repository_impl.dart';
import 'package:truthworld/data/repositories/channel_repository_impl.dart';
import 'package:truthworld/data/repositories/comment_repository_impl.dart';
import 'package:truthworld/data/repositories/community_repository_impl.dart';
import 'package:truthworld/data/repositories/dashboard_repository_impl.dart';
import 'package:truthworld/data/repositories/home_repository_impl.dart';
import 'package:truthworld/data/repositories/library_repository_impl.dart';
import 'package:truthworld/data/repositories/notification_repository_impl.dart';
import 'package:truthworld/data/repositories/playlist_repository_impl.dart';
import 'package:truthworld/data/repositories/search_repository_impl.dart';
import 'package:truthworld/data/repositories/video_repository_impl.dart';
import 'package:truthworld/domain/repositories/admin_repository.dart';
import 'package:truthworld/domain/repositories/advertiser_repository.dart';
import 'package:truthworld/domain/repositories/analytics_repository.dart';
import 'package:truthworld/domain/repositories/channel_repository.dart';
import 'package:truthworld/domain/repositories/comment_repository.dart';
import 'package:truthworld/domain/repositories/community_repository.dart';
import 'package:truthworld/domain/repositories/dashboard_repository.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/domain/repositories/library_repository.dart';
import 'package:truthworld/domain/repositories/notification_repository.dart';
import 'package:truthworld/domain/repositories/playlist_repository.dart';
import 'package:truthworld/domain/repositories/search_repository.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/impression_tracking_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/features/miniplayer/presentation/bindings/miniplayer_binding.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/saved_videos_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    /// ❌ DO NOT put AuthService here anymore
    /// It must be initialized in main() using Get.putAsync()

    // Initialize miniplayer
    MiniplayerBinding().dependencies();

    // Audio service
    Get.lazyPut(AudioOnlyService.new, fenix: true);
    Get.lazyPut(AdService.new, fenix: true);

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
    Get.lazyPut<VideoRepository>(VideoRepositoryImpl.new, fenix: true);
    Get.lazyPut<ChannelRepository>(ChannelRepositoryImpl.new, fenix: true);
    Get.lazyPut<CommentRepository>(CommentRepositoryImpl.new, fenix: true);
    Get.lazyPut<CommunityRepository>(
      CommunityRepositoryImpl.new,
      fenix: true,
    );
    Get.lazyPut<PlaylistRepository>(
      PlaylistRepositoryImpl.new,
      fenix: true,
    );
    Get.lazyPut<NotificationRepository>(
      NotificationRepositoryImpl.new,
      fenix: true,
    );
    Get.lazyPut<SearchRepository>(SearchRepositoryImpl.new, fenix: true);
    Get.lazyPut<HomeRepository>(HomeRepositoryImpl.new, fenix: true);
    Get.lazyPut<AdminRepository>(AdminRepositoryImpl.new, fenix: true);
    Get.lazyPut<DashboardRepository>(DashboardRepositoryImpl.new, fenix: true);
    Get.lazyPut<AdvertiserRepository>(AdvertiserRepositoryImpl.new, fenix: true);
    Get.lazyPut<AnalyticsRepository>(AnalyticsRepositoryImpl.new, fenix: true);
    Get.lazyPut<LibraryRepository>(LibraryRepositoryImpl.new, fenix: true);
    Get.lazyPut(TopicRepository.new, fenix: true);

    // Topic Controllers
    Get.lazyPut(FollowingTopicsController.new, fenix: true);
    Get.lazyPut(ExploreTopicsController.new, fenix: true);
    Get.lazyPut(TopicController.new, fenix: true);
    Get.lazyPut(CreateTopicController.new, fenix: true);

    // Core Feature Controllers
    Get.lazyPut(UserSettingsController.new, fenix: true);
    Get.lazyPut(PlaylistController.new, fenix: true);
    Get.lazyPut(SubscriptionController.new, fenix: true);
    Get.lazyPut(WatchHistoryController.new, fenix: true);
    Get.lazyPut(SavedVideosController.new, fenix: true);
  }
}
