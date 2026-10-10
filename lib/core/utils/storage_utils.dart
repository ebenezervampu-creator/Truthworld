import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/firebase_options.dart';

class StorageUtils {
  static final Map<String, String> _fastUrlCache = {};

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
  static Future<String> resolveUrl(String pathOrUrl) async {
    if (pathOrUrl.isEmpty) return '';
    final fast = getFastDownloadUrl(pathOrUrl);
    if (fast.isNotEmpty &&
        (fast.startsWith('http://') || fast.startsWith('https://'))) {
      return fast;
    }

    if (pathOrUrl.startsWith('gs://')) {
      try {
        final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
        final refUrl = pathOrUrl.startsWith('gs://')
            ? pathOrUrl
            : 'gs://$bucket/$pathOrUrl';
        final tokenUrl = await FirebaseStorage.instance
            .refFromURL(refUrl)
            .getDownloadURL()
            .timeout(const Duration(seconds: 1));
        _fastUrlCache[pathOrUrl] = tokenUrl;
        return tokenUrl;
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'StorageUtils.resolvePlaybackUrl',
        );
        return fast;
      }
    }
    return fast;
  }
}
