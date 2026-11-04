import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/engine/search_sanitizer.dart';
import 'package:typesense/typesense.dart';

/// Instant, typo-tolerant search engine powered by Typesense.
/// Provides sub-30ms search-as-you-type with multi-field weighted ranking.
class TypesenseSearchEngine {
  TypesenseSearchEngine({Client? client}) : _customClient = client;

  final Client? _customClient;
  Client? _cachedClient;

  Client get _client {
    final custom = _customClient;
    if (custom != null) return custom;
    if (_cachedClient != null) return _cachedClient!;

    final protocol = AppConfig.typesenseProtocol.toLowerCase() == 'http'
        ? Protocol.http
        : Protocol.https;

    final node = Node(
      protocol,
      AppConfig.typesenseHost,
      port: AppConfig.typesensePort,
    );

    final config = Configuration(
      AppConfig.typesenseSearchKey,
      nodes: {node},
      connectionTimeout: const Duration(seconds: 2),
      numRetries: 1,
      cachedSearchResultsTTL: const Duration(minutes: 5),
    );

    _cachedClient = Client(config);
    return _cachedClient!;
  }

  /// Whether Typesense search is globally enabled via AppConfig
  bool get isEnabled => AppConfig.enableTypesenseSearch;

  /// Combined federated search across videos, channels, and topics
  Future<List<SearchResult>> searchCombined(
    String query, {
    String? filter,
    int limit = 20,
  }) async {
    if (!isEnabled) return [];
    final cleanQuery = SearchSanitizer.sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final activeFilter = filter ?? 'All';

    try {
      final searches = <Map<String, dynamic>>[];

      // 1. Video Search Query
      if (activeFilter == 'All' || activeFilter == 'Videos' || activeFilter == 'Recently uploaded') {
        final videoParams = <String, dynamic>{
          'collection': 'videos',
          'q': cleanQuery,
          'query_by': 'title,channelName,tags,topics,description',
          'query_by_weights': '4,3,2,2,1',
          'per_page': limit,
          'num_typos': 2,
          'prefix': true,
        };

        if (activeFilter == 'Recently uploaded') {
          videoParams['sort_by'] = 'createdAt:desc';
        }

        searches.add(videoParams);
      }

      // 2. Channel Search Query
      if (activeFilter == 'All' || activeFilter == 'Channels' || cleanQuery.startsWith('@')) {
        searches.add({
          'collection': 'channels',
          'q': cleanQuery.replaceFirst('@', ''),
          'query_by': 'channelName,handle',
          'query_by_weights': '3,4',
          'per_page': activeFilter == 'Channels' ? limit : 3,
          'num_typos': 1,
          'prefix': true,
        });
      }

      // 3. Topic Search Query
      if (activeFilter == 'All' || activeFilter == 'Topics') {
        searches.add({
          'collection': 'topics',
          'q': cleanQuery,
          'query_by': 'title,slug',
          'query_by_weights': '4,3',
          'per_page': activeFilter == 'Topics' ? limit : 4,
          'num_typos': 1,
          'prefix': true,
        });
      }

      if (searches.isEmpty) return [];

      final multiSearchResult = await _client.multiSearch.perform({
        'searches': searches,
      });

      final results = <SearchResult>[];
      final rawResults = multiSearchResult['results'] as List<dynamic>? ?? [];

      for (final res in rawResults) {
        if (res is! Map<String, dynamic>) continue;
        final hits = res['hits'] as List<dynamic>? ?? [];

        for (final hit in hits) {
          if (hit is! Map<String, dynamic>) continue;
          final doc = hit['document'] as Map<String, dynamic>?;
          if (doc == null) continue;

          final item = _mapDocToSearchResult(doc, res['request_params']?['collection_name']);
          if (item != null && item.isValid) {
            results.add(item);
          }
        }
      }

      // Channel exact matches bubble to top, followed by videos sorted by relevance
      results.sort((a, b) {
        if (a.type == ResultType.channel && b.type != ResultType.channel) {
          if (cleanQuery.startsWith('@') || a.title.toLowerCase().contains(cleanQuery.toLowerCase())) {
            return -1;
          }
        }
        if (b.type == ResultType.channel && a.type != ResultType.channel) {
          if (cleanQuery.startsWith('@') || b.title.toLowerCase().contains(cleanQuery.toLowerCase())) {
            return 1;
          }
        }
        return b.relevanceScore.compareTo(a.relevanceScore);
      });

      return results.take(limit).toList();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TypesenseSearchEngine.searchCombined',
      );
      return [];
    }
  }

  /// Search videos specifically with instant typo tolerance
  Future<List<SearchResult>> searchVideos(
    String query, {
    int limit = 20,
    String? category,
    String? language,
  }) async {
    if (!isEnabled) return [];
    final cleanQuery = SearchSanitizer.sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    try {
      final searchParams = <String, dynamic>{
        'q': cleanQuery,
        'query_by': 'title,channelName,tags,topics,description',
        'query_by_weights': '4,3,2,2,1',
        'per_page': limit.toString(),
        'num_typos': '2',
        'prefix': 'true',
      };

      final filterClauses = <String>[];
      if (category != null && category.isNotEmpty) {
        filterClauses.add('category:=$category');
      }
      if (language != null && language.isNotEmpty) {
        filterClauses.add('language:=$language');
      }

      if (filterClauses.isNotEmpty) {
        searchParams['filter_by'] = filterClauses.join(' && ');
      }

      final resp = await _client
          .collection('videos')
          .documents
          .search(searchParams);

      final hits = resp['hits'] as List<dynamic>? ?? [];
      final results = <SearchResult>[];

      for (final hit in hits) {
        if (hit is! Map<String, dynamic>) continue;
        final doc = hit['document'] as Map<String, dynamic>?;
        if (doc == null) continue;

        final item = _mapDocToSearchResult(doc, 'videos');
        if (item != null && item.isValid) {
          results.add(item);
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TypesenseSearchEngine.searchVideos',
      );
      return [];
    }
  }

  /// Search channels specifically
  Future<List<SearchResult>> searchChannels(
    String query, {
    int limit = 20,
  }) async {
    if (!isEnabled) return [];
    final cleanQuery = query.replaceFirst('@', '').trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final resp = await _client.collection('channels').documents.search({
        'q': cleanQuery,
        'query_by': 'channelName,handle',
        'query_by_weights': '3,4',
        'per_page': limit.toString(),
        'num_typos': '1',
        'prefix': 'true',
      });

      final hits = resp['hits'] as List<dynamic>? ?? [];
      final results = <SearchResult>[];

      for (final hit in hits) {
        if (hit is! Map<String, dynamic>) continue;
        final doc = hit['document'] as Map<String, dynamic>?;
        if (doc == null) continue;

        final item = _mapDocToSearchResult(doc, 'channels');
        if (item != null && item.isValid) {
          results.add(item);
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TypesenseSearchEngine.searchChannels',
      );
      return [];
    }
  }

  /// Search topics specifically
  Future<List<SearchResult>> searchTopics(
    String query, {
    int limit = 20,
  }) async {
    if (!isEnabled) return [];
    final cleanQuery = SearchSanitizer.sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    try {
      final resp = await _client.collection('topics').documents.search({
        'q': cleanQuery,
        'query_by': 'title,slug',
        'query_by_weights': '4,3',
        'per_page': limit.toString(),
        'num_typos': '1',
        'prefix': 'true',
      });

      final hits = resp['hits'] as List<dynamic>? ?? [];
      final results = <SearchResult>[];

      for (final hit in hits) {
        if (hit is! Map<String, dynamic>) continue;
        final doc = hit['document'] as Map<String, dynamic>?;
        if (doc == null) continue;

        final item = _mapDocToSearchResult(doc, 'topics');
        if (item != null && item.isValid) {
          results.add(item);
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TypesenseSearchEngine.searchTopics',
      );
      return [];
    }
  }

  /// Maps a raw Typesense document payload into a strongly-typed SearchResult
  SearchResult? _mapDocToSearchResult(
    Map<String, dynamic> doc,
    dynamic collectionName,
  ) {
    try {
      final id = doc['id']?.toString() ?? '';
      if (id.isEmpty) return null;

      final coll = collectionName?.toString() ?? 'videos';

      if (coll == 'channels') {
        final rawHandle = doc['handle']?.toString() ?? '';
        final handle = rawHandle.startsWith('@') ? rawHandle : '@$rawHandle';
        final avatar = doc['avatarUrl']?.toString() ?? '';

        return SearchResult(
          id: id,
          title: doc['channelName']?.toString() ?? 'Channel',
          thumbnail: avatar,
          views: (doc['subscriberCount'] as num?)?.toInt() ?? 0,
          channelName: handle.isNotEmpty ? handle : (doc['channelName']?.toString() ?? 'Channel'),
          channelImage: avatar,
          createdAt: Timestamp.fromMillisecondsSinceEpoch(
            (doc['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          ),
          type: ResultType.channel,
          category: doc['category']?.toString(),
          isTrusted: doc['isTrusted'] == true,
          relevanceScore: 80.0,
        );
      }

      if (coll == 'topics') {
        final slug = doc['slug']?.toString() ?? id;
        final thumb = doc['thumbnailUrl']?.toString() ?? '';

        return SearchResult(
          id: id,
          title: doc['title']?.toString() ?? 'Topic',
          thumbnail: thumb,
          views: (doc['videoCount'] as num?)?.toInt() ?? 0,
          channelName: 'T/$slug',
          channelImage: thumb,
          createdAt: Timestamp.fromMillisecondsSinceEpoch(
            (doc['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          ),
          type: ResultType.topic,
          category: doc['category']?.toString(),
          relevanceScore: 50.0,
        );
      }

      // Default: Video Document
      final thumb = doc['thumbnailUrl']?.toString() ?? '';
      final chImg = doc['channelImage']?.toString() ?? '';

      return SearchResult(
        id: id,
        title: doc['title']?.toString() ?? 'Untitled',
        thumbnail: thumb,
        views: (doc['views'] as num?)?.toInt() ?? 0,
        channelName: doc['channelName']?.toString() ?? 'Unknown',
        channelImage: chImg,
        createdAt: Timestamp.fromMillisecondsSinceEpoch(
          (doc['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
        durationMs: (doc['durationMs'] as num?)?.toInt(),
        language: doc['language']?.toString(),
        category: doc['category']?.toString(),
        visibility: doc['visibility']?.toString() ?? 'public',
        isFactChecked: doc['isFactChecked'] == true,
        trustScore: (doc['trustScore'] as num?)?.toDouble() ?? 0.0,
        isTrusted: doc['isTrusted'] == true,
        relevanceScore: 70.0,
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TypesenseSearchEngine._mapDocToSearchResult',
      );
      return null;
    }
  }
}
