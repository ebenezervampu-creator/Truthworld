import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
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
      final key = slug.toLowerCase().trim();
      final now = DateTime.now();
      if (_topicCache.containsKey(key) && _cacheTime.containsKey(key)) {
        if (now.difference(_cacheTime[key]!) < _cacheTtl) {
          return _topicCache[key];
        }
      }

      var cleanSlug = slug.trim();
      if (cleanSlug.toLowerCase().startsWith('t/')) {
        cleanSlug = cleanSlug.substring(2).trim();
      }
      final handleToQuery = 't/${cleanSlug.toLowerCase()}';
      final cleanKey = cleanSlug.toLowerCase();

      // Parallel execution of lookups to cut network roundtrip latency in 3x
      final results = await Future.wait([
        _firestore
            .collection(FirestoreCollections.topics)
            .where('slug', isEqualTo: slug)
            .limit(1)
            .get(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('slug', isEqualTo: cleanSlug)
            .limit(1)
            .get(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('handleLowercase', isEqualTo: handleToQuery)
            .limit(1)
            .get(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('handle', isEqualTo: 'T/$cleanSlug')
            .limit(1)
            .get(),
        _firestore.collection(FirestoreCollections.topics).doc(slug).get(),
        _firestore.collection(FirestoreCollections.topics).doc(cleanSlug).get(),
      ]);

      for (var i = 0; i < 4; i++) {
        final snap = results[i] as QuerySnapshot;
        if (snap.docs.isNotEmpty) {
          final topic = Topic.fromDocumentSnapshot(snap.docs.first);
          _cacheTopic(key, topic);
          _cacheTopic(cleanKey, topic);
          return topic;
        }
      }

      for (var i = 4; i < 6; i++) {
        final docSnap = results[i] as DocumentSnapshot;
        if (docSnap.exists) {
          final topic = Topic.fromDocumentSnapshot(docSnap);
          _cacheTopic(key, topic);
          _cacheTopic(cleanKey, topic);
          return topic;
        }
      }

      return null;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getTopicBySlug');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getTopicById');
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
          .where((video) => VideoVisibilityPolicy.isValidVideo(video) && video.visibility.toLowerCase() == 'public')
          .toList();
      if (videos.isNotEmpty) {
        final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        return TopicVideosPage(videos: videos, lastDoc: newLastDoc);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getVideosPageByTopic.primary');
    }

    // Fallback: Query without orderBy composite index requirement
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.videos)
          .where('topics', arrayContains: topicSlug)
          .limit(limit)
          .get();
      var videos = snap.docs
          .map(Video.fromDocumentSnapshot)
          .where((video) => VideoVisibilityPolicy.isValidVideo(video) && video.visibility.toLowerCase() == 'public')
          .toList();

      // If still empty, query by topicId directly
      if (videos.isEmpty) {
        final topicIdSnap = await _firestore
            .collection(FirestoreCollections.videos)
            .where('topicId', isEqualTo: topicSlug)
            .limit(limit)
            .get();
        videos = topicIdSnap.docs
            .map(Video.fromDocumentSnapshot)
            .where((video) => VideoVisibilityPolicy.isValidVideo(video) && video.visibility.toLowerCase() == 'public')
            .toList();
      }

      if (videos.isNotEmpty) {
        if (orderBy == 'views') {
          videos.sort((a, b) => descending ? b.views.compareTo(a.views) : a.views.compareTo(b.views));
        } else {
          videos.sort((a, b) => descending ? b.uploadedAt.compareTo(a.uploadedAt) : a.uploadedAt.compareTo(b.uploadedAt));
        }
        return TopicVideosPage(videos: videos, lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null);
      }
      return const TopicVideosPage(videos: [], lastDoc: null);
    } catch (fallbackErr, s) {
      ErrorHandler.log(fallbackErr, stackTrace: s, tag: 'TopicRepository.getVideosPageByTopic.fallback');
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
              .where((video) => VideoVisibilityPolicy.isValidVideo(video) && video.visibility.toLowerCase() == 'public')
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
              .where((video) => VideoVisibilityPolicy.isValidVideo(video) && video.visibility.toLowerCase() == 'public'),
        );
      }

      return allVideos;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getFeaturedVideos');
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
          query.docs
              .map(Topic.fromDocumentSnapshot)
              .where((t) => t.isValidTopic),
        );
      }

      return allTopics;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getRelatedTopics');
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
          .where((t) => t.isValidTopic && t.slug != excludeSlug)
          .toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getSimilarTopics');
      return [];
    }
  }

  // ==========================================================================
  // POPULAR TOPICS
  // ==========================================================================

  List<Topic> _deduplicateTopics(Iterable<Topic> raw) {
    final seen = <String>{};
    final result = <Topic>[];
    for (final t in raw) {
      if (t.isValidTopic && seen.add(t.canonicalKey)) {
        result.add(t);
      }
    }
    return result;
  }

  /// Get popular topics (for discovery)
  Future<List<Topic>> getPopularTopics({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .orderBy('videoCount', descending: true)
          .limit(limit)
          .get();

      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      if (list.isNotEmpty) return list;

      final fallbackSnap = await _firestore
          .collection(FirestoreCollections.topics)
          .limit(limit)
          .get();
      final fallbackList = _deduplicateTopics(fallbackSnap.docs.map(Topic.fromDocumentSnapshot));
      fallbackList.sort((a, b) => b.effectiveVideoCount.compareTo(a.effectiveVideoCount));
      return fallbackList;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getPopularTopics');
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

      return _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.searchTopics');
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
        final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
        if (list.isNotEmpty) return list;
      }
      return getPopularTopics(limit: limit);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchFeaturedTopics');
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
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      if (list.isNotEmpty) return list;
      return fetchTopics(limit: limit, lastDoc: lastDoc, category: category);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchTrendingTopics');
      try {
        Query fallback = _firestore.collection(FirestoreCollections.topics);
        if (category.toLowerCase() != 'all') {
          fallback = fallback.where('category', isEqualTo: category);
        }
        fallback = fallback.limit(limit);
        final snap = await fallback.get();
        final list = _deduplicateTopics(snap.docs.map(Topic.fromDocumentSnapshot));
        list.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
        if (list.isNotEmpty) return list;
      } catch (fallbackErr, fallbackStack) {
        ErrorHandler.log(fallbackErr, stackTrace: fallbackStack, tag: 'TopicRepository.fetchTrendingTopics.fallback');
      }
      return fetchTopics(limit: limit, lastDoc: lastDoc, category: category);
    }
  }

  Future<List<Topic>> fetchNewestTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _firestore.collection(FirestoreCollections.topics);
      if (category.toLowerCase() != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      query = query.orderBy('createdAt', descending: true).limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      if (list.isNotEmpty) return list;
      return fetchTopics(limit: limit, lastDoc: lastDoc, category: category);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchNewestTopics');
      try {
        Query fallback = _firestore.collection(FirestoreCollections.topics);
        if (category.toLowerCase() != 'all') {
          fallback = fallback.where('category', isEqualTo: category);
        }
        fallback = fallback.limit(limit);
        final snap = await fallback.get();
        final list = _deduplicateTopics(snap.docs.map(Topic.fromDocumentSnapshot));
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (list.isNotEmpty) return list;
      } catch (fallbackErr, fallbackStack) {
        ErrorHandler.log(fallbackErr, stackTrace: fallbackStack, tag: 'TopicRepository.fetchNewestTopics.fallback');
      }
      return fetchTopics(limit: limit, lastDoc: lastDoc, category: category);
    }
  }

  Future<List<Topic>> fetchPopularTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _firestore.collection(FirestoreCollections.topics);
      if (category.toLowerCase() != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      query = query.orderBy('followerCount', descending: true).limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      if (list.isNotEmpty) return list;
      return fetchTopics(limit: limit, lastDoc: lastDoc, category: category);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchPopularTopics');
      try {
        Query fallback = _firestore.collection(FirestoreCollections.topics);
        if (category.toLowerCase() != 'all') {
          fallback = fallback.where('category', isEqualTo: category);
        }
        fallback = fallback.limit(limit);
        final snap = await fallback.get();
        final list = _deduplicateTopics(snap.docs.map(Topic.fromDocumentSnapshot));
        list.sort((a, b) => b.followerCount.compareTo(a.followerCount));
        if (list.isNotEmpty) return list;
      } catch (fallbackErr, fallbackStack) {
        ErrorHandler.log(fallbackErr, stackTrace: fallbackStack, tag: 'TopicRepository.fetchPopularTopics.fallback');
      }
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
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      if (list.isNotEmpty) return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchTopics');
    }

    try {
      Query fallbackQuery = _firestore.collection(FirestoreCollections.topics);
      if (category.toLowerCase() != 'all') {
        fallbackQuery = fallbackQuery.where('category', isEqualTo: category);
      }
      fallbackQuery = fallbackQuery.limit(limit);
      final snapshot = await fallbackQuery.get();
      final fallbackList = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      fallbackList.sort((a, b) => b.effectiveVideoCount.compareTo(a.effectiveVideoCount));
      return fallbackList;
    } catch (err, errStack) {
      ErrorHandler.log(err, stackTrace: errStack, tag: 'TopicRepository.fetchTopics.fallback');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchFollowedTopics');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchFavoriteTopics');
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
            return query.docs
                .map(Topic.fromDocumentSnapshot)
                .where((t) => t.isValidTopic && t.videoCount > 0)
                .toList();
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchTopicsByIds.batch');
            return <Topic>[];
          }
        }());
      }
      final results = await Future.wait(futures);
      return results.expand((t) => t).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchTopicsByIds');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.isTopicFollowed');
      return false;
    }
  }

  Future<bool> followTopic(String userId, String topicId) async {
    try {
      final topicRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId);
      final userSavedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId);

      return await _firestore.runTransaction<bool>((tx) async {
        final topicSnap = await tx.get(topicRef);
        if (!topicSnap.exists) return false;
        final topic = Topic.fromDocumentSnapshot(topicSnap);
        if (!topic.isValidTopic || topic.videoCount <= 0) return false;

        final savedSnap = await tx.get(userSavedRef);
        // Idempotent guard: already following — do nothing, no duplicate count
        if (savedSnap.exists) return true;

        tx.set(userSavedRef, {
          'topicId': topicId,
          'savedAt': FieldValue.serverTimestamp(),
          'notificationSetting': 'personalized',
        });
        tx.update(topicRef, {
          'followerCount': FieldValue.increment(1),
        });
        return true;
      });
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.followTopic');
      return false;
    } finally {
      _topicCache.clear();
    }
  }

  Future<Map<String, String>> fetchTopicNotificationSettings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .get();

      final settings = <String, String>{};
      for (final doc in snapshot.docs) {
        settings[doc.id] =
            (doc.data()['notificationSetting'] as String?) ?? 'personalized';
      }
      return settings;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicRepository.fetchTopicNotificationSettings',
      );
      return {};
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
        return doc.data()?['notificationSetting'] as String? ?? 'personalized';
      }
      return 'personalized';
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getTopicNotificationSetting');
      return 'personalized';
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.updateTopicNotificationSetting');
      return false;
    }
  }

  Future<bool> unfollowTopic(String userId, String topicId) async {
    try {
      final topicRef = _firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId);
      final userSavedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .doc(topicId);

      return await _firestore.runTransaction<bool>((tx) async {
        final savedSnap = await tx.get(userSavedRef);
        // Idempotent guard: not following — do nothing, no negative drift
        if (!savedSnap.exists) return true;

        tx.delete(userSavedRef);
        tx.update(topicRef, {
          'followerCount': FieldValue.increment(-1),
        });
        return true;
      });
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.unfollowTopic');
      return false;
    } finally {
      _topicCache.clear();
    }
  }

  /// Get channels related to topic tag/slug
  Future<List<Channel>> getChannelsByTopic(String tag, {int limit = 15}) async {
    try {
      final tagLower = tag.toLowerCase().replaceAll('#', '').trim();
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .limit(40)
          .get();

      final list = snapshot.docs.map(Channel.fromDocumentSnapshot).where((c) {
        final catMatch = c.category.toLowerCase().contains(tagLower) ||
            c.categories.any((cat) => cat.toLowerCase().contains(tagLower));
        final nameMatch = c.name.toLowerCase().contains(tagLower);
        final descMatch = c.description.toLowerCase().contains(tagLower);
        return catMatch || nameMatch || descMatch;
      }).toList();

      if (list.isEmpty && snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map(Channel.fromDocumentSnapshot)
            .take(limit)
            .toList();
      }
      return list.take(limit).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getChannelsByTopic');
      return [];
    }
  }

  /// Get playlists related to topic tag/slug
  Future<List<PlaylistModel>> getPlaylistsByTopic(String tag, {int limit = 15}) async {
    try {
      final tagLower = tag.toLowerCase().replaceAll('#', '').trim();
      final snapshot = await _firestore
          .collection(FirestoreCollections.playlists)
          .limit(40)
          .get();

      final list = snapshot.docs
          .map(PlaylistModel.fromDocumentSnapshot)
          .where((p) {
        final nameMatch = p.name.toLowerCase().contains(tagLower);
        final descMatch = p.description.toLowerCase().contains(tagLower);
        return nameMatch || descMatch;
      }).toList();

      if (list.isEmpty && snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map(PlaylistModel.fromDocumentSnapshot)
            .take(limit)
            .toList();
      }
      return list.take(limit).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getPlaylistsByTopic');
      return [];
    }
  }

  /// Get community posts related to topic tag/slug
  Future<List<CommunityPostModel>> getCommunityPostsByTopic(String tag, {int limit = 15}) async {
    try {
      final tagLower = tag.toLowerCase().replaceAll('#', '').trim();

      // 1. Direct query by topics arrayContains or topicId
      final topicSnap = await _firestore
          .collection(FirestoreCollections.community)
          .where('topics', arrayContains: tagLower)
          .limit(limit)
          .get();

      final posts = topicSnap.docs
          .map((doc) => CommunityPostModel.fromMap(doc.data()..['id'] = doc.id))
          .toList();

      if (posts.isNotEmpty) {
        return posts;
      }

      final topicIdSnap = await _firestore
          .collection(FirestoreCollections.community)
          .where('topicId', isEqualTo: tagLower)
          .limit(limit)
          .get();

      final postsId = topicIdSnap.docs
          .map((doc) => CommunityPostModel.fromMap(doc.data()..['id'] = doc.id))
          .toList();

      if (postsId.isNotEmpty) {
        return postsId;
      }

      // 2. Fallback text search across recent community posts
      final snapshot = await _firestore
          .collection(FirestoreCollections.community)
          .limit(40)
          .get();

      final list = snapshot.docs
          .map((doc) => CommunityPostModel.fromMap(doc.data()..['id'] = doc.id))
          .where((post) {
        final titleMatch = post.title.toLowerCase().contains(tagLower);
        final descMatch = post.description.toLowerCase().contains(tagLower);
        final tagMatch = post.tags.any((t) => t.toLowerCase().contains(tagLower));
        final catMatch = post.selectedCategory.toLowerCase().contains(tagLower);
        return titleMatch || descMatch || tagMatch || catMatch;
      }).toList();

      if (list.isEmpty && snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => CommunityPostModel.fromMap(doc.data()..['id'] = doc.id))
            .take(limit)
            .toList();
      }
      return list.take(limit).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getCommunityPostsByTopic');
      return [];
    }
  }
}

