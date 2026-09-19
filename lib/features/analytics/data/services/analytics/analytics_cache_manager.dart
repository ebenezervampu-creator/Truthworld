import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';

/// Cached wrapper for video analytics snapshot with creation timestamp.
class CachedVideoAnalytics {
  CachedVideoAnalytics({
    required this.snapshot,
    required this.createdAt,
  });

  final VideoAnalyticsSnapshot snapshot;
  final DateTime createdAt;
}

/// In-memory cache manager for video analytics snapshots with TTL expiration.
class AnalyticsCacheManager {
  AnalyticsCacheManager({int cacheExpiryMinutes = 15})
      : _cacheExpiryMinutes = cacheExpiryMinutes;

  final int _cacheExpiryMinutes;
  final Map<String, CachedVideoAnalytics> _cache = {};

  /// Retrieves a valid cached snapshot, or null if expired or missing.
  VideoAnalyticsSnapshot? get(String key) {
    final cached = _cache[key];
    if (cached == null) return null;

    final age = DateTime.now().difference(cached.createdAt).inMinutes;
    if (age < _cacheExpiryMinutes) {
      return cached.snapshot;
    }

    _cache.remove(key);
    return null;
  }

  /// Puts a snapshot into the cache with the current timestamp.
  void put(String key, VideoAnalyticsSnapshot snapshot) {
    _cache[key] = CachedVideoAnalytics(
      snapshot: snapshot,
      createdAt: DateTime.now(),
    );
  }

  /// Invalidates all cache entries for a specific video.
  void invalidateVideo(String videoId) {
    _cache.removeWhere((key, _) => key.startsWith(videoId));
  }

  /// Clears the entire analytics cache.
  void clear() {
    _cache.clear();
    logger.info('Analytics cache cleared', tag: 'AnalyticsCacheManager');
  }

  /// Expiry duration in minutes.
  int get cacheExpiryMinutes => _cacheExpiryMinutes;
}
