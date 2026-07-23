import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/services/image_verification_service.dart';

/// ============================================================================
/// VERIFICATION CACHE SERVICE - INDUSTRY STANDARD CACHING
/// ============================================================================
/// Implements efficient caching for image verification results
/// Reduces Firestore reads and improves UI responsiveness
/// - Automatic cache invalidation (5 min TTL)
/// - Memory efficient LRU eviction
/// - Real-time sync support

class VerificationCacheService {

  factory VerificationCacheService() {
    return _singleton;
  }

  VerificationCacheService._internal();
  static final VerificationCacheService _singleton = VerificationCacheService._internal();

  // Cache storage with timestamp tracking
  final Map<String, _CacheEntry> _cache = {};
  
  // Configuration
  static const Duration cacheTTL = Duration(minutes: 5);
  static const int maxCacheSize = 100;
  static const Duration cleanupInterval = Duration(minutes: 1);

  DateTime _lastCleanup = DateTime.now();

  /// Initialize cache with periodic cleanup
  void initialize() {
    _lastCleanup = DateTime.now();
  }

  /// Get cached verification result
  VerificationResult? getVerification(String docId) {
    final entry = _cache[docId];
    
    // Check if cache is still valid
    if (entry != null) {
      final age = DateTime.now().difference(entry.timestamp);
      
      if (age.inSeconds < cacheTTL.inSeconds) {
        // Update access time for LRU
        entry.lastAccessed = DateTime.now();
        return entry.result;
      } else {
        // Cache expired, remove it
        _cache.remove(docId);
      }
    }
    
    return null;
  }

  /// Cache a verification result
  void setVerification(String docId, VerificationResult result) {
    _performCleanupIfNeeded();
    
    _cache[docId] = _CacheEntry(
      result: result,
      timestamp: DateTime.now(),
    );
  }

  /// Invalidate specific cache entry
  void invalidate(String docId) {
    _cache.remove(docId);
  }

  /// Clear entire cache
  void clear() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'maxSize': maxCacheSize,
      'entries': _cache.entries
          .map((e) => {
                'docId': e.key,
                'status': e.value.result.status.name,
                'age': DateTime.now().difference(e.value.timestamp).inSeconds,
              })
          .toList(),
    };
  }

  void _performCleanupIfNeeded() {
    final now = DateTime.now();
    final timeSinceLastCleanup = now.difference(_lastCleanup);

    // Run cleanup periodically or if cache is full
    if (timeSinceLastCleanup > cleanupInterval || _cache.length >= maxCacheSize) {
      _cleanup();
      _lastCleanup = now;
    }
  }

  void _cleanup() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    // Remove expired entries
    _cache.forEach((key, entry) {
      final age = now.difference(entry.timestamp);
      if (age > cacheTTL) {
        keysToRemove.add(key);
      }
    });

    keysToRemove.forEach(_cache.remove);

    // If still over capacity, use LRU eviction
    while (_cache.length > maxCacheSize) {
      String? lruKey;
      DateTime? oldestAccess;

      _cache.forEach((key, entry) {
        if (oldestAccess == null || entry.lastAccessed.isBefore(oldestAccess!)) {
          lruKey = key;
          oldestAccess = entry.lastAccessed;
        }
      });

      if (lruKey != null) {
        _cache.remove(lruKey);
      } else {
        break;
      }
    }
  }
}

class _CacheEntry {

  _CacheEntry({
    required this.result,
    required this.timestamp,
  }) : lastAccessed = DateTime.now();
  final VerificationResult result;
  final DateTime timestamp;
  DateTime lastAccessed;
}

/// ============================================================================
/// OPTIMIZED IMAGE VERIFICATION SERVICE
/// ============================================================================
/// Enhanced version with caching and performance optimizations

extension OptimizedImageVerificationService on ImageVerificationService {
  static final _cache = VerificationCacheService();

