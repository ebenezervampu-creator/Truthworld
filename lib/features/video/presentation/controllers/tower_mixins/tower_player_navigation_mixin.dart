import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/digital_wellbeing_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

mixin TowerPlayerNavigationMixin on GetxController {
  // Host controller dependencies
  VideoPlayerValue get vv;
  PlaybackSource get activePlayback;
  VideoController? get videoController;
  String? get tag;
  RxBool get isAudioOnly;
  RxBool get isLooping;
  SleepTimerService get sleepTimerService;
  void trackAnalytics(PlayerEvent event);
  void showToast(String msg);
  Future<void> seekTo(Duration pos);
  bool get hasEnded;
  set hasEnded(bool val);
  RxBool get isFullScreen;
  RxBool get showMoreVideos;
  void openMoreVideos();

  // ── Playlist & queue navigation ───────────────────────────
  bool get hasPreviousVideo {
    isAudioOnly.value; // Guarantee Rx access for Obx
    try {
      final vc = videoController;
      if (vc != null && vc.playlistVideos.isNotEmpty) {
        return vc.currentPlaylistIndex.value > 0;
      }
      return VideoPlaybackQueueService.to.hasPreviousVideo;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerNavigationMixin.hasPreviousVideo',
      );
    }
    return false;
  }

  bool get hasNextVideo {
    isAudioOnly.value; // Guarantee Rx access for Obx
    try {
      final vc = videoController;
      if (vc != null && vc.playlistVideos.isNotEmpty) {
        return vc.currentPlaylistIndex.value < vc.playlistVideos.length - 1;
      }
      if (VideoPlaybackQueueService.to.hasForwardVideo) return true;
      if (vc != null && vc.recommendedVideos.isNotEmpty) return true;
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerNavigationMixin.hasNextVideo',
      );
    }
    return false;
  }

  // ── Navigation lock — prevent concurrent video switches ────
  final RxBool isNavigatingToVideo = false.obs;

  void playNext() {
    trackAnalytics(PlayerEvent('next'));
    final vc = videoController;
    if (vc == null) return;

    if (vc.playlistVideos.isNotEmpty &&
        vc.currentPlaylistIndex.value < vc.playlistVideos.length - 1) {
      final next = vc.playlistVideos[vc.currentPlaylistIndex.value + 1];
      VideoPlaybackQueueService.to.pushCurrentForNext(next);
      executeNavigateToVideo(next, vc);
      return;
    }

    if (VideoPlaybackQueueService.to.hasForwardVideo) {
      final next = VideoPlaybackQueueService.to.nextForwardVideo;
      if (next != null) {
        VideoPlaybackQueueService.to.pushCurrentForNext(next);
        executeNavigateToVideo(next, vc);
        return;
      }
    }

    if (vc.recommendedVideos.isNotEmpty) {
      final next = vc.recommendedVideos.firstWhereOrNull(
        (v) => v.id != vc.video.id,
      ) ?? vc.recommendedVideos.first;
      if (next.id != vc.video.id) {
        VideoPlaybackQueueService.to.pushCurrentForNext(next);
        executeNavigateToVideo(next, vc);
        return;
      }
    }

    VideoPlaybackQueueService.to.fetchFallbackNextVideo(vc.video.id).then((fallback) {
      if (fallback != null && fallback.id != vc.video.id) {
        VideoPlaybackQueueService.to.pushCurrentForNext(fallback);
        executeNavigateToVideo(fallback, vc);
      } else {
        showToast('No more videos available');
      }
    });
  }

  void playPrevious() {
    trackAnalytics(PlayerEvent('previous'));
    final vc = videoController;
    if (vc == null) return;

    if (vv.position > const Duration(seconds: 3)) {
      seekTo(Duration.zero);
      return;
    }

    if (vc.playlistVideos.isNotEmpty) {
      if (vc.currentPlaylistIndex.value > 0) {
        final prev = vc.playlistVideos[vc.currentPlaylistIndex.value - 1];
        executeNavigateToVideo(prev, vc);
      } else {
        seekTo(Duration.zero);
      }
      return;
    }

    if (VideoPlaybackQueueService.to.hasPreviousVideo) {
      final prev = VideoPlaybackQueueService.to.popPreviousVideo();
      if (prev != null) {
        executeNavigateToVideo(prev, vc);
        return;
      }
    }

    seekTo(Duration.zero);
  }

  void executeNavigateToVideo(Video video, VideoController vc) {
    // Navigation lock — prevent concurrent switches that cause stuck state
    if (isNavigatingToVideo.value) return;
    isNavigatingToVideo.value = true;
    try {
      activePlayback.pause();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerNavigationMixin.navigateToVideo.pause',
      );
    }
    Get.offNamed(
      '/watch?v=${video.id}',
      arguments: {
        'video': video,
        'playlist': vc.currentPlaylist.value,
        'heroTag': 'video_${video.id}_${DateTime.now().millisecondsSinceEpoch}',
      },
      preventDuplicates: false,
    );
    // Reset lock after short delay (route transition)
    Future.delayed(const Duration(milliseconds: 500), () {
      isNavigatingToVideo.value = false;
    });
  }

  void navigateToVideo(Video video) {
    final vc = videoController;
    if (vc != null) {
      executeNavigateToVideo(video, vc);
    }
  }

  // ── End Screen & Autoplay ──────────────────────────────────
  final RxBool isAutoplay = true.obs;
  final RxBool showEndScreen = false.obs;
  final RxBool isEndScreenOverlayHidden = false.obs;
  final RxInt autoplayCountdown = 5.obs;
  Timer? autoplayTimer;

  void toggleAutoplay() {
    isAutoplay.toggle();
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        Get.find<VideoController>(tag: tag).isAutoplay.value = isAutoplay.value;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerNavigationMixin.toggleAutoplay',
      );
    }
    showToast(isAutoplay.value ? 'Autoplay ON' : 'Autoplay OFF');
  }

  void onTrackEnded() {
    trackAnalytics(PlayerEvent('ended'));

    if (sleepTimerService.isAtEndOfVideo) {
      sleepTimerService.onTrackEnded();
      return;
    }

    if (isLooping.value) return; // Looping is handled by VideoPlayerController

    // Reset overlay hidden state so it shows initially
    isEndScreenOverlayHidden.value = false;
    if (isFullScreen.value) {
      openMoreVideos();
    } else {
      showEndScreen.value = true;
    }

    if (isAutoplay.value) {
      if (Get.isRegistered<DigitalWellbeingService>() &&
          DigitalWellbeingService.to.shouldPauseAutoplayDuringBedtime()) {
        debugPrint('[TowerPlayerNavigationMixin] 🌙 Bedtime active - autoplay paused');
        return;
      }
      startAutoplayCountdown();
    }
  }

  void startAutoplayCountdown() {
    autoplayTimer?.cancel();
    autoplayCountdown.value = 5;
    autoplayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (autoplayCountdown.value <= 1) {
        timer.cancel();
        playNextImmediately();
      } else {
        autoplayCountdown.value--;
      }
    });
  }

  void cancelAutoplayCountdown() {
    autoplayTimer?.cancel();
    autoplayTimer = null;
    autoplayCountdown.value = 0;
  }

  void playNextImmediately() {
    autoplayTimer?.cancel();
    autoplayTimer = null;
    showEndScreen.value = false;
    showMoreVideos.value = false;
    isEndScreenOverlayHidden.value = false;
    playNext();
  }

  void replayVideo() {
    autoplayTimer?.cancel();
    autoplayTimer = null;
    showEndScreen.value = false;
    showMoreVideos.value = false;
    isEndScreenOverlayHidden.value = false;
    hasEnded = false;
    seekTo(Duration.zero);
    activePlayback.play();
  }
}
