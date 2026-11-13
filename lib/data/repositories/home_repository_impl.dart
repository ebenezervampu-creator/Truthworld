import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/domain/entities/topic_entity.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/features/home/data/datasources/edge_feed_remote_data_source.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Implementation of [HomeRepository] backed by Edge CDN with Cloud Firestore fallback.
class HomeRepositoryImpl extends BaseRepository implements HomeRepository {
  final FirebaseFirestore _firestore;
  final EdgeFeedRemoteDataSource _edgeFeedDataSource;

  HomeRepositoryImpl({
    FirebaseFirestore? firestore,
    EdgeFeedRemoteDataSource? edgeFeedDataSource,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _edgeFeedDataSource = edgeFeedDataSource ?? EdgeFeedRemoteDataSource();

  @override
  Future<Result<List<VideoEntity>>> getHomeFeed({
    int page = 1,
    int limit = 20,
    String? category,
    dynamic startAfter,
  }) async {
    // 1. Edge-First Delivery: For page 1 or string-based opaque cursor
    if (startAfter == null || startAfter is String) {
      try {
        final edgeRes = await _edgeFeedDataSource.fetchFeed(
          feedType: 'home',
          category: category,
          limit: limit,
          cursor: startAfter is String ? startAfter : null,
        );
        if (edgeRes.videos.isNotEmpty || edgeRes.isNotModified) {
          return Result.success(edgeRes.videos);
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeRepositoryImpl.getHomeFeed.edgeFallback',
        );
      }
    }

    // 2. Direct Firestore Fallback (offline, edge failure, or DocumentSnapshot cursor)
    return safeFetch(() async {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      if (startAfter is DocumentSnapshot) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .where(VideoVisibilityPolicy.isVisibleForFeed)
          .map((v) => v.toEntity())
          .toList();
    });
  }

  @override
  Future<Result<List<VideoEntity>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    // 1. Edge-First Delivery
    if (startAfter == null || startAfter is String) {
      try {
        final edgeRes = await _edgeFeedDataSource.fetchFeed(
          feedType: 'home',
          category: category,
          limit: limit,
          cursor: startAfter is String ? startAfter : null,
        );
        if (edgeRes.videos.isNotEmpty || edgeRes.isNotModified) {
          return Result.success(edgeRes.videos);
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'HomeRepositoryImpl.getVideosByCategory.edgeFallback',
        );
      }
    }

    // 2. Direct Firestore Fallback
    return safeFetch(() async {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('category', isEqualTo: category)
          .limit(limit);

      if (startAfter is DocumentSnapshot) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .where(VideoVisibilityPolicy.isVisibleForFeed)
          .map((v) => v.toEntity())
          .toList();
    });
  }

  @override
  Future<Result<List<TopicEntity>>> getFeaturedTopics({int limit = 10}) async {
    return safeFetch(() async {
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.topics)
            .where('status', isEqualTo: 'active')
            .where('isFeatured', isEqualTo: true)
            .limit(limit)
            .get();

        final topics = snapshot.docs
            .map(Topic.fromDocumentSnapshot)
            .where((t) => t.isValidTopic && t.videoCount > 0)
            .map((t) => t.toEntity())
            .toList();
        if (topics.isNotEmpty) return topics;
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'HomeRepositoryImpl.getFeaturedTopics',
        );
      }

      final fallbackSnapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .where('status', isEqualTo: 'active')
          .limit(limit)
          .get();

      return fallbackSnapshot.docs
          .map(Topic.fromDocumentSnapshot)
          .where((t) => t.isValidTopic && t.videoCount > 0)
          .map((t) => t.toEntity())
          .toList();
    });
  }

  @override
  Future<Result<List<VideoEntity>>> getVideosByTopic(
    String topicId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    return safeFetch(() async {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'public')
          .where('topics', arrayContains: topicId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter is DocumentSnapshot) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Video.fromDocumentSnapshot(doc).toEntity())
          .toList();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getCommunityPosts({
    int page = 1,
    int limit = 10,
    dynamic startAfter,
  }) async {
    return safeFetch(() async {
      var query = _firestore
          .collection(FirestoreCollections.community)
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter is DocumentSnapshot) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
  }
}
