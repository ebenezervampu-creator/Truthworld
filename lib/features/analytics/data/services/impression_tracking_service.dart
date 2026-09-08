import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/firebase_rtdb_helper.dart';

/// Tracks thumbnail impressions for true CTR calculation.
///
/// CTR = (qualified views / impressions) × 100
///
/// An impression is counted when:
///   1. Video thumbnail is >= 50% visible in the viewport
///   2. Visible for >= 1 second (prevents scroll-through inflations)
///   3. Same thumbnail is only counted once per user session
///
/// Optimized Architecture:
/// - In-memory client aggregation per video during 30s scroll windows.
/// - Atomic delta increments pushed to RTDB `/pendingImpressions/{videoId}`.
/// - Zero Firestore document writes on client (scheduled Cloud Function rolls up to Firestore).
class ImpressionTrackingService extends GetxService {
  static const String _tag = 'ImpressionTrackingService';
  static const int _batchFlushInterval = 30; // seconds
  static const int _minVisibleDurationMs = 1000; // 1 second
  static const double _minVisibleFraction = 0.5; // 50% visible

  final FirebaseDatabase _database = getSafeFirebaseDatabase();

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
    logger.info('Impression Tracking Service initialized (RTDB Pipeline)', tag: _tag);
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
    String? source, // Where in the UI: home_feed, search_results, suggested, etc.
  }) {
    if (videoId.isEmpty) return;

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
  // BATCH FLUSH TO RTDB (Zero Firestore writes)
  // ===========================================================================

  void _startBatchFlushTimer() {
    _flushTimer = Timer.periodic(
      const Duration(seconds: _batchFlushInterval),
      (_) => _flushBatch(),
    );
  }

  /// Flush batched impressions to RTDB.
  /// Aggregates counts per video in-memory and pushes atomic ServerValue.increment deltas.
  Future<void> _flushBatch() async {
    if (_batch.isEmpty) return;

    final toFlush = List<_ImpressionEvent>.from(_batch);
    _batch.clear();

    try {
      // 1. Group impressions by video in memory
      final videoImpressionCounts = <String, int>{};
      for (final event in toFlush) {
        videoImpressionCounts[event.videoId] =
            (videoImpressionCounts[event.videoId] ?? 0) + 1;
      }

      // 2. Perform atomic multi-path update in RTDB
      final updates = <String, dynamic>{};
      for (final entry in videoImpressionCounts.entries) {
        updates['pendingImpressions/${entry.key}/count'] =
            ServerValue.increment(entry.value);
        updates['pendingImpressions/${entry.key}/updatedAt'] =
            ServerValue.timestamp;
      }

      await _database.ref().update(updates);

      logger.info(
        'Flushed ${toFlush.length} impressions for ${videoImpressionCounts.length} videos to RTDB',
        tag: _tag,
      );
    } catch (e) {
      // Put back failed events for retry
      _batch.insertAll(0, toFlush);
      debugPrint('[$_tag] Failed to flush impressions to RTDB, will retry: $e');
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
