import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/search/data/services/engine/typesense_search_engine.dart';
import 'package:truthworld/features/home/data/datasources/edge_feed_remote_data_source.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class TopicVideosPage {
  final List<Video> videos;
  final DocumentSnapshot? lastDoc;
  const TopicVideosPage({required this.videos, required this.lastDoc});
}

class TopicPageResult {
  final List<Topic> topics;
  final DocumentSnapshot? lastDoc;
  const TopicPageResult({required this.topics, required this.lastDoc});
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

  TopicRepository({FirebaseFirestore? firestore, EdgeFeedRemoteDataSource? edgeDataSource})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _edgeDataSource = edgeDataSource ?? EdgeFeedRemoteDataSource();
  final FirebaseFirestore _firestore;
  final EdgeFeedRemoteDataSource? _edgeDataSource;

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
            .getCacheFirst(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('slug', isEqualTo: cleanSlug)
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('handleLowercase', isEqualTo: handleToQuery)
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('handle', isEqualTo: 'T/$cleanSlug')
            .limit(1)
            .getCacheFirst(),
        _firestore.collection(FirestoreCollections.topics).doc(slug).getCacheFirst(),
        _firestore.collection(FirestoreCollections.topics).doc(cleanSlug).getCacheFirst(),
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
          .getCacheFirst();
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

  /// Validates whether a video can be displayed on a topic page.
  /// Unlisted, private, deleted, or rejected videos are never displayed on public topic pages.
  bool _isTopicVideoVisible(Video video) {
    if (VideoVisibilityPolicy.isPrivate(video) ||
        VideoVisibilityPolicy.isUnlisted(video)) {
      return false;
    }

    if (VideoVisibilityPolicy.isOwner(video)) {
      if (video.status == VideoStatus.deleted || video.status == VideoStatus.rejected) {
        return false;
      }
      return VideoVisibilityPolicy.hasPlayableMedia(video) || video.thumbnailUrl.isNotEmpty;
    }

    if (video.status == VideoStatus.deleted || video.status == VideoStatus.rejected) {
      return false;
    }
    final statusName = video.status.name.toLowerCase();
    if (statusName == 'deleted' || statusName == 'deletion_pending' || statusName == 'rejected') {
      return false;
    }

    final hasPlayable = VideoVisibilityPolicy.hasPlayableMedia(video);
    if (!hasPlayable && !VideoVisibilityPolicy.hasValidThumbnail(video)) {
      return false;
    }

    return VideoVisibilityPolicy.canViewVideo(video) || hasPlayable;
  }

  /// Get videos page with DocumentSnapshot cursor for pagination
  Future<TopicVideosPage> getVideosPageByTopic(
    String topicSlug, {
    int limit = 12,
    DocumentSnapshot? lastDoc,
    String orderBy = 'uploadedAt',
    bool descending = true,
  }) async {
    // Step 0: Edge-first delivery for initial topic video requests
    if (lastDoc == null && (orderBy == 'uploadedAt' || orderBy == 'createdAt') && descending && _edgeDataSource != null) {
      try {
        final edgeResponse = await _edgeDataSource!.fetchTopicFeed(topicSlug, limit: limit);
        if (edgeResponse.videos.isNotEmpty) {
          final mappedVideos = edgeResponse.videos.map(Video.fromEntity).where(_isTopicVideoVisible).toList();
          if (mappedVideos.isNotEmpty) {
            return TopicVideosPage(videos: mappedVideos, lastDoc: null);
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getVideosPageByTopic.edge');
      }
    }

    try {
      Query query = _firestore
          .collection(FirestoreCollections.videos)
          .where('topics', arrayContains: topicSlug)
          .orderBy(orderBy, descending: descending)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.getCacheFirst();
      final videos = snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .where(_isTopicVideoVisible)
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
          .getCacheFirst();
      var videos = snap.docs
          .map(Video.fromDocumentSnapshot)
          .where(_isTopicVideoVisible)
          .toList();

      // If still empty, query by topicId directly
      if (videos.isEmpty) {
        final topicIdSnap = await _firestore
            .collection(FirestoreCollections.videos)
            .where('topicId', isEqualTo: topicSlug)
            .limit(limit)
            .getCacheFirst();
        videos = topicIdSnap.docs
            .map(Video.fromDocumentSnapshot)
            .where(_isTopicVideoVisible)
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
              .where(_isTopicVideoVisible)
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

      final batches = <List<String>>[];
      for (var i = 0; i < videoIds.length; i += batchSize) {
        batches.add(videoIds.skip(i).take(batchSize).toList());
      }

      final results = await Future.wait(
        batches.map(
          (batch) => _firestore
              .collection(FirestoreCollections.videos)
              .where(FieldPath.documentId, whereIn: batch)
              .getCacheFirst(),
        ),
      );

      for (final query in results) {
        allVideos.addAll(
          query.docs
              .map(Video.fromDocumentSnapshot)
              .where(_isTopicVideoVisible),
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

      final batches = <List<String>>[];
      for (var i = 0; i < slugs.length; i += batchSize) {
        batches.add(slugs.skip(i).take(batchSize).toList());
      }

      final results = await Future.wait(
        batches.map(
          (batch) => _firestore
              .collection(FirestoreCollections.topics)
              .where('slug', whereIn: batch)
              .getCacheFirst(),
        ),
      );

      for (final query in results) {
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

      final snapshot = await query.getCacheFirst();

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
          .getCacheFirst();

      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      if (list.isNotEmpty) return list;

      final fallbackSnap = await _firestore
          .collection(FirestoreCollections.topics)
          .limit(limit)
          .getCacheFirst();
      final fallbackList = _deduplicateTopics(fallbackSnap.docs.map(Topic.fromDocumentSnapshot));
      fallbackList.sort((a, b) => b.effectiveVideoCount.compareTo(a.effectiveVideoCount));
      return fallbackList;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getPopularTopics');
      return [];
    }
  }

  /// Search topics by prefix across slug, handleLowercase, and name
  Future<List<Topic>> searchTopics(String query, {int limit = 10}) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    try {
      // Step 0: Typesense instant search (<20ms with typo tolerance)
      final tsEngine = TypesenseSearchEngine();
      if (tsEngine.isEnabled) {
        final tsResults = await tsEngine.searchTopics(clean, limit: limit);
        if (tsResults.isNotEmpty) {
          final matchedTopics = <Topic>[];
          final missingIds = <String>[];

          for (final item in tsResults) {
            final cached = _topicCache[item.id.toLowerCase()] ??
                _topicCache[item.title.toLowerCase()];
            if (cached != null) {
              matchedTopics.add(cached);
            } else {
              missingIds.add(item.id);
            }
          }

          if (missingIds.isNotEmpty) {
            for (var i = 0; i < missingIds.length; i += 10) {
              final chunk = missingIds.skip(i).take(10).toList();
              final snap = await _firestore
                  .collection(FirestoreCollections.topics)
                  .where(FieldPath.documentId, whereIn: chunk)
                  .getCacheFirst();
              final fetched = snap.docs.map(Topic.fromDocumentSnapshot).toList();
              matchedTopics.addAll(fetched);
              for (final t in fetched) {
                _topicCache[t.id.toLowerCase()] = t;
                _topicCache[t.slug.toLowerCase()] = t;
                _cacheTime[t.id.toLowerCase()] = DateTime.now();
              }
            }
          }

          if (matchedTopics.isNotEmpty) {
            return _deduplicateTopics(matchedTopics).take(limit).toList();
          }
        }
      }

      // Fallback: 3 parallel Firestore prefix queries
      final highSurrogate = '$clean\uf8ff';
      final titleCase = clean[0].toUpperCase() + (clean.length > 1 ? clean.substring(1) : '');
      final titleHighSurrogate = '$titleCase\uf8ff';

      final queries = await Future.wait([
        _firestore
            .collection(FirestoreCollections.topics)
            .where('slug', isGreaterThanOrEqualTo: clean)
            .where('slug', isLessThan: highSurrogate)
            .limit(limit)
            .getCacheFirst(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('handleLowercase', isGreaterThanOrEqualTo: 't/$clean')
            .where('handleLowercase', isLessThan: 't/$highSurrogate')
            .limit(limit)
            .getCacheFirst(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('name', isGreaterThanOrEqualTo: titleCase)
            .where('name', isLessThan: titleHighSurrogate)
            .limit(limit)
            .getCacheFirst(),
      ]);

      final allDocs = <DocumentSnapshot>[];
      for (final q in queries) {
        allDocs.addAll(q.docs);
      }

      return _deduplicateTopics(allDocs.map(Topic.fromDocumentSnapshot)).take(limit).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.searchTopics');
      return [];
    }
  }

  Future<List<Topic>> fetchFeaturedTopics({int limit = 5}) async {
    // Step 0: Edge-first delivery for featured/trending topics
    if (_edgeDataSource != null) {
      try {
        final edgeTopics = await _edgeDataSource!.fetchDiscoveryTopics(category: 'all', limit: limit);
        if (edgeTopics.isNotEmpty) {
          final list = _deduplicateTopics(edgeTopics);
          if (list.isNotEmpty) return list;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchFeaturedTopics.edge');
      }
    }

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .where('isFeatured', isEqualTo: true)
          .limit(limit)
          .getCacheFirst();
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

  Future<TopicPageResult> fetchTrendingTopicsPage({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    // Step 0: Edge-first delivery for trending topics
    if (lastDoc == null && _edgeDataSource != null) {
      try {
        final edgeTopics = await _edgeDataSource!.fetchDiscoveryTopics(category: category, limit: limit);
        if (edgeTopics.isNotEmpty) {
          final list = _deduplicateTopics(edgeTopics);
          if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: null);
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchTrendingTopicsPage.edge');
      }
    }

    try {
      Query query = _firestore.collection(FirestoreCollections.topics);
      if (category.toLowerCase() != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      query = query.orderBy('trendingScore', descending: true).limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.getCacheFirst();
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      final nextDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: nextDoc);
      return fetchTopicsPage(limit: limit, lastDoc: lastDoc, category: category);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchTrendingTopics');
      try {
        Query fallback = _firestore.collection(FirestoreCollections.topics);
        if (category.toLowerCase() != 'all') {
          fallback = fallback.where('category', isEqualTo: category);
        }
        fallback = fallback.limit(limit);
        final snap = await fallback.getCacheFirst();
        final list = _deduplicateTopics(snap.docs.map(Topic.fromDocumentSnapshot));
        list.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
        final nextDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: nextDoc);
      } catch (fallbackErr, fallbackStack) {
        ErrorHandler.log(fallbackErr, stackTrace: fallbackStack, tag: 'TopicRepository.fetchTrendingTopics.fallback');
      }
      return fetchTopicsPage(limit: limit, lastDoc: lastDoc, category: category);
    }
  }

  Future<List<Topic>> fetchTrendingTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    final page = await fetchTrendingTopicsPage(
      category: category,
      limit: limit,
      lastDoc: lastDoc,
    );
    return page.topics;
  }

  Future<TopicPageResult> fetchNewestTopicsPage({
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
      final snapshot = await query.getCacheFirst();
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      final nextDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: nextDoc);
      return fetchTopicsPage(limit: limit, lastDoc: lastDoc, category: category);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchNewestTopics');
      try {
        Query fallback = _firestore.collection(FirestoreCollections.topics);
        if (category.toLowerCase() != 'all') {
          fallback = fallback.where('category', isEqualTo: category);
        }
        fallback = fallback.limit(limit);
        final snap = await fallback.getCacheFirst();
        final list = _deduplicateTopics(snap.docs.map(Topic.fromDocumentSnapshot));
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final nextDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: nextDoc);
      } catch (fallbackErr, fallbackStack) {
        ErrorHandler.log(fallbackErr, stackTrace: fallbackStack, tag: 'TopicRepository.fetchNewestTopics.fallback');
      }
      return fetchTopicsPage(limit: limit, lastDoc: lastDoc, category: category);
    }
  }

  Future<List<Topic>> fetchNewestTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    final page = await fetchNewestTopicsPage(
      category: category,
      limit: limit,
      lastDoc: lastDoc,
    );
    return page.topics;
  }

  Future<TopicPageResult> fetchPopularTopicsPage({
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
      final snapshot = await query.getCacheFirst();
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      final nextDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: nextDoc);
      return fetchTopicsPage(limit: limit, lastDoc: lastDoc, category: category);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchPopularTopics');
      try {
        Query fallback = _firestore.collection(FirestoreCollections.topics);
        if (category.toLowerCase() != 'all') {
          fallback = fallback.where('category', isEqualTo: category);
        }
        fallback = fallback.limit(limit);
        final snap = await fallback.getCacheFirst();
        final list = _deduplicateTopics(snap.docs.map(Topic.fromDocumentSnapshot));
        list.sort((a, b) => b.followerCount.compareTo(a.followerCount));
        final nextDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: nextDoc);
      } catch (fallbackErr, fallbackStack) {
        ErrorHandler.log(fallbackErr, stackTrace: fallbackStack, tag: 'TopicRepository.fetchPopularTopics.fallback');
      }
      return fetchTopicsPage(limit: limit, lastDoc: lastDoc, category: category);
    }
  }

  Future<List<Topic>> fetchPopularTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    final page = await fetchPopularTopicsPage(
      category: category,
      limit: limit,
      lastDoc: lastDoc,
    );
    return page.topics;
  }

  Future<TopicPageResult> fetchTopicsPage({
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
      final snapshot = await query.getCacheFirst();
      final list = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      final nextDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      if (list.isNotEmpty) return TopicPageResult(topics: list, lastDoc: nextDoc);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.fetchTopics');
    }

    try {
      Query fallbackQuery = _firestore.collection(FirestoreCollections.topics);
      if (category.toLowerCase() != 'all') {
        fallbackQuery = fallbackQuery.where('category', isEqualTo: category);
      }
      fallbackQuery = fallbackQuery.limit(limit);
      final snapshot = await fallbackQuery.getCacheFirst();
      final fallbackList = _deduplicateTopics(snapshot.docs.map(Topic.fromDocumentSnapshot));
      fallbackList.sort((a, b) => b.effectiveVideoCount.compareTo(a.effectiveVideoCount));
      final nextDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return TopicPageResult(topics: fallbackList, lastDoc: nextDoc);
    } catch (err, errStack) {
      ErrorHandler.log(err, stackTrace: errStack, tag: 'TopicRepository.fetchTopics.fallback');
      return const TopicPageResult(topics: [], lastDoc: null);
    }
  }

  Future<List<Topic>> fetchTopics({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    final page = await fetchTopicsPage(
      category: category,
      limit: limit,
      lastDoc: lastDoc,
    );
    return page.topics;
  }

  Future<List<Topic>> fetchFollowedTopics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('savedTopics')
          .getCacheFirst();

      if (snapshot.docs.isEmpty) return [];

      final topicIds = <String>{};
      for (final doc in snapshot.docs) {
        topicIds.add(doc.id);
        final data = doc.data();
        final rawId = data['topicId'] as String?;
        if (rawId != null && rawId.trim().isNotEmpty) {
          topicIds.add(rawId.trim());
        }
      }
      return _fetchTopicsByIds(topicIds.toList());
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
          .getCacheFirst();

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
                .getCacheFirst();
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
          .getCacheFirst();
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

      final txSuccess = await _firestore.runTransaction<bool>((tx) async {
        var topicSnap = await tx.get(topicRef);
        var activeTopicRef = topicRef;
        if (!topicSnap.exists) {
          final q = await _firestore
              .collection(FirestoreCollections.topics)
              .where('slug', isEqualTo: topicId)
              .limit(1)
              .getCacheFirst();
          if (q.docs.isNotEmpty) {
            activeTopicRef = _firestore
                .collection(FirestoreCollections.topics)
                .doc(q.docs.first.id);
            topicSnap = await tx.get(activeTopicRef);
          }
        }

        if (!topicSnap.exists) return false;
        final topic = Topic.fromDocumentSnapshot(topicSnap);
        final hasVideos = topic.effectiveVideoCount > 0 || topic.featuredVideoIds.isNotEmpty;
        if (topic.isArchivedOrDeleted || (!topic.isValidTopic && !hasVideos)) return false;

        final savedSnap = await tx.get(userSavedRef);
        // Idempotent guard: already following — do nothing, no duplicate count
        if (savedSnap.exists) {
          final data = topicSnap.data();
          final currentCount = (data?['followerCount'] as num?)?.toInt() ?? 0;
          if (currentCount < 1) {
            tx.update(activeTopicRef, {'followerCount': 1});
          }
          return true;
        }

        tx.set(userSavedRef, {
          'topicId': topicId,
          'savedAt': FieldValue.serverTimestamp(),
          'notificationSetting': 'personalized',
        });
        tx.update(activeTopicRef, {
          'followerCount': FieldValue.increment(1),
        });
        return true;
      });

      if (txSuccess) return true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.followTopic.transaction');
    }

    // Secondary fallback: Callable Cloud Function
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('followTopic');
      final res = await callable.call<Map<dynamic, dynamic>>({
        'topicId': topicId,
        'notificationSetting': 'personalized',
      });
      return res.data['success'] == true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.followTopic.callableFallback');
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
          .getCacheFirst();

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
          .getCacheFirst();
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

      final txSuccess = await _firestore.runTransaction<bool>((tx) async {
        final savedSnap = await tx.get(userSavedRef);
        // Idempotent guard: not following — do nothing, no negative drift
        if (!savedSnap.exists) return true;

        tx.delete(userSavedRef);

        var topicSnap = await tx.get(topicRef);
        var activeTopicRef = topicRef;
        if (!topicSnap.exists) {
          final q = await _firestore
              .collection(FirestoreCollections.topics)
              .where('slug', isEqualTo: topicId)
              .limit(1)
              .getCacheFirst();
          if (q.docs.isNotEmpty) {
            activeTopicRef = _firestore
                .collection(FirestoreCollections.topics)
                .doc(q.docs.first.id);
            topicSnap = await tx.get(activeTopicRef);
          }
        }

        if (topicSnap.exists) {
          final data = topicSnap.data();
          final currentCount = (data?['followerCount'] as num?)?.toInt() ?? 0;
          if (currentCount > 0) {
            tx.update(activeTopicRef, {
              'followerCount': FieldValue.increment(-1),
            });
          }
        }
        return true;
      });

      if (txSuccess) return true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.unfollowTopic.transaction');
    }

    // Secondary fallback: Callable Cloud Function
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('unfollowTopic');
      final res = await callable.call<Map<dynamic, dynamic>>({
        'topicId': topicId,
      });
      return res.data['success'] == true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.unfollowTopic.callableFallback');
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
          .getCacheFirst();

      final list = snapshot.docs.map(Channel.fromDocumentSnapshot).where((c) {
        final catMatch = c.category.toLowerCase().contains(tagLower) ||
            c.categories.any((cat) => cat.toLowerCase().contains(tagLower));
        final nameMatch = c.name.toLowerCase().contains(tagLower);
        final descMatch = c.description.toLowerCase().contains(tagLower);
        return catMatch || nameMatch || descMatch;
      }).toList();

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
          .getCacheFirst();

      final list = snapshot.docs
          .map(PlaylistModel.fromDocumentSnapshot)
          .where((p) {
        final nameMatch = p.name.toLowerCase().contains(tagLower);
        final descMatch = p.description.toLowerCase().contains(tagLower);
        return nameMatch || descMatch;
      }).toList();

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
          .getCacheFirst();

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
          .getCacheFirst();

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
          .getCacheFirst();

      final list = snapshot.docs
          .map((doc) => CommunityPostModel.fromMap(doc.data()..['id'] = doc.id))
          .where((post) {
        final titleMatch = post.title.toLowerCase().contains(tagLower);
        final descMatch = post.description.toLowerCase().contains(tagLower);
        final tagMatch = post.tags.any((t) => t.toLowerCase().contains(tagLower));
        final catMatch = post.selectedCategory.toLowerCase().contains(tagLower);
        return titleMatch || descMatch || tagMatch || catMatch;
      }).toList();

      return list.take(limit).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TopicRepository.getCommunityPostsByTopic');
      return [];
    }
  }
}

