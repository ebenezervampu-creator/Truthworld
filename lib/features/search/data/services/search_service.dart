import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import '../models/search_result.dart';
import '../models/search_cache.dart';

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

      // Merge and sort
      List<SearchResult> merged = results.expand((x) => x).toList();
      merged = _sortResults(merged);

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
    // 1. Try keywords (fast, indexed query)
    var results = await _firestore
        .collection('videos')
        .where('keywords', arrayContains: query)
        .where('status', whereIn: const ['processed', 'published'])
        .limit(20)
        .get()
        .then(
          (s) => s.docs
              .map((d) => SearchResult.fromFirestore(d, type: ResultType.video))
              .toList(),
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
                  (d) => SearchResult.fromFirestore(d, type: ResultType.video),
                )
                .toList(),
          );
    }

    // 3. Free Local Cache Fallback (for development/testing or offline capability)
    // Note: This fallback only searches currently cached/loaded videos in HomeController, not the entire Firestore catalog,
    // which prevents costly Firestore reads.
    if (results.isEmpty) {
      try {
        if (Get.isRegistered<HomeController>()) {
          final homeCtrl = Get.find<HomeController>();
          final localMatches = homeCtrl.videos
              .where((v) => v.title.toLowerCase().contains(query))
              .map((v) => SearchResult(
                    id: v.id,
                    title: v.title,
                    thumbnail: v.thumbnailUrl,
                    views: v.viewCount,
                    channelName: v.channelName,
                    channelImage: v.channelAvatarUrl,
                    createdAt: v.createdAt,
                    type: ResultType.video,
                    durationMs: v.durationValue.inMilliseconds,
                  ));
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
                  (d) => SearchResult.fromFirestore(d, type: ResultType.channel),
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
                    (d) => SearchResult.fromFirestore(d, type: ResultType.channel),
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
                    (d) => SearchResult.fromFirestore(d, type: ResultType.topic),
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
          .where('visibility', isEqualTo: 'Public')
          .orderBy('views', descending: true)
          .limit(5)
          .get();

      return snapshot.docs
          .map((doc) => SearchResult.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [Search] Recommended fetch failed: $e');
      // Final fallback: just get any 5 videos if views-ordering requires an index
      try {
        final snapshot = await _firestore.collection('videos').limit(5).get();
        return snapshot.docs
            .map((doc) => SearchResult.fromFirestore(doc))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Fetch trending search queries from Firestore
  Future<List<String>> getTrendingSuggestions() async {
    try {
      final snapshot = await _firestore
          .collection('trending_searches')
          .orderBy('count', descending: true)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) {
        return [
          'Flutter Tutorial',
          'Web Development',
          'Mobile Apps',
          'UI Design',
          'Firebase',
        ];
      }

      return snapshot.docs.map((doc) => doc.get('query') as String).toList();
    } catch (e) {
      debugPrint('⚠️ [Search] Trending fetch failed: $e');
      return [
        'Flutter Tutorial',
        'Web Development',
        'Mobile Apps',
        'UI Design',
        'Firebase',
      ];
    }
  }

  /// Sort results locally (avoid expensive Firestore sorting)
  ///
  /// Priority:
  /// 1. Views (descending) - most popular first
  /// 2. CreatedAt (descending) - most recent second
  List<SearchResult> _sortResults(List<SearchResult> results) {
    results.sort((a, b) {
      // First: sort by views (descending)
      final viewsCompare = b.views.compareTo(a.views);
      if (viewsCompare != 0) return viewsCompare;

      // Second: sort by date (descending)
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
      await Future.delayed(Duration(milliseconds: 100));
    }

    debugPrint('✅ [Search] Cache warmup complete');
  }
}





