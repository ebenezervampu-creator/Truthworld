import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/firebase_rtdb_helper.dart';

/// Hybrid Multi-Tiered Watch History & Playback Resume Service.
///
/// Tier 1: Local GetStorage (0ms instant resume on same device, offline-ready)
/// Tier 2: Firebase RTDB /playbackResume (lightweight, zero-cost cross-device sync)
/// Tier 3: Cloud Firestore /watch_history (durable permanent watch history, updated on pause/exit/completion)
class WatchHistoryService extends GetxService {
  static WatchHistoryService get to {
    if (!Get.isRegistered<WatchHistoryService>()) {
      Get.put(WatchHistoryService(), permanent: true);
    }
    return Get.find<WatchHistoryService>();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = getSafeFirebaseDatabase();
  final GetStorage _storage = GetStorage();

  final RxMap<String, double> _watchProgress =
      <String, double>{}.obs; // videoId -> percentage (0-100)
  RxMap<String, double> get watchProgressMap => _watchProgress;
  final RxMap<String, int> _lastPositions =
      <String, int>{}.obs; // videoId -> seconds

  StreamSubscription? _historySubscription;
  StreamSubscription? _rtdbResumeSubscription;

  @override
  void onInit() {
    super.onInit();
    // Listen to auth changes to fetch history for the new user
    ever(AuthService.to.currentUser, _handleAuthChanged);
    _handleAuthChanged(AuthService.to.user);
  }

  void clearHistorySubscriptions() {
    _historySubscription?.cancel();
    _historySubscription = null;
    _rtdbResumeSubscription?.cancel();
    _rtdbResumeSubscription = null;
    _watchProgress.clear();
    _lastPositions.clear();
  }

  void _handleAuthChanged(dynamic user) {
    clearHistorySubscriptions();

    if (user != null) {
      final userId = AuthService.to.uid;
      if (userId.isEmpty) return;

      // 1. Listen to permanent Firestore watch history (bounded to 200 items for cost efficiency)
      _historySubscription = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history')
          .orderBy('watchedAt', descending: true)
          .limit(200)
          .snapshots()
          .listen(
            (snapshot) {
              for (final doc in snapshot.docs) {
                final data = doc.data();
                final videoId = doc.id;
                final percentage =
                    (data['watchPercentage'] as num?)?.toDouble() ?? 0.0;
                final lastPos = (data['lastPosition'] as num?)?.toInt() ?? 0;
                final watchedDur = (data['watchedDuration'] as num?)?.toInt() ?? 0;
                final vidDur = (data['videoDuration'] as num?)?.toInt() ?? 0;

                _watchProgress[videoId] = percentage;
                _lastPositions[videoId] = lastPos;

                if (watchedDur > 0) {
                  _storage.write('cumulative_watch_$videoId', watchedDur);
                }
                if (percentage >= 90.0 ||
                    data['isCompleted'] == true ||
                    (vidDur > 0 && watchedDur >= (vidDur * 0.90))) {
                  _storage.write('fully_watched_$videoId', true);
                  _watchProgress[videoId] = 100.0;
                }
              }
            },
            onError: (e) {
              logger.error(
                'Error listening to watch history: $e',
                tag: 'WATCH_HISTORY',
              );
            },
          );

      // 2. Listen to RTDB cross-device resume updates (zero-cost operations)
      try {
        _rtdbResumeSubscription = _database
            .ref('playbackResume/$userId')
            .onValue
            .listen((event) {
              final val = event.snapshot.value;
              if (val is Map) {
                val.forEach((key, raw) {
                  if (raw is Map) {
                    final videoId = key.toString();
                    final pos = (raw['position'] as num?)?.toInt() ?? 0;
                    final pct = (raw['percentage'] as num?)?.toDouble() ?? 0.0;
                    if (pos > 0) _lastPositions[videoId] = pos;
                    if (pct > 0) _watchProgress[videoId] = pct;
                  }
                });
              }
            }, onError: (Object e, StackTrace s) {
              ErrorHandler.log(
                e,
                stackTrace: s,
                tag: 'WatchHistoryService.resumeListener',
              );
            });
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'WatchHistoryService._setupRtdbResumeSync',
        );
      }
    }
  }

  /// Get watch progress percentage for a video (0.0 to 100.0)
  double getProgress(String videoId) {
    if (videoId.isEmpty) return 0.0;
    final memoryVal = _watchProgress[videoId];
    try {
      final local = _storage.read<Map<String, dynamic>>('resume_$videoId');
      if (local != null && local['percentage'] is num) {
        return (local['percentage'] as num).toDouble();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.getProgress',
      );
    }
    return memoryVal ?? 0.0;
  }

  /// Get last watched position in seconds for a video (checking local storage first, then memory/RTDB/Firestore)
  int getLastPosition(String videoId) {
    if (videoId.isEmpty) return 0;
    try {
      final local = _storage.read<Map<String, dynamic>>('resume_$videoId');
      if (local != null && local['position'] is num) {
        final pos = (local['position'] as num).toInt();
        if (pos > 0) return pos;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.getLastPosition',
      );
    }
    return _lastPositions[videoId] ?? 0;
  }

