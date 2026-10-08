import 'dart:async';
import 'dart:typed_data';

/// Abstract adapter for web audio player operations.
abstract class WebAudioPlayerAdapter {
  void init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onEnded,
    required void Function() onWaiting,
    required void Function() onCanPlay,
    required void Function(String err) onError,
    required void Function(double dur) onDurationChange,
  });
  void loadAndPlay(String url, {double volume = 1.0, bool loop = false});
  void play();
  void pause();
  void stop();
  void dispose();
  void seek(double seconds);
  void setVolume(double volume);
  void setMuted(bool muted);
  double get currentTime;
  double get duration;
  void setupMediaSession({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function(double seconds) onSeekRelative,
    required void Function() onPreviousTrack,
    required void Function() onNextTrack,
  });
  void updateMediaSessionMetadata({
    required String title,
    required String artworkUrl,
  });
  void updateMediaSessionPositionState({
    required double duration,
    required double position,
    required double playbackRate,
  });
}

/// Stub implementation of web platform utilities for Dart VM / mobile / desktop platforms.
class WebPlatformUtilsImpl {
  static String createBlobUrl(Uint8List bytes, [String mimeType = 'video/mp4']) => '';
  static void revokeBlobUrl(String url) {}

  static Future<Duration?> getVideoDurationFromBytes(
    Uint8List bytes, [
    String mimeType = 'video/mp4',
  ]) async => null;

  static bool isFullscreen() => false;
  static void requestFullscreen() {}
  static void exitFullscreen() {}
  static StreamSubscription? onFullscreenChange(void Function(bool isFullscreen) callback) => null;

  static void pushUrlHistory(String route) {}

  static double getInitialBandwidthHint({double defaultKbps = 5000}) => defaultKbps;

  static bool hasInjectedData() => false;
  static Map<String, dynamic>? getInjectedData() => null;
  static dynamic getInjectedField(String field) => null;
  static void clearInjectedData() {}
  static void removeInjectedData() {}

  static bool isPipSupported() => false;
  static bool isDocumentInPip() => false;
  static bool enterPip() => false;
  static bool exitPip() => false;

  static void ensureRecaptchaContainer() {}

  static WebAudioPlayerAdapter createAudioPlayer() => _StubAudioPlayer();
}

class _StubAudioPlayer implements WebAudioPlayerAdapter {
  @override
  void init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onEnded,
    required void Function() onWaiting,
    required void Function() onCanPlay,
    required void Function(String err) onError,
    required void Function(double dur) onDurationChange,
  }) {}

  @override
  void loadAndPlay(String url, {double volume = 1.0, bool loop = false}) {}

  @override
  void play() {}

  @override
  void pause() {}

  @override
  void stop() {}

  @override
  void seek(double seconds) {}

  @override
  void setVolume(double volume) {}

  @override
  void setMuted(bool muted) {}

  @override
  double get currentTime => 0.0;

  @override
  double get duration => 0.0;

  @override
  void dispose() {}

  @override
  void setupMediaSession({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function(double seconds) onSeekRelative,
    required void Function() onPreviousTrack,
    required void Function() onNextTrack,
  }) {}

  @override
  void updateMediaSessionMetadata({
    required String title,
    required String artworkUrl,
  }) {}

  @override
  void updateMediaSessionPositionState({
    required double duration,
    required double position,
    required double playbackRate,
  }) {}
}
