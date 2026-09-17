import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:video_player/video_player.dart';

/// Mixin handling studio video player preview, playback sync, and cue highlighting
mixin SubtitlesPlayerMixin on SubtitlesControllerBase {
  @override
  Future<void> initVideoPlayer(Video video) async {
    try {
      isVideoPlayerInitialized.value = false;
      disposeVideoPlayer();

      var playUrl = '';

      // 1. Check adaptiveResolutions on video model for valid processed resolution streams
      if (video.adaptiveResolutions.isNotEmpty) {
        final valid = video.adaptiveResolutions.where((r) {
          final u = r.url.trim().toLowerCase();
          final l = r.label.toLowerCase();
          return u.isNotEmpty &&
              !l.contains('audio') &&
              !u.contains('/audio') &&
              !u.endsWith('original.mp4') &&
              !u.contains('/original/');
        }).toList();

        if (valid.isNotEmpty) {
          // Select preferred resolution for studio subtitle player (720p/480p or first available)
          final preferred = valid.firstWhereOrNull((r) => r.height == 720 || r.label == '720p') ??
              valid.firstWhereOrNull((r) => r.height == 480 || r.label == '480p') ??
              valid.first;
          playUrl = preferred.url;
        }
      }

      // 2. Check HLS stream
      if (playUrl.isEmpty && video.hlsUrl.isNotEmpty && !video.hlsUrl.endsWith('original.mp4')) {
        playUrl = video.hlsUrl;
      }

      // 3. Fallback to fetching streaming resolutions via VideoMediaService if model lacks resolutions
      if (playUrl.isEmpty && video.id.isNotEmpty) {
        try {
          final streaming = await VideoMediaService().getStreaming(video.id);
          if (streaming.adaptiveResolutions.isNotEmpty) {
            final valid = streaming.adaptiveResolutions.where((r) {
              final u = r.url.trim().toLowerCase();
              final l = r.label.toLowerCase();
              return u.isNotEmpty &&
                  !l.contains('audio') &&
                  !u.contains('/audio') &&
                  !u.endsWith('original.mp4') &&
                  !u.contains('/original/');
            }).toList();
            if (valid.isNotEmpty) {
              playUrl = valid.first.url;
            }
          }
          if (playUrl.isEmpty && streaming.hlsUrl.isNotEmpty && !streaming.hlsUrl.endsWith('original.mp4')) {
            playUrl = streaming.hlsUrl;
          }
        } catch (e) {
          logger.warning('Could not fetch streaming data for subtitles preview: $e', tag: SubtitlesControllerBase.subtitlesTag);
        }
      }

      if (playUrl.isEmpty) {
        logger.warning('No processed resolution stream found for video: ${video.id}. Raw video playback is disabled.', tag: SubtitlesControllerBase.subtitlesTag);
        isVideoPlayerInitialized.value = false;
        return;
      }

      playUrl = await StorageUtils.resolveUrl(playUrl);
      if (playUrl.isEmpty) return;

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      videoPlayerController = controller;
      videoDuration.value = controller.value.duration;
      isVideoPlayerInitialized.value = true;
      controller.addListener(onVideoPlayerUpdate);
    } catch (e) {
      logger.error('Error initializing video preview player',
          error: e, tag: SubtitlesControllerBase.subtitlesTag);
      isVideoPlayerInitialized.value = false;
    }
  }

  @override
  void disposeVideoPlayer() {
    videoPlayerController?.removeListener(onVideoPlayerUpdate);
    videoPlayerController?.dispose();
    videoPlayerController = null;
    isVideoPlayerInitialized.value = false;
    isVideoPlaying.value = false;
    currentVideoPosition.value = Duration.zero;
    videoDuration.value = Duration.zero;
    activeCueIndex.value = -1;
  }

  void onVideoPlayerUpdate() {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) {
      return;
    }
    currentVideoPosition.value = videoPlayerController!.value.position;
    isVideoPlaying.value = videoPlayerController!.value.isPlaying;
    updateActiveCueIndex(videoPlayerController!.value.position);
  }

  void updateActiveCueIndex(Duration position) {
    if (currentCues.isEmpty) {
      activeCueIndex.value = -1;
      return;
    }
    final posMs = position.inMilliseconds;
    for (var i = 0; i < currentCues.length; i++) {
      final cue = currentCues[i];
      final startMs =
          SubtitleParser.parseTimeDuration(cue.startTime).inMilliseconds;
      final endMs =
          SubtitleParser.parseTimeDuration(cue.endTime).inMilliseconds;
      if (posMs >= startMs && posMs <= endMs) {
        if (activeCueIndex.value != i) {
          activeCueIndex.value = i;
        }
        return;
      }
    }
    activeCueIndex.value = -1;
  }

  Future<void> seekTo(Duration position) async {
    if (videoPlayerController != null && isVideoPlayerInitialized.value) {
      await videoPlayerController!.seekTo(position);
    }
  }

  Future<void> seekToCue(int index) async {
    if (index < 0 || index >= currentCues.length) return;
    final cue = currentCues[index];
    final dur = SubtitleParser.parseTimeDuration(cue.startTime);
    await seekTo(dur);
  }

  Future<void> togglePlayPause() async {
    if (videoPlayerController == null || !isVideoPlayerInitialized.value) return;
    if (videoPlayerController!.value.isPlaying) {
      await videoPlayerController!.pause();
      isVideoPlaying.value = false;
    } else {
      await videoPlayerController!.play();
      isVideoPlaying.value = true;
    }
  }

  void toggleVideoPreview() {
    showVideoPreview.toggle();
  }
}
