import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/features/search/data/models/search_cache.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/engine/search_engine_barrel.dart';

export 'engine/search_engine_barrel.dart';

/// Central search coordinator orchestrating vector search, multi-tier fallback, and caching.
class SearchService {
  SearchService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    SearchCache? cache,
    TypesenseSearchEngine? typesenseEngine,
  })  : _cache = cache ?? SearchCache(),
        _typesenseEngine = typesenseEngine ?? TypesenseSearchEngine(),
        _cloudExecutor = SearchCloudExecutor(functions: functions),
        _entityEngine = SearchEntityQueryEngine(firestore: firestore),
        _recommendationsEngine =
            SearchRecommendationsEngine(firestore: firestore),
        _ranker = const SearchResultRanker();

  final SearchCache _cache;
  final TypesenseSearchEngine _typesenseEngine;
  final SearchCloudExecutor _cloudExecutor;
  final SearchEntityQueryEngine _entityEngine;
  final SearchRecommendationsEngine _recommendationsEngine;
  final SearchResultRanker _ranker;

  /// Strips trailing and leading punctuation marks (. ? ! , ; : - _) and collapses whitespace
  static String sanitizeQuery(String query) =>
      SearchSanitizer.sanitizeQuery(query);

  /// Extracts clean alphanumeric search tokens without punctuation
  static List<String> extractTokens(String query) =>
      SearchSanitizer.extractTokens(query);

  /// Execute search query with intelligent fallback across all types
  Future<List<SearchResult>> search(
    String query, {
    AiSearchIntent? intent,
    String? filter,
    int limit = 20,
  }) async {
    final normalized = sanitizeQuery(query);
    if (normalized.isEmpty) {
      return [];
    }

    final cacheKey = intent != null && intent.hasCriteria
        ? 'ai:${intent.resultMode.name}:${filter ?? "All"}:$normalized'
        : '${filter ?? "All"}:$normalized';

    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    final effectiveFilter =
        filter ?? (intent?.scope.name.capitalizeFirst ?? 'All');

    // Step 0: Instant (<30ms) Typo-Tolerant Typesense Search
    if (_typesenseEngine.isEnabled) {
      final tsResults = await _typesenseEngine.searchCombined(
        normalized,
        filter: effectiveFilter,
        limit: limit,
      );
      if (tsResults.isNotEmpty) {
        _cache.put(cacheKey, tsResults);
        return tsResults;
      }
    }

    // Step 1: In-House Server-Side Vector & Hybrid Search via Cloud Function
    final backendResults = await _cloudExecutor.executeVectorSearch(
      normalized,
      filter: effectiveFilter,
      limit: limit,
    );

    if (backendResults.isNotEmpty) {
      _cache.put(cacheKey, backendResults);
      return backendResults;
    }

    // Step 2: Client Fallback (Cold-start, offline resilience, or AI-guided)
    try {
      if (intent != null && intent.hasCriteria) {
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
            _entityEngine.searchVideos(term),
            _entityEngine.searchChannels(term),
            _entityEngine.searchPlaylists(term),
            _entityEngine.searchTopics(term),
          ]);
          for (final item in termResults.expand((x) => x)) {
            candidateMap['${item.type.name}_${item.id}'] = item;
          }
        }

        final scoredCandidates = <SearchResult>[];
        for (final item in candidateMap.values) {
          final score =
              AiSearchService.instance.scoreSearchResult(item, intent);
          if (score > 0) {
            item.relevanceScore = score;
            scoredCandidates.add(item);
          }
        }

        if (intent.resultMode == SearchResultMode.trending) {
          scoredCandidates.sort((a, b) => b.views.compareTo(a.views));
        } else if (intent.resultMode == SearchResultMode.recent) {
          scoredCandidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else {
          scoredCandidates.sort(
            (a, b) => b.relevanceScore.compareTo(a.relevanceScore),
          );
        }

        _cache.put(cacheKey, scoredCandidates);
        return scoredCandidates;
      }

      // Standard search: execute all search types in parallel for maximum speed
      final results = await Future.wait([
        _entityEngine.searchVideos(normalized),
        _entityEngine.searchChannels(normalized),
        _entityEngine.searchPlaylists(normalized),
        _entityEngine.searchTopics(normalized),
      ]);

      var merged = results.expand((x) => x).toList();
      merged = _ranker.rankAndSortResults(merged, normalized);

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
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for videos: "$query"');
      return cached;
    }

    try {
      if (_typesenseEngine.isEnabled) {
        final tsResults = await _typesenseEngine.searchVideos(normalized);
        if (tsResults.isNotEmpty) {
          _cache.put(cacheKey, tsResults);
          return tsResults;
        }
      }

      final results = await _entityEngine.searchVideos(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchVideos');
      return [];
    }
  }

  /// 🎙️ CHANNEL SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchChannels(String query) async {
    if (query.isEmpty) return [];

    final normalized = query.toLowerCase().trim();
    final cacheKey = 'channels:$normalized';

    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for channels: "$query"');
      return cached;
    }

    try {
      if (_typesenseEngine.isEnabled) {
        final tsResults = await _typesenseEngine.searchChannels(normalized);
        if (tsResults.isNotEmpty) {
          _cache.put(cacheKey, tsResults);
          return tsResults;
        }
      }

      final results = await _entityEngine.searchChannels(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchChannels');
      return [];
    }
  }

  /// 📂 PLAYLIST SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchPlaylists(String query) async {
    if (query.isEmpty) return [];

    final normalized = query.toLowerCase().trim();
    final cacheKey = 'playlists:$normalized';

    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for playlists: "$query"');
      return cached;
    }

    try {
      final results = await _entityEngine.searchPlaylists(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchPlaylists');
      return [];
    }
  }

  /// 🏷️ TOPIC SEARCH (PUBLIC API - for enhanced search)
  Future<List<SearchResult>> searchTopics(String query) async {
    final normalized = sanitizeQuery(query);
    if (normalized.isEmpty) return [];

    final cacheKey = 'topics:$normalized';
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('💾 [Search] Cache hit for topics: "$query"');
      return cached;
    }

    try {
      if (_typesenseEngine.isEnabled) {
        final tsResults = await _typesenseEngine.searchTopics(normalized);
        if (tsResults.isNotEmpty) {
          _cache.put(cacheKey, tsResults);
          return tsResults;
        }
      }

      final results = await _entityEngine.searchTopics(normalized);
      _cache.put(cacheKey, results);
      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.searchTopics');
      return [];
    }
  }

  /// Fetch recommended videos for empty search state
  Future<List<SearchResult>> getRecommended() =>
      _recommendationsEngine.getRecommended();

  /// Fetch recommended channels for empty search state
  Future<List<SearchResult>> getRecommendedChannels() =>
      _recommendationsEngine.getRecommendedChannels();

  /// Fetch recommended playlists for empty search state
  Future<List<SearchResult>> getRecommendedPlaylists() =>
      _recommendationsEngine.getRecommendedPlaylists();

  /// Fetch recommended topics for empty search state
  Future<List<SearchResult>> getRecommendedTopics() =>
      _recommendationsEngine.getRecommendedTopics();

  /// Fetch balanced diverse mix of videos, channels, playlists, and topics for 'All' tab
  Future<List<SearchResult>> getRecommendedAll() =>
      _recommendationsEngine.getRecommendedAll();

  /// Fetch recommended content based on the active filter chip
  Future<List<SearchResult>> getRecommendedForFilter(
    String filter, {
    Set<String>? watchedVideoIds,
  }) =>
      _recommendationsEngine.getRecommendedForFilter(
        filter,
        watchedVideoIds: watchedVideoIds,
      );

  /// Fetch trending search queries from Firestore
  Future<List<String>> getTrendingSuggestions() =>
      _recommendationsEngine.getTrendingSuggestions();

  /// Clear cache manually
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️ [Search] Cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() => _cache.getStats();

  /// Check if a query is cached
  bool isCached(String query) => _cache.isCached(query);

  /// Warmup cache with trending searches
  Future<void> warmupCache(List<String> trendingQueries) async {
    debugPrint(
      '🔥 [Search] Warming up cache with ${trendingQueries.length} trending searches',
    );

    for (final query in trendingQueries) {
      if (_cache.isCached(query)) continue;

      try {
        final results = await search(query);
        debugPrint(
          '✅ [Search] Warmed up: "$query" (${results.length} results)',
        );
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'SearchService.warmupCache');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('✅ [Search] Cache warmup complete');
  }
}
