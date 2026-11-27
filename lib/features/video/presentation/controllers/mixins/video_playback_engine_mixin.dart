import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/guest_playback_limit_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_analytics_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Mixin orchestrating video player initialization, multi-resolution adaptive streaming, fullscreen Chewie events, and teardown.
mixin VideoPlaybackEngineMixin on GetxController {
  Video get video;
  VideoPlayerController? get videoPlayerController;
  set videoPlayerController(VideoPlayerController? c);
  Rx<VideoPlayerController?> get rxVideoPlayerController;
  RxDouble get rxAspectRatio;
  ChewieController? get chewieController;
  set chewieController(ChewieController? c);

  RxBool get rxIsLoading;
  RxBool get isPlayerInitialized;
  RxBool get videoError;
  RxString get rxErrorMessage;
  RxBool get rxIsOffline;
  RxBool get isAutoSwitching;
  RxBool get isSwitchingResolution;
  RxBool get showThumbnail;
  RxBool get isAutoplay;
  RxBool get isPlayingRx;
  RxBool get isAudioOnly;
  Rx<VideoClip?> get activeClip;
  Duration? get initialSeekPosition;
  set initialSeekPosition(Duration? pos);
  String? get offlineBlobUrl;
  RxList<VideoResolutionV2> get availableResolutions;
  Rx<VideoResolutionV2?> get currentResolution;
  RxSet<String> get blacklistedStreamUrls;
  Stopwatch get watchStopwatch;
  RxBool get isSubscribed;
  bool get isChannelMember;
  bool get isRecoveringFromFormatError;

  VideoAnalyticsController get analyticsController;
  MainController get mainController;
  String get playbackSessionId;
  String get trafficSource;
  String get viewerHash;
  StreamSubscription<DocumentSnapshot>? get videoSubscription;
  set videoSubscription(StreamSubscription<DocumentSnapshot>? s);
  StreamSubscription? get languageRequestsSubscription;
  set languageRequestsSubscription(StreamSubscription? s);

  void videoListener();
  void videoErrorListener();
  Future<void> attemptFormatFallback();
  Future<void> fireMilestoneEvent(String eventType, int position, int duration);
  Future<String?> resolvePlaybackTargetUrl({String? overrideUrl});
  ChewieController buildChewieController({
    required VideoPlayerController vpc,
    required String videoId,
    required VoidCallback onChewieEvent,
    required Future<void> Function() onRetry,
  });

  void onChewieEvent() {
    // Sync chewie events
  }

  bool get isVpcInitialized {
    if (isPlayerInitialized.value) return true;
    final vpc = videoPlayerController;
    if (vpc == null) return false;
    try {
      return vpc.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  bool get isVpcPlaying {
    final vpc = videoPlayerController;
    if (vpc == null) return false;
    try {
      return vpc.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  int _playerInitEpoch = 0;

  bool _isControllerUsable(VideoPlayerController? vpc) {
    if (vpc == null) return false;
    try {
      return vpc.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  void _safeDisposeVpc(VideoPlayerController? vpc) {
    if (vpc == null) return;
    try {
      vpc.removeListener(videoErrorListener);
      vpc.removeListener(videoListener);
    } catch (_) {}
    try {
      if (_isControllerUsable(vpc) && vpc.value.isPlaying) {
        vpc.pause().catchError((_) {});
      }
    } catch (_) {}
    try {
      vpc.dispose().catchError((_) {});
    } catch (_) {}
  }

  void _safeDisposeChewie(ChewieController? cc) {
    if (cc == null) return;
    if (identical(chewieController, cc)) {
      chewieController = null;
    }
    try {
      cc.removeListener(onChewieEvent);
    } catch (_) {}
    try {
      cc.dispose();
    } catch (_) {}
  }

  Future<void> initializeVideoPlayer({String? overrideUrl}) async {
    if (isClosed) return;
    final currentEpoch = ++_playerInitEpoch;

    final isAuto = isAutoSwitching.value;
    final isSwitching = isSwitchingResolution.value;
    final isHandoffAvailable = VideoPlaybackHandoff.isActive(video.id);
    final hasActivePlayer = isVpcInitialized;

    if (!isAuto && !isSwitching && !isHandoffAvailable && !hasActivePlayer) {
      rxIsLoading.value = true;
      // Do NOT call disposePlayer() here. Keeping old controller alive until
      // newVpc is initialized and synced ensures a seamless warm swap with zero
      // error flashes.
    }

    videoError.value = false;
    if (!isHandoffAvailable && !isSwitching && !hasActivePlayer) {
      showThumbnail.value = true;
    } else if (hasActivePlayer) {
      showThumbnail.value = false;
      rxIsLoading.value = false;
    }

    final isOwner = VideoVisibilityPolicy.isOwner(video);

    if (video.isPrivate && !isOwner) {
      videoError.value = true;
      rxErrorMessage.value =
          'This video is private. Only the channel owner can view this video.';
      rxIsLoading.value = false;
      showThumbnail.value = false;
      return;
    }

    if (video.isMembersOnly && !isOwner && !isChannelMember) {
      debugPrint(
        '[VideoController] 🔒 Members-only video gated: Viewer is not a member of ${video.channelId}',
      );
      rxIsLoading.value = false;
      showThumbnail.value = true;
      return;
    }

    if (video.isSubscribersOnly && !isOwner && !isSubscribed.value) {
      debugPrint(
        '[VideoController] 🔒 Subscribers-only video gated: Viewer is not subscribed to ${video.channelId}',
      );
      rxIsLoading.value = false;
      showThumbnail.value = true;
      return;
    }

    final chStatus = (video.channelStatus ?? '').toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (chStatus == 'onhold' || chStatus == 'hold') {
      videoError.value = true;
      rxErrorMessage.value =
          'This video is temporarily unavailable while the channel is on hold.';
      rxIsLoading.value = false;
      return;
    }

    if (video.isRejected ||
        video.status == VideoStatus.rejected ||
        video.visibility == 'rejected' ||
        video.channelStatus == 'rejected' ||
        chStatus == 'suspended') {
      videoError.value = true;
      rxErrorMessage.value =
          'This video has been removed for violating community guidelines.';
      rxIsLoading.value = false;
      return;
    }

    try {
      final oldVpc = videoPlayerController;
      final oldCc = chewieController;

      // Attempt to retrieve a pre-warmed/hovered/miniplayer controller for 0ms startup
      final handoffVpc = VideoPlaybackHandoff.retrieveController(video.id);
      final VideoPlayerController newVpc;
      final wasHandoff = handoffVpc != null;

      if (wasHandoff) {
        debugPrint(
          '[VideoController] 🚀 Instant handoff from pre-warmed Google CDN player for: ${video.id}',
        );
        newVpc = handoffVpc;
        await newVpc.setLooping(
          false,
        ); // Disable looping which was enabled for hover previews
        final hasAltAudio = TowerPlayerController.getForTagOrActive(video.id)?.hasAlternateAudioTrack ?? false;
        await newVpc.setVolume(hasAltAudio ? 0.0 : 1.0); // Reset volume to unmute on watch screen unless alternate audio is active
        if (newVpc.value.isInitialized) {
          rxIsLoading.value = false;
          showThumbnail.value = false;
        }
      } else {
        final targetUrl = await resolvePlaybackTargetUrl(overrideUrl: overrideUrl);
        if (isClosed || _playerInitEpoch != currentEpoch) return;
        if (targetUrl == null || targetUrl.isEmpty) {
          throw Exception('Failed to resolve target playback URL');
        }
        debugPrint('[VideoController] Initializing Google CDN player for: $targetUrl');

        if (!kIsWeb &&
            rxIsOffline.value &&
            !targetUrl.startsWith('http') &&
            !targetUrl.startsWith('blob:')) {
          newVpc = VideoPlayerController.file(
            File(targetUrl),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: true,
              allowBackgroundPlayback: true,
            ),
          );
        } else {
          final isHlsOrCmaf = targetUrl.contains('.m3u8') || targetUrl.contains('/cmaf/');
          final networkHeaders = await StorageUtils.getMediaHeaders(
            isHlsOrCmaf: isHlsOrCmaf,
          );

          newVpc = (rxIsOffline.value && targetUrl.startsWith('blob:'))
              ? VideoPlayerController.networkUrl(
                  Uri.parse(targetUrl),
                  videoPlayerOptions: VideoPlayerOptions(
                    mixWithOthers: true,
                    allowBackgroundPlayback: true,
                  ),
                )
              : VideoPlayerController.networkUrl(
                  Uri.parse(targetUrl),
                  httpHeaders: networkHeaders,
                  videoPlayerOptions: VideoPlayerOptions(
                    mixWithOthers: true,
                    allowBackgroundPlayback: true,
                  ),
                );
        }
      }

      HoverPreviewCoordinator.globalMute.value = true;

      if (!newVpc.value.isInitialized) {
        if (wasHandoff) {
          final handoffFuture =
              VideoPlaybackHandoff.consumeInitializationFuture(video.id) ??
              VideoPlaybackHandoff.getInitializationFuture(video.id);
          if (handoffFuture != null) {
            try {
              await handoffFuture.timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Video initialization timeout'),
              );
            } catch (e) {
              debugPrint(
                '[VideoController] Pre-warm handoff error ($e), checking player status',
              );
            }
          }
          if (!newVpc.value.isInitialized) {
            await newVpc.initialize().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Video initialization timeout'),
            );
          }
        } else {
          await newVpc.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Video initialization timeout'),
          );
        }
      }

      if (isClosed || _playerInitEpoch != currentEpoch) {
        _safeDisposeVpc(newVpc);
        return;
      }

      if (!newVpc.value.isInitialized) {
        throw Exception('Video controller failed to initialize');
      }

      // Guard against fragmented or truncated resolution streams:
      // If the stream reports a truncated duration (e.g. <= 5s) when the video model duration is known to be longer (> 10s),
      // seamlessly blacklist the bad URL and fall back to the original source URL which contains the full media stream.
      final expectedDurationSec = video.durationSeconds > 0
          ? video.durationSeconds
          : video.durationValue.inSeconds;
      final streamDurationSec = newVpc.value.duration.inSeconds;
      final isTruncatedResolution = newVpc.value.isInitialized &&
          expectedDurationSec > 10 &&
          streamDurationSec > 0 &&
          streamDurationSec <= 5 &&
          overrideUrl != video.originalUrl &&
          overrideUrl != video.videoUrl &&
          (video.originalUrl.isNotEmpty || video.videoUrl.isNotEmpty);

      if (isTruncatedResolution) {
        debugPrint(
          '[VideoController] ⚠️ Truncated resolution stream detected ($streamDurationSec s vs expected $expectedDurationSec s). Blacklisting stream and falling back to original source URL.',
        );

        // 1. Permanently blacklist the truncated URL for this session
        final badUrl = newVpc.dataSource;
        if (badUrl.isNotEmpty) {
          blacklistedStreamUrls.add(badUrl);
        }
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          blacklistedStreamUrls.add(overrideUrl);
        }
        if (video.hlsUrl.isNotEmpty && (badUrl == video.hlsUrl || overrideUrl == video.hlsUrl)) {
          blacklistedStreamUrls.add(video.hlsUrl);
        }

        // 2. Evict blacklisted variants from reactive collections so ABR/selectors never revert to them
        availableResolutions.removeWhere((r) => blacklistedStreamUrls.contains(r.url));
        if (currentResolution.value != null && blacklistedStreamUrls.contains(currentResolution.value!.url)) {
          currentResolution.value = null;
        }

        _safeDisposeVpc(newVpc);
        final fallbackSource = video.originalUrl.isNotEmpty
            ? video.originalUrl
            : video.videoUrl;
        return initializeVideoPlayer(overrideUrl: fallbackSource);
      }

      // ── YouTube-Grade Seamless Auto Mode Resolution Swap ──────
      // If an existing controller is already active and we are in Auto mode (ABR),
      // seamlessly pre-seek and pre-roll the new player in the background
      // while keeping the old player playing uninterrupted until the exact frame handoff.
      final isWarmSwap = oldVpc != null &&
          _isControllerUsable(oldVpc) &&
          isAuto;

      if (isWarmSwap) {
        final livePos = oldVpc.value.position > Duration.zero
            ? oldVpc.value.position
            : (initialSeekPosition ?? Duration.zero);
        final wasPlaying = oldVpc.value.isPlaying;
        final currentSpeed = oldVpc.value.playbackSpeed;
        final currentVol = oldVpc.value.volume;

        // Pre-seek new player to the exact live frame before attaching to UI
        if (livePos > Duration.zero) {
          await newVpc.seekTo(livePos);
          initialSeekPosition = null;
        }
        if (currentSpeed != 1.0) {
          await newVpc.setPlaybackSpeed(currentSpeed);
        }

        if (wasPlaying) {
          // Pre-roll new player muted so frames decode immediately
          await newVpc.setVolume(0.0);
          try {
            await newVpc.play();
          } catch (_) {}
          // Unmute to match live volume
          final hasAltAudio = TowerPlayerController.getForTagOrActive(video.id)?.hasAlternateAudioTrack ?? false;
          final targetVol = hasAltAudio ? 0.0 : (currentVol > 0 ? currentVol : 1.0);
          try {
            await newVpc.setVolume(targetVol);
          } catch (_) {}
        } else {
          final hasAltAudio = TowerPlayerController.getForTagOrActive(video.id)?.hasAlternateAudioTrack ?? false;
          final targetVol = hasAltAudio ? 0.0 : (currentVol > 0 ? currentVol : 1.0);
          await newVpc.setVolume(targetVol);
        }

        if (isClosed || _playerInitEpoch != currentEpoch) {
          _safeDisposeVpc(newVpc);
          return;
        }

        // Sync aspect ratio reactively
        if (newVpc.value.aspectRatio > 0) {
          rxAspectRatio.value = newVpc.value.aspectRatio;
        }

        // Atomically hand off active controller to reactive UI
        isPlayerInitialized.value = newVpc.value.isInitialized;
        videoPlayerController = newVpc;
        rxVideoPlayerController.refresh();
        showThumbnail.value = false;
        rxIsLoading.value = false;

        // Dispose old controller safely
        _safeDisposeVpc(oldVpc);
        _safeDisposeChewie(oldCc);
        chewieController = null;

        // Ensure background AudioOnlyService is completely deactivated
        if (Get.isRegistered<AudioOnlyService>()) {
          try {
            final audioSvc = Get.find<AudioOnlyService>();
            if (audioSvc.isActive.value || audioSvc.isPlaying.value) {
              audioSvc.deactivateBackgroundPlayback();
            }
          } catch (_) {}
        }

        // Attach listeners to new controller
        newVpc.addListener(videoErrorListener);
        newVpc.addListener(videoListener);

        // Sync TowerPlayerController seamlessly
        final playerTag = video.id;
        if (Get.isRegistered<TowerPlayerController>(tag: playerTag)) {
          Get.find<TowerPlayerController>(tag: playerTag).sync(newVpc);
        }

        debugPrint(
          '[VideoController] ⚡ YouTube-grade seamless auto resolution switch completed at ${livePos.inSeconds}s (Auto mode)',
        );
        return;
      }

      // ── Manual Resolution Switch (Particular Resolution Requested) ──
      // When the user explicitly requests a particular resolution (e.g. 720p, 480p),
      // this CAN cause buffering: pause old stream, show buffering spinner, seek to current timestamp,
      // and resume once buffered.
      final isManualSwitch = oldVpc != null &&
          _isControllerUsable(oldVpc) &&
          isSwitching &&
          !isAuto;

      if (isManualSwitch) {
        final resumePos = oldVpc.value.position > Duration.zero
            ? oldVpc.value.position
            : (initialSeekPosition ?? Duration.zero);
        final wasPlaying = oldVpc.value.isPlaying;
        final currentSpeed = oldVpc.value.playbackSpeed;
        final currentVol = oldVpc.value.volume;

        // Pause and mute old player immediately so user doesn't keep hearing old resolution
        try {
          if (_isControllerUsable(oldVpc)) {
            oldVpc.removeListener(videoErrorListener);
            oldVpc.removeListener(videoListener);
            oldVpc.pause().catchError((_) {});
          }
        } catch (_) {}

        // Pre-seek new player to the exact resume position
        if (resumePos > Duration.zero) {
          await newVpc.seekTo(resumePos);
          initialSeekPosition = null;
        }
        if (currentSpeed != 1.0) {
          await newVpc.setPlaybackSpeed(currentSpeed);
        }
        final hasAltAudio = TowerPlayerController.getForTagOrActive(video.id)?.hasAlternateAudioTrack ?? false;
        final targetVol = hasAltAudio ? 0.0 : (currentVol > 0 ? currentVol : 1.0);
        await newVpc.setVolume(targetVol);

        if (isClosed || _playerInitEpoch != currentEpoch) {
          _safeDisposeVpc(newVpc);
          return;
        }

        // Sync aspect ratio reactively
        if (newVpc.value.aspectRatio > 0) {
          rxAspectRatio.value = newVpc.value.aspectRatio;
        }

        // Hand off controller to reactive state
        isPlayerInitialized.value = newVpc.value.isInitialized;
        videoPlayerController = newVpc;
        rxVideoPlayerController.refresh();
        showThumbnail.value = false;
        rxIsLoading.value = false;

        // Dispose old controller safely
        _safeDisposeVpc(oldVpc);
        _safeDisposeChewie(oldCc);
        chewieController = null;

        // Ensure background AudioOnlyService is completely deactivated
        if (Get.isRegistered<AudioOnlyService>()) {
          try {
            final audioSvc = Get.find<AudioOnlyService>();
            if (audioSvc.isActive.value || audioSvc.isPlaying.value) {
              audioSvc.deactivateBackgroundPlayback();
            }
          } catch (_) {}
        }

        // Attach listeners
        newVpc.addListener(videoErrorListener);
        newVpc.addListener(videoListener);

        // Sync TowerPlayerController
        final playerTag = video.id;
        final towerCtrl = Get.isRegistered<TowerPlayerController>(tag: playerTag)
            ? Get.find<TowerPlayerController>(tag: playerTag)
            : null;
        towerCtrl?.sync(newVpc);

        if (wasPlaying) {
          try {
            await newVpc.play();
          } catch (_) {}
        }

        if (towerCtrl != null) {
          towerCtrl.isBuffering.value = newVpc.value.isBuffering;
          towerCtrl.abr.playbackState.value =
              wasPlaying ? PlaybackState.playing : PlaybackState.paused;
        }

        debugPrint(
          '[VideoController] 🎬 Manual resolution switch to requested tier completed at ${resumePos.inSeconds}s',
        );
        return;
      }

      if (isClosed || _playerInitEpoch != currentEpoch) {
        _safeDisposeVpc(newVpc);
        return;
      }

      // Sync aspect ratio reactively upon successful initialization
      if (newVpc.value.isInitialized && newVpc.value.aspectRatio > 0) {
        rxAspectRatio.value = newVpc.value.aspectRatio;
      }

      // Immediately wire new initialized controller to reactive state & clear loading/thumbnail
      isPlayerInitialized.value = newVpc.value.isInitialized;
      videoPlayerController = newVpc;
      rxVideoPlayerController.refresh();
      showThumbnail.value = false;
      rxIsLoading.value = false;

      // Mute and pause old controller immediately to guarantee zero overlapping audio
      if (oldVpc != null && oldVpc != newVpc) {
        try {
          oldVpc.removeListener(videoErrorListener);
          oldVpc.removeListener(videoListener);
          if (_isControllerUsable(oldVpc)) {
            oldVpc.pause().catchError((_) {});
          }
        } catch (_) {}
      }

      // Ensure any background AudioOnlyService is completely deactivated so two streams never play
      if (Get.isRegistered<AudioOnlyService>()) {
        try {
          final audioSvc = Get.find<AudioOnlyService>();
          if (audioSvc.isActive.value || audioSvc.isPlaying.value) {
            audioSvc.deactivateBackgroundPlayback();
          }
        } catch (_) {}
      }

      // Ensure volume is configured properly: on Web start muted for YouTube-style instant autoplay
      try {
        final hasAltAudio = TowerPlayerController.getForTagOrActive(video.id)?.hasAlternateAudioTrack ?? false;
        if (kIsWeb) {
          // On Web, browsers strictly block unmuted autoplay without prior user interaction.
          // Setting volume to 0 (muted) guarantees immediate playback exactly like YouTube.
          // Volume will be restored to unmuted upon user interaction.
          await newVpc.setVolume(0.0);
        } else {
          await newVpc.setVolume(hasAltAudio ? 0.0 : 1.0);
        }
      } catch (e) {
        debugPrint('[VideoController] setVolume error: $e');
      }

      // Add listeners AFTER initialization succeeds to prevent race conditions during setup
      newVpc.addListener(videoErrorListener);
      newVpc.addListener(videoListener);

      // Ensure TowerPlayerController is deterministically initialized and bound
      try {
        final playerTag = video.id;
        if (Get.isRegistered<TowerPlayerController>(tag: playerTag)) {
          Get.find<TowerPlayerController>(tag: playerTag).sync(newVpc);
        } else {
          Get.put(
            TowerPlayerController(
              videoPlayerController: newVpc,
              tag: playerTag,
            ),
            tag: playerTag,
          );
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'VideoPlaybackEngineMixin.ensureTowerPlayer',
        );
      }

      if (wasHandoff) {
        final durationSec = newVpc.value.duration.inSeconds;
        final isNearEnd = durationSec > 0 &&
            (newVpc.value.position >= Duration(seconds: durationSec - 10) ||
                (newVpc.value.position.inSeconds / durationSec) >= 0.90);
        final isFullyWatched = Get.isRegistered<WatchHistoryService>() &&
            WatchHistoryService.to.isVideoFullyWatched(video.id, totalDuration: durationSec);

        if (isNearEnd || isFullyWatched) {
          debugPrint(
            '[VideoController] 🔄 Handed off controller was near end or fully watched. Resetting to 0:00.',
          );
          await newVpc.seekTo(Duration.zero);
          initialSeekPosition = null;
        } else if (newVpc.value.position <= const Duration(seconds: 1) &&
            initialSeekPosition != null &&
            initialSeekPosition! > Duration.zero) {
          final initNearEnd = durationSec > 0 &&
              (initialSeekPosition! >= Duration(seconds: durationSec - 10) ||
                  (initialSeekPosition!.inSeconds / durationSec) >= 0.90);
          final initNearStart = initialSeekPosition! < const Duration(seconds: 5);
          if (!initNearEnd && !initNearStart) {
            debugPrint(
              '[VideoController] ⏩ Pre-warmed handoff seeking to resume position: ${initialSeekPosition!.inSeconds}s',
            );
            await newVpc.seekTo(initialSeekPosition!);
            _showResumeSnackbar(initialSeekPosition!.inSeconds, newVpc);
          } else {
            await newVpc.seekTo(Duration.zero);
          }
          initialSeekPosition = null;
        } else {
          // Handed off controller is already at the live playing frame!
          // Do NOT seek backwards to WatchHistoryService or initial position.
          debugPrint(
            '[VideoController] ⏩ Handed off controller already at ${newVpc.value.position.inSeconds}s. Continuing seamlessly.',
          );
          initialSeekPosition = null;
        }
        if (isClosed || _playerInitEpoch != currentEpoch) {
          _safeDisposeVpc(newVpc);
          return;
        }
        if (!newVpc.value.isPlaying) {
          try {
            await newVpc.play();
          } catch (_) {}
        }
        if (currentResolution.value == null && availableResolutions.isNotEmpty) {
          final resHeight = newVpc.value.size.height.toInt();
          final match = availableResolutions.firstWhereOrNull(
                (r) => (resHeight > 0 && r.height == resHeight) || r.url == newVpc.dataSource,
              ) ??
              availableResolutions.first;
          currentResolution.value = match;
        }
      } else {
        final durationSec = newVpc.value.duration.inSeconds;
        final isFullyWatched = Get.isRegistered<WatchHistoryService>() &&
            WatchHistoryService.to.isVideoFullyWatched(video.id, totalDuration: durationSec);

        if (activeClip.value != null) {
          final startMs = (activeClip.value!.startTime * 1000).toInt();
          debugPrint(
            '[VideoController] 🎬 Seeking player to clip start time: ${activeClip.value!.startTime}s ($startMs ms)',
          );
          await newVpc.seekTo(Duration(milliseconds: startMs));
        } else if (initialSeekPosition != null && initialSeekPosition! > Duration.zero) {
          final isNearEnd = durationSec > 0 &&
              (initialSeekPosition! >= Duration(seconds: durationSec - 10) ||
                  (initialSeekPosition!.inSeconds / durationSec) >= 0.90);
          final isNearStart = initialSeekPosition! < const Duration(seconds: 5);

          if (!isNearEnd && !isFullyWatched && !isNearStart) {
            debugPrint(
              '[VideoController] ⏩ Seeking player to resume/start timestamp: ${initialSeekPosition!.inSeconds}s',
            );
            await newVpc.seekTo(initialSeekPosition!);
            _showResumeSnackbar(initialSeekPosition!.inSeconds, newVpc);
          } else {
            debugPrint(
              '[VideoController] 🔄 Video was completed or near boundary (${initialSeekPosition!.inSeconds}s / ${durationSec}s). Starting from beginning.',
            );
            await newVpc.seekTo(Duration.zero);
            if (Get.isRegistered<WatchHistoryService>()) {
              WatchHistoryService.to.resetResumePosition(video.id);
            }
          }
          initialSeekPosition = null; // Consume once
        } else {
          final lastPos = Get.isRegistered<WatchHistoryService>()
              ? WatchHistoryService.to.getLastPosition(video.id, totalDuration: durationSec)
              : 0;
          if (lastPos >= 5 && (durationSec <= 0 || lastPos < durationSec - 10)) {
            // Seek to last position
            await newVpc.seekTo(Duration(seconds: lastPos));
            _showResumeSnackbar(lastPos, newVpc);
          } else {
            await newVpc.seekTo(Duration.zero);
          }
        }

        // Check guest playback limit before starting playback
        if (Get.isRegistered<GuestPlaybackLimitService>() &&
            !GuestPlaybackLimitService.to.isPlaybackAllowed()) {
          GuestPlaybackLimitService.to.promptGuestSignIn();
        } else {
          if (isClosed || _playerInitEpoch != currentEpoch) {
            _safeDisposeVpc(newVpc);
            return;
          }
          // Immediately start playback to begin decoding and frame rendering at target position
          try {
            await newVpc.play();
          } catch (e) {
            debugPrint('[VideoController] Note: Immediate play trigger exception: $e');
            if (kIsWeb) {
              try {
                await newVpc.setVolume(0);
                await newVpc.play();
              } catch (eWeb) {
                debugPrint('[VideoController] web muted autoplay fallback error: $eWeb');
              }
            }
          }
        }
      }

      // Track initiation
      if (!isAuto && !wasHandoff) {
        final isSub = isSubscribed.value;
        final isNotSub = !isSub;
        // Start stopwatch immediately for accurate tracking from second 0
        if (!watchStopwatch.isRunning) watchStopwatch.start();

        final rawDur = newVpc.value.duration.inSeconds;
        final totalDur = rawDur > 0
            ? rawDur
            : (video.durationSeconds > 0
                ? video.durationSeconds
                : (video.durationValue.inSeconds > 0
                    ? video.durationValue.inSeconds
                    : 0));

        if (totalDur > 0) {
          mainController.trackWatchEvent(
            videoId: video.id,
            channelId: video.channelId,
            eventType: 'video_start',
            position: 0,
            duration: totalDur,
            isSubscriber: isSub,
            isNotSubscriber: isNotSub,
            trafficSource: trafficSource,
            viewerHash: viewerHash.isNotEmpty ? viewerHash : null,
            sessionId: playbackSessionId,
          );
        }
      }

      if (isClosed || _playerInitEpoch != currentEpoch) {
        _safeDisposeVpc(newVpc);
        return;
      }

      chewieController = ChewieController(
        videoPlayerController: videoPlayerController!,
        allowedScreenSleep: false,
        showControlsOnInitialize: false,
        placeholder: const ColoredBox(
          color: AppColors.bgPage,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.brand,
          handleColor: AppColors.brand,
          backgroundColor: AppColors.brand.withValues(alpha: 0.2),
          bufferedColor: AppColors.brand.withValues(alpha: 0.33),
        ),
        customControls: TowerCustomPlayer(
          videoPlayerController: videoPlayerController!,
          tag: video.id,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Video playback error',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Unable to play this video. Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: initializeVideoPlayer,
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        deviceOrientationsOnEnterFullScreen:
            videoPlayerController!.value.aspectRatio > 1.0
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
        deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
        systemOverlaysOnEnterFullScreen: const [],
      );

      if (isClosed || _playerInitEpoch != currentEpoch) {
        _safeDisposeVpc(newVpc);
        _safeDisposeChewie(chewieController);
        chewieController = null;
        return;
      }

      // Listen for fullscreen changes from Chewie
      chewieController!.addListener(onChewieEvent);

      // Warm handoff: dispose old ones now that new ones are ready and synced
      if (oldVpc != null && oldVpc != newVpc) {
        _safeDisposeVpc(oldVpc);
        _safeDisposeChewie(oldCc);
      }

      debugPrint(
        '[VideoController] Player initialized successfully (Handoff: $isAuto)',
      );
    } catch (e, stackTrace) {
      if (isClosed || _playerInitEpoch != currentEpoch) {
        return;
      }
      debugPrint('[VideoController] Playback Error: $e');
      debugPrint('[VideoController] Stack trace: $stackTrace');

      if (!isRecoveringFromFormatError) {
        debugPrint('[VideoController] 🔄 Automatic fallback triggered from catch block...');
        await attemptFormatFallback();
        return;
      }

      videoError.value = true;
      final errorMsg = e.toString();
      if (errorMsg.contains('Future already completed') ||
          errorMsg.contains('Bad state')) {
        rxErrorMessage.value =
            'Video stream unavailable. Please check your connection or try again.';
      } else {
        rxErrorMessage.value =
            'This video is currently unavailable. Please check your connection or try again.';
      }
    } finally {
      if (!isClosed) {
        rxIsLoading.value = false;
      }
    }
  }

  void disposePlayer() {
    _playerInitEpoch++;
    videoSubscription?.cancel();
    languageRequestsSubscription?.cancel();
    _safeDisposeChewie(chewieController);
    chewieController = null;
    try {
      analyticsController.stopTimer();
    } catch (_) {}
    try {
      final playerTag = video.id;
      if (playerTag.isNotEmpty && Get.isRegistered<TowerPlayerController>(tag: playerTag)) {
        Get.delete<TowerPlayerController>(tag: playerTag, force: true);
      }
    } catch (_) {}
    _safeDisposeVpc(videoPlayerController);
    videoPlayerController = null;
    isPlayerInitialized.value = false;
  }

  void _showResumeSnackbar(int resumeSeconds, VideoPlayerController vpc) {
    if (resumeSeconds < 5) return;
    final formattedTime = _formatResumeTimestamp(resumeSeconds);
    AppSnackbar.info(
      'Resumed from $formattedTime',
      title: 'Resuming Video',
      actionLabel: 'Start Over',
      onAction: () {
        vpc.seekTo(Duration.zero);
        if (Get.isRegistered<WatchHistoryService>()) {
          WatchHistoryService.to.resetResumePosition(video.id);
        }
        VideoPlaybackHandoff.clear(video.id);
      },
      duration: const Duration(seconds: 5),
    );
  }

  String _formatResumeTimestamp(int seconds) {
    final d = Duration(seconds: seconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

}