  /// Get cached or fetch verification result
  Future<VerificationResult> getCachedVerification(String docId) async {
    // Try cache first
    final cached = _cache.getVerification(docId);
    if (cached != null) {
      return cached;
    }

    // Fallback to Firestore fetch
    try {
      final result = await _getVerificationFromFirestore(docId);
      _cache.setVerification(docId, result);
      return result;
    } catch (e) {
      return VerificationResult(
        status: VerificationStatus.error,
        reason: 'Failed to fetch verification: $e',
      );
    }
  }

  Future<VerificationResult> _getVerificationFromFirestore(String docId) async {
    final doc = await FirebaseFirestore.instance
        .collection('image_verification')
        .doc(docId)
        .get();

    return VerificationResult.fromFirestore(doc);
  }

  /// Stream with cache-aware updates
  Stream<VerificationResult> streamVerificationStatusOptimized(String docId) async* {
    // Emit cached value first if available
    final cachedResult = _cache.getVerification(docId);
    
    if (cachedResult != null && cachedResult.status != VerificationStatus.pending) {
      yield cachedResult;
      yield* streamVerificationStatus(docId)
          .takeWhile((result) => result.status == cachedResult.status);
      return;
    }

    // No cached result or pending, use normal stream
    yield* streamVerificationStatus(docId).map((result) {
      _cache.setVerification(docId, result);
      return result;
    });
  }

  /// Preload verification for upcoming items
  Future<void> preloadVerifications(List<String> docIds) async {
    final futures = docIds.map(getCachedVerification).toList();
    await Future.wait(futures);
  }
}

/// ============================================================================
/// PERFORMANCE MONITORING SERVICE
/// ============================================================================
/// Track verification performance metrics for optimization

class VerificationPerformanceMonitor {

  factory VerificationPerformanceMonitor() {
    return _singleton;
  }

  VerificationPerformanceMonitor._internal();
  static final VerificationPerformanceMonitor _singleton =
      VerificationPerformanceMonitor._internal();

  final Map<String, _PerformanceEntry> _metrics = {};

  /// Record verification response time
  void recordFetchTime(String docId, Duration duration) {
    _metrics[docId] = _PerformanceEntry(
      docId: docId,
      fetchTime: duration,
      timestamp: DateTime.now(),
    );
  }

  /// Record UI render time
  void recordRenderTime(String docId, Duration duration) {
    if (_metrics.containsKey(docId)) {
      _metrics[docId]!.renderTime = duration;
    }
  }

  /// Get average performance metrics
  Map<String, dynamic> getAverageMetrics() {
    if (_metrics.isEmpty) {
      return {
        'average_fetch_ms': 0,
        'average_render_ms': 0,
        'total_operations': 0,
      };
    }

    final avgFetch = _metrics.values
            .where((e) => e.fetchTime != null)
            .fold<Duration>(Duration.zero, (acc, e) => acc + e.fetchTime!)
            .inMilliseconds /
        _metrics.length;

    final avgRender = _metrics.values
            .where((e) => e.renderTime != null)
            .fold<Duration>(Duration.zero, (acc, e) => acc + e.renderTime!)
            .inMilliseconds /
        _metrics.length;

    return {
      'average_fetch_ms': avgFetch.toStringAsFixed(2),
      'average_render_ms': avgRender.toStringAsFixed(2),
      'total_operations': _metrics.length,
        'slowest_fetch_ms': _metrics.values
          .where((e) => e.fetchTime != null)
          .fold<Duration>(Duration.zero, (maxAcc, e) =>
              e.fetchTime!.inMilliseconds > maxAcc.inMilliseconds ? e.fetchTime! : maxAcc)
          .inMilliseconds,
    };
  }

  /// Clear metrics
  void clear() {
    _metrics.clear();
  }
}

class _PerformanceEntry {

  _PerformanceEntry({
    required this.docId,
    this.fetchTime,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  final String docId;
  final Duration? fetchTime;
  Duration? renderTime;
  final DateTime timestamp;
}





