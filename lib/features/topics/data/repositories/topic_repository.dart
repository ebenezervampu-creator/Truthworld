import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Repository for Topic-related Firestore operations
///
/// Optimized for:
/// - Scalable querying with pagination
/// - Low Firestore read costs
/// - Denormalized data access
class TopicRepository {
  final FirebaseFirestore _firestore;

  TopicRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================================================
  // TOPIC QUERIES
  // ==========================================================================

  /// Get topic by slug or handle or document ID (for /topic/:slug or /T/:slug route)
  Future<Topic?> getTopicBySlug(String slug) async {
    try {
      // 1. Try slug first
      var query = await _firestore
          .collection('topics')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Topic.fromDocumentSnapshot(query.docs.first);
      }

      // 2. Try handleLowercase (e.g. t/slug)
      final handleToQuery = 't/${slug.toLowerCase()}';
      query = await _firestore
          .collection('topics')
          .where('handleLowercase', isEqualTo: handleToQuery)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Topic.fromDocumentSnapshot(query.docs.first);
      }

      // 3. Try Direct Document ID Lookup as fallback
      final doc = await _firestore.collection('topics').doc(slug).get();
      if (doc.exists) {
        return Topic.fromDocumentSnapshot(doc);
      }

      return null;
    } catch (e) {
      debugPrint('Error getTopicBySlug: $e');
      return null;
    }
  }

  /// Get topic by ID
  Future<Topic?> getTopicById(String topicId) async {
    try {
      final doc = await _firestore.collection('topics').doc(topicId).get();
      if (!doc.exists) return null;
      return Topic.fromDocumentSnapshot(doc);
    } catch (e) {
      debugPrint('Error fetching topic by ID: $e');
      return null;
    }
  }

  /// Stream topic by slug or handle or document ID (for real-time updates)
  Stream<Topic?> streamTopicBySlug(String slug) {
    return _firestore
        .collection('topics')
        .where('slug', isEqualTo: slug)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        return Topic.fromDocumentSnapshot(snapshot.docs.first);
      }
      final handleToQuery = 't/${slug.toLowerCase()}';
      final handleQuery = await _firestore
          .collection('topics')
          .where('handleLowercase', isEqualTo: handleToQuery)
          .limit(1)
          .get();
      if (handleQuery.docs.isNotEmpty) {
        return Topic.fromDocumentSnapshot(handleQuery.docs.first);
      }
      final doc = await _firestore.collection('topics').doc(slug).get();
      if (doc.exists) {
        return Topic.fromDocumentSnapshot(doc);
      }
      return null;
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
    try {
      Query query = _firestore
          .collection('videos')
          .where('topics', arrayContains: topicSlug)
          .where('visibility', isEqualTo: 'Public')
          .orderBy(orderBy, descending: descending)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Video.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching videos by topic: $e');
      return [];
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
        .collection('videos')
        .where('topics', arrayContains: topicSlug)
        .where('visibility', isEqualTo: 'Public')
        .orderBy(orderBy, descending: descending)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Video.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Get featured videos for a topic
  /// Uses pre-computed featuredVideoIds from topic document
  Future<List<Video>> getFeaturedVideos(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];

    try {
      // Firestore IN query limited to 10 items
      final batchSize = 10;
      List<Video> allVideos = [];

      for (var i = 0; i < videoIds.length; i += batchSize) {
        final batch = videoIds.skip(i).take(batchSize).toList();
        final query = await _firestore
            .collection('videos')
            .where(FieldPath.documentId, whereIn: batch)
            .where('visibility', isEqualTo: 'Public')
            .get();

        allVideos.addAll(
          query.docs.map((doc) => Video.fromDocumentSnapshot(doc)),
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
      descending: true,
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
      final batchSize = 10;
      List<Topic> allTopics = [];

      for (var i = 0; i < slugs.length; i += batchSize) {
        final batch = slugs.skip(i).take(batchSize).toList();
        final query = await _firestore
            .collection('topics')
            .where('slug', whereIn: batch)
            .get();

        allTopics.addAll(
          query.docs.map((doc) => Topic.fromDocumentSnapshot(doc)),
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
      Query query = _firestore
          .collection('topics')
          .where('category', isEqualTo: category)
          .orderBy('videoCount', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Topic.fromDocumentSnapshot(doc))
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
          .collection('topics')
          .orderBy('videoCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Topic.fromDocumentSnapshot(doc))
          .toList();
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
          .collection('topics')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: '${query}z')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Topic.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching topics: $e');
      return [];
    }
  }

  Future<List<Topic>> fetchFeaturedTopics({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('topics')
          .where('isFeatured', isEqualTo: true)
          .limit(limit)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => Topic.fromDocumentSnapshot(doc)).toList();
      }
      return getPopularTopics(limit: limit);
    } catch (e) {
      debugPrint('Error fetchFeaturedTopics: $e');
      return getPopularTopics(limit: limit);
    }
  }

  Future<List<Topic>> fetchTrendingTopics({
    int limit = 20,
    DocumentSnapshot? lastDoc,
    required String category,
  }) async {
    try {
      Query query = _firestore.collection('topics');
      if (category.toLowerCase() != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      query = query.orderBy('trendingScore', descending: true).limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Topic.fromDocumentSnapshot(doc)).toList();
    } catch (e) {
      debugPrint('Error fetchTrendingTopics: $e');
      return fetchTopics(limit: limit, lastDoc: lastDoc, category: category);
    }
  }

  Future<List<Topic>> fetchTopics({
    int limit = 20,
    DocumentSnapshot? lastDoc,
    required String category,
  }) async {
    try {
      Query query = _firestore.collection('topics');
      if (category.toLowerCase() != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      query = query.orderBy('videoCount', descending: true).limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Topic.fromDocumentSnapshot(doc)).toList();
    } catch (e) {
      debugPrint('Error fetchTopics: $e');
      return [];
    }
  }

  Future<List<Topic>> fetchFollowedTopics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
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
          .collection('users')
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
      final batchSize = 10;
      List<Topic> topics = [];
      for (var i = 0; i < ids.length; i += batchSize) {
        final batch = ids.skip(i).take(batchSize).toList();
        final query = await _firestore
            .collection('topics')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        topics.addAll(
          query.docs.map((doc) => Topic.fromDocumentSnapshot(doc)),
        );
      }
      return topics;
    } catch (e) {
      debugPrint('Error _fetchTopicsByIds: $e');
      return [];
    }
  }

  Future<bool> isTopicFollowed(String userId, String topicId) async {
    try {
      final doc = await _firestore
          .collection('users')
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
      final topicRef = _firestore.collection('topics').doc(topicId);
      final userSavedRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId);

      // YouTube-standard: user-centric subcollection + denormalized count only
      batch.set(userSavedRef, {
        'topicId': topicId,
        'savedAt': FieldValue.serverTimestamp(),
      });
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

  Future<bool> unfollowTopic(String userId, String topicId) async {
    try {
      final batch = _firestore.batch();
      final topicRef = _firestore.collection('topics').doc(topicId);
      final userSavedRef = _firestore
          .collection('users')
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





