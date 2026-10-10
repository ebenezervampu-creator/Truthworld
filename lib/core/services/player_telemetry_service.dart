import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Player Quality of Service (QoS) and playback telemetry event.
class PlaybackQoSEvent {
  const PlaybackQoSEvent({
    required this.videoId,
    required this.startupLatencyMs,
    required this.totalBufferingMs,
    required this.stallCount,
    required this.resolutionSwitches,
    required this.playedDurationSeconds,
    this.fatalError,
    this.endedNormally = false,
  });

  final String videoId;
  final int startupLatencyMs;
  final int totalBufferingMs;
  final int stallCount;
  final int resolutionSwitches;
  final int playedDurationSeconds;
  final String? fatalError;
  final bool endedNormally;

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'startupLatencyMs': startupLatencyMs,
        'totalBufferingMs': totalBufferingMs,
        'stallCount': stallCount,
        'resolutionSwitches': resolutionSwitches,
        'playedDurationSeconds': playedDurationSeconds,
        'fatalError': fatalError,
        'endedNormally': endedNormally,
        'timestamp': DateTime.now().toIso8601String(),
      };
}

/// Active session tracking for a specific video playback lifecycle.
class PlaybackSessionTracker {
  PlaybackSessionTracker({required this.videoId})
      : startTime = DateTime.now();

  final String videoId;
  final DateTime startTime;

  DateTime? firstFrameTime;
  int stallCount = 0;
  int totalBufferingMs = 0;
  DateTime? currentStallStartTime;
  int resolutionSwitches = 0;
  int playedDurationSeconds = 0;
  String? fatalError;

  void recordFirstFrame() {
    firstFrameTime ??= DateTime.now();
  }

  void startBuffering() {
    if (currentStallStartTime == null) {
      stallCount++;
      currentStallStartTime = DateTime.now();
    }
  }

  void stopBuffering() {
    if (currentStallStartTime != null) {
      final elapsed =
          DateTime.now().difference(currentStallStartTime!).inMilliseconds;
      totalBufferingMs += elapsed;
      currentStallStartTime = null;
    }
  }

  void recordResolutionSwitch(String newResolution) {
    resolutionSwitches++;
  }

  void recordHeartbeat({required int currentPositionSeconds}) {
    playedDurationSeconds = currentPositionSeconds;
  }

  void recordFatalError(String error) {
    fatalError = error;
  }

  PlaybackQoSEvent finalizeSession({bool endedNormally = true}) {
    stopBuffering();
    final startupLatency = firstFrameTime != null
        ? firstFrameTime!.difference(startTime).inMilliseconds
        : 0;

    return PlaybackQoSEvent(
      videoId: videoId,
      startupLatencyMs: startupLatency,
      totalBufferingMs: totalBufferingMs,
      stallCount: stallCount,
      resolutionSwitches: resolutionSwitches,
      playedDurationSeconds: playedDurationSeconds,
      fatalError: fatalError,
      endedNormally: endedNormally,
    );
  }
}

/// Service that monitors video player buffering, stalls, and telemetry.
class PlayerTelemetryService extends GetxService {
  static PlayerTelemetryService get to => Get.find<PlayerTelemetryService>();

  final Map<String, PlaybackSessionTracker> _activeSessions = {};

  /// Starts monitoring playback QoS for a video ID.
  PlaybackSessionTracker startSession(String videoId) {
    final tracker = PlaybackSessionTracker(videoId: videoId);
    _activeSessions[videoId] = tracker;
    return tracker;
  }

  /// Records first frame rendered (Time to First Frame).
  void recordFirstFrame(String videoId) {
    _activeSessions[videoId]?.recordFirstFrame();
  }

  /// Records that the player entered a buffering/stall state.
  void recordBufferStart(String videoId) {
    _activeSessions[videoId]?.startBuffering();
  }

  /// Records that the player resumed playback after buffering.
  void recordBufferEnd(String videoId) {
    _activeSessions[videoId]?.stopBuffering();
  }

  /// Records a fatal playback error (e.g. HLS decode error or HTTP 403).
  void recordFatalError(String videoId, String error) {
    _activeSessions[videoId]?.recordFatalError(error);
  }

  /// Ends playback session and dispatches telemetry event.
  void endSession(String videoId, {bool endedNormally = true}) {
    final tracker = _activeSessions.remove(videoId);
    if (tracker == null) return;

    final event = tracker.finalizeSession(endedNormally: endedNormally);
    _dispatchTelemetry(event);
  }

  void _dispatchTelemetry(PlaybackQoSEvent event) {
    if (kDebugMode) {
      LoggerService().info(
        'Playback QoS Telemetry: video=${event.videoId}, '
        'TTFF=${event.startupLatencyMs}ms, stalls=${event.stallCount}, '
        'buffering=${event.totalBufferingMs}ms, error=${event.fatalError}',
        tag: 'PlayerTelemetry',
      );
    }
  }
}
