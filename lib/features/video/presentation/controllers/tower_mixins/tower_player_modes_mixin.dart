import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/services/storyboard_service.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/storyboard_thumbnail_widget.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

mixin TowerPlayerModesMixin on GetxController {
  static const MethodChannel pipChannel = MethodChannel(
    'com.example.truthworld/pip',
  );

  VideoPlayerController get videoPlayerController;
  String? get tag;
  VideoController? get videoController;
  void trackAnalytics(PlayerEvent event);
  FocusNode get focusNode;
  RxBool get isFullScreen;
  RxBool get showCommentsPopup;
  RxBool get showTranscriptPopup;
  RxBool get showFactCheckPopup;
  RxBool get showLiveChat;
  RxDouble get aspectRatio;
  void onInteraction();
  void startHideTimer([Duration? timeout]);
  RxBool get controlsVisible;
  RxBool get settingsOpen;
  RxBool get isLooping;
  TimerBag get timers;
  ChewieController? get chewieController;

  final Rx<PlaybackMode> playbackMode = PlaybackMode.video.obs;
  final RxBool isAudioOnly = false.obs;
  bool isSwitchingModes = false;
  final RxString activePanel = ''.obs;
  final RxBool isPiP = false.obs;
  final RxBool seekPreviewVis = false.obs;
  final Rx<Duration> seekPreviewPos = Duration.zero.obs;
  final RxDouble seekPreviewX = 0.0.obs;
  final Rx<StoryboardTrack?> storyboardTrack = Rx<StoryboardTrack?>(null);
  void setStoryboardTrack(StoryboardTrack? track) => storyboardTrack.value = track;
  // ignore: cancel_subscriptions
  StreamSubscription? webFullscreenSub;

  Future<void> toggleAudioOnly({
    String? videoUrl,
    String? title,
    String? artworkUrl,
  }) async {
    if (isSwitchingModes) return;
    isSwitchingModes = true;

    try {
      if (playbackMode.value == PlaybackMode.audio || isAudioOnly.value) {
        playbackMode.value = PlaybackMode.switchingToVideo;

        if (!videoPlayerController.value.isPlaying) {
          await videoPlayerController.play();
        }

        playbackMode.value = PlaybackMode.video;
        isAudioOnly.value = false;
        TowerPlayerController.globalAudioOnly = false;
        try {
          if (Get.isRegistered<VideoController>(tag: tag)) {
            Get.find<VideoController>(tag: tag).isAudioOnly.value = false;
          } else if (Get.isRegistered<VideoController>()) {
            Get.find<VideoController>().isAudioOnly.value = false;
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerModesMixin.syncVideoControllerOff',
          );
        }
        trackAnalytics(PlayerEvent('audio_only_off'));
      } else {
        playbackMode.value = PlaybackMode.switchingToAudio;

        if (!videoPlayerController.value.isPlaying) {
          await videoPlayerController.play();
        }

        playbackMode.value = PlaybackMode.audio;
        isAudioOnly.value = true;
        TowerPlayerController.globalAudioOnly = true;
        try {
          if (Get.isRegistered<VideoController>(tag: tag)) {
            Get.find<VideoController>(tag: tag).isAudioOnly.value = true;
          } else if (Get.isRegistered<VideoController>()) {
            Get.find<VideoController>().isAudioOnly.value = true;
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerModesMixin.syncVideoControllerOn',
          );
        }

        // If user has Audio Premium (or full premium), dismiss any active ad when switching to audio-only
        if (this is TowerPlayerController) {
          final tpc = this as TowerPlayerController;
          if (tpc.shouldSuppressAds && tpc.isShowingAd.value) {
            tpc.finishAd();
          }
        }

        trackAnalytics(PlayerEvent('audio_only_on'));
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerModesMixin.toggleAudioOnly',
      );
      playbackMode.value = isAudioOnly.value
          ? PlaybackMode.audio
          : PlaybackMode.video;
    } finally {
      isSwitchingModes = false;
    }
  }

  void updateSeekPreview(double fraction, double xPixel, Duration total) {
    final pos = Duration(
      milliseconds: (total.inMilliseconds * fraction).toInt(),
    );
    seekPreviewPos.value = pos;
    seekPreviewX.value = xPixel;
    seekPreviewVis.value = true;

    final track = storyboardTrack.value;
    if (track != null) {
      SpriteSheetImageCache.preloadAround(track, pos);
    }
  }

  void hideSeekPreview() => seekPreviewVis.value = false;

  void openSettings([BuildContext? context]) {
    final ctx = context ?? Get.context;
    final isMobilePlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isMobileWidth = ctx != null && (MediaQuery.of(ctx).size.width < 600);
    final isMobile = isMobilePlatform || isMobileWidth;

    activePanel.value = '';
    controlsVisible.value = true;
    timers.cancel('hide');

    if (ctx != null && isMobile && TowerPlayerController.showMobileSettingsCallback != null) {
      if (this is TowerPlayerController) {
        TowerPlayerController.showMobileSettingsCallback!(ctx, this as TowerPlayerController);
      }
    } else {
      settingsOpen.value = true;
    }
  }

  void closeSettings() {
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }
    settingsOpen.value = false;
    activePanel.value = '';
    startHideTimer();
  }

  Future<void> toggleFullscreen() async {
    focusNode.requestFocus();
    final nextState = !isFullScreen.value;
    isFullScreen.value = nextState;
    if (!nextState) {
      showCommentsPopup.value = false;
      showTranscriptPopup.value = false;
      showFactCheckPopup.value = false;
      showLiveChat.value = false;
    }

    try {
      final vc = videoController;
      if (vc != null) {
        vc.isFullScreen.value = nextState;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerModesMixin.syncFullScreen',
      );
    }

    if (kIsWeb) {
      try {
        if (nextState) {
          if (html.document.fullscreenElement == null) {
            html.document.documentElement?.requestFullscreen();
          }
        } else {
          if (html.document.fullscreenElement != null) {
            html.document.exitFullscreen();
          }
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerModesMixin.webFullscreen',
        );
      }
    } else {
      try {
        if (nextState) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          if (aspectRatio.value > 1.0) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          }
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerModesMixin.nativeFullscreen',
        );
      }
    }

    onInteraction();
    trackAnalytics(
      PlayerEvent(nextState ? 'fullscreen_enter' : 'fullscreen_exit'),
    );
  }

  void setupChewieListeners() {
    try {
      chewieController?.removeListener(onInternalChewieChanged);
      chewieController?.addListener(onInternalChewieChanged);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerModesMixin.setupChewieListeners.internal',
      );
    }

    try {
      final vc = videoController;
      if (vc != null && vc.chewieController != null) {
        vc.chewieController!.removeListener(onOuterChewieChanged);
        vc.chewieController!.addListener(onOuterChewieChanged);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerModesMixin.setupChewieListeners.outer',
      );
    }
  }

  void onInternalChewieChanged() {}
  void onOuterChewieChanged() {}

  Future<void> togglePiP() async {
    final success =
        await PipService.to.togglePip(aspectRatio: aspectRatio.value);
    if (!success) {
      final vid = videoController?.video;
      if (vid != null) {
        final pos = videoPlayerController.value.position;
        Get.back();
        MiniplayerController.to.showWithVideo(vid, resumeFromPosition: pos);
      }
    }
  }

  void updateAutoPip(bool isPlaying) {
    PipService.to.updateAutoPip(
      enabled: isPlaying,
      aspectRatio: aspectRatio.value,
    );
  }

  void toggleLoop() {
    isLooping.value = !isLooping.value;
    try {
      videoPlayerController.setLooping(isLooping.value);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerModesMixin.toggleLoop',
      );
    }
  }
}
