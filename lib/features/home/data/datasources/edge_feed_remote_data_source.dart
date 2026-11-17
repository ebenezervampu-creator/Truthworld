import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Exception thrown when Edge Feed request fails.
class EdgeFeedException implements Exception {
  final String message;
  final int? statusCode;

  EdgeFeedException(this.message, {this.statusCode});

  @override
  String toString() => 'EdgeFeedException: $message (status: $statusCode)';
}

/// Structured response container from Edge Feed Delivery CDN
class EdgeFeedResponse {
  final List<VideoEntity> videos;
  final String? nextCursor;
  final bool hasMore;
  final bool isNotModified;
  final String? eTag;

  EdgeFeedResponse({
    required this.videos,
    this.nextCursor,
    this.hasMore = false,
    this.isNotModified = false,
    this.eTag,
  });
}

/// High-speed remote data source backed by Firebase Hosting / CDN edge caching.
class EdgeFeedRemoteDataSource {
  final http.Client _client;
  final FeedCacheManager _cacheManager;
  final String _baseUrl;

  EdgeFeedRemoteDataSource({
    http.Client? client,
    FeedCacheManager? cacheManager,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _cacheManager = cacheManager ?? FeedCacheManager(),
        _baseUrl = baseUrl ?? (kIsWeb ? '' : 'https://www.truthworld.in');

  /// Fetch feed from CDN edge with RFC 9110 conditional revalidation.
  Future<EdgeFeedResponse> fetchFeed({
    String feedType = 'home',
    String? category,
    String? lang,
    int limit = 24,
    String? cursor,
    String? userId,
  }) async {
    final catKey = (category != null && category.isNotEmpty) ? category : 'All';
    final normalizedFeedKey = FeedCacheManager.cacheKeyForCategory(catKey, userId: userId);

    // Retrieve local cache and ETag if present
    final cachedVideos = _cacheManager.getValidCachedVideos(normalizedFeedKey);
    final storedETag = _cacheManager.getETag(normalizedFeedKey);

    // Build URL query parameters
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (category != null && category.isNotEmpty && category != 'All') {
      queryParams['category'] = category.trim().toLowerCase();
    }
    if (lang != null && lang.isNotEmpty && lang != 'all') {
      queryParams['lang'] = lang.trim().toLowerCase();
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor.trim();
    }

    final String path;
    if (feedType == 'trending') {
      path = '/api/feed/trending';
    } else if (feedType == 'explore') {
      path = '/api/feed/explore';
    } else {
      path = '/api/feed';
    }
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);

    // Header Hygiene: Strictly strip all authentication, user cookies, and tokens
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    // CRITICAL: Send If-None-Match ONLY if local cached body exists
    if (storedETag != null && storedETag.isNotEmpty && cachedVideos != null && cachedVideos.isNotEmpty) {
      headers['If-None-Match'] = storedETag;
    }

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 3));

      // Handle 304 Not Modified: Reuse local cache with 0ms network deserialization
      if (response.statusCode == 304) {
        if (cachedVideos != null && cachedVideos.isNotEmpty) {
          debugPrint('[EdgeFeedRemoteDataSource] 304 Not Modified. Reusing local feed.');
          final nextCursor = _cacheManager.getNextCursor(normalizedFeedKey);
          return EdgeFeedResponse(
            videos: cachedVideos.map((v) => v.toEntity()).toList(),
            nextCursor: nextCursor,
            hasMore: true,
            isNotModified: true,
            eTag: storedETag,
          );
        }
      }

      // Handle 200 OK: Parse, persist to FeedCacheManager, and return
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> feedList = jsonBody['feed'] ?? [];
        final String? nextCursor = jsonBody['nextCursor'];
        final bool hasMore = jsonBody['hasMore'] ?? false;
        final responseETag = response.headers['etag'];

        final List<Video> parsedVideos = feedList
            .map((item) => Video.fromMap(Map<String, dynamic>.from(item)))
            .toList();

