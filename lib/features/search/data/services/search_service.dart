import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/data/models/search_cache.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// SearchService: Core query logic
///
/// Responsibilities:
/// - Handle Firestore queries
/// - Implement fallback strategy
/// - Sort results locally
/// - Manage cache
///
/// Query Strategy (low-latency MVP):
/// 1. Check cache (instant)
/// 2. Primary: keyword search (fast)
/// 3. Fallback: prefix search (if no results)
/// 4. Sort locally
/// 5. Cache result
class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SearchCache _cache = SearchCache();

  static final RegExp _whitespaceRegExp = RegExp(r'\s+');
  static final RegExp _trailingPunctuationRegExp = RegExp(r'[\.\?\!\,\;\:\-_]+$');
  static final RegExp _leadingPunctuationRegExp = RegExp(r'^[\.\?\!\,\;\:\-_]+');
  static final RegExp _nonWordNonDigitRegExp = RegExp(r'[^\w\d]');

  /// Strips trailing and leading punctuation marks (. ? ! , ; : - _) and collapses whitespace
  static String sanitizeQuery(String query) {
    var cleaned = query.trim().replaceAll(_whitespaceRegExp, ' ');
    cleaned = cleaned.replaceAll(_trailingPunctuationRegExp, '').trim();
    cleaned = cleaned.replaceAll(_leadingPunctuationRegExp, '').trim();
    return cleaned.toLowerCase();
  }

  /// Extracts clean alphanumeric search tokens without punctuation
  static List<String> extractTokens(String query) {
    return query
        .toLowerCase()
        .split(_whitespaceRegExp)
        .map((t) => t.replaceAll(_nonWordNonDigitRegExp, '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Execute search query with intelligent fallback across all types
  ///
  /// Returns: Merged list of SearchResult objects (videos, channels, playlists, topics)
  Future<List<SearchResult>> search(String query, {AiSearchIntent? intent}) async {
    final normalized = sanitizeQuery(query);
    if (normalized.isEmpty) {
      return [];
    }

    final cacheKey = intent != null && intent.hasCriteria
        ? 'ai:${intent.resultMode.name}:$normalized'
        : normalized;

    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      if (intent != null && intent.hasCriteria) {
        // AI-guided query expansion: query Firestore using clean keywords
        final searchTerms = <String>{};
        if (intent.cleanKeywords.isNotEmpty) {
          searchTerms.addAll(intent.cleanKeywords.take(3));
        } else if (intent.detectedLanguage != null) {
          searchTerms.add(intent.detectedLanguage!);
        }
        if (searchTerms.isEmpty) {
          searchTerms.add(normalized);
        }

        final candidateMap = <String, SearchResult>{};
        for (final term in searchTerms) {
          final termResults = await Future.wait([
            _searchVideos(term),
            _searchChannels(term),
            _searchPlaylists(term),
            _searchTopics(term),
          ]);
          for (final item in termResults.expand((x) => x)) {
            candidateMap['${item.type.name}_${item.id}'] = item;
          }
        }

        // Score and filter candidates against the rich intent
        final scoredCandidates = <SearchResult>[];
        for (final item in candidateMap.values) {
          final score = AiSearchService.instance.scoreSearchResult(item, intent);
          if (score > 0) {
            item.relevanceScore = score;
            scoredCandidates.add(item);
          }
        }

        // Sort based on intent mode
        if (intent.resultMode == SearchResultMode.trending) {
          scoredCandidates.sort((a, b) => b.views.compareTo(a.views));
        } else if (intent.resultMode == SearchResultMode.recent) {
          scoredCandidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else {
          // Both ranked and exhaustive preserve high relevance at the top
          scoredCandidates.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
        }

        _cache.put(cacheKey, scoredCandidates);
        return scoredCandidates;
      }

      // Standard search: execute all search types in parallel for maximum speed
      final results = await Future.wait([
        _searchVideos(normalized),
        _searchChannels(normalized),
        _searchPlaylists(normalized),
        _searchTopics(normalized),
      ]);

      // Merge and sort using Industry Standard relevance scoring & ranking
      var merged = results.expand((x) => x).toList();
      merged = _rankAndSortResults(merged, normalized);

      _cache.put(cacheKey, merged);
      return merged;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.search.combined');
      return [];
    }
  }

  /// 🎬 VIDEO SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchVideos(String query) async {
    final normalized = sanitizeQuery(query);
    if (normalized.isEmpty) return [];

    final cacheKey = 'videos:$normalized';

    // Check cache
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for videos: "$query"');
      return cached;
    }

    try {
      final results = await _searchVideos(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchVideos');
      return [];
    }
  }

  /// 🎬 VIDEO SEARCH (INTERNAL - with fallback strategy, cost-effective & case-insensitive)
  Future<List<SearchResult>> _searchVideos(String query) async {
    final cleanQuery = sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item, [Map<String, dynamic>? data]) {
      if (!item.isValid) return;
      if (data != null && !VideoVisibilityPolicy.isMapValid(data)) return;
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    // 1. Try keywords (fast, indexed query)
    try {
      final s = await _firestore
          .collection('videos')
          .where('keywords', arrayContains: cleanQuery)
          .limit(20)
          .get();
      for (final doc in s.docs) {
        addResult(SearchResult.fromFirestore(doc), doc.data());
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchVideos.keywords');
    }

    // 2. Try prefix search with lowercase, TitleCase, and UPPERCASE
    if (results.isEmpty) {
      for (final qPrefix in [query, titleCased, query.toUpperCase()]) {
        try {
          final s = await _firestore
              .collection('videos')
              .where('title', isGreaterThanOrEqualTo: qPrefix)
              .where('title', isLessThanOrEqualTo: '$qPrefix\uf8ff')
              .limit(20)
              .get();
          for (final doc in s.docs) {
            addResult(SearchResult.fromFirestore(doc));
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchVideos.prefix');
        }
        if (results.isNotEmpty) break;
      }
    }

    // 3. Robust Full-Text Substring Fallback over Firestore videos
    if (results.isEmpty) {
      try {
        final s = await _firestore.collection('videos').limit(50).get();
        final docs = s.docs.map(SearchResult.fromFirestore);
        for (final item in docs) {
          final t = item.title.toLowerCase();
          final c = item.channelName.toLowerCase();
          if (t.contains(cleanQuery) ||
              c.contains(cleanQuery) ||
              (tokens.isNotEmpty &&
                  tokens.every((token) => t.contains(token) || c.contains(token)))) {
            addResult(item);
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchVideos.fullscan');
      }
    }

    // 4. Free Local Multi-Token Fallback (for development/testing or offline capability)
    if (results.isEmpty) {
      try {
        if (Get.isRegistered<HomeController>()) {
          final homeCtrl = Get.find<HomeController>();
          final localMatches = homeCtrl.videos
              .whereType<Video>()
              .where((v) {
                final t = v.title.toLowerCase();
                final c = v.channelName.toLowerCase();
                if (t.contains(cleanQuery) || c.contains(cleanQuery)) return true;
                if (tokens.isNotEmpty) {
                  return tokens.every(
                    (token) => t.contains(token) || c.contains(token),
                  );
                }
                return false;
              })
              .map(
                (v) => SearchResult(
                  id: v.id,
                  title: v.title,
                  thumbnail: v.thumbnailUrl,
                  views: v.viewCount,
                  channelName: v.channelName,
                  channelImage: v.channelAvatarUrl,
                  createdAt: v.createdAt,
                  durationMs: v.durationValue.inMilliseconds,
                ),
              );
          localMatches.forEach(addResult);
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchVideos.localCache');
      }
    }

    return results;
  }

  /// 🎙️ CHANNEL SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchChannels(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final normalized = query.toLowerCase().trim();
    final cacheKey = 'channels:$normalized';

    // Check cache
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for channels: "$query"');
      return cached;
    }

    try {
      final results = await _searchChannels(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchChannels');
      return [];
    }
  }

  /// 🎙️ CHANNEL SEARCH (INTERNAL - robust case-insensitive with fallback)
  Future<List<SearchResult>> _searchChannels(String query) async {
    final cleanQuery = sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item) {
      if (!item.isValid) return;
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    try {
      // 1. Try nameLowercase prefix
      final s1 = await _firestore
          .collection('channels')
          .where('nameLowercase', isGreaterThanOrEqualTo: cleanQuery)
          .where('nameLowercase', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(10)
          .get();
      for (final doc in s1.docs) {
        addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
      }

      // 2. Try name prefix (query and TitleCase)
      if (results.isEmpty) {
        for (final qPrefix in [cleanQuery, titleCased]) {
          final s2 = await _firestore
              .collection('channels')
              .where('name', isGreaterThanOrEqualTo: qPrefix)
              .where('name', isLessThanOrEqualTo: '$qPrefix\uf8ff')
              .limit(10)
              .get();
          for (final doc in s2.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
          }
          if (results.isNotEmpty) break;
        }
      }

      // 3. Try handle / handleLowercase prefix
      if (results.isEmpty) {
        for (final handleQ in [cleanQuery, '@$cleanQuery']) {
          final s3 = await _firestore
              .collection('channels')
              .where('handleLowercase', isGreaterThanOrEqualTo: handleQ)
              .where('handleLowercase', isLessThanOrEqualTo: '$handleQ\uf8ff')
              .limit(10)
              .get();
          for (final doc in s3.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
          }
          if (results.isNotEmpty) break;
        }
      }

      // 4. Fallback Full-Text substring scan over channels
      if (results.isEmpty) {
        final s4 = await _firestore.collection('channels').limit(40).get();
        for (final doc in s4.docs) {
          final data = doc.data();
          final name = (data['name'] as String? ?? data['channelName'] as String? ?? '').toLowerCase();
          final handle = (data['handle'] as String? ?? '').toLowerCase();
          final desc = (data['description'] as String? ?? '').toLowerCase();

          if (name.contains(cleanQuery) ||
              handle.contains(cleanQuery) ||
              desc.contains(cleanQuery) ||
              (tokens.isNotEmpty && tokens.every((tok) => name.contains(tok) || handle.contains(tok)))) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
          }
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService._searchChannels');
      return results;
    }
  }

  /// 📂 PLAYLIST SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchPlaylists(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final normalized = query.toLowerCase().trim();
    final cacheKey = 'playlists:$normalized';

    // Check cache
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for playlists: "$query"');
      return cached;
    }

    try {
      final results = await _searchPlaylists(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchPlaylists');
      return [];
    }
  }

  /// 📂 PLAYLIST SEARCH (INTERNAL - robust case-insensitive with fallback)
  Future<List<SearchResult>> _searchPlaylists(String query) async {
    final cleanQuery = sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item, [Map<String, dynamic>? data]) {
      if (!item.isValid) return;
      if (data != null) {
        final vis = (data['visibility'] as String?)?.toLowerCase();
        if (vis == 'private') return;
        final count = (data['videoCount'] as num?)?.toInt() ??
            (data['videosCount'] as num?)?.toInt() ??
            (data['videoIds'] as List?)?.length ??
            0;
        if (count <= 0) return;
      }
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    try {
      // 1. Try name prefix (query and TitleCase)
      for (final qPrefix in [cleanQuery, titleCased]) {
        final s1 = await _firestore
            .collection('playlists')
            .where('name', isGreaterThanOrEqualTo: qPrefix)
            .where('name', isLessThanOrEqualTo: '$qPrefix\uf8ff')
            .limit(10)
            .get();
        for (final doc in s1.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.playlist), doc.data());
        }
        if (results.isNotEmpty) break;
      }

      // 2. Try title prefix if empty
      if (results.isEmpty) {
        for (final qPrefix in [cleanQuery, titleCased]) {
          final s2 = await _firestore
              .collection('playlists')
              .where('title', isGreaterThanOrEqualTo: qPrefix)
              .where('title', isLessThanOrEqualTo: '$qPrefix\uf8ff')
              .limit(10)
              .get();
          for (final doc in s2.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.playlist), doc.data());
          }
          if (results.isNotEmpty) break;
        }
      }

      // 3. Fallback Full-Text substring scan over playlists
      if (results.isEmpty) {
        final s3 = await _firestore.collection('playlists').limit(40).get();
        for (final doc in s3.docs) {
          final data = doc.data();
          final name = (data['name'] as String? ?? data['playlistName'] as String? ?? data['title'] as String? ?? '').toLowerCase();
          final desc = (data['description'] as String? ?? '').toLowerCase();

          if (name.contains(cleanQuery) ||
              desc.contains(cleanQuery) ||
              (tokens.isNotEmpty && tokens.every(name.contains))) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.playlist), data);
          }
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService._searchPlaylists');
      return results;
    }
  }

  /// 🏷️ TOPIC SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchTopics(String query) async {
    final normalized = sanitizeQuery(query);
    if (normalized.isEmpty) {
      return [];
    }

    final cacheKey = 'topics:$normalized';

    // Check cache
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for topics: "$query"');
      return cached;
    }

    try {
      final results = await _searchTopics(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchTopics');
      return [];
    }
  }

  /// 🏷️ TOPIC SEARCH (INTERNAL - robust case-insensitive with fallback)
  Future<List<SearchResult>> _searchTopics(String query) async {
    final cleanQuery = sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item, [Map<String, dynamic>? data]) {
      if (!item.isValid) return;
      if (data != null) {
        final status = (data['status'] as String?)?.toLowerCase();
        if (status != null && status != 'active') return;
        final count = (data['videoCount'] as num?)?.toInt() ??
            (data['featuredVideoIds'] as List?)?.length ??
            0;
        if (count <= 0) return;
      }
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    try {
      // 1. Try title prefix (query and TitleCase)
      for (final qPrefix in [cleanQuery, titleCased]) {
        final s1 = await _firestore
            .collection('topics')
            .where('title', isGreaterThanOrEqualTo: qPrefix)
            .where('title', isLessThanOrEqualTo: '$qPrefix\uf8ff')
            .limit(10)
            .get();
        for (final doc in s1.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), doc.data());
        }
        if (results.isNotEmpty) break;
      }

      // 2. Try slug prefix
      if (results.isEmpty) {
        final s2 = await _firestore
            .collection('topics')
            .where('slug', isGreaterThanOrEqualTo: cleanQuery)
            .where('slug', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
            .limit(10)
            .get();
        for (final doc in s2.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), doc.data());
        }
      }

      // 3. Try tags arrayContains
      if (results.isEmpty) {
        final s3 = await _firestore
            .collection('topics')
            .where('tags', arrayContains: cleanQuery)
            .limit(10)
            .get();
        for (final doc in s3.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), doc.data());
        }
      }

      // 4. Fallback Full-Text substring scan over topics
      if (results.isEmpty) {
        final s4 = await _firestore.collection('topics').limit(40).get();
        for (final doc in s4.docs) {
          final data = doc.data();
          final title = (data['title'] as String? ?? data['name'] as String? ?? '').toLowerCase();
          final desc = (data['description'] as String? ?? '').toLowerCase();

          if (title.contains(cleanQuery) ||
              desc.contains(cleanQuery) ||
              (tokens.isNotEmpty && tokens.every(title.contains))) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), data);
          }
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService._searchTopics');
      return results;
    }
  }

  /// Fetch recommended videos for empty search state
  /// Returns top 12 most viewed videos
  Future<List<SearchResult>> getRecommended() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('status', whereIn: const ['ready', 'processed', 'published', 'public'])
          .orderBy('views', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .where((doc) => VideoVisibilityPolicy.isMapValid(doc.data()))
          .map(SearchResult.fromFirestore)
          .where((item) => item.isValid)
          .take(12)
          .toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.getRecommended');
      // Secondary fallback: query without composite ordering (and sort locally) if index is building or missing
      try {
        final snapshot = await _firestore.collection('videos').limit(30).get();
        final results = snapshot.docs
            .where((doc) => VideoVisibilityPolicy.isMapValid(doc.data()))
            .map(SearchResult.fromFirestore)
            .where((item) => item.isValid)
            .toList();
        results.sort((a, b) => b.views.compareTo(a.views));
        return results.take(12).toList();
      } catch (err, errStack) {
        ErrorHandler.log(err, stackTrace: errStack, tag: 'SearchService.getRecommended.fallback');
        return [];
      }
    }
  }

  /// Fetch recommended channels for empty search state
  Future<List<SearchResult>> getRecommendedChannels() async {
    try {
      final snapshot = await _firestore
          .collection('channels')
          .limit(25)
          .get();

      final results = snapshot.docs
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.channel))
          .where((item) => item.isValid)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      return results.take(15).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.getRecommendedChannels');
      return [];
    }
  }

  /// Fetch recommended playlists for empty search state (only playlists with at least 1 video)
  Future<List<SearchResult>> getRecommendedPlaylists() async {
    try {
      final snapshot = await _firestore
          .collection('playlists')
          .limit(25)
          .get();

      final results = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final vis = (data['visibility'] as String?)?.toLowerCase();
            final count = (data['videoCount'] as num?)?.toInt() ??
                (data['videosCount'] as num?)?.toInt() ??
                (data['videoIds'] as List?)?.length ??
                0;
            return (vis == null || vis != 'private') && count > 0;
          })
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.playlist))
          .where((item) => item.isValid && item.views > 0)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      return results.take(15).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.getRecommendedPlaylists');
      return [];
    }
  }

  /// Fetch recommended topics for empty search state (only active topics with at least 1 video)
  Future<List<SearchResult>> getRecommendedTopics() async {
    try {
      final snapshot = await _firestore
          .collection('topics')
          .limit(25)
          .get();

      final results = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final status = (data['status'] as String?)?.toLowerCase();
            final count = (data['videoCount'] as num?)?.toInt() ??
                (data['featuredVideoIds'] as List?)?.length ??
                0;
            return (status == null || status == 'active') && count > 0;
          })
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.topic))
          .where((item) => item.isValid && item.views > 0)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      return results.take(15).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.getRecommendedTopics');
      return [];
    }
  }

  /// Fetch a balanced, diverse mix of videos, channels, playlists, and topics for 'All' tab
  Future<List<SearchResult>> getRecommendedAll() async {
    try {
      final results = await Future.wait([
        getRecommended(),
        getRecommendedChannels(),
        getRecommendedPlaylists(),
        getRecommendedTopics(),
      ]);

      final videos = results[0];
      final channels = results[1];
      final playlists = results[2];
      final topics = results[3];

      final combined = <SearchResult>[];

      // Curated layout for the 'All' tab:
      // 1. Top Channel (if available)
      if (channels.isNotEmpty) {
        combined.add(channels.first);
      }

      // 2. Top 2 Videos
      if (videos.isNotEmpty) {
        combined.addAll(videos.take(2));
      }

      // 3. Top Topic (if available)
      if (topics.isNotEmpty) {
        combined.add(topics.first);
      }

      // 4. Next 2 Videos
      if (videos.length > 2) {
        combined.addAll(videos.skip(2).take(2));
      }

      // 5. Top Playlist (if available)
      if (playlists.isNotEmpty) {
        combined.add(playlists.first);
      }

      // 6. Remaining Channels
      if (channels.length > 1) {
        combined.addAll(channels.skip(1).take(2));
      }

      // 7. Remaining Topics
      if (topics.length > 1) {
        combined.addAll(topics.skip(1).take(2));
      }

      // 8. Remaining Playlists
      if (playlists.length > 1) {
        combined.addAll(playlists.skip(1).take(2));
      }

      // 9. Remaining Videos
      if (videos.length > 4) {
        combined.addAll(videos.skip(4));
      }

      final seenKeys = <String>{};
      final uniqueCombined = <SearchResult>[];
      for (final item in combined) {
        if (seenKeys.add('${item.type.name}_${item.id}')) {
          uniqueCombined.add(item);
        }
      }

      return uniqueCombined.isNotEmpty ? uniqueCombined : videos;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.getRecommendedAll');
      return getRecommended();
    }
  }

  /// Fetch recommended content based on the active filter chip
  Future<List<SearchResult>> getRecommendedForFilter(
    String filter, {
    Set<String>? watchedVideoIds,
  }) async {
    switch (filter) {
      case 'Channels':
        return getRecommendedChannels();
      case 'Playlists':
        return getRecommendedPlaylists();
      case 'Topics':
        return getRecommendedTopics();
      case 'Watched':
        final allVideos = await getRecommended();
        if (watchedVideoIds == null || watchedVideoIds.isEmpty) {
          return allVideos.take(6).toList();
        }
        return allVideos
            .where((v) => watchedVideoIds.contains(v.id))
            .toList();
      case 'Unwatched':
        final allVideos = await getRecommended();
        if (watchedVideoIds == null || watchedVideoIds.isEmpty) {
          return allVideos;
        }
        return allVideos
            .where((v) => !watchedVideoIds.contains(v.id))
            .toList();
      case 'Recently uploaded':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final allVideos = await getRecommended();
        final recent = allVideos.where((v) => v.uploadedAt.isAfter(sevenDaysAgo)).toList();
        return recent.isNotEmpty ? recent : allVideos;
      case 'Videos':
        return getRecommended();
      case 'All':
      default:
        return getRecommendedAll();
    }
  }

  /// Fetch trending search queries from Firestore
  Future<List<String>> getTrendingSuggestions() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('trending_searches')
            .orderBy('searchCount', descending: true)
            .limit(10)
            .get();
      } catch (e1, s1) {
        ErrorHandler.log(e1, stackTrace: s1, tag: 'SearchService.trending.searchCount');
        try {
          snapshot = await _firestore
              .collection('trending_searches')
              .orderBy('count', descending: true)
              .limit(10)
              .get();
        } catch (e2, s2) {
          ErrorHandler.log(e2, stackTrace: s2, tag: 'SearchService.trending.count');
          snapshot = await _firestore
              .collection('trending_searches')
              .limit(10)
              .get();
        }
      }

      if (snapshot.docs.isEmpty) {
        return const [
          'Flutter Tutorial',
          'Web Development',
          'Mobile Apps',
          'UI Design',
          'Firebase',
        ];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['term'] ?? data['query'] ?? doc.id).toString();
      }).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.getTrendingSuggestions');
      return const [
        'Flutter Tutorial',
        'Web Development',
        'Mobile Apps',
        'UI Design',
        'Firebase',
      ];
    }
  }

  /// Sort results locally using Industry Standard multi-factor relevance ranking
  List<SearchResult> _rankAndSortResults(
    List<SearchResult> results,
    String rawQuery,
  ) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return results;

    final tokens = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    for (final item in results) {
      var score = 0.0;
      final title = item.title.toLowerCase();
      final channel = item.channelName.toLowerCase();

      // 1. Title matching (Exact: 100, Prefix: 80, Substring: 60)
      if (title == query) {
        score += 100.0;
      } else if (title.startsWith(query)) {
        score += 80.0;
      } else if (title.contains(query)) {
        score += 60.0;
      }

      // 2. Channel matching (Exact: 75, Prefix: 55, Substring: 35)
      if (channel == query) {
        score += 75.0;
      } else if (channel.startsWith(query)) {
        score += 55.0;
      } else if (channel.contains(query)) {
        score += 35.0;
      }

      // 3. Multi-token coverage boost (up to 50 points based on ratio of matched words)
      if (tokens.isNotEmpty) {
        var tokenMatches = 0;
        for (final token in tokens) {
          if (title.contains(token) || channel.contains(token)) {
            tokenMatches++;
          }
        }
        final tokenRatio = tokenMatches / tokens.length;
        score += tokenRatio * 50.0;
      }

      // 4. Prominence boost for channels, topics, and playlists when there is a strong match
      if (score >= 60.0) {
        if (item.type == ResultType.channel) {
          score += 25.0; // Place strongly matching channel near the top
        } else if (item.type == ResultType.topic) {
          score += 15.0; // Place strongly matching topic hub prominently
        } else if (item.type == ResultType.playlist) {
          score += 10.0; // Place strongly matching playlist prominently
        }
      }

      // 5. Popularity Boost (Log scale of views)
      if (item.views > 0) {
        score += item.views.toString().length * 2.5;
      }

      // 6. Freshness / Recency Boost
      final daysOld = DateTime.now().difference(item.createdAt.toDate()).inDays;
      if (daysOld >= 0 && daysOld < 30) {
        score += (30 - daysOld) * 0.3;
      }

      item.relevanceScore = score;
    }

    results.sort((a, b) {
      final scoreCompare = b.relevanceScore.compareTo(a.relevanceScore);
      if (scoreCompare != 0) return scoreCompare;
      final viewsCompare = b.views.compareTo(a.views);
      if (viewsCompare != 0) return viewsCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    return results;
  }

  /// Clear cache manually
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️ [Search] Cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  /// Check if a query is cached
  bool isCached(String query) {
    return _cache.isCached(query);
  }

  /// Warmup cache with trending searches (optional)
  ///
  /// Call during app init to pre-populate cache
  /// with popular searches
  Future<void> warmupCache(List<String> trendingQueries) async {
    debugPrint(
      '🔥 [Search] Warming up cache with ${trendingQueries.length} trending searches',
    );

    for (final query in trendingQueries) {
      // Skip if already cached
      if (_cache.isCached(query)) continue;

      try {
        final results = await search(query);
        debugPrint(
          '✅ [Search] Warmed up: "$query" (${results.length} results)',
        );
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.warmupCache');
      }

      // Small delay to avoid overwhelming Firestore
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('✅ [Search] Cache warmup complete');
  }
}
