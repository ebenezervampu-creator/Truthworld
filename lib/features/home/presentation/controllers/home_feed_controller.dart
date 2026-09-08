import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/ad_service.dart';
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
    addWorker(
      ever(_authService.isAuthenticated, (isAuth) {
        if (isAuth) {
          fetchCommunityPosts().then((_) => mixHomeFeed());
        }
      }),
    );
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

  bool _matchesCategory(Video v, String cat) {
    final target = cat.trim().toLowerCase();
    final vCat = v.category.trim().toLowerCase();
    if (vCat == target || vCat.contains(target) || target.contains(vCat)) return true;
    if (v.tags.any((t) => t.trim().toLowerCase() == target || t.trim().toLowerCase().contains(target))) return true;
    if (v.topics.any((t) => t.trim().toLowerCase() == target || t.trim().toLowerCase().contains(target))) return true;
    return false;
  }

  void _loadCachedVideos([String? category]) {
    try {
      final cat = category ?? _selectedCategory;
      final cacheKey = FeedCacheManager.cacheKeyForCategory(cat);
      final cachedVideos = _feedCacheManager.getValidCachedVideos(cacheKey);
      if (cachedVideos != null && cachedVideos.isNotEmpty && videos.isEmpty) {
        final isSpecialTab = cat == 'All' ||
            cat == '🔥 Trending' ||
            cat == 'Trending' ||
            cat == '⭐ Popular' ||
            cat == 'Popular' ||
            cat == '✨ New' ||
            cat == 'New' ||
            cat == 'Flip Coin' ||
            cat == '🪙 Flip Coin';

        if (!isSpecialTab) {
          final validForCategory = cachedVideos.where((v) => _matchesCategory(v, cat)).toList();
          if (validForCategory.isEmpty) {
            return;
          }
          videos.assignAll(validForCategory);
        } else {
          videos.assignAll(cachedVideos);
        }
        mixHomeFeed();
        isLoadingVideos.value = false;
      }
    } catch (e) {
      debugPrint('HomeFeedController: Cache load error: $e');
    }
  }

  void _saveVideosToCache([String? category]) {
    try {
      final cat = category ?? _selectedCategory;
      if (videos.isNotEmpty && cat != 'Posts' && cat != 'Subscriptions' && cat != 'Topics' && cat != 'Explore Topics') {
        final isSpecialTab = cat == 'All' ||
            cat == '🔥 Trending' ||
            cat == 'Trending' ||
            cat == '⭐ Popular' ||
            cat == 'Popular' ||
            cat == '✨ New' ||
            cat == 'New' ||
            cat == 'Flip Coin' ||
            cat == '🪙 Flip Coin';

        final videosToCache = isSpecialTab
            ? videos.toList()
            : videos.where((v) => _matchesCategory(v, cat)).toList();

        if (videosToCache.isNotEmpty) {
          final cacheKey = FeedCacheManager.cacheKeyForCategory(cat);
          _feedCacheManager.saveFeedToCache(cacheKey, videosToCache);
        }
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
        _fetchTrendingVideos(),
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

  Future<List<Video>> _fetchTrendingVideos({int limit = 10}) async {
    final results = await VideoQueryBuilder.publicVideos(
      _firestore,
      orderByField: 'views',
      limit: limit,
    ).get();
    final rawList = results.docs.map(Video.fromDocumentSnapshot).toList();
    if (Get.isRegistered<TruthworldAlgorithm>()) {
      final algorithm = Get.find<TruthworldAlgorithm>();
      final ranked = algorithm.rankVideos(
        rawList.sanitizeForFeed(),
        RecommendationSurface.trending,
        diversityConfig: DiversityConfig.trending,
      );
      return ranked.map((s) => s.video).toList().sanitizeForRecommendation();
    }
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

  Query _buildCategoryQuery({DocumentSnapshot? startAfter}) {
    final cat = _selectedCategory;
    if (cat == '⭐ Popular' || cat == 'Popular') {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        orderByField: 'viewCount',
        startAfter: startAfter,
      );
    } else if (cat == '🔥 Trending' || cat == 'Trending') {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        orderByField: 'views',
        startAfter: startAfter,
      );
    } else if (cat == '✨ New' || cat == 'New') {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        startAfter: startAfter,
      );
    } else if (cat == 'All' || cat == 'Flip Coin' || cat == '🪙 Flip Coin' || cat == 'Subscriptions' || cat == 'Posts') {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        startAfter: startAfter,
      );
    } else {
      return VideoQueryBuilder.categoryVideos(
        _firestore,
        category: cat,
        withOrderBy: false,
        startAfter: startAfter,
      );
    }
  }

  Future<void> fetchInitialVideos() async {
    await safeExecute(_fetchInitialVideosInternal, showLoading: videos.isEmpty);
  }

  Future<void> _fetchInitialVideosInternal() async {
    try {
      final currentCat = _selectedCategory;
      final isPostsTab = currentCat == 'Posts';
      final isMainFeed = currentCat == 'All';
      final isTrending = currentCat == 'Trending' || currentCat == '🔥 Trending';
      final isPopular = currentCat == 'Popular' || currentCat == '⭐ Popular';
      final isNew = currentCat == 'New' || currentCat == '✨ New';
      final isFlipCoin = currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin';
      final isTopics = currentCat == 'Topics' || currentCat == 'Explore Topics';
      final isSubscriptions = currentCat == 'Subscriptions';

      if (isSubscriptions) {
        isLoadingVideos.value = false;
        videos.clear();
        communityPosts.clear();
        homeFeedItems.clear();
        return;
      }

      if (isTopics) {
        isLoadingVideos.value = false;
        videos.clear();
        communityPosts.clear();
        homeFeedItems.clear();
        if (Get.isRegistered<HomeDiscoveryController>()) {
          Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
          Get.find<HomeDiscoveryController>().fetchForYouTopics();
        }
        return;
      }

      if (isPostsTab) {
        isLoadingVideos.value = true;
        videos.clear();
        communityPosts.clear();
        _lastDocument = null;
        rxHasMore.value = true;

        await _fetchInitialCommunityPostsTab();
        clearError();
        return;
      }

      // Check cache first for instant feedback & cost-effective Firestore minimization
      _loadCachedVideos(currentCat);

      if (videos.isEmpty) {
        isLoadingVideos.value = true;
      }

      _lastDocument = null;
      rxHasMore.value = true;
      communityPosts.clear();

      if (isMainFeed) {
        await _fetchMainFeedVideos();
      } else if (isTrending) {
        await _fetchTrendingTabVideos();
      } else if (isPopular) {
        await _fetchPopularTabVideos();
      } else if (isNew) {
        await _fetchNewTabVideos();
      } else if (isFlipCoin) {
        await _fetchFlipCoinTabVideos();
      } else {
        await _fetchCategoryTabVideos(currentCat);
      }

      if (isMainFeed && _authService.isAuthenticated.value) {
        fetchCommunityPosts().then((_) {
          if (communityPosts.isNotEmpty) {
            mixHomeFeed();
          }
        });
      } else if (!isPostsTab) {
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

  Future<void> _fetchMainFeedVideos() async {
    final currentUserId = _authService.user?.uid;
    final userProfile = Get.isRegistered<UserInterestProfileService>()
        ? Get.find<UserInterestProfileService>().profile.value
        : null;
    final feedAlgorithmService = Get.isRegistered<FeedAlgorithmService>()
        ? Get.find<FeedAlgorithmService>()
        : null;

    if (feedAlgorithmService != null &&
        feedAlgorithmService.isServerAvailable &&
        currentUserId != null &&
        currentUserId.isNotEmpty) {
      try {
        final serverVideos = await feedAlgorithmService.getPersonalizedFeed(
          userId: currentUserId,
        );

        final adjusted = feedAlgorithmService.applyLocalAdjustments(
          serverVideos,
          notInterestedVideoIds: userProfile?.notInterestedVideoIds,
          blockedChannelIds: userProfile?.blockedChannelIds,
          recentlyWatchedVideoIds: userProfile?.recentlyWatchedVideoIds,
        );

        final isFlipped = Get.isRegistered<FlipCoinService>() &&
            Get.find<FlipCoinService>().isHomeFlipped.value;

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

        _saveVideosToCache('All');
        if (serverVideos.length < _pageSize) rxHasMore.value = false;
        return;
      } catch (e) {
        debugPrint('Server feed unavailable, falling back to local: $e');
      }
    }

    QuerySnapshot? results;
    try {
      results = await _firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .limit(_pageSize)
          .get();
    } catch (e) {
      debugPrint('Main feed query failed with uploadedAt, trying createdAt: $e');
      try {
        results = await _firestore
            .collection('videos')
            .orderBy('createdAt', descending: true)
            .limit(_pageSize)
            .get();
      } catch (e2) {
        debugPrint('Main feed query failed with createdAt, falling back: $e2');
        try {
          results = await _firestore.collection('videos').limit(_pageSize).get();
        } catch (_) {}
      }
    }

    if (results != null && results.docs.isNotEmpty) {
      _lastDocument = results.docs.last;
      final rawVideos = results.docs
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(
          rawVideos,
          RecommendationSurface.homeFeedAll,
          diversityConfig: DiversityConfig.homeFeed,
        );
        final rankedVideos = ranked.map((s) => s.video).toList();
        videos.assignAll(rankedVideos.isNotEmpty ? rankedVideos : rawVideos);
      } else {
        videos.assignAll(rawVideos);
      }

      _saveVideosToCache('All');
      if (rawVideos.length < _pageSize) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
    }
  }

  Future<void> _fetchTrendingTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    try {
      results = await _firestore
          .collection('videos')
          .orderBy('viewCount', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      debugPrint('Trending fetch by viewCount failed: $e');
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await _firestore
            .collection('videos')
            .orderBy('views', descending: true)
            .limit(limit)
            .get();
      } catch (e) {
        debugPrint('Trending fetch by views failed: $e');
      }
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await _firestore
            .collection('videos')
            .orderBy('uploadedAt', descending: true)
            .limit(limit)
            .get();
      } catch (e) {
        debugPrint('Trending fetch fallback query failed: $e');
        try {
          results = await _firestore.collection('videos').limit(limit).get();
        } catch (_) {}
      }
    }

    if (results != null && results.docs.isNotEmpty) {
      _lastDocument = results.docs.last;
      final rawVideos = results.docs
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      rawVideos.sort((a, b) {
        final daysA = DateTime.now().difference(a.createdAt.toDate()).inDays + 1;
        final daysB = DateTime.now().difference(b.createdAt.toDate()).inDays + 1;
        final viewsA = (a.views > 0 ? a.views : a.viewCount).toDouble();
        final viewsB = (b.views > 0 ? b.views : b.viewCount).toDouble();
        final scoreA = (viewsA * 0.5) + (a.likes * 0.3) + (a.commentCount * 0.2) + ((1.0 / daysA) * 100) + (a.trustScore * 10);
        final scoreB = (viewsB * 0.5) + (b.likes * 0.3) + (b.commentCount * 0.2) + ((1.0 / daysB) * 100) + (b.trustScore * 10);
        return scoreB.compareTo(scoreA);
      });

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(
          rawVideos,
          RecommendationSurface.trending,
          diversityConfig: DiversityConfig.trending,
        );
        final rankedVideos = ranked.map((s) => s.video).toList();
        videos.assignAll(rankedVideos.isNotEmpty ? rankedVideos : rawVideos);
      } else {
        videos.assignAll(rawVideos);
      }

      _saveVideosToCache('Trending');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
    }
  }

  Future<void> _fetchPopularTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    try {
      results = await _firestore
          .collection('videos')
          .orderBy('viewCount', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      debugPrint('Popular fetch by viewCount failed: $e');
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await _firestore
            .collection('videos')
            .orderBy('views', descending: true)
            .limit(limit)
            .get();
      } catch (e) {
        debugPrint('Popular fetch by views failed: $e');
      }
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await _firestore.collection('videos').limit(limit).get();
      } catch (e) {
        debugPrint('Popular fallback failed: $e');
      }
    }

    if (results != null && results.docs.isNotEmpty) {
      _lastDocument = results.docs.last;
      final rawVideos = results.docs
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      rawVideos.sort((a, b) {
        final viewsA = a.views > 0 ? a.views : a.viewCount;
        final viewsB = b.views > 0 ? b.views : b.viewCount;
        final metricA = (viewsA * 2) + a.likes;
        final metricB = (viewsB * 2) + b.likes;
        return metricB.compareTo(metricA);
      });

      videos.assignAll(rawVideos);
      _saveVideosToCache('Popular');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
    }
  }

  Future<void> _fetchNewTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    try {
      results = await _firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      debugPrint('New tab fetch by uploadedAt failed: $e');
      try {
        results = await _firestore
            .collection('videos')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
      } catch (e2) {
        debugPrint('New tab fetch by createdAt failed: $e2');
        try {
          results = await _firestore.collection('videos').limit(limit).get();
        } catch (_) {}
      }
    }

    if (results != null && results.docs.isNotEmpty) {
      _lastDocument = results.docs.last;
      final rawVideos = results.docs
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      rawVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      videos.assignAll(rawVideos);
      _saveVideosToCache('New');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
    }
  }

  Future<void> _fetchFlipCoinTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    try {
      results = await _firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      try {
        results = await _firestore.collection('videos').limit(limit).get();
      } catch (_) {}
    }

    if (results != null && results.docs.isNotEmpty) {
      _lastDocument = results.docs.last;
      final rawVideos = results.docs
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideosOpposite(
          rawVideos,
          RecommendationSurface.homeFeedAll,
          diversityConfig: DiversityConfig.homeFeed,
        );
        videos.assignAll(ranked.map((s) => s.video).toList());
      } else {
        rawVideos.shuffle();
        videos.assignAll(rawVideos);
      }

      _saveVideosToCache('Flip Coin');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
    }
  }

  Future<void> _fetchCategoryTabVideos(String category) async {
    final cat = category.trim();
    final candidateDocs = <DocumentSnapshot>[];

    // 1. Try Firestore with exact category case and orderBy uploadedAt
    try {
      final snap = await _firestore
          .collection('videos')
          .where('category', isEqualTo: cat)
          .orderBy('uploadedAt', descending: true)
          .limit(_pageSize)
          .get();
      if (snap.docs.isNotEmpty) {
        candidateDocs.addAll(snap.docs);
        _lastDocument = snap.docs.last;
      }
    } catch (e) {
      debugPrint('Category query with orderBy failed: $e');
    }

    // 2. Try Firestore with exact category case WITHOUT orderBy
    if (candidateDocs.isEmpty) {
      try {
        final snap = await _firestore
            .collection('videos')
            .where('category', isEqualTo: cat)
            .limit(_pageSize)
            .get();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          _lastDocument = snap.docs.last;
        }
      } catch (e) {
        debugPrint('Category query without orderBy failed: $e');
      }
    }

    // 3. Try lowercase category name
    if (candidateDocs.isEmpty && cat.toLowerCase() != cat) {
      try {
        final snap = await _firestore
            .collection('videos')
            .where('category', isEqualTo: cat.toLowerCase())
            .limit(_pageSize)
            .get();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          _lastDocument = snap.docs.last;
        }
      } catch (e) {
        debugPrint('Lowercase category query failed: $e');
      }
    }

    // 4. Try tags matching category
    if (candidateDocs.isEmpty) {
      try {
        final snap = await _firestore
            .collection('videos')
            .where('tags', arrayContains: cat.toLowerCase())
            .limit(_pageSize)
            .get();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          _lastDocument = snap.docs.last;
        }
      } catch (e) {
        debugPrint('Tags category query failed: $e');
      }
    }

    // 5. Try topics matching category
    if (candidateDocs.isEmpty) {
      try {
        final snap = await _firestore
            .collection('videos')
            .where('topics', arrayContains: cat.toLowerCase())
            .limit(_pageSize)
            .get();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          _lastDocument = snap.docs.last;
        }
      } catch (e) {
        debugPrint('Topics category query failed: $e');
      }
    }

    // 6. Broader scan across recent videos if direct indexed queries didn't yield results
    if (candidateDocs.isEmpty) {
      try {
        final snap = await _firestore.collection('videos').limit(120).get();
        candidateDocs.addAll(snap.docs);
      } catch (e) {
        debugPrint('Broader candidate scan failed: $e');
      }
    }

    final uniqueVideos = <String, Video>{};
    for (final doc in candidateDocs) {
      try {
        final v = Video.fromDocumentSnapshot(doc);
        if (_matchesCategory(v, cat) && VideoVisibilityPolicy.isVisibleForFeed(v)) {
          uniqueVideos[v.id] = v;
        }
      } catch (e) {
        debugPrint('Error parsing video ${doc.id}: $e');
      }
    }

    final catVideos = uniqueVideos.values.toList();

    if (catVideos.isNotEmpty) {
      catVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(
          catVideos,
          RecommendationSurface.homeFeedCategory,
        );
        final rankedList = ranked.map((s) => s.video).toList();
        videos.assignAll(rankedList.isNotEmpty ? rankedList : catVideos);
      } else {
        videos.assignAll(catVideos);
      }

      _saveVideosToCache(cat);
      rxHasMore.value = catVideos.length >= _pageSize;
    } else {
      // Zero matching videos: maintain empty list so clean empty state is rendered
      videos.clear();
      rxHasMore.value = false;
    }

    try {
      final topicDocs = await _firestore
          .collection('topics')
          .where('status', isEqualTo: 'active')
          .where('category', isEqualTo: cat)
          .limit(10)
          .get();
      if (topicDocs.docs.isNotEmpty && Get.isRegistered<HomeDiscoveryController>()) {
        final catTopics = topicDocs.docs
            .map(Topic.fromDocumentSnapshot)
            .where((t) => t.isValidTopic && t.videoCount > 0)
            .toList();
        if (catTopics.isNotEmpty) {
          Get.find<HomeDiscoveryController>().featuredTopics.assignAll(catTopics);
        }
      }
    } catch (e) {
      debugPrint('Error fetching category topics: $e');
    }
  }

  Future<void> fetchMoreVideos() async {
    if (isLoadingMore.value || !rxHasMore.value || _lastDocument == null) return;
    isLoadingMore.value = true;
    try {
      final currentCat = _selectedCategory;
      if (currentCat == 'Posts') {
        await _fetchMoreCommunityPostsTab();
        return;
      }

      final isSpecialTab = currentCat == 'All' ||
          currentCat == '🔥 Trending' ||
          currentCat == 'Trending' ||
          currentCat == '⭐ Popular' ||
          currentCat == 'Popular' ||
          currentCat == '✨ New' ||
          currentCat == 'New' ||
          currentCat == 'Flip Coin' ||
          currentCat == '🪙 Flip Coin';

      final query = _buildCategoryQuery(startAfter: _lastDocument);
      final results = await query.limit(_pageSize).get().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Loading more videos'),
          );

      if (results.docs.isNotEmpty) {
        _lastDocument = results.docs.last;
        final rawVideos = results.docs.map(Video.fromDocumentSnapshot).toList().sanitizeForFeed();

        final filteredVideos = isSpecialTab
            ? rawVideos
            : rawVideos.where((v) => _matchesCategory(v, currentCat)).toList();

        if (filteredVideos.isNotEmpty) {
          final isFlipped = (currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin') ||
              (Get.isRegistered<FlipCoinService>() && Get.find<FlipCoinService>().isHomeFlipped.value);

          List<Video> videosToAdd;
          if (isFlipped && Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideosOpposite(
              filteredVideos,
              RecommendationSurface.homeFeedAll,
              diversityConfig: DiversityConfig.homeFeed,
            );
            videosToAdd = ranked.map((s) => s.video).toList();
          } else if ((currentCat == '🔥 Trending' || currentCat == 'Trending') && Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideos(
              filteredVideos,
              RecommendationSurface.trending,
              diversityConfig: DiversityConfig.trending,
            );
            videosToAdd = ranked.map((s) => s.video).toList();
          } else {
            videosToAdd = filteredVideos;
          }

          final existingIds = videos.map((v) => v.id).toSet();
          final uniqueNewVideos = videosToAdd.where((v) => !existingIds.contains(v.id)).toList();
          if (uniqueNewVideos.isNotEmpty) {
            videos.addAll(uniqueNewVideos);
          }
          if (results.docs.length < _pageSize) rxHasMore.value = false;
        } else {
          rxHasMore.value = false;
        }
      } else {
        rxHasMore.value = false;
      }

      mixHomeFeed();
    } catch (e) {
      debugPrint('Error fetching more videos: $e');
      rxHasMore.value = false;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> _fetchInitialCommunityPostsTab() async {
    try {
      var docs = <DocumentSnapshot>[];

      // 1. Try primary collection 'Community' with order
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.community)
            .orderBy('uploadedAt', descending: true)
            .limit(_pageSize)
            .get();
        if (snapshot.docs.isNotEmpty) {
          docs = snapshot.docs;
        }
      } catch (e) {
        debugPrint('Community query with uploadedAt failed: $e');
      }

      // 2. Try primary collection 'Community' with timestamp order
      if (docs.isEmpty) {
        try {
          final snapshot = await _firestore
              .collection(FirestoreCollections.community)
              .orderBy('timestamp', descending: true)
              .limit(_pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e) {
          debugPrint('Community query with timestamp failed: $e');
        }
      }

      // 3. Try primary collection 'Community' without order (handles varied date fields)
      if (docs.isEmpty) {
        try {
          final snapshot = await _firestore
              .collection(FirestoreCollections.community)
              .limit(_pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e) {
          debugPrint('Community query without order failed: $e');
        }
      }

      // 4. Try lowercase 'community' collection
      if (docs.isEmpty) {
        try {
          final snapshot = await _firestore
              .collection('community')
              .limit(_pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e) {
          debugPrint('Lowercase community query failed: $e');
        }
      }

      // 5. Try 'community_posts' collection
      if (docs.isEmpty) {
        try {
          final snapshot = await _firestore
              .collection('community_posts')
              .limit(_pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e) {
          debugPrint('community_posts query failed: $e');
        }
      }

      if (docs.isNotEmpty) {
        _lastDocument = docs.last;
        final posts = <CommunityPostModel>[];
        for (final doc in docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data()! as Map);
            data.putIfAbsent('id', () => doc.id);
            final post = CommunityPostModel.fromMap(data);
            if (post.isValid && !post.isDraft) {
              posts.add(post);
            }
          } catch (docErr) {
            debugPrint('Error parsing community post ${doc.id}: $docErr');
          }
        }

        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.assignAll(posts);
        homeFeedItems.assignAll(posts);
        rxHasMore.value = docs.length >= _pageSize;
      } else {
        communityPosts.clear();
        homeFeedItems.clear();
        rxHasMore.value = false;
      }
    } catch (e) {
      debugPrint('Error fetching community posts for Posts tab: $e');
      communityPosts.clear();
      homeFeedItems.clear();
      rxHasMore.value = false;
    }
  }

  Future<void> _fetchMoreCommunityPostsTab() async {
    if (_lastDocument == null) {
      rxHasMore.value = false;
      return;
    }
    try {
      var docs = <DocumentSnapshot>[];
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.community)
            .startAfterDocument(_lastDocument!)
            .limit(_pageSize)
            .get().timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Loading more posts'),
            );
        if (snapshot.docs.isNotEmpty) {
          docs = snapshot.docs;
        }
      } catch (e) {
        debugPrint('Paginated community query failed, falling back: $e');
      }

      if (docs.isNotEmpty) {
        _lastDocument = docs.last;
        final newPosts = <CommunityPostModel>[];
        for (final doc in docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data()! as Map);
            data.putIfAbsent('id', () => doc.id);
            final post = CommunityPostModel.fromMap(data);
            if (post.isValid && !post.isDraft) {
              newPosts.add(post);
            }
          } catch (docErr) {
            debugPrint('Error parsing more community post ${doc.id}: $docErr');
          }
        }
        newPosts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.addAll(newPosts);
        homeFeedItems.assignAll(communityPosts);
        rxHasMore.value = docs.length >= _pageSize;
      } else {
        rxHasMore.value = false;
      }
    } catch (e) {
      debugPrint('Error fetching more community posts: $e');
      rxHasMore.value = false;
    }
  }

  Future<void> fetchCommunityPosts() async {
    try {
      var snapshot = await _firestore.collection(FirestoreCollections.community).limit(50).get();
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore.collection('community').limit(50).get();
      }
      final posts = <CommunityPostModel>[];
      for (final doc in snapshot.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data.putIfAbsent('id', () => doc.id);
          final post = CommunityPostModel.fromMap(data);
          if (post.isValid && !post.isDraft) {
            posts.add(post);
          }
        } catch (e) {
          debugPrint('Error parsing community post: $e');
        }
      }
      posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      communityPosts.assignAll(posts.take(10));
    } catch (e) {
      debugPrint('Error fetching community posts: $e');
    }
  }

  void mixHomeFeed() {
    if (_selectedCategory == 'Posts') {
      homeFeedItems.assignAll(communityPosts);
      return;
    }

    final mixed = <dynamic>[];
    var videoIndex = 0;
    var postIndex = 0;
    var adIndex = 0;
    final homepageAds = Get.isRegistered<AdService>()
        ? AdService.to.getAdsForType('homepage')
        : <AdItem>[];

    final isAuth = _authService.isAuthenticated.value;

    while (videoIndex < videos.length) {
      for (var i = 0; i < 6 && videoIndex < videos.length; i++) {
        mixed.add(videos[videoIndex++]);
      }
      if (isAuth && postIndex < communityPosts.length && _selectedCategory == 'All') {
        mixed.add(communityPosts[postIndex++]);
      }
      if (homepageAds.isNotEmpty && videoIndex < videos.length) {
        mixed.add(homepageAds[adIndex++ % homepageAds.length]);
      }
    }

    if (homepageAds.isNotEmpty && !mixed.any((item) => item is AdItem) && mixed.isNotEmpty) {
      final insertPos = mixed.length > 2 ? 2 : mixed.length;
      mixed.insert(insertPos, homepageAds.first);
    }

    homeFeedItems.assignAll(mixed);
  }

  Future<void> fetchCategoryContent(String category) async {
    if (Get.isRegistered<HomeDiscoveryController>()) {
      Get.find<HomeDiscoveryController>().selectedCategory.value = category;
    }
    await _fetchInitialVideosInternal();
  }

  Future<void> refreshHomeFeed() async {
    try {
      final category = _selectedCategory;
      if (category == 'Posts') {
        isLoadingVideos.value = true;
        videos.clear();
        communityPosts.clear();
        _lastDocument = null;
        rxHasMore.value = true;
        await _fetchInitialCommunityPostsTab();
      } else if (category == 'Topics' || category == 'Explore Topics') {
        isLoadingVideos.value = false;
        if (Get.isRegistered<HomeDiscoveryController>()) {
          await Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
          await Get.find<HomeDiscoveryController>().fetchForYouTopics();
        }
      } else if (category == 'All') {
        await _fetchInitialVideosInternal();
        if (Get.isRegistered<HomeDiscoveryController>()) {
          await Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
          await Get.find<HomeDiscoveryController>().fetchForYouTopics();
        }
      } else {
        await fetchCategoryContent(category);
      }
    } catch (e) {
      debugPrint('Error refreshing home feed: $e');
    } finally {
      isLoadingVideos.value = false;
    }
  }
}
