// ============================================================
// playback_source.dart
// Abstract Playback Authority and Sources for Truthworld Media
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:video_player/video_player.dart';

/// Enum representing the explicit playback mode of the player state machine.
enum PlaybackMode {
  video,
  audio,
  switchingToAudio,
  switchingToVideo,
}

/// Abstract interface for active playback authority.
/// Shields UI components and controllers from platform-specific player details.
abstract class PlaybackSource {
  Duration get position;
  Duration get duration;
  bool get isPlaying;
  ValueListenable<Duration> get positionListenable;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// Video playback authority wrapping [VideoPlayerController].
class VideoPlaybackSource implements PlaybackSource {
  VideoPlaybackSource(this._controller) {
    _controller.addListener(_onControllerChanged);
  }
  final VideoPlayerController _controller;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );

  void _onControllerChanged() {
    if (_controller.value.isInitialized) {
      _positionNotifier.value = _controller.value.position;
    }
  }

  @override
  Duration get position => _controller.value.position;

  @override
  Duration get duration => _controller.value.duration;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  ValueListenable<Duration> get positionListenable => _positionNotifier;

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seek(Duration position) => _controller.seekTo(position);

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  Future<void> dispose() async {
    _controller.removeListener(_onControllerChanged);
    _positionNotifier.dispose();
  }
}

/// Audio playback authority wrapping [AudioOnlyService].
class AudioPlaybackSource implements PlaybackSource {
  AudioPlaybackSource(this._service) {
    _service.position.listen((sec) {
      _positionNotifier.value = Duration(milliseconds: (sec * 1000).round());
    });
  }
  final AudioOnlyService _service;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );

  @override
  Duration get position => Duration(
    milliseconds: (_service.position.value * 1000).round(),
  );

  @override
  Duration get duration => Duration(
    milliseconds: (_service.duration.value * 1000).round(),
  );

  @override
  bool get isPlaying => _service.isPlaying.value;

  @override
  ValueListenable<Duration> get positionListenable => _positionNotifier;

  @override
  Future<void> play() => _service.play();

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> seek(Duration position) => _service.seekTo(position);

  @override
  Future<void> setVolume(double volume) async => _service.setVolume(volume);

  @override
  Future<void> dispose() async {
    _positionNotifier.dispose();
  }
}
