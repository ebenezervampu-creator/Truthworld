import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/guest_playback_limit_service.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_preferences.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_vpc_event_handler.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

/// Mixin managing primary playback controls, volume, seeking, zooming, retry logic, and analytics.
mixin TowerPlayerPlaybackControlMixin on GetxController {
  // ── Host Dependencies ──
  @override
  bool get isClosed;
  VideoPlayerController get videoPlayerController;
  VideoPlayerController? get audioTrackController;
  bool get hasAlternateAudioTrack;
  PlaybackSource get activePlayback;
  RxBool get isShowingAd;
  void togglePlayPauseAd();
  void cancelPendingTap();
  void onInteraction();
  void syncActiveSubtitle({Duration? overridePos});
  RxString get activePanel;
  TimerBag get timers;
  RxBool get isAudioOnly;
  AudioOnlyService? get audioService;
  bool get hasEnded;
  set hasEnded(bool val);
  void hideSeekPreview();
  RxDouble get aspectRatio;
  Duration get effectiveDuration;

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
  final Rx<Offset> zoomPanOffset = Offset.zero.obs;

  bool get isZoomedIn => zoomScale.value > 1.02 || isZoomToFill.value;

  /// Calculate the zoom scale needed to fill the screen horizontally/vertically without black bars,
  /// preserving authentic aspect ratio exactly like YouTube's "Zoomed to fill".
  double calculateFillScale(Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return 1.0;
    final ar = aspectRatio.value > 0 ? aspectRatio.value : (16 / 9);
    final viewportAspect = viewportSize.width / viewportSize.height;

    if (viewportAspect >= ar) {
      // Screen is wider than video (pillarbox)
      return (viewportAspect / ar).clamp(1.0, 8.0);
    } else {
      // Screen is taller than video (letterbox)
      return (ar / viewportAspect).clamp(1.0, 8.0);
    }
  }

  /// Clamps the pan offset so that the zoomed video never shows empty black borders
  /// and remains cleanly framed within the viewport bounds.
  Offset clampPanOffset(Offset pan, double scale, Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0 || scale <= 1.001) {
      return Offset.zero;
    }
    final ar = aspectRatio.value > 0 ? aspectRatio.value : (16 / 9);
    final viewportAspect = viewportSize.width / viewportSize.height;

    double fitWidth;
    double fitHeight;
    if (viewportAspect >= ar) {
      fitHeight = viewportSize.height;
      fitWidth = viewportSize.height * ar;
    } else {
      fitWidth = viewportSize.width;
      fitHeight = viewportSize.width / ar;
    }

    final scaledWidth = fitWidth * scale;
    final scaledHeight = fitHeight * scale;

    final maxDx = scaledWidth > viewportSize.width
        ? (scaledWidth - viewportSize.width) / 2.0
        : 0.0;
    final maxDy = scaledHeight > viewportSize.height
        ? (scaledHeight - viewportSize.height) / 2.0
        : 0.0;

    final clampedX = maxDx > 0 ? pan.dx.clamp(-maxDx, maxDx) : 0.0;
    final clampedY = maxDy > 0 ? pan.dy.clamp(-maxDy, maxDy) : 0.0;

    return Offset(clampedX, clampedY);
  }

  Timer? _zoomAnimationTimer;

  void cancelZoomAnimation() {
    _zoomAnimationTimer?.cancel();
    _zoomAnimationTimer = null;
  }

  /// Smoothly animates zoom scale and pan offset using an ease-out cubic curve (60/120 FPS).
  void animateZoomTo({
    required double targetScale,
    required Offset targetPan,
    bool fill = false,
    Duration duration = const Duration(milliseconds: 240),
  }) {
    cancelZoomAnimation();
    final startScale = zoomScale.value;
    final startPan = zoomPanOffset.value;
    final startTime = DateTime.now();
    final totalMs = duration.inMilliseconds;

    if (totalMs <= 0 ||
        ((startScale - targetScale).abs() < 0.001 &&
            (startPan - targetPan).distance < 0.5)) {
      zoomScale.value = targetScale;
      zoomPanOffset.value = targetPan;
      isZoomToFill.value = fill;
      return;
    }

    _zoomAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final t = (elapsed / totalMs).clamp(0.0, 1.0);
      final curveVal = Curves.easeOutCubic.transform(t);

      zoomScale.value = startScale + (targetScale - startScale) * curveVal;
      zoomPanOffset.value = Offset.lerp(startPan, targetPan, curveVal)!;

      if (t >= 1.0) {
        timer.cancel();
        _zoomAnimationTimer = null;
        zoomScale.value = targetScale;
        zoomPanOffset.value = targetPan;
        isZoomToFill.value = fill;
      }
    });
  }

  /// Reset zoom and pan offset cleanly back to original 1.0x fit
  void resetZoom({bool animated = false}) {
    if (animated) {
      animateZoomTo(
        targetScale: 1.0,
        targetPan: Offset.zero,
      );
    } else {
      cancelZoomAnimation();
      isZoomToFill.value = false;
      zoomScale.value = 1.0;
      zoomPanOffset.value = Offset.zero;
    }
  }

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
    if (isZoomToFill.value) return 'Zoomed to fill';
    if (zoomScale.value <= 1.0) return 'Fit (1.0x)';
    final valStr = zoomScale.value % 1 == 0
        ? zoomScale.value.toInt().toString()
        : zoomScale.value.toStringAsFixed(1);
    return '${valStr}x';
  }

  void setZoomScale(
    double scale, {
    bool fill = false,
    Size? viewportSize,
    bool animated = false,
  }) {
    if (fill) {
      final fScale =
          viewportSize != null ? calculateFillScale(viewportSize) : 1.0;
      if (animated && viewportSize != null) {
        animateZoomTo(
          targetScale: fScale,
          targetPan: Offset.zero,
          fill: true,
        );
      } else {
        cancelZoomAnimation();
        isZoomToFill.value = true;
        zoomScale.value = 1.0;
        zoomPanOffset.value = Offset.zero;
      }
      showToast('Zoomed to fill');
    } else {
      if (scale <= 1.0) {
        resetZoom(animated: animated);
        showToast('Original');
      } else {
        final targetPan = viewportSize != null
            ? clampPanOffset(zoomPanOffset.value, scale, viewportSize)
            : zoomPanOffset.value;
        if (animated) {
          animateZoomTo(
            targetScale: scale,
            targetPan: targetPan,
          );
        } else {
          cancelZoomAnimation();
          isZoomToFill.value = false;
          zoomScale.value = scale;
          zoomPanOffset.value = targetPan;
        }
        final valStr = scale % 1 == 0
            ? scale.toInt().toString()
            : scale.toStringAsFixed(1);
        showToast('${valStr}x');
      }
    }
  }

  void toggleZoomToFill({Size? viewportSize, bool animated = false}) {
    if (isZoomToFill.value || zoomScale.value > 1.05) {
      resetZoom(animated: animated);
      showToast('Original');
    } else {
      setZoomScale(1.0, fill: true, viewportSize: viewportSize, animated: animated);
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
        if (Get.isRegistered<GuestPlaybackLimitService>() &&
            !GuestPlaybackLimitService.to.isPlaybackAllowed()) {
          GuestPlaybackLimitService.to.promptGuestSignIn();
          return;
        }
        final totalDur = effectiveDuration > Duration.zero
            ? effectiveDuration
            : activePlayback.duration;
        if (totalDur > Duration.zero &&
            activePlayback.position >= totalDur) {
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
      TowerPlayerVpcEventHandler.notifyManualSeekInitiated();
      await activePlayback.seek(pos);
      syncActiveSubtitle(overridePos: pos);
      hideSeekPreview();
      if (audioTrackController != null &&
          audioTrackController!.value.isInitialized &&
          !audioTrackController!.value.hasError) {
        final audioDur = audioTrackController!.value.duration;
        if (audioDur == Duration.zero || pos <= audioDur) {
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
    final total = effectiveDuration > Duration.zero
        ? effectiveDuration
        : activePlayback.duration;
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
      if (hasAlternateAudioTrack &&
          audioTrackController != null &&
          !audioTrackController!.value.hasError) {
        videoPlayerController.setVolume(0.0);
        audioTrackController?.setVolume(isMuted.value ? 0.0 : volume.value);
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
      setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 1.0);
    } else {
      _volumeBeforeMute = volume.value > 0 ? volume.value : 1.0;
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
      (_) {
        _totalWatchSeconds++;
        if (Get.isRegistered<GuestPlaybackLimitService>()) {
          GuestPlaybackLimitService.to.onPlaybackActive();
        }
      },
    );
  }

  void stopWatchTimer() {
    timers.cancel('watch');
    if (Get.isRegistered<GuestPlaybackLimitService>()) {
      GuestPlaybackLimitService.to.onPlaybackPaused();
    }
  }
}
