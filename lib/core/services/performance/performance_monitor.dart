import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Performance Monitoring Service
///
/// Tracks key performance metrics:
/// - Page load times
/// - Image loading duration
/// - API response times
/// - Cache hit rates
/// - Core Web Vitals (FCP, LCP, CLS)
class PerformanceMonitor {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Metric names
  static const String kPageLoadTime = 'page_load_time_ms';
  static const String kFirstContentfulPaint = 'fcp_ms';
  static const String kLargestContentfulPaint = 'lcp_ms';
  static const String kCumulativeLayoutShift = 'cls';

  static const String kImageLoadTime = 'image_load_ms';
  static const String kApiResponseTime = 'api_response_ms';
  static const String kFirestoreReadTime = 'firestore_read_ms';

  static const String kCacheHitRate = 'cache_hit_rate';
  static const String kCacheSize = 'cache_size_mb';
  static const String kOfflineHits = 'offline_hits';

  // State & Resource Metrics
  static int _activeControllers = 0;
  static int _activeWorkers = 0;
  static int _activeStreamSubscriptions = 0;
  static int _activeVideoDecoders = 0;

  static int get activeControllers => _activeControllers;
  static int get activeWorkers => _activeWorkers;
  static int get activeStreamSubscriptions => _activeStreamSubscriptions;
  static int get activeVideoDecoders => _activeVideoDecoders;

  // Cache tracking
  static int _totalRequests = 0;
  static int _cacheHits = 0;
  static int _offlineHits = 0;

  static void trackControllerInit(String controllerName) {
    _activeControllers++;
    if (kDebugMode) {
      logger.debug(
        'Active Controllers: $_activeControllers (+$controllerName)',
        tag: 'PERF',
      );
    }
  }

  static void trackControllerDispose(String controllerName) {
    if (_activeControllers > 0) _activeControllers--;
    if (kDebugMode) {
      logger.debug(
        'Active Controllers: $_activeControllers (-$controllerName)',
        tag: 'PERF',
      );
    }
  }

  static void updateResourceMetrics({
    int? activeWorkers,
    int? activeStreams,
    int? activeDecoders,
  }) {
    if (activeWorkers != null) _activeWorkers = activeWorkers;
    if (activeStreams != null) _activeStreamSubscriptions = activeStreams;
    if (activeDecoders != null) _activeVideoDecoders = activeDecoders;
  }

