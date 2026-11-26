import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/storyboard_service.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/storyboard_thumbnail_widget.dart';
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
  RxDouble get aspectRatio;
  void onInteraction();
  void startHideTimer([Duration? timeout]);
  RxBool get controlsVisible;
  RxBool get settingsOpen;
  RxBool get isLooping;
  TimerBag get timers;
  ChewieController? get chewieController;
  RxBool get showMoreVideos;
  void showToast(String msg);

  final RxBool isTheaterMode = false.obs;

  void toggleMoreVideos() {
    showMoreVideos.value = !showMoreVideos.value;
  }

  void openMoreVideos() {
    showMoreVideos.value = true;
  }

  void closeMoreVideos() {
    showMoreVideos.value = false;
  }

  void toggleTheaterMode() {
    isTheaterMode.value = !isTheaterMode.value;
    showToast(isTheaterMode.value ? 'Theater mode on (t)' : 'Default view (t)');
  }

  final Rx<PlaybackMode> playbackMode = PlaybackMode.video.obs;
  final RxBool isAudioOnly = false.obs;
  VideoResolutionV2? _savedResolutionBeforeAudioOnly;
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

  // ── Visual Evidence Warning Pill ─────────────────────────
  final RxBool visualEvidencePillVisible = false.obs;
  final RxString visualEvidencePillText = ''.obs;
  DateTime _lastVisualEvidencePillTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _visualEvidencePillCount = 0;
  Timer? _visualEvidencePillDismissTimer;

  void evaluateVisualEvidenceSignals(Duration pos) {
    if (!isAudioOnly.value || isPiP.value) {
      if (visualEvidencePillVisible.value) {
        visualEvidencePillVisible.value = false;
      }
      return;
    }

    if (_visualEvidencePillCount >= 3) return;

    final now = DateTime.now();
    if (now.difference(_lastVisualEvidencePillTime).inSeconds < 45) return;

    if (this is TowerPlayerController) {
      final tpc = this as TowerPlayerController;
      final claims = tpc.availableClaims;
      if (claims.isNotEmpty) {
        final posSec = pos.inMilliseconds / 1000.0;
        for (final claim in claims) {
          if (claim.start != null) {
            final s = claim.start!;
            final e = claim.end ?? (s + 8.0);
            if (posSec >= s && posSec <= e) {
              final text = claim.text;
              final isHighSignal = text.length >= 45 ||
                  claim.verdict.toLowerCase().contains('supported') ||
                  claim.verdict.toLowerCase().contains('contradicted');
              if (isHighSignal) {
                _triggerVisualEvidencePill('On-screen evidence presented · Tap to view');
                return;
              }
            }
          }
        }
      }
    }
  }

  void _triggerVisualEvidencePill(String text) {
    visualEvidencePillText.value = text;
    visualEvidencePillVisible.value = true;
    _visualEvidencePillCount++;
    _lastVisualEvidencePillTime = DateTime.now();

    _visualEvidencePillDismissTimer?.cancel();
    _visualEvidencePillDismissTimer = Timer(const Duration(seconds: 6), () {
      visualEvidencePillVisible.value = false;
    });
  }

  void onVisualEvidencePillTap() {
    visualEvidencePillVisible.value = false;
    _visualEvidencePillDismissTimer?.cancel();
    setAudioOnly(false);
  }

  void dismissVisualEvidencePill() {
    visualEvidencePillVisible.value = false;
    _visualEvidencePillDismissTimer?.cancel();
  }

  Future<void> setAudioOnly(bool enabled) async {
    if (isAudioOnly.value == enabled) return;
    await toggleAudioOnly();
  }

  Future<void> toggleAudioOnly({
    String? videoUrl,
    String? title,
    String? artworkUrl,
  }) async {
    if (isSwitchingModes) return;
    isSwitchingModes = true;

    try {
      if (playbackMode.value == PlaybackMode.audio || isAudioOnly.value) {
        dismissVisualEvidencePill();
        _visualEvidencePillCount = 0;
        playbackMode.value = PlaybackMode.video;
        isAudioOnly.value = false;
        TowerPlayerController.globalAudioOnly = false;
        if (Get.arguments is Map) {
          try {
            (Get.arguments as Map)['isAudioOnly'] = false;
          } catch (_) {}
        }
        if (!videoPlayerController.value.isPlaying) {
          try {
            await videoPlayerController.play();
          } catch (_) {}
        }
        if (Get.isRegistered<AudioOnlyService>()) {
          try {
            final audioSvc = Get.find<AudioOnlyService>();
            if (audioSvc.isActive.value || audioSvc.isPlaying.value) {
              audioSvc.deactivateBackgroundPlayback();
            }
          } catch (_) {}
        }
        try {
          final vc = this is TowerPlayerController
              ? (this as TowerPlayerController).videoController
              : (Get.isRegistered<VideoController>(tag: tag)
                  ? Get.find<VideoController>(tag: tag)
                  : (Get.isRegistered<VideoController>()
                      ? Get.find<VideoController>()
                      : null));
          if (vc != null) {
            vc.isAudioOnly.value = false;
            // Restore user's previous resolution if it was saved before switching to audio-only
            if (_savedResolutionBeforeAudioOnly != null &&
                _savedResolutionBeforeAudioOnly!.label.toLowerCase() != 'audio only') {
              final restoreRes = _savedResolutionBeforeAudioOnly!;
              _savedResolutionBeforeAudioOnly = null;
              await vc.setResolution(restoreRes, isManual: false);
            } else {
              _savedResolutionBeforeAudioOnly = null;
              final defaultRes = vc.availableResolutions.firstWhereOrNull(
                    (r) =>
                        r.label.toLowerCase() != 'audio only' &&
                        r.label.toLowerCase() != '144p',
                  ) ??
                  (vc.availableResolutions.isNotEmpty
                      ? vc.availableResolutions.first
                      : null);
              if (defaultRes != null) {
                await vc.setResolution(defaultRes, isManual: false);
              }
            }
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerModesMixin.syncVideoControllerOff',
          );
        }
        controlsVisible.value = true;
        startHideTimer();
        if (!videoPlayerController.value.isPlaying) {
          try {
            await videoPlayerController.play();
          } catch (_) {}
        }
        trackAnalytics(PlayerEvent('audio_only_off'));
      } else {
        dismissVisualEvidencePill();
        _visualEvidencePillCount = 0;
        playbackMode.value = PlaybackMode.audio;
        isAudioOnly.value = true;
        TowerPlayerController.globalAudioOnly = true;
        if (Get.arguments is Map) {
          try {
            (Get.arguments as Map)['isAudioOnly'] = true;
          } catch (_) {}
        }
        if (!videoPlayerController.value.isPlaying) {
          try {
            await videoPlayerController.play();
          } catch (_) {}
        }
        try {
          final vc = this is TowerPlayerController
              ? (this as TowerPlayerController).videoController
              : (Get.isRegistered<VideoController>(tag: tag)
                  ? Get.find<VideoController>(tag: tag)
                  : (Get.isRegistered<VideoController>()
                      ? Get.find<VideoController>()
                      : null));
          if (vc != null) {
            vc.isAudioOnly.value = true;
            _savedResolutionBeforeAudioOnly = vc.currentResolution.value;

            // Tier 1: True Demuxed HLS Audio Track (128 kbps AAC-LC)
            final demuxedAudioUrl = vc.resolveAudioOnlyTargetUrl();
            if (demuxedAudioUrl != null && demuxedAudioUrl.isNotEmpty) {
              final audioRes = VideoResolutionV2(
                label: 'Audio only',
                url: demuxedAudioUrl,
                width: 0,
                height: 0,
                bitrate: 128,
              );
              await vc.setResolution(audioRes, isManual: false);
            } else {
              // Tier 2: Low-bandwidth fallback: Immediately downscale the stream to 144p or lowest resolution tier
              final lowestRes = vc.availableResolutions.firstWhereOrNull(
                    (r) => r.label.toLowerCase() == '144p',
                  ) ??
                  (vc.availableResolutions.isNotEmpty
                      ? vc.availableResolutions.last
                      : null) ??
                  vc.video.adaptiveResolutions.firstWhereOrNull(
                    (r) => r.label.toLowerCase() == '144p',
                  );
              if (lowestRes != null &&
                  vc.currentResolution.value?.url != lowestRes.url) {
                await vc.setResolution(lowestRes, isManual: false);
              }
            }
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

        controlsVisible.value = true;
        startHideTimer();
        if (!videoPlayerController.value.isPlaying) {
          try {
            await videoPlayerController.play();
          } catch (_) {}
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
      try {
        (this as dynamic).resetZoom();
      } catch (_) {}
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
      if (nextState) {
        if (!WebPlatformUtils.isFullscreen()) {
          WebPlatformUtils.requestFullscreen();
        }
      } else {
        if (WebPlatformUtils.isFullscreen()) {
          WebPlatformUtils.exitFullscreen();
        }
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
    // TowerCustomPlayer and TowerPlayerController natively manage full-screen,
    // playback state, and UI controls. Chewie listeners are omitted to eliminate
    // redundant overhead and prevent ChangeNotifier assertions against disposed controller
    // instances during resolution switches.
  }

  void onInternalChewieChanged() {}
  void onOuterChewieChanged() {}

  Future<void> togglePiP() async {
    var hasNext = true;
    var hasPrev = false;
    try {
      final dyn = this as dynamic;
      hasNext = dyn.hasNextVideo as bool? ?? true;
      hasPrev = dyn.hasPreviousVideo as bool? ?? false;
    } catch (_) {}

    final isCurrentlyPlaying = videoPlayerController.value.isInitialized &&
        videoPlayerController.value.isPlaying;

    final success = await PipService.to.togglePip(
      aspectRatio: aspectRatio.value,
      isPlaying: isCurrentlyPlaying,
      hasPrevious: hasPrev,
      hasNext: hasNext,
    );
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
    var hasNext = true;
    var hasPrev = false;
    try {
      final dyn = this as dynamic;
      hasNext = dyn.hasNextVideo as bool? ?? true;
      hasPrev = dyn.hasPreviousVideo as bool? ?? false;
    } catch (_) {}

    PipService.to.updateAutoPip(
      enabled: isPlaying,
      aspectRatio: aspectRatio.value,
      isPlaying: isPlaying,
      hasPrevious: hasPrev,
      hasNext: hasNext,
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
