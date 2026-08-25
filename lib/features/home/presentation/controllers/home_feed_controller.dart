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

  void _loadCachedVideos([String? category]) {
    try {
      final cat = category ?? _selectedCategory;
      final cacheKey = FeedCacheManager.cacheKeyForCategory(cat);
      final cachedVideos = _feedCacheManager.getValidCachedVideos(cacheKey);
      if (cachedVideos != null && cachedVideos.isNotEmpty && videos.isEmpty) {
        videos.assignAll(cachedVideos);
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
      if (videos.isNotEmpty && cat != 'Posts' && cat != 'Subscriptions') {
        final cacheKey = FeedCacheManager.cacheKeyForCategory(cat);
        _feedCacheManager.saveFeedToCache(cacheKey, videos);
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
      descending: true,
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
        orderByField: 'views',
        descending: true,
        startAfter: startAfter,
      );
    } else if (cat == '🔥 Trending' || cat == 'Trending') {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        orderByField: 'views',
        descending: true,
        startAfter: startAfter,
      );
    } else if (cat == '✨ New' || cat == 'New') {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        orderByField: 'uploadedAt',
        descending: true,
        startAfter: startAfter,
      );
    } else if (cat == 'All' || cat == 'Flip Coin' || cat == '🪙 Flip Coin' || cat == 'Subscriptions' || cat == 'Posts') {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        orderByField: 'uploadedAt',
        descending: true,
        startAfter: startAfter,
      );
    } else {
      return VideoQueryBuilder.publicVideos(
        _firestore,
        category: cat,
        orderByField: 'uploadedAt',
        descending: true,
        startAfter: startAfter,
      );
    }
  }

  Future<void> fetchInitialVideos() async {
    await safeExecute(_fetchInitialVideosInternal, showLoading: videos.isEmpty);
  }

  Future<void> _fetchInitialVideosInternal() async {
    try {
      final isPostsTab = _selectedCategory == 'Posts';
      final isMainFeed = _selectedCategory == 'All';
      final currentCat = _selectedCategory;

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

      final currentUserId = _authService.user?.uid;
      final userProfile = Get.isRegistered<UserInterestProfileService>() ? Get.find<UserInterestProfileService>().profile.value : null;
      final feedAlgorithmService = Get.isRegistered<FeedAlgorithmService>() ? Get.find<FeedAlgorithmService>() : null;
      var fetchedFromServer = false;

      if (isMainFeed && feedAlgorithmService != null && feedAlgorithmService.isServerAvailable && currentUserId != null && currentUserId.isNotEmpty) {
        try {
          final serverVideos = await feedAlgorithmService.getPersonalizedFeed(
            userId: currentUserId,
            category: null,
          );

          final adjusted = feedAlgorithmService.applyLocalAdjustments(
            serverVideos,
            notInterestedVideoIds: userProfile?.notInterestedVideoIds,
            blockedChannelIds: userProfile?.blockedChannelIds,
            recentlyWatchedVideoIds: userProfile?.recentlyWatchedVideoIds,
          );

          final isFlipped = Get.isRegistered<FlipCoinService>() && Get.find<FlipCoinService>().isHomeFlipped.value;

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

          _saveVideosToCache(currentCat);
          if (serverVideos.length < _pageSize) rxHasMore.value = false;
          fetchedFromServer = true;
        } catch (e) {
          debugPrint('Server feed unavailable, falling back to local: $e');
        }
      }

      if (!fetchedFromServer) {
        final isFlipCoinCat = currentCat == 'Flip Coin' ||
            currentCat == '🪙 Flip Coin' ||
            (Get.isRegistered<FlipCoinService>() &&
                Get.find<FlipCoinService>().isHomeFlipped.value);
        final queryLimit = isFlipCoinCat
            ? 80
            : (currentCat == '🔥 Trending' || currentCat == 'Trending' ? 36 : _pageSize);

        final query = _buildCategoryQuery();
        final results = await query.limit(queryLimit).get();

        if (results.docs.isNotEmpty) {
          _lastDocument = results.docs.last;
          final rawVideos = results.docs.map(Video.fromDocumentSnapshot).toList().sanitizeForFeed();

          if (currentCat == '🔥 Trending' || currentCat == 'Trending') {
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
              rawVideos.sort((a, b) {
                final daysA = DateTime.now().difference(a.createdAt.toDate()).inDays;
                final daysB = DateTime.now().difference(b.createdAt.toDate()).inDays;
                final scoreA = (a.views + a.likes * 3) / (daysA + 1);
                final scoreB = (b.views + b.likes * 3) / (daysB + 1);
                return scoreB.compareTo(scoreA);
              });
              videos.assignAll(rawVideos);
            }
          } else if (currentCat == '⭐ Popular' || currentCat == 'Popular') {
            // Firestore query is already ordered by views DESC
            videos.assignAll(rawVideos);
          } else if (currentCat == '✨ New' || currentCat == 'New') {
            // Firestore query is already ordered by uploadedAt DESC
            videos.assignAll(rawVideos);
          } else if ((isMainFeed || currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin') && Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final isFlipped = (currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin') || (Get.isRegistered<FlipCoinService>() && Get.find<FlipCoinService>().isHomeFlipped.value);
            final ranked = isFlipped
                ? algorithm.rankVideosOpposite(rawVideos, RecommendationSurface.homeFeedAll, diversityConfig: DiversityConfig.homeFeed)
                : algorithm.rankVideos(rawVideos, RecommendationSurface.homeFeedAll, diversityConfig: DiversityConfig.homeFeed);
            final rankedVideos = ranked.map((s) => s.video).toList();
            if (isFlipped) {
              videos.assignAll(rankedVideos);
            } else {
              videos.assignAll(rankedVideos.isNotEmpty ? rankedVideos : rawVideos);
            }
          } else if (currentCat != 'All' && Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideos(rawVideos, RecommendationSurface.homeFeedCategory);
            final rankedVideos = ranked.map((s) => s.video).toList();
            videos.assignAll(rankedVideos.isNotEmpty ? rankedVideos : rawVideos);
          } else {
            videos.assignAll(rawVideos);
          }

          _saveVideosToCache(currentCat);
          if (results.docs.length < queryLimit) rxHasMore.value = false;
        } else {
          try {
            final fallbackResults = await _firestore.collection('videos').limit(_pageSize).get();
            if (fallbackResults.docs.isNotEmpty) {
              _lastDocument = fallbackResults.docs.last;
              final fallbackVideos = fallbackResults.docs.map(Video.fromDocumentSnapshot).where(VideoVisibilityPolicy.isVisibleForFeed).toList();
              final isFlipped = (currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin') || (Get.isRegistered<FlipCoinService>() && Get.find<FlipCoinService>().isHomeFlipped.value);
              if (isFlipped && Get.isRegistered<TruthworldAlgorithm>()) {
                final ranked = Get.find<TruthworldAlgorithm>().rankVideosOpposite(
                  fallbackVideos,
                  RecommendationSurface.homeFeedAll,
                  diversityConfig: DiversityConfig.homeFeed,
                );
                videos.assignAll(ranked.map((s) => s.video).toList());
              } else if (fallbackVideos.isNotEmpty) {
                videos.assignAll(fallbackVideos);
              } else {
                videos.clear();
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

  Future<void> fetchMoreVideos() async {
    if (isLoadingMore.value || !rxHasMore.value || _lastDocument == null) return;
    isLoadingMore.value = true;
    try {
      if (_selectedCategory == 'Posts') {
        await _fetchMoreCommunityPostsTab();
        return;
      }

      final query = _buildCategoryQuery(startAfter: _lastDocument);
      final results = await query.limit(_pageSize).get().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Loading more videos'),
          );

      if (results.docs.isNotEmpty) {
        _lastDocument = results.docs.last;
        final newVideos = results.docs.map(Video.fromDocumentSnapshot).toList().sanitizeForFeed();
        final currentCat = _selectedCategory;
        final isFlipped = (currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin') ||
            (Get.isRegistered<FlipCoinService>() && Get.find<FlipCoinService>().isHomeFlipped.value);

        List<Video> videosToAdd;
        if (isFlipped && Get.isRegistered<TruthworldAlgorithm>()) {
          final algorithm = Get.find<TruthworldAlgorithm>();
          final ranked = algorithm.rankVideosOpposite(
            newVideos,
            RecommendationSurface.homeFeedAll,
            diversityConfig: DiversityConfig.homeFeed,
          );
          videosToAdd = ranked.map((s) => s.video).toList();
        } else if ((currentCat == '🔥 Trending' || currentCat == 'Trending') && Get.isRegistered<TruthworldAlgorithm>()) {
          final algorithm = Get.find<TruthworldAlgorithm>();
          final ranked = algorithm.rankVideos(
            newVideos,
            RecommendationSurface.trending,
            diversityConfig: DiversityConfig.trending,
          );
          videosToAdd = ranked.map((s) => s.video).toList();
        } else {
          videosToAdd = newVideos;
        }

        final combined = [...videos, ...videosToAdd].sanitizeForFeed();
        videos.assignAll(combined);
        if (results.docs.length < _pageSize) rxHasMore.value = false;
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
      final query = _firestore
          .collection(FirestoreCollections.community)
          .where('visibility', isEqualTo: 'Public')
          .orderBy('uploadedAt', descending: true)
          .limit(_pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get();
      } catch (e) {
        debugPrint('Community query with orderBy uploadedAt failed, falling back: $e');
        snapshot = await _firestore
            .collection(FirestoreCollections.community)
            .where('visibility', isEqualTo: 'Public')
            .limit(_pageSize)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final posts = snapshot.docs
            .map((doc) => CommunityPostModel.fromMap(
                (doc.data()! as Map<String, dynamic>)..putIfAbsent('id', () => doc.id)))
            .where((p) => p.isValid && !p.isDraft)
            .toList();
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.assignAll(posts);
        homeFeedItems.assignAll(posts);
        rxHasMore.value = snapshot.docs.length >= _pageSize;
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
      final query = _firestore
          .collection(FirestoreCollections.community)
          .where('visibility', isEqualTo: 'Public')
          .orderBy('uploadedAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get().timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Loading more posts'),
            );
      } catch (e) {
        debugPrint('Paginated community query with orderBy failed, falling back: $e');
        snapshot = await _firestore
            .collection(FirestoreCollections.community)
            .where('visibility', isEqualTo: 'Public')
            .startAfterDocument(_lastDocument!)
            .limit(_pageSize)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newPosts = snapshot.docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map);
              data.putIfAbsent('id', () => doc.id);
              return CommunityPostModel.fromMap(data);
            })
            .where((p) => p.isValid && !p.isDraft)
            .toList();
        newPosts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.addAll(newPosts);
        homeFeedItems.assignAll(communityPosts);
        rxHasMore.value = snapshot.docs.length >= _pageSize;
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
      final snapshot = await _firestore.collection(FirestoreCollections.community).where('visibility', isEqualTo: 'Public').limit(50).get();
      final posts = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            data.putIfAbsent('id', () => doc.id);
            return CommunityPostModel.fromMap(data);
          })
          .where((p) => p.isValid && !p.isDraft)
          .toList();
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
    if (category == 'All' ||
        category == '🔥 Trending' ||
        category == 'Trending' ||
        category == '⭐ Popular' ||
        category == 'Popular' ||
        category == '✨ New' ||
        category == 'New' ||
        category == 'Posts' ||
        category == 'Flip Coin' ||
        category == '🪙 Flip Coin') {
      if (Get.isRegistered<HomeDiscoveryController>()) {
        Get.find<HomeDiscoveryController>().selectedCategory.value = category;
      }
      await _fetchInitialVideosInternal();
      return;
    }

    isLoadingVideos.value = true;
    videos.clear();
    _lastDocument = null;
    rxHasMore.value = true;

    try {
      communityPosts.clear();

      final cacheKey = FeedCacheManager.cacheKeyForCategory(category);
      final cached = _feedCacheManager.getValidCachedVideos(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        videos.assignAll(cached);
        mixHomeFeed();
        isLoadingVideos.value = false;
      }

      final videoDocs = await VideoQueryBuilder.publicVideos(
        _firestore,
        category: category,
        orderByField: 'uploadedAt',
        descending: true,
        limit: _pageSize,
      ).get();

      var catVideos = <Video>[];
      if (videoDocs.docs.isNotEmpty) {
        _lastDocument = videoDocs.docs.last;
        catVideos = videoDocs.docs.map(Video.fromDocumentSnapshot).toList().sanitizeForFeed();
      }

      if (catVideos.isEmpty) {
        final fallbackDocs = await _firestore
            .collection('videos')
            .where('category', isEqualTo: category)
            .limit(_pageSize)
            .get();
        catVideos = fallbackDocs.docs
            .map(Video.fromDocumentSnapshot)
            .where(VideoVisibilityPolicy.isVisibleForFeed)
            .toList();
      }

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(catVideos, RecommendationSurface.homeFeedCategory);
        final rankedCatVideos = ranked.map((s) => s.video).toList();
        videos.assignAll(rankedCatVideos.isNotEmpty ? rankedCatVideos : catVideos);
      } else {
        videos.assignAll(catVideos);
      }

      if (videos.isNotEmpty) {
        _saveVideosToCache(category);
      }

      try {
        final topicDocs = await _firestore.collection('topics').where('category', isEqualTo: category).limit(10).get();
        if (topicDocs.docs.isNotEmpty && Get.isRegistered<HomeDiscoveryController>()) {
          final catTopics = topicDocs.docs
              .map(Topic.fromDocumentSnapshot)
              .where((t) => t.isValidTopic)
              .toList();
          if (catTopics.isNotEmpty) {
            Get.find<HomeDiscoveryController>().featuredTopics.assignAll(catTopics);
          }
        }
      } catch (e) {
        debugPrint('Error fetching category topics: $e');
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
      if (category == 'Posts') {
        isLoadingVideos.value = true;
        videos.clear();
        communityPosts.clear();
        _lastDocument = null;
        rxHasMore.value = true;
        await _fetchInitialCommunityPostsTab();
      } else if (category == 'All') {
        await _fetchInitialVideosInternal();
        if (Get.isRegistered<HomeDiscoveryController>()) {
          await Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
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
