import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Structured cache metadata container
class CacheMetadata {

  CacheMetadata({
    required this.cacheType, required this.generatedAt, required this.expiresAt, this.schemaVersion = 2,
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

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

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
  static const int currentSchemaVersion = 2;
  static const Duration defaultTTL = Duration(minutes: 15);

  // Scoped Cache Key Constants
  static const String keyHomeFeed = 'feed_home';
  static const String keyTrendingFeed = 'feed_trending';
  static const String keyMusicFeed = 'feed_music';

  /// Retrieve valid, non-expired, and sanitized videos from local storage for a given cache key.
  List<Video>? getValidCachedVideos(
    String cacheKey, {
    Duration ttl = defaultTTL,
    List<String>? blockedChannelIds,
  }) {
    try {
      final rawData = _storage.read<Map>(cacheKey);
      if (rawData == null) return null;

      final cacheMap = Map<String, dynamic>.from(rawData);
      final metadataMap = cacheMap['metadata'];
      final videosListRaw = cacheMap['videos'];

      if (metadataMap == null || videosListRaw == null || videosListRaw is! List) {
        return null;
      }

      final metadata = CacheMetadata.fromMap(Map<String, dynamic>.from(metadataMap));

      // Check schema version compatibility and TTL expiration
      if (metadata.schemaVersion != currentSchemaVersion || metadata.isExpired) {
        debugPrint('[FeedCacheManager] Cache for $cacheKey expired or schema mismatch. Evicting.');
        _storage.remove(cacheKey);
        return null;
      }

      final rawVideos = videosListRaw
          .map((data) => Video.fromMap(Map<String, dynamic>.from(data)))
          .toList();

      // Pass through VideoSanitizer to ensure deleted/pending items are excluded
      final sanitized = VideoSanitizer.sanitizeForFeed(
        rawVideos,
        blockedChannelIds: blockedChannelIds,
      );

      debugPrint('[FeedCacheManager] Loaded ${sanitized.length} valid cached videos for $cacheKey');
      return sanitized;
    } catch (e) {
      debugPrint('[FeedCacheManager] Error loading cache for $cacheKey: $e');
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
        cacheType: cacheType,
        generatedAt: nowMs,
        expiresAt: expiresMs,
      );

      final sanitizedVideos = VideoSanitizer.sanitizeForFeed(videos).take(maxItems).toList();
      final serializedVideos = sanitizedVideos.map((v) => v.toMap()).toList();

      final cacheData = {
        'metadata': metadata.toMap(),
        'videos': serializedVideos,
      };

      _storage.write(cacheKey, cacheData);
      debugPrint('[FeedCacheManager] Saved ${sanitizedVideos.length} videos to cache key: $cacheKey');
    } catch (e) {
      debugPrint('[FeedCacheManager] Error saving cache for $cacheKey: $e');
    }
  }

  /// Manually evict cache key
  void invalidate(String cacheKey) {
    _storage.remove(cacheKey);
  }
}
