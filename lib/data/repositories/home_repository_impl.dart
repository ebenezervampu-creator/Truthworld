import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Implementation of [HomeRepository] backed by Cloud Firestore.
class HomeRepositoryImpl extends BaseRepository implements HomeRepository {
  final FirebaseFirestore _firestore;

  DocumentSnapshot? _lastFeedDoc;
  DocumentSnapshot? _lastCategoryDoc;
  DocumentSnapshot? _lastTopicDoc;
  DocumentSnapshot? _lastCommunityDoc;

  HomeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Video>>> getHomeFeed({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastFeedDoc = null;

      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      if (_lastFeedDoc != null) {
        query = query.startAfterDocument(_lastFeedDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastFeedDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .toList();
    });
  }

  @override
  Future<Result<List<Video>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastCategoryDoc = null;

      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'public')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (_lastCategoryDoc != null) {
        query = query.startAfterDocument(_lastCategoryDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastCategoryDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .toList();
    });
  }

  @override
  Future<Result<List<Topic>>> getFeaturedTopics({int limit = 10}) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .where('isFeatured', isEqualTo: true)
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(Topic.fromDocumentSnapshot)
          .toList();
    });
  }

  @override
  Future<Result<List<Video>>> getVideosByTopic(
    String topicId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastTopicDoc = null;

      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('status', isEqualTo: 'published')
          .where('visibility', isEqualTo: 'public')
          .where('topics', arrayContains: topicId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (_lastTopicDoc != null) {
        query = query.startAfterDocument(_lastTopicDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastTopicDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .toList();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getCommunityPosts({
    int page = 1,
    int limit = 10,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastCommunityDoc = null;

      var query = _firestore
          .collection(FirestoreCollections.community)
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (_lastCommunityDoc != null) {
        query = query.startAfterDocument(_lastCommunityDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastCommunityDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
  }
}
