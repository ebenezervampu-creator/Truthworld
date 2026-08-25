import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for real-time live viewer presence tracking in RTDB.
///
/// Flow:
/// 1. When video starts playing, a session node is created at `/activeViewers/{videoId}/{sessionId}`.
/// 2. `.onDisconnect().remove()` is attached to the session reference to guarantee auto-removal on client disconnect.
/// 3. A 10-second heartbeat timer keeps `updatedAt`, `position`, and `watchedSeconds` fresh.
/// 4. Backend Cloud Function (`onActiveViewerWrite`) aggregates viewer counts into `/liveStats/{videoId}/concurrentCount`.
/// 5. UI components (`LiveViewerWidget`, `CreatorAnalyticsController`) listen to real-time streams of `/liveStats`.
class VideoPresenceService extends GetxService {
  static const String _tag = 'VideoPresenceService';

  static VideoPresenceService get to {
    if (!Get.isRegistered<VideoPresenceService>()) {
      return Get.put(VideoPresenceService());
    }
    return Get.find<VideoPresenceService>();
  }

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Uuid _uuid = const Uuid();

  String? _currentVideoId;
  String? _currentSessionId;
  DatabaseReference? _currentSessionRef;
  Timer? _heartbeatTimer;

  int _lastWatchedSeconds = 0;
  double _lastPosition = 0;

  /// Whether there is an active watching session
  bool get isWatching => _currentSessionRef != null && _currentVideoId != null;
  String? get currentVideoId => _currentVideoId;
  String? get currentSessionId => _currentSessionId;

  /// Start tracking live viewer presence for a video.
  Future<void> startWatching({
    required String videoId,
    double position = 0,
    int watchedSeconds = 0,
  }) async {
    if (videoId.isEmpty) return;

    // If already watching the same video with active session, just update heartbeat
    if (_currentVideoId == videoId && _currentSessionRef != null) {
      heartbeat(position: position, watchedSeconds: watchedSeconds);
      return;
    }

    // Stop existing session if switching videos
    if (isWatching) {
      await stopWatching();
    }

    try {
      _currentVideoId = videoId;
      _currentSessionId = _uuid.v4();
      _lastPosition = position;
      _lastWatchedSeconds = watchedSeconds;

      final user = FirebaseAuth.instance.currentUser;
      final uid = (user != null && user.uid.isNotEmpty)
          ? user.uid
          : 'anonymous_$_currentSessionId';

      final ref = _database.ref('activeViewers/$videoId/$_currentSessionId');
      _currentSessionRef = ref;

      final sessionData = <String, dynamic>{
        'uid': uid,
        'watchedSeconds': watchedSeconds,
        'position': position,
        'updatedAt': ServerValue.timestamp,
      };

      // Set initial data and register onDisconnect handler
      await ref.set(sessionData);
      await ref.onDisconnect().remove();

      logger.info(
        'Live presence started for video: $videoId (session: $_currentSessionId)',
        tag: _tag,
      );

      // Start periodic heartbeat (every 10s to stay below the 15s stale threshold)
      _startHeartbeatTimer();
    } catch (e, stackTrace) {
      logger.error(
        'Failed to start live presence for video: $videoId: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Update active viewer presence heartbeat
  void heartbeat({double? position, int? watchedSeconds}) {
    if (_currentSessionRef == null || _currentVideoId == null) return;

    if (position != null) _lastPosition = position;
    if (watchedSeconds != null) _lastWatchedSeconds = watchedSeconds;

    try {
      _currentSessionRef!.update({
        'position': _lastPosition,
        'watchedSeconds': _lastWatchedSeconds,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[$_tag] Heartbeat update error: $e');
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      heartbeat();
    });
  }

  /// Stop watching and immediately remove presence session
  Future<void> stopWatching() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final ref = _currentSessionRef;
    final videoId = _currentVideoId;
    final sessionId = _currentSessionId;

    _currentSessionRef = null;
    _currentVideoId = null;
    _currentSessionId = null;
    _lastPosition = 0;
    _lastWatchedSeconds = 0;

    if (ref != null) {
      try {
        await ref.onDisconnect().cancel();
        await ref.remove();
        logger.info(
          'Live presence stopped for video: $videoId (session: $sessionId)',
          tag: _tag,
        );
      } catch (e) {
        debugPrint('[$_tag] Error removing presence session: $e');
      }
    }
  }

  /// Real-time stream of concurrent viewers for a specific video or global.
  Stream<int> getLiveViewerCountStream(String? videoId) {
    try {
      final path = (videoId != null && videoId.isNotEmpty)
          ? 'liveStats/$videoId/concurrentCount'
          : 'liveStats/global/concurrentCount';

      return _database.ref(path).onValue.map((event) {
        final val = event.snapshot.value;
        if (val is num) return val.toInt();
        return 0;
      }).handleError((Object error) {
        debugPrint('[$_tag] Error in live viewer count stream: $error');
        return 0;
      });
    } catch (e) {
      debugPrint('[$_tag] Failed to create live viewer stream: $e');
      return Stream.value(0);
    }
  }

  /// One-shot fetch of the current concurrent viewer count
  Future<int> getLiveViewerCount(String? videoId) async {
    try {
      final path = (videoId != null && videoId.isNotEmpty)
          ? 'liveStats/$videoId/concurrentCount'
          : 'liveStats/global/concurrentCount';

      final snapshot = await _database.ref(path).get();
      final val = snapshot.value;
      if (val is num) return val.toInt();
      return 0;
    } catch (e) {
      debugPrint('[$_tag] Error fetching live viewer count: $e');
      return 0;
    }
  }

  @override
  void onClose() {
    stopWatching();
    super.onClose();
  }
}