  /// Save local position immediately into GetStorage (called every few seconds during playback - 100% free, 0ms)
  void saveLocalPosition(String videoId, int positionSeconds, double percentage) {
    if (videoId.isEmpty || positionSeconds <= 0) return;

    final currentPos = _lastPositions[videoId];
    final currentPct = _watchProgress[videoId];

    final hasPosChanged = currentPos != positionSeconds;
    final hasPctChanged = currentPct == null || (currentPct - percentage).abs() >= 1.0;

    if (hasPosChanged || hasPctChanged) {
      void applyUpdate() {
        if (hasPosChanged) _lastPositions[videoId] = positionSeconds;
        if (hasPctChanged) _watchProgress[videoId] = percentage;
      }

      if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          applyUpdate();
        });
      } else {
        applyUpdate();
      }
    }

    try {
      _storage.write('resume_$videoId', {
        'position': positionSeconds,
        'percentage': percentage,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.saveLocalPosition',
      );
    }
  }

  /// Sync cross-device resume position to RTDB (throttled to 45-60s - 100% free operation)
  Future<void> syncCrossDeviceResume(
    String videoId,
    int positionSeconds,
    double percentage,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty || videoId.isEmpty || positionSeconds <= 0) return;

    try {
      await _database.ref('playbackResume/$userId/$videoId').set({
        'position': positionSeconds,
        'percentage': percentage,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.syncCrossDeviceResume',
      );
    }
  }

  /// Check if a video has any watch progress
  bool hasProgress(String videoId) {
    return getProgress(videoId) > 0;
  }

  /// Check if a video has been watched (in memory, RTDB, Firestore stream, or local storage)
  bool isVideoWatched(String videoId) {
    if (videoId.isEmpty) return false;
    if (_watchProgress.containsKey(videoId)) return true;
    if (_lastPositions.containsKey(videoId) && (_lastPositions[videoId] ?? 0) > 0) return true;
    try {
      final local = _storage.read<Map<String, dynamic>>('resume_$videoId');
      if (local != null) return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.isVideoWatched',
      );
    }
    return false;
  }

  /// Get set of all known watched video IDs
  Set<String> get allWatchedVideoIds {
    final set = <String>{..._watchProgress.keys, ..._lastPositions.keys};
    return set;
  }

  /// Get cumulative watched seconds for this video across all sessions
  int getCumulativeWatchSeconds(String videoId) {
    if (videoId.isEmpty) return 0;
    try {
      final localSec = _storage.read<int>('cumulative_watch_$videoId');
      if (localSec != null && localSec > 0) return localSec;
    } catch (_) {}
    return 0;
  }

  /// Add watch delta to cumulative seconds and auto-mark fully watched if reaching 90%
  void addCumulativeWatchSeconds(String videoId, int deltaSeconds, int totalDuration) {
    if (videoId.isEmpty || deltaSeconds <= 0) return;
    try {
      final current = getCumulativeWatchSeconds(videoId);
      final newTotal = current + deltaSeconds;
      final clamped = totalDuration > 0 ? (newTotal > totalDuration ? totalDuration : newTotal) : newTotal;
      _storage.write('cumulative_watch_$videoId', clamped);
      if (totalDuration > 0 && clamped >= (totalDuration * 0.90)) {
        markVideoFullyWatched(videoId);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.addCumulativeWatchSeconds',
      );
    }
  }

  /// Check if a video has been fully watched (>= 90% true watch time or marked completed)
  bool isVideoFullyWatched(String videoId, {int? totalDuration}) {
    if (videoId.isEmpty) return false;
    final pct = getProgress(videoId);
    if (pct >= 90.0) return true;
    try {
      final local = _storage.read<Map<String, dynamic>>('resume_$videoId');
      if (local != null && local['isCompleted'] == true) return true;
      final watchedFlag = _storage.read<bool>('fully_watched_$videoId');
      if (watchedFlag == true) return true;

      final cumulativeSec = getCumulativeWatchSeconds(videoId);
      final dur = totalDuration ?? (local != null ? (local['duration'] as num?)?.toInt() : null);
      if (dur != null && dur > 0 && cumulativeSec >= (dur * 0.90)) {
        return true;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.isVideoFullyWatched',
      );
    }
    return false;
  }

  /// Mark video as fully watched so repeat views never count watch time again
  void markVideoFullyWatched(String videoId) {
    if (videoId.isEmpty) return;
    try {
      _storage.write('fully_watched_$videoId', true);
      _watchProgress[videoId] = 100.0;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.markVideoFullyWatched',
      );
    }
  }

  @override
  void onClose() {
    _historySubscription?.cancel();
    _rtdbResumeSubscription?.cancel();
    super.onClose();
  }
}
