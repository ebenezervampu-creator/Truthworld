import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/studio_video_resolution_resolver.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Represents a single selectable audio track (base or dubbed language).
class AudioTrackOption {
  const AudioTrackOption({
    required this.code,
    required this.label,
    this.audioUrl,
    this.videoUrl,
    this.isEmbedded = false,
  });

  final String code;
  final String label;
  final String? audioUrl; // null => use video's embedded audio
  final String? videoUrl; // non-null => pre-rendered dubbed video available
  final bool isEmbedded;
}

/// Controls synchronised playback of a video + optional dubbed audio overlay.
///
/// Architecture:
///   • [VideoPlayerController] always plays the video frames.
///   • When the user picks an embedded track → video audio is un-muted.
///   • When the user picks a dubbed track  → video is muted and [AudioPlayer]
///     (just_audio) plays the dubbed file in lockstep.
///
/// Usage:
///   final ctrl = Get.find`MultiAudioPlayerController`();
///   ctrl.initialize(videoUrl, tracks);
class MultiAudioPlayerController extends BaseController {
  static const _tag = 'MultiAudioPlayerController';

  // ── Observable state ────────────────────────────────────────────────────────
  final RxBool isInitializing = true.obs;
  final RxBool hasError = false.obs;
  final RxString rxErrorMessage = ''.obs;

  final RxBool isPlaying = false.obs;
  final RxBool isMuted = false.obs;
  final RxDouble volume = 1.0.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final Rx<Duration> buffered = Duration.zero.obs;

  final RxList<AudioTrackOption> availableTracks = <AudioTrackOption>[].obs;
  final selectedTrack = Rxn<AudioTrackOption>();
  final RxBool isChangingTrack = false.obs;

  // ── Resolution state (Strictly non-raw processed streams) ──────────────────
  final RxList<VideoResolutionV2> availableResolutions = <VideoResolutionV2>[].obs;
  final Rx<VideoResolutionV2?> currentResolution = Rx<VideoResolutionV2?>(null);
  final RxBool isSwitchingResolution = false.obs;

  final RxBool showControls = true.obs;
  final RxBool isFullscreen = false.obs;
  final RxDouble playbackSpeed = 1.0.obs;

  // ── Internal ─────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  final AudioPlayer _dubPlayer = AudioPlayer();
  Timer? _flashControlsTimer;
  String _baseVideoUrl = '';

  bool _dubMode = false; // true when a dubbed audio overlay is active
  bool _seeking = false;
  bool _isSyncSeeking = false;

  // Expose the raw VideoPlayerController so the view can build a VideoPlayer()
  VideoPlayerController? get videoController => _videoCtrl;
  ChewieController? chewieController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void onClose() {
    _flashControlsTimer?.cancel();
    _flashControlsTimer = null;
    if (_videoCtrl != null) {
      _videoCtrl!.removeListener(_onVideoTick);
      _videoCtrl!.dispose();
      _videoCtrl = null;
    }
    chewieController?.dispose();
    _dubPlayer.dispose();
    super.onClose();
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Checks if a given URL is a raw video file (which must NEVER be played directly).
  static bool isRawVideoUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.endsWith('original.mp4') ||
        lower.contains('/original/') ||
        lower.endsWith('.raw');
  }

