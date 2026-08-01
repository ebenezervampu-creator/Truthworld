import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Represents a single selectable audio track (base or dubbed language).
class AudioTrackOption {
  // true => original video audio

  const AudioTrackOption({
    required this.code,
    required this.label,
    this.audioUrl,
    this.isEmbedded = false,
  });
  final String code;
  final String label;
  final String? audioUrl; // null => use video's embedded audio
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
///   final ctrl = Get.find<MultiAudioPlayerController>();
///   ctrl.initialize(videoUrl, tracks);
class MultiAudioPlayerController extends GetxController {
  static const _tag = 'MultiAudioPlayerController';

  // ── Observable state ────────────────────────────────────────────────────────
  final isInitializing = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  final isPlaying = false.obs;
  final isMuted = false.obs;
  final volume = 1.0.obs;

  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final buffered = Duration.zero.obs;

  final availableTracks = <AudioTrackOption>[].obs;
  final selectedTrack = Rxn<AudioTrackOption>();
  final isChangingTrack = false.obs;

  final showControls = true.obs;
  final isFullscreen = false.obs;
  final playbackSpeed = 1.0.obs;

  // ── Internal ─────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  final AudioPlayer _dubPlayer = AudioPlayer();

  bool _dubMode = false; // true when a dubbed audio overlay is active
  bool _seeking = false;

  // Expose the raw VideoPlayerController so the view can build a VideoPlayer()
  VideoPlayerController? get videoController => _videoCtrl;
  ChewieController? chewieController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void onClose() {
    chewieController?.dispose();
    _videoCtrl?.dispose();
    _dubPlayer.dispose();
    super.onClose();
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Call once with the video URL and the list of audio track options.
  Future<void> initialize(
    String videoUrl, {
    required List<AudioTrackOption> tracks,
    String? preferredTrackCode,
  }) async {
    isInitializing.value = true;
    hasError.value = false;

    try {
      // Tear down any previous session
      await _videoCtrl?.dispose();
      await _dubPlayer.stop();

      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoCtrl!.initialize();

      _videoCtrl!.addListener(_onVideoTick);

      chewieController?.dispose();
      chewieController = ChewieController(
        videoPlayerController: _videoCtrl!,
        showControls: false,
        autoInitialize: true,
        allowedScreenSleep: false,
        aspectRatio: _videoCtrl!.value.aspectRatio,
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

      duration.value = _videoCtrl!.value.duration;
      availableTracks.value = tracks;

      // Pick starting track
      final preferred = tracks.firstWhereOrNull(
        (t) => t.code == (preferredTrackCode ?? 'en'),
      );
      await _selectTrackInternal(
        preferred ?? tracks.first,
        seek: Duration.zero,
      );

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
      errorMessage.value = e.toString();
      isInitializing.value = false;
    }
  }

  Future<void> switchTrack(AudioTrackOption track) async {
    if (track.code == selectedTrack.value?.code) return;
    isChangingTrack.value = true;

    final resumePos = position.value;
    final wasPlaying = isPlaying.value;

    await _pauseAll();
    await _selectTrackInternal(track, seek: resumePos);

    if (wasPlaying) play();
    isChangingTrack.value = false;
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
    showControls.value = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (isPlaying.value) showControls.value = false;
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  Future<void> _selectTrackInternal(
    AudioTrackOption track, {
    required Duration seek,
  }) async {
    selectedTrack.value = track;

    if (track.isEmbedded || track.audioUrl == null || track.audioUrl!.isEmpty) {
      // Use the video's own audio
      _dubMode = false;
      await _dubPlayer.stop();
      _videoCtrl?.setVolume(_effectiveVolume());
    } else {
      // Dubbed track – mute the video, play dubbed audio in sync
      _dubMode = true;
      _videoCtrl?.setVolume(0);
      await _dubPlayer.setUrl(track.audioUrl!);
      await _dubPlayer.seek(seek);
      _dubPlayer.setVolume(_effectiveVolume());
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
        if (drift > const Duration(milliseconds: 300)) {
          _dubPlayer.seek(v.position);
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
