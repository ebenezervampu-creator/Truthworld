import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class TopicVideosPage {
  final List<Video> videos;
  final DocumentSnapshot? lastDoc;
  const TopicVideosPage({required this.videos, required this.lastDoc});
}

/// Repository for Topic-related Firestore operations
///
/// Optimized for:
/// - Scalable querying with pagination
/// - Low Firestore read costs
/// - Denormalized data access
class TopicRepository {
  static final Map<String, Topic> _topicCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  TopicRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  // ==========================================================================
  // TOPIC QUERIES
  // ==========================================================================

  /// Get topic by slug or handle or document ID (for /topic/:slug or /T/:slug route)
  /// Uses in-memory caching and parallel query execution for low latency
  Future<Topic?> getTopicBySlug(String slug) async {
    try {
      final key = slug.toLowerCase();
      final now = DateTime.now();
      if (_topicCache.containsKey(key) && _cacheTime.containsKey(key)) {
        if (now.difference(_cacheTime[key]!) < _cacheTtl) {
          return _topicCache[key];
        }
      }

      // Parallel execution of lookups to cut network roundtrip latency in 3x
      final handleToQuery = 't/${slug.toLowerCase()}';
      final results = await Future.wait([
        _firestore
            .collection(FirestoreCollections.topics)
            .where('slug', isEqualTo: slug)
            .limit(1)
            .get(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('handleLowercase', isEqualTo: handleToQuery)
            .limit(1)
            .get(),
        _firestore.collection(FirestoreCollections.topics).doc(slug).get(),
      ]);

      final slugSnap = results[0] as QuerySnapshot;
      if (slugSnap.docs.isNotEmpty) {
        final topic = Topic.fromDocumentSnapshot(slugSnap.docs.first);
        _cacheTopic(key, topic);
        return topic;
      }

      final handleSnap = results[1] as QuerySnapshot;
      if (handleSnap.docs.isNotEmpty) {
        final topic = Topic.fromDocumentSnapshot(handleSnap.docs.first);
        _cacheTopic(key, topic);
        return topic;
      }

      final docSnap = results[2] as DocumentSnapshot;
      if (docSnap.exists) {
        final topic = Topic.fromDocumentSnapshot(docSnap);
        _cacheTopic(key, topic);
        return topic;
      }

      return null;
    } catch (e) {
      debugPrint('Error getTopicBySlug: $e');
      return null;
    }
  }

  void _cacheTopic(String key, Topic topic) {
    _topicCache[key] = topic;
    _cacheTime[key] = DateTime.now();
  }

  /// Get topic by ID
  Future<Topic?> getTopicById(String topicId) async {
    try {
      final key = topicId.toLowerCase();
      final now = DateTime.now();
      if (_topicCache.containsKey(key) && _cacheTime.containsKey(key)) {
        if (now.difference(_cacheTime[key]!) < _cacheTtl) {
          return _topicCache[key];
        }
      }

      final doc = await _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .get();
      if (!doc.exists) return null;
      final topic = Topic.fromDocumentSnapshot(doc);
      _cacheTopic(key, topic);
      return topic;
    } catch (e) {
      debugPrint('Error fetching topic by ID: $e');
      return null;
    }
  }

  /// Stream topic by slug or handle or document ID (for real-time updates)
  Stream<Topic?> streamTopicBySlug(String slug) {
    return _firestore
        .collection(FirestoreCollections.topics)
        .where('slug', isEqualTo: slug)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final topic = Topic.fromDocumentSnapshot(snapshot.docs.first);
            _cacheTopic(slug.toLowerCase(), topic);
            return topic;
          }
          return _topicCache[slug.toLowerCase()];
        });
  }

  // ==========================================================================
  // VIDEO QUERIES (DENORMALIZED)
  // ==========================================================================

  /// Get videos by topic slug with pagination
  /// Uses denormalized topics array for O(1) query performance
  Future<List<Video>> getVideosByTopic(
    String topicSlug, {
    int limit = 12,
    DocumentSnapshot? lastDoc,
    String orderBy = 'uploadedAt',
    bool descending = true,
  }) async {
    final page = await getVideosPageByTopic(
      topicSlug,
      limit: limit,
      lastDoc: lastDoc,
      orderBy: orderBy,
      descending: descending,
    );
    return page.videos;
  }

  /// Get videos page with DocumentSnapshot cursor for pagination
  Future<TopicVideosPage> getVideosPageByTopic(
    String topicSlug, {
    int limit = 12,
    DocumentSnapshot? lastDoc,
    String orderBy = 'uploadedAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection(FirestoreCollections.videos)
          .where('topics', arrayContains: topicSlug)
          .orderBy(orderBy, descending: descending)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      final videos = snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .where((video) => video.visibility.toLowerCase() == 'public')
          .toList();
      final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return TopicVideosPage(videos: videos, lastDoc: newLastDoc);
    } catch (e) {
      debugPrint('Error fetching videos page by topic: $e');
      return const TopicVideosPage(videos: [], lastDoc: null);
    }
  }

  /// Stream videos by topic (for real-time updates)
  Stream<List<Video>> streamVideosByTopic(
    String topicSlug, {
    int limit = 12,
    String orderBy = 'uploadedAt',
    bool descending = true,
  }) {
    return _firestore
        .collection(FirestoreCollections.videos)
        .where('topics', arrayContains: topicSlug)
        .orderBy(orderBy, descending: descending)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where((video) => video.visibility.toLowerCase() == 'public')
              .toList(),
        );
  }

  /// Get featured videos for a topic
  /// Uses pre-computed featuredVideoIds from topic document
  Future<List<Video>> getFeaturedVideos(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];

    try {
      // Firestore IN query limited to 10 items
      const batchSize = 10;
      final allVideos = <Video>[];

      for (var i = 0; i < videoIds.length; i += batchSize) {
        final batch = videoIds.skip(i).take(batchSize).toList();
        final query = await _firestore
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        allVideos.addAll(
          query.docs
              .map(Video.fromDocumentSnapshot)
              .where((video) => video.visibility.toLowerCase() == 'public'),
        );
      }

      return allVideos;
    } catch (e) {
      debugPrint('Error fetching featured videos: $e');
      return [];
    }
  }

  /// Get trending videos for topic (by views)
  Future<List<Video>> getTrendingVideos(
    String topicSlug, {
    int limit = 6,
  }) async {
    return getVideosByTopic(
      topicSlug,
      limit: limit,
      orderBy: 'views',
    );
  }

  // ==========================================================================
  // RELATED TOPICS
  // ==========================================================================

  /// Get related topics by slug list
  Future<List<Topic>> getRelatedTopics(List<String> slugs) async {
    if (slugs.isEmpty) return [];

    try {
      // Firestore IN query limited to 10 items
      const batchSize = 10;
      final allTopics = <Topic>[];

      for (var i = 0; i < slugs.length; i += batchSize) {
        final batch = slugs.skip(i).take(batchSize).toList();
        final query = await _firestore
            .collection(FirestoreCollections.topics)
            .where('slug', whereIn: batch)
            .get();

        allTopics.addAll(
          query.docs.map(Topic.fromDocumentSnapshot),
        );
      }

      return allTopics;
    } catch (e) {
      debugPrint('Error: $e');
      return [];
    }
  }

  /// Get similar topics by category
  Future<List<Topic>> getSimilarTopics(
    String category, {
    String? excludeSlug,
    int limit = 8,
  }) async {
    try {
      final Query query = _firestore
          .collection(FirestoreCollections.topics)
          .where('category', isEqualTo: category)
          .orderBy('videoCount', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map(Topic.fromDocumentSnapshot)
          .where((t) => t.slug != excludeSlug)
          .toList();
    } catch (e) {
      debugPrint('Error fetching similar topics: $e');
      return [];
    }
  }

  // ==========================================================================
  // POPULAR TOPICS
  // ==========================================================================

  /// Get popular topics (for discovery)
  Future<List<Topic>> getPopularTopics({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .orderBy('videoCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map(Topic.fromDocumentSnapshot).toList();
    } catch (e) {
      debugPrint('Error fetching popular topics: $e');
      return [];
    }
  }

  /// Search topics by title prefix
  Future<List<Topic>> searchTopics(String query, {int limit = 10}) async {
    if (query.isEmpty) return [];

    try {
      // Case-insensitive search using range queries
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: '${query}z')
          .limit(limit)
          .get();

      return snapshot.docs.map(Topic.fromDocumentSnapshot).toList();
    } catch (e) {
      debugPrint('Error searching topics: $e');
      return [];
    }
  }

  Future<List<Topic>> fetchFeaturedTopics({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .where('isFeatured', isEqualTo: true)
          .limit(limit)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map(Topic.fromDocumentSnapshot).toList();
      }
      return getPopularTopics(limit: limit);
    } catch (e) {
      debugPrint('Error fetchFeaturedTopics: $e');
      return getPopularTopics(limit: limit);
    }
  }

  Future<List<Topic>> fetchTrendingTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _firestore.collection(FirestoreCollections.topics);
      if (category.toLowerCase() != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      query = query.orderBy('trendingScore', descending: true).limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      return snapshot.docs.map(Topic.fromDocumentSnapshot).toList();
    } catch (e) {
      debugPrint('Error fetchTrendingTopics: $e');
      return fetchTopics(limit: limit, lastDoc: lastDoc, category: category);
    }
  }

  Future<List<Topic>> fetchTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _firestore.collection(FirestoreCollections.topics);
      if (category.toLowerCase() != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      query = query.orderBy('videoCount', descending: true).limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      return snapshot.docs.map(Topic.fromDocumentSnapshot).toList();
    } catch (e) {
      debugPrint('Error fetchTopics: $e');
      return [];
    }
  }

  Future<List<Topic>> fetchFollowedTopics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .get();

      if (snapshot.docs.isEmpty) return [];

      final topicIds = snapshot.docs.map((doc) => doc.id).toList();
      return _fetchTopicsByIds(topicIds);
    } catch (e) {
      debugPrint('Error fetchFollowedTopics: $e');
      return [];
    }
  }

  Future<List<Topic>> fetchFavoriteTopics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('likedTopics')
          .get();

      if (snapshot.docs.isEmpty) return [];

      final topicIds = snapshot.docs.map((doc) => doc.id).toList();
      return _fetchTopicsByIds(topicIds);
    } catch (e) {
      debugPrint('Error fetchFavoriteTopics: $e');
      return [];
    }
  }

  Future<List<Topic>> _fetchTopicsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      const batchSize = 10;
      final futures = <Future<List<Topic>>>[];
      for (var i = 0; i < ids.length; i += batchSize) {
        final batch = ids.skip(i).take(batchSize).toList();
        futures.add(() async {
          try {
            final query = await _firestore
                .collection(FirestoreCollections.topics)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            return query.docs.map(Topic.fromDocumentSnapshot).toList();
          } catch (e) {
            debugPrint('Error batch fetching topics by IDs: $e');
            return <Topic>[];
          }
        }());
      }
      final results = await Future.wait(futures);
      return results.expand((t) => t).toList();
    } catch (e) {
      debugPrint('Error _fetchTopicsByIds: $e');
      return [];
    }
  }

  Future<bool> isTopicFollowed(String userId, String topicId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error isTopicFollowed: $e');
      return false;
    }
  }

  Future<bool> followTopic(String userId, String topicId) async {
    try {
      final batch = _firestore.batch();
      final topicRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId);
      final userSavedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId);

      // YouTube-standard: user-centric subcollection + denormalized count only
      batch.set(userSavedRef, {
        'topicId': topicId,
        'savedAt': FieldValue.serverTimestamp(),
        'notificationSetting': 'all',
      }, SetOptions(merge: true));
      batch.update(topicRef, {
        'followerCount': FieldValue.increment(1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error followTopic: $e');
      return false;
    }
  }

  Future<String> getTopicNotificationSetting(
    String userId,
    String topicId,
  ) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId)
          .get();
      if (doc.exists) {
        return doc.data()?['notificationSetting'] as String? ?? 'all';
      }
      return 'all';
    } catch (e) {
      debugPrint('Error getTopicNotificationSetting: $e');
      return 'all';
    }
  }

  Future<bool> updateTopicNotificationSetting(
    String userId,
    String topicId,
    String setting,
  ) async {
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId)
          .set({
            'topicId': topicId,
            'notificationSetting': setting,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error updateTopicNotificationSetting: $e');
      return false;
    }
  }

  Future<bool> unfollowTopic(String userId, String topicId) async {
    try {
      final batch = _firestore.batch();
      final topicRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId);
      final userSavedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId);

      // YouTube-standard: only delete user-centric doc + decrement count
      batch.delete(userSavedRef);
      batch.update(topicRef, {
        'followerCount': FieldValue.increment(-1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error unfollowTopic: $e');
      return false;
    }
  }
}
