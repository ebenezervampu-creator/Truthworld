import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
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
  RxBool get showMoreVideos;
  void openMoreVideos();
  void closeMoreVideos();
  RxBool get isFullScreen;
  void toggleFullscreen();
  Future<void> togglePlayPause();
  VideoPlayerValue get vv;
  RxBool get isMuted;
  RxDouble get volume;
  VideoPlayerController get videoPlayerController;
  VideoPlayerController? get audioTrackController;
  bool get hasAlternateAudioTrack;
  TimerBag get timers;
  Future<void> seekRelative(int seconds, {bool showFeedbackToast = true});
  int get seekStepSeconds;
  bool get isZoomedIn;
  void resetZoom({bool animated = false});
  void showToast(String msg);
  VideoController? get videoController;

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

  DateTime? _suppressHoverUntil;

  bool get isHoverSuppressed =>
      _suppressHoverUntil != null &&
      DateTime.now().isBefore(_suppressHoverUntil!);

  void suppressHoverFor([
    Duration duration = const Duration(milliseconds: 600),
  ]) {
    _suppressHoverUntil = DateTime.now().add(duration);
  }

  void startHideTimer([Duration? timeout]);
  void setVolume(double val);
  Future<void> seekTo(Duration position);
  void hideSeekPreview();

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

    // Web: if controls are already showing, tapping anywhere on the video viewport
    // closes them immediately.
    if (kIsWeb && controlsVisible.value) {
      cancelPendingTap();
      suppressHoverFor();
      toggleControls();
      return;
    }

    if (kIsWeb &&
        (showCommentsPopup.value ||
            showTranscriptPopup.value ||
            showFactCheckPopup.value ||
            showMoreVideos.value)) {
      showCommentsPopup.value = false;
      showTranscriptPopup.value = false;
      showFactCheckPopup.value = false;
      closeMoreVideos();
      return;
    }

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
      if (isZoomedIn && tapX > playerWidth * 0.25 && tapX < playerWidth * 0.75) {
        resetZoom(animated: true);
        showToast('Original');
        return;
      }
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
      hideSeekPreview();
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
    if (kIsWeb) {
      if (controlsVisible.value) {
        suppressHoverFor();
      }
      toggleControls();
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

  /// On Web: handles tapping the background dismiss layer when controls are visible.
  void onBackgroundTapWeb() {
    focusNode.requestFocus();
    if (settingsOpen.value) {
      closeSettings();
      return;
    }
    if (showCommentsPopup.value ||
        showTranscriptPopup.value ||
        showFactCheckPopup.value ||
        showMoreVideos.value) {
      showCommentsPopup.value = false;
      showTranscriptPopup.value = false;
      showFactCheckPopup.value = false;
      closeMoreVideos();
      return;
    }
    cancelPendingTap();
    suppressHoverFor();
    toggleControls();
  }

  void onInteraction() {
    if (kIsWeb && isHoverSuppressed) return;
    if (!controlsVisible.value) controlsVisible.value = true;
    if (!isMuted.value) {
      if (hasAlternateAudioTrack) {
        if (videoPlayerController.value.volume > 0.0) {
          try {
            videoPlayerController.setVolume(0.0);
          } catch (_) {}
        }
        if (audioTrackController != null &&
            audioTrackController!.value.isInitialized &&
            audioTrackController!.value.volume == 0.0) {
          try {
            audioTrackController!.setVolume(volume.value > 0 ? volume.value : 1.0);
          } catch (_) {}
        }
      } else if (videoPlayerController.value.volume == 0.0) {
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
  Size _dragViewportSize = Size.zero;
  bool _intentResolved = false;
  bool _isVerticalSwipeActive = false;
  bool _isMoreVideosSwipe = false;

  /// Checks whether a local touch/scroll point is located in the Jio Hotstar
  /// More Videos trigger zone: the horizontal middle of the player, strictly
  /// in the area down of the pause/play and next/previous video buttons.
  bool isInMoreVideosZone(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return false;

    // Horizontally: middle of the video player (between 25% and 75% width)
    final isMiddleX = localPosition.dx >= size.width * 0.25 &&
        localPosition.dx <= size.width * 0.75;

    // Vertically: strictly down of the pause/play and previous/next buttons
    // Center controls are at height * 0.5 with ~32-36px button radius
    final centerControlsBottom = (size.height * 0.5) + 30.0;
    final isDownOfCenterControls = localPosition.dy >= centerControlsBottom &&
        localPosition.dy <= size.height;

    return isMiddleX && isDownOfCenterControls;
  }

  void onVerticalDragStart(DragStartDetails d, Size size) {
    _dragStartPos = d.localPosition;
    _dragViewportSize = size;
    _dragAccumulated = Offset.zero;
    _intentResolved = false;
    _isVerticalSwipeActive = false;
    _isMoreVideosSwipe =
        isFullScreen.value && isInMoreVideosZone(d.localPosition, size);
  }

  void onVerticalDragUpdate(DragUpdateDetails d, Size size) {
    _dragViewportSize = size;
    _dragAccumulated += d.delta;

    // Movement intent threshold: ensures intentional vertical movement
    if (!_intentResolved) {
      if (!isFullScreen.value) {
        final isScrolledDown = videoController?.isWatchScrolledDown ?? false;
        // In portrait mode:
        // Downward drag when at top -> miniplayer drag
        // Upward drag OR downward drag when already scrolled down -> scroll the watch feed!
        if (_dragAccumulated.dy > 6.0 && !isScrolledDown) {
          _intentResolved = true;
          _isVerticalSwipeActive = true;
          cancelPendingTap();
          videoController?.onDragDownStart();
        } else if (_dragAccumulated.dy < -6.0 || (_dragAccumulated.dy > 6.0 && isScrolledDown)) {
          _intentResolved = true;
          _isVerticalSwipeActive = true;
          cancelPendingTap();
          videoController?.onFeedDragStart(
            DragStartDetails(
              globalPosition: d.globalPosition,
              localPosition: d.localPosition,
            ),
          );
        } else if (_dragAccumulated.dx.abs() > 32.0 && _dragAccumulated.dy.abs() < 10.0) {
          _intentResolved = true;
          _isVerticalSwipeActive = false;
        }
      } else {
        if (_dragAccumulated.dy.abs() > 12.0 || _dragAccumulated.dx.abs() > 12.0) {
          _intentResolved = true;
          // Only activate if vertical movement is dominant (avoids accidental triggers)
          if (_dragAccumulated.dy.abs() > _dragAccumulated.dx.abs() * 1.25) {
            _isVerticalSwipeActive = true;
            cancelPendingTap();
          }
        }
      }
    }

    if (!_isVerticalSwipeActive || size.height <= 0) return;

    // When NOT in fullscreen mode (portrait watch view):
    // Dragging down from top minimizes to miniplayer like YouTube!
    // Dragging up or dragging while scrolled down feeds smoothly to watch scroll feed!
    if (!isFullScreen.value) {
      if ((videoController?.dragDownOffset.value ?? 0) > 0 ||
          (_dragAccumulated.dy > 0 &&
              !(videoController?.isWatchScrolledDown ?? false) &&
              videoController?.feedDrag == null)) {
        cancelPendingTap();
        videoController?.onDragDownDelta(d.delta.dy);
      } else {
        cancelPendingTap();
        videoController?.onFeedDragUpdate(d);
      }
      return;
    }

    // In fullscreen:
    // If drag started in More Videos zone (middle area down of center controls) and moving upward:
    // Dedicated to opening More Videos like Jio Hotstar; avoid volume/brightness HUDs.
    if (_isMoreVideosSwipe && _dragAccumulated.dy < 0) {
      return;
    }

    // If More Videos is currently open and user is swiping down to dismiss:
    if (showMoreVideos.value && _dragAccumulated.dy > 0) {
      return;
    }

    // Dedicated Brightness & Volume zones like Jio Hotstar:
    // Left vertical zone (left 35% of player) = Screen Brightness
    // Right vertical zone (right 35% of player) = Audio Volume
    // Middle vertical zone (35% to 65%) = Neither brightness nor volume
    final isLeft = _dragStartPos.dx < size.width * 0.35;
    final isRight = _dragStartPos.dx > size.width * 0.65;
    final delta = -d.delta.dy / size.height;

    if (isLeft) {
      // Left vertical zone = Screen Brightness
      brightness.value = (brightness.value + delta).clamp(0.0, 1.0);
      showSwipeBrightnessHUD.value = true;
      swipeBrightnessLevel.value = brightness.value;
    } else if (isRight) {
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

    final velocity = d.primaryVelocity ?? d.velocity.pixelsPerSecond.dy;

    // When NOT in fullscreen mode:
    if (!isFullScreen.value) {
      final currentDrag = videoController?.dragDownOffset.value ?? 0.0;
      if (currentDrag > 0) {
        videoController?.onDragDownEnd(velocity);
        return;
      }
      if (videoController?.feedDrag != null) {
        videoController?.onFeedDragEnd(d);
        return;
      }
      videoController?.onDragDownCancel();
      if (velocity < -500 && (videoController?.currentWatchScrollOffset ?? 0.0) <= 0.0) {
        toggleFullscreen();
      }
      return;
    }

    // In fullscreen:
    if (isFullScreen.value) {
      // 1. If More Videos is open and user swipes down, close it
      if (showMoreVideos.value && (velocity > 200 || _dragAccumulated.dy > 40)) {
        closeMoreVideos();
        _isMoreVideosSwipe = false;
        return;
      }

      // 2. Exactly like Jio Hotstar: ONLY open More Videos when gesture originated
      // in the middle of the player down of the pause/play and next/previous icons:
      final originatedInMoreVideosZone = _isMoreVideosSwipe ||
          isInMoreVideosZone(_dragStartPos, _dragViewportSize);

      if (originatedInMoreVideosZone &&
          (velocity < -200 || _dragAccumulated.dy < -40)) {
        openMoreVideos();
        _isMoreVideosSwipe = false;
        return;
      }
    }
    _isMoreVideosSwipe = false;

    if (velocity < -500) {
      if (!isFullScreen.value) toggleFullscreen();
    } else if (velocity > 500) {
      if (isFullScreen.value && !showMoreVideos.value) toggleFullscreen();
    }
  }

  void onVerticalDragCancel() {
    showSwipeBrightnessHUD.value = false;
    showSwipeVolumeHUD.value = false;
    _intentResolved = false;
    _isVerticalSwipeActive = false;
    if (!isFullScreen.value) {
      videoController?.onDragDownCancel();
      videoController?.onFeedDragCancel();
    }
  }
}
