import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_state_base.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_subtitles_mixin.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';
import 'package:video_player/video_player.dart';

/// Mixin providing URL resolution, VideoPlayerController listeners, position tracking,
/// auto-recovery, and playback controls.
mixin MiniplayerPlaybackMixin on MiniplayerStateBase, MiniplayerSubtitlesMixin {
  /// Resolves the most appropriate playable stream URL for the video.
  Future<String> resolvePlayableUrl(Video video, String? overrideUrl) async {
    String? targetUrl;

    if (overrideUrl != null && overrideUrl.isNotEmpty) {
      targetUrl = overrideUrl;
    }

    final validAdaptive = video.adaptiveResolutions.where((r) {
      final u = r.url.trim().toLowerCase();
      final l = r.label.toLowerCase();
      return u.isNotEmpty &&
          !l.contains('audio') &&
          !u.contains('/audio');
    }).toList();

    final nonOriginalAdaptive = validAdaptive.where((r) {
      final u = r.url.toLowerCase();
      return !u.endsWith('original.mp4') && !u.contains('/original/');
    }).toList();

    final preferredAdaptive = nonOriginalAdaptive.isNotEmpty
        ? nonOriginalAdaptive
        : validAdaptive;

    if (targetUrl == null || targetUrl.isEmpty) {
      if (kIsWeb) {
        // On web, avoid .m3u8 HLS if MP4 resolutions are available
        final mp4Res = preferredAdaptive.firstWhereOrNull(
          (r) => !r.url.contains('.m3u8'),
        );
        if (mp4Res != null) {
          targetUrl = mp4Res.url;
        } else if (video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.endsWith('original.mp4') &&
            !video.hlsUrl.contains('/original/')) {
          targetUrl = video.hlsUrl;
        }
      } else {
        // On native, prefer HLS or adaptive resolutions
        if (video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.startsWith('gs://') &&
            !video.hlsUrl.endsWith('original.mp4') &&
            !video.hlsUrl.contains('/original/')) {
          targetUrl = video.hlsUrl;
        } else if (preferredAdaptive.isNotEmpty) {
          targetUrl = preferredAdaptive.first.url;
        }
      }
    }

    // Fallback: Query VideoMediaService for streaming resolutions if model lacks them
    if ((targetUrl == null || targetUrl.isEmpty) && video.id.isNotEmpty) {
      try {
        final streaming = await VideoMediaService().getStreaming(video.id);
        final streamingValid = streaming.adaptiveResolutions.where((r) {
          final u = r.url.trim().toLowerCase();
          final l = r.label.toLowerCase();
          return u.isNotEmpty &&
              !l.contains('audio') &&
              !u.contains('/audio');
        }).toList();

        final streamingNonOriginal = streamingValid.where((r) {
          final u = r.url.toLowerCase();
          return !u.endsWith('original.mp4') && !u.contains('/original/');
        }).toList();

        final preferredStreaming = streamingNonOriginal.isNotEmpty
            ? streamingNonOriginal
            : streamingValid;

        if (streamingValid.isNotEmpty) {
          final mp4Res = kIsWeb
              ? preferredStreaming.firstWhereOrNull((r) => !r.url.contains('.m3u8'))
              : null;
          targetUrl = mp4Res?.url ?? preferredStreaming.first.url;
        } else if (streaming.hlsUrl.isNotEmpty &&
            !streaming.hlsUrl.endsWith('original.mp4') &&
            !streaming.hlsUrl.contains('/original/')) {
          targetUrl = streaming.hlsUrl;
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.resolvePlayableUrl',
        );
      }
    }

    // Absolute fallback: check video.videoUrl, video.originalUrl, or video.hlsUrl
    if (targetUrl == null || targetUrl.isEmpty) {
      if (video.videoUrl.isNotEmpty) {
        targetUrl = video.videoUrl;
      } else if (video.originalUrl.isNotEmpty) {
        targetUrl = video.originalUrl;
      } else if (video.hlsUrl.isNotEmpty) {
        targetUrl = video.hlsUrl;
      }
    }

    // Fast-download CDN and authenticated resolution for storage paths
    if (targetUrl != null && targetUrl.isNotEmpty) {
      targetUrl = await StorageUtils.resolveUrl(targetUrl);
    }

    return targetUrl ?? '';
  }

  /// Schedule automatic retry on playback errors.
  void scheduleAutoRecovery() {
    if (isControllerClosed || currentVideo.value == null) return;
    if (recoveryAttempts >= MiniplayerStateBase.maxRecoveryAttempts) {
      error.value = 'Playback error. Tap to retry.';
      return;
    }
    recoveryDebounceTimer?.cancel();
    recoveryDebounceTimer = trackTimer(
      Timer(const Duration(milliseconds: 600), () {
        if (!isControllerClosed && currentVideo.value != null) {
          recoveryAttempts++;
          attemptRecovery();
        }
      }),
    );
  }

  /// Clear active clip to switch back to full video playback.
  @override
  void clearActiveClip() {
    activeClip.value = null;
    if (currentVideo.value != null) {
      videoInfo.value = MiniplayerVideoInfo.fromVideo(
        currentVideo.value!,
        isAudioOnly: isAudioOnly.value,
      );
      totalDuration.value = currentVideo.value!.durationValue;
      if (internalVpc != null && internalVpc!.value.isInitialized) {
        currentPosition.value = internalVpc!.value.position;
      }
    }
  }

  /// Native VideoPlayerController listener.
  void vpcListener() {
    final vpc = internalVpc;
    if (vpc == null || isControllerClosed) return;
    try {
      final val = vpc.value;
      if (isPlaying.value != val.isPlaying) {
        isPlaying.value = val.isPlaying;
        PipService.to.updateAutoPip(
          enabled: val.isPlaying && mode.value != MiniplayerMode.dismissed,
          aspectRatio: currentAspectRatio,
        );
      }
      isBuffering.value = val.isBuffering;

      // Clip loop and position tracking
      if (activeClip.value != null) {
        final clip = activeClip.value!;
        final currentPosSec = val.position.inMilliseconds / 1000.0;
        final startMs = (clip.startTime * 1000).toInt();
        final endMs = (clip.endTime * 1000).toInt();
        final clipDurMs = endMs - startMs;

        if (currentPosSec >= clip.endTime) {
          vpc.seekTo(Duration(milliseconds: startMs));
          return;
        }
        if (currentPosSec < clip.startTime - 0.5) {
          vpc.seekTo(Duration(milliseconds: startMs));
          return;
        }

        final relMs =
            (val.position.inMilliseconds - startMs).clamp(0, clipDurMs);
        currentPosition.value = Duration(milliseconds: relMs);
        totalDuration.value = Duration(milliseconds: clipDurMs);
      } else {
        currentPosition.value = val.position;
        if (val.duration > Duration.zero) {
          totalDuration.value = val.duration;
        }
      }

      if (val.hasError) {
        final err = val.errorDescription;
        if (isIgnorablePlaybackError(err)) {
          debugPrint(
            '[MiniplayerController] Ignored benign browser playback interruption: $err',
          );
        } else if (error.value.isEmpty) {
          debugPrint('[MiniplayerController] Playback error detected: $err');
          scheduleAutoRecovery();
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'MiniplayerController.vpcListener',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAYBACK CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Plays the next video in the queue or fallback recommendations.
  Future<void> playNext() async {
    if (!isAutoplay.value) return;
    final current = currentVideo.value;
    if (current == null) return;
    if (isNavigatingVideo.value) return;
    isNavigatingVideo.value = true;

    try {
      if (VideoPlaybackQueueService.to.hasForwardVideo) {
        final next = VideoPlaybackQueueService.to.nextForwardVideo;
        if (next != null) {
          VideoPlaybackQueueService.to.pushCurrentForNext(next);
          await showWithVideo(next);
          return;
        }
      }

      final fallback =
          await VideoPlaybackQueueService.to.fetchFallbackNextVideo(current.id);
      if (fallback != null && fallback.id != current.id) {
        VideoPlaybackQueueService.to.pushCurrentForNext(fallback);
        await showWithVideo(fallback);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'MiniplayerController.playNext',
      );
    } finally {
      isNavigatingVideo.value = false;
    }
  }

  /// Plays the previous video in the queue stack.
  Future<void> playPrevious() async {
    if (!isAutoplay.value) return;
    if (!VideoPlaybackQueueService.to.hasPreviousVideo) return;
    if (isNavigatingVideo.value) return;
    isNavigatingVideo.value = true;

    try {
      final prev = VideoPlaybackQueueService.to.popPreviousVideo();
      if (prev != null) {
        await showWithVideo(prev);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'MiniplayerController.playPrevious',
      );
    } finally {
      isNavigatingVideo.value = false;
    }
  }

  Future<void> togglePlayPause() async {
    final vpc = internalVpc;
    if (vpc == null) {
      isPlaying.value = !isPlaying.value;
      return;
    }
    if (vpc.value.isPlaying) {
      await vpc.pause();
      isPlaying.value = false;
    } else {
      HoverPreviewCoordinator.globalMute.value = true;
      try {
        await vpc.play();
        isPlaying.value = true;
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.togglePlayPause',
        );
        try {
          await vpc.setVolume(0);
          await vpc.play();
          isPlaying.value = true;
        } catch (e2, s2) {
          ErrorHandler.log(
            e2,
            stackTrace: s2,
            tag: 'MiniplayerController.togglePlayPauseMutedFallback',
          );
        }
      }
    }
  }

  /// Triggers Picture-in-Picture mode for the active video.
  Future<bool> enterPip() async {
    return PipService.to.enterPip(aspectRatio: currentAspectRatio);
  }

  Future<void> seekForward({int seconds = 10}) async {
    final vpc = internalVpc;
    if (vpc == null) {
      if (activeClip.value != null) {
        final clip = activeClip.value!;
        final clipDur = Duration(
          milliseconds: ((clip.endTime - clip.startTime) * 1000).toInt(),
        );
        final target = currentPosition.value + Duration(seconds: seconds);
        currentPosition.value = target > clipDur
            ? clipDur
            : (target < Duration.zero ? Duration.zero : target);
      } else {
        final target = currentPosition.value + Duration(seconds: seconds);
        currentPosition.value = target > totalDuration.value
            ? totalDuration.value
            : (target < Duration.zero ? Duration.zero : target);
      }
      return;
    }
    if (activeClip.value != null) {
      final clip = activeClip.value!;
      final startMs = (clip.startTime * 1000).toInt();
      final endMs = (clip.endTime * 1000).toInt();
      final currentAbs = vpc.value.position;
      final target = currentAbs + Duration(seconds: seconds);
      final clamped = target > Duration(milliseconds: endMs)
          ? Duration(milliseconds: endMs)
          : (target < Duration(milliseconds: startMs)
              ? Duration(milliseconds: startMs)
              : target);
      currentPosition.value =
          Duration(milliseconds: clamped.inMilliseconds - startMs);
      await vpc.seekTo(clamped);
    } else {
      final target = vpc.value.position + Duration(seconds: seconds);
      final clamped =
          target > vpc.value.duration ? vpc.value.duration : target;
      currentPosition.value = clamped;
      await vpc.seekTo(clamped);
    }
  }

  Future<void> seekBackward({int seconds = 10}) async {
    final vpc = internalVpc;
    if (vpc == null) {
      if (activeClip.value != null) {
        final clip = activeClip.value!;
        final clipDur = Duration(
          milliseconds: ((clip.endTime - clip.startTime) * 1000).toInt(),
        );
        final target = currentPosition.value - Duration(seconds: seconds);
        currentPosition.value = target < Duration.zero
            ? Duration.zero
            : (target > clipDur ? clipDur : target);
      } else {
        final target = currentPosition.value - Duration(seconds: seconds);
        currentPosition.value = target < Duration.zero
            ? Duration.zero
            : (target > totalDuration.value ? totalDuration.value : target);
      }
      return;
    }
    if (activeClip.value != null) {
      final clip = activeClip.value!;
      final startMs = (clip.startTime * 1000).toInt();
      final endMs = (clip.endTime * 1000).toInt();
      final currentAbs = vpc.value.position;
      final target = currentAbs - Duration(seconds: seconds);
      final clamped = target < Duration(milliseconds: startMs)
          ? Duration(milliseconds: startMs)
          : (target > Duration(milliseconds: endMs)
              ? Duration(milliseconds: endMs)
              : target);
      currentPosition.value =
          Duration(milliseconds: clamped.inMilliseconds - startMs);
      await vpc.seekTo(clamped);
    } else {
      final target = vpc.value.position - Duration(seconds: seconds);
      final clamped = target < Duration.zero ? Duration.zero : target;
      currentPosition.value = clamped;
      await vpc.seekTo(clamped);
    }
  }

  Future<void> seekTo(Duration position) async {
    final vpc = internalVpc;
    if (vpc == null) {
      if (activeClip.value != null) {
        final clip = activeClip.value!;
        final clipDur = Duration(
          milliseconds: ((clip.endTime - clip.startTime) * 1000).toInt(),
        );
        final clamped = position < Duration.zero
            ? Duration.zero
            : (position > clipDur ? clipDur : position);
        currentPosition.value = clamped;
      } else {
        final clamped = position < Duration.zero
            ? Duration.zero
            : (position > totalDuration.value ? totalDuration.value : position);
        currentPosition.value = clamped;
      }
      return;
    }
    if (activeClip.value != null) {
      final clip = activeClip.value!;
      final startMs = (clip.startTime * 1000).toInt();
      final endMs = (clip.endTime * 1000).toInt();
      final targetAbsMs =
          (startMs + position.inMilliseconds).clamp(startMs, endMs);
      final targetAbs = Duration(milliseconds: targetAbsMs);
      currentPosition.value =
          Duration(milliseconds: targetAbsMs - startMs);
      await vpc.seekTo(targetAbs);
    } else {
      final clamped = position < Duration.zero
          ? Duration.zero
          : (position > vpc.value.duration ? vpc.value.duration : position);
      currentPosition.value = clamped;
      await vpc.seekTo(clamped);
    }
  }

  Future<void> seekToRatio(double ratio) async {
    final vpc = internalVpc;
    if (activeClip.value != null) {
      final clip = activeClip.value!;
      final startMs = (clip.startTime * 1000).toInt();
      final clipDurMs = ((clip.endTime - clip.startTime) * 1000).toInt();
      if (clipDurMs <= 0) return;
      final targetRelMs = (clipDurMs * ratio.clamp(0.0, 1.0)).toInt();
      final targetAbs = Duration(milliseconds: startMs + targetRelMs);
      currentPosition.value = Duration(milliseconds: targetRelMs);
      if (vpc != null) {
        await vpc.seekTo(targetAbs);
      }
    } else {
      final totalMs = totalDuration.value.inMilliseconds;
      if (totalMs <= 0) return;
      final targetMs = (totalMs * ratio.clamp(0.0, 1.0)).toInt();
      final targetDuration = Duration(milliseconds: targetMs);
      currentPosition.value = targetDuration;
      if (vpc != null) {
        await vpc.seekTo(targetDuration);
      }
    }
  }

  void toggleMobileControls() {
    showMobileControls.value = !showMobileControls.value;
    hideControlsTimer?.cancel();
    if (showMobileControls.value) {
      hideControlsTimer = trackTimer(
        Timer(const Duration(seconds: 3), () {
          if (!isControllerClosed) {
            showMobileControls.value = false;
          }
        }),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIMERS & RESOURCE LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Periodic position sampler running at ~4 Hz.
  /// Much cheaper than a per-frame listener on the VideoPlayerController.
  void startPositionTimer() {
    stopPositionTimer();
    positionTimer = trackTimer(
      Timer.periodic(const Duration(milliseconds: 250), (_) {
        final vpc = internalVpc;
        if (vpc == null || isControllerClosed) return;

        final VideoPlayerValue val;
        try {
          val = vpc.value;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'MiniplayerController.positionTimer.vpcValue',
          );
          return;
        }
        isPlaying.value = val.isPlaying;
        isBuffering.value = val.isBuffering;

        if (activeClip.value != null) {
          final clip = activeClip.value!;
          final currentPosSec = val.position.inMilliseconds / 1000.0;
          final startMs = (clip.startTime * 1000).toInt();
          final endMs = (clip.endTime * 1000).toInt();
          final clipDurMs = endMs - startMs;

          if (currentPosSec >= clip.endTime) {
            vpc.seekTo(Duration(milliseconds: startMs));
            return;
          }
          if (currentPosSec < clip.startTime - 0.5) {
            vpc.seekTo(Duration(milliseconds: startMs));
            return;
          }

          final relMs =
              (val.position.inMilliseconds - startMs).clamp(0, clipDurMs);
          currentPosition.value = Duration(milliseconds: relMs);
          totalDuration.value = Duration(milliseconds: clipDurMs);
        } else {
          currentPosition.value = val.position;
          if (val.duration > Duration.zero) {
            totalDuration.value = val.duration;
          }
        }

        // Subtitle lookup
        if (subtitlesEnabled.value && subtitleSegments.isNotEmpty) {
          final pos = val.position;
          final seg = findSubtitle(pos);
          currentSubtitle.value = seg?.text ?? '';
        } else {
          currentSubtitle.value = '';
        }

        // Auto-advance or stop when complete
        if (val.position >= val.duration &&
            val.duration > Duration.zero &&
            !val.isPlaying) {
          isPlaying.value = false;
          if (isAutoplay.value &&
              activeClip.value == null &&
              !isNavigatingVideo.value) {
            playNext();
          }
        }
      }),
    );
  }

  void stopPositionTimer() {
    positionTimer?.cancel();
    positionTimer = null;
  }

  void disposeVideoControllers() {
    stopPositionTimer();
    if (internalVpc != null) {
      try {
        internalVpc!.removeListener(vpcListener);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.dispose.removeListener',
        );
      }
      try {
        internalVpc!.pause();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.dispose.pause',
        );
      }
      try {
        internalVpc!.dispose();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.dispose.dispose',
        );
      }
      internalVpc = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR HANDLING & RECOVERY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Attempt to recover from an error state by re-initializing if possible.
  @override
  Future<void> attemptRecovery() async {
    if (isControllerClosed || currentVideo.value == null) return;

    final currentPos = currentPosition.value;
    final wasPlaying = isPlaying.value;

    debugPrint(
      '[MiniplayerController] 🔄 Attempting recovery from ${currentPos.inSeconds}s (attempt $recoveryAttempts)...',
    );

    error.value = '';
    isBuffering.value = true;

    try {
      await showWithVideo(
        currentVideo.value!,
        resumeFromPosition: currentPos,
      );

      if (wasPlaying && internalVpc != null) {
        try {
          await internalVpc!.play();
          isPlaying.value = true;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'MiniplayerController.attemptRecovery.play',
          );
          try {
            await internalVpc!.setVolume(0);
            await internalVpc!.play();
            isPlaying.value = true;
          } catch (e2, s2) {
            ErrorHandler.log(
              e2,
              stackTrace: s2,
              tag: 'MiniplayerController.attemptRecovery.mutedPlay',
            );
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'MiniplayerController.attemptRecovery',
      );
      if (recoveryAttempts >= MiniplayerStateBase.maxRecoveryAttempts) {
        error.value = 'Playback error. Tap to retry.';
      }
    } finally {
      isBuffering.value = false;
    }
  }
}
