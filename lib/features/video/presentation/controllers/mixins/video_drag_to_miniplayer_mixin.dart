import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:video_player/video_player.dart';

/// Mixin providing YouTube-style drag-down gesture handling on VideoScreen
/// to smoothly collapse the watch screen into the miniplayer and show the previous screen.
mixin VideoDragToMiniplayerMixin on BaseController, GetTickerProviderStateMixin {
  /// Vertical drag offset in pixels when user drags down on VideoScreen.
  final RxDouble dragDownOffset = 0.0.obs;

  /// Whether a drag-down gesture is actively in progress.
  final RxBool isDraggingDown = false.obs;

  /// Whether the screen is actively dismissing / minimizing to miniplayer.
  final RxBool isDismissingToMiniplayer = false.obs;

  /// Whether the player handoff to miniplayer has completed.
  final RxBool isMiniplayerHandoffDone = false.obs;

  /// Internal guard preventing duplicate execution of minimizeToMiniplayer handoff.
  bool get _isMiniplayerHandoffDone => isMiniplayerHandoffDone.value;
  set _isMiniplayerHandoffDone(bool val) => isMiniplayerHandoffDone.value = val;

  /// Spring animation controller for returning smoothly to top if released below threshold.
  AnimationController? _dragSpringController;
  Animation<double>? _dragSpringAnimation;

  /// Maximum drag distance in pixels for full miniplayer interpolation.
  static const double maxDragDistance = 280.0;

  /// Threshold in pixels to trigger miniplayer minimize.
  static const double minimizeThreshold = 80.0;

  /// Downward velocity threshold (pixels/sec) to trigger miniplayer minimize on flick/fling.
  static const double minimizeVelocityThreshold = 250.0;

  // Contracts required from host VideoController
  Video get video;
  VideoPlayerController? get videoPlayerController;
  set videoPlayerController(VideoPlayerController? value);
  Rx<VideoPlayerController?> get rxVideoPlayerController;
  bool get isVpcInitialized;
  Rx<VideoClip?> get activeClip;
  RxBool get isAudioOnly;
  Rx<VideoResolutionV2?> get currentResolution;
  Stopwatch get watchStopwatch;
  void flushRemainingWatchTime();
  Future<void> syncWatchHistory(int watchSeconds, int totalDuration);
  void videoErrorListener();
  void videoListener();
  ChewieController? get chewieController;
  set chewieController(ChewieController? value);
  void onChewieEvent();
  ScrollController get scrollController;

  /// Vertical scroll offset of the mobile watch screen content feed.
  final RxDouble watchScrollY = 0.0.obs;

  /// Whether the watch screen feed is currently scrolled down.
  bool get isWatchScrolledDown =>
      (scrollController.hasClients && scrollController.offset > 2.0) ||
      watchScrollY.value > 2.0;

  /// Current watch scroll offset directly from scrollController if available.
  double get currentWatchScrollOffset =>
      scrollController.hasClients ? scrollController.offset : watchScrollY.value;

  /// Active drag session forwarding touch gestures from player to scrollController.
  Drag? _feedDrag;
  Drag? get feedDrag => _feedDrag;

  /// Updates watch screen scroll offset from ScrollNotification.
  void onWatchScrollUpdate(double pixels) {
    if ((watchScrollY.value - pixels).abs() > 0.5) {
      watchScrollY.value = pixels;
    }
  }

  /// Starts feeding drag updates to the watch screen's scrollController.
  void onFeedDragStart(DragStartDetails details) {
    if (scrollController.hasClients) {
      _feedDrag?.cancel();
      _feedDrag = scrollController.position.drag(details, () {
        _feedDrag = null;
      });
    }
  }

  /// Updates feed scroll position with 1:1 physics tracking.
  void onFeedDragUpdate(DragUpdateDetails details) {
    _feedDrag?.update(details);
  }

  /// Ends the feed drag with native Flutter inertial ballistic fling momentum.
  void onFeedDragEnd([dynamic details]) {
    if (details is DragEndDetails) {
      _feedDrag?.end(details);
    } else {
      _feedDrag?.cancel();
    }
    _feedDrag = null;
  }

  /// Cancels feed drag.
  void onFeedDragCancel() {
    _feedDrag?.cancel();
    _feedDrag = null;
  }

  /// Initializes the drag-to-miniplayer animation controller.
  void initDragToMiniplayer() {
    resetDragState();
    _dragSpringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _dragSpringController!.addListener(() {
      if (_dragSpringAnimation != null) {
        dragDownOffset.value = _dragSpringAnimation!.value;
      }
    });
  }

  /// Resets drag and dismiss flags to allow fresh gestures on new video loads.
  void resetDragState() {
    isMiniplayerHandoffDone.value = false;
    isDismissingToMiniplayer.value = false;
    isDraggingDown.value = false;
    dragDownOffset.value = 0.0;
    watchScrollY.value = 0.0;
    _feedDrag?.cancel();
    _feedDrag = null;
    _dragSpringController?.stop();
  }

  /// Called when the user initiates a drag-down gesture.
  void onDragDownStart([DragStartDetails? details]) {
    if (_isMiniplayerHandoffDone || isDismissingToMiniplayer.value) return;
    _dragSpringController?.stop();
    isDraggingDown.value = true;
  }

  /// Called on each drag delta update with direct 1:1 finger tracking.
  void onDragDownDelta(double delta) {
    if (_isMiniplayerHandoffDone || isDismissingToMiniplayer.value) return;
    isDraggingDown.value = true;
    _dragSpringController?.stop();
    final current = dragDownOffset.value;
    final updated = (current + delta).clamp(0.0, 900.0);
    dragDownOffset.value = updated;
  }

  /// Called when drag finishes. Evaluates threshold and downward velocity.
  void onDragDownEnd([double? velocity, double? targetScreenHeight]) {
    if (_isMiniplayerHandoffDone || isDismissingToMiniplayer.value) return;
    isDraggingDown.value = false;

    final currentOffset = dragDownOffset.value;
    final vel = velocity ?? 0.0;

    if (currentOffset >= minimizeThreshold || vel >= minimizeVelocityThreshold) {
      isDismissingToMiniplayer.value = true;
      update();
      _animateDismissDown(maxDragDistance);
    } else {
      animateDragBack();
    }
  }

  /// Called when drag is canceled by gesture arena or system interruption.
  void onDragDownCancel() {
    if (_isMiniplayerHandoffDone || isDismissingToMiniplayer.value) return;
    // If finger has already passed threshold when canceled, commit to dismiss rather than snapping back
    if (dragDownOffset.value >= minimizeThreshold) {
      isDismissingToMiniplayer.value = true;
      update();
      _animateDismissDown(maxDragDistance);
      return;
    }
    isDraggingDown.value = false;
    animateDragBack();
  }

  /// Smoothly animates drag down offset back to zero (original position).
  void animateDragBack() {
    if (_dragSpringController == null) {
      dragDownOffset.value = 0.0;
      return;
    }
    _dragSpringController!.stop();
    _dragSpringAnimation = Tween<double>(
      begin: dragDownOffset.value,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _dragSpringController!,
        curve: Curves.easeOutCubic,
      ),
    );
    _dragSpringController!.duration = const Duration(milliseconds: 180);
    _dragSpringController!.forward(from: 0.0).then((_) {
      dragDownOffset.value = 0.0;
    });
  }

  /// Smoothly animates the player into the docked miniplayer position and performs handoff.
  void _animateDismissDown(double targetDistance) {
    isDismissingToMiniplayer.value = true;
    isDraggingDown.value = false;
    update();
    if (_dragSpringController == null || dragDownOffset.value >= targetDistance) {
      dragDownOffset.value = targetDistance;
      minimizeToMiniplayer();
      return;
    }
    _dragSpringController!.stop();
    _dragSpringAnimation = Tween<double>(
      begin: dragDownOffset.value,
      end: targetDistance,
    ).animate(
      CurvedAnimation(
        parent: _dragSpringController!,
        curve: Curves.easeOutCubic,
      ),
    );
    _dragSpringController!.duration = const Duration(milliseconds: 180);
    _dragSpringController!.forward(from: 0.0).then((_) {
      dragDownOffset.value = targetDistance;
      minimizeToMiniplayer();
    });
  }

  /// Smoothly animates drag down to miniplayer and minimizes (used on tap minimize or back button).
  void minimizeWithAnimation() {
    if (isMiniplayerHandoffDone.value || isDismissingToMiniplayer.value) return;
    if (video.id.isEmpty) return;
    isDismissingToMiniplayer.value = true;
    update();
    if (_dragSpringController != null && dragDownOffset.value == 0.0) {
      _animateDismissDown(maxDragDistance);
    } else {
      minimizeToMiniplayer();
    }
  }

  /// Minimizes the current video to the miniplayer and returns to the previous screen.
  Future<void> minimizeToMiniplayer() async {
    if (isMiniplayerHandoffDone.value) return;
    if (video.id.isEmpty) return;
    isMiniplayerHandoffDone.value = true;
    isDismissingToMiniplayer.value = true;
    isDraggingDown.value = false;
    // Maintain maximum drag distance offset so the watch screen remains fully transparent
    // and docked while popping, completely preventing any snap-back blink.
    dragDownOffset.value = maxDragDistance;
    _dragSpringController?.stop();
    update();

    // Capture playback position
    var pos = Duration.zero;
    try {
      if (isVpcInitialized && videoPlayerController != null) {
        pos = videoPlayerController!.value.position;
      }
    } catch (_) {}

    final videoToPlay = video;
    final activeClipToPlay = activeClip.value;
    final isAudioOnlyToPlay = isAudioOnly.value;
    final selectedResUrl = currentResolution.value?.url;

    // Sync watch history before popping
    try {
      if (isVpcInitialized && videoPlayerController != null) {
        final totalDuration = videoPlayerController!.value.duration.inSeconds;
        final watchSeconds = watchStopwatch.elapsed.inSeconds;
        flushRemainingWatchTime();
        syncWatchHistory(watchSeconds, totalDuration);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoDragToMiniplayerMixin.minimizeToMiniplayer.syncHistory',
      );
    }

    final durSec = isVpcInitialized && videoPlayerController != null
        ? videoPlayerController!.value.duration.inSeconds
        : videoToPlay.durationSeconds;
    final isNearEnd = durSec > 0 &&
        (pos.inSeconds >= (durSec - 10) || (pos.inSeconds / durSec) >= 0.90);
    final isFullyWatched = Get.isRegistered<WatchHistoryService>() &&
        WatchHistoryService.to.isVideoFullyWatched(videoToPlay.id, totalDuration: durSec);
    final isNearStart = pos < const Duration(seconds: 5);

    final isEligible = !isNearEnd && !isFullyWatched && !isNearStart && pos > Duration.zero;

    // Register active controller for zero-latency handoff to miniplayer
    if (videoPlayerController != null && !kIsWeb) {
      try {
        videoPlayerController!.removeListener(videoErrorListener);
        videoPlayerController!.removeListener(videoListener);
      } catch (_) {}
      try {
        chewieController?.removeListener(onChewieEvent);
        chewieController?.dispose();
      } catch (_) {}
      chewieController = null;

      if (isEligible) {
        VideoPlaybackHandoff.registerActiveController(
          videoToPlay.id,
          videoPlayerController!,
          position: pos,
        );
      } else {
        VideoPlaybackHandoff.clear(videoToPlay.id);
        try {
          videoPlayerController!.seekTo(Duration.zero);
        } catch (_) {}
        VideoPlaybackHandoff.registerActiveController(
          videoToPlay.id,
          videoPlayerController!,
          position: Duration.zero,
        );
      }
      videoPlayerController = null;
      rxVideoPlayerController.value = null;
    } else {
      if (isEligible) {
        VideoPlaybackHandoff.registerResumePosition(videoToPlay.id, pos);
      } else {
        VideoPlaybackHandoff.clear(videoToPlay.id);
      }
    }

    // Launch video in miniplayer synchronously/immediately before popping route
    try {
      unawaited(
        MiniplayerController.to.showWithVideo(
          videoToPlay,
          resumeFromPosition: isEligible ? pos : Duration.zero,
          overrideUrl: selectedResUrl,
          clip: activeClipToPlay,
          isAudioOnly: isAudioOnlyToPlay,
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoDragToMiniplayerMixin.minimizeToMiniplayer.showWithVideo',
      );
    }

    // Safely pop all watch screens back to the underlying screen or home.
    void performPop() {
      try {
        final hasWatch = RouteStackObserver.hasRoute('/watch') ||
            RouteStackObserver.hasRoute('watch');
        if (hasWatch) {
          Get.until((route) {
            if (route.isFirst) return true;
            final name = route.settings.name;
            if (name == null) return false; // Pop modal sheets/dialogs on top of watch
            return !name.toLowerCase().contains('watch'); // Pop watch screen
          });
          // Extra safety: if watch is still in stack, navigate to home cleanly
          if (RouteStackObserver.hasRoute('/watch') ||
              RouteStackObserver.hasRoute('watch')) {
            RouteStackObserver.navigateToHome();
          }
        } else if (Get.key.currentState?.canPop() == true) {
          Get.back();
        } else {
          RouteStackObserver.navigateToHome();
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'VideoDragToMiniplayerMixin.minimizeToMiniplayer.performPop',
        );
        RouteStackObserver.navigateToHome();
      }
    }

    if (Get.testMode) {
      performPop();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => performPop());
    }
  }

  /// Disposes animation resources.
  void disposeDragToMiniplayer() {
    _feedDrag?.cancel();
    _feedDrag = null;
    _dragSpringController?.dispose();
    _dragSpringController = null;
    isMiniplayerHandoffDone.value = false;
    isDismissingToMiniplayer.value = false;
    isDraggingDown.value = false;
    dragDownOffset.value = 0.0;
    watchScrollY.value = 0.0;
  }
}
