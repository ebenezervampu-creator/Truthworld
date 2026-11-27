import 'dart:async';
import 'dart:typed_data';

import 'package:truthworld/core/utils/web_platform_utils_stub.dart'
    if (dart.library.js_interop) 'package:truthworld/core/utils/web_platform_utils_web.dart';

export 'package:truthworld/core/utils/web_platform_utils_stub.dart'
    show WebAudioPlayerAdapter;

/// Universal cross-platform bridge for web-only DOM and JS interop capabilities.
/// Completely decoupled to ensure 100% compilation safety across native Dart VM,
/// unit tests, Android, iOS, Desktop, and Flutter Web.
class WebPlatformUtils {
  WebPlatformUtils._();

  /// Create a temporary object/blob URL from raw bytes on Web platforms.
  /// Returns empty string on native platforms.
  static String createBlobUrl(Uint8List bytes, [String mimeType = 'video/mp4']) =>
      WebPlatformUtilsImpl.createBlobUrl(bytes, mimeType);

  /// Revoke a previously created object/blob URL on Web platforms.
  static void revokeBlobUrl(String url) =>
      WebPlatformUtilsImpl.revokeBlobUrl(url);

  /// Extract video duration from in-memory bytes using browser DOM on Web platforms.
  /// Returns null on native platforms or on error.
  static Future<Duration?> getVideoDurationFromBytes(
    Uint8List bytes, [
    String mimeType = 'video/mp4',
  ]) =>
      WebPlatformUtilsImpl.getVideoDurationFromBytes(bytes, mimeType);

  /// Fetch a JS Blob from an existing browser `blob:` URL without copying into Dart heap.
  /// Returns null on native platforms or on error.
  static Future<dynamic> fetchBlobFromObjectUrl(String blobUrl) =>
      WebPlatformUtilsImpl.fetchBlobFromObjectUrl(blobUrl);

  /// Probe media duration directly from a `blob:` or HTTPS URL on Web without revoking it.
  /// Returns null on native platforms or on error.
  static Future<Duration?> getVideoDurationFromUrl(String url) =>
      WebPlatformUtilsImpl.getVideoDurationFromUrl(url);

  /// Check if document is currently in fullscreen on Web.
  static bool isFullscreen() => WebPlatformUtilsImpl.isFullscreen();

  /// Request browser fullscreen mode on Web.
  static void requestFullscreen() => WebPlatformUtilsImpl.requestFullscreen();

  /// Exit browser fullscreen mode on Web.
  static void exitFullscreen() => WebPlatformUtilsImpl.exitFullscreen();

  /// Listen to browser fullscreen change events on Web.
  static StreamSubscription? onFullscreenChange(
    void Function(bool isFullscreen) callback,
  ) =>
      WebPlatformUtilsImpl.onFullscreenChange(callback);

  /// Push an entry to browser history on Web.
  static void pushUrlHistory(String route) =>
      WebPlatformUtilsImpl.pushUrlHistory(route);

  /// Retrieve network downlink bandwidth estimate in kbps from browser NetworkInformation API.
  static double getInitialBandwidthHint({double defaultKbps = 5000}) =>
      WebPlatformUtilsImpl.getInitialBandwidthHint(defaultKbps: defaultKbps);

  /// Check if prerendered video data was injected into window.__VIDEO_DATA__ on Web.
  static bool hasInjectedData() => WebPlatformUtilsImpl.hasInjectedData();

  /// Get the prerendered video data map from window.__VIDEO_DATA__ on Web.
  static Map<String, dynamic>? getInjectedData() =>
      WebPlatformUtilsImpl.getInjectedData();

  /// Get a specific field from window.__VIDEO_DATA__ on Web.
  static dynamic getInjectedField(String field) =>
      WebPlatformUtilsImpl.getInjectedField(field);

  /// Nullify window.__VIDEO_DATA__ on Web.
  static void clearInjectedData() => WebPlatformUtilsImpl.clearInjectedData();

  /// Delete window.__VIDEO_DATA__ property on Web.
  static void removeInjectedData() => WebPlatformUtilsImpl.removeInjectedData();

  /// Check if Picture-in-Picture is supported by the browser on Web.
  static bool isPipSupported() => WebPlatformUtilsImpl.isPipSupported();

  /// Check if document is currently in PiP on Web.
  static bool isDocumentInPip() => WebPlatformUtilsImpl.isDocumentInPip();

  /// Enter Picture-in-Picture on the first video element on Web.
  static bool enterPip() => WebPlatformUtilsImpl.enterPip();

  /// Exit Picture-in-Picture on Web.
  static bool exitPip() => WebPlatformUtilsImpl.exitPip();

  /// Ensure reCAPTCHA container DOM element exists for Firebase Web phone auth.
  static void ensureRecaptchaContainer() =>
      WebPlatformUtilsImpl.ensureRecaptchaContainer();

  /// Factory creating the web audio player adapter on Web, or a stub on Native.
  static WebAudioPlayerAdapter createAudioPlayer() =>
      WebPlatformUtilsImpl.createAudioPlayer();
}
