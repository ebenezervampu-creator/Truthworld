import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/datasources/local/database_helpers.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Mixin orchestrating video playback flow, Chewie controller configuration, offline resolution pre-fetching, and miniplayer handoff.
mixin VideoPlaybackFlowMixin on GetxController {
  Video get video;
  RxBool get rxIsLoading;
  RxBool get videoError;
  RxString get rxErrorMessage;
  RxBool get rxIsOffline;
  RxBool get isAutoSwitching;
  RxBool get isSwitchingResolution;
  RxBool get showThumbnail;
  RxBool get isAutoplay;
  RxBool get isAudioOnly;
  Rx<VideoClip?> get activeClip;
  RxList<VideoResolutionV2> get availableResolutions;
  Rx<VideoResolutionV2?> get currentResolution;
  String? get offlineBlobUrl;
  VideoPlayerController? get videoPlayerController;
  set videoPlayerController(VideoPlayerController? c);
  Rx<VideoPlayerController?> get rxVideoPlayerController;
  ChewieController? get chewieController;
  set chewieController(ChewieController? c);
  Stopwatch get watchStopwatch;
  bool get isVpcInitialized;

  Future<void> initializeOfflinePlayback();
  Future<void> fetchAvailableResolutions();
  Future<void> fetchAvailableSubtitles();
  Future<void> fetchAvailableAudioTracks();
  Future<void> loadTranscriptForVideo();
  Future<void> loadFactCheckData([String? overrideUrl, bool force = false]);
  Future<void> initializeVideoPlayer({String? overrideUrl});
  void disposePlayer();
  void videoListener();
  void videoErrorListener();
  void onChewieEvent();
  void flushRemainingWatchTime();
  Future<void> syncWatchHistory(int watchSeconds, int totalDuration);

  double get vpcAspectRatio {
    final vpc = videoPlayerController;
    if (vpc == null) return 16 / 9;
    try {
      final ratio = vpc.value.aspectRatio;
      return (ratio.isFinite && ratio > 0) ? ratio : 16 / 9;
    } catch (_) {
      return 16 / 9;
    }
  }

  ChewieController buildChewieController({
    required VideoPlayerController vpc,
    required String videoId,
    required VoidCallback onChewieEvent,
    required Future<void> Function() onRetry,
  }) {
    final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
    final isPrem = auth?.isPremiumUser.value ?? false;
    final isAudioOnlyPlan = isPrem && auth?.premiumPlanId.value == 'audio_monthly';
    final suppressAds = isPrem && (!isAudioOnlyPlan || isAudioOnly.value);
    final hasPreRollAd = !suppressAds &&
        Get.isRegistered<AdService>() &&
        (AdService.to.getSponsorAdForVideo(videoId) != null ||
            AdService.to.getSkippableVideoAds().isNotEmpty);

    final cc = ChewieController(
      videoPlayerController: vpc,
      autoPlay: !hasPreRollAd,
      allowedScreenSleep: false,
      showControlsOnInitialize: false,
      placeholder: const ColoredBox(
        color: AppColors.bgPage,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.error),
        ),
      ),
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.error,
        handleColor: AppColors.error,
        backgroundColor: AppColors.textSecondary.withValues(alpha: 0.5),
        bufferedColor: AppColors.textPrimary.withValues(alpha: 0.3),
      ),
      customControls: TowerCustomPlayer(
        videoPlayerController: vpc,
        tag: videoId,
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Video playback error',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.black),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      deviceOrientationsOnEnterFullScreen:
          vpc.value.aspectRatio > 1.0
          ? [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      systemOverlaysOnEnterFullScreen: const [],
    );

    cc.addListener(onChewieEvent);
    return cc;
  }

  void handoffToMiniplayerOrDispose() {
    final currentRoute = Get.currentRoute.toLowerCase();
    final hasWatchInStack = RouteStackObserver.routeStack.isNotEmpty &&
        (RouteStackObserver.routeStack.last.settings.name?.toLowerCase().contains('watch') ?? false);
    final isGoingToWatch =
        currentRoute.contains('watch') ||
        currentRoute.contains('videoscreen') ||
        hasWatchInStack ||
        RouteStackObserver.hasRoute('/watch') ||
        RouteStackObserver.hasRoute('/videoscreen');

    final shouldStartMiniplayer =
        !isGoingToWatch &&
        isVpcInitialized &&
        Get.isRegistered<MiniplayerController>(tag: 'miniplayer');

    if (isVpcInitialized) {
      try {
        final totalDuration = videoPlayerController!.value.duration.inSeconds;
        final watchSeconds = watchStopwatch.elapsed.inSeconds;
        flushRemainingWatchTime();
        syncWatchHistory(watchSeconds, totalDuration);
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoController.handoff.sync');
      }
    }

    if (shouldStartMiniplayer) {
      var pos = Duration.zero;
      try {
        pos = videoPlayerController!.value.position;
      } catch (_) {}
      final videoToPlay = video;
      final selectedResUrl = currentResolution.value?.url;

      try {
        videoPlayerController!.pause();
      } catch (_) {}

      try {
        videoPlayerController!.removeListener(videoErrorListener);
        videoPlayerController!.removeListener(videoListener);
      } catch (_) {}

      try {
        chewieController?.removeListener(onChewieEvent);
        chewieController?.dispose();
      } catch (_) {}
      chewieController = null;

      TowerPlayerController.pauseAllActivePlayers();

      if (videoPlayerController != null && !kIsWeb) {
        VideoPlaybackHandoff.registerActiveController(
          video.id,
          videoPlayerController!,
        );
        videoPlayerController = null;
        rxVideoPlayerController.value = null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          MiniplayerController.to.showWithVideo(
            videoToPlay,
            resumeFromPosition: pos,
            overrideUrl: selectedResUrl,
          );
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'VideoController.showMiniplayer');
        }
      });
    }

    disposePlayer();
  }

  Future<String?> resolvePlaybackTargetUrl({String? overrideUrl}) async {
    var targetUrl = overrideUrl;
    if (targetUrl == null || targetUrl.isEmpty) {
      if (currentResolution.value != null &&
          currentResolution.value!.url.isNotEmpty) {
        targetUrl = currentResolution.value!.url;
      } else if (!kIsWeb && video.hlsUrl.isNotEmpty) {
        targetUrl = video.hlsUrl;
      } else if (availableResolutions.isNotEmpty) {
        final mp4Res = availableResolutions.firstWhereOrNull(
          (r) => r.url.isNotEmpty && !r.url.contains('.m3u8'),
        );
        if (mp4Res != null) {
          targetUrl = mp4Res.url;
        }
      }
      if (targetUrl == null || targetUrl.isEmpty) {
        if (video.videoUrl.isNotEmpty) {
          targetUrl = video.videoUrl;
        } else if (video.originalUrl.isNotEmpty) {
          targetUrl = video.originalUrl;
        } else if (video.hlsUrl.isNotEmpty) {
          targetUrl = video.hlsUrl;
        }
      }
    }

    if (targetUrl != null && targetUrl.isNotEmpty) {
      targetUrl = await StorageUtils.resolveUrl(targetUrl);
    }

    if (kIsWeb && targetUrl != null && targetUrl.contains('.m3u8')) {
      if (currentResolution.value != null &&
          currentResolution.value!.url.isNotEmpty &&
          !currentResolution.value!.url.contains('.m3u8')) {
        debugPrint(
          '[VideoController] ⚠️ Skipping HLS URL on web, using resolution MP4 instead',
        );
        targetUrl = currentResolution.value!.url;
      } else if (availableResolutions.isNotEmpty) {
        final mp4Res = availableResolutions.firstWhereOrNull(
          (r) => !r.url.contains('.m3u8'),
        );
        if (mp4Res != null) {
          debugPrint(
            '[VideoController] ⚠️ Skipping HLS URL on web, using ${mp4Res.label} MP4 instead',
          );
          targetUrl = mp4Res.url;
        }
      }
    }

    if (targetUrl == null || targetUrl.isEmpty) {
      throw Exception('No optimized video resolution available');
    }

    return targetUrl;
  }

  Future<void> startPlaybackFlow({String? overrideUrl}) async {
    // 0. Check offline storage metadata first for instant 0ms offline playback
    if (!rxIsOffline.value) {
      try {
        final offlineMeta = await getOfflineVideoMetadata(video.id);
        if (offlineMeta != null) {
          rxIsOffline.value = true;
          if (offlineMeta.isAudioOnly) {
            isAudioOnly.value = true;
          }
        }
      } catch (_) {}
    }

    if (rxIsOffline.value) {
      await initializeOfflinePlayback();
      return;
    }

    final mediaService = VideoMediaService();

    // 1. Kick off metadata loading: fetch localization first so audio tracks cache is populated
    final Future<void> metadataFuture = () async {
      await Future.wait<dynamic>([
        mediaService.getLocalization(video.id),
        mediaService.getCredibility(video.id),
      ]);
      await Future.wait<void>([
        fetchAvailableResolutions(),
        fetchAvailableSubtitles(),
        fetchAvailableAudioTracks(),
      ]);
      unawaited(loadTranscriptForVideo());
      if (video.factCheckUrl.isNotEmpty) {
        unawaited(loadFactCheckData());
      }
    }();

    // Priority 0: Explicit overrideUrl passed in (e.g. from miniplayer or custom stream source)
    if (overrideUrl != null && overrideUrl.isNotEmpty) {
      debugPrint('[VideoController] 🎯 Direct playback from overrideUrl: $overrideUrl');
      await initializeVideoPlayer(overrideUrl: overrideUrl);
      if (activeClip.value != null) {
        videoPlayerController?.seekTo(
          Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
        );
      }
      metadataFuture.then((_) {
        if (availableResolutions.isNotEmpty) {
          final match = availableResolutions.firstWhereOrNull(
            (r) => r.url == overrideUrl,
          );
          if (match != null) {
            currentResolution.value = match;
          }
        }
      });
      return;
    }

    // Check if we have an active handoff controller (from miniplayer or card hover)
    final hasHandoff = VideoPlaybackHandoff.isActive(video.id);
    if (hasHandoff) {
      debugPrint(
        '[VideoController] 🚀 Instant handoff playback from active controller for: ${video.id}',
      );
      rxIsLoading.value = false;
      showThumbnail.value = false;
      await initializeVideoPlayer();

      // Once metadata finishes, update resolutions reactively without re-initializing player
      metadataFuture.then((_) {
        if (availableResolutions.isNotEmpty) {
          final best = availableResolutions.firstWhereOrNull(
            (r) => r.url.isNotEmpty && !r.url.contains('.m3u8'),
          ) ?? availableResolutions.first;
          if (currentResolution.value?.url != best.url) {
            currentResolution.value = best;
          }
        }
      });
      return;
    }

    // 2. Playback strategy:
    //    - On native (iOS/Android/Desktop): Attempt HLS adaptive streaming for instant start
    //    - If HLS not available or fails, automatically fallback to transcoded MP4s / videoUrl / originalUrl
    var hlsSuccess = false;
    if (!kIsWeb && video.hlsUrl.isNotEmpty) {
      debugPrint('[VideoController] 🎬 Native playback: Using HLS adaptive stream');
      await initializeVideoPlayer(overrideUrl: video.hlsUrl);

      if (!videoError.value) {
        hlsSuccess = true;
        // Once metadata finishes, update the quality/resolution menu reactively
        metadataFuture.then((_) {
          if (availableResolutions.isNotEmpty) {
            final best = availableResolutions.first;
            if (currentResolution.value?.url != best.url) {
              currentResolution.value = best;
            }
          }
        });
      } else {
        debugPrint('[VideoController] ⚠️ HLS stream failed, falling back to MP4 ladder...');
        videoError.value = false;
        rxErrorMessage.value = '';
      }
    }

    if (!hlsSuccess) {
      debugPrint('[VideoController] 🌐 Initializing stream from resolutions / MP4 variants...');
      await metadataFuture;

      if (availableResolutions.isNotEmpty) {
        final mp4Res = availableResolutions.firstWhereOrNull(
          (r) => r.url.isNotEmpty && !r.url.contains('.m3u8') && !r.url.endsWith('original.mp4') && !r.url.contains('/original/'),
        );
        final best = mp4Res ?? availableResolutions.first;
        currentResolution.value = best;
        debugPrint(
          '[VideoController] ✅ Playing ${best.label} (${best.width}x${best.height})',
        );
        await initializeVideoPlayer(overrideUrl: best.url);
      } else if (video.hlsUrl.isNotEmpty && !video.hlsUrl.endsWith('original.mp4') && !video.hlsUrl.contains('/original/')) {
        debugPrint('[VideoController] 🎬 Playing from hlsUrl: ${video.hlsUrl}');
        await initializeVideoPlayer(overrideUrl: video.hlsUrl);
      } else if (video.videoUrl.isNotEmpty) {
        debugPrint('[VideoController] 🎬 Playing from fallback videoUrl: ${video.videoUrl}');
        await initializeVideoPlayer(overrideUrl: video.videoUrl);
      } else if (video.originalUrl.isNotEmpty) {
        debugPrint('[VideoController] 🎬 Playing from fallback originalUrl: ${video.originalUrl}');
        await initializeVideoPlayer(overrideUrl: video.originalUrl);
      } else {
        debugPrint(
          '[VideoController] ❌ No playable video stream found.',
        );
        videoError.value = true;
        rxErrorMessage.value =
            'This video is currently unavailable. Please try again later.';
        rxIsLoading.value = false;
        return;
      }
    }

    // If starting with a clip, seek to start time
    if (activeClip.value != null) {
      videoPlayerController?.seekTo(
        Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
      );
    }
  }

}
