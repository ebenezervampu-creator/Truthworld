import 'package:truthworld/firebase_options.dart';

class StorageUtils {
  static final Map<String, String> _fastUrlCache = {};

  /// Instantly generates a direct Firebase Storage HTTP download URL from a gs:// or standard path,
  /// completely bypassing the slow 500ms+ network handshake required by getDownloadURL().
  /// Results are cached in RAM for 0ms subsequent lookups.
  static String getFastDownloadUrl(String pathOrGsUrl) {
    if (pathOrGsUrl.isEmpty) return '';
    final cached = _fastUrlCache[pathOrGsUrl];
    if (cached != null) return cached;

    String result;
    if (pathOrGsUrl.startsWith('http://') ||
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
}
