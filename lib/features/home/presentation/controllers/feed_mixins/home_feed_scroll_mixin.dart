import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/home_feed_controller_base.dart';
import 'package:truthworld/features/home/presentation/controllers/home_navigation_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Mixin handling scroll tracking, bottom navigation auto-hide,
/// pull-to-refresh resets, and infinite scroll video pagination.
mixin HomeFeedScrollMixin on HomeFeedControllerBase {
  void bindScrollListener() {
    scrollController.addListener(scrollListener);
  }

  void scrollListener() {
    if (!scrollController.hasClients || scrollController.positions.length != 1) return;

    final position = scrollController.position;
    final currentScroll = position.pixels;

    if (Get.isRegistered<HomeNavigationController>()) {
      final navCtrl = Get.find<HomeNavigationController>();
      if (currentScroll > lastScrollPosition && currentScroll > 50) {
        if (navCtrl.showBottomNav.value) navCtrl.showBottomNav.value = false;
      } else if (currentScroll < lastScrollPosition) {
        if (!navCtrl.showBottomNav.value) navCtrl.showBottomNav.value = true;
      }
    }
    lastScrollPosition = currentScroll;

    final scrollPercentage = (position.pixels / position.maxScrollExtent) * 100;

    if (scrollPercentage >= HomeFeedControllerBase.loadMoreThreshold &&
        !isLoadingMore.value &&
        rxHasMore.value) {
      fetchMoreVideos();
    }
  }

  void onScrollNotification(ScrollUpdateNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return;
    if (notification.dragDetails == null) return;
    final delta = notification.scrollDelta ?? 0;
    if (delta.abs() < HomeFeedControllerBase.kScrollThreshold) return;

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

  void resetFeedAndFetch() {
    videos.clear();
    lastDocument = null;
    rxHasMore.value = true;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    fetchInitialVideos();
  }

  @override
  Future<void> fetchMoreVideos() async {
    if (isLoadingMore.value || !rxHasMore.value || lastDocument == null) return;
    isLoadingMore.value = true;
    try {
      final currentCat = selectedCategory;
      if (currentCat == 'Posts') {
        await fetchMoreCommunityPostsTab();
        return;
      }

      final isSpecialTab = currentCat == 'All' ||
          currentCat == 'Unexplored' ||
          currentCat == '🧭 Unexplored' ||
          currentCat == '🔥 Trending' ||
          currentCat == 'Trending' ||
          currentCat == '⭐ Popular' ||
          currentCat == 'Popular' ||
          currentCat == '✨ New' ||
          currentCat == 'New' ||
          currentCat == 'Flip Coin' ||
          currentCat == '🪙 Flip Coin';

      final query = buildCategoryQuery(startAfter: lastDocument);
      final results = await query.limit(HomeFeedControllerBase.pageSize).get().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Loading more videos'),
          );

      if (results.docs.isNotEmpty) {
        lastDocument = results.docs.last;
        final rawVideos = results.docs
            .map(Video.fromDocumentSnapshot)
            .toList()
            .sanitizeForFeed();

        final filteredVideos = isSpecialTab
            ? rawVideos
            : rawVideos.where((v) => matchesCategory(v, currentCat)).toList();

        if (filteredVideos.isNotEmpty) {
          final isFlipped = (currentCat == 'Flip Coin' || currentCat == '🪙 Flip Coin') ||
              (Get.isRegistered<FlipCoinService>() &&
                  Get.find<FlipCoinService>().isHomeFlipped.value);
          final isUnexplored =
              currentCat == 'Unexplored' || currentCat == '🧭 Unexplored';

          List<Video> videosToAdd;
          if (isFlipped && Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final ranked = algorithm.rankVideosOpposite(
              filteredVideos,
              RecommendationSurface.homeFeedAll,
              diversityConfig: DiversityConfig.homeFeed,
            );
            videosToAdd = ranked.map((s) => s.video).toList();
          } else if (isUnexplored) {
            final watchedIds = getWatchedVideoIds();
            final unexpCandidates =
                filteredVideos.where((v) => !watchedIds.contains(v.id)).toList();
            if (Get.isRegistered<TruthworldAlgorithm>()) {
              final algorithm = Get.find<TruthworldAlgorithm>();
              final ranked = algorithm.rankVideosUnexplored(
                unexpCandidates,
                RecommendationSurface.unexplored,
                diversityConfig: DiversityConfig.unexplored,
              );
              videosToAdd = ranked.map((s) => s.video).toList();
            } else {
              videosToAdd = unexpCandidates;
            }
          } else if ((currentCat == '🔥 Trending' || currentCat == 'Trending') &&
              Get.isRegistered<TruthworldAlgorithm>()) {
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
          final uniqueNewVideos = <Video>[];
          for (final v in videosToAdd) {
            if (v.id.isNotEmpty && existingIds.add(v.id)) {
              uniqueNewVideos.add(v);
            }
          }
          if (uniqueNewVideos.isNotEmpty) {
            videos.addAll(uniqueNewVideos);
            if (isUnexplored) {
              pruneWatchedVideosFromUnexplored();
            }
          }
          if (results.docs.length < HomeFeedControllerBase.pageSize) {
            rxHasMore.value = false;
          }
        } else {
          rxHasMore.value = false;
        }
      } else {
        rxHasMore.value = false;
      }

      mixHomeFeed();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController.fetchMoreVideos',
      );
      rxHasMore.value = false;
    } finally {
      isLoadingMore.value = false;
    }
  }
}

