import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/data/models/search_cache.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

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

  /// Execute search query with intelligent fallback across all types
  ///
  /// Returns: Merged list of SearchResult objects (videos, channels, playlists)
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) {
      return [];
    }
    final normalized = query.toLowerCase().trim();
    final cached = _cache.get(normalized);
    if (cached != null) {
      return cached;
    }

    try {
      // Execute all search types in parallel for maximum speed
      final results = await Future.wait([
        _searchVideos(normalized),
        _searchChannels(normalized),
        _searchPlaylists(normalized),
        _searchTopics(normalized),
      ]);

      // Merge and sort using Industry Standard relevance scoring & ranking
      var merged = results.expand((x) => x).toList();
      merged = _rankAndSortResults(merged, normalized);

      _cache.put(normalized, merged);
      return merged;
    } catch (e) {
      debugPrint('❌ [Search] Combined query failed: $e');
      return [];
    }
  }

  /// 🎬 VIDEO SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchVideos(String query) async {
    if (query.isEmpty) return [];

    final normalized = query.toLowerCase().trim();
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
    } catch (e) {
      debugPrint('❌ [Search] Video search failed: $e');
      return [];
    }
  }

  /// 🎬 VIDEO SEARCH (INTERNAL - with fallback strategy, cost-effective)
  Future<List<SearchResult>> _searchVideos(String query) async {
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    // 1. Try keywords (fast, indexed query)
    var results = await _firestore
        .collection('videos')
        .where('keywords', arrayContains: query)
        .where('status', whereIn: const ['processed', 'published'])
        .limit(20)
        .get()
        .then(
          (s) => s.docs.map(SearchResult.fromFirestore).toList(),
        );

    // 2. Fallback to prefix search (title)
    if (results.isEmpty) {
      results = await _firestore
          .collection('videos')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .where('status', whereIn: const ['processed', 'published'])
          .limit(20)
          .get()
          .then(
            (s) => s.docs
                .map(
                  SearchResult.fromFirestore,
                )
                .toList(),
          );
    }

    // 3. Free Local Multi-Token Fallback (for development/testing or offline capability)
    if (results.isEmpty) {
      try {
        if (Get.isRegistered<HomeController>()) {
          final homeCtrl = Get.find<HomeController>();
          final localMatches = homeCtrl.videos
              .where((v) {
                final t = v.title.toLowerCase();
                final c = v.channelName.toLowerCase();
                if (t.contains(query) || c.contains(query)) return true;
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
          results.addAll(localMatches);
        }
      } catch (e) {
        debugPrint('⚠️ [Search] Local cache fallback failed: $e');
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
    } catch (e) {
      debugPrint('❌ [Search] Channel search failed: $e');
      return [];
    }
  }

  /// 🎙️ CHANNEL SEARCH (INTERNAL - cost-effective)
  Future<List<SearchResult>> _searchChannels(String query) async {
    try {
      // 1. Try channelName prefix (indexed)
      var results = await _firestore
          .collection('channels')
          .where('channelName', isGreaterThanOrEqualTo: query)
          .where('channelName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get()
          .then(
            (s) => s.docs
                .map(
                  (d) =>
                      SearchResult.fromFirestore(d, type: ResultType.channel),
                )
                .toList(),
          );

      // 2. Try handle if no results
      if (results.isEmpty) {
        results = await _firestore
            .collection('channels')
            .where('handle', isGreaterThanOrEqualTo: query)
            .where('handle', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(10)
            .get()
            .then(
              (s) => s.docs
                  .map(
                    (d) =>
                        SearchResult.fromFirestore(d, type: ResultType.channel),
                  )
                  .toList(),
            );
      }
      return results;
    } catch (e) {
      debugPrint('⚠️ [Search] Channel query failed: $e');
      return [];
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
    } catch (e) {
      debugPrint('❌ [Search] Playlist search failed: $e');
      return [];
    }
  }

  /// 📂 PLAYLIST SEARCH (INTERNAL - cost-effective)
  Future<List<SearchResult>> _searchPlaylists(String query) async {
    try {
      return await _firestore
          .collection('playlists')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .where('visibility', isEqualTo: 'Public')
          .limit(10)
          .get()
          .then(
            (s) => s.docs
                .map(
                  (d) =>
                      SearchResult.fromFirestore(d, type: ResultType.playlist),
                )
                .toList(),
          );
    } catch (e) {
      debugPrint('⚠️ [Search] Playlist query failed: $e');
      return [];
    }
  }

  /// 🏷️ TOPIC SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchTopics(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final normalized = query.toLowerCase().trim();
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
    } catch (e) {
      debugPrint('❌ [Search] Topic search failed: $e');
      return [];
    }
  }

  /// 🏷️ TOPIC SEARCH (INTERNAL - cost-effective)
  Future<List<SearchResult>> _searchTopics(String query) async {
    try {
      // 1. Try title prefix
      var results = await _firestore
          .collection('topics')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get()
          .then(
            (s) => s.docs
                .map(
                  (d) => SearchResult.fromFirestore(d, type: ResultType.topic),
                )
                .toList(),
          );

      // 2. Try handle prefix if no results
      if (results.isEmpty) {
        results = await _firestore
            .collection('topics')
            .where('handle', isGreaterThanOrEqualTo: query)
            .where('handle', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(10)
            .get()
            .then(
              (s) => s.docs
                  .map(
                    (d) =>
                        SearchResult.fromFirestore(d, type: ResultType.topic),
                  )
                  .toList(),
            );
      }
      return results;
    } catch (e) {
      debugPrint('⚠️ [Search] Topic query failed: $e');
      return [];
    }
  }

  /// Fetch recommended videos for empty search state (You may like section)
  /// Returns top 5 most viewed videos
  Future<List<SearchResult>> getRecommended() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('status', whereIn: const ['processed', 'published'])
          .orderBy('views', descending: true)
          .limit(5)
          .get();

      return snapshot.docs.map(SearchResult.fromFirestore).toList();
    } catch (e) {
      debugPrint('⚠️ [Search] Recommended fetch failed: $e');
      // Secondary fallback: query without ordering if index is missing
      try {
        final snapshot = await _firestore.collection('videos').limit(5).get();
        return snapshot.docs.map(SearchResult.fromFirestore).toList();
      } catch (err) {
        debugPrint('⚠️ [Search] Fallback recommended fetch failed: $err');
        return [];
      }
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
      } catch (_) {
        try {
          snapshot = await _firestore
              .collection('trending_searches')
              .orderBy('count', descending: true)
              .limit(10)
              .get();
        } catch (_) {
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
    } catch (e) {
      debugPrint('⚠️ [Search] Trending fetch failed: $e');
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

      // 4. Popularity Boost (Log scale of views)
      if (item.views > 0) {
        score += item.views.toString().length * 2.5;
      }

      // 5. Freshness / Recency Boost
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
      } catch (e) {
        debugPrint('⚠️ [Search] Failed to warmup "$query": $e');
      }

      // Small delay to avoid overwhelming Firestore
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('✅ [Search] Cache warmup complete');
  }
}
