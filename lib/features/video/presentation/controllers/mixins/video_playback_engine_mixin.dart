import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
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
  ChewieController? get chewieController;
  set chewieController(ChewieController? c);

  RxBool get rxIsLoading;
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
  Stopwatch get watchStopwatch;
  RxBool get isSubscribed;
  bool get isRecoveringFromFormatError;

  VideoAnalyticsController get analyticsController;
  MainController get mainController;
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

  Future<void> initializeVideoPlayer({String? overrideUrl}) async {
    final isAuto = isAutoSwitching.value;

    final isHandoffAvailable = VideoPlaybackHandoff.isActive(video.id);

    if (!isAuto && !isHandoffAvailable) {
      rxIsLoading.value = true;
      // Do NOT call disposePlayer() here. Keeping old controller alive until
      // newVpc is initialized and synced ensures a seamless warm swap with zero
      // error flashes.
    }

    videoError.value = false;
    if (!isHandoffAvailable) {
      showThumbnail.value = true;
    } else {
      showThumbnail.value = false;
      rxIsLoading.value = false;
    }

    if (video.status == VideoStatus.rejected ||
        video.visibility == 'rejected' ||
        video.channelStatus == 'rejected') {
      videoError.value = true;
      rxErrorMessage.value =
          'This video has been removed for violating community guidelines.';
      rxIsLoading.value = false;
      return;
    }

    try {
      final targetUrl = (await resolvePlaybackTargetUrl(overrideUrl: overrideUrl))!;

      debugPrint('[VideoController] Initializing player for: $targetUrl');

      final oldVpc = videoPlayerController;
      final oldCc = chewieController;

      // Attempt to retrieve a pre-warmed/hovered controller for zero-latency startup
      final handoffVpc = VideoPlaybackHandoff.retrieveController(video.id);
      final VideoPlayerController newVpc;
      final wasHandoff = handoffVpc != null;

      if (wasHandoff) {
        debugPrint(
          '[VideoController] Found active handoff controller for: ${video.id}',
        );
        newVpc = handoffVpc;
        await newVpc.setLooping(
          false,
        ); // Disable looping which was enabled for hover previews
        await newVpc.setVolume(1); // Reset volume to unmute on watch screen
        rxIsLoading.value = false;
        showThumbnail.value = false;
      } else if (!kIsWeb &&
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
                httpHeaders: const {
                  'Connection': 'keep-alive',
                  'Accept': '*/*',
                },
                videoPlayerOptions: VideoPlayerOptions(
                  mixWithOthers: true,
                  allowBackgroundPlayback: true,
                ),
              );
      }

      HoverPreviewCoordinator.globalMute.value = true;

      if (!newVpc.value.isInitialized) {
        await newVpc.initialize().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Video initialization timeout');
          },
        );
      }

      // Ensure volume is set to full unmuted playback on watch screen
      try {
        await newVpc.setVolume(1.0);
      } catch (e) {
        debugPrint('[VideoController] setVolume error: $e');
      }

      // Add listeners AFTER initialization succeeds to prevent race conditions during setup
      newVpc.addListener(videoErrorListener);
      newVpc.addListener(videoListener);

      // --- CLIP MODE & RESUME LOGIC (Seek BEFORE play to prevent 0:00 audio/video flash) ---
      if (wasHandoff) {
        // Handed off controller is already at the live playing frame!
        // Do NOT seek backwards to WatchHistoryService or initial position.
        debugPrint(
          '[VideoController] ⏩ Handed off controller already at ${newVpc.value.position.inSeconds}s. Continuing seamlessly.',
        );
        initialSeekPosition = null;
        if (!newVpc.value.isPlaying) {
          try {
            await newVpc.play();
          } catch (_) {}
        }
      } else {
        if (activeClip.value != null) {
          final startMs = (activeClip.value!.startTime * 1000).toInt();
          debugPrint(
            '[VideoController] 🎬 Seeking player to clip start time: ${activeClip.value!.startTime}s ($startMs ms)',
          );
          await newVpc.seekTo(Duration(milliseconds: startMs));
        } else if (initialSeekPosition != null && initialSeekPosition! > Duration.zero) {
          debugPrint(
            '[VideoController] ⏩ Seeking player to resume/start timestamp: ${initialSeekPosition!.inSeconds}s',
          );
          await newVpc.seekTo(initialSeekPosition!);
          initialSeekPosition = null; // Consume once
        } else {
          final lastPos = WatchHistoryService.to.getLastPosition(video.id);
          if (lastPos > 0 && lastPos < newVpc.value.duration.inSeconds - 10) {
            // Seek to last position
            await newVpc.seekTo(Duration(seconds: lastPos));

            // Show resume snackbar
            Get.snackbar(
              'Resuming Video',
              'Resumed from ${Duration(seconds: lastPos).toString().split('.').first.padLeft(8, '0').substring(3)}',
              snackPosition: SnackPosition.BOTTOM,
              mainButton: TextButton(
                onPressed: () {
                  newVpc.seekTo(Duration.zero);
                  Get.back();
                },
                child: const Text(
                  'Start Over',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: AppColors.bgPage.withValues(alpha: 0.7),
              colorText: AppColors.textPrimary,
            );
          }
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

      // Track initiation
      if (!isAuto && !wasHandoff) {
        final isSub = isSubscribed.value;
        final isNotSub = !isSub;
        // Start stopwatch immediately for accurate tracking from second 0
        if (!watchStopwatch.isRunning) watchStopwatch.start();

        mainController.trackWatchEvent(
          videoId: video.id,
          channelId: video.channelId,
          eventType: 'video_start',
          position: 0,
          duration: newVpc.value.duration.inSeconds,
          isSubscriber: isSub,
          isNotSubscriber: isNotSub,
        );
      }

      videoPlayerController = newVpc;

      // Sync active TowerPlayerController immediately before disposing old controller
      try {
        if (Get.isRegistered<TowerPlayerController>(tag: video.id)) {
          Get.find<TowerPlayerController>(tag: video.id).sync(newVpc);
        } else if (Get.isRegistered<TowerPlayerController>()) {
          Get.find<TowerPlayerController>().sync(newVpc);
        }
      } catch (e) {
        debugPrint('[VideoController] TowerPlayer sync error: $e');
      }

      final isPremium = Get.isRegistered<AuthService>() &&
          AuthService.to.isPremiumUser.value;
      final hasPreRollAd = !isPremium &&
          Get.isRegistered<AdService>() &&
          (AdService.to.getSponsorAdForVideo(video.id) != null ||
              AdService.to.getSkippableVideoAds().isNotEmpty);

      chewieController = ChewieController(
        videoPlayerController: videoPlayerController!,
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
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: initializeVideoPlayer,
                  icon: const Icon(Icons.refresh, color: Colors.white),
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

      // Listen for fullscreen changes from Chewie
      chewieController!.addListener(onChewieEvent);

      // Warm handoff: dispose old ones now that new ones are ready and synced
      if (oldVpc != null && oldVpc != newVpc) {
        try {
          oldVpc.removeListener(videoErrorListener);
          oldVpc.removeListener(videoListener);
        } catch (_) {}
        try {
          oldCc?.removeListener(onChewieEvent);
          oldCc?.dispose();
        } catch (_) {}
        try {
          oldVpc.dispose();
        } catch (_) {}
      }

      debugPrint(
        '[VideoController] Player initialized successfully (Handoff: $isAuto)',
      );
    } catch (e, stackTrace) {
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
      rxIsLoading.value = false;
    }
  }

  void disposePlayer() {
    videoSubscription?.cancel();
    languageRequestsSubscription?.cancel();
    try {
      chewieController?.removeListener(onChewieEvent);
    } catch (_) {}
    try {
      videoPlayerController?.removeListener(videoErrorListener);
      videoPlayerController?.removeListener(videoListener);
    } catch (_) {}
    try {
      chewieController?.dispose();
    } catch (_) {}
    chewieController = null;
    try {
      analyticsController.stopTimer();
    } catch (_) {}
    try {
      videoPlayerController?.dispose();
    } catch (_) {}
    videoPlayerController = null;
  }

}
