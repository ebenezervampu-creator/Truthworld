import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/feed_algorithm_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/home_feed_controller_base.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_query_builder.dart';

/// Mixin handling query generation, main personalized home feed fetching,
/// self-healing published status updates, and multi-pass category tab queries.
mixin HomeFeedCategoryTabsMixin on HomeFeedControllerBase {
  @override
  Query buildCategoryQuery({DocumentSnapshot? startAfter}) {
    final cat = selectedCategory;
    if (cat == '⭐ Popular' || cat == 'Popular') {
      return VideoQueryBuilder.publicVideos(
        firestore,
        orderByField: 'viewCount',
        startAfter: startAfter,
      );
    } else if (cat == '🔥 Trending' || cat == 'Trending') {
      return VideoQueryBuilder.publicVideos(
        firestore,
        orderByField: 'views',
        startAfter: startAfter,
      );
    } else if (cat == '✨ New' || cat == 'New') {
      return VideoQueryBuilder.publicVideos(
        firestore,
        startAfter: startAfter,
      );
    } else if (cat == 'All' ||
        cat == 'Unexplored' ||
        cat == '🧭 Unexplored' ||
        cat == 'Flip Coin' ||
        cat == '🪙 Flip Coin' ||
        cat == 'Subscriptions' ||
        cat == 'Posts') {
      return VideoQueryBuilder.publicVideos(
        firestore,
        startAfter: startAfter,
      );
    } else {
      return VideoQueryBuilder.categoryVideos(
        firestore,
        category: cat,
        withOrderBy: false,
        startAfter: startAfter,
      );
    }
  }

  FeedAlgorithmService? get feedAlgorithmService =>
      Get.isRegistered<FeedAlgorithmService>()
          ? Get.find<FeedAlgorithmService>()
          : null;

  @override
  Future<void> fetchMainFeedVideos({bool forceNetwork = false}) async {
    final currentUid = currentUserId;
    final userProfile = Get.isRegistered<UserInterestProfileService>()
        ? Get.find<UserInterestProfileService>().profile.value
        : null;

    final algorithmService = feedAlgorithmService;
    if (algorithmService != null &&
        algorithmService.isServerAvailable &&
        currentUid != null &&
        currentUid.isNotEmpty) {
      try {
        final serverVideos = await algorithmService.getPersonalizedFeed(
          userId: currentUid,
        );

        final adjusted = algorithmService.applyLocalAdjustments(
          serverVideos,
          notInterestedVideoIds: userProfile?.notInterestedVideoIds,
          blockedChannelIds: userProfile?.blockedChannelIds,
          recentlyWatchedVideoIds: userProfile?.recentlyWatchedVideoIds,
        );

        var candidates = adjusted.isNotEmpty ? adjusted : serverVideos;

        // Ensure Personalized Feed never returns 0 videos: if candidates is empty, retrieve any other fallback videos
        if (candidates.isEmpty) {
          candidates =
              await algorithmService.getPersonalizedFeedFallback();
        }

        if (candidates.isNotEmpty) {
          // YouTube-style backfill:
          // First prefer personalized videos (candidates).
          // If candidates count is lower than HomeFeedControllerBase.pageSize (low video count or content crisis),
          // query remaining available public videos from TruthWorld catalog in Firestore and append them.
          if (candidates.length < HomeFeedControllerBase.pageSize) {
            final existingIds = candidates.map((v) => v.id).toSet();
            final remainingNeeded =
                HomeFeedControllerBase.pageSize - candidates.length;
            final backfillVideos =
                await algorithmService.getAnyFallbackVideos(
              limit: remainingNeeded + existingIds.length,
            );
            for (final v in backfillVideos) {
              if (!existingIds.contains(v.id)) {
                candidates.add(v);
                existingIds.add(v.id);
                if (candidates.length >= HomeFeedControllerBase.pageSize) break;
              }
            }
          }

          final isFlipped = Get.isRegistered<FlipCoinService>() &&
              Get.find<FlipCoinService>().isHomeFlipped.value;

          if (isFlipped && Get.isRegistered<TruthworldAlgorithm>()) {
            final ranked = Get.find<TruthworldAlgorithm>().rankVideosOpposite(
              candidates,
              RecommendationSurface.homeFeedAll,
              diversityConfig: DiversityConfig.homeFeed,
            );
            videos.assignAll(ranked.map((s) => s.video).toList());
          } else {
            videos.assignAll(candidates);
          }

          saveVideosToCache('All');
          rxHasMore.value = candidates.length >= HomeFeedControllerBase.pageSize;
          return;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchMainFeedVideos.serverFeed',
        );
      }
    }

    final docMap = <String, DocumentSnapshot>{};

    // YouTube-style SWR: Revalidate fresh videos from network across uploadedAt & createdAt
    // Pass 1: Query ordered by uploadedAt DESC
    try {
      final query = VideoQueryBuilder.publicVideos(firestore);
      final results = forceNetwork
          ? await query.get(const GetOptions(source: Source.server))
          : await query.getCacheFirst();
      for (final doc in results.docs) {
        docMap[doc.id] = doc;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchMainFeedVideos.uploadedAt',
      );
    }

    // Pass 2: Query ordered by createdAt DESC to discover videos lacking uploadedAt
    if (docMap.length < HomeFeedControllerBase.pageSize) {
      try {
        final query = VideoQueryBuilder.publicVideos(
          firestore,
          orderByField: 'createdAt',
        );
        final results = forceNetwork
            ? await query.get(const GetOptions(source: Source.server))
            : await query.getCacheFirst();
        for (final doc in results.docs) {
          docMap.putIfAbsent(doc.id, () => doc);
        }
      } catch (e2, stackTrace2) {
        ErrorHandler.log(
          e2,
          stackTrace: stackTrace2,
          tag: 'HomeFeedController._fetchMainFeedVideos.createdAt',
        );
      }
    }

    // Pass 3: Unconstrained collection query fallback if both ordered queries were empty/errored
    if (docMap.isEmpty) {
      try {
        final query = firestore
            .collection('videos')
            .limit(HomeFeedControllerBase.pageSize);
        final results = forceNetwork
            ? await query.get(const GetOptions(source: Source.server))
            : await query.getCacheFirst();
        for (final doc in results.docs) {
          docMap.putIfAbsent(doc.id, () => doc);
        }
      } catch (e3, stackTrace3) {
        ErrorHandler.log(
          e3,
          stackTrace: stackTrace3,
          tag: 'HomeFeedController._fetchMainFeedVideos.unconstrainedFallback',
        );
      }
    }

    if (docMap.isNotEmpty) {
      final docsList = docMap.values.toList();
      lastDocument = docsList.last;

      // Self-heal: Asynchronously verify 'processing' items without blocking the video presentation
      if (authService.isAuthenticated.value) {
        unawaited(Future(() {
          for (final doc in docsList) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null && data['status'] == 'processing') {
              final pStage = data['aiFeatures'] is Map
                  ? data['aiFeatures']['pipelineStage']
                  : data['pipelineStage'];
              final isPub = pStage == 'published' ||
                  data['isPublished'] == true ||
                  data['publishedAt'] != null;
              if (isPub) {
                final owner = data['ownerId'] ?? data['userId'] ?? data['uploaderId'];
                if (currentUid != null && owner == currentUid) {
                  doc.reference.update({'status': 'published'}).catchError((e, s) {
                    ErrorHandler.log(
                      e,
                      stackTrace: s,
                      tag: 'HomeFeedCategoryTabsMixin.updateStatus',
                    );
                  });
                }
              }
            }
          }
        }));
      }

      final allParsed = docsList.map(Video.fromDocumentSnapshot).toList();
      // Sort newest first based on uploadedAt or createdAt
      allParsed.sort((a, b) {
        final timeA = a.uploadedAt.toDate();
        final timeB = b.uploadedAt.toDate();
        return timeB.compareTo(timeA);
      });

      final rawVideos = allParsed.sanitizeForFeed();

      if (rawVideos.isNotEmpty) {
        final isFlipped = Get.isRegistered<FlipCoinService>() &&
            Get.find<FlipCoinService>().isHomeFlipped.value;

        if (Get.isRegistered<TruthworldAlgorithm>()) {
          final algorithm = Get.find<TruthworldAlgorithm>();
          final ranked = isFlipped
              ? algorithm.rankVideosOpposite(
                  rawVideos,
                  RecommendationSurface.homeFeedAll,
                  diversityConfig: DiversityConfig.homeFeed,
                )
              : algorithm.rankVideos(
                  rawVideos,
                  RecommendationSurface.homeFeedAll,
                  diversityConfig: DiversityConfig.homeFeed,
                );
          final rankedVideos = ranked.map((s) => s.video).toList();
          videos.assignAll(rankedVideos.isNotEmpty ? rankedVideos : rawVideos);
        } else {
          videos.assignAll(rawVideos);
        }

        saveVideosToCache('All');
        if (rawVideos.length < HomeFeedControllerBase.pageSize) {
          rxHasMore.value = false;
        }
      } else {
        // Fallback: If strict sanitizeForFeed filtered out every doc, ensure playable public videos are displayed
        final playableVideos = docsList
            .map(Video.fromDocumentSnapshot)
            .where((v) =>
                v.id.isNotEmpty &&
                !v.isDraft &&
                v.status != VideoStatus.deleted &&
                v.status != VideoStatus.rejected &&
                VideoVisibilityPolicy.hasPlayableMedia(v))
            .toList();

        if (playableVideos.isNotEmpty) {
          videos.assignAll(playableVideos);
          saveVideosToCache('All');
          if (playableVideos.length < HomeFeedControllerBase.pageSize) {
            rxHasMore.value = false;
          }
        } else {
          // If we had cached videos, preserve them gracefully (YouTube offline behavior)
          if (videos.isEmpty) {
            videos.clear();
            rxHasMore.value = false;
            feedCacheManager.invalidateCategory('All', userId: currentUserId);
          }
        }
      }
    } else {
      // If network returned 0 docs but cached videos were already loaded, keep them (YouTube offline resilience)
      if (videos.isEmpty) {
        videos.clear();
        rxHasMore.value = false;
        feedCacheManager.invalidateCategory('All', userId: currentUserId);
      }
    }
  }

  @override
  Future<void> fetchCategoryTabVideos(String category) async {
    final cat = category.trim();
    final candidateDocs = <DocumentSnapshot>[];

    // 1. Try Firestore with exact category case and orderBy uploadedAt
    try {
      final snap = await firestore
          .collection('videos')
          .where('category', isEqualTo: cat)
          .orderBy('uploadedAt', descending: true)
          .limit(HomeFeedControllerBase.pageSize)
          .getCacheFirst();
      if (snap.docs.isNotEmpty) {
        candidateDocs.addAll(snap.docs);
        lastDocument = snap.docs.last;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchCategoryTabVideos.orderBy',
      );
    }

    // 2. Try Firestore with exact category case WITHOUT orderBy
    if (candidateDocs.isEmpty) {
      try {
        final snap = await firestore
            .collection('videos')
            .where('category', isEqualTo: cat)
            .limit(HomeFeedControllerBase.pageSize)
            .getCacheFirst();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          lastDocument = snap.docs.last;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchCategoryTabVideos.withoutOrderBy',
        );
      }
    }

    // 3. Try lowercase category name
    if (candidateDocs.isEmpty && cat.toLowerCase() != cat) {
      try {
        final snap = await firestore
            .collection('videos')
            .where('category', isEqualTo: cat.toLowerCase())
            .limit(HomeFeedControllerBase.pageSize)
            .getCacheFirst();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          lastDocument = snap.docs.last;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchCategoryTabVideos.lowercase',
        );
      }
    }

    // 4. Try tags matching category
    if (candidateDocs.isEmpty) {
      try {
        final snap = await firestore
            .collection('videos')
            .where('tags', arrayContains: cat.toLowerCase())
            .limit(HomeFeedControllerBase.pageSize)
            .getCacheFirst();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          lastDocument = snap.docs.last;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchCategoryTabVideos.tags',
        );
      }
    }

    // 5. Try topics matching category
    if (candidateDocs.isEmpty) {
      try {
        final snap = await firestore
            .collection('videos')
            .where('topics', arrayContains: cat.toLowerCase())
            .limit(HomeFeedControllerBase.pageSize)
            .getCacheFirst();
        if (snap.docs.isNotEmpty) {
          candidateDocs.addAll(snap.docs);
          lastDocument = snap.docs.last;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchCategoryTabVideos.topics',
        );
      }
    }

    // 6. Broader scan across recent videos if direct indexed queries didn't yield results
    if (candidateDocs.isEmpty) {
      try {
        final snap =
            await firestore.collection('videos').limit(120).getCacheFirst();
        candidateDocs.addAll(snap.docs);
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchCategoryTabVideos.broaderScan',
        );
      }
    }

    final uniqueVideos = <String, Video>{};
    for (final doc in candidateDocs) {
      try {
        final v = Video.fromDocumentSnapshot(doc);
        if (matchesCategory(v, cat) && VideoVisibilityPolicy.isVisibleForFeed(v)) {
          uniqueVideos[v.id] = v;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchCategoryTabVideos.parseVideo',
        );
      }
    }

    final catVideos = uniqueVideos.values.toList();
    var finalVideos = catVideos;

    // Fallback: If no videos matched this particular category/topics/tags,
    // never return 0 videos: fall back to any other available public videos
    if (finalVideos.isEmpty && candidateDocs.isNotEmpty) {
      final fallbackList = <Video>[];
      for (final doc in candidateDocs) {
        try {
          final v = Video.fromDocumentSnapshot(doc);
          if (VideoVisibilityPolicy.isVisibleForFeed(v)) {
            fallbackList.add(v);
          }
        } catch (_) {}
      }
      if (fallbackList.isNotEmpty) {
        finalVideos = fallbackList;
      }
    }

    // YouTube-style backfill for category tabs:
    // First prefer category-specific videos (finalVideos).
    // If count is lower than HomeFeedControllerBase.pageSize, backfill remaining slots from TruthWorld catalog
    // so category tabs never face a low video count or content crisis.
    if (finalVideos.length < HomeFeedControllerBase.pageSize) {
      final existingIds = finalVideos.map((v) => v.id).toSet();
      for (final doc in candidateDocs) {
        if (finalVideos.length >= HomeFeedControllerBase.pageSize) break;
        if (!existingIds.contains(doc.id)) {
          try {
            final v = Video.fromDocumentSnapshot(doc);
            if (VideoVisibilityPolicy.isVisibleForFeed(v)) {
              finalVideos.add(v);
              existingIds.add(v.id);
            }
          } catch (_) {}
        }
      }
      final feedAlgorithmService = Get.isRegistered<FeedAlgorithmService>()
          ? Get.find<FeedAlgorithmService>()
          : null;
      if (finalVideos.length < HomeFeedControllerBase.pageSize &&
          feedAlgorithmService != null) {
        try {
          final remainingNeeded =
              HomeFeedControllerBase.pageSize - finalVideos.length;
          final moreVideos = await feedAlgorithmService.getAnyFallbackVideos(
            limit: remainingNeeded + existingIds.length,
          );
          for (final v in moreVideos) {
            if (!existingIds.contains(v.id)) {
              finalVideos.add(v);
              existingIds.add(v.id);
              if (finalVideos.length >= HomeFeedControllerBase.pageSize) break;
            }
          }
        } catch (_) {}
      }
    }

    if (finalVideos.isNotEmpty) {
      finalVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(
          finalVideos,
          RecommendationSurface.homeFeedCategory,
        );
        final rankedList = ranked.map((s) => s.video).toList();
        videos.assignAll(rankedList.isNotEmpty ? rankedList : finalVideos);
      } else {
        videos.assignAll(finalVideos);
      }

      saveVideosToCache(cat);
      rxHasMore.value = finalVideos.length >= HomeFeedControllerBase.pageSize;
    } else {
      if (videos.isEmpty) {
        videos.clear();
        rxHasMore.value = false;
        feedCacheManager.invalidateCategory(cat, userId: currentUserId);
      }
    }

    try {
      final topicDocs = await firestore
          .collection('topics')
          .where('status', isEqualTo: 'active')
          .where('category', isEqualTo: cat)
          .limit(10)
          .getCacheFirst();
      if (Get.isRegistered<HomeDiscoveryController>()) {
        final discoveryCtrl = Get.find<HomeDiscoveryController>();
        if (topicDocs.docs.isNotEmpty) {
          final catTopics = topicDocs.docs
              .map(Topic.fromDocumentSnapshot)
              .where((t) => t.isValidTopic && t.videoCount > 0)
              .toList();
          if (catTopics.isNotEmpty) {
            discoveryCtrl.featuredTopics.assignAll(catTopics);
          } else {
            discoveryCtrl.featuredTopics.clear();
          }
        } else {
          discoveryCtrl.featuredTopics.clear();
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchCategoryTabVideos.fetchCategoryTopics',
      );
    }
  }
}

