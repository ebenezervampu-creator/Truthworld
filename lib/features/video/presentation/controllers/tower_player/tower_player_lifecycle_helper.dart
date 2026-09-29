import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_preferences.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

/// Helper handling complex initialization routines for ads and web fullscreen listeners.
class TowerPlayerLifecycleHelper {
  /// Check whether initial playback originates from miniplayer or active position handoff
  static bool isFromMiniplayerOrResumed({
    required dynamic arguments,
    required String? tag,
    required String? videoId,
    required Duration currentPosition,
  }) {
    return (arguments is Map && arguments['isFromMiniplayer'] == true) ||
        VideoPlaybackHandoff.hasActivePosition(tag ?? videoId ?? '') ||
        currentPosition > Duration.zero;
  }

  /// Trigger initial pre-roll sponsor or skippable video ad if eligible
  static void triggerInitialPreRollAd({
    required bool isClosed,
    required bool shouldSuppressAds,
    required bool isFromMiniplayer,
    required bool preRollPlayed,
    required String? videoId,
    required VideoPlayerController videoPlayerController,
    required void Function(dynamic ad, {required bool isPreRoll}) onStartSponsorAd,
    required void Function({required bool isPreRoll}) onStartAd,
    required void Function(bool played) setPreRollPlayed,
  }) {
    final initialSponsorAd = Get.isRegistered<AdService>()
        ? AdService.to.getSponsorAdForVideo(videoId)
        : null;
    final hasInitialAds = !shouldSuppressAds &&
        !isFromMiniplayer &&
        Get.isRegistered<AdService>() &&
        (initialSponsorAd != null ||
            AdService.to.getSkippableVideoAds().isNotEmpty);

    if (hasInitialAds && !preRollPlayed) {
      setPreRollPlayed(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        if (videoPlayerController.value.isPlaying) {
          try {
            videoPlayerController.pause();
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'TowerPlayerLifecycleHelper.pausePreRoll',
            );
          }
        }
        if (initialSponsorAd != null) {
          onStartSponsorAd(initialSponsorAd, isPreRoll: true);
        } else {
          onStartAd(isPreRoll: true);
        }
      });
    }
  }

  /// Initialize HTML DOM fullscreen change listener on web platforms
  static StreamSubscription? initWebFullscreenListener({
    required RxBool isFullScreen,
    required VideoController? Function() getVideoController,
    required VoidCallback onInteraction,
  }) {
    if (!kIsWeb) return null;
    return html.document.onFullscreenChange.listen((_) {
      final isFs = html.document.fullscreenElement != null;
      if (isFullScreen.value != isFs) {
        isFullScreen.value = isFs;
        try {
          final vc = getVideoController();
          if (vc != null) {
            vc.isFullScreen.value = isFs;
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerLifecycleHelper.webFullscreenSync',
          );
        }
        onInteraction();
      }
    });
  }

  /// Disposes audio controller, ad controller, timers, and platform listeners
  static void disposeControllers({
    required VideoPlayerController? adPlayerController,
    required VideoPlayerController? audioTrackController,
    required VideoPlayerController videoPlayerController,
    required StreamSubscription? webFullscreenSub,
    required Timer? errorDebounceTimer,
    required Timer? singleTapTimer,
    required Timer? autoplayTimer,
    required FocusNode focusNode,
    required bool isFullScreen,
    required void Function() onAdVpcUpdate,
    required void Function() onVpcUpdate,
  }) {
    if (adPlayerController != null) {
      try {
        adPlayerController.removeListener(onAdVpcUpdate);
        adPlayerController.dispose();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.dispose.adPlayer');
      }
    }
    if (audioTrackController != null) {
      try {
        audioTrackController.dispose();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.dispose.audioTrack');
      }
    }
    autoplayTimer?.cancel();
    webFullscreenSub?.cancel();
    if (isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    errorDebounceTimer?.cancel();
    singleTapTimer?.cancel();
    focusNode.dispose();
    try {
      videoPlayerController.removeListener(onVpcUpdate);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.dispose.removeVpcListener');
    }
  }

  /// Synchronizes video player controller instance and resets playback state
  static (VideoPlaybackSource, bool) syncController({
    required VideoPlayerController currentVpc,
    required VideoPlayerController newVpc,
    required PlaybackSource? currentSource,
    required bool isShowingAd,
    required void Function() onVpcUpdate,
  }) {
    if (currentVpc != newVpc || currentSource == null) {
      try {
        currentVpc.removeListener(onVpcUpdate);
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.sync.removeListener');
      }
      try {
        currentSource?.dispose();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.sync.disposeSource');
      }
    }

    if (isShowingAd) {
      try {
        newVpc.pause();
        newVpc.seekTo(Duration.zero);
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.sync.pauseAd');
      }
    }

    try {
      newVpc.addListener(onVpcUpdate);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.sync.addListener');
    }

    final source = VideoPlaybackSource(newVpc);
    return (source, newVpc.value.isInitialized);
  }

  /// Loads user playback settings (nerd stats, autoplay) safely
  static void loadUserSettings({
    required String? tag,
    required RxBool showStatsForNerds,
    required RxBool isAutoplay,
  }) {
    try {
      if (Get.isRegistered<UserSettingsController>()) {
        final settings = UserSettingsController.to;
        showStatsForNerds.value = settings.playback.value.statsForNerdsEnabled;
        isAutoplay.value = settings.playback.value.autoplayNext;
      } else if (tag != null && Get.isRegistered<VideoController>(tag: tag)) {
        isAutoplay.value = Get.find<VideoController>(tag: tag).isAutoplay.value;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.loadUserSettings');
    }
  }

  /// Applies initial preferences including persistent subtitles, audio-only, and playback speed
  static void applyInitialPreferences({
    required dynamic arguments,
    required RxBool subtitlesEnabled,
    required RxString activeSubLang,
    required RxBool isAudioOnly,
    required RxDouble playbackSpeed,
    required VideoPlayerController vpc,
    required VoidCallback onToggleAudioOnly,
    required bool Function() isClosed,
  }) {
    subtitlesEnabled.value = TowerPlayerPreferences.globalSubtitlesEnabled;
    activeSubLang.value = TowerPlayerPreferences.globalActiveSubLang;
    final shouldAudioOnly =
        arguments is Map && arguments['isAudioOnly'] == true;
    isAudioOnly.value = shouldAudioOnly;
    playbackSpeed.value = TowerPlayerPreferences.globalPlaybackSpeed;

    if (playbackSpeed.value != 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isClosed() &&
            (vpc.value.playbackSpeed - playbackSpeed.value).abs() > 0.001) {
          try {
            vpc.setPlaybackSpeed(playbackSpeed.value);
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerLifecycleHelper.setPlaybackSpeed');
          }
        }
      });
    }

    if (shouldAudioOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isClosed()) {
          onToggleAudioOnly();
        }
      });
    }
  }
}
