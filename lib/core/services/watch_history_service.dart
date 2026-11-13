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

  Future<void> clearHistorySubscriptions() async {
    final histSub = _historySubscription;
    final rtdbSub = _rtdbResumeSubscription;
    _historySubscription = null;
    _rtdbResumeSubscription = null;

    final cancellations = <Future<void>>[];
    if (histSub != null) cancellations.add(histSub.cancel());
    if (rtdbSub != null) cancellations.add(rtdbSub.cancel());

    if (cancellations.isNotEmpty) {
      await Future.wait(cancellations);
    }

    _watchProgress.clear();
    _lastPositions.clear();
  }

  void _handleAuthChanged(dynamic user) {
    unawaited(clearHistorySubscriptions());

    if (user != null) {
      final userId = AuthService.to.uid;
      if (userId.isEmpty) return;

      // 1. One-time fetch of recent watch history (bounded to 25 items for fast boot & minimal read costs)
      // Real-time resume synchronization is continuously handled by the zero-cost RTDB listener below.
      _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history')
          .orderBy('watchedAt', descending: true)
          .limit(25)
          .get()
          .then(
            (snapshot) {
              for (final doc in snapshot.docs) {
                final data = doc.data();
                final videoId = doc.id;
                final percentage =
                    (data['watchPercentage'] as num?)?.toDouble() ?? 0.0;
                var lastPos = (data['lastPosition'] as num?)?.toInt() ?? 0;
                final watchedDur = (data['watchedDuration'] as num?)?.toInt() ?? 0;
                final vidDur = (data['videoDuration'] as num?)?.toInt() ?? 0;

                _watchProgress[videoId] = percentage;

                if (watchedDur > 0) {
                  _storage.write('cumulative_watch_$videoId', watchedDur);
                }
                if (percentage >= 90.0 ||
                    data['isCompleted'] == true ||
                    (vidDur > 0 && watchedDur >= (vidDur * 0.90)) ||
                    (vidDur > 0 && lastPos >= (vidDur - 10))) {
                  _storage.write('fully_watched_$videoId', true);
                  _watchProgress[videoId] = 100.0;
                  lastPos = 0; // Completed videos always restart from the beginning (0:00)
                }
                _lastPositions[videoId] = lastPos;
              }
            },
            onError: (e) {
              logger.error(
                'Error fetching initial watch history: $e',
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
                    if (pct >= 90.0 || isVideoFullyWatched(videoId)) {
                      _lastPositions[videoId] = 0;
                    } else if (pos > 0) {
                      _lastPositions[videoId] = pos;
                    }
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
    if (_storage.read<bool>('fully_watched_$videoId') == true) {
      return 100.0;
    }
    final memoryVal = _watchProgress[videoId];
    if (memoryVal != null && memoryVal >= 100.0) return 100.0;
    try {
      final local = _storage.read<Map<String, dynamic>>('resume_$videoId');
      if (local != null) {
        if (local['isCompleted'] == true) return 100.0;
        if (local['percentage'] is num) {
          final pct = (local['percentage'] as num).toDouble();
          return pct >= 90.0 ? 100.0 : pct;
        }
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

  /// Get last watched position in seconds for a video (checking local storage first, then memory/RTDB/Firestore).
  ///
  /// YouTube Playback Parity:
  /// - Videos that have been fully watched (>= 90% or marked completed) always return 0 (start over).
  /// - Positions within the first 5s return 0 (no micro-resumes).
  /// - Positions within the last 10s or >= 90% of duration return 0 (never resume directly at the end).
  int getLastPosition(String videoId, {int? totalDuration}) {
    if (videoId.isEmpty) return 0;

    // 1. If video is already marked or verified as fully watched, resume position is strictly 0.
    if (isVideoFullyWatched(videoId, totalDuration: totalDuration)) {
      return 0;
    }

    try {
      final local = _storage.read<Map<String, dynamic>>('resume_$videoId');
      if (local != null) {
        if (local['isCompleted'] == true) return 0;
        final pct = (local['percentage'] as num?)?.toDouble() ?? 0.0;
        if (pct >= 90.0) return 0;

        if (local['position'] is num) {
          final pos = (local['position'] as num).toInt();
          // YouTube threshold: ignore micro-progress in first 5s
          if (pos < 5) return 0;

          // YouTube threshold: within last 10s or >= 90% of duration, restart from 0
          final dur = totalDuration ?? (local['duration'] as num?)?.toInt();
          if (dur != null && dur > 0) {
            if (pos >= (dur - 10) || (pos / dur) >= 0.90) {
              return 0;
            }
          }
          if (pos > 0) return pos;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.getLastPosition',
      );
    }

    final memPos = _lastPositions[videoId] ?? 0;
    if (memPos < 5) return 0;
    if (totalDuration != null && totalDuration > 0) {
      if (memPos >= (totalDuration - 10) || (memPos / totalDuration) >= 0.90) {
        return 0;
      }
    }
    return memPos;
  }

  /// Get resume position in seconds for playback (semantic alias for [getLastPosition]).
  int getResumePosition(String videoId, {int? totalDuration}) =>
      getLastPosition(videoId, totalDuration: totalDuration);

  /// Reset playback resume position to 0 (beginning) while preserving watch history metrics
  /// (e.g. 100% watched bar on thumbnail, cumulative watch time, and completion state).
  void resetResumePosition(String videoId) {
    if (videoId.isEmpty) return;
    _lastPositions[videoId] = 0;
    try {
      final isWatched = isVideoFullyWatched(videoId);
      final local = _storage.read<Map<String, dynamic>>('resume_$videoId');
      final existingPct = (local != null && local['percentage'] is num)
          ? (local['percentage'] as num).toDouble()
          : (_watchProgress[videoId] ?? 0.0);
      final effectivePct = isWatched ? 100.0 : existingPct;
      _storage.write('resume_$videoId', {
        'position': 0,
        'percentage': effectivePct,
        if (isWatched) 'isCompleted': true,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (isWatched) {
        _watchProgress[videoId] = 100.0;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'WatchHistoryService.resetResumePosition',
      );
    }

    final userId = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
    if (userId.isNotEmpty) {
      try {
        _database.ref('playbackResume/$userId/$videoId').update({
          'position': 0,
          'updatedAt': ServerValue.timestamp,
        }).catchError((_) {});
      } catch (_) {}
    }
  }

  /// Save local position immediately into GetStorage (called every few seconds during playback - 100% free, 0ms)
  void saveLocalPosition(
    String videoId,
    int positionSeconds,
    double percentage, {
    int? totalDuration,
  }) {
    if (videoId.isEmpty || positionSeconds < 0) return;

    final isNearEnd = (totalDuration != null && totalDuration > 0 && positionSeconds >= (totalDuration - 10)) ||
        percentage >= 90.0;
    final isFullyWatched = isVideoFullyWatched(videoId, totalDuration: totalDuration);

    final effectivePos = (isNearEnd || isFullyWatched) ? 0 : positionSeconds;
    final effectivePct = (isNearEnd || isFullyWatched) ? 100.0 : percentage;

    final currentPos = _lastPositions[videoId];
    final currentPct = _watchProgress[videoId];

    final hasPosChanged = currentPos != effectivePos;
    final hasPctChanged = currentPct == null || (currentPct - effectivePct).abs() >= 1.0;

    if (hasPosChanged || hasPctChanged) {
      void applyUpdate() {
        if (hasPosChanged) _lastPositions[videoId] = effectivePos;
        if (hasPctChanged) _watchProgress[videoId] = effectivePct;
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
        'position': effectivePos,
        'percentage': effectivePct,
        if (isNearEnd || isFullyWatched) 'isCompleted': true,
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
    final userId = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
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

  /// Mark video as fully watched so repeat views never count watch time again,
  /// and reset playback resume position so subsequent views restart cleanly from 0:00.
  void markVideoFullyWatched(String videoId) {
    if (videoId.isEmpty) return;
    try {
      _storage.write('fully_watched_$videoId', true);
      _watchProgress[videoId] = 100.0;
      resetResumePosition(videoId);
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
