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
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js.dart' show JsObject, context;

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

  // ── Web Audio API objects ──────────────────────────────────
  dynamic _audioElement;
  html.MediaSession? _mediaSession;
  Timer? _positionTimer;

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

  void _initNativeAudio() {
    try {
      _nativePlayer = AudioPlayer();

      _playerStateSub = _nativePlayer!.playerStateStream.listen(
        (state) {
          isPlaying.value = state.playing;
          isBuffering.value = state.processingState == ProcessingState.buffering ||
              state.processingState == ProcessingState.loading;

          if (state.processingState == ProcessingState.completed) {
            isPlaying.value = false;
            _onTrackEnded();
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AudioOnlyService.playerStateStream',
        ),
      );

      _positionSub = _nativePlayer!.positionStream.listen(
        (pos) {
          position.value = pos.inMilliseconds / 1000.0;
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AudioOnlyService.positionStream',
        ),
      );

      _durationSub = _nativePlayer!.durationStream.listen(
        (dur) {
          if (dur != null) {
            duration.value = dur.inMilliseconds / 1000.0;
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AudioOnlyService.durationStream',
        ),
      );

      debugPrint('[AudioOnly] Native AudioPlayer initialized successfully');
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
      _audioElement = html.AudioElement()
        ..preload = 'auto'
        ..crossOrigin = 'anonymous';

      _audioElement!.onPlay.listen((_) => isPlaying.value = true);
      _audioElement!.onPause.listen((_) => isPlaying.value = false);
      _audioElement!.onEnded.listen((_) {
        isPlaying.value = false;
        _onTrackEnded();
      });
      _audioElement!.onWaiting.listen((_) => isBuffering.value = true);
      _audioElement!.onCanPlay.listen((_) => isBuffering.value = false);
      _audioElement!.onError.listen((e) {
        error.value = 'Unable to play audio. Please check your connection and try again.';
        ErrorHandler.log(
          'Audio element error: ${_audioElement?.error?.message ?? "Unknown"}',
          tag: 'AudioOnlyService.webAudio',
        );
      });
      _audioElement!.onDurationChange.listen((_) {
        duration.value = (_audioElement?.duration ?? 0).toDouble();
      });

      html.document.body?.append(_audioElement!);
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
    if (!kIsWeb) return;

    try {
      _mediaSession = html.window.navigator.mediaSession;
      if (_mediaSession == null) return;

      _registerMediaSessionAction('play', play);
      _registerMediaSessionAction('pause', pause);
      _registerMediaSessionAction('seekbackward', () => seekRelative(-10));
      _registerMediaSessionAction('seekforward', () => seekRelative(10));
      _registerMediaSessionAction('previoustrack', _onPreviousTrack);
      _registerMediaSessionAction('nexttrack', _onNextTrack);

      debugPrint('[AudioOnly] Media Session API registered');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.setupMediaSessionAPI',
      );
    }
  }

  void _registerMediaSessionAction(String action, Function handler) {
    try {
      final dynamic nav = context['navigator'];
      nav['mediaSession'].callMethod('setActionHandler', [
        action,
        handler,
      ]);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.registerMediaSessionAction.$action',
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
    await activateAudioOnly(
      videoUrl: mediaUrl,
      title: title,
      artworkUrl: artworkUrl,
      startPosition: startPosition,
    );
    if (autoPlay) {
      await play();
    }
  }

  Duration deactivateBackgroundPlayback() {
    isBackgroundPlayback.value = false;
    return deactivate();
  }

  Future<void> activateAudioOnly({
    required String videoUrl,
    required String title,
    required String artworkUrl,
    Duration? startPosition,
  }) async {
    isAudioOnly.value = true;
    isActive.value = true;
    currentTrackTitle.value = title;
    currentArtwork.value = artworkUrl;
    error.value = '';

    final audioUrl = _resolveAudioUrl(videoUrl);

    if (kIsWeb) {
      try {
        _audioElement?.src = audioUrl;
        _audioElement?.load();

        if (startPosition != null && startPosition > Duration.zero) {
          _audioElement?.currentTime = startPosition.inMilliseconds / 1000.0;
        }

        await _audioElement?.play();
        _startPositionTracking();
        _updateMediaSessionMetadata(title: title, artworkUrl: artworkUrl);

        debugPrint('[AudioOnly] Web Audio Playing: $audioUrl');
      } catch (e, stackTrace) {
        error.value =
            'Unable to start audio stream. Please check your connection and try again.';
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AudioOnlyService.playAudioUrlWeb',
        );
      }
    } else {
      try {
        if (_nativePlayer == null) {
          _initNativeAudio();
        }
        if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) {
          await _nativePlayer?.setUrl(audioUrl);
        } else {
          final filePath = audioUrl.startsWith('file://')
              ? audioUrl.replaceFirst('file://', '')
              : audioUrl;
          await _nativePlayer?.setFilePath(filePath);
        }
        if (startPosition != null && startPosition > Duration.zero) {
          await _nativePlayer?.seek(startPosition);
        }
        await _nativePlayer?.play();
        debugPrint('[AudioOnly] Native Audio Playing: $audioUrl');
      } catch (e, stackTrace) {
        error.value =
            'Unable to start audio stream. Please check your connection and try again.';
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AudioOnlyService.playAudioUrlNative',
        );
      }
    }
  }

  String _resolveAudioUrl(String videoUrl) {
    return videoUrl;
  }

  Future<void> play() async {
    try {
      if (kIsWeb) {
        await _audioElement?.play();
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
        _audioElement?.pause();
      } else {
        await _nativePlayer?.pause();
      }
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
      if (_audioElement == null) return;
      _audioElement!.currentTime = pos.inMilliseconds / 1000.0;
    } else {
      await _nativePlayer?.seek(pos);
    }
  }

  Future<void> seekRelative(int seconds) async {
    if (kIsWeb) {
      if (_audioElement == null) return;
      final newTime = (_audioElement!.currentTime + seconds).clamp(
        0.0,
        _audioElement!.duration,
      );
      _audioElement!.currentTime = newTime;
    } else {
      final cur = _nativePlayer?.position ?? Duration.zero;
      final target = cur + Duration(seconds: seconds);
      await _nativePlayer?.seek(target);
    }
  }

  void setVolume(double vol) {
    volume.value = vol.clamp(0.0, 1.0);
    if (kIsWeb) {
      if (_audioElement != null) {
        _audioElement!.volume = volume.value;
      }
    } else {
      _nativePlayer?.setVolume(volume.value);
    }
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    if (kIsWeb) {
      if (_audioElement != null) {
        _audioElement!.muted = isMuted.value;
      }
    } else {
      _nativePlayer?.setVolume(isMuted.value ? 0.0 : volume.value);
    }
  }

  void syncPosition(Duration pos) {
    if (kIsWeb) {
      if (_audioElement == null) return;
      _audioElement!.currentTime = pos.inMilliseconds / 1000.0;
    } else {
      _nativePlayer?.seek(pos);
    }
  }

  Duration get currentPosition {
    if (kIsWeb) {
      final secs = _audioElement?.currentTime ?? position.value;
      return Duration(milliseconds: (secs * 1000).round());
    } else {
      return _nativePlayer?.position ?? Duration(milliseconds: (position.value * 1000).round());
    }
  }

  Duration deactivate() {
    final currentPos = currentPosition;
    if (kIsWeb) {
      _audioElement?.pause();
      _stopPositionTracking();
    } else {
      _nativePlayer?.pause();
    }
    isAudioOnly.value = false;
    isActive.value = false;
    debugPrint(
      '[AudioOnly] Deactivated at $currentPos, returning to video mode',
    );
    return currentPos;
  }

  // ── Position Tracking (Web) ────────────────────────────────

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_audioElement != null) {
        position.value = _audioElement!.currentTime.toDouble();
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
    if (!kIsWeb || _mediaSession == null) return;
    try {
      final dynamic nav = context['navigator'];
      final dynamic mediaSession = nav?['mediaSession'];
      final dynamic mediaMetadataConstructor = context['MediaMetadata'];
      if (mediaSession != null && mediaMetadataConstructor != null) {
        mediaSession['metadata'] = JsObject(
          mediaMetadataConstructor,
          [
            JsObject.jsify({
              'title': title,
              'artist': 'Truthworld',
              'album': '',
              'artwork': [
                {'src': artworkUrl, 'sizes': '512x512', 'type': 'image/jpeg'},
              ],
            }),
          ],
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.updateMediaSessionMetadata',
      );
    }
  }

  void _updateMediaSessionPositionState() {
    if (!kIsWeb || _mediaSession == null) return;
    try {
      final dur = _audioElement?.duration ?? 0;
      final pos = _audioElement?.currentTime ?? 0;
      if (dur > 0) {
        final dynamic nav = context['navigator'];
        nav['mediaSession'].callMethod('setPositionState', [
          JsObject.jsify({
            'duration': dur,
            'playbackRate': _audioElement?.playbackRate ?? 1.0,
            'position': pos,
          }),
        ]);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AudioOnlyService.updateMediaSessionPositionState',
      );
    }
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
      _audioElement?.pause();
      _audioElement?.remove();
    }
    super.onClose();
  }
}

typedef VoidCallback = void Function();

