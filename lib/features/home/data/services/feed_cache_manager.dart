import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Structured cache metadata container
class CacheMetadata {
  CacheMetadata({
    required this.cacheType,
    required this.generatedAt,
    required this.expiresAt,
    this.schemaVersion = 2,
    this.feedVersion = 1,
    this.queryHash = '',
  });

  factory CacheMetadata.fromMap(Map<String, dynamic> map) {
    return CacheMetadata(
      schemaVersion: map['schemaVersion'] ?? 2,
      cacheType: map['cacheType'] ?? 'unknown',
      generatedAt: map['generatedAt'] ?? 0,
      expiresAt: map['expiresAt'] ?? 0,
      feedVersion: map['feedVersion'] ?? 1,
      queryHash: map['queryHash'] ?? '',
    );
  }
  final int schemaVersion;
  final String cacheType;
  final int generatedAt;
  final int expiresAt;
  final int feedVersion;
  final String queryHash;

  /// Whether the cache has passed its initial freshness window and should be revalidated in background.
  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  /// Stale status for Stale-While-Revalidate caching pattern
  bool get isStale => isExpired;

  /// Whether the cache is older than the absolute maximum stale retention limit (e.g. 7 days).
  bool isPermanentlyExpired([Duration maxRetention = const Duration(days: 7)]) =>
      DateTime.now().millisecondsSinceEpoch >
      (generatedAt + maxRetention.inMilliseconds);

  Map<String, dynamic> toMap() => {
    'schemaVersion': schemaVersion,
    'cacheType': cacheType,
    'generatedAt': generatedAt,
    'expiresAt': expiresAt,
    'feedVersion': feedVersion,
    'queryHash': queryHash,
  };
}

/// Decoupled cache manager for managing scoped feeds, TTL versioning, and sanitization.
class FeedCacheManager {
  FeedCacheManager([GetStorage? storage]) : _storage = storage ?? GetStorage();
  final GetStorage _storage;
  static const int currentSchemaVersion = 3;
  static const Duration defaultTTL = Duration(minutes: 3);

  /// Maximum duration to retain cached feed for instant first-frame painting (Stale-While-Revalidate).
  /// Retains previously fetched feeds for 7 days so users always experience sub-50ms instant launches.
  static const Duration maxStaleRetention = Duration(days: 7);

  // Scoped Cache Key Constants
  static const String keyHomeFeed = 'feed_home';
  static const String keyUnexploredFeed = 'feed_unexplored';
  static const String keyTrendingFeed = 'feed_trending';
  static const String keyPopularFeed = 'feed_popular';
  static const String keyNewFeed = 'feed_new';
  static const String keyFlipCoinFeed = 'feed_flip_coin';
  static const String keyMusicFeed = 'feed_music';

