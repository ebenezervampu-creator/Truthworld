import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/firebase_options.dart';

class StorageUtils {
  static final Map<String, String> _fastUrlCache = {};

  /// Instantly generates a direct Firebase Storage HTTP download URL from a gs://, storage.googleapis.com,
  /// or standard path, completely bypassing slow network roundtrips.
  /// Results are cached in RAM for 0ms subsequent lookups.
  static String getFastDownloadUrl(String pathOrGsUrl) {
    if (pathOrGsUrl.isEmpty) return '';
    final cached = _fastUrlCache[pathOrGsUrl];
    if (cached != null) return cached;

    String result;
    if (pathOrGsUrl.startsWith('https://storage.googleapis.com/') ||
        pathOrGsUrl.startsWith('http://storage.googleapis.com/')) {
      // Convert raw GCS URL to Firebase Storage URL format
      final clean = pathOrGsUrl
          .replaceFirst('https://storage.googleapis.com/', '')
          .replaceFirst('http://storage.googleapis.com/', '');
      final slashIdx = clean.indexOf('/');
      final bucket = slashIdx != -1
          ? clean.substring(0, slashIdx)
          : DefaultFirebaseOptions.currentPlatform.storageBucket;
      final path = slashIdx != -1 ? clean.substring(slashIdx + 1) : clean;
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final encodedPath = Uri.encodeComponent(cleanPath);
      result =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
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
      final encodedPath = Uri.encodeComponent(cleanPath);
      result =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
    }

    _fastUrlCache[pathOrGsUrl] = result;
    return result;
  }

  /// Asynchronously resolves authenticated signed download URLs for private Firebase Storage files.
  static Future<String> resolveUrl(String pathOrUrl) async {
    if (pathOrUrl.isEmpty) return '';
    final fast = getFastDownloadUrl(pathOrUrl);
    if (fast.contains('token=')) return fast;

    if (pathOrUrl.startsWith('gs://') ||
        pathOrUrl.startsWith('https://storage.googleapis.com/') ||
        (pathOrUrl.contains('firebasestorage.googleapis.com') &&
            !pathOrUrl.contains('token='))) {
      try {
        final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
        final refUrl = pathOrUrl.startsWith('http')
            ? pathOrUrl
            : (pathOrUrl.startsWith('gs://')
                ? pathOrUrl
                : 'gs://$bucket/$pathOrUrl');
        final tokenUrl = await FirebaseStorage.instance
            .refFromURL(refUrl)
            .getDownloadURL()
            .timeout(const Duration(seconds: 3));
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
