import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// Helper for logging search analytics and retrying failed queries with exponential backoff.
class SearchAnalyticsTracker {
  /// Track search execution to Firebase Analytics
  static Future<void> trackSearchAnalytics({
    required String query,
    required int resultCount,
    required int latencyMs,
    required bool wasCached,
    String? error,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'search_executed',
        parameters: {
          'query': query,
          'results_count': resultCount,
          'latency_ms': latencyMs,
          'was_cached': wasCached ? 1 : 0,
          'error': error ?? 'none',
          'query_timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchAnalyticsTracker.trackAnalytics');
    }
  }

  /// Retry failed search query with exponential backoff
  static Future<List<SearchResult>> retryWithBackoff(
    Future<List<SearchResult>> Function() queryFn, {
    int maxRetries = 3,
    int initialDelayMs = 100,
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      try {
        return await queryFn();
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        final backoffDelay = initialDelayMs * (1 << i);
        await Future.delayed(Duration(milliseconds: backoffDelay));
      }
    }
    return [];
  }
}