  /// Rebuilds the ChewieController instance with brand styling.
  void rebuildChewieController({required double aspectRatio}) {
    chewieController?.dispose();
    chewieController = ChewieController(
      videoPlayerController: _videoCtrl!,
      showControls: false,
      allowedScreenSleep: false,
      aspectRatio: aspectRatio,
      placeholder: const ColoredBox(
        color: AppColors.bgPage,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.brand,
        handleColor: AppColors.brand,
        bufferedColor: AppColors.brand.withValues(alpha: 0.33),
        backgroundColor: AppColors.brand.withValues(alpha: 0.2),
      ),
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: AppColors.brand,
        handleColor: AppColors.brand,
        bufferedColor: AppColors.brand.withValues(alpha: 0.33),
        backgroundColor: AppColors.brand.withValues(alpha: 0.2),
      ),
    );
  }

  /// Switches active playback resolution dynamically, seeking to current position without interruption.
  Future<void> switchResolution(VideoResolutionV2 res) async {
    if (currentResolution.value?.url == res.url) return;
    isSwitchingResolution.value = true;

    try {
      final currentPos = position.value;
      final wasPlaying = isPlaying.value;

      currentResolution.value = res;
      final resolvedUrl = await StorageUtils.resolveUrl(res.url);
      final target = resolvedUrl.isNotEmpty ? resolvedUrl : StorageUtils.getFastDownloadUrl(res.url);
      if (target.isEmpty) throw Exception('Unable to resolve resolution stream');

      final newCtrl = VideoPlayerController.networkUrl(
        Uri.parse(target),
        httpHeaders: StorageUtils.getSyncMediaHeaders(),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await newCtrl.initialize();

      _videoCtrl?.removeListener(_onVideoTick);
      await _videoCtrl?.dispose();
      _videoCtrl = newCtrl;
      _baseVideoUrl = target;
      _videoCtrl!.addListener(_onVideoTick);

      if (currentPos > Duration.zero && currentPos < _videoCtrl!.value.duration) {
        await _videoCtrl!.seekTo(currentPos);
      }

      rebuildChewieController(
        aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
      );

      if (wasPlaying) {
        play();
      }
    } catch (e, s) {
      logger.error('Failed switching resolution to ${res.label}', error: e, stackTrace: s, tag: _tag);
    } finally {
      isSwitchingResolution.value = false;
    }
  }

  /// Call once with the video URL and the list of audio track options.
  Future<void> initialize(
    String videoUrl, {
    required List<AudioTrackOption> tracks,
    String? preferredTrackCode,
    Video? video,
    VideoResolutionV2? targetResolution,
  }) async {
    isInitializing.value = true;
    hasError.value = false;

    try {
      // Tear down any previous session
      if (_videoCtrl != null) {
        _videoCtrl!.removeListener(_onVideoTick);
        await _videoCtrl!.dispose();
        _videoCtrl = null;
      }
      await _dubPlayer.stop();

      // Gather candidate non-raw resolution streams
      final candidateUrls = <String>[];
      if (video != null) {
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
          for (final r in resolutions) {
            if (!candidateUrls.contains(r.url)) {
              candidateUrls.add(r.url);
            }
          }
        }
      }

      // STRICT ZERO RAW VIDEO: Never add raw URLs
      if (videoUrl.trim().isNotEmpty && !isRawVideoUrl(videoUrl) && !candidateUrls.contains(videoUrl.trim())) {
        candidateUrls.add(videoUrl.trim());
      }

      if (candidateUrls.isEmpty) {
        throw Exception('No playable processed video resolutions found. Transcoding in progress.');
      }

      VideoPlayerController? initializedCtrl;
      String? successfulBaseUrl;
      for (final rawUrl in candidateUrls) {
        try {
          final resolvedUrl = await StorageUtils.resolveUrl(rawUrl);
          final target = resolvedUrl.isNotEmpty ? resolvedUrl : StorageUtils.getFastDownloadUrl(rawUrl);
          if (target.isEmpty) continue;

          final ctrl = VideoPlayerController.networkUrl(
            Uri.parse(target),
            httpHeaders: StorageUtils.getSyncMediaHeaders(),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await ctrl.initialize();
          initializedCtrl = ctrl;
          successfulBaseUrl = target;
          break;
        } catch (err) {
          logger.warning('Failed candidate stream: $rawUrl ($err)', tag: _tag);
        }
      }

      if (initializedCtrl == null) {
        throw Exception('Unable to load video stream.');
      }

      _videoCtrl = initializedCtrl;
      _baseVideoUrl = successfulBaseUrl ?? '';
      _videoCtrl!.addListener(_onVideoTick);

      rebuildChewieController(
        aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
      );

      duration.value = _videoCtrl!.value.duration;
      availableTracks.value = tracks;

      // Pick starting track
      if (tracks.isNotEmpty) {
        final preferred = tracks.firstWhereOrNull(
          (t) => t.code == (preferredTrackCode ?? 'en'),
        );
        final initialTrack = preferred ?? tracks.firstOrNull;
        if (initialTrack != null) {
          await _selectTrackInternal(
            initialTrack,
            seek: Duration.zero,
          );
        }
      }

      isInitializing.value = false;
      play();
    } catch (e, s) {
      logger.error(
        'Failed initialising MultiAudioPlayerController',
        error: e,
        stackTrace: s,
        tag: _tag,
      );
      hasError.value = true;
      rxErrorMessage.value = AppException.from(e, s).displayMessage;
      isInitializing.value = false;
    }
  }

  Future<void> switchTrack(AudioTrackOption track) async {
    if (track.code == selectedTrack.value?.code) return;
    isChangingTrack.value = true;

    final resumePos = position.value;
    final wasPlaying = isPlaying.value;

    try {
      await _pauseAll();
      await _selectTrackInternal(track, seek: resumePos);
      if (wasPlaying) play();
    } catch (e, s) {
      logger.error('Failed switching audio track to ${track.code}', error: e, stackTrace: s, tag: _tag);
      _dubMode = false;
      _videoCtrl?.setVolume(_effectiveVolume());
      if (wasPlaying) play();
    } finally {
      isChangingTrack.value = false;
    }
  }

  void play() {
    _videoCtrl?.play();
    if (_dubMode) _dubPlayer.play();
    isPlaying.value = true;
  }

  void pause() {
    _pauseAll();
    isPlaying.value = false;
  }

  Future<void> seekTo(Duration pos) async {
    _seeking = true;
    await _videoCtrl?.seekTo(pos);
    if (_dubMode) {
      final dubDur = _dubPlayer.duration ?? Duration.zero;
      if (dubDur > Duration.zero && pos <= dubDur) {
        await _dubPlayer.seek(pos);
      } else {
        await _dubPlayer.pause();
      }
    }
    position.value = pos;
    _seeking = false;
  }

  void setVolume(double v) {
    volume.value = v.clamp(0.0, 1.0);
    _applyVolume();
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    _applyVolume();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed.value = speed;
    await _videoCtrl?.setPlaybackSpeed(speed);
    await _dubPlayer.setSpeed(speed);
  }

  void setFullscreen(bool value) => isFullscreen.value = value;

  void flashControls() {
    _flashControlsTimer?.cancel();
    showControls.value = true;
    _flashControlsTimer = Timer(const Duration(seconds: 3), () {
      if (isPlaying.value) showControls.value = false;
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  Future<void> _selectTrackInternal(
    AudioTrackOption track, {
    required Duration seek,
  }) async {
    selectedTrack.value = track;

    try {
      // 1. Dubbed video container (pre-rendered MP4 with dubbed language audio)
      if (track.videoUrl != null && track.videoUrl!.isNotEmpty) {
        _dubMode = false;
        await _dubPlayer.stop();

        final rawVideo = track.videoUrl!;
        final resolvedVideo = await StorageUtils.resolveUrl(rawVideo);
        final target = resolvedVideo.isNotEmpty ? resolvedVideo : StorageUtils.getFastDownloadUrl(rawVideo);

        if (target.isNotEmpty && _videoCtrl?.dataSource != target) {
          final newCtrl = VideoPlayerController.networkUrl(
            Uri.parse(target),
            httpHeaders: StorageUtils.getSyncMediaHeaders(),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await newCtrl.initialize();

          _videoCtrl?.removeListener(_onVideoTick);
          await _videoCtrl?.dispose();
          _videoCtrl = newCtrl;
          _videoCtrl!.addListener(_onVideoTick);

          if (seek > Duration.zero && seek < _videoCtrl!.value.duration) {
            await _videoCtrl!.seekTo(seek);
          }
          _videoCtrl!.setVolume(_effectiveVolume());

          rebuildChewieController(
            aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
          );
          duration.value = _videoCtrl!.value.duration;
        }
        return;
      }

      // 2. Base / embedded track (or no separate dubbed audio)
      if (track.isEmbedded || track.audioUrl == null || track.audioUrl!.isEmpty) {
        _dubMode = false;
        await _dubPlayer.stop();

        // Restore base video stream if currently playing a dubbed video
        if (_baseVideoUrl.isNotEmpty && _videoCtrl?.dataSource != _baseVideoUrl) {
          try {
            final newCtrl = VideoPlayerController.networkUrl(
              Uri.parse(_baseVideoUrl),
              httpHeaders: StorageUtils.getSyncMediaHeaders(),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            );
            await newCtrl.initialize();

            _videoCtrl?.removeListener(_onVideoTick);
            await _videoCtrl?.dispose();
            _videoCtrl = newCtrl;
            _videoCtrl!.addListener(_onVideoTick);

            if (seek > Duration.zero && seek < _videoCtrl!.value.duration) {
              await _videoCtrl!.seekTo(seek);
            }
            rebuildChewieController(
              aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
            );
            duration.value = _videoCtrl!.value.duration;
          } catch (e) {
            logger.warning('Unable to switch back to base video stream: $e', tag: _tag);
          }
        }

        _videoCtrl?.setVolume(_effectiveVolume());
        return;
      }

      // 3. Dubbed audio overlay track (video frames from base video + synced audio from just_audio)
      _dubMode = true;

      // Restore base video if needed
      if (_baseVideoUrl.isNotEmpty && _videoCtrl?.dataSource != _baseVideoUrl) {
        try {
          final newCtrl = VideoPlayerController.networkUrl(
            Uri.parse(_baseVideoUrl),
            httpHeaders: StorageUtils.getSyncMediaHeaders(),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await newCtrl.initialize();

          _videoCtrl?.removeListener(_onVideoTick);
          await _videoCtrl?.dispose();
          _videoCtrl = newCtrl;
          _videoCtrl!.addListener(_onVideoTick);

          if (seek > Duration.zero && seek < _videoCtrl!.value.duration) {
            await _videoCtrl!.seekTo(seek);
          }
          rebuildChewieController(
            aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
          );
          duration.value = _videoCtrl!.value.duration;
        } catch (e) {
          logger.warning('Unable to switch back to base video stream: $e', tag: _tag);
        }
      }

      _videoCtrl?.setVolume(0);

      final rawAudioUrl = track.audioUrl!;
      final resolvedAudio = await StorageUtils.resolveUrl(rawAudioUrl);
      final targetAudio = resolvedAudio.isNotEmpty ? resolvedAudio : StorageUtils.getFastDownloadUrl(rawAudioUrl);

      if (targetAudio.isNotEmpty) {
        await _dubPlayer.setUrl(
          targetAudio,
          headers: StorageUtils.getSyncMediaHeaders(),
        );
        if (seek > Duration.zero) {
          await _dubPlayer.seek(seek);
        }
        _dubPlayer.setVolume(_effectiveVolume());
      }
    } catch (e, s) {
      logger.error('Failed selecting track ${track.code}: $e', error: e, stackTrace: s, tag: _tag);
      _dubMode = false;
      _videoCtrl?.setVolume(_effectiveVolume());
    }
  }

  Future<void> _pauseAll() async {
    await _videoCtrl?.pause();
    await _dubPlayer.pause();
    isPlaying.value = false;
  }

  void _onVideoTick() {
    final v = _videoCtrl?.value;
    if (v == null) return;

    if (!_seeking) position.value = v.position;

    // Sync dub player if it drifts more than 300 ms
    if (_dubMode && v.isPlaying) {
      final dubDur = _dubPlayer.duration ?? Duration.zero;
      if (dubDur > Duration.zero && v.position > dubDur) {
        if (_dubPlayer.playing) {
          _dubPlayer.pause();
        }
      } else {
        final dubPos = _dubPlayer.position;
        final drift = (v.position - dubPos).abs();
        if (drift > const Duration(milliseconds: 300) && !_isSyncSeeking) {
          _isSyncSeeking = true;
          _dubPlayer.seek(v.position).catchError((_) {}).whenComplete(() {
            _isSyncSeeking = false;
          });
        }
      }
    }

    // Detect end of video
    if (v.position >= v.duration && v.duration > Duration.zero) {
      isPlaying.value = false;
      _dubPlayer.pause();
    }
  }

  void _applyVolume() {
    final v = isMuted.value ? 0.0 : volume.value;
    if (!_dubMode) _videoCtrl?.setVolume(v);
    if (_dubMode) _dubPlayer.setVolume(v);
  }

  double _effectiveVolume() => isMuted.value ? 0.0 : volume.value;
}
