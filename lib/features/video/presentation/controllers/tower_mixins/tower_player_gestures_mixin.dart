import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerGesturesMixin on GetxController {
  FocusNode get focusNode;
  RxBool get settingsOpen;
  void closeSettings();
  RxBool get isShowingAd;
  RxBool get controlsVisible;
  RxBool get isDragging;
  RxBool get showCommentsPopup;
  RxBool get showTranscriptPopup;
  RxBool get showFactCheckPopup;
  RxBool get isFullScreen;
  void toggleFullscreen();
  Future<void> togglePlayPause();
  VideoPlayerValue get vv;
  RxBool get isMuted;
  RxDouble get volume;
  VideoPlayerController get videoPlayerController;
  TimerBag get timers;
  Future<void> seekRelative(int seconds, {bool showFeedbackToast = true});
  int get seekStepSeconds;

  // Swipe HUD
  final RxDouble brightness = 1.0.obs;
  final RxBool showSwipeVolumeHUD = false.obs;
  final RxBool showSwipeBrightnessHUD = false.obs;
  final RxDouble swipeVolumeLevel = 0.0.obs;
  final RxDouble swipeBrightnessLevel = 0.0.obs;

  // Double tap
  final RxBool showDoubleTapLeft = false.obs;
  final RxBool showDoubleTapRight = false.obs;
  final RxInt doubleTapSeconds = 0.obs;
  Timer? singleTapTimer;
  DateTime? lastTapTime;
  double lastTapX = 0;
  double doubleTapX = 0;

  void startHideTimer([Duration? timeout]);
  void setVolume(double val);
  Future<void> seekTo(Duration position);

  void cancelPendingTap() {
    singleTapTimer?.cancel();
    singleTapTimer = null;
    lastTapTime = null;
  }

  void handlePlayerTap(double tapX, double playerWidth, bool isDesktop) {
    focusNode.requestFocus();
    if (settingsOpen.value) {
      closeSettings();
      return;
    }
    if (isShowingAd.value) return;

    final now = DateTime.now();
    final half = playerWidth / 2;
    final isLeft = tapX < half;

    if (showDoubleTapLeft.value || showDoubleTapRight.value) {
      if (isLeft && showDoubleTapLeft.value) {
        executeDoubleTapSeek(isLeft: true);
        return;
      } else if (!isLeft && showDoubleTapRight.value) {
        executeDoubleTapSeek(isLeft: false);
        return;
      } else {
        executeDoubleTapSeek(isLeft: isLeft, resetAccumulator: true);
        return;
      }
    }

    final isRecentTap = lastTapTime != null &&
        now.difference(lastTapTime!).inMilliseconds < 350;
    final isSameHalf = (tapX < half) == (lastTapX < half);

    if (isRecentTap && isSameHalf) {
      singleTapTimer?.cancel();
      singleTapTimer = null;
      lastTapTime = null;
      executeDoubleTapSeek(isLeft: isLeft, resetAccumulator: true);
    } else {
      lastTapTime = now;
      lastTapX = tapX;

      singleTapTimer?.cancel();
      singleTapTimer = Timer(const Duration(milliseconds: 260), () {
        singleTapTimer = null;
        lastTapTime = null;
        onTap(isDesktop);
      });
    }
  }

  void toggleControls() {
    if (controlsVisible.value) {
      timers.cancel('hide');
      controlsVisible.value = false;
    } else {
      controlsVisible.value = true;
      startHideTimer();
    }
  }

  void onTap(bool isDesktop) {
    focusNode.requestFocus();
    if (settingsOpen.value) {
      closeSettings();
      return;
    }
    final isTouch = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isTouch && isDesktop) {
      togglePlayPause();
    } else {
      toggleControls();
    }
  }

  void onInteraction() {
    if (!controlsVisible.value) controlsVisible.value = true;
    if (!isMuted.value && videoPlayerController.value.volume == 0.0) {
      try {
        videoPlayerController.setVolume(volume.value > 0 ? volume.value : 1.0);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerGesturesMixin.onInteraction',
        );
      }
    }
    if (!isDragging.value) startHideTimer();
  }

  void onDoubleTapDown(double x) => doubleTapX = x;

  void onDoubleTap(double playerWidth) {
    final half = playerWidth / 2;
    if (doubleTapX < half) {
      doubleTapLeft();
    } else {
      doubleTapRight();
    }
  }

  void executeDoubleTapSeek({
    required bool isLeft,
    bool resetAccumulator = false,
  }) {
    final step = seekStepSeconds;
    if (resetAccumulator ||
        (isLeft ? !showDoubleTapLeft.value : !showDoubleTapRight.value)) {
      doubleTapSeconds.value = step;
    } else {
      doubleTapSeconds.value += step;
    }

    if (isLeft) {
      showDoubleTapRight.value = false;
      showDoubleTapLeft.value = true;
      seekRelative(-step, showFeedbackToast: false);
      timers.set(
        'doubleTapDismiss',
        const Duration(milliseconds: 750),
        () {
          showDoubleTapLeft.value = false;
          doubleTapSeconds.value = 0;
        },
      );
    } else {
      showDoubleTapLeft.value = false;
      showDoubleTapRight.value = true;
      seekRelative(step, showFeedbackToast: false);
      timers.set(
        'doubleTapDismiss',
        const Duration(milliseconds: 750),
        () {
          showDoubleTapRight.value = false;
          doubleTapSeconds.value = 0;
        },
      );
    }
  }

  void doubleTapLeft() => executeDoubleTapSeek(isLeft: true);
  void doubleTapRight() => executeDoubleTapSeek(isLeft: false);

  Offset _dragStartPos = Offset.zero;
  Offset _dragAccumulated = Offset.zero;
  bool _intentResolved = false;
  bool _isVerticalSwipeActive = false;

  void onVerticalDragStart(DragStartDetails d, Size size) {
    _dragStartPos = d.localPosition;
    _dragAccumulated = Offset.zero;
    _intentResolved = false;
    _isVerticalSwipeActive = false;
  }

  void onVerticalDragUpdate(DragUpdateDetails d, Size size) {
    _dragAccumulated += d.delta;

    // Movement intent threshold (12px): ensures intentional vertical movement
    if (!_intentResolved) {
      if (_dragAccumulated.dy.abs() > 12.0 || _dragAccumulated.dx.abs() > 12.0) {
        _intentResolved = true;
        // Only activate if vertical movement is dominant (avoids accidental triggers)
        if (_dragAccumulated.dy.abs() > _dragAccumulated.dx.abs() * 1.25) {
          _isVerticalSwipeActive = true;
        }
      }
    }

    if (!_isVerticalSwipeActive || size.height <= 0) return;

    final isLeft = _dragStartPos.dx < size.width / 2;
    final delta = -d.delta.dy / size.height;

    if (isLeft) {
      // Left vertical zone = Screen Brightness
      brightness.value = (brightness.value + delta).clamp(0.0, 1.0);
      showSwipeBrightnessHUD.value = true;
      swipeBrightnessLevel.value = brightness.value;
    } else {
      // Right vertical zone = Audio Volume
      final newVol = (volume.value + delta).clamp(0.0, 1.0);
      setVolume(newVol);
      showSwipeVolumeHUD.value = true;
      swipeVolumeLevel.value = newVol;
    }
  }

  void onVerticalDragEnd(DragEndDetails d) {
    showSwipeBrightnessHUD.value = false;
    showSwipeVolumeHUD.value = false;
    _intentResolved = false;
    _isVerticalSwipeActive = false;

    final velocity = d.primaryVelocity ?? 0;
    if (velocity < -500) {
      if (!isFullScreen.value) toggleFullscreen();
    } else if (velocity > 500) {
      if (isFullScreen.value) toggleFullscreen();
    }
  }
}
