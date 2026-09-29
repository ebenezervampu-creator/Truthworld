import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Base controller containing shared state and contract definitions
/// for [HomeFeedController] and its modular mixins.
abstract class HomeFeedControllerBase extends BaseController {
  AuthService get authService;
  FirebaseFirestore get firestore;
  FeedCacheManager get feedCacheManager;
  HomeRepository? get homeRepository;
  set homeRepository(HomeRepository? repo);

  // Observable feeds
  final RxList<Video> videos = <Video>[].obs;
  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxList<dynamic> homeFeedItems = <dynamic>[].obs;

  // Pagination & Loading States
  final RxBool isLoadingVideos = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool rxHasMore = true.obs;
  DocumentSnapshot? lastDocument;

  static const int pageSize = 24;
  static const int loadMoreThreshold = 90;

  // Scroll Management
  final ScrollController scrollController = ScrollController();
  double lastScrollPosition = 0;
  static const double kScrollThreshold = 8;

  // Carousel Observables
  final RxList<Video> recommendedVideos = <Video>[].obs;
  final RxList<Video> musicVideos = <Video>[].obs;
  final RxList<Video> trendingVideos = <Video>[].obs;
  final RxBool isCarouselLoading = true.obs;

  /// Currently selected category from [HomeDiscoveryController] or default 'All'.
  String get selectedCategory {
    if (Get.isRegistered<HomeDiscoveryController>()) {
      return Get.find<HomeDiscoveryController>().selectedCategory.value;
    }
    return 'All';
  }

  /// Current authenticated user ID if available.
  String? get currentUserId => authService.user?.uid;

  @override
  bool get isItemsEmpty => homeFeedItems.isEmpty && videos.isEmpty;

  // --- Abstract Cross-Mixin Coordination Hooks ---
  bool matchesCategory(Video v, String cat);
  Set<String> getWatchedVideoIds();
  void pruneWatchedVideosFromUnexplored();
  void rerankActiveFeedOnProfileUpdate();
  void loadCachedVideos([String? category]);
  void saveVideosToCache([String? category]);
  void mixHomeFeed();

  Query buildCategoryQuery({DocumentSnapshot? startAfter});
  Future<void> fetchMoreVideos();
  Future<void> fetchInitialVideos();
  Future<void> fetchInitialVideosInternal();
  Future<void> fetchMainFeedVideos();
  Future<void> fetchTrendingTabVideos();
  Future<void> fetchPopularTabVideos();
  Future<void> fetchNewTabVideos();
  Future<void> fetchUnexploredTabVideos();
  Future<void> fetchFlipCoinTabVideos();
  Future<void> fetchCategoryTabVideos(String category);

  Future<void> fetchCarouselVideos();
  Future<void> fetchCarouselVideosInternal();
  Future<void> fetchCommunityPosts();
  Future<void> fetchInitialCommunityPostsTab();
  Future<void> fetchMoreCommunityPostsTab();
}
