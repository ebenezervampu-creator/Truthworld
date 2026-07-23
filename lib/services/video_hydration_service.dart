import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:universal_html/js.dart' as js;

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
  /// 
  /// Returns true if:
  /// - Running on web
  /// - __VIDEO_DATA__ exists in window
  /// - Data is not undefined
  static bool hasInjectedData() {
    try {
      // Only available on web
      if (!kIsWeb) {
        return false;
      }

      final data = js.context['__VIDEO_DATA__'];
      final isUndefined = data == null || data == js.context['undefined'];

      if (!isUndefined) {
        debugPrint('✅ Injected data detected');
      }

      return !isUndefined;
    } catch (e) {
      debugPrint('⚠️ Error checking injected data: $e');
      return false;
    }
  }

  /// Get the injected video data as a Dart Map
  /// 
  /// Returns null if:
  /// - Not running on web
  /// - Data not found
  /// - Error reading from JS context
  /// 
  /// Otherwise returns map with keys:
  /// - id, title, description, thumbnail
  /// - duration, uploadDate
  /// - creatorId, creatorName
  /// - viewCount, rating, ratingCount
  /// - videoUrl, hlsUrl, dashUrl
  /// - slug
  static Map<String, dynamic>? getInjectedData() {
    try {
      if (!kIsWeb) {
        return null;
      }

      final dynamic jsData = js.context['__VIDEO_DATA__'];

      if (jsData == null || jsData == js.context['undefined']) {
        return null;
      }

      // Convert JavaScript object to Dart Map
      final data = <String, dynamic>{
        'id': jsData['id'] as String?,
        'title': jsData['title'] as String?,
        'description': jsData['description'] as String?,
        'thumbnail': jsData['thumbnail'] as String?,
        'duration': jsData['duration'] as int?,
        'uploadDate': jsData['uploadDate'] as String?,
        'creatorId': jsData['creatorId'] as String?,
        'creatorName': jsData['creatorName'] as String?,
        'channelId': jsData['channelId'] as String?,
        'category': jsData['category'] as String?,
        'tags': jsData['tags'] as List?,
        'viewCount': jsData['viewCount'] as int?,
        'rating': jsData['rating'] as double?,
        'ratingCount': jsData['ratingCount'] as int?,
        'videoUrl': jsData['videoUrl'] as String?,
        'hlsUrl': jsData['hlsUrl'] as String?,
        'dashUrl': jsData['dashUrl'] as String?,
        'slug': jsData['slug'] as String?,
      };

      debugPrint('✅ Retrieved injected data: ${data['title']}');
      return data;
    } catch (e) {
      debugPrint('❌ Error reading injected data: $e');
      return null;
    }
  }

  /// Get a specific field from injected data
  /// 
  /// Example: VideoHydrationService.getInjectedField('title')
  static dynamic getInjectedField(String field) {
    try {
      if (!kIsWeb) {
        return null;
      }

      final dynamic data = js.context['__VIDEO_DATA__'];
      if (data == null || data == js.context['undefined']) {
        return null;
      }

      return data[field];
    } catch (e) {
      debugPrint('❌ Error reading field "$field": $e');
      return null;
    }
  }

  /// Clean up injected data after it's been consumed
  /// 
  /// Safe to call multiple times - doesn't error if data doesn't exist
  static void clearInjectedData() {
    try {
      if (kIsWeb) {
        js.context['__VIDEO_DATA__'] = null;
        debugPrint('✅ Cleared injected data');
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing injected data: $e');
    }
  }

  /// Completely remove the __VIDEO_DATA__ from window
  static void removeInjectedData() {
    try {
      if (kIsWeb) {
        js.context.deleteProperty('__VIDEO_DATA__');
        debugPrint('✅ Removed __VIDEO_DATA__ from window');
      }
    } catch (e) {
      debugPrint('⚠️ Error removing injected data: $e');
    }
  }

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





