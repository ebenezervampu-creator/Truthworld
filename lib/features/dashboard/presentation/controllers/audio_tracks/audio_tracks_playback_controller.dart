import 'dart:async';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';

/// Coordinator for inline audio track preview playback across devices.
class AudioTracksPlaybackController extends BaseController {
  static const String _tag = 'AudioTracksPlayback';

  final AudioPlayer _player = AudioPlayer();

  // Observable playback states
  final RxString activeTrackId = ''.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isMuted = false.obs;
  final RxDouble volume = 1.0.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void onInit() {
    super.onInit();
    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    try {
      _playerStateSub = trackSubscription(_player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          isPlaying.value = false;
          position.value = Duration.zero;
          // Explicitly pause the player to reset playWhenReady to false before seeking.
          // In just_audio, state.playing remains true at completion; seeking to zero
          // without pausing causes ExoPlayer to immediately resume, triggering an infinite replay loop.
          _player.pause().then((_) {
            _player.seek(Duration.zero).catchError((_) {});
          }).catchError((_) {});
        } else {
          isPlaying.value = state.playing;
        }
      }, onError: (e) {
        logger.error('AudioPlayer state stream error', error: e, tag: _tag);
      }));

      _positionSub = trackSubscription(_player.positionStream.listen((pos) {
        position.value = pos;
      }, onError: (e) {
        logger.error('AudioPlayer position stream error', error: e, tag: _tag);
      }));

      _durationSub = trackSubscription(_player.durationStream.listen((dur) {
        if (dur != null && dur > Duration.zero) {
          duration.value = dur;
        }
      }, onError: (e) {
        logger.error('AudioPlayer duration stream error', error: e, tag: _tag);
      }));
    } catch (e) {
      logger.error('Failed subscribing to AudioPlayer streams', error: e, tag: _tag);
    }
  }

  /// Toggles playback for a specified audio track.
  Future<void> togglePlay(
    String trackId,
    String audioUrl, {
    Duration? fallbackDuration,
  }) async {
    final cleanUrl = audioUrl.trim();
    if (cleanUrl.isEmpty) {
      AppSnackbar.info('No audio file uploaded for this track yet.');
      return;
    }

    try {
      TowerPlayerRegistry.pauseAllActivePlayers();
      MultiAudioPlayerController.pauseAll();
    } catch (_) {}

    if (activeTrackId.value == trackId) {
      if (isPlaying.value) {
        await pause();
      } else {
        await resume();
      }
      return;
    }

    // New track activation
    activeTrackId.value = trackId;
    position.value = Duration.zero;
    if (fallbackDuration != null && fallbackDuration > Duration.zero) {
      duration.value = fallbackDuration;
    }

    try {
      await _player.stop();
      final resolvedUrl = await StorageUtils.resolveUrl(cleanUrl);
      final playUrl = resolvedUrl.isNotEmpty ? resolvedUrl : cleanUrl;
      final headers = await StorageUtils.getMediaHeaders();
      await _player.setUrl(
        playUrl,
        headers: headers.isNotEmpty ? headers : null,
      );
      await _player.setVolume(isMuted.value ? 0.0 : volume.value);
      await _player.play();
      isPlaying.value = true;
    } catch (e) {
      logger.error('Error starting audio playback for: $cleanUrl', error: e, tag: _tag);
      // Graceful fallback for unreachable or invalid URLs without exposing raw errors
      isPlaying.value = false;
      AppSnackbar.error('Unable to play audio preview. Please check your connection.');
    }
  }

  /// Pauses currently playing track.
  Future<void> pause() async {
    try {
      await _player.pause();
      isPlaying.value = false;
    } catch (e) {
      logger.error('Error pausing audio', error: e, tag: _tag);
    }
  }

  /// Resumes currently selected track.
  Future<void> resume() async {
    try {
      await _player.play();
      isPlaying.value = true;
    } catch (e) {
      logger.error('Error resuming audio', error: e, tag: _tag);
    }
  }

  /// Seeks to specified position.
  Future<void> seek(Duration newPosition) async {
    position.value = newPosition;
    try {
      await _player.seek(newPosition);
    } catch (e) {
      logger.error('Error seeking audio track', error: e, tag: _tag);
    }
  }

  /// Toggles mute state.
  Future<void> toggleMute() async {
    isMuted.value = !isMuted.value;
    try {
      await _player.setVolume(isMuted.value ? 0.0 : volume.value);
    } catch (e) {
      logger.error('Error toggling audio mute', error: e, tag: _tag);
    }
  }

  /// Stops playback and clears pointer.
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    isPlaying.value = false;
    activeTrackId.value = '';
    position.value = Duration.zero;
  }

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    try {
      _player.stop();
    } catch (_) {}
    _player.dispose();
    super.onClose();
  }
}
