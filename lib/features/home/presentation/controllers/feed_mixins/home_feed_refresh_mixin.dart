import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/home_feed_controller_base.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';

/// Mixin implementing YouTube-exact Home Feed refresh lifecycle
/// for [HomeFeedControllerBase] and [HomeFeedController].
///
/// Implements YouTube's Two-Stage Refresh & Recommendation Architecture:
/// 1. Session Impression / Seen-Video Memory: Tracks visible video IDs so that on pull-to-refresh,
///    already-viewed videos yield top spots to fresh unseen candidates.
/// 2. YouTube Refresh Epoch: Increments on every refresh to apply exploration jitter and rotation.
/// 3. YouTube Small-Catalog Serendipity Rotation: In small catalogs where all items have been seen,
///    deterministically shifts the candidate window so lower videos rotate into top hero positions.
/// 4. Smooth Scroll Reset: Ensures user starts at the top of the newly refreshed feed.
mixin HomeFeedYouTubeRefreshMixin on HomeFeedControllerBase {
  bool _isYouTubeRefreshing = false;
  bool get isYouTubeRefreshing => _isYouTubeRefreshing;

  /// Executes YouTube-style pull-to-refresh:
  /// 1. Records currently displayed videos into session impression memory
  /// 2. Increments YouTube refresh epoch
  /// 3. Invalidates category cache in FeedCacheManager
  /// 4. Revalidates fresh candidate pool from network
  /// 5. Re-ranks candidates with YouTube seen-demotion & refresh rotation
  /// 6. Blends community posts & ads via mixHomeFeed
  /// 7. Updates persistent cache for offline resilience
  /// 8. Resets scroll controller to top smoothly
  Future<void> executeYouTubeFeedRefresh({bool forceNetwork = true}) async {
    if (_isYouTubeRefreshing) return;
    _isYouTubeRefreshing = true;
    try {
      final currentCat = selectedCategory;

      // 1. Record currently displayed video IDs to YouTube impression tracker
      if (videos.isNotEmpty) {
        final currentVisibleIds = videos
            .map((v) => v.id)
            .where((id) => id.isNotEmpty)
            .toSet();
        youtubeFeedRefreshService.markVideosAsSeen(currentVisibleIds);
        if (videos.first.id.isNotEmpty) {
          youtubeFeedRefreshService.setLastTopVideoId(videos.first.id);
        }
      }

      // 2. Increment YouTube refresh epoch
      youtubeFeedRefreshService.incrementRefreshEpoch();

      // 3. Invalidate category cache in FeedCacheManager
      if (forceNetwork) {
        feedCacheManager.invalidateCategory(currentCat, userId: currentUserId);
      }

      lastDocument = null;
      rxHasMore.value = true;

      // 4. Fetch and re-rank according to active tab
      if (currentCat == 'Posts') {
        isLoadingVideos.value = true;
        videos.clear();
        communityPosts.clear();
        lastDocument = null;
        rxHasMore.value = true;
        await fetchInitialCommunityPostsTab();
      } else if (currentCat == 'Topics' || currentCat == 'Explore Topics') {
        isLoadingVideos.value = false;
        if (Get.isRegistered<HomeDiscoveryController>()) {
          await Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
        }
      } else if (currentCat == 'All' || currentCat.isEmpty) {
        await fetchMainFeedVideos(forceNetwork: forceNetwork);
        if (authService.isAuthenticated.value) {
          fetchCommunityPosts().then((_) => mixHomeFeed());
        }
        if (Get.isRegistered<HomeDiscoveryController>()) {
          Get.find<HomeDiscoveryController>().fetchFeaturedTopics();
        }
      } else if (currentCat == 'Unexplored' || currentCat == '🧭 Unexplored') {
        await fetchUnexploredTabVideos();
      } else if (currentCat == 'Trending' || currentCat == '🔥 Trending') {
        await fetchTrendingTabVideos();
      } else if (currentCat == 'Popular' || currentCat == '⭐ Popular') {
        await fetchPopularTabVideos();
      } else if (currentCat == 'New' || currentCat == '✨ New') {
        await fetchNewTabVideos();
      } else if (currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin') {
        await fetchFlipCoinTabVideos();
      } else {
        await fetchCategoryTabVideos(currentCat);
      }

      // 5. Synthesize final mixed feed with community posts and ads
      mixHomeFeed();

      // 6. Smoothly reset scroll position to top if needed (YouTube behavior)
      if (scrollController.hasClients && scrollController.offset > 0) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedYouTubeRefreshMixin.executeYouTubeFeedRefresh',
      );
    } finally {
      _isYouTubeRefreshing = false;
      isLoadingVideos.value = false;
    }
  }
}
