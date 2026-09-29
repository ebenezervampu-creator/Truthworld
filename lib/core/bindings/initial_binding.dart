import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/feed_algorithm_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/session_interest_tracker.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/digital_wellbeing_service.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/data/datasources/remote/channel_remote_datasource.dart';
import 'package:truthworld/data/datasources/remote/video_remote_datasource.dart';
import 'package:truthworld/data/repositories/admin_repository_impl.dart';
import 'package:truthworld/data/repositories/advertiser_repository_impl.dart';
import 'package:truthworld/data/repositories/analytics_repository_impl.dart';
import 'package:truthworld/data/repositories/category_repository_impl.dart';
import 'package:truthworld/data/repositories/channel_repository_impl.dart';
import 'package:truthworld/data/repositories/comment_repository_impl.dart';
import 'package:truthworld/data/repositories/community_repository_impl.dart';
import 'package:truthworld/data/repositories/dashboard_repository_impl.dart';
import 'package:truthworld/data/repositories/feedback_repository_impl.dart';
import 'package:truthworld/data/repositories/hashtag_repository_impl.dart';
import 'package:truthworld/data/repositories/home_repository_impl.dart';
import 'package:truthworld/data/repositories/library_repository_impl.dart';
import 'package:truthworld/data/repositories/notification_repository_impl.dart';
import 'package:truthworld/data/repositories/playlist_repository_impl.dart';
import 'package:truthworld/data/repositories/premium_repository_impl.dart';
import 'package:truthworld/data/repositories/search_repository_impl.dart';
import 'package:truthworld/data/repositories/subscription_repository_impl.dart';
import 'package:truthworld/data/repositories/trending_repository_impl.dart';
import 'package:truthworld/data/repositories/video_repository_impl.dart';
import 'package:truthworld/data/repositories/watchtime_repository_impl.dart';
import 'package:truthworld/domain/repositories/admin_repository.dart';
import 'package:truthworld/domain/repositories/advertiser_repository.dart';
import 'package:truthworld/domain/repositories/analytics_repository.dart';
import 'package:truthworld/domain/repositories/category_repository.dart';
import 'package:truthworld/domain/repositories/channel_repository.dart';
import 'package:truthworld/domain/repositories/comment_repository.dart';
import 'package:truthworld/domain/repositories/community_repository.dart';
import 'package:truthworld/domain/repositories/dashboard_repository.dart';
import 'package:truthworld/domain/repositories/feedback_repository.dart';
import 'package:truthworld/domain/repositories/hashtag_repository.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/domain/repositories/library_repository.dart';
import 'package:truthworld/domain/repositories/notification_repository.dart';
import 'package:truthworld/domain/repositories/playlist_repository.dart';
import 'package:truthworld/domain/repositories/premium_repository.dart';
import 'package:truthworld/domain/repositories/search_repository.dart';
import 'package:truthworld/domain/repositories/subscription_repository.dart';
import 'package:truthworld/domain/repositories/trending_repository.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/domain/repositories/watchtime_repository.dart';
import 'package:truthworld/domain/usecases/channel/get_channel_by_id_usecase.dart';
import 'package:truthworld/domain/usecases/channel/toggle_subscription_usecase.dart';
import 'package:truthworld/domain/usecases/comment/add_comment_usecase.dart';
import 'package:truthworld/domain/usecases/comment/get_comments_usecase.dart';
import 'package:truthworld/domain/usecases/community/create_community_post_usecase.dart';
import 'package:truthworld/domain/usecases/search/search_videos_usecase.dart';
import 'package:truthworld/domain/usecases/video/get_trending_videos_usecase.dart';
import 'package:truthworld/domain/usecases/video/get_video_by_id_usecase.dart';
import 'package:truthworld/domain/usecases/video/toggle_like_video_usecase.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/impression_tracking_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/video_presence_service.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/app_navigation_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/app_state_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/user_session_controller.dart';
import 'package:truthworld/features/likedvideos/presentation/controllers/likedvideos_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/bindings/miniplayer_binding.dart';
import 'package:truthworld/features/myvideos/presentation/controllers/my_videos_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_dialog_controller.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/trending/presentation/controllers/trending_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/saved_videos_controller.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Global Core App Controllers
    Get.lazyPut(AppStateController.new, fenix: true);
    Get.lazyPut(UserSessionController.new, fenix: true);
    Get.lazyPut(AppNavigationController.new, fenix: true);
    Get.lazyPut(MainController.new, fenix: true);

    // Fallback registration if AuthService was not initialized prior to route resolution
    if (!Get.isRegistered<AuthService>()) {
      Get.put(AuthService(), permanent: true);
    }

    // Initialize Picture-in-Picture Service
    if (!Get.isRegistered<PipService>()) {
      Get.put(PipService(), permanent: true);
    }

    // Initialize miniplayer
    MiniplayerBinding().dependencies();

    // Audio service
    Get.lazyPut(AudioOnlyService.new, fenix: true);
    Get.lazyPut(AdService.new, fenix: true);

    // Core analytics services (lazy, fenix for recreation if needed)
    Get.lazyPut(GeolocationService.new, fenix: true);
    if (!Get.isRegistered<CurrencyLocalizationService>()) {
      Get.put(CurrencyLocalizationService(), permanent: true);
    }
    Get.lazyPut(VideoAnalyticsService.new, fenix: true);
    Get.lazyPut(VideoPresenceService.new, fenix: true);
    Get.lazyPut(ViewerIdentityService.new, fenix: true);
    Get.lazyPut(ImpressionTrackingService.new, fenix: true);
    Get.lazyPut(WatchHistoryService.new, fenix: true);
    Get.lazyPut(DistributedCounterService.new, fenix: true);

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
    Get.lazyPut<CategoryRepository>(CategoryRepositoryImpl.new, fenix: true);
    Get.lazyPut<FeedbackRepository>(FeedbackRepositoryImpl.new, fenix: true);
    Get.lazyPut<HashtagRepository>(HashtagRepositoryImpl.new, fenix: true);
    Get.lazyPut<PremiumRepository>(PremiumRepositoryImpl.new, fenix: true);
    Get.lazyPut<SubscriptionRepository>(
      SubscriptionRepositoryImpl.new,
      fenix: true,
    );
    Get.lazyPut<TrendingRepository>(TrendingRepositoryImpl.new, fenix: true);
    Get.lazyPut<WatchTimeRepository>(WatchTimeRepositoryImpl.new, fenix: true);
    Get.lazyPut(TopicRepository.new, fenix: true);

    Get.lazyPut<VideoRemoteDataSource>(FirestoreVideoRemoteDataSource.new, fenix: true);
    Get.lazyPut<ChannelRemoteDataSource>(FirestoreChannelRemoteDataSource.new, fenix: true);

    // Clean Architecture Domain Use Cases
    Get.lazyPut(() => GetTrendingVideosUseCase(Get.find<TrendingRepository>()), fenix: true);
    Get.lazyPut(() => GetVideoByIdUseCase(Get.find<VideoRepository>()), fenix: true);
    Get.lazyPut(() => ToggleLikeVideoUseCase(Get.find<VideoRepository>()), fenix: true);
    Get.lazyPut(() => SearchVideosUseCase(Get.find<SearchRepository>()), fenix: true);
    Get.lazyPut(() => GetChannelByIdUseCase(Get.find<ChannelRepository>()), fenix: true);
    Get.lazyPut(() => ToggleSubscriptionUseCase(Get.find<ChannelRepository>()), fenix: true);
    Get.lazyPut(() => AddCommentUseCase(Get.find<CommentRepository>()), fenix: true);
    Get.lazyPut(() => GetCommentsUseCase(Get.find<CommentRepository>()), fenix: true);
    Get.lazyPut(() => CreateCommunityPostUseCase(Get.find<CommunityRepository>()), fenix: true);

    // Topic Controllers (lazy, disposed when out of view)
    Get.lazyPut(FollowingTopicsController.new);
    Get.lazyPut(ExploreTopicsController.new);
    Get.lazyPut(TopicController.new);
    Get.lazyPut(CreateTopicController.new);

    // Core Feature Controllers
    if (!Get.isRegistered<UserSettingsController>()) {
      Get.lazyPut(UserSettingsController.new, fenix: true);
    }
    Get.lazyPut(DigitalWellbeingService.new, fenix: true);
    Get.lazyPut(PlaylistController.new, fenix: true);
    Get.lazyPut(PlaylistDialogController.new, fenix: true);
    Get.lazyPut(SubscriptionController.new, fenix: true);
    Get.lazyPut(ChannelSubscriptionController.new, fenix: true);
    Get.lazyPut(WatchHistoryController.new, fenix: true);
    Get.lazyPut(SavedVideosController.new, fenix: true);
    Get.lazyPut(UserClipsController.new, fenix: true);
    Get.lazyPut(TrendingController.new, fenix: true);
    Get.lazyPut(MyVideosController.new, fenix: true);
    Get.lazyPut(LikedVideosController.new, fenix: true);
    Get.lazyPut(DownloadsController.new, fenix: true);
  }
}