        // Persist to FeedCacheManager for instant future first-frame painting
        if (cursor == null && parsedVideos.isNotEmpty) {
          _cacheManager.saveFeedToCache(
            normalizedFeedKey,
            parsedVideos,
            eTag: responseETag,
            nextCursor: nextCursor,
            cacheType: feedType,
          );
        }

        return EdgeFeedResponse(
          videos: parsedVideos.map((v) => v.toEntity()).toList(),
          nextCursor: nextCursor,
          hasMore: hasMore,
          isNotModified: false,
          eTag: responseETag,
        );
      }

      throw EdgeFeedException(
        'Edge feed returned unexpected status code',
        statusCode: response.statusCode,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'EdgeFeedRemoteDataSource.fetchFeed',
      );
      rethrow;
    }
  }

  /// Fetch high-diversity explore feed with category interleaving
  Future<EdgeFeedResponse> fetchExploreFeed({
    String? category,
    String? lang,
    int limit = 24,
    String? cursor,
    String? userId,
  }) async {
    return fetchFeed(
      feedType: 'explore',
      category: category,
      lang: lang,
      limit: limit,
      cursor: cursor,
      userId: userId,
    );
  }

  /// Fetch topic video feed from CDN edge with local caching and ETag revalidation.
  Future<EdgeFeedResponse> fetchTopicFeed(
    String topicSlug, {
    String? lang,
    int limit = 12,
    String? cursor,
  }) async {
    final cleanTopic = topicSlug.trim().toLowerCase().replaceAll(RegExp(r'^t/'), '');
    final cacheKey = 'topic_$cleanTopic';
    final cachedVideos = _cacheManager.getValidCachedVideos(cacheKey);
    final storedETag = _cacheManager.getETag(cacheKey);

    final queryParams = <String, String>{
      'topic': cleanTopic,
      'limit': limit.toString(),
    };
    if (lang != null && lang.isNotEmpty && lang != 'all') {
      queryParams['lang'] = lang.trim().toLowerCase();
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor.trim();
    }

    final uri = Uri.parse('$_baseUrl/api/feed').replace(queryParameters: queryParams);
    final headers = <String, String>{'Accept': 'application/json'};
    if (storedETag != null && storedETag.isNotEmpty && cachedVideos != null && cachedVideos.isNotEmpty) {
      headers['If-None-Match'] = storedETag;
    }

    try {
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 3));

      if (response.statusCode == 304 && cachedVideos != null && cachedVideos.isNotEmpty) {
        final nextCursor = _cacheManager.getNextCursor(cacheKey);
        return EdgeFeedResponse(
          videos: cachedVideos.map((v) => v.toEntity()).toList(),
          nextCursor: nextCursor,
          hasMore: true,
          isNotModified: true,
          eTag: storedETag,
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> feedList = jsonBody['feed'] ?? [];
        final String? nextCursor = jsonBody['nextCursor'];
        final bool hasMore = jsonBody['hasMore'] ?? false;
        final responseETag = response.headers['etag'];

        final List<Video> parsedVideos = feedList
            .map((item) => Video.fromMap(Map<String, dynamic>.from(item)))
            .toList();

        if (cursor == null && parsedVideos.isNotEmpty) {
          _cacheManager.saveFeedToCache(
            cacheKey,
            parsedVideos,
            eTag: responseETag,
            nextCursor: nextCursor,
            cacheType: 'topic',
          );
        }

        return EdgeFeedResponse(
          videos: parsedVideos.map((v) => v.toEntity()).toList(),
          nextCursor: nextCursor,
          hasMore: hasMore,
          isNotModified: false,
          eTag: responseETag,
        );
      }

      throw EdgeFeedException(
        'Edge topic feed returned unexpected status code',
        statusCode: response.statusCode,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'EdgeFeedRemoteDataSource.fetchTopicFeed');
      rethrow;
    }
  }

  /// Fetch creator channel public uploads from CDN edge with local caching and ETag revalidation.
  Future<EdgeFeedResponse> fetchChannelFeed(
    String channelId, {
    int limit = 12,
    String? cursor,
  }) async {
    final cleanId = channelId.trim();
    final cacheKey = 'channel_$cleanId';
    final cachedVideos = _cacheManager.getValidCachedVideos(cacheKey);
    final storedETag = _cacheManager.getETag(cacheKey);

    final queryParams = <String, String>{
      'channelId': cleanId,
      'limit': limit.toString(),
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor.trim();
    }

    final uri = Uri.parse('$_baseUrl/api/feed').replace(queryParameters: queryParams);
    final headers = <String, String>{'Accept': 'application/json'};
    if (storedETag != null && storedETag.isNotEmpty && cachedVideos != null && cachedVideos.isNotEmpty) {
      headers['If-None-Match'] = storedETag;
    }

    try {
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 3));

      if (response.statusCode == 304 && cachedVideos != null && cachedVideos.isNotEmpty) {
        final nextCursor = _cacheManager.getNextCursor(cacheKey);
        return EdgeFeedResponse(
          videos: cachedVideos.map((v) => v.toEntity()).toList(),
          nextCursor: nextCursor,
          hasMore: true,
          isNotModified: true,
          eTag: storedETag,
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> feedList = jsonBody['feed'] ?? [];
        final String? nextCursor = jsonBody['nextCursor'];
        final bool hasMore = jsonBody['hasMore'] ?? false;
        final responseETag = response.headers['etag'];

        final List<Video> parsedVideos = feedList
            .map((item) => Video.fromMap(Map<String, dynamic>.from(item)))
            .toList();

        if (cursor == null && parsedVideos.isNotEmpty) {
          _cacheManager.saveFeedToCache(
            cacheKey,
            parsedVideos,
            eTag: responseETag,
            nextCursor: nextCursor,
            cacheType: 'channel',
          );
        }

        return EdgeFeedResponse(
          videos: parsedVideos.map((v) => v.toEntity()).toList(),
          nextCursor: nextCursor,
          hasMore: hasMore,
          isNotModified: false,
          eTag: responseETag,
        );
      }

      throw EdgeFeedException(
        'Edge channel feed returned unexpected status code',
        statusCode: response.statusCode,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'EdgeFeedRemoteDataSource.fetchChannelFeed');
      rethrow;
    }
  }

  /// Fetch featured and trending topics directory from edge discovery API.
  Future<List<Topic>> fetchDiscoveryTopics({
    String category = 'all',
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'category': category.toLowerCase().trim(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse('$_baseUrl/api/discovery/topics').replace(queryParameters: queryParams);
    final headers = <String, String>{'Accept': 'application/json'};

    try {
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> list = jsonBody['topics'] ?? [];
        return list
            .map((item) => Topic.fromMap(Map<String, dynamic>.from(item), docId: item['id'] ?? ''))
            .toList();
      }
      throw EdgeFeedException(
        'Discovery topics returned unexpected status code',
        statusCode: response.statusCode,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'EdgeFeedRemoteDataSource.fetchDiscoveryTopics');
      rethrow;
    }
  }

  /// Fetch top creators / leaderboard from edge discovery API.
  Future<List<Channel>> fetchDiscoveryChannels({
    String category = 'all',
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'category': category.toLowerCase().trim(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse('$_baseUrl/api/discovery/channels').replace(queryParameters: queryParams);
    final headers = <String, String>{'Accept': 'application/json'};

    try {
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> list = jsonBody['channels'] ?? [];
        return list
            .map((item) => Channel.fromMap(Map<String, dynamic>.from(item), item['id'] ?? ''))
            .toList();
      }
      throw EdgeFeedException(
        'Discovery channels returned unexpected status code',
        statusCode: response.statusCode,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'EdgeFeedRemoteDataSource.fetchDiscoveryChannels');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}
