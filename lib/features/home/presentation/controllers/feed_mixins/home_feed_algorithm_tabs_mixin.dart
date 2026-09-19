import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/home_feed_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Mixin handling algorithmic feed tabs: Trending, Popular,
/// New, Unexplored, and Flip Coin.
mixin HomeFeedAlgorithmTabsMixin on HomeFeedControllerBase {
  @override
  Future<void> fetchTrendingTabVideos() async {
    const limit = 60;

    if (homeRepository != null) {
      final repoRes = await homeRepository!.getHomeFeed(limit: limit);
      if (repoRes.isSuccess && repoRes.dataOrNull != null && repoRes.dataOrNull!.isNotEmpty) {
        final rawVideos = repoRes.dataOrNull!
            .map(Video.fromEntity)
            .toList()
            .sanitizeForFeed();

        rawVideos.sort((a, b) {
          final daysA = DateTime.now().difference(a.createdAt.toDate()).inDays + 1;
          final daysB = DateTime.now().difference(b.createdAt.toDate()).inDays + 1;
          final viewsA = (a.views > 0 ? a.views : a.viewCount).toDouble();
          final viewsB = (b.views > 0 ? b.views : b.viewCount).toDouble();
          final scoreA = (viewsA * 0.5) +
              (a.likes * 0.3) +
              (a.commentCount * 0.2) +
              ((1.0 / daysA) * 100) +
              (a.trustScore * 10);
          final scoreB = (viewsB * 0.5) +
              (b.likes * 0.3) +
              (b.commentCount * 0.2) +
              ((1.0 / daysB) * 100) +
              (b.trustScore * 10);
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

        saveVideosToCache('Trending');
        if (rawVideos.length < limit) rxHasMore.value = false;
        return;
      }
    }

    QuerySnapshot? results;

    try {
      results = await firestore
          .collection('videos')
          .orderBy('viewCount', descending: true)
          .limit(limit)
          .get();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchTrendingTabVideos.viewCount',
      );
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await firestore
            .collection('videos')
            .orderBy('views', descending: true)
            .limit(limit)
            .get();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchTrendingTabVideos.views',
        );
      }
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await firestore
            .collection('videos')
            .orderBy('uploadedAt', descending: true)
            .limit(limit)
            .get();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchTrendingTabVideos.uploadedAt',
        );
        try {
          results = await firestore.collection('videos').limit(limit).get();
        } catch (e2, stackTrace2) {
          ErrorHandler.log(
            e2,
            stackTrace: stackTrace2,
            tag: 'HomeFeedController._fetchTrendingTabVideos.unconstrainedFallback',
          );
        }
      }
    }

    if (results != null && results.docs.isNotEmpty) {
      lastDocument = results.docs.last;
      final rawVideos = results.docs
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      rawVideos.sort((a, b) {
        final daysA = DateTime.now().difference(a.createdAt.toDate()).inDays + 1;
        final daysB = DateTime.now().difference(b.createdAt.toDate()).inDays + 1;
        final viewsA = (a.views > 0 ? a.views : a.viewCount).toDouble();
        final viewsB = (b.views > 0 ? b.views : b.viewCount).toDouble();
        final scoreA = (viewsA * 0.5) +
            (a.likes * 0.3) +
            (a.commentCount * 0.2) +
            ((1.0 / daysA) * 100) +
            (a.trustScore * 10);
        final scoreB = (viewsB * 0.5) +
            (b.likes * 0.3) +
            (b.commentCount * 0.2) +
            ((1.0 / daysB) * 100) +
            (b.trustScore * 10);
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

      saveVideosToCache('Trending');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
      feedCacheManager.invalidateCategory('Trending', userId: currentUserId);
    }
  }

  @override
  Future<void> fetchPopularTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    try {
      results = await firestore
          .collection('videos')
          .orderBy('viewCount', descending: true)
          .limit(limit)
          .get();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchPopularTabVideos.viewCount',
      );
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await firestore
            .collection('videos')
            .orderBy('views', descending: true)
            .limit(limit)
            .get();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchPopularTabVideos.views',
        );
      }
    }

    if (results == null || results.docs.isEmpty) {
      try {
        results = await firestore.collection('videos').limit(limit).get();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchPopularTabVideos.unconstrainedFallback',
        );
      }
    }

    if (results != null && results.docs.isNotEmpty) {
      lastDocument = results.docs.last;
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
      saveVideosToCache('Popular');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
      feedCacheManager.invalidateCategory('Popular', userId: currentUserId);
    }
  }

  @override
  Future<void> fetchNewTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    try {
      results = await firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
          .get();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchNewTabVideos.uploadedAt',
      );
      try {
        results = await firestore
            .collection('videos')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
      } catch (e2, stackTrace2) {
        ErrorHandler.log(
          e2,
          stackTrace: stackTrace2,
          tag: 'HomeFeedController._fetchNewTabVideos.createdAt',
        );
        try {
          results = await firestore.collection('videos').limit(limit).get();
        } catch (e3, stackTrace3) {
          ErrorHandler.log(
            e3,
            stackTrace: stackTrace3,
            tag: 'HomeFeedController._fetchNewTabVideos.unconstrainedFallback',
          );
        }
      }
    }

    if (results != null && results.docs.isNotEmpty) {
      lastDocument = results.docs.last;
      final rawVideos = results.docs
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      rawVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      videos.assignAll(rawVideos);
      saveVideosToCache('New');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
      feedCacheManager.invalidateCategory('New', userId: currentUserId);
    }
  }

  @override
  Future<void> fetchUnexploredTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    // Ensure UserInterestProfile is loaded for authenticated user
    if (Get.isRegistered<UserInterestProfileService>()) {
      final profileService = UserInterestProfileService.to;
      if (profileService.currentProfile == null && authService.uid.isNotEmpty) {
        await profileService.loadProfile(authService.uid);
      }
    }

    try {
      results = await firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
          .get();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchUnexploredTabVideos.uploadedAt',
      );
      try {
        results = await firestore.collection('videos').limit(limit).get();
      } catch (e2, stackTrace2) {
        ErrorHandler.log(
          e2,
          stackTrace: stackTrace2,
          tag: 'HomeFeedController._fetchUnexploredTabVideos.unconstrainedFallback',
        );
      }
    }

    final candidateDocMap = <String, DocumentSnapshot>{};
    if (results != null) {
      for (final doc in results.docs) {
        candidateDocMap[doc.id] = doc;
      }
    }

    // Query candidate videos specifically from the user's Unexplored Categories
    if (Get.isRegistered<UserInterestProfileService>()) {
      final profile = UserInterestProfileService.to.currentProfile;
      if (profile != null) {
        final unexploredCats = profile.getUnexploredCategories();
        for (final cat in unexploredCats.take(4)) {
          try {
            final catSnap = await firestore
                .collection('videos')
                .where('category', isEqualTo: cat)
                .limit(15)
                .get();
            for (final doc in catSnap.docs) {
              candidateDocMap[doc.id] = doc;
            }
          } catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'HomeFeedController._fetchUnexploredTabVideos.candidateQuery',
            );
          }
        }
      }
    }

    if (candidateDocMap.isNotEmpty) {
      lastDocument = candidateDocMap.values.last;
      final rawVideos = candidateDocMap.values
          .map(Video.fromDocumentSnapshot)
          .toList()
          .sanitizeForFeed();

      // Disqualify already watched videos from candidates
      final watchedIds = getWatchedVideoIds();
      final candidateVideos =
          rawVideos.where((v) => !watchedIds.contains(v.id)).toList();

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideosUnexplored(
          candidateVideos,
          RecommendationSurface.unexplored,
          diversityConfig: DiversityConfig.unexplored,
        );
        videos.assignAll(ranked.map((s) => s.video).toList());
      } else {
        candidateVideos.shuffle();
        videos.assignAll(candidateVideos);
      }

      pruneWatchedVideosFromUnexplored();
      saveVideosToCache('Unexplored');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
      feedCacheManager.invalidateCategory('Unexplored', userId: currentUserId);
    }
  }

  @override
  Future<void> fetchFlipCoinTabVideos() async {
    const limit = 60;
    QuerySnapshot? results;

    try {
      results = await firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
          .get();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchFlipCoinTabVideos.uploadedAt',
      );
      try {
        results = await firestore.collection('videos').limit(limit).get();
      } catch (e2, stackTrace2) {
        ErrorHandler.log(
          e2,
          stackTrace: stackTrace2,
          tag: 'HomeFeedController._fetchFlipCoinTabVideos.unconstrainedFallback',
        );
      }
    }

    final candidateDocMap = <String, DocumentSnapshot>{};
    if (results != null) {
      for (final doc in results.docs) {
        candidateDocMap[doc.id] = doc;
      }
    }

    // Query candidate videos representing The Other Side of the Coin
    if (Get.isRegistered<UserInterestProfileService>()) {
      final profile = UserInterestProfileService.to.currentProfile;
      if (profile != null && profile.categoryAffinities.isNotEmpty) {
        final contrastCats = profile.categoryAffinities.keys
            .where((c) => (profile.categoryAffinities[c] ?? 0.0) < 0.2)
            .take(3);
        for (final cat in contrastCats) {
          try {
            final catSnap = await firestore
                .collection('videos')
                .where('category', isEqualTo: cat)
                .limit(15)
                .get();
            for (final doc in catSnap.docs) {
              candidateDocMap[doc.id] = doc;
            }
          } catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'HomeFeedController._fetchFlipCoinTabVideos.contrastCategory',
            );
          }
        }
      }
    }

    if (candidateDocMap.isNotEmpty) {
      lastDocument = candidateDocMap.values.last;
      final rawVideos = candidateDocMap.values
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

      saveVideosToCache('Flip Coin');
      if (rawVideos.length < limit) rxHasMore.value = false;
    } else {
      videos.clear();
      rxHasMore.value = false;
      feedCacheManager.invalidateCategory('Flip Coin', userId: currentUserId);
    }
  }
}

