import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/feed_algorithm_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_navigation_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_query_builder.dart';

class HomeFeedController extends BaseController {
  final AuthService _authService = Get.find<AuthService>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FeedCacheManager _feedCacheManager = FeedCacheManager();
  late final HomeRepository homeRepository;

  final RxList<Video> videos = <Video>[].obs;
  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxList<dynamic> homeFeedItems = <dynamic>[].obs;
  
  final RxBool isLoadingVideos = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool rxHasMore = true.obs;
  DocumentSnapshot? _lastDocument;

  static const int _pageSize = 24;
  static const int _loadMoreThreshold = 90;

  final scrollController = ScrollController();
  double _lastScrollPosition = 0;
  static const double kScrollThreshold = 8;

  final RxList<Video> recommendedVideos = <Video>[].obs;
  final RxList<Video> musicVideos = <Video>[].obs;
  final RxList<Video> trendingVideos = <Video>[].obs;
  final RxBool isCarouselLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<HomeRepository>()) {
      homeRepository = Get.find<HomeRepository>();
    }
    _bindScrollListener();
    _loadCachedVideos();
    fetchInitialVideos();
    fetchCarouselVideos();
  }

  @override
  void onClose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    super.onClose();
  }

  void _bindScrollListener() {
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!scrollController.hasClients || scrollController.positions.length != 1) return;

    final position = scrollController.position;
    final currentScroll = position.pixels;

    if (Get.isRegistered<HomeNavigationController>()) {
      final navCtrl = Get.find<HomeNavigationController>();
      if (currentScroll > _lastScrollPosition && currentScroll > 50) {
        if (navCtrl.showBottomNav.value) navCtrl.showBottomNav.value = false;
      } else if (currentScroll < _lastScrollPosition) {
        if (!navCtrl.showBottomNav.value) navCtrl.showBottomNav.value = true;
      }
    }
    _lastScrollPosition = currentScroll;

    final scrollPercentage = (position.pixels / position.maxScrollExtent) * 100;

    if (scrollPercentage >= _loadMoreThreshold && !isLoadingMore.value && rxHasMore.value) {
      fetchMoreVideos();
    }
  }

  void onScrollNotification(ScrollUpdateNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return;
    if (notification.dragDetails == null) return;
    final delta = notification.scrollDelta ?? 0;
    if (delta.abs() < kScrollThreshold) return;

    if (Get.isRegistered<HomeNavigationController>()) {
      final navCtrl = Get.find<HomeNavigationController>();
      if (notification.metrics.pixels <= 0) {
        if (!navCtrl.showBottomNav.value) navCtrl.showBottomNav.value = true;
        return;
      }
      if (delta > 0) {
        if (navCtrl.showBottomNav.value) navCtrl.showBottomNav.value = false;
      } else {
        if (!navCtrl.showBottomNav.value) navCtrl.showBottomNav.value = true;
      }
    }
  }

  void _loadCachedVideos() {
    try {
      final cachedVideos = _feedCacheManager.getValidCachedVideos(FeedCacheManager.keyHomeFeed);
      if (cachedVideos != null && cachedVideos.isNotEmpty && videos.isEmpty) {
        videos.assignAll(cachedVideos);
        isLoadingVideos.value = false;
      }
    } catch (e) {
      debugPrint('HomeFeedController: Cache load error: $e');
    }
  }

  void _saveVideosToCache() {
    try {
      if (videos.isNotEmpty) {
        _feedCacheManager.saveFeedToCache(FeedCacheManager.keyHomeFeed, videos);
      }
    } catch (e) {
      debugPrint('HomeFeedController: Cache save error: $e');
    }
  }

  Future<void> fetchCarouselVideos() async {
    await safeExecute(_fetchCarouselVideosInternal, showLoading: false);
  }

  Future<void> _fetchCarouselVideosInternal() async {
    isCarouselLoading.value = true;
    try {
      final results = await Future.wait([
        _fetchPublicVideos(),
        _fetchCategoryVideos('Music'),
        _fetchPublicVideos(),
      ]);
      recommendedVideos.assignAll(results[0]);
      musicVideos.assignAll(results[1]);
      trendingVideos.assignAll(results[2]);
      clearError();
    } catch (e) {
      debugPrint('Error fetching carousel videos: $e');
    } finally {
      isCarouselLoading.value = false;
    }
  }

  Future<List<Video>> _fetchPublicVideos({int limit = 10}) async {
    final results = await VideoQueryBuilder.publicVideos(_firestore, limit: limit).get();
    final rawList = results.docs.map(Video.fromDocumentSnapshot).toList();
    return rawList.sanitizeForRecommendation();
  }

  Future<List<Video>> _fetchCategoryVideos(String category, {int limit = 10}) async {
    final results = await VideoQueryBuilder.publicVideos(_firestore, category: category, limit: limit).get();
    final rawList = results.docs.map(Video.fromDocumentSnapshot).toList();
    return rawList.sanitizeForRecommendation();
  }

  void resetFeedAndFetch() {
    videos.clear();
    _lastDocument = null;
    rxHasMore.value = true;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    fetchInitialVideos();
  }

  String get _selectedCategory {
    if (Get.isRegistered<HomeDiscoveryController>()) {
      return Get.find<HomeDiscoveryController>().selectedCategory.value;
    }
    return 'All';
  }

  Query _buildCategoryQuery() {
    return VideoQueryBuilder.publicVideos(_firestore, category: _selectedCategory);
  }

  Future<void> fetchInitialVideos() async {
    await safeExecute(_fetchInitialVideosInternal, showLoading: videos.isEmpty);
  }

  Future<void> _fetchInitialVideosInternal() async {
    try {
      final isMainFeed = _selectedCategory == 'All';
      if (!isMainFeed || videos.isEmpty) {
        isLoadingVideos.value = true;
        videos.clear();
      }

      _lastDocument = null;
      rxHasMore.value = true;

      final currentUserId = _authService.user?.uid;
      final userProfile = Get.isRegistered<UserInterestProfileService>() ? Get.find<UserInterestProfileService>().profile.value : null;
      final feedAlgorithmService = Get.isRegistered<FeedAlgorithmService>() ? Get.find<FeedAlgorithmService>() : null;
      var fetchedFromServer = false;

      if (feedAlgorithmService != null && feedAlgorithmService.isServerAvailable && currentUserId != null && currentUserId.isNotEmpty) {
        try {
          final serverVideos = await feedAlgorithmService.getPersonalizedFeed(
            userId: currentUserId,
            category: _selectedCategory == 'All' ? null : _selectedCategory,
          );

          final adjusted = feedAlgorithmService.applyLocalAdjustments(
            serverVideos,
            notInterestedVideoIds: userProfile?.notInterestedVideoIds,
            blockedChannelIds: userProfile?.blockedChannelIds,
            recentlyWatchedVideoIds: userProfile?.recentlyWatchedVideoIds,
          );

          final isFlipped = (_selectedCategory == '🪙 Flip Coin') || (Get.isRegistered<FlipCoinService>() && Get.find<FlipCoinService>().isHomeFlipped.value);

          if (isFlipped && Get.isRegistered<TruthworldAlgorithm>()) {
            final ranked = Get.find<TruthworldAlgorithm>().rankVideosOpposite(
              adjusted,
              RecommendationSurface.homeFeedAll,
              diversityConfig: DiversityConfig.homeFeed,
            );
            videos.assignAll(ranked.map((s) => s.video).toList());
          } else {
            videos.assignAll(adjusted);
          }

          if (isMainFeed) _saveVideosToCache();
          if (serverVideos.length < _pageSize) rxHasMore.value = false;
          fetchedFromServer = true;
        } catch (e) {
          debugPrint('Server feed unavailable, falling back to local: $e');
        }
      }

      if (!fetchedFromServer) {
        final results = await _buildCategoryQuery().limit(_pageSize).get();
        if (results.docs.isNotEmpty) {
          _lastDocument = results.docs.last;
          final rawVideos = results.docs.map(Video.fromDocumentSnapshot).toList().sanitizeForFeed();
          final currentCat = _selectedCategory;
          
          if (currentCat == '🔥 Trending' || currentCat == 'Trending') {
            rawVideos.sort((a, b) {
              final daysA = DateTime.now().difference(a.createdAt.toDate()).inDays;
              final daysB = DateTime.now().difference(b.createdAt.toDate()).inDays;
              final scoreA = (a.views + a.likes * 3) / (daysA + 1);
              final scoreB = (b.views + b.likes * 3) / (daysB + 1);
              return scoreB.compareTo(scoreA);
            });
            videos.assignAll(rawVideos);
          } else if (currentCat == '✨ New' || currentCat == 'New') {
            rawVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            videos.assignAll(rawVideos);
          } else if (currentCat == '⭐ Popular' || currentCat == 'Popular') {
            rawVideos.sort((a, b) => b.views.compareTo(a.views));
            videos.assignAll(rawVideos);
          } else if ((isMainFeed || currentCat == '🪙 Flip Coin') && Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final isFlipped = (currentCat == '🪙 Flip Coin') || (Get.isRegistered<FlipCoinService>() && Get.find<FlipCoinService>().isHomeFlipped.value);
            final ranked = isFlipped
                ? algorithm.rankVideosOpposite(rawVideos, RecommendationSurface.homeFeedAll, diversityConfig: DiversityConfig.homeFeed)
                : algorithm.rankVideos(rawVideos, RecommendationSurface.homeFeedAll, diversityConfig: DiversityConfig.homeFeed);
            final rankedVideos = ranked.map((s) => s.video).toList();
            videos.assignAll(rankedVideos.isNotEmpty ? rankedVideos : rawVideos);
          } else {
            videos.assignAll(rawVideos);
          }

          if (isMainFeed) _saveVideosToCache();
          if (results.docs.length < _pageSize) rxHasMore.value = false;
        } else {
          try {
            final fallbackResults = await _firestore.collection('videos').limit(_pageSize).get();
            if (fallbackResults.docs.isNotEmpty) {
              _lastDocument = fallbackResults.docs.last;
              final fallbackVideos = fallbackResults.docs.map(Video.fromDocumentSnapshot).where(VideoVisibilityPolicy.isVisibleForFeed).toList();
              if (fallbackVideos.isNotEmpty) {
                videos.assignAll(fallbackVideos);
              } else {
                videos.assignAll(fallbackResults.docs.map(Video.fromDocumentSnapshot).where((v) => v.status != VideoStatus.deleted).toList());
              }
            } else {
              videos.clear();
            }
          } catch (fbErr) {
            videos.clear();
          }
          rxHasMore.value = false;
        }
      }

      if (isMainFeed) {
        await fetchCommunityPosts();
      } else {
        communityPosts.clear();
      }
      mixHomeFeed();
      if (Get.isRegistered<HomeDiscoveryController>()) {
        Get.find<HomeDiscoveryController>().fetchAvailableCategories();
      }
      clearError();
    } catch (e) {
      setError('Failed to load videos: $e');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  Future<void> fetchMoreVideos() async {
    if (isLoadingMore.value || !rxHasMore.value || _lastDocument == null) return;
    isLoadingMore.value = true;
    try {
      var query = _buildCategoryQuery();
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      } else if (videos.isNotEmpty) {
        query = query.startAfter([videos.last.uploadedAt]);
      }

      final results = await query.limit(_pageSize).get().timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Loading more videos'));

      if (results.docs.isNotEmpty) {
        _lastDocument = results.docs.last;
        final newVideos = results.docs.map(Video.fromDocumentSnapshot).toList();
        final combined = [...videos, ...newVideos].sanitizeForFeed();
        videos.assignAll(combined);
        if (results.docs.length < _pageSize) rxHasMore.value = false;
      } else {
        rxHasMore.value = false;
      }

      mixHomeFeed();
    } catch (e) {
      rxHasMore.value = false;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> fetchCommunityPosts() async {
    try {
      final snapshot = await _firestore.collection('Community').where('visibility', isEqualTo: 'Public').limit(50).get();
      final posts = snapshot.docs.map((doc) => CommunityPostModel.fromMap(doc.data())).toList();
      posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      communityPosts.assignAll(posts.take(10));
    } catch (e) {
      debugPrint('Error fetching community posts: $e');
    }
  }

  void mixHomeFeed() {
    final mixed = <dynamic>[];
    var videoIndex = 0;
    var postIndex = 0;
    final limitedPosts = communityPosts.take(3).toList();

    while (videoIndex < videos.length || postIndex < limitedPosts.length) {
      for (var i = 0; i < 6 && videoIndex < videos.length; i++) {
        mixed.add(videos[videoIndex++]);
      }
      if (postIndex < limitedPosts.length && videos.isNotEmpty) {
        mixed.add(limitedPosts[postIndex++]);
      } else if (videos.isEmpty && postIndex < 1) {
        mixed.add(limitedPosts[postIndex++]);
      }
    }
    homeFeedItems.assignAll(mixed);
  }

  Future<void> fetchCategoryContent(String category) async {
    isLoadingVideos.value = true;
    videos.clear();
    _lastDocument = null;
    rxHasMore.value = true;

    try {
      if (category == 'All') {
        await _fetchInitialVideosInternal();
        return;
      }

      final videoDocs = await VideoQueryBuilder.publicVideos(_firestore, category: category, limit: _pageSize).get();
      var catVideos = <Video>[];
      if (videoDocs.docs.isNotEmpty) {
        _lastDocument = videoDocs.docs.last;
        catVideos = videoDocs.docs.map(Video.fromDocumentSnapshot).toList().sanitizeForFeed();
      }

      if (catVideos.isEmpty) {
        final fallbackDocs = await _firestore.collection('videos').where('category', isEqualTo: category).limit(_pageSize).get();
        catVideos = fallbackDocs.docs.map(Video.fromDocumentSnapshot).where(VideoVisibilityPolicy.isVisibleForFeed).toList();
      }

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(catVideos, RecommendationSurface.homeFeedCategory);
        final rankedCatVideos = ranked.map((s) => s.video).toList();
        videos.assignAll(rankedCatVideos.isNotEmpty ? rankedCatVideos : catVideos);
      } else {
        videos.assignAll(catVideos);
      }

      try {
        final topicDocs = await _firestore.collection('topics').where('category', isEqualTo: category).limit(10).get();
        if (topicDocs.docs.isNotEmpty && Get.isRegistered<HomeDiscoveryController>()) {
          final catTopics = topicDocs.docs.map(Topic.fromDocumentSnapshot).toList();
          Get.find<HomeDiscoveryController>().featuredTopics.assignAll(catTopics);
        }
      } catch (e) {
        debugPrint('Error fetching category topics: $e');
      }

      try {
        final postDocs = await _firestore.collection('Community').where('visibility', isEqualTo: 'Public').limit(20).get();
        final posts = postDocs.docs.map((doc) => CommunityPostModel.fromMap(doc.data())).where((p) => p.selectedCategory == category || category == 'All').toList();
        communityPosts.assignAll(posts.take(5));
      } catch (e) {
        debugPrint('Error fetching category posts: $e');
      }

      mixHomeFeed();
    } catch (e) {
      debugPrint('Error fetching category content: $e');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  Future<void> refreshHomeFeed() async {
    try {
      final category = _selectedCategory;
      if (category != 'All') {
        await fetchCategoryContent(category);
      } else {
        await _fetchInitialVideosInternal();
        if (Get.isRegistered<HomeDiscoveryController>()) {
          await Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
        }
      }
    } catch (e) {
      debugPrint('Error refreshing home feed: $e');
    }
  }
}
