import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (Get.isRegistered<UserSettingsController>()) {
        final mode =
            UserSettingsController.to.playback.value.backgroundPlaybackMode;
        if (mode == 'Off' && !isPiP.value) {
          if (videoPlayerController.value.isPlaying) {
            videoPlayerController.pause();
          }
        } else if ((mode == 'Always On' || mode == 'Headphones Only') && !isPiP.value) {
          handleEnterBackground();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      handleExitBackground();
    }
  }

  Future<void> handleEnterBackground() async {
    if (!videoPlayerController.value.isPlaying) return;
    final vc = videoController;
    if (vc == null) return;

    isBackgroundAudioActive = true;
    final currentPos = videoPlayerController.value.position;

    // Pause video player so the video surface is detached cleanly
    await videoPlayerController.pause();

    initAudioService();
    if (audioService != null) {
      final mediaUrl = resolveBackgroundMediaUrl(vc);

      if (mediaUrl.isNotEmpty) {
        await audioService!.activateBackgroundPlayback(
          mediaUrl: mediaUrl,
          title: vc.video.title,
          artworkUrl: vc.video.thumbnailUrl,
          startPosition: currentPos,
        );
      }
    }
  }

  Future<void> handleExitBackground() async {
    if (!isBackgroundAudioActive) return;
    isBackgroundAudioActive = false;

    if (audioService != null && audioService!.isActive.value) {
      final resumedPos = audioService!.currentPosition;
      final wasPlaying = audioService!.isPlaying.value;

      audioService!.deactivateBackgroundPlayback();

      await videoPlayerController.seekTo(resumedPos);
      if (wasPlaying) {
        await videoPlayerController.play();
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
