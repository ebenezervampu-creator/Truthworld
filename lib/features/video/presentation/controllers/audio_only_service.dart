// ============================================================
// audio_only_service.dart
// Industry-Standard Audio-Only Pipeline for Flutter Web & Native
// Uses: Web Audio API (Web) & just_audio (Native Android / iOS)
// Standard: Matches music audio pipeline
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';

/// Audio-Only playback service for true background & low-bandwidth playback.
/// Bypasses video decoding for maximum battery and data efficiency.
class AudioOnlyService extends GetxService {
  // ── State ──────────────────────────────────────────────────
  final RxBool isAudioOnly = false.obs;
  final RxBool isActive = false.obs;
  final RxDouble volume = 1.0.obs;
  final RxBool isMuted = false.obs;
  final RxString currentTrackTitle = ''.obs;
  final RxString currentArtwork = ''.obs;
  final RxDouble position = 0.0.obs;
  final RxDouble duration = 0.0.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isBuffering = false.obs;
  final RxString error = ''.obs;

  // ── Native (just_audio) Player ─────────────────────────────
  AudioPlayer? _nativePlayer;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  // ── Web Audio API Adapter ──────────────────────────────────
  WebAudioPlayerAdapter? _webAudioPlayer;
  Timer? _positionTimer;
  String? _currentLoadedUrl;

