import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/firebase_rtdb_helper.dart';
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

  final FirebaseDatabase _database = getSafeFirebaseDatabase();
  final Uuid _uuid = const Uuid();

  String? _currentVideoId;
  String? _currentSessionId;
  DatabaseReference? _currentSessionRef;
  Timer? _heartbeatTimer;
  StreamSubscription? _connectionSubscription;

  int _lastWatchedSeconds = 0;
  double _lastPosition = 0;
  bool _isTransitioning = false;

  /// Whether there is an active watching session
  bool get isWatching => _currentSessionRef != null && _currentVideoId != null;
  String? get currentVideoId => _currentVideoId;
  String? get currentSessionId => _currentSessionId;

  @override
  void onInit() {
    super.onInit();
    _listenToConnectionState();
  }

  /// Listen to RTDB connection state for seamless reconnection recovery
  void _listenToConnectionState() {
    try {
      _connectionSubscription?.cancel();
      _connectionSubscription = _database.ref('.info/connected').onValue.listen((event) {
        final isConnected = event.snapshot.value == true;
        if (isConnected && isWatching && _currentSessionRef != null && _currentVideoId != null) {
          logger.info('RTDB reconnected. Restoring live presence session: $_currentSessionId', tag: _tag);
          _reestablishSession();
        }
      }, onError: (Object e, StackTrace s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: '$_tag.connectionSubscription',
        );
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: '$_tag.listenToConnectionState',
      );
    }
  }

  /// Re-writes presence node and re-attaches onDisconnect handler after network reconnection
  Future<void> _reestablishSession() async {
    final ref = _currentSessionRef;
    final videoId = _currentVideoId;
    final sessionId = _currentSessionId;
    if (ref == null || videoId == null || sessionId == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = (currentUser != null && !currentUser.isAnonymous)
          ? currentUser.uid
          : 'guest_$sessionId';

      final sessionData = <String, dynamic>{
        'uid': uid,
        'watchedSeconds': _lastWatchedSeconds,
        'position': _lastPosition,
        'updatedAt': ServerValue.timestamp,
      };

      await ref.set(sessionData);
      await ref.onDisconnect().remove();
      logger.info('Presence session re-established: $sessionId for video: $videoId', tag: _tag);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: '$_tag.reestablishSession',
      );
    }
  }

  /// Start tracking live viewer presence for a video (idempotent and race-guarded).
  Future<void> startWatching({
    required String videoId,
    double position = 0,
    int watchedSeconds = 0,
  }) async {
    if (videoId.isEmpty) return;

    // Idempotent fast-path: if already watching the exact same video with active session
    if (_currentVideoId == videoId && _currentSessionRef != null) {
      heartbeat(position: position, watchedSeconds: watchedSeconds);
      return;
    }

    if (_isTransitioning) {
      // Small delay to allow previous transition to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    _isTransitioning = true;
    try {
      // Stop previous session cleanly if switching videos
      if (isWatching) {
        await _internalStopWatching();
      }

      _currentVideoId = videoId;
      _currentSessionId = _uuid.v4();
      _lastPosition = position;
      _lastWatchedSeconds = watchedSeconds;

      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = (currentUser != null && !currentUser.isAnonymous)
          ? currentUser.uid
          : 'guest_$_currentSessionId';

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

      // Start periodic heartbeat (every 8s for high fault-tolerance)
      _startHeartbeatTimer();
    } catch (e, stackTrace) {
      logger.error(
        'Failed to start live presence for video: $videoId: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
    } finally {
      _isTransitioning = false;
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
      }).catchError((Object e, StackTrace s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: '$_tag.heartbeat.update',
        );
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: '$_tag.heartbeat',
      );
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      heartbeat();
    });
  }

  /// Stop watching and immediately remove presence session
  Future<void> stopWatching() async {
    _isTransitioning = true;
    try {
      await _internalStopWatching();
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _internalStopWatching() async {
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
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: '$_tag.internalStopWatching.onDisconnect',
        );
      }
      try {
        await ref.remove();
        logger.info(
          'Live presence stopped for video: $videoId (session: $sessionId)',
          tag: _tag,
        );
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: '$_tag.internalStopWatching.remove',
        );
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
      }).handleError((Object error, StackTrace stackTrace) {
        ErrorHandler.log(
          error,
          stackTrace: stackTrace,
          tag: '$_tag.getLiveViewerCountStream',
        );
        return 0;
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: '$_tag.getLiveViewerCountStream.create',
      );
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
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: '$_tag.getLiveViewerCount',
      );
      return 0;
    }
  }

  @override
  void onClose() {
    _connectionSubscription?.cancel();
    stopWatching();
    super.onClose();
  }
}
