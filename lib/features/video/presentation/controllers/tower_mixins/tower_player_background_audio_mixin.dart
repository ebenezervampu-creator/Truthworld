import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerBackgroundAudioMixin on GetxController {
  // Host controller dependencies
  VideoPlayerController get videoPlayerController;
  VideoController? get videoController;
  RxBool get isPiP;
  void playNext();
  void playPrevious();
  void onTrackEnded();

  AudioOnlyService? audioService;
  bool isBackgroundAudioActive = false;
  bool _isBackgroundTransitioning = false;
  bool _shouldExitBackgroundOnComplete = false;

  void initAudioService() {
    if (!Get.isRegistered<AudioOnlyService>()) {
      Get.put(AudioOnlyService());
    }
    audioService = Get.find<AudioOnlyService>();
    audioService!.setCallbacks(
      onNext: playNext,
      onPrevious: playPrevious,
      onEnded: onTrackEnded,
    );
  }

  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _shouldExitBackgroundOnComplete = false;
      if (isBackgroundAudioActive || _isBackgroundTransitioning) return;
      if (Get.isRegistered<UserSettingsController>()) {
        final mode =
            UserSettingsController.to.playback.value.backgroundPlaybackMode;
        if (mode == 'Off' && !isPiP.value) {
          if (videoPlayerController.value.isInitialized &&
              videoPlayerController.value.isPlaying) {
            try {
              videoPlayerController.pause();
            } catch (_) {}
          }
        } else if ((mode == 'Always On' || mode == 'Headphones Only') &&
            !isPiP.value) {
          // On Web, the HTML5 video element automatically maintains audio playback in
          // background tabs without interruption, buffering delays, or dual-audio issues.
          // Background audio delegation is only needed on native mobile platforms where
          // the OS destroys the video surface upon minimization.
          if (!kIsWeb) {
            handleEnterBackground();
          }
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!kIsWeb) {
        if (_isBackgroundTransitioning) {
          _shouldExitBackgroundOnComplete = true;
        } else {
          handleExitBackground();
        }
      } else {
        // On Web, defensively ensure any stray audio service playback is silenced
        if (audioService != null && audioService!.isActive.value) {
          try {
            audioService!.deactivateBackgroundPlayback();
          } catch (_) {}
        }
      }
    }
  }

  Future<void> handleEnterBackground() async {
    if (kIsWeb) return;
    if (isBackgroundAudioActive || _isBackgroundTransitioning) return;
    if (!videoPlayerController.value.isInitialized ||
        !videoPlayerController.value.isPlaying) {
      return;
    }
    final vc = videoController;
    if (vc == null) return;

    _isBackgroundTransitioning = true;
    try {
      final currentPos = videoPlayerController.value.position;

      // Pause video player cleanly so the video surface is detached
      try {
        await videoPlayerController.pause();
      } catch (_) {}

      // If user resumed foreground while pausing was in progress, abort background activation
      if (_shouldExitBackgroundOnComplete) {
        _shouldExitBackgroundOnComplete = false;
        if (videoPlayerController.value.isInitialized) {
          try {
            await videoPlayerController.play();
          } catch (_) {}
        }
        return;
      }

      initAudioService();
      if (audioService != null) {
        final mediaUrl = resolveBackgroundMediaUrl(vc);

        if (mediaUrl.isNotEmpty) {
          isBackgroundAudioActive = true;
          await audioService!.activateBackgroundPlayback(
            mediaUrl: mediaUrl,
            title: vc.video.title,
            artworkUrl: vc.video.thumbnailUrl,
            startPosition: currentPos,
          );

          // If resumed while audio service was activating, exit immediately
          if (_shouldExitBackgroundOnComplete) {
            _shouldExitBackgroundOnComplete = false;
            await handleExitBackground();
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerBackgroundAudioMixin.handleEnterBackground',
      );
    } finally {
      _isBackgroundTransitioning = false;
    }
  }

  Future<void> handleExitBackground() async {
    if (kIsWeb) {
      if (audioService != null && audioService!.isActive.value) {
        try {
          audioService!.deactivateBackgroundPlayback();
        } catch (_) {}
      }
      isBackgroundAudioActive = false;
      _isBackgroundTransitioning = false;
      return;
    }
    final shouldDeactivate = isBackgroundAudioActive ||
        _isBackgroundTransitioning ||
        (audioService != null && audioService!.isActive.value);
    if (!shouldDeactivate) return;
    isBackgroundAudioActive = false;
    _isBackgroundTransitioning = false;

    if (audioService != null && audioService!.isActive.value) {
      final resumedPos = audioService!.currentPosition;
      final wasPlaying = audioService!.isPlaying.value;

      try {
        audioService!.deactivateBackgroundPlayback();
      } catch (_) {}

      if (videoPlayerController.value.isInitialized) {
        try {
          await videoPlayerController.seekTo(resumedPos);
          if (wasPlaying) {
            await videoPlayerController.play();
          }
        } catch (_) {}
      }
    }
  }

  String resolveBackgroundMediaUrl(VideoController vc) {
    if (vc.isOffline && vc.offlineBlobUrl != null && vc.offlineBlobUrl!.isNotEmpty) {
      return vc.offlineBlobUrl!;
    }
    if (vc.currentResolution.value?.url.isNotEmpty == true) {
      return vc.currentResolution.value!.url;
    }
    if (vc.video.hlsUrl.isNotEmpty) {
      return vc.video.hlsUrl;
    }
    if (vc.video.videoUrl.isNotEmpty) {
      return vc.video.videoUrl;
    }
    return vc.video.originalUrl;
  }
}
