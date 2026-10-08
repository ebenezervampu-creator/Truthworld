import 'package:flutter/foundation.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';

/// Service to handle video data injection from prerendered HTML pages.
///
/// How it works:
/// 1. Firebase Hosting serves prerendered HTML with injected data
/// 2. HTML contains: window.__VIDEO_DATA__ = {...}
/// 3. This service reads that data from JavaScript context
/// 4. Flutter app uses injected data for instant hydration (no loading)
///
/// Only active on web - returns null on mobile.
class VideoHydrationService {
  /// Check if video data was injected by the prerender system
  static bool hasInjectedData() => WebPlatformUtils.hasInjectedData();

  /// Get the injected video data as a Dart Map
  static Map<String, dynamic>? getInjectedData() =>
      WebPlatformUtils.getInjectedData();

  /// Get a specific field from injected data
  static dynamic getInjectedField(String field) =>
      WebPlatformUtils.getInjectedField(field);

  /// Clean up injected data after it's been consumed
  static void clearInjectedData() => WebPlatformUtils.clearInjectedData();

  /// Completely remove the __VIDEO_DATA__ from window
  static void removeInjectedData() => WebPlatformUtils.removeInjectedData();

  /// Debug: Print all injected data to console
  static void debugPrintInjectedData() {
    if (!kIsWeb) {
      debugPrint('⚠️ Not running on web - no injected data');
      return;
    }

    final data = getInjectedData();
    if (data != null) {
      debugPrint('=== INJECTED VIDEO DATA ===');
      data.forEach((key, value) {
        debugPrint('  $key: $value');
      });
      debugPrint('===========================');
    } else {
      debugPrint('❌ No injected data found');
    }
  }
}