  /// Track page load from navigation start to first frame rendered
  static void trackPageLoad(String pageName) {
    if (kDebugMode) {
      logger.debug('Page load started: $pageName', tag: 'PERF');
    }

    final startTime = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      _sendMetric(kPageLoadTime, duration, {'page': pageName});

      if (kDebugMode) {
        logger.info('Page loaded: $pageName (${duration}ms)', tag: 'PERF');
      }
    });
  }

  /// Track image loading time
  static void trackImageLoad(
    String url,
    int durationMs, {
    bool cached = false,
  }) {
    _sendMetric(kImageLoadTime, durationMs, {
      'cached': cached ? 'true' : 'false',
      'url_domain': _extractDomain(url),
    });

    _recordCacheHit(cached);

    if (kDebugMode) {
      logger.debug(
        'Image loaded: $url (${durationMs}ms, cached: $cached)',
        tag: 'PERF',
      );
    }
  }

  /// Track API response time
  static void trackApiResponse(String endpoint, int durationMs) {
    _sendMetric(kApiResponseTime, durationMs, {'endpoint': endpoint});

    if (kDebugMode) {
      logger.debug('API response: $endpoint (${durationMs}ms)', tag: 'PERF');
    }
  }

  /// Track Firestore read operation
  static void trackFirestoreRead(String collection, int durationMs) {
    _sendMetric(kFirestoreReadTime, durationMs, {'collection': collection});

    if (kDebugMode) {
      logger.debug(
        'Firestore read: $collection (${durationMs}ms)',
        tag: 'PERF',
      );
    }
  }

  /// Track first contentful paint (FCP)
  /// Call this when main content is first painted
  static void trackFCP(int durationMs) {
    _sendMetric(kFirstContentfulPaint, durationMs);

    if (kDebugMode) {
      logger.debug('FCP: ${durationMs}ms', tag: 'PERF');
    }
  }

  /// Track largest contentful paint (LCP)
  /// Call when largest visible content is painted
  static void trackLCP(int durationMs) {
    _sendMetric(kLargestContentfulPaint, durationMs);

    if (kDebugMode) {
      logger.debug('LCP: ${durationMs}ms', tag: 'PERF');
    }
  }

  /// Track cumulative layout shift
  /// 0.0 is perfect, < 0.1 is good
  static void trackCLS(double clsValue) {
    _sendMetric(kCumulativeLayoutShift, clsValue.toInt());

    if (kDebugMode) {
      logger.debug('CLS: $clsValue', tag: 'PERF');
    }
  }

  /// Log cache statistics
  static void logCacheStats(int cacheSizeMb) {
    _sendMetric(kCacheSize, cacheSizeMb);

    final hitRate = _totalRequests > 0
        ? (_cacheHits / _totalRequests * 100).toStringAsFixed(2)
        : '0.00';

    if (kDebugMode) {
      logger.debug(
        'Cache stats:\n  Hit rate: $hitRate%\n  Offline hits: $_offlineHits\n  Cache size: ${cacheSizeMb}MB',
        tag: 'PERF',
      );
    }
  }

  /// Track error
  static void trackError(String errorName, String errorMessage) {
    _analytics.logEvent(
      name: 'error_occurred',
      parameters: {
        'error_name': errorName,
        'error_message': errorMessage,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (kDebugMode) {
      logger.error('Error: $errorName - $errorMessage', tag: 'PERF');
    }
  }

  /// Track user action
  static void trackUserAction(
    String actionName, {
    Map<String, String>? parameters,
  }) {
    _analytics.logEvent(name: actionName, parameters: parameters ?? {});

    if (kDebugMode) {
      logger.debug('User action: $actionName', tag: 'PERF');
    }
  }

  /// Internal: Send metric to Firebase
  static void _sendMetric(
    String name,
    int value, [
    Map<String, String>? dimensions,
  ]) {
    try {
      _analytics.logEvent(
        name: name,
        parameters: {
          ...?dimensions,
          'value': value,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      logger.error('Error sending metric: $e', tag: 'PERF');
    }
  }

  /// Internal: Record cache hit
  static void _recordCacheHit(bool hit) {
    _totalRequests++;
    if (hit) {
      _cacheHits++;
    }
  }

  /// Internal: Extract domain from URL
  static String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return 'unknown';
    }
  }

  /// Reset statistics
  static void resetStats() {
    _totalRequests = 0;
    _cacheHits = 0;
    _offlineHits = 0;
  }

  /// Get current cache hit rate
  static double getCacheHitRate() {
    if (_totalRequests == 0) return 0;
    return _cacheHits / _totalRequests;
  }
}

/// Performance Timing Helper
///
/// Utility for measuring operation durations
class PerformanceTiming {
  static final Map<String, DateTime> _timers = {};

  /// Start a timer
  static void start(String key) {
    _timers[key] = DateTime.now();
  }

  /// End timer and return duration in milliseconds
  static int end(String key, {bool printResult = true}) {
    if (!_timers.containsKey(key)) {
      logger.warning('Timer "$key" not found', tag: 'PERF');
      return 0;
    }

    final duration = DateTime.now().difference(_timers[key]!).inMilliseconds;
    _timers.remove(key);

    if (printResult && kDebugMode) {
      logger.debug('$key: ${duration}ms', tag: 'PERF');
    }

    return duration;
  }

  /// Stop all timers
  static void clearAll() {
    _timers.clear();
  }
}

/// Measure operation duration
///
/// Usage: final duration = await measure(() => expensiveOperation();
Future<int> measure(Future<void> Function() operation) async {
  final start = Stopwatch()..start();
  await operation();
  return start.elapsedMilliseconds;
}
