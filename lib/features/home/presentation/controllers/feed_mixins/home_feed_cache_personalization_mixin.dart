import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/widgets/truthworld_splash_screen.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/home_feed_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Mixin managing feed caching, personalization pruning,
/// interest profile dynamic re-ranking, and feed item synthesis.
mixin HomeFeedCachePersonalizationMixin on HomeFeedControllerBase {
  static final Map<String, String> _normalizedCatCache = {};

  @override
  bool matchesCategory(Video v, String cat) {
    final cleanCat = cat.trim().toLowerCase();
    if (cleanCat.isEmpty || cleanCat == 'all') return true;

    final targetNorm = _normalizedCatCache[cat] ??=
        AppCategories.normalizeCategory(cat).toLowerCase();

    // 1. Direct category match & normalized category match
    final vCat = v.category.trim().toLowerCase();
    if (vCat.isNotEmpty) {
      if (vCat == cleanCat || vCat == targetNorm) return true;
      final normVCat = AppCategories.normalizeCategory(v.category).toLowerCase();
      if (normVCat == cleanCat || normVCat == targetNorm) return true;

      final vParts = vCat.split(RegExp(r'[\/&,]')).map((s) => s.trim().toLowerCase());
      if (vParts.contains(cleanCat) || vParts.contains(targetNorm)) return true;

      final targetParts = cleanCat.split(RegExp(r'[\/&,]')).map((s) => s.trim().toLowerCase());
      if (targetParts.contains(vCat) || targetParts.contains(normVCat)) return true;
    }

    // 2. VideoCategory or effectiveCategory match if present
    final effectiveCat = (v.effectiveCategory ?? '').trim().toLowerCase();
    if (effectiveCat.isNotEmpty) {
      if (effectiveCat == cleanCat || effectiveCat == targetNorm) return true;
      final normEff = AppCategories.normalizeCategory(effectiveCat).toLowerCase();
      if (normEff == cleanCat || normEff == targetNorm) return true;
    }

    // 3. Exact tag match or normalized tag match (word-bounded, zero loose substring bleed)
    for (final tag in v.tags) {
      final t = tag.trim().toLowerCase();
      if (t.isEmpty) continue;
      if (t == cleanCat || t == targetNorm) return true;
      if (AppCategories.normalizeCategory(t).toLowerCase() == cleanCat ||
          AppCategories.normalizeCategory(t).toLowerCase() == targetNorm) {
        return true;
      }
      final words = t.split(RegExp(r'[\s\-_]+'));
      for (final word in words) {
        if (word == cleanCat || word == targetNorm) return true;
        if (AppCategories.normalizeCategory(word).toLowerCase() == cleanCat ||
            AppCategories.normalizeCategory(word).toLowerCase() == targetNorm) {
          return true;
        }
      }
    }

    // 4. Exact topic match or normalized topic match (word-bounded, zero loose substring bleed)
    for (final topic in v.topics) {
      final t = topic.trim().toLowerCase();
      if (t.isEmpty) continue;
      if (t == cleanCat || t == targetNorm) return true;
      if (AppCategories.normalizeCategory(t).toLowerCase() == cleanCat ||
          AppCategories.normalizeCategory(t).toLowerCase() == targetNorm) {
        return true;
      }
      final words = t.split(RegExp(r'[\s\-_]+'));
      for (final word in words) {
        if (word == cleanCat || word == targetNorm) return true;
        if (AppCategories.normalizeCategory(word).toLowerCase() == cleanCat ||
            AppCategories.normalizeCategory(word).toLowerCase() == targetNorm) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  Set<String> getWatchedVideoIds() {
    final watched = <String>{};
    if (Get.isRegistered<UserInterestProfileService>()) {
      final profile = UserInterestProfileService.to.currentProfile;
      if (profile != null) {
        watched.addAll(profile.recentlyWatchedVideoIds);
        watched.addAll(profile.watchProgress.keys);
      }
    }
    if (Get.isRegistered<WatchHistoryService>()) {
      watched.addAll(WatchHistoryService.to.allWatchedVideoIds);
    }
    return watched;
  }

  @override
  void pruneWatchedVideosFromUnexplored() {
    final cat = selectedCategory;
    if (cat != 'Unexplored' && cat != '🧭 Unexplored') return;
    final watchedIds = getWatchedVideoIds();
    if (watchedIds.isEmpty) return;

    final initialLen = videos.length;
    videos.removeWhere((v) => watchedIds.contains(v.id));
    if (videos.length != initialLen) {
      mixHomeFeed();
      saveVideosToCache('Unexplored');
    }
  }

  @override
  void rerankActiveFeedOnProfileUpdate() {
    final cat = selectedCategory;
    if ((cat == 'All' || cat.isEmpty) &&
        videos.isNotEmpty &&
        Get.isRegistered<TruthworldAlgorithm>()) {
      final algorithm = Get.find<TruthworldAlgorithm>();
      final ranked = algorithm.rankVideos(
        videos.toList(),
        RecommendationSurface.homeFeedAll,
        diversityConfig: DiversityConfig.homeFeed,
      );
      final rankedVideos = ranked.map((s) => s.video).toList();
      if (rankedVideos.isNotEmpty) {
        videos.assignAll(rankedVideos);
        mixHomeFeed();
      }
    } else if (cat == 'Unexplored' || cat == '🧭 Unexplored') {
      pruneWatchedVideosFromUnexplored();
    }
  }

  @override
  void loadCachedVideos([String? category]) {
    try {
      final cat = category ?? selectedCategory;
      final cacheKey = FeedCacheManager.cacheKeyForCategory(cat, userId: currentUserId);
      final cachedVideos = feedCacheManager.getValidCachedVideos(cacheKey);
      if (cachedVideos != null && cachedVideos.isNotEmpty && videos.isEmpty) {
        final isSpecialTab = cat == 'All' ||
            cat == 'Unexplored' ||
            cat == '🧭 Unexplored' ||
            cat == '🔥 Trending' ||
            cat == 'Trending' ||
            cat == '⭐ Popular' ||
            cat == 'Popular' ||
            cat == '✨ New' ||
            cat == 'New' ||
            cat == 'Flip Coin' ||
            cat == '🪙 Flip Coin';

        if (cat == 'Unexplored' || cat == '🧭 Unexplored') {
          final watchedIds = getWatchedVideoIds();
          final seenIds = <String>{};
          final validUnexplored = cachedVideos
              .where((v) =>
                  v.id.isNotEmpty &&
                  !watchedIds.contains(v.id) &&
                  seenIds.add(v.id))
              .toList();
          if (validUnexplored.isEmpty) {
            return;
          }
          videos.assignAll(validUnexplored);
        } else if (!isSpecialTab) {
          final seenIds = <String>{};
          final validForCategory = cachedVideos
              .where((v) =>
                  v.id.isNotEmpty &&
                  matchesCategory(v, cat) &&
                  seenIds.add(v.id))
              .toList();
          if (validForCategory.isEmpty) {
            return;
          }
          videos.assignAll(validForCategory);
        } else if (cat == 'All' && Get.isRegistered<TruthworldAlgorithm>()) {
          final algorithm = Get.find<TruthworldAlgorithm>();
          final ranked = algorithm.rankVideos(
            cachedVideos,
            RecommendationSurface.homeFeedAll,
            diversityConfig: DiversityConfig.homeFeed,
          );
          final rankedVideos = ranked.map((s) => s.video).toList();
          final seenIds = <String>{};
          final distinct = (rankedVideos.isNotEmpty ? rankedVideos : cachedVideos)
              .where((v) => v.id.isNotEmpty && seenIds.add(v.id))
              .toList();
          videos.assignAll(distinct);
        } else {
          final seenIds = <String>{};
          videos.assignAll(
            cachedVideos.where((v) => v.id.isNotEmpty && seenIds.add(v.id)).toList(),
          );
        }
        mixHomeFeed();
        isLoadingVideos.value = false;
        precacheTopThumbnails(videos.take(4).toList());
        TruthworldSplashScreen.dismiss();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._loadCachedVideos',
      );
    }
  }

  /// Proactively pre-cache top video thumbnails into memory to eliminate render delay
  void precacheTopThumbnails(List<Video> topVideos) {
    if (topVideos.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = Get.context;
      if (context == null || !context.mounted) return;
      for (final v in topVideos) {
        if (v.thumbnailUrl.isNotEmpty) {
          try {
            precacheImage(
              CachedNetworkImageProvider(
                v.thumbnailUrl,
                maxWidth: kIsWeb ? null : 1280,
              ),
              context,
            );
          } catch (_) {}
        }
      }
    });
  }

  @override
  void saveVideosToCache([String? category]) {
    try {
      final cat = category ?? selectedCategory;
      if (videos.isNotEmpty &&
          cat != 'Posts' &&
          cat != 'Subscriptions' &&
          cat != 'Topics' &&
          cat != 'Explore Topics') {
        final isSpecialTab = cat == 'All' ||
            cat == 'Unexplored' ||
            cat == '🧭 Unexplored' ||
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
            : videos.where((v) => matchesCategory(v, cat)).toList();

        if (videosToCache.isNotEmpty) {
          final cacheKey = FeedCacheManager.cacheKeyForCategory(cat, userId: currentUserId);
          feedCacheManager.saveFeedToCache(cacheKey, videosToCache);
          precacheTopThumbnails(videosToCache.take(4).toList());
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._saveVideosToCache',
      );
    }
  }

  @override
  void mixHomeFeed() {
    if (selectedCategory == 'Posts') {
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

    final isAuth =
        Get.isRegistered<AuthService>() && authService.isAuthenticated.value;

    final seenVideoIds = <String>{};
    final uniqueVideos = <Video>[];
    for (final v in videos) {
      if (v.id.isNotEmpty && seenVideoIds.add(v.id)) {
        uniqueVideos.add(v);
      }
    }

    while (videoIndex < uniqueVideos.length) {
      for (var i = 0; i < 6 && videoIndex < uniqueVideos.length; i++) {
        mixed.add(uniqueVideos[videoIndex++]);
      }
      if (isAuth && postIndex < communityPosts.length && selectedCategory == 'All') {
        mixed.add(communityPosts[postIndex++]);
      }
      if (homepageAds.isNotEmpty && videoIndex < uniqueVideos.length) {
        mixed.add(homepageAds[adIndex++ % homepageAds.length]);
      }
    }

    if (homepageAds.isNotEmpty && !mixed.any((item) => item is AdItem) && mixed.isNotEmpty) {
      final insertPos = mixed.length >= 3 ? 3 : mixed.length;
      mixed.insert(insertPos, homepageAds.first);
    }

    homeFeedItems.assignAll(mixed);
  }
}

