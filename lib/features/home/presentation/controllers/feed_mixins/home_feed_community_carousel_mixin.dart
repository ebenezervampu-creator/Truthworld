import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/home_feed_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_query_builder.dart';

/// Mixin handling carousel media fetching and community post pagination.
mixin HomeFeedCommunityCarouselMixin on HomeFeedControllerBase {
  @override
  Future<void> fetchCarouselVideos() async {
    await safeExecute(fetchCarouselVideosInternal, showLoading: false);
  }

  @override
  Future<void> fetchCarouselVideosInternal() async {
    isCarouselLoading.value = true;
    try {
      final results = await Future.wait([
        fetchPublicVideos(),
        fetchCategoryVideos('Music'),
        fetchTrendingVideos(),
      ]);
      recommendedVideos.assignAll(results[0]);
      musicVideos.assignAll(results[1]);
      trendingVideos.assignAll(results[2]);
      clearError();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchCarouselVideosInternal',
      );
    } finally {
      isCarouselLoading.value = false;
    }
  }

  Future<List<Video>> fetchPublicVideos({int limit = 10}) async {
    final results =
        await VideoQueryBuilder.publicVideos(firestore, limit: limit).get();
    final rawList = results.docs.map(Video.fromDocumentSnapshot).toList();
    return rawList.sanitizeForRecommendation();
  }

  Future<List<Video>> fetchCategoryVideos(String category, {int limit = 10}) async {
    final results = await VideoQueryBuilder.publicVideos(
      firestore,
      category: category,
      limit: limit,
    ).get();
    final rawList = results.docs.map(Video.fromDocumentSnapshot).toList();
    return rawList.sanitizeForRecommendation();
  }

  Future<List<Video>> fetchTrendingVideos({int limit = 10}) async {
    final results = await VideoQueryBuilder.publicVideos(
      firestore,
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

  @override
  Future<void> fetchInitialCommunityPostsTab() async {
    try {
      var docs = <DocumentSnapshot>[];

      // 1. Try primary collection 'Community' with order
      try {
        final snapshot = await firestore
            .collection(FirestoreCollections.community)
            .orderBy('uploadedAt', descending: true)
            .limit(HomeFeedControllerBase.pageSize)
            .get();
        if (snapshot.docs.isNotEmpty) {
          docs = snapshot.docs;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchInitialCommunityPostsTab.uploadedAt',
        );
      }

      // 2. Try primary collection 'Community' with timestamp order
      if (docs.isEmpty) {
        try {
          final snapshot = await firestore
              .collection(FirestoreCollections.community)
              .orderBy('timestamp', descending: true)
              .limit(HomeFeedControllerBase.pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'HomeFeedController._fetchInitialCommunityPostsTab.timestamp',
          );
        }
      }

      // 3. Try primary collection 'Community' without order (handles varied date fields)
      if (docs.isEmpty) {
        try {
          final snapshot = await firestore
              .collection(FirestoreCollections.community)
              .limit(HomeFeedControllerBase.pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'HomeFeedController._fetchInitialCommunityPostsTab.withoutOrder',
          );
        }
      }

      // 4. Try lowercase 'community' collection
      if (docs.isEmpty) {
        try {
          final snapshot = await firestore
              .collection('community')
              .limit(HomeFeedControllerBase.pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'HomeFeedController._fetchInitialCommunityPostsTab.lowercase',
          );
        }
      }

      // 5. Try 'community_posts' collection
      if (docs.isEmpty) {
        try {
          final snapshot = await firestore
              .collection('community_posts')
              .limit(HomeFeedControllerBase.pageSize)
              .get();
          if (snapshot.docs.isNotEmpty) {
            docs = snapshot.docs;
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'HomeFeedController._fetchInitialCommunityPostsTab.communityPosts',
          );
        }
      }

      if (docs.isNotEmpty) {
        lastDocument = docs.last;
        final posts = <CommunityPostModel>[];
        for (final doc in docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data()! as Map);
            data.putIfAbsent('id', () => doc.id);
            final post = CommunityPostModel.fromMap(data);
            if (post.isValid && !post.isDraft) {
              posts.add(post);
            }
          } catch (docErr, stackTrace) {
            ErrorHandler.log(
              docErr,
              stackTrace: stackTrace,
              tag: 'HomeFeedController._fetchInitialCommunityPostsTab.parsePost',
            );
          }
        }

        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.assignAll(posts);
        homeFeedItems.assignAll(posts);
        rxHasMore.value = docs.length >= HomeFeedControllerBase.pageSize;
      } else {
        communityPosts.clear();
        homeFeedItems.clear();
        rxHasMore.value = false;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchInitialCommunityPostsTab',
      );
      communityPosts.clear();
      homeFeedItems.clear();
      rxHasMore.value = false;
    }
  }

  @override
  Future<void> fetchMoreCommunityPostsTab() async {
    if (lastDocument == null) {
      rxHasMore.value = false;
      return;
    }
    try {
      var docs = <DocumentSnapshot>[];
      try {
        final snapshot = await firestore
            .collection(FirestoreCollections.community)
            .startAfterDocument(lastDocument!)
            .limit(HomeFeedControllerBase.pageSize)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Loading more posts'),
            );
        if (snapshot.docs.isNotEmpty) {
          docs = snapshot.docs;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeFeedController._fetchMoreCommunityPostsTab.paginatedQuery',
        );
      }

      if (docs.isNotEmpty) {
        lastDocument = docs.last;
        final newPosts = <CommunityPostModel>[];
        for (final doc in docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data()! as Map);
            data.putIfAbsent('id', () => doc.id);
            final post = CommunityPostModel.fromMap(data);
            if (post.isValid && !post.isDraft) {
              newPosts.add(post);
            }
          } catch (docErr, stackTrace) {
            ErrorHandler.log(
              docErr,
              stackTrace: stackTrace,
              tag: 'HomeFeedController._fetchMoreCommunityPostsTab.parsePost',
            );
          }
        }
        newPosts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        communityPosts.addAll(newPosts);
        homeFeedItems.assignAll(communityPosts);
        rxHasMore.value = docs.length >= HomeFeedControllerBase.pageSize;
      } else {
        rxHasMore.value = false;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController._fetchMoreCommunityPostsTab',
      );
      rxHasMore.value = false;
    }
  }

  @override
  Future<void> fetchCommunityPosts() async {
    try {
      var snapshot = await firestore
          .collection(FirestoreCollections.community)
          .limit(50)
          .get();
      if (snapshot.docs.isEmpty) {
        snapshot = await firestore.collection('community').limit(50).get();
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
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'HomeFeedController.fetchCommunityPosts.parsePost',
          );
        }
      }
      posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      communityPosts.assignAll(posts.take(10));
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'HomeFeedController.fetchCommunityPosts',
      );
    }
  }
}

