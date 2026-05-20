import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Search Analytics Service
/// Tracks search metrics for insights and optimization
/// Helps identify trends, popular queries, and user behavior patterns
class SearchAnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════
  // SEARCH EVENT TRACKING
  // ═══════════════════════════════════════════════════════════════════════

  /// Log search query execution
  Future<void> logSearchQuery({
    required String query,
    required String searchType, // 'all', 'videos', 'channels'
    required String sortBy,
    required int resultsCount,
    required int latencyMs,
    required bool wasCached,
    String? category,
    String? error,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'search_query',
        parameters: {
          'query_text': query.length > 100 ? query.substring(0, 100) : query,
          'query_length': query.length,
          'search_type': searchType,
          'sort_by': sortBy,
          'results_count': resultsCount,
          'latency_ms': latencyMs,
          'was_cached': wasCached ? 'yes' : 'no',
          'category': category ?? 'none',
          'has_error': error != null ? 'yes' : 'no',
          'error_message': error ?? 'none',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Also save to Firestore for advanced analytics
      await _recordSearchAnalytics(
        query: query,
        searchType: searchType,
        sortBy: sortBy,
        resultsCount: resultsCount,
        latencyMs: latencyMs,
        wasCached: wasCached,
        category: category,
        error: error,
      );

      debugPrint('📊 Search analytics logged: "$query" ($resultsCount results)');
    } catch (e) {
      debugPrint('❌ Analytics logging error: $e');
    }
  }

  /// Log search result click (when user taps a result)
  Future<void> logResultClick({
    required String query,
    required String resultId,
    required String resultType, // 'video' or 'channel'
    required int position, // Position in results list
  }) async {
    try {
      await _analytics.logEvent(
        name: 'search_result_click',
        parameters: {
          'query': query,
          'result_id': resultId,
          'result_type': resultType,
          'position': position,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('❌ Click tracking error: $e');
    }
  }

  /// Log filter usage
  Future<void> logFilterUsed({
    required String filterType, // 'search_type', 'sort', 'category', 'date'
    required String filterValue,
    required String searchQuery,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'search_filter_applied',
        parameters: {
          'filter_type': filterType,
          'filter_value': filterValue,
          'query': searchQuery,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('❌ Filter tracking error: $e');
    }
  }

  /// Log search session
  Future<void> logSearchSession({
    required Duration sessionDuration,
    required int totalQueries,
    required int totalClicks,
    required bool filtersUsed,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'search_session',
        parameters: {
          'session_duration_seconds': sessionDuration.inSeconds,
          'total_queries': totalQueries,
          'total_clicks': totalClicks,
          'filters_used': filtersUsed ? 'yes' : 'no',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('❌ Session tracking error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Save detailed search analytics to Firestore
  Future<void> _recordSearchAnalytics({
    required String query,
    required String searchType,
    required String sortBy,
    required int resultsCount,
    required int latencyMs,
    required bool wasCached,
    String? category,
    String? error,
  }) async {
    try {
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);

      // Record in search analytics collection
      await _firestore.collection('search_analytics').add({
        'query': query,
        'queryLowercase': query.toLowerCase(),
        'searchType': searchType,
        'sortBy': sortBy,
        'resultsCount': resultsCount,
        'latencyMs': latencyMs,
        'wasCached': wasCached,
        'category': category,
        'error': error,
        'timestamp': timestamp,
        'date': now.toUtc().toIso8601String().split('T').first,
      });

      // Update trending searches counter
      await _updateTrendingSearch(query);
    } catch (e) {
      debugPrint('❌ Error recording search analytics: $e');
    }
  }

  /// Update trending searches collection
  Future<void> _updateTrendingSearch(String query) async {
    try {
      final docRef = _firestore
          .collection('trending_searches')
          .doc(query.toLowerCase());

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          transaction.update(docRef, {
            'searchCount': FieldValue.increment(1),
            'lastSearched': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(docRef, {
            'term': query,
            'termLowercase': query.toLowerCase(),
            'searchCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSearched': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Error updating trending search: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANALYTICS QUERIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Get top searches for a date range
  Future<List<Map<String, dynamic>>> getTopSearches({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('trending_searches')
          .where('lastSearched',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('lastSearched', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('searchCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error fetching top searches: $e');
      return [];
    }
  }

  /// Get average search latency
  Future<double> getAverageSearchLatency({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('search_analytics')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .limit(1000)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      double totalLatency = 0;
      for (var doc in snapshot.docs) {
        totalLatency += (doc['latencyMs'] as num).toDouble();
      }

      return totalLatency / snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error calculating average latency: $e');
      return 0.0;
    }
  }

  /// Get search performance metrics
  Future<SearchMetrics> getSearchMetrics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('search_analytics')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .limit(10000)
          .get();

      if (snapshot.docs.isEmpty) {
        return SearchMetrics.empty();
      }

      int totalQueries = snapshot.docs.length;
      int cachedQueries = 0;
      int errorQueries = 0;
      double totalLatency = 0;
      int totalResults = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['wasCached'] == true) cachedQueries++;
        if (data['error'] != null) errorQueries++;
        totalLatency += (data['latencyMs'] as num).toDouble();
        totalResults += (data['resultsCount'] as num).toInt();
      }

      return SearchMetrics(
        totalQueries: totalQueries,
        cachedQueries: cachedQueries,
        errorQueries: errorQueries,
        averageLatencyMs: totalLatency / totalQueries,
        cacheHitRate: (cachedQueries / totalQueries) * 100,
        errorRate: (errorQueries / totalQueries) * 100,
        averageResultsPerQuery: totalResults / totalQueries,
      );
    } catch (e) {
      debugPrint('❌ Error calculating metrics: $e');
      return SearchMetrics.empty();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MODEL CLASSES
// ═══════════════════════════════════════════════════════════════════════

/// Search performance metrics
class SearchMetrics {
  final int totalQueries;
  final int cachedQueries;
  final int errorQueries;
  final double averageLatencyMs;
  final double cacheHitRate;
  final double errorRate;
  final double averageResultsPerQuery;

  SearchMetrics({
    required this.totalQueries,
    required this.cachedQueries,
    required this.errorQueries,
    required this.averageLatencyMs,
    required this.cacheHitRate,
    required this.errorRate,
    required this.averageResultsPerQuery,
  });

  factory SearchMetrics.empty() => SearchMetrics(
    totalQueries: 0,
    cachedQueries: 0,
    errorQueries: 0,
    averageLatencyMs: 0,
    cacheHitRate: 0,
    errorRate: 0,
    averageResultsPerQuery: 0,
  );

  @override
  String toString() {
    return '''
    SearchMetrics:
    - Total Queries: $totalQueries
    - Cached Queries: $cachedQueries (${cacheHitRate.toStringAsFixed(1)}% hit rate)
    - Error Queries: $errorQueries (${errorRate.toStringAsFixed(1)}% error rate)
    - Average Latency: ${averageLatencyMs.toStringAsFixed(0)}ms
    - Average Results: ${averageResultsPerQuery.toStringAsFixed(0)} per query
    ''';
  }
}
