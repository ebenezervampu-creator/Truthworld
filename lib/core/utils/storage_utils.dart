import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/firebase_options.dart';

class StorageUtils {
  static final Map<String, String> _fastUrlCache = {};
  static String? _cachedAppCheckToken;

  /// Update cached App Check token from listener or initialization
  static void updateAppCheckToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _cachedAppCheckToken = token;
    }
  }

  /// Get current in-memory App Check token if available
  static String? get currentAppCheckToken => _cachedAppCheckToken;

  /// Retrieves a valid App Check token (from in-memory cache or fast fallback fetch).
  static Future<String?> getAppCheckToken() async {
    try {
      var token = _cachedAppCheckToken;
      if (token == null || token.isEmpty) {
        token = await FirebaseAppCheck.instance
            .getToken()
            .timeout(const Duration(milliseconds: 1500));
        if (token != null && token.isNotEmpty) {
          _cachedAppCheckToken = token;
        }
      }
      return token;
    } catch (_) {
      return _cachedAppCheckToken;
    }
  }

  /// Generates media playback headers with active Firebase App Check token.
  /// This ensures ExoPlayer, AVPlayer, and Web media loaders can stream from Cloud Storage
  /// without triggering HTTP 401 Unauthorized errors when App Check is enforced.
  static Future<Map<String, String>> getMediaHeaders({
    bool isHlsOrCmaf = false,
  }) async {
    final headers = <String, String>{
      'Connection': 'keep-alive',
    };
    if (isHlsOrCmaf) {
      headers['Accept'] =
          'application/vnd.apple.mpegurl, application/x-mpegURL, video/mp4;q=0.9, */*;q=0.8';
      headers['Cache-Control'] = 'no-cache';
    } else {
      headers['Accept'] = '*/*';
    }

    try {
      final token = await getAppCheckToken();
      if (token != null && token.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = token;
      }
    } catch (_) {
      // Graceful fallback in test or offline modes
    }

    return headers;
  }

  /// Synchronously generates media playback headers using the in-memory cached AppCheck token.
  static Map<String, String> getSyncMediaHeaders({bool isHlsOrCmaf = false}) {
    final headers = <String, String>{
      'Connection': 'keep-alive',
    };
    if (isHlsOrCmaf) {
      headers['Accept'] =
          'application/vnd.apple.mpegurl, application/x-mpegURL, video/mp4;q=0.9, */*;q=0.8';
      headers['Cache-Control'] = 'no-cache';
    } else {
      headers['Accept'] = '*/*';
    }
    if (_cachedAppCheckToken != null && _cachedAppCheckToken!.isNotEmpty) {
      headers['X-Firebase-AppCheck'] = _cachedAppCheckToken!;
    }
    return headers;
  }

  /// Instantly generates a direct Google Cloud CDN / HTTP download URL from a gs://, storage.googleapis.com,
  /// or standard path, completely bypassing slow network roundtrips and high direct egress rates.
  /// Results are cached in RAM for 0ms subsequent lookups.
  static String getFastDownloadUrl(String pathOrGsUrl) {
    if (pathOrGsUrl.isEmpty) return '';
    final cached = _fastUrlCache[pathOrGsUrl];
    if (cached != null) return cached;

    String result;
    if (pathOrGsUrl.startsWith('https://storage.googleapis.com/') ||
        pathOrGsUrl.startsWith('http://storage.googleapis.com/')) {
      // Direct Google Cloud CDN / GCS URL - preserve direct edge caching
      result = pathOrGsUrl;
    } else if (pathOrGsUrl.startsWith('http://') ||
        pathOrGsUrl.startsWith('https://')) {
      if (pathOrGsUrl.contains('firebasestorage.googleapis.com') &&
          !pathOrGsUrl.contains('alt=media')) {
        result = pathOrGsUrl.contains('?')
            ? '$pathOrGsUrl&alt=media'
            : '$pathOrGsUrl?alt=media';
      } else {
        result = pathOrGsUrl;
      }
    } else {
      final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
      final path = pathOrGsUrl.startsWith('gs://')
          ? pathOrGsUrl.replaceAll('gs://$bucket/', '').replaceAll('gs://', '')
          : pathOrGsUrl;

      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      // Route via Google Cloud CDN origin for high-speed edge caching and low egress billing ($0.02-$0.08/GB instead of $0.12+/GB)
      result = '${AppConfig.cdnBaseUrl}/$bucket/$cleanPath';
    }

    _fastUrlCache[pathOrGsUrl] = result;
    return result;
  }

  /// Asynchronously resolves direct Google CDN or Firebase Storage HTTP download URLs.
  /// Because TruthWorld uses Google CDN for media and video delivery, URLs are resolved
  /// instantly in 0ms without blocking on slow metadata roundtrips.
  /// If a raw storage path or gs:// URL is provided, securely resolves a signed token download URL.
  static Future<String> resolveUrl(String pathOrUrl) async {
    if (pathOrUrl.isEmpty) return '';

    // If it's already an HTTP URL, return fast URL with alt=media handling
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return getFastDownloadUrl(pathOrUrl);
    }

    // For storage paths or gs:// URLs, generate token URL via FirebaseStorage
    try {
      final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
      final cleanPath = pathOrUrl
          .replaceAll('gs://$bucket/', '')
          .replaceAll('gs://', '');
      final formattedPath =
          cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;
      final tokenUrl = await FirebaseStorage.instance
          .ref(formattedPath)
          .getDownloadURL()
          .timeout(const Duration(seconds: 3));
      _fastUrlCache[pathOrUrl] = tokenUrl;
      return tokenUrl;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'StorageUtils.resolveUrl.tokenFallback',
      );
      return getFastDownloadUrl(pathOrUrl);
    }
  }
}
