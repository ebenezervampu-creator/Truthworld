import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_tracks_playback_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/studio_video_resolution_resolver.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
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

  // ── Global Studio Controller Coordination ────────────────────────────────────
  static final List<MultiAudioPlayerController> _activeStudioControllers = [];

  /// Pauses all active studio controllers to prevent concurrent audio playback.
  static void pauseAll() {
    for (final c in List<MultiAudioPlayerController>.from(_activeStudioControllers)) {
      try {
        c.pause();
      } catch (_) {}
    }
  }

  /// Disposes all active studio controllers.
  static void disposeAll() {
    for (final c in List<MultiAudioPlayerController>.from(_activeStudioControllers)) {
      try {
        c.pause();
        c.dispose();
      } catch (_) {}
    }
    _activeStudioControllers.clear();
  }

  // ── Internal ─────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  final AudioPlayer _dubPlayer = AudioPlayer();
  Timer? _flashControlsTimer;
  String _baseVideoUrl = '';

  bool _dubMode = false; // true when a dubbed audio overlay is active
  bool _seeking = false;
  bool _isSyncSeeking = false;
  int _initEpoch = 0;
  int _trackSwitchEpoch = 0;

  // Expose the raw VideoPlayerController so the view can build a VideoPlayer()
  VideoPlayerController? get videoController => _videoCtrl;
  ChewieController? chewieController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    if (!_activeStudioControllers.contains(this)) {
      _activeStudioControllers.add(this);
    }
  }
  @override
  void onClose() {
    _activeStudioControllers.remove(this);
    _flashControlsTimer?.cancel();
    _flashControlsTimer = null;
    if (_videoCtrl != null) {
      _videoCtrl!.removeListener(_onVideoTick);
      try {
        _videoCtrl!.pause();
      } catch (_) {}
      try {
        _videoCtrl!.dispose();
      } catch (_) {}
      _videoCtrl = null;
    }
    try {
      chewieController?.pause();
    } catch (_) {}
    try {
      chewieController?.dispose();
    } catch (_) {}
    chewieController = null;
    try {
      _dubPlayer.stop();
    } catch (_) {}
    try {
      _dubPlayer.dispose();
    } catch (_) {}
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
    if (isClosed || currentResolution.value?.url == res.url) return;
    isSwitchingResolution.value = true;

    try {
      final currentPos = position.value;
      final wasPlaying = isPlaying.value;

      currentResolution.value = res;
      final resolvedUrl = await StorageUtils.resolveUrl(res.url);
      if (isClosed) return;
      final target = resolvedUrl.isNotEmpty ? resolvedUrl : StorageUtils.getFastDownloadUrl(res.url);
      if (target.isEmpty) throw Exception('Unable to resolve resolution stream');

      final newCtrl = VideoPlayerController.networkUrl(
        Uri.parse(target),
        httpHeaders: StorageUtils.getSyncMediaHeaders(),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await newCtrl.initialize();
      if (isClosed) {
        try {
          await newCtrl.dispose();
        } catch (_) {}
        return;
      }

      _videoCtrl?.removeListener(_onVideoTick);
      try {
        await _videoCtrl?.dispose();
      } catch (_) {}
      if (isClosed) {
        try {
          await newCtrl.dispose();
        } catch (_) {}
        return;
      }

      _videoCtrl = newCtrl;
      _baseVideoUrl = target;
      _videoCtrl!.addListener(_onVideoTick);

      if (currentPos > Duration.zero && currentPos < _videoCtrl!.value.duration) {
        await _videoCtrl!.seekTo(currentPos);
      }
      if (isClosed) return;

      if (_dubMode) {
        _videoCtrl!.setVolume(0.0);
      } else {
        _videoCtrl!.setVolume(_effectiveVolume());
      }

      rebuildChewieController(
        aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
      );

      if (wasPlaying && !isClosed) {
        play();
      }
    } catch (e, s) {
      if (!isClosed) {
        logger.error('Failed switching resolution to ${res.label}', error: e, stackTrace: s, tag: _tag);
      }
    } finally {
      if (!isClosed) {
        isSwitchingResolution.value = false;
      }
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
    if (isClosed) return;
    final currentEpoch = ++_initEpoch;
    isInitializing.value = true;
    hasError.value = false;

    try {
      // Immediately tear down any previous session and silence players
      _dubMode = false;
      if (_videoCtrl != null) {
        _videoCtrl!.removeListener(_onVideoTick);
        try {
          _videoCtrl!.pause();
          await _videoCtrl!.dispose();
        } catch (_) {}
        _videoCtrl = null;
      }
      try {
        chewieController?.pause();
        chewieController?.dispose();
        chewieController = null;
      } catch (_) {}
      if (isClosed || currentEpoch != _initEpoch) return;
      try {
        await _dubPlayer.stop();
      } catch (_) {}
      if (isClosed || currentEpoch != _initEpoch) return;

      // Gather candidate non-raw resolution streams
      final candidateUrls = <String>[];
      if (video != null) {
        final resolutions = await StudioVideoResolutionResolver.resolveResolutions(video);
        if (isClosed || currentEpoch != _initEpoch) return;
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
        if (isClosed || currentEpoch != _initEpoch) return;
        try {
          final resolvedUrl = await StorageUtils.resolveUrl(rawUrl);
          if (isClosed || currentEpoch != _initEpoch) return;
          final target = resolvedUrl.isNotEmpty ? resolvedUrl : StorageUtils.getFastDownloadUrl(rawUrl);
          if (target.isEmpty) continue;

          final isFirebaseStorage = target.contains('firebasestorage.googleapis.com') && target.contains('token=');
          final ctrl = VideoPlayerController.networkUrl(
            Uri.parse(target),
            httpHeaders: isFirebaseStorage ? const <String, String>{} : StorageUtils.getSyncMediaHeaders(),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await ctrl.initialize();
          if (isClosed || currentEpoch != _initEpoch) {
            try {
              await ctrl.dispose();
            } catch (_) {}
            return;
          }
          initializedCtrl = ctrl;
          successfulBaseUrl = target;
          break;
        } catch (err) {
          logger.warning('Failed candidate stream: $rawUrl ($err)', tag: _tag);
        }
      }

      if (isClosed || currentEpoch != _initEpoch) {
        try {
          await initializedCtrl?.dispose();
        } catch (_) {}
        return;
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

      // Pick starting track (defaults to base embedded track or preferred)
      if (tracks.isNotEmpty) {
        final preferred = tracks.firstWhereOrNull(
          (t) => t.code == preferredTrackCode,
        );
        final baseTrack = tracks.firstWhereOrNull((t) => t.isEmbedded);
        final initialTrack = preferred ?? baseTrack ?? tracks.firstOrNull;
        if (initialTrack != null) {
          await _selectTrackInternal(
            initialTrack,
            seek: Duration.zero,
          );
          if (isClosed || currentEpoch != _initEpoch) return;
        }
      }

      if (isClosed || currentEpoch != _initEpoch) return;
      isInitializing.value = false;
      play();
    } catch (e, s) {
      if (isClosed || currentEpoch != _initEpoch) return;
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
    if (isClosed) return;
    if (track.code == selectedTrack.value?.code &&
        _dubMode == (!track.isEmbedded && track.audioUrl != null && track.audioUrl!.isNotEmpty)) {
      return;
    }
    isChangingTrack.value = true;

    final wasPlaying = isPlaying.value;

    try {
      final isSeamlessAudio = (track.videoUrl == null || track.videoUrl!.isEmpty) &&
          (_baseVideoUrl.isEmpty || _videoCtrl?.dataSource == _baseVideoUrl);

      if (isSeamlessAudio) {
        await _switchAudioTrackSeamless(track, wasPlaying: wasPlaying);
      } else {
        // Video container change required (e.g. pre-rendered dubbed MP4 video)
        await _pauseAll();
        if (isClosed) return;
        final resumePos = position.value;
        await _selectTrackInternal(track, seek: resumePos);
        if (isClosed) return;
        if (wasPlaying) play();
      }
    } on PlayerInterruptedException catch (_) {
      // Audio loading was superseded by a newer track selection; graceful no-op
    } catch (e, s) {
      if (!isClosed) {
        logger.error('Failed switching audio track to ${track.code}', error: e, stackTrace: s, tag: _tag);
        _dubMode = false;
        _videoCtrl?.setVolume(_effectiveVolume());
        if (wasPlaying && _videoCtrl != null && !_videoCtrl!.value.isPlaying) {
          _videoCtrl?.play();
        }
        AppSnackbar.warning('Unable to switch audio track. Playing original audio.');
      }
    } finally {
      if (!isClosed) {
        isChangingTrack.value = false;
      }
    }
  }

  /// Seamless in-flight audio track switch without pausing or buffering video frames.
  Future<void> _switchAudioTrackSeamless(
    AudioTrackOption track, {
    required bool wasPlaying,
  }) async {
    if (isClosed) return;
    final switchEpoch = ++_trackSwitchEpoch;

    // 1. Base / embedded track (or no separate dubbed audio)
    // Instantaneous: silence dub player and restore volume to running video player.
    if (track.isEmbedded || track.audioUrl == null || track.audioUrl!.isEmpty) {
      _dubMode = false;
      selectedTrack.value = track;
      try {
        await _dubPlayer.stop();
      } catch (_) {}
      try {
        await _dubPlayer.setVolume(0.0);
      } catch (_) {}
      if (!isClosed && switchEpoch == _trackSwitchEpoch) {
        _videoCtrl?.setVolume(_effectiveVolume());
      }
      return;
    }

    // 2. Dubbed audio overlay track:
    // Video continues playing uninterrupted in the background while audio stream connects.
    final rawAudioUrl = track.audioUrl!;
    final resolvedAudio = await StorageUtils.resolveUrl(rawAudioUrl);
    if (isClosed || switchEpoch != _trackSwitchEpoch) return;
    final targetAudio = resolvedAudio.isNotEmpty
        ? resolvedAudio
        : StorageUtils.getFastDownloadUrl(rawAudioUrl);

    if (targetAudio.isNotEmpty) {
      final isFirebaseStorage = targetAudio.contains('firebasestorage.googleapis.com') && targetAudio.contains('token=');
      final headers = isFirebaseStorage ? null : StorageUtils.getSyncMediaHeaders();

      await _dubPlayer.setUrl(
        targetAudio,
        headers: headers,
      );
      if (isClosed || switchEpoch != _trackSwitchEpoch) return;

      final livePos = _videoCtrl?.value.position ?? position.value;
      if (livePos > Duration.zero) {
        try {
          await _dubPlayer.seek(livePos);
        } catch (_) {}
      }
      if (isClosed || switchEpoch != _trackSwitchEpoch) return;

      selectedTrack.value = track;
      _dubMode = true;
      _videoCtrl?.setVolume(0.0);
      try {
        await _dubPlayer.setVolume(_effectiveVolume());
      } catch (_) {}
      if (isClosed || switchEpoch != _trackSwitchEpoch) return;

      if (wasPlaying && (_videoCtrl?.value.isPlaying ?? false)) {
        try {
          await _dubPlayer.play();
        } catch (_) {}
      } else if (!wasPlaying) {
        try {
          await _dubPlayer.pause();
        } catch (_) {}
      }
    }
  }

  void play() {
    if (isClosed) return;
    try {
      TowerPlayerRegistry.pauseAllActivePlayers();
      if (Get.isRegistered<AudioTracksPlaybackController>()) {
        Get.find<AudioTracksPlaybackController>().stop();
      }
      for (final c in _activeStudioControllers) {
        if (c != this && !c.isClosed) {
          try {
            c.pause();
          } catch (_) {}
        }
      }
      if (!_activeStudioControllers.contains(this)) {
        _activeStudioControllers.add(this);
      }
    } catch (_) {}

    if (isClosed) return;
    if (_dubMode) {
      _videoCtrl?.setVolume(0.0);
      try {
        _dubPlayer.setVolume(_effectiveVolume());
        _dubPlayer.play();
      } catch (_) {}
    } else {
      try {
        _dubPlayer.setVolume(0.0);
        _dubPlayer.pause();
      } catch (_) {}
      _videoCtrl?.setVolume(_effectiveVolume());
    }
    try {
      _videoCtrl?.play();
    } catch (_) {}
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

  Future<void> toggleFullscreen(
    BuildContext context, {
    dynamic video,
    dynamic tracksController,
    VoidCallback? onAddDubTrack,
  }) async {
    if (isFullscreen.value) {
      exitFullscreen(context);
    } else {
      await enterFullscreen(
        context,
        video: video,
        tracksController: tracksController,
        onAddDubTrack: onAddDubTrack,
      );
    }
  }

  Future<void> enterFullscreen(
    BuildContext context, {
    dynamic video,
    dynamic tracksController,
    VoidCallback? onAddDubTrack,
  }) async {
    if (isFullscreen.value) return;
    isFullscreen.value = true;
    if (kIsWeb) {
      if (!WebPlatformUtils.isFullscreen()) {
        WebPlatformUtils.requestFullscreen();
      }
    } else {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } catch (_) {}
    }
  }

  void exitFullscreen(BuildContext? context) {
    if (!isFullscreen.value) return;
    isFullscreen.value = false;
    if (kIsWeb) {
      if (WebPlatformUtils.isFullscreen()) {
        WebPlatformUtils.exitFullscreen();
      }
    } else {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (_) {}
    }
  }

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
    if (isClosed) return;
    selectedTrack.value = track;

    try {
      // 1. Dubbed video container (pre-rendered MP4 with dubbed language audio)
      if (track.videoUrl != null && track.videoUrl!.isNotEmpty) {
        _dubMode = false;
        try {
          await _dubPlayer.stop().timeout(const Duration(milliseconds: 300), onTimeout: () {});
        } catch (_) {}
        if (isClosed) return;

        final rawVideo = track.videoUrl!;
        final resolvedVideo = await StorageUtils.resolveUrl(rawVideo);
        if (isClosed) return;
        final target = resolvedVideo.isNotEmpty ? resolvedVideo : StorageUtils.getFastDownloadUrl(rawVideo);

        if (target.isNotEmpty && _videoCtrl?.dataSource != target) {
          final newCtrl = VideoPlayerController.networkUrl(
            Uri.parse(target),
            httpHeaders: StorageUtils.getSyncMediaHeaders(),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await newCtrl.initialize();
          if (isClosed) {
            try {
              await newCtrl.dispose();
            } catch (_) {}
            return;
          }

          _videoCtrl?.removeListener(_onVideoTick);
          try {
            await _videoCtrl?.dispose();
          } catch (_) {}
          if (isClosed) {
            try {
              await newCtrl.dispose();
            } catch (_) {}
            return;
          }

          _videoCtrl = newCtrl;
          _videoCtrl!.addListener(_onVideoTick);

          if (seek > Duration.zero && seek < _videoCtrl!.value.duration) {
            await _videoCtrl!.seekTo(seek);
          }
          if (isClosed) return;

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
        try {
          await _dubPlayer.stop().timeout(const Duration(milliseconds: 300), onTimeout: () {});
        } catch (_) {}
        try {
          await _dubPlayer.setVolume(0.0).timeout(const Duration(milliseconds: 300), onTimeout: () {});
        } catch (_) {}
        if (isClosed) return;

        // Restore base video stream if currently playing a dubbed video
        if (_baseVideoUrl.isNotEmpty && _videoCtrl?.dataSource != _baseVideoUrl) {
          try {
            final newCtrl = VideoPlayerController.networkUrl(
              Uri.parse(_baseVideoUrl),
              httpHeaders: StorageUtils.getSyncMediaHeaders(),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            );
            await newCtrl.initialize();
            if (isClosed) {
              try {
                await newCtrl.dispose();
              } catch (_) {}
              return;
            }

            _videoCtrl?.removeListener(_onVideoTick);
            try {
              await _videoCtrl?.dispose();
            } catch (_) {}
            if (isClosed) {
              try {
                await newCtrl.dispose();
              } catch (_) {}
              return;
            }

            _videoCtrl = newCtrl;
            _videoCtrl!.addListener(_onVideoTick);

            if (seek > Duration.zero && seek < _videoCtrl!.value.duration) {
              await _videoCtrl!.seekTo(seek);
            }
            if (isClosed) return;

            rebuildChewieController(
              aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
            );
            duration.value = _videoCtrl!.value.duration;
          } catch (e) {
            if (!isClosed) {
              logger.warning('Unable to switch back to base video stream: $e', tag: _tag);
            }
          }
        }

        if (!isClosed) {
          _videoCtrl?.setVolume(_effectiveVolume());
        }
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
          if (isClosed) {
            try {
              await newCtrl.dispose();
            } catch (_) {}
            return;
          }

          _videoCtrl?.removeListener(_onVideoTick);
          try {
            await _videoCtrl?.dispose();
          } catch (_) {}
          if (isClosed) {
            try {
              await newCtrl.dispose();
            } catch (_) {}
            return;
          }

          _videoCtrl = newCtrl;
          _videoCtrl!.addListener(_onVideoTick);

          if (seek > Duration.zero && seek < _videoCtrl!.value.duration) {
            await _videoCtrl!.seekTo(seek);
          }
          if (isClosed) return;

          rebuildChewieController(
            aspectRatio: _videoCtrl!.value.aspectRatio > 0 ? _videoCtrl!.value.aspectRatio : 16 / 9,
          );
          duration.value = _videoCtrl!.value.duration;
        } catch (e) {
          if (!isClosed) {
            logger.warning('Unable to switch back to base video stream: $e', tag: _tag);
          }
        }
      }

      if (isClosed) return;
      _videoCtrl?.setVolume(0.0);

      final rawAudioUrl = track.audioUrl!;
      final resolvedAudio = await StorageUtils.resolveUrl(rawAudioUrl);
      if (isClosed) return;
      final targetAudio = resolvedAudio.isNotEmpty ? resolvedAudio : StorageUtils.getFastDownloadUrl(rawAudioUrl);

      if (targetAudio.isNotEmpty) {
        final isFirebaseStorage = targetAudio.contains('firebasestorage.googleapis.com') && targetAudio.contains('token=');
        final headers = isFirebaseStorage ? null : StorageUtils.getSyncMediaHeaders();

        await _dubPlayer.setUrl(
          targetAudio,
          headers: headers,
        );
        if (isClosed) return;

        if (seek > Duration.zero) {
          try {
            await _dubPlayer.seek(seek);
          } catch (_) {}
        }
        if (isClosed) return;

        try {
          await _dubPlayer.setVolume(_effectiveVolume());
        } catch (_) {}
      }
    } on PlayerInterruptedException catch (_) {
      // Audio loading was superseded by a newer track selection
    } catch (e, s) {
      if (!isClosed) {
        logger.error('Failed selecting track ${track.code}: $e', error: e, stackTrace: s, tag: _tag);
        _dubMode = false;
        try {
          await _dubPlayer.stop();
        } catch (_) {}
        _videoCtrl?.setVolume(_effectiveVolume());
      }
    }
  }

  Future<void> _pauseAll() async {
    isPlaying.value = false;
    try {
      if (_videoCtrl != null) {
        await _videoCtrl!.pause();
      }
    } catch (_) {}
    try {
      await _dubPlayer.pause();
    } catch (_) {}
  }

  void _onVideoTick() {
    final v = _videoCtrl?.value;
    if (v == null) return;

    if (!_seeking) position.value = v.position;

    if (!_dubMode) {
      if (_dubPlayer.playing) {
        _dubPlayer.pause();
        _dubPlayer.setVolume(0.0);
      }
    } else {
      // Strictly enforce video is muted during dubbed playback
      if (v.volume > 0.0) {
        _videoCtrl?.setVolume(0.0);
      }

      if (!v.isPlaying) {
        if (_dubPlayer.playing) {
          _dubPlayer.pause();
        }
      } else {
        // Synchronise dub playback with video
        if (!_dubPlayer.playing && isPlaying.value) {
          _dubPlayer.setVolume(_effectiveVolume());
          _dubPlayer.play();
        }

        final dubDur = _dubPlayer.duration ?? Duration.zero;
        if (dubDur > Duration.zero && v.position > dubDur) {
          if (_dubPlayer.playing) {
            _dubPlayer.pause();
          }
        } else {
          final dubPos = _dubPlayer.position;
          final drift = (v.position - dubPos).abs();
          if (drift > const Duration(milliseconds: 600) &&
              !_isSyncSeeking &&
              _dubPlayer.playerState.processingState == ProcessingState.ready) {
            _isSyncSeeking = true;
            _dubPlayer.seek(v.position).catchError((_) {}).whenComplete(() {
              Future.delayed(const Duration(milliseconds: 1000), () {
                _isSyncSeeking = false;
              });
            });
          }
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
    final v = _effectiveVolume();
    if (!_dubMode) {
      _dubPlayer.setVolume(0.0);
      _dubPlayer.pause();
      _videoCtrl?.setVolume(v);
    } else {
      _videoCtrl?.setVolume(0.0);
      _dubPlayer.setVolume(v);
    }
  }

  double _effectiveVolume() => isMuted.value ? 0.0 : volume.value;
}
