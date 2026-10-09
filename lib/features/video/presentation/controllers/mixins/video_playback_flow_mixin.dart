import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
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
  final RxDouble rxAspectRatio = (16 / 9).obs;
  ChewieController? get chewieController;
  set chewieController(ChewieController? c);
  Stopwatch get watchStopwatch;
  bool get isVpcInitialized;

  Future<void> initializeOfflinePlayback();
  Future<void> fetchAvailableResolutions();
  Future<void> fetchAvailableSubtitles();
  Future<void> fetchAvailableAudioTracks();
  Future<void> loadTranscriptForVideo({bool forceRefresh = false});
  Future<void> loadFactCheckData([String? overrideUrl, bool force = false]);
  Future<void> initializeVideoPlayer({String? overrideUrl});
  void disposePlayer();
  void videoListener();
  void videoErrorListener();
  void onChewieEvent();
  void flushRemainingWatchTime();
  Future<void> syncWatchHistory(int watchSeconds, int totalDuration);

  double get vpcAspectRatio {
    // 1. Sync from active TowerPlayerController if available
    try {
      final tpc = TowerPlayerRegistry.getForTagOrActive(video.id);
      if (tpc != null && tpc.aspectRatio.value > 0) {
        if ((rxAspectRatio.value - tpc.aspectRatio.value).abs() > 0.001) {
          rxAspectRatio.value = tpc.aspectRatio.value;
        }
      }
    } catch (_) {}

    // 2. Sync from underlying videoPlayerController if initialized
    final vpc = videoPlayerController;
    if (vpc != null && vpc.value.isInitialized) {
      try {
        final ratio = vpc.value.aspectRatio;
        if (ratio.isFinite && ratio > 0 && (rxAspectRatio.value - ratio).abs() > 0.001) {
          rxAspectRatio.value = ratio;
        }
      } catch (_) {}
    }

    return rxAspectRatio.value;
  }

  ChewieController buildChewieController({
    required VideoPlayerController vpc,
    required String videoId,
    required VoidCallback onChewieEvent,
    required Future<void> Function() onRetry,
  }) {
    final cc = ChewieController(
      videoPlayerController: vpc,
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
        if (isVpcInitialized && videoPlayerController != null) {
          pos = videoPlayerController!.value.position;
        }
      } catch (_) {}
      final videoToPlay = video;
      final selectedResUrl = currentResolution.value?.url;

      try {
        if (isVpcInitialized && videoPlayerController != null) {
          videoPlayerController!.pause().catchError((_) {});
        }
      } catch (_) {}

      try {
        if (videoPlayerController != null) {
          videoPlayerController!.removeListener(videoErrorListener);
          videoPlayerController!.removeListener(videoListener);
        }
      } catch (_) {}

      try {
        chewieController?.removeListener(onChewieEvent);
        chewieController?.dispose();
      } catch (_) {}
      chewieController = null;

      TowerPlayerController.pauseAllActivePlayers();

      final activeClipToPlay = activeClip.value;
      final isAudioOnlyToPlay = isAudioOnly.value;

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
            clip: activeClipToPlay,
            isAudioOnly: isAudioOnlyToPlay,
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
          currentResolution.value!.url.isNotEmpty &&
          (!kIsWeb || !currentResolution.value!.url.contains('.m3u8'))) {
        targetUrl = currentResolution.value!.url;
      } else if (!kIsWeb && video.hlsUrl.isNotEmpty) {
        targetUrl = video.hlsUrl;
      } else if (availableResolutions.isNotEmpty) {
        final mp4Res = availableResolutions.firstWhereOrNull(
          (r) => r.url.isNotEmpty && (!kIsWeb || !r.url.contains('.m3u8')),
        );
        if (mp4Res != null) {
          targetUrl = mp4Res.url;
        }
      } else if (video.adaptiveResolutions.isNotEmpty) {
        final mp4Res = video.adaptiveResolutions.firstWhereOrNull(
          (r) => r.url.isNotEmpty && (!kIsWeb || !r.url.contains('.m3u8')),
        );
        if (mp4Res != null) {
          targetUrl = mp4Res.url;
        }
      }
      if (targetUrl == null || targetUrl.isEmpty) {
        if (video.videoUrl.isNotEmpty &&
            (!kIsWeb || !video.videoUrl.contains('.m3u8'))) {
          targetUrl = video.videoUrl;
        } else if (video.originalUrl.isNotEmpty &&
            (!kIsWeb || !video.originalUrl.contains('.m3u8'))) {
          targetUrl = video.originalUrl;
        } else if (video.videoUrl.isNotEmpty) {
          targetUrl = video.videoUrl;
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
      } else if (video.adaptiveResolutions.isNotEmpty) {
        final mp4Res = video.adaptiveResolutions.firstWhereOrNull(
          (r) => !r.url.contains('.m3u8'),
        );
        if (mp4Res != null) {
          targetUrl = mp4Res.url;
        }
      } else if (video.videoUrl.isNotEmpty && !video.videoUrl.contains('.m3u8')) {
        targetUrl = video.videoUrl;
      } else if (video.originalUrl.isNotEmpty && !video.originalUrl.contains('.m3u8')) {
        targetUrl = video.originalUrl;
      }
    }

    if (targetUrl == null || targetUrl.isEmpty) {
      throw Exception('No optimized video resolution available');
    }

    return targetUrl;
  }

  Future<void> startPlaybackFlow({String? overrideUrl}) async {
    // 0. Check offline storage metadata first for instant 0ms offline playback
    try {
      final isExplicitOffline = Get.arguments is Map && Get.arguments['isOffline'] == true;
      final isExplicitAudio = isAudioOnly.value || (Get.arguments is Map && Get.arguments['isAudioOnly'] == true);
      final isDeviceOffline = Get.isRegistered<ConnectivityService>() &&
          !ConnectivityService.to.isConnected;

      final offlineMeta = await getOfflineVideoMetadata(video.id);
      if (offlineMeta != null) {
        if (isExplicitOffline || isDeviceOffline) {
          rxIsOffline.value = true;
          if (offlineMeta.isAudioOnly) {
            isAudioOnly.value = true;
          }
        } else if (!offlineMeta.isAudioOnly && !isExplicitAudio) {
          // Full video offline file on disk: safe to play offline to save data while showing full video
          rxIsOffline.value = true;
          isAudioOnly.value = false;
        } else if (offlineMeta.isAudioOnly && isExplicitAudio) {
          rxIsOffline.value = true;
          isAudioOnly.value = true;
        } else {
          // User is online and wants video, but offline download is only audio:
          // Do NOT hijack video playback into audio mode! Stream normal video from network.
          rxIsOffline.value = false;
          isAudioOnly.value = false;
          TowerPlayerPreferences.globalAudioOnly = false;
        }
      } else {
        if (!isExplicitOffline && !isDeviceOffline) {
          rxIsOffline.value = false;
        }
      }
    } catch (_) {}

    if (rxIsOffline.value) {
      await initializeOfflinePlayback();
      return;
    }

    // Populate initial resolutions and currentResolution immediately from in-memory video model
    if (availableResolutions.isEmpty && video.adaptiveResolutions.isNotEmpty) {
      final modelResolutions = video.adaptiveResolutions
          .where((r) => r.url.trim().isNotEmpty)
          .toList();
      if (modelResolutions.isNotEmpty) {
        modelResolutions.sort((a, b) => b.height.compareTo(a.height));
        availableResolutions.assignAll(modelResolutions);
        if (currentResolution.value == null) {
          final mp4 = modelResolutions.firstWhereOrNull(
            (r) =>
                !r.url.contains('.m3u8') && !r.url.endsWith('original.mp4'),
          ) ?? modelResolutions.first;
          currentResolution.value = mp4;
        }
      }
    }

    final mediaService = VideoMediaService();

    // 1. Kick off metadata loading in background concurrently:
    // Localization, credibility, subtitles, and audio tracks run without blocking playback.
    final Future<void> metadataFuture = () async {
      if (isClosed) return;
      await Future.wait<dynamic>([
        mediaService.getLocalization(video.id),
        mediaService.getCredibility(video.id),
      ]);
      if (isClosed) return;
      await Future.wait<void>([
        fetchAvailableResolutions(),
        fetchAvailableSubtitles(),
        fetchAvailableAudioTracks(),
      ]);
      if (isClosed) return;
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
        if (isClosed) return;
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

    // Check if we have an active handoff controller (from miniplayer or card hover/tap)
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
        if (isClosed) return;
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

    // 2. Playback strategy backed by Google CDN:
    //    - On native (iOS/Android/Desktop): Attempt HLS adaptive streaming for instant start
    //    - If HLS not available or on Web, immediately stream from best available Google CDN MP4
    var hlsSuccess = false;
    if (!kIsWeb && video.hlsUrl.isNotEmpty && !video.hlsUrl.startsWith('gs://')) {
      debugPrint('[VideoController] 🎬 Native playback: Using HLS adaptive stream from Google CDN');
      await initializeVideoPlayer(overrideUrl: video.hlsUrl);

      if (!videoError.value) {
        hlsSuccess = true;
        // Once metadata finishes, update the quality/resolution menu reactively
        metadataFuture.then((_) {
          if (isClosed) return;
          if (availableResolutions.isNotEmpty) {
            final best = availableResolutions.first;
            if (currentResolution.value?.url != best.url) {
              currentResolution.value = best;
            }
          }
        });
      } else {
        debugPrint('[VideoController] ⚠️ HLS stream failed, falling back to Google CDN MP4...');
        videoError.value = false;
        rxErrorMessage.value = '';
      }
    }

    if (!hlsSuccess) {
      debugPrint('[VideoController] 🌐 Instant Google CDN playback from best available stream...');

      // Find the best immediate Google CDN stream available in RAM synchronously (0ms)
      String? immediateStreamUrl;
      if (currentResolution.value != null &&
          currentResolution.value!.url.isNotEmpty &&
          (!kIsWeb || !currentResolution.value!.url.contains('.m3u8'))) {
        immediateStreamUrl = currentResolution.value!.url;
      } else if (availableResolutions.isNotEmpty) {
        final mp4Res = availableResolutions.firstWhereOrNull(
          (r) =>
              r.url.isNotEmpty &&
              (!kIsWeb || !r.url.contains('.m3u8')) &&
              !r.url.endsWith('original.mp4') &&
              !r.url.contains('/original/'),
        );
        immediateStreamUrl = (mp4Res ?? availableResolutions.first).url;
      } else if (video.adaptiveResolutions.isNotEmpty) {
        final mp4Res = video.adaptiveResolutions.firstWhereOrNull(
          (r) =>
              r.url.isNotEmpty &&
              (!kIsWeb || !r.url.contains('.m3u8')) &&
              !r.url.endsWith('original.mp4') &&
              !r.url.contains('/original/'),
        );
        immediateStreamUrl = (mp4Res ?? video.adaptiveResolutions.first).url;
      }

      if (immediateStreamUrl == null || immediateStreamUrl.isEmpty) {
        if (!kIsWeb &&
            video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.endsWith('original.mp4') &&
            !video.hlsUrl.contains('/original/')) {
          immediateStreamUrl = video.hlsUrl;
        } else if (video.videoUrl.isNotEmpty &&
            (!kIsWeb || !video.videoUrl.contains('.m3u8'))) {
          immediateStreamUrl = video.videoUrl;
        } else if (video.originalUrl.isNotEmpty &&
            (!kIsWeb || !video.originalUrl.contains('.m3u8'))) {
          immediateStreamUrl = video.originalUrl;
        } else if (video.videoUrl.isNotEmpty) {
          immediateStreamUrl = video.videoUrl;
        } else if (video.hlsUrl.isNotEmpty) {
          immediateStreamUrl = video.hlsUrl;
        }
      }

      if (immediateStreamUrl != null && immediateStreamUrl.isNotEmpty) {
        debugPrint('[VideoController] ⚡ Starting immediate Google CDN stream: $immediateStreamUrl');
        await initializeVideoPlayer(overrideUrl: immediateStreamUrl);
      } else {
        // Fallback only if no stream info existed on video model at all: wait for metadata
        debugPrint('[VideoController] ⚠️ No immediate stream on model, waiting for metadata...');
        await metadataFuture;
        if (availableResolutions.isNotEmpty) {
          final best = availableResolutions.first;
          currentResolution.value = best;
          await initializeVideoPlayer(overrideUrl: best.url);
        } else if (video.videoUrl.isNotEmpty) {
          await initializeVideoPlayer(overrideUrl: video.videoUrl);
        } else {
          videoError.value = true;
          rxErrorMessage.value =
              'This video is currently unavailable. Please try again later.';
          rxIsLoading.value = false;
          return;
        }
      }

      // Reactively wire metadata when background loading completes
      metadataFuture.then((_) {
        if (isClosed) return;
        if (availableResolutions.isNotEmpty) {
          final mp4Res = availableResolutions.firstWhereOrNull(
            (r) =>
                r.url.isNotEmpty &&
                (!kIsWeb || !r.url.contains('.m3u8')) &&
                !r.url.endsWith('original.mp4'),
          );
          final best = mp4Res ?? availableResolutions.first;
          if (currentResolution.value == null ||
              currentResolution.value?.url != best.url) {
            currentResolution.value = best;
          }
        }
      });
    }

    // If starting with a clip, seek to start time
    if (activeClip.value != null) {
      videoPlayerController?.seekTo(
        Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
      );
    }
  }

}
