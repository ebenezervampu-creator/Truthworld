import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_preferences.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

/// Mixin managing primary playback controls, volume, seeking, zooming, retry logic, and analytics.
mixin TowerPlayerPlaybackControlMixin on GetxController {
  // ── Host Dependencies ──
  @override
  bool get isClosed;
  VideoPlayerController get videoPlayerController;
  VideoPlayerController? get audioTrackController;
  PlaybackSource get activePlayback;
  RxBool get isShowingAd;
  void togglePlayPauseAd();
  void cancelPendingTap();
  void onInteraction();
  void syncActiveSubtitle();
  RxString get activePanel;
  TimerBag get timers;
  RxBool get isAudioOnly;
  AudioOnlyService? get audioService;
  bool get hasEnded;
  set hasEnded(bool val);

  // ── State ──
  final RxDouble volume = 1.0.obs;
  final RxBool isMuted = false.obs;
  final RxBool volumeSliderVis = false.obs;
  double _volumeBeforeMute = 1.0;

  final RxDouble playbackSpeed = 1.0.obs;
  final RxString toastMessage = ''.obs;
  final RxBool showStatsForNerds = false.obs;

  // Zoom & aspect ratio
  final RxBool isZoomToFill = false.obs;
  final RxDouble zoomScale = 1.0.obs;

  // Analytics & watch time
  final List<PlayerEvent> _events = [];
  List<PlayerEvent> get events => List.unmodifiable(_events);
  int _totalWatchSeconds = 0;
  int get totalWatchSeconds => _totalWatchSeconds;

  // Retry state
  int _retryCount = 0;
  int get retryCount => _retryCount;
  static const int maxRetries = 3;

  double get bufferHealthSeconds {
    final pos = videoPlayerController.value.position;
    final buffered = videoPlayerController.value.buffered;
    if (buffered.isEmpty) return 0;
    for (final r in buffered) {
      if (r.start <= pos && r.end >= pos) {
        return (r.end - pos).inMilliseconds / 1000.0;
      }
    }
    for (final r in buffered) {
      if (r.start > pos) return (r.end - r.start).inMilliseconds / 1000.0;
    }
    return 0;
  }

  String get zoomLabel {
    if (isZoomToFill.value) return 'Fill screen';
    if (zoomScale.value == 1.0) return 'Fit (1.0x)';
    final valStr = zoomScale.value % 1 == 0
        ? zoomScale.value.toInt().toString()
        : zoomScale.value.toStringAsFixed(1);
    return '${valStr}x';
  }

  void setZoomScale(double scale, {bool fill = false}) {
    if (fill) {
      isZoomToFill.value = true;
      zoomScale.value = 1.0;
      showToast('Zoom to Fill');
    } else {
      isZoomToFill.value = false;
      zoomScale.value = scale;
      final valStr = scale % 1 == 0
          ? scale.toInt().toString()
          : scale.toStringAsFixed(1);
      showToast(scale == 1.0 ? 'Original (Fit)' : 'Zoom ${valStr}x');
    }
  }

  void toggleZoomToFill() {
    if (isZoomToFill.value) {
      setZoomScale(1.0);
    } else {
      setZoomScale(1.0, fill: true);
    }
  }

  Future<void> togglePlayPause() async {
    cancelPendingTap();
    if (isShowingAd.value) {
      togglePlayPauseAd();
      return;
    }
    try {
      if (activePlayback.isPlaying) {
        await activePlayback.pause();
        await audioTrackController?.pause();
        stopWatchTimer();
        trackAnalytics(
          PlayerEvent(
            'pause',
            data: {'position': activePlayback.position.inSeconds},
          ),
        );
      } else {
        if (activePlayback.duration > Duration.zero &&
            activePlayback.position >= activePlayback.duration) {
          await activePlayback.seek(Duration.zero);
          await audioTrackController?.seekTo(Duration.zero);
        }
        TowerPlayerRegistry.pauseAllActivePlayers();
        HoverPreviewCoordinator.globalMute.value = true;
        await activePlayback.play();
        await audioTrackController?.play();
        startWatchTimer();
        trackAnalytics(
          PlayerEvent(
            'play',
            data: {'position': activePlayback.position.inSeconds},
          ),
        );
      }
      onInteraction();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerPlaybackControlMixin.togglePlayPause',
      );
    }
  }

  Future<void> seekTo(Duration pos) async {
    try {
      hasEnded = false;
      await activePlayback.seek(pos);
      syncActiveSubtitle();
      if (audioTrackController != null &&
          audioTrackController!.value.isInitialized) {
        final audioDur = audioTrackController!.value.duration;
        if (audioDur > Duration.zero && pos <= audioDur) {
          await audioTrackController!.seekTo(pos);
        } else {
          await audioTrackController!.pause();
        }
      }
      onInteraction();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerPlaybackControlMixin.seekTo');
    }
  }

  Future<void> seekRelative(
    int seconds, {
    bool showFeedbackToast = true,
  }) async {
    final current = activePlayback.position;
    final total = activePlayback.duration;
    final maxSecs = total.inSeconds > 0 ? total.inSeconds : 1;
    final newPos = Duration(
      seconds: (current.inSeconds + seconds).clamp(0, maxSecs),
    );
    await seekTo(newPos);
    if (showFeedbackToast) {
      showToast(seconds > 0 ? '+${seconds}s' : '${seconds}s');
    }
  }

  void setVolume(double vol) {
    volume.value = vol.clamp(0.0, 1.0);
    isMuted.value = vol == 0;
    try {
      if (audioTrackController != null) {
        videoPlayerController.setVolume(0);
        audioTrackController!.setVolume(isMuted.value ? 0.0 : volume.value);
      } else {
        videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerPlaybackControlMixin.setVolume',
      );
    }
    if (isAudioOnly.value) audioService?.setVolume(volume.value);
    onInteraction();
  }

  void toggleMute() {
    if (isMuted.value) {
      setVolume(_volumeBeforeMute);
    } else {
      _volumeBeforeMute = volume.value;
      setVolume(0);
    }
  }

  IconData get volumeIcon {
    if (isMuted.value || volume.value == 0) return Icons.volume_off_rounded;
    if (volume.value < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  void setSpeed(double speed) {
    try {
      videoPlayerController.setPlaybackSpeed(speed);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerPlaybackControlMixin.setSpeed.video',
      );
    }
    try {
      audioTrackController?.setPlaybackSpeed(speed);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerPlaybackControlMixin.setSpeed.audioTrack',
      );
    }
    playbackSpeed.value = speed;
    TowerPlayerPreferences.globalPlaybackSpeed = speed;
    activePanel.value = '';
    trackAnalytics(PlayerEvent('speed_change', data: {'speed': speed}));
  }

  void showToast(String msg) {
    toastMessage.value = msg;
    timers.set(
      'toast',
      Duration(milliseconds: PT.kToastDurationMs.toInt()),
      () => toastMessage.value = '',
    );
  }

  void scheduleRetry() {
    _retryCount++;
    timers.set(
      'retry',
      Duration(seconds: pow(2, _retryCount).toInt()),
      () async {
        try {
          await videoPlayerController.initialize();
          await videoPlayerController.play();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerPlaybackControlMixin.scheduleRetry',
          );
        }
      },
    );
  }

  void retryManual() {
    _retryCount = 0;
    scheduleRetry();
  }

  void resetRetryCount() {
    _retryCount = 0;
  }

  void trackAnalytics(PlayerEvent event) => _events.add(event);

  void startWatchTimer() {
    timers.setPeriodic(
      'watch',
      const Duration(seconds: 1),
      (_) => _totalWatchSeconds++,
    );
  }

  void stopWatchTimer() => timers.cancel('watch');
}
