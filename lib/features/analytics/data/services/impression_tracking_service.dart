import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Tracks thumbnail impressions for true CTR calculation.
///
/// CTR = (qualified views / impressions) × 100
///
/// An impression is counted when:
///   1. Video thumbnail is >= 50% visible in the viewport
///   2. Visible for >= 1 second (prevents scroll-through inflations)
///   3. Same thumbnail is only counted once per user session
///
/// Impressions are batched and flushed every 30 seconds to minimize writes.
class ImpressionTrackingService extends GetxService {
  static const String _tag = 'ImpressionTrackingService';
  static const int _batchFlushInterval = 30; // seconds
  static const int _minVisibleDurationMs = 1000; // 1 second
  static const double _minVisibleFraction = 0.5; // 50% visible

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Batch buffer of impressions waiting to be flushed
  final List<_ImpressionEvent> _batch = [];

  /// Tracks which video IDs have already been counted this session
  final Set<String> _seenThisSession = {};

  /// Timer for periodic batch flush
  Timer? _flushTimer;

  @override
  void onInit() {
    super.onInit();
    _startBatchFlushTimer();
    logger.info('Impression Tracking Service initialized', tag: _tag);
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    _flushBatch(); // Flush remaining on shutdown
    super.onClose();
  }

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /// Record a video playback milestone (25%, 50%, 75%, 100%).
  void recordPlaybackMilestone({
    required String videoId,
    required int milestonePct,
  }) {
    logger.info('Playback milestone $milestonePct% for $videoId', tag: _tag);
  }

  /// Record a thumbnail impression.
  /// Call this when a video thumbnail has been visible for >= 1 second.
  /// Deduplicates within the same session.
  void recordImpression({
    required String videoId,
    required String channelId,
    String?
    source, // Where in the UI: home_feed, search_results, suggested, etc.
  }) {
    // Deduplicate within session
    final dedupKey = '${videoId}_${source ?? 'unknown'}';
    if (_seenThisSession.contains(dedupKey)) return;
    _seenThisSession.add(dedupKey);

    _batch.add(
      _ImpressionEvent(
        videoId: videoId,
        channelId: channelId,
        source: source ?? 'unknown',
        timestamp: DateTime.now(),
        userId: AuthService.to.uid.isNotEmpty ? AuthService.to.uid : null,
      ),
    );

    // Auto-flush if batch is large
    if (_batch.length >= 50) {
      _flushBatch();
    }
  }

  /// Create an IntersectionObserver-style tracker for a video card widget.
  /// Returns a callback to attach to a VisibilityDetector-like mechanism.
  ImpressionTracker createTracker({
    required String videoId,
    required String channelId,
    String? source,
  }) {
    return ImpressionTracker(
      videoId: videoId,
      channelId: channelId,
      source: source,
      service: this,
      minVisibleDurationMs: _minVisibleDurationMs,
      minVisibleFraction: _minVisibleFraction,
    );
  }

  /// Clear session dedup (call on app foreground resume)
  void resetSession() {
    _seenThisSession.clear();
  }

  // ===========================================================================
  // BATCH FLUSH
  // ===========================================================================

  void _startBatchFlushTimer() {
    _flushTimer = Timer.periodic(
      const Duration(seconds: _batchFlushInterval),
      (_) => _flushBatch(),
    );
  }

  /// Flush batched impressions to Firestore.
  /// Uses a single batch write for cost efficiency.
  Future<void> _flushBatch() async {
    if (_batch.isEmpty) return;

    final toFlush = List<_ImpressionEvent>.from(_batch);
    _batch.clear();

    try {
      final batch = _firestore.batch();

      // Group by video for daily impression counter increment
      final videoImpressionCounts = <String, int>{};
      final channelImpressionCounts = <String, int>{};

      for (final event in toFlush) {
        videoImpressionCounts[event.videoId] =
            (videoImpressionCounts[event.videoId] ?? 0) + 1;
        channelImpressionCounts[event.channelId] =
            (channelImpressionCounts[event.channelId] ?? 0) + 1;
      }

      // Increment impression counters on video documents
      for (final entry in videoImpressionCounts.entries) {
        final videoRef = _firestore
            .collection(FirestoreCollections.videos)
            .doc(entry.key);
        batch.update(videoRef, {
          'impressionCount': FieldValue.increment(entry.value),
        });
      }

      // Write individual impression events for detailed analytics
      // (optional: can be disabled for cost at scale)
      for (final event in toFlush) {
        final ref = _firestore.collection('impressions_raw').doc();
        batch.set(ref, event.toMap());
      }

      await batch.commit();

      logger.info(
        'Flushed ${toFlush.length} impressions for ${videoImpressionCounts.length} videos',
        tag: _tag,
      );
    } catch (e) {
      // Put back failed events for retry
      _batch.insertAll(0, toFlush);
      logger.warning('Failed to flush impressions, will retry: $e', tag: _tag);
    }
  }
}

// =============================================================================
// IMPRESSION EVENT (internal batch item)
// =============================================================================

class _ImpressionEvent {
  _ImpressionEvent({
    required this.videoId,
    required this.channelId,
    required this.source,
    required this.timestamp,
    this.userId,
  });
  final String videoId;
  final String channelId;
  final String source;
  final DateTime timestamp;
  final String? userId;

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'channelId': channelId,
    'source': source,
    'timestamp': Timestamp.fromDate(timestamp),
    'userId': userId,
  };
}

// =============================================================================
// IMPRESSION TRACKER (per-card visibility observer)
// =============================================================================

/// Attach to a video card to track when the thumbnail becomes visible.
/// Implements the "50% visible for 1 second" rule.
class ImpressionTracker {
  ImpressionTracker({
    required this.videoId,
    required this.channelId,
    required this.service,
    required this.minVisibleDurationMs,
    required this.minVisibleFraction,
    this.source,
  });
  final String videoId;
  final String channelId;
  final String? source;
  final ImpressionTrackingService service;
  final int minVisibleDurationMs;
  final double minVisibleFraction;

  Timer? _visibilityTimer;
  bool _hasRecorded = false;

  /// Call when visibility fraction changes (from VisibilityDetector or similar).
  /// [visibleFraction] should be 0.0-1.0
  void onVisibilityChanged(double visibleFraction) {
    if (_hasRecorded) return;

    if (visibleFraction >= minVisibleFraction) {
      // Start timer if not already running
      _visibilityTimer ??= Timer(
        Duration(milliseconds: minVisibleDurationMs),
        () {
          if (!_hasRecorded) {
            _hasRecorded = true;
            service.recordImpression(
              videoId: videoId,
              channelId: channelId,
              source: source,
            );
          }
        },
      );
    } else {
      // Thumbnail scrolled away before 1s — cancel
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
    }
  }

  /// Cleanup — call in widget dispose
  void dispose() {
    _visibilityTimer?.cancel();
    _visibilityTimer = null;
  }
}
