import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_gestures_mixin.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_playback_mixin.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_state_base.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_subtitles_mixin.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';
import 'package:video_player/video_player.dart';

/// Mixin handling player initialization, handoff to full-screen watch view, and teardown.
mixin MiniplayerHandoffMixin on
    MiniplayerStateBase,
    MiniplayerPlaybackMixin,
    MiniplayerSubtitlesMixin,
    MiniplayerGesturesMixin {
  /// Load a [video] into the miniplayer and begin playback.
  ///
  /// If [clip] is provided, playback and timeline are scoped strictly to the clip bounds.
  /// If [isAudioOnly] is true, the miniplayer renders the audio-only visual stage.
  @override
  Future<void> showWithVideo(
    Video video, {
    Duration? resumeFromPosition,
    String? overrideUrl,
    VideoClip? clip,
    bool isAudioOnly = false,
  }) async {
    if (isControllerClosed) return;

    // Reset error state
    error.value = '';
    recoveryDebounceTimer?.cancel();

    // Store active clip and audio only mode
    activeClip.value = clip;
    this.isAudioOnly.value = isAudioOnly;

    // If same video and clip is already loaded and active, just ensure visibility and play
    if (videoInfo.value?.id == video.id &&
        videoInfo.value?.clip?.id == clip?.id &&
        videoInfo.value?.isAudioOnly == isAudioOnly &&
        internalVpc != null &&
        isVideoReady.value) {
      mode.value = MiniplayerMode.collapsed;
      dragProgress.value = 0.0;
      dragOffset.value = null;
      dragOffset.value = null;
      try {
        HoverPreviewCoordinator.globalMute.value = true;
        await internalVpc!.play();
        isPlaying.value = true;
      } catch (e, s) {
        if (!isIgnorablePlaybackError(e.toString())) {
          try {
            await internalVpc!.setVolume(0);
            await internalVpc!.play();
            isPlaying.value = true;
          } catch (e2, s2) {
            ErrorHandler.log(
              e2,
              stackTrace: s2,
              tag: 'MiniplayerController.resumeMutedFallback',
            );
          }
        } else {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'MiniplayerController.sameVideoPlay',
          );
        }
      }
      PipService.to.updateAutoPip(
        enabled: isPlaying.value,
        aspectRatio: currentAspectRatio,
        isPlaying: isPlaying.value,
        hasPrevious: hasPreviousVideo,
        hasNext: hasNextVideo,
      );
      return;
    }

    // Check if an active pre-warmed or handed-off controller exists
    final handoffVpc =
        !kIsWeb ? VideoPlaybackHandoff.retrieveController(video.id) : null;
    final wasHandoff = handoffVpc != null && !handoffVpc.value.hasError;

    if (wasHandoff) {
      debugPrint(
        '[MiniplayerController] 🚀 Zero-latency handoff controller found for: ${video.id}',
      );
      // Cleanly dispose previous video if one was running
      disposeVideoControllers();

      videoInfo.value = MiniplayerVideoInfo.fromVideo(
        video,
        clip: clip,
        isAudioOnly: isAudioOnly,
      );
      currentVideo.value = video;
      try {
        VideoPlaybackQueueService.to.onVideoLoaded(video);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.showWithVideo.queue',
        );
      }
      mode.value = MiniplayerMode.collapsed;
      dragProgress.value = 0.0;
      dragOffset.value = null;

      internalVpc = handoffVpc;
      currentPlayingUrl = handoffVpc.dataSource;
      handoffVpc.addListener(vpcListener);

      if (clip != null) {
        final startMs = (clip.startTime * 1000).toInt();
        final endMs = (clip.endTime * 1000).toInt();
        final clipDur = Duration(
          milliseconds: (endMs - startMs).clamp(0, 86400000),
        );
        totalDuration.value = clipDur;
        final currentMs = handoffVpc.value.position.inMilliseconds;
        currentPosition.value = Duration(
          milliseconds: (currentMs - startMs).clamp(0, clipDur.inMilliseconds),
        );
      } else {
        currentPosition.value = handoffVpc.value.position;
        totalDuration.value = handoffVpc.value.duration;
      }

      // Mark video ready immediately so MiniplayerVideoFrame displays without flash
      isVideoReady.value = true;
      isBuffering.value = handoffVpc.value.isBuffering;
      isPlaying.value = handoffVpc.value.isPlaying;

      subtitlesEnabled.value = TowerPlayerController.globalSubtitlesEnabled;
      if (subtitlesEnabled.value) {
        loadBestSubtitleTrack();
      } else {
        subtitleSegments.clear();
        currentSubtitle.value = '';
      }

      HoverPreviewCoordinator.globalMute.value = true;
      if (!handoffVpc.value.isPlaying) {
        try {
          unawaited(handoffVpc.play());
          isPlaying.value = true;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'MiniplayerController.playHandoffVpc',
          );
        }
      }
      try {
        unawaited(handoffVpc.setLooping(false));
        unawaited(handoffVpc.setVolume(1.0));
      } catch (_) {}

      startPositionTimer();
      PipService.to.updateAutoPip(
        enabled: mode.value != MiniplayerMode.dismissed,
        aspectRatio: currentAspectRatio,
        isPlaying: isPlaying.value,
        hasPrevious: hasPreviousVideo,
        hasNext: hasNextVideo,
      );
      return;
    }

    if (handoffVpc != null && handoffVpc.value.hasError) {
      try {
        handoffVpc.dispose();
      } catch (_) {}
    }

    // Dispose previous
    disposeVideoControllers();

    // Populate metadata first so the UI shows thumbnail immediately
    videoInfo.value = MiniplayerVideoInfo.fromVideo(
      video,
      clip: clip,
      isAudioOnly: isAudioOnly,
    );
    currentVideo.value = video;
    try {
      VideoPlaybackQueueService.to.onVideoLoaded(video);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'MiniplayerController.showWithVideo.queue',
      );
    }
    mode.value = MiniplayerMode.collapsed;
    dragProgress.value = 0.0;
    dragOffset.value = null;
    isPlaying.value = false;
    isBuffering.value = true;
    isVideoReady.value = false;

    // Immediately enable auto-pip with loading state so exiting to home during load enters PiP cleanly
    PipService.to.updateAutoPip(
      enabled: true,
      aspectRatio: currentAspectRatio,
      isPlaying: false,
      hasPrevious: hasPreviousVideo,
      hasNext: hasNextVideo,
    );

    // Determine initial positions and duration based on clip vs full video
    final Duration hardwareSeekTarget;
    if (clip != null) {
      final startMs = (clip.startTime * 1000).toInt();
      final endMs = (clip.endTime * 1000).toInt();
      final clipDur = Duration(
        milliseconds: (endMs - startMs).clamp(0, 86400000),
      );
      totalDuration.value = clipDur;

      if (resumeFromPosition != null &&
          resumeFromPosition.inMilliseconds >= startMs &&
          resumeFromPosition.inMilliseconds <= endMs) {
        currentPosition.value = Duration(
          milliseconds: resumeFromPosition.inMilliseconds - startMs,
        );
        hardwareSeekTarget = resumeFromPosition;
      } else {
        currentPosition.value = Duration.zero;
        hardwareSeekTarget = Duration(milliseconds: startMs);
      }
    } else {
      currentPosition.value = resumeFromPosition ?? Duration.zero;
      totalDuration.value = video.durationValue;
      hardwareSeekTarget = resumeFromPosition ?? Duration.zero;
    }

    // Sync and load subtitles if global subtitles are enabled
    subtitlesEnabled.value = TowerPlayerController.globalSubtitlesEnabled;
    if (subtitlesEnabled.value) {
      loadBestSubtitleTrack();
    } else {
      subtitleSegments.clear();
      currentSubtitle.value = '';
    }

    final chStatus = (video.channelStatus ?? '').toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (chStatus == 'onhold' || chStatus == 'hold') {
      isBuffering.value = false;
      error.value =
          'This video is temporarily unavailable while the channel is on hold.';
      return;
    }

    if (video.isRejected ||
        video.status == VideoStatus.rejected ||
        video.visibility == 'rejected' ||
        video.channelStatus == 'rejected' ||
        chStatus == 'suspended') {
      isBuffering.value = false;
      error.value =
          'This video has been removed for violating community guidelines.';
      return;
    }

    try {
      final targetUrl = await resolvePlayableUrl(video, overrideUrl);
      currentPlayingUrl = targetUrl;
      if (targetUrl.isEmpty) {
        debugPrint('[MiniplayerController] Video URL is empty');
        error.value = 'Video unavailable';
        isBuffering.value = false;
        return;
      }

      debugPrint('[MiniplayerController] Initializing player for: $targetUrl');
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse(targetUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        ),
      );
      await vpc.initialize();

      if (isControllerClosed) {
        vpc.dispose();
        return;
      }

      internalVpc = vpc;
      vpc.addListener(vpcListener);

      if (clip != null) {
        totalDuration.value = Duration(
          milliseconds: ((clip.endTime - clip.startTime) * 1000).toInt(),
        );
      } else {
        totalDuration.value = vpc.value.duration;
      }
      isBuffering.value = false;
      isVideoReady.value = true;

      // Seek to hardware resume position if provided
      if (hardwareSeekTarget > Duration.zero &&
          (vpc.value.duration == Duration.zero ||
              hardwareSeekTarget < vpc.value.duration)) {
        await vpc.seekTo(hardwareSeekTarget);
      }

      // Explicitly start playback so the miniplayer plays when appearing
      HoverPreviewCoordinator.globalMute.value = true;
      try {
        await vpc.play();
        isPlaying.value = true;
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.playAutoplayFallback',
        );
        try {
          await vpc.setVolume(0);
          await vpc.play();
          isPlaying.value = true;
        } catch (e2, s2) {
          ErrorHandler.log(
            e2,
            stackTrace: s2,
            tag: 'MiniplayerController.playFallbackFailed',
          );
          // If browser blocked playback, leave paused without showing error
          isPlaying.value = false;
        }
      }

      startPositionTimer();
      PipService.to.updateAutoPip(
        enabled: mode.value != MiniplayerMode.dismissed,
        aspectRatio: currentAspectRatio,
        isPlaying: isPlaying.value,
        hasPrevious: hasPreviousVideo,
        hasNext: hasNextVideo,
      );
    } catch (e, s) {
      if (isControllerClosed) return;
      final errorMsg = e.toString();
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'MiniplayerController.initVpc',
      );

      isBuffering.value = false;
      isVideoReady.value = false;

      if (isIgnorablePlaybackError(errorMsg)) {
        // Benign error during init / play, do not show error on UI
        return;
      }

      if (errorMsg.contains('MEDIA_ERR_SRC_NOT_SUPPORTED') ||
          errorMsg.contains('Format error')) {
        error.value =
            'Video format not supported. Tap to retry or open in full player.';
      } else {
        scheduleAutoRecovery();
      }
    }
  }

  /// Dismiss the miniplayer and clean up all resources.
  @override
  void dismiss() {
    if (isControllerClosed) return;
    PipService.to.updateAutoPip(
      enabled: false,
      isPlaying: false,
      hasNext: false,
    );
    recoveryDebounceTimer?.cancel();
    recoveryAttempts = 0;

    // Persist watch progress before disposing controllers
    final video = currentVideo.value;
    final pos = currentPosition.value;
    final dur = totalDuration.value;
    if (video != null && pos.inSeconds > 0 && dur.inSeconds > 0) {
      final isNearEnd = pos.inSeconds >= (dur.inSeconds - 10) || (pos.inSeconds / dur.inSeconds) >= 0.90;
      final pct = ((pos.inSeconds / dur.inSeconds) * 100.0).clamp(0.0, 100.0);
      final isFullyWatched = pct >= 90.0 || isNearEnd;

      if (Get.isRegistered<WatchHistoryService>()) {
        WatchHistoryService.to.saveLocalPosition(
          video.id,
          pos.inSeconds,
          pct,
          totalDuration: dur.inSeconds,
        );
        if (isFullyWatched) {
          WatchHistoryService.to.markVideoFullyWatched(video.id);
          WatchHistoryService.to.resetResumePosition(video.id);
          VideoPlaybackHandoff.clear(video.id);
        } else {
          unawaited(
            WatchHistoryService.to.syncCrossDeviceResume(video.id, pos.inSeconds, pct),
          );
          VideoPlaybackHandoff.registerResumePosition(video.id, pos);
        }
      } else if (!isFullyWatched) {
        VideoPlaybackHandoff.registerResumePosition(video.id, pos);
      } else {
        VideoPlaybackHandoff.clear(video.id);
      }

      final userId = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
      if (userId.isNotEmpty && Firebase.apps.isNotEmpty) {
        try {
          unawaited(
            FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(userId)
                .collection('watch_history')
                .doc(video.id)
                .set({
                  'videoId': video.id,
                  'channelId': video.channelId,
                  'channelName': video.channelName,
                  'channelImage': video.channelImage,
                  'title': video.title,
                  'thumbnailUrl': video.thumbnailUrl,
                  'duration': video.duration,
                  'durationMs': dur.inMilliseconds,
                  'views': video.views,
                  'likeCount': video.likeCount,
                  'category': video.category,
                  'tags': video.tags,
                  'description': video.description,
                  'videoUrl': video.originalUrl,
                  'ownerId': video.ownerId,
                  'watchedAt': FieldValue.serverTimestamp(),
                  'watchedDuration': pos.inSeconds,
                  'watchPercentage': isFullyWatched ? 100.0 : pct,
                  'isCompleted': isFullyWatched,
                  'lastPosition': isFullyWatched ? 0 : pos.inSeconds,
                  'videoDuration': dur.inSeconds,
                }, SetOptions(merge: true))
                .catchError((e, s) {
                  ErrorHandler.log(
                    e,
                    stackTrace: s,
                    tag: 'MiniplayerController.dismiss.saveWatchHistory',
                  );
                }),
          );
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'MiniplayerController.dismiss.saveWatchHistorySync',
          );
        }
      }
    }

    disposeVideoControllers();
    mode.value = MiniplayerMode.dismissed;
    videoInfo.value = null;
    currentVideo.value = null;
    activeClip.value = null;
    isAudioOnly.value = false;
    isPlaying.value = false;
    isVideoReady.value = false;
    currentPosition.value = Duration.zero;
    totalDuration.value = Duration.zero;
    error.value = '';
    dragProgress.value = 0.0;
    dragOffset.value = null;
    isHovering.value = false;
  }

  /// Navigate to full video screen and close miniplayer.
  void openFullScreen() {
    final video = currentVideo.value;
    if (video == null) return;

    // Capture the most accurate live absolute position available from hardware or tracker
    var absPos = Duration.zero;
    if (internalVpc != null &&
        internalVpc!.value.isInitialized &&
        internalVpc!.value.position > Duration.zero) {
      absPos = internalVpc!.value.position;
    } else if (activeClip.value != null) {
      final startMs = (activeClip.value!.startTime * 1000).toInt();
      absPos = Duration(
        milliseconds: startMs + currentPosition.value.inMilliseconds,
      );
    } else {
      absPos = currentPosition.value;
    }

    mode.value = MiniplayerMode.transitioning;

    final durSec = totalDuration.value.inSeconds > 0
        ? totalDuration.value.inSeconds
        : video.durationSeconds;
    final isNearEnd = durSec > 0 &&
        (absPos.inSeconds >= (durSec - 10) || (absPos.inSeconds / durSec) >= 0.90);
    final isFullyWatched = Get.isRegistered<WatchHistoryService>() &&
        WatchHistoryService.to.isVideoFullyWatched(video.id, totalDuration: durSec);
    final isNearStart = absPos < const Duration(seconds: 5);

    final effectiveResume =
        (isNearEnd || isFullyWatched || isNearStart) ? null : absPos;

    // Register active controller & live timestamp for handoff BEFORE navigating
    if (internalVpc != null && !kIsWeb) {
      try {
        internalVpc!.removeListener(vpcListener);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.openFullScreen.removeListener',
        );
      }
      if (effectiveResume != null) {
        VideoPlaybackHandoff.registerActiveController(
          video.id,
          internalVpc!,
          position: effectiveResume,
        );
      } else {
        VideoPlaybackHandoff.clear(video.id);
        try {
          internalVpc!.seekTo(Duration.zero);
        } catch (_) {}
      }
      // Set to null so dismiss() won't dispose it while handing over!
      internalVpc = null;
    } else {
      if (effectiveResume != null) {
        VideoPlaybackHandoff.registerResumePosition(video.id, effectiveResume);
      } else {
        VideoPlaybackHandoff.clear(video.id);
      }
      if (kIsWeb && internalVpc != null) {
        try {
          internalVpc!.pause();
        } catch (_) {}
      }
    }

    final args = <String, dynamic>{
      'video': video,
      if (effectiveResume != null) ...{
        'resumePosition': effectiveResume.inMilliseconds,
        'initialPosition': effectiveResume,
      },
      'isFromMiniplayer': true,
      if (activeClip.value != null) 'clip': activeClip.value,
      'isAudioOnly': isAudioOnly.value,
      if (currentPlayingUrl != null && currentPlayingUrl!.isNotEmpty)
        'overrideUrl': currentPlayingUrl,
    };

    MiniplayerNavigationHelper.navigateToVideoScreen(
      video: video,
      routeArguments: args,
      resumePosition: effectiveResume,
    );

    // Give navigation transition 600ms to complete smoothly before cleaning up transitioning state.
    // VideoScreen's postFrameCallback will also call dismiss() once mounted.
    transitionTimer?.cancel();
    transitionTimer = trackTimer(
      Timer(const Duration(milliseconds: 600), () {
        if (!isControllerClosed && mode.value == MiniplayerMode.transitioning) {
          dismiss();
        }
      }),
    );
  }
}