  // ── Equalizer state ────────────────────────────────────────
  final RxDouble bassGain = 0.0.obs;
  final RxDouble midGain = 0.0.obs;
  final RxDouble trebleGain = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    if (kIsWeb) {
      _initWebAudioAPI();
      _setupMediaSessionAPI();
    } else {
      _initNativeAudio();
    }
  }

  // ── Native Initialization ──────────────────────────────────

  Future<void> _initNativeAudio() async {
    try {
      _nativePlayer = AudioPlayer();

      _playerStateSub = _nativePlayer!.playerStateStream.listen((state) {
        isPlaying.value = state.playing;
        switch (state.processingState) {
          case ProcessingState.idle:
            isBuffering.value = false;
          case ProcessingState.loading:
          case ProcessingState.buffering:
            isBuffering.value = true;
          case ProcessingState.ready:
            isBuffering.value = false;
          case ProcessingState.completed:
            isPlaying.value = false;
            isBuffering.value = false;
            _onTrackEnded();
        }
      });

      _positionSub = _nativePlayer!.positionStream.listen((pos) {
        position.value = pos.inMilliseconds / 1000.0;
      });

      _durationSub = _nativePlayer!.durationStream.listen((dur) {
        if (dur != null) {
          duration.value = dur.inMilliseconds / 1000.0;
        }
      });

      debugPrint('[AudioOnly] Native just_audio player initialized');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.initNativeAudio',
      );
    }
  }

  // ── Web Initialization ─────────────────────────────────────

  void _initWebAudioAPI() {
    if (!kIsWeb) return;

    try {
      _webAudioPlayer = WebPlatformUtils.createAudioPlayer();
      _webAudioPlayer!.init(
        onPlay: () => isPlaying.value = true,
        onPause: () => isPlaying.value = false,
        onEnded: () {
          isPlaying.value = false;
          _onTrackEnded();
        },
        onWaiting: () => isBuffering.value = true,
        onCanPlay: () => isBuffering.value = false,
        onError: (err) {
          error.value = 'Unable to play audio. Please check your connection and try again.';
          ErrorHandler.log(
            'Audio element error: $err',
            tag: 'AudioOnlyService.webAudio',
          );
        },
        onDurationChange: (dur) {
          duration.value = dur;
        },
      );

      debugPrint('[AudioOnly] Web Audio API initialized');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.initWebAudioAPI',
      );
    }
  }

  void _setupMediaSessionAPI() {
    if (!kIsWeb || _webAudioPlayer == null) return;

    try {
      _webAudioPlayer!.setupMediaSession(
        onPlay: play,
        onPause: pause,
        onSeekRelative: (sec) => seekRelative(sec.toInt()),
        onPreviousTrack: _onPreviousTrack,
        onNextTrack: _onNextTrack,
      );

      debugPrint('[AudioOnly] Media Session API registered');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.setupMediaSessionAPI',
      );
    }
  }

  final RxBool isBackgroundPlayback = false.obs;

  // ── Core Playback API ──────────────────────────────────────

  Future<void> activateBackgroundPlayback({
    required String mediaUrl,
    required String title,
    required String artworkUrl,
    required Duration startPosition,
    bool autoPlay = true,
  }) async {
    isBackgroundPlayback.value = true;
    await activate(
      videoUrl: mediaUrl,
      title: title,
      artworkUrl: artworkUrl,
      startPosition: startPosition,
    );
    if (!autoPlay) {
      await pause();
    }
  }

  Future<void> activate({
    required String videoUrl,
    required String title,
    required String artworkUrl,
    Duration? startPosition,
    String? audioStreamUrl,
  }) async {
    isActive.value = true;
    isAudioOnly.value = true;
    currentTrackTitle.value = title;
    currentArtwork.value = artworkUrl;
    error.value = '';

    final audioUrl = _resolveAudioUrl(videoUrl);

    if (_currentLoadedUrl == audioUrl && isActive.value && isPlaying.value) {
      if (startPosition != null && startPosition > Duration.zero) {
        seekTo(startPosition);
      }
      return;
    }
    _currentLoadedUrl = audioUrl;

    if (kIsWeb) {
      try {
        _webAudioPlayer?.loadAndPlay(
          audioUrl,
          volume: volume.value,
        );

        if (startPosition != null && startPosition > Duration.zero) {
          _webAudioPlayer?.seek(startPosition.inMilliseconds / 1000.0);
        }

        _startPositionTracking();
        _updateMediaSessionMetadata(title: title, artworkUrl: artworkUrl);

        debugPrint('[AudioOnly] Web Audio Playing: $audioUrl');
      } catch (e, stackTrace) {
        error.value =
            'Unable to start audio stream. Please check your connection and try again.';
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AudioOnlyService.activate.web',
        );
      }
    } else {
      try {
        if (_nativePlayer == null) await _initNativeAudio();

        await _nativePlayer!.setUrl(audioUrl);

        if (startPosition != null && startPosition > Duration.zero) {
          await _nativePlayer!.seek(startPosition);
        }

        await _nativePlayer!.setVolume(volume.value);
        await _nativePlayer!.play();

        debugPrint('[AudioOnly] Native Audio Playing: $audioUrl');
      } catch (e, stackTrace) {
        error.value =
            'Unable to start audio stream. Please check your connection and try again.';
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AudioOnlyService.activate.native',
        );
      }
    }
  }

  String _resolveAudioUrl(String videoUrl) {
    if (videoUrl.contains('.m3u8')) {
      return videoUrl;
    }
    return videoUrl;
  }

  Future<void> play() async {
    try {
      if (kIsWeb) {
        _webAudioPlayer?.play();
      } else {
        await _nativePlayer?.play();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.play',
      );
    }
  }

  Future<void> pause() async {
    try {
      if (kIsWeb) {
        _webAudioPlayer?.pause();
      } else {
        await _nativePlayer?.pause();
      }
      isPlaying.value = false;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.pause',
      );
    }
  }

  Future<void> seekTo(Duration pos) async {
    if (kIsWeb) {
      if (_webAudioPlayer == null) return;
      _webAudioPlayer!.seek(pos.inMilliseconds / 1000.0);
    } else {
      await _nativePlayer?.seek(pos);
    }
  }

  Future<void> seekRelative(int seconds) async {
    if (kIsWeb) {
      if (_webAudioPlayer == null) return;
      final newTime = (_webAudioPlayer!.currentTime + seconds).clamp(
        0.0,
        _webAudioPlayer!.duration,
      );
      _webAudioPlayer!.seek(newTime);
    } else {
      final cur = _nativePlayer?.position ?? Duration.zero;
      final target = cur + Duration(seconds: seconds);
      await _nativePlayer?.seek(target);
    }
  }

  void setVolume(double vol) {
    volume.value = vol.clamp(0.0, 1.0);
    if (kIsWeb) {
      _webAudioPlayer?.setVolume(volume.value);
    } else {
      _nativePlayer?.setVolume(volume.value);
    }
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    if (kIsWeb) {
      _webAudioPlayer?.setMuted(isMuted.value);
    } else {
      _nativePlayer?.setVolume(isMuted.value ? 0.0 : volume.value);
    }
  }

  void syncPosition(Duration pos) {
    if (kIsWeb) {
      if (_webAudioPlayer == null) return;
      _webAudioPlayer!.seek(pos.inMilliseconds / 1000.0);
    } else {
      _nativePlayer?.seek(pos);
    }
  }

  Duration get currentPosition {
    if (kIsWeb) {
      final secs = _webAudioPlayer?.currentTime ?? position.value;
      return Duration(milliseconds: (secs * 1000).round());
    } else {
      return _nativePlayer?.position ?? Duration(milliseconds: (position.value * 1000).round());
    }
  }

  Duration deactivate() {
    final currentPos = currentPosition;
    _currentLoadedUrl = null;
    if (kIsWeb) {
      _webAudioPlayer?.pause();
      _webAudioPlayer?.stop();
      _stopPositionTracking();
    } else {
      _nativePlayer?.pause();
      _nativePlayer?.stop();
    }
    isActive.value = false;
    isPlaying.value = false;
    isAudioOnly.value = false;
    isBackgroundPlayback.value = false;
    return currentPos;
  }

  Duration deactivateBackgroundPlayback() => deactivate();

  // ── Position Tracking (Web) ────────────────────────────────

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_webAudioPlayer != null) {
        position.value = _webAudioPlayer!.currentTime;
        _updateMediaSessionPositionState();
      }
    });
  }

  void _stopPositionTracking() {
    _positionTimer?.cancel();
  }

  void _updateMediaSessionMetadata({
    required String title,
    required String artworkUrl,
  }) {
    if (!kIsWeb || _webAudioPlayer == null) return;
    _webAudioPlayer?.updateMediaSessionMetadata(
      title: title,
      artworkUrl: artworkUrl,
    );
  }

  void _updateMediaSessionPositionState() {
    if (!kIsWeb || _webAudioPlayer == null) return;
    _webAudioPlayer?.updateMediaSessionPositionState(
      duration: duration.value,
      position: position.value,
      playbackRate: 1.0,
    );
  }

  // ── Callbacks ──────────────────────────────────────────────

  VoidCallback? _onNextTrackCallback;
  VoidCallback? _onPreviousTrackCallback;
  VoidCallback? _onTrackEndedCallback;

  void setCallbacks({
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    VoidCallback? onEnded,
  }) {
    _onNextTrackCallback = onNext;
    _onPreviousTrackCallback = onPrevious;
    _onTrackEndedCallback = onEnded;
  }

  void _onNextTrack() => _onNextTrackCallback?.call();
  void _onPreviousTrack() => _onPreviousTrackCallback?.call();
  void _onTrackEnded() => _onTrackEndedCallback?.call();

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _nativePlayer?.dispose();
    if (kIsWeb) {
      _webAudioPlayer?.dispose();
    }
    super.onClose();
  }
}

typedef VoidCallback = void Function();
