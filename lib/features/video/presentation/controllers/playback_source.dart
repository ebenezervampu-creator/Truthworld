// ============================================================
// playback_source.dart
// Abstract Playback Authority and Sources for Truthworld Media
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
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
    try {
      _controller.addListener(_onControllerChanged);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackSource.addListener',
      );
    }
  }
  final VideoPlayerController _controller;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );

  void _onControllerChanged() {
    try {
      if (_controller.value.isInitialized) {
        _positionNotifier.value = _controller.value.position;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackSource._onControllerChanged',
      );
    }
  }

  @override
  Duration get position {
    try {
      return _controller.value.position;
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  Duration get duration {
    try {
      return _controller.value.duration;
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  bool get isPlaying {
    try {
      return _controller.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  @override
  ValueListenable<Duration> get positionListenable => _positionNotifier;

  @override
  Future<void> play() async {
    try {
      await _controller.play();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackSource.play',
      );
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _controller.pause();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackSource.pause',
      );
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _controller.seekTo(position);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackSource.seek',
      );
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _controller.setVolume(volume);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackSource.setVolume',
      );
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _controller.removeListener(_onControllerChanged);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoPlaybackSource.dispose',
      );
    }
    _positionNotifier.dispose();
  }
}

/// Audio playback authority wrapping [AudioOnlyService].
class AudioPlaybackSource implements PlaybackSource {
  AudioPlaybackSource(this._service) {
    _positionSubscription = _service.position.listen((sec) {
      _positionNotifier.value = Duration(milliseconds: (sec * 1000).round());
    }, onError: (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioPlaybackSource.position',
      );
    });
  }
  final AudioOnlyService _service;
  StreamSubscription? _positionSubscription;
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
    _positionSubscription?.cancel();
    _positionNotifier.dispose();
  }
}
