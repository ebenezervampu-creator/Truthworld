import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_track_models.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/studio_video_resolution_resolver.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:video_player/video_player.dart';

/// GetX controller managing Chewie video playback and resolution switching for studio video tracks.
///
/// Enforces the platform standard: Never play raw video; play using processed resolutions.
class StudioChewieVideoPlayerController extends GetxController {
  StudioChewieVideoPlayerController({
    required this.video,
    required this.track,
  });

  static const _tag = 'StudioChewieVideoPlayerController';

  final Video video;
  final VideoTrackItem track;

  VideoPlayerController? _vpc;
  ChewieController? chewieController;

  VideoPlayerController? get videoPlayerController => _vpc;

  final RxBool isLoading = true.obs;
  final RxBool isSwitchingResolution = false.obs;
  final RxnString errorMessage = RxnString();
  final RxList<VideoResolutionV2> availableResolutions = <VideoResolutionV2>[].obs;
  final Rx<VideoResolutionV2?> currentResolution = Rx<VideoResolutionV2?>(null);

  @override
  void onInit() {
    super.onInit();
    unawaited(_initPlayer());
  }

  @override
  void onClose() {
    _safeDisposeControllers();
    super.onClose();
  }

  void _safeDisposeControllers() {
    try {
      chewieController?.pause();
      chewieController?.dispose();
      chewieController = null;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: '$_tag._safeDisposeControllers.chewie');
    }
    try {
      _vpc?.pause();
      _vpc?.dispose();
      _vpc = null;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: '$_tag._safeDisposeControllers.vpc');
    }
  }

  void retry() {
    unawaited(_initPlayer());
  }

  Future<void> switchResolution(VideoResolutionV2 res) async {
    if (currentResolution.value?.url == res.url) return;
    isSwitchingResolution.value = true;

    final seekTo = _vpc?.value.position ?? Duration.zero;
    final wasPlaying = _vpc?.value.isPlaying ?? false;

    await _initPlayer(
      targetResolution: res,
      seekTo: seekTo,
      autoPlay: wasPlaying,
    );

    isSwitchingResolution.value = false;
  }

  Future<void> _initPlayer({
    VideoResolutionV2? targetResolution,
    Duration seekTo = Duration.zero,
    bool autoPlay = true,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      _safeDisposeControllers();

      // 1. Gather candidate resolution URLs
      final candidateUrls = <String>[];

      if (track.isBaseTrack) {
        final resolutions = await StudioVideoResolutionResolver.resolveResolutions(video);
        availableResolutions.value = resolutions;

        if (targetResolution != null) {
          currentResolution.value = targetResolution;
          candidateUrls.add(targetResolution.url);
        } else {
          final defaultRes = StudioVideoResolutionResolver.pickDefaultResolution(resolutions);
          currentResolution.value = defaultRes;
          if (defaultRes != null) {
            candidateUrls.add(defaultRes.url);
          }
          // Add remaining resolutions as fallback candidates
          for (final r in resolutions) {
            if (!candidateUrls.contains(r.url)) {
              candidateUrls.add(r.url);
            }
          }
        }
      } else {
        // Dubbed video track
        availableResolutions.clear();
        currentResolution.value = null;
        if (track.videoUrl.trim().isNotEmpty) {
          candidateUrls.add(track.videoUrl.trim());
        }
      }

      // If candidates list is still empty, fallback to videoUrl resolved with token
      if (candidateUrls.isEmpty) {
        final rawFallback = track.videoUrl.isNotEmpty ? track.videoUrl : video.videoUrl;
        if (rawFallback.isNotEmpty) {
          candidateUrls.add(rawFallback);
        }
      }

      if (candidateUrls.isEmpty) {
        errorMessage.value = 'No playable video stream found for this track.';
        isLoading.value = false;
        return;
      }

      // 2. Resolve URLs via StorageUtils (guaranteeing valid download tokens / CDN signature)
      final resolvedCandidates = <String>[];
      for (final raw in candidateUrls) {
        final resolved = await StorageUtils.resolveUrl(raw);
        final target = resolved.isNotEmpty ? resolved : StorageUtils.getFastDownloadUrl(raw);
        if (target.isNotEmpty && !resolvedCandidates.contains(target)) {
          resolvedCandidates.add(target);
        }
      }

      if (resolvedCandidates.isEmpty) {
        errorMessage.value = 'Unable to resolve video playback stream.';
        isLoading.value = false;
        return;
      }

      // 3. Initialize VideoPlayerController with candidate fallback
      VideoPlayerController? initializedVpc;
      for (final targetUrl in resolvedCandidates) {
        try {
          final headers = StorageUtils.getSyncMediaHeaders();
          final uri = Uri.parse(targetUrl);
          final vpc = VideoPlayerController.networkUrl(
            uri,
            httpHeaders: headers,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );

          await vpc.initialize();
          initializedVpc = vpc;
          break;
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: '$_tag.initializeCandidate.failed',
          );
        }
      }

      if (initializedVpc == null) {
        errorMessage.value = 'Unable to load video stream. Please check connection and try again.';
        isLoading.value = false;
        return;
      }

      _vpc = initializedVpc;

      if (seekTo > Duration.zero && seekTo < _vpc!.value.duration) {
        await _vpc!.seekTo(seekTo);
      }

      final aspect = _vpc!.value.aspectRatio > 0 ? _vpc!.value.aspectRatio : 16 / 9;

      // 4. Create ChewieController with native controls and brand styling
      chewieController = ChewieController(
        videoPlayerController: _vpc!,
        autoPlay: autoPlay,
        allowedScreenSleep: false,
        aspectRatio: aspect,
        placeholder: const ColoredBox(
          color: Color(0xFF0F0F11),
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white12,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white12,
        ),
        errorBuilder: (context, errorMsg) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white70,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unable to load video stream.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: retry,
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      );

      isLoading.value = false;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: '$_tag._initPlayer');
      errorMessage.value = 'Unable to load video stream. Please check connection and try again.';
      isLoading.value = false;
    }
  }
}
