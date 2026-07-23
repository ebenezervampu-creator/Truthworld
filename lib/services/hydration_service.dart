import 'package:flutter/foundation.dart';
import 'package:universal_html/js.dart' as js;

/// Service to handle zero-latency data injection from prerendered HTML pages.
///
/// How it works:
/// 1. Firebase Hosting serves prerendered HTML via the seoServer function.
/// 2. HTML contains injected global variables: `window.__VIDEO_DATA__ = {...}`
/// 3. This service reads that data from the JavaScript context instantly.
/// 4. Flutter app bypasses Firestore reads and renders immediately.
///
/// Only active on web - returns null on mobile.
class HydrationService {
  static bool _hasData(String key) {
    if (!kIsWeb) return false;
    try {
      final dynamic jsContext = js.context;
      final data = jsContext[key];
      return data != null && data != jsContext['undefined'];
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic>? _getData(String key) {
    if (!kIsWeb) return null;
    try {
      final dynamic jsContext = js.context;
      final dynamic jsData = jsContext[key];
      if (jsData == null || jsData == jsContext['undefined']) {
        return null;
      }

      // Convert JavaScript object to Dart Map recursively or simply cast
      // The js package handles simple JS interop map casting well enough.
      final dartMap = <String, dynamic>{};
      final keys =
          (jsContext['Object'] as dynamic).callMethod('keys', [jsData]) as List;
      for (final k in keys) {
        dartMap[k as String] = jsData[k];
      }

      // Clear data to prevent reuse on navigation
      jsContext[key] = jsContext['undefined'];

      return dartMap;
    } catch (e) {
      debugPrint('❌ Error reading injected $key: $e');
      return null;
    }
  }

  // ===========================================================================
  // VIDEO HYDRATION
  // ===========================================================================
  static bool hasVideoData() => _hasData('__VIDEO_DATA__');

  static Map<String, dynamic>? getVideoData() {
    return _getData('__VIDEO_DATA__');
  }

  // ===========================================================================
  // CHANNEL HYDRATION
  // ===========================================================================
  static bool hasChannelData() => _hasData('__CHANNEL_DATA__');

  static Map<String, dynamic>? getChannelData() {
    return _getData('__CHANNEL_DATA__');
  }

  // ===========================================================================
  // TOPIC HYDRATION
  // ===========================================================================
  static bool hasTopicData() => _hasData('__TOPIC_DATA__');

  static Map<String, dynamic>? getTopicData() {
    return _getData('__TOPIC_DATA__');
  }

  // ===========================================================================
  // PLAYLIST HYDRATION
  // ===========================================================================
  static bool hasPlaylistData() => _hasData('__PLAYLIST_DATA__');

  static Map<String, dynamic>? getPlaylistData() {
    return _getData('__PLAYLIST_DATA__');
  }
}
