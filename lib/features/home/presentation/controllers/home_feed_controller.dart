import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/widgets/truthworld_splash_screen.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/feed_mixins.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';

export 'feed_mixins/feed_mixins.dart';

/// Controller coordinating home feed data streams, discovery tabs,
/// community integration, caching, and algorithmic recommendations.
class HomeFeedController extends HomeFeedControllerBase
    with
        HomeFeedCachePersonalizationMixin,
        HomeFeedAlgorithmTabsMixin,
        HomeFeedCategoryTabsMixin,
        HomeFeedCommunityCarouselMixin,
        HomeFeedScrollMixin {
  @override
  late final AuthService authService =
      Get.isRegistered<AuthService>() ? Get.find<AuthService>() : AuthService();

  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  final FeedCacheManager feedCacheManager = FeedCacheManager();

  @override
  HomeRepository? homeRepository;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<HomeRepository>()) {
      homeRepository = Get.find<HomeRepository>();
    }
    bindScrollListener();
    loadCachedVideos();
    fetchInitialVideos();
    addWorker(
      ever(authService.isAuthenticated, (isAuth) {
        if (isAuth) {
          fetchCommunityPosts().then((_) => mixHomeFeed());
        }
      }),
    );
    if (Get.isRegistered<WatchHistoryService>()) {
      addWorker(
        ever(WatchHistoryService.to.watchProgressMap, (_) {
          pruneWatchedVideosFromUnexplored();
        }),
      );
    }
    if (Get.isRegistered<UserInterestProfileService>()) {
      addWorker(
        ever(UserInterestProfileService.to.profile, (_) {
          rerankActiveFeedOnProfileUpdate();
        }),
      );
    }
    if (Get.isRegistered<UserLanguagesService>()) {
      addWorker(
        ever(UserLanguagesService.to.primaryLanguage, (_) {
          refreshFeed(forceNetwork: true);
        }),
      );
    }
  }

  @override
  void onClose() {
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    super.onClose();
  }

  @override
  Future<void> fetchInitialVideos() async {
    await safeExecute(fetchInitialVideosInternal, showLoading: videos.isEmpty);
  }

  @override
  Future<void> fetchInitialVideosInternal() async {
    try {
      final currentCat = selectedCategory;
      final isPostsTab = currentCat == 'Posts';
      final isMainFeed = currentCat == 'All';
      final isUnexplored =
          currentCat == 'Unexplored' || currentCat == '🧭 Unexplored';
      final isTrending =
          currentCat == 'Trending' || currentCat == '🔥 Trending';
      final isPopular = currentCat == 'Popular' || currentCat == '⭐ Popular';
      final isNew = currentCat == 'New' || currentCat == '✨ New';
      final isFlipCoin =
          currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin';
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
        }
        return;
      }

      if (isPostsTab) {
        isLoadingVideos.value = true;
        videos.clear();
        communityPosts.clear();
        lastDocument = null;
        rxHasMore.value = true;

        await fetchInitialCommunityPostsTab();
        clearError();
        return;
      }

      // Check cache first for instant feedback & cost-effective Firestore minimization
      loadCachedVideos(currentCat);

      if (videos.isEmpty) {
        isLoadingVideos.value = true;
      }

      lastDocument = null;
      rxHasMore.value = true;
      communityPosts.clear();

      if (isMainFeed) {
        await fetchMainFeedVideos();
      } else if (isUnexplored) {
        await fetchUnexploredTabVideos();
      } else if (isTrending) {
        await fetchTrendingTabVideos();
      } else if (isPopular) {
        await fetchPopularTabVideos();
      } else if (isNew) {
        await fetchNewTabVideos();
      } else if (isFlipCoin) {
        await fetchFlipCoinTabVideos();
      } else {
        await fetchCategoryTabVideos(currentCat);
      }

      if (isMainFeed && authService.isAuthenticated.value) {
        fetchCommunityPosts().then((_) {
          if (communityPosts.isNotEmpty) {
            mixHomeFeed();
          }
        });
      } else if (!isPostsTab) {
        communityPosts.clear();
      }

      mixHomeFeed();
      TruthworldSplashScreen.dismiss();
      if (Get.isRegistered<HomeDiscoveryController>()) {
        Get.find<HomeDiscoveryController>().fetchAvailableCategories();
      }
      clearError();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController.fetchInitialVideosInternal',
      );
      setError('Unable to load videos. Please check your connection and try again.');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  bool _isRefreshing = false;

  /// Manually refresh feed from network, bypassing stale cache and re-ranking
  Future<void> refreshFeed({bool forceNetwork = true}) async {
    final cat = selectedCategory;
    if (forceNetwork) {
      feedCacheManager.invalidateCategory(cat, userId: currentUserId);
    }
    lastDocument = null;
    rxHasMore.value = true;
    if (cat == 'All' || cat.isEmpty) {
      await fetchMainFeedVideos(forceNetwork: forceNetwork);
      if (authService.isAuthenticated.value) {
        fetchCommunityPosts().then((_) => mixHomeFeed());
      }
    } else if (cat == 'Unexplored' || cat == '🧭 Unexplored') {
      await fetchUnexploredTabVideos();
    } else if (cat == 'Trending' || cat == '🔥 Trending') {
      await fetchTrendingTabVideos();
    } else if (cat == 'Popular' || cat == '⭐ Popular') {
      await fetchPopularTabVideos();
    } else if (cat == 'New' || cat == '✨ New') {
      await fetchNewTabVideos();
    } else if (cat == 'Flip Coin' || cat == '🪙 Flip Coin') {
      await fetchFlipCoinTabVideos();
    } else {
      await fetchCategoryTabVideos(cat);
    }
    mixHomeFeed();
  }

  Future<void> fetchCategoryContent(String category) async {
    if (Get.isRegistered<HomeDiscoveryController>()) {
      Get.find<HomeDiscoveryController>().selectedCategory.value = category;
    }
    await fetchInitialVideosInternal();
  }

  Future<void> refreshHomeFeed() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final category = selectedCategory;
      if (category == 'Posts') {
        isLoadingVideos.value = true;
        videos.clear();
        communityPosts.clear();
        lastDocument = null;
        rxHasMore.value = true;
        await fetchInitialCommunityPostsTab();
      } else if (category == 'Topics' || category == 'Explore Topics') {
        isLoadingVideos.value = false;
        if (Get.isRegistered<HomeDiscoveryController>()) {
          await Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
        }
      } else {
        await refreshFeed();
        if (category == 'All' && Get.isRegistered<HomeDiscoveryController>()) {
          await Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController.refreshHomeFeed',
      );
    } finally {
      _isRefreshing = false;
      isLoadingVideos.value = false;
    }
  }
}