  /// Resolve a normalized cache key for any category or home tab, scoped by userId.
  static String cacheKeyForCategory(String category, {String? userId}) {
    final cat = category.trim();
    final userSuffix = (userId != null && userId.isNotEmpty) ? '_$userId' : '';
    String baseKey;
    if (cat.isEmpty || cat == 'All') {
      baseKey = keyHomeFeed;
    } else if (cat == 'Unexplored' || cat == '🧭 Unexplored') {
      baseKey = keyUnexploredFeed;
    } else if (cat == '🔥 Trending' || cat == 'Trending') {
      baseKey = keyTrendingFeed;
    } else if (cat == '⭐ Popular' || cat == 'Popular') {
      baseKey = keyPopularFeed;
    } else if (cat == '✨ New' || cat == 'New') {
      baseKey = keyNewFeed;
    } else if (cat == 'Flip Coin' || cat == '🪙 Flip Coin') {
      baseKey = keyFlipCoinFeed;
    } else if (cat == 'Music') {
      baseKey = keyMusicFeed;
    } else {
      baseKey = 'feed_cat_${cat.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_')}';
    }
    return '$baseKey$userSuffix';
  }

  /// Retrieve valid and sanitized videos from local storage for a given cache key.
  /// Defaults to Stale-While-Revalidate ([allowStale] = true) to guarantee instant,
  /// zero-latency first-frame painting while background revalidation occurs.
  List<Video>? getValidCachedVideos(
    String cacheKey, {
    Duration ttl = defaultTTL,
    List<String>? blockedChannelIds,
    bool allowStale = true,
  }) {
    try {
      final rawData = _storage.read<Map>(cacheKey);
      if (rawData == null) return null;

      final cacheMap = Map<String, dynamic>.from(rawData);
      final metadataMap = cacheMap['metadata'];
      final videosListRaw = cacheMap['videos'];

      if (metadataMap == null ||
          videosListRaw == null ||
          videosListRaw is! List) {
        return null;
      }

      final metadata = CacheMetadata.fromMap(
        Map<String, dynamic>.from(metadataMap),
      );

      // Check schema version compatibility and hard retention limit (Stale-While-Revalidate)
      if (metadata.schemaVersion != currentSchemaVersion ||
          metadata.isPermanentlyExpired()) {
        debugPrint(
          '[FeedCacheManager] Cache for $cacheKey permanently expired or schema mismatch. Evicting.',
        );
        _storage.remove(cacheKey);
        return null;
      }

      if (!allowStale && metadata.isStale) {
        return null;
      }

      final rawVideos = videosListRaw
          .map((data) => Video.fromMap(Map<String, dynamic>.from(data)))
          .toList();

      // Pass through VideoSanitizer to ensure deleted/pending items are excluded
      var sanitized = VideoSanitizer.sanitizeForFeed(
        rawVideos,
        blockedChannelIds: blockedChannelIds,
      );

      if (sanitized.isEmpty && rawVideos.isNotEmpty) {
        final seenFallback = <String>{};
        sanitized = rawVideos
            .where((v) =>
                v.id.isNotEmpty &&
                seenFallback.add(v.id) &&
                !v.isDraft &&
                v.status != VideoStatus.deleted &&
                v.status != VideoStatus.rejected &&
                VideoVisibilityPolicy.hasPlayableMedia(v))
            .toList();
      }

      debugPrint(
        '[FeedCacheManager] Loaded ${sanitized.length} valid cached videos for $cacheKey (isStale: ${metadata.isStale})',
      );
      return sanitized;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedCacheManager.loadFeedFromCache',
      );
      return null;
    }
  }

  /// Persist feed videos to local storage with metadata header and TTL
  void saveFeedToCache(
    String cacheKey,
    List<Video> videos, {
    Duration ttl = defaultTTL,
    int maxItems = 24,
    String cacheType = 'home_feed',
  }) {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final expiresMs = nowMs + ttl.inMilliseconds;

      final metadata = CacheMetadata(
        schemaVersion: currentSchemaVersion,
        cacheType: cacheType,
        generatedAt: nowMs,
        expiresAt: expiresMs,
      );

      final sanitizedVideos = VideoSanitizer.sanitizeForFeed(
        videos,
      ).take(maxItems).toList();

      var targetVideos = sanitizedVideos;
      if (targetVideos.isEmpty && videos.isNotEmpty) {
        final seenTarget = <String>{};
        targetVideos = videos
            .where((v) =>
                v.id.isNotEmpty &&
                seenTarget.add(v.id) &&
                !v.isDraft &&
                v.status != VideoStatus.deleted &&
                v.status != VideoStatus.rejected &&
                VideoVisibilityPolicy.hasPlayableMedia(v))
            .take(maxItems)
            .toList();
      }

      if (targetVideos.isEmpty) {
        debugPrint(
          '[FeedCacheManager] No valid videos to cache for key: $cacheKey. Skipping save.',
        );
        return;
      }

      final serializedVideos = targetVideos.map((v) => v.toMap()).toList();

      final cacheData = {
        'metadata': metadata.toMap(),
        'videos': serializedVideos,
      };

      _storage.write(cacheKey, cacheData);
      debugPrint(
        '[FeedCacheManager] Saved ${targetVideos.length} videos to cache key: $cacheKey',
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedCacheManager.saveFeedToCache',
      );
    }
  }

  /// Manually evict cache key
  void invalidate(String cacheKey) {
    _storage.remove(cacheKey);
  }

  /// Evict cache for a specific category and user
  void invalidateCategory(String category, {String? userId}) {
    final key = cacheKeyForCategory(category, userId: userId);
    _storage.remove(key);
  }

  /// Update an existing video's view count and metadata across all cached feeds.
  void updateCachedVideo(Video updatedVideo) {
    if (updatedVideo.id.isEmpty) return;

    final targetKeys = <String>{
      keyHomeFeed,
      keyUnexploredFeed,
      keyTrendingFeed,
      keyPopularFeed,
      keyNewFeed,
      keyFlipCoinFeed,
      keyMusicFeed,
    };

    try {
      final allKeys = _storage.getKeys();
      for (final k in allKeys) {
        if (k is String && k.startsWith('feed_')) {
          targetKeys.add(k);
        }
      }
    } catch (_) {
      // In case getKeys throws or is unsupported in test/mock environment
    }

    for (final cacheKey in targetKeys) {
      _updateVideoInCacheKey(cacheKey, updatedVideo);
    }
  }

  void _updateVideoInCacheKey(String cacheKey, Video updatedVideo) {
    try {
      final rawData = _storage.read<Map>(cacheKey);
      if (rawData == null) return;

      final cacheMap = Map<String, dynamic>.from(rawData);
      final videosListRaw = cacheMap['videos'];
      if (videosListRaw is! List) return;

      var updated = false;
      final newVideosList = <Map<String, dynamic>>[];
      for (final item in videosListRaw) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap['id'] == updatedVideo.id) {
            final oldViews = (itemMap['views'] as num?)?.toInt() ??
                (itemMap['viewCount'] as num?)?.toInt() ??
                0;
            final targetViews =
                updatedVideo.views > oldViews ? updatedVideo.views : oldViews;
            itemMap['views'] = targetViews;
            itemMap['viewCount'] = targetViews;
            newVideosList.add(itemMap);
            updated = true;
          } else {
            newVideosList.add(itemMap);
          }
        }
      }

      if (updated) {
        cacheMap['videos'] = newVideosList;
        _storage.write(cacheKey, cacheMap);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedCacheManager.updateCachedVideo',
      );
    }
  }
}

