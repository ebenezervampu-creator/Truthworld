import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/topic_entity.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Implementation of [HomeRepository] backed by Cloud Firestore.
class HomeRepositoryImpl extends BaseRepository implements HomeRepository {
  final FirebaseFirestore _firestore;

  HomeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<VideoEntity>>> getHomeFeed({
    int page = 1,
    int limit = 20,
    String? category,
    dynamic startAfter,
  }) async {
    return safeFetch(() async {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

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
  Future<Result<List<VideoEntity>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    return safeFetch(() async {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'public')
          .where('category', isEqualTo: category)
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
