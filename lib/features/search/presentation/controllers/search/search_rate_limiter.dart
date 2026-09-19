import 'package:flutter/foundation.dart';

/// Sliding-window query rate limiter to prevent API abuse and excessive backend costs.
class SearchRateLimiter {
  SearchRateLimiter({this.maxQueriesPerMinute = 35});

  /// Maximum queries allowed per 60-second window
  final int maxQueriesPerMinute;

  int _queryCount = 0;
  DateTime _queryWindowStart = DateTime.now();

  int get queryCount => _queryCount;

  /// Check if the query limit has been exceeded in the active sliding window
  bool isRateLimitExceeded() {
    final now = DateTime.now();
    final secondsSinceWindowStart = now.difference(_queryWindowStart).inSeconds;

    // Reset window if minute has passed
    if (secondsSinceWindowStart > 60) {
      _queryCount = 0;
      _queryWindowStart = now;
      return false;
    }

    // Check if limit exceeded
    if (_queryCount >= maxQueriesPerMinute) {
      debugPrint(
        '⚠️ [Search] Rate limit exceeded! '
        '($_queryCount/$maxQueriesPerMinute queries in last $secondsSinceWindowStart seconds)',
      );
      return true;
    }

    return false;
  }

  /// Increment query count when an authentic query is dispatched
  void recordQuery() {
    _queryCount++;
    debugPrint('💰 [Search] Query recorded ($_queryCount/min)');
  }

  /// Reset counter and window
  void reset() {
    _queryCount = 0;
    _queryWindowStart = DateTime.now();
  }
}
