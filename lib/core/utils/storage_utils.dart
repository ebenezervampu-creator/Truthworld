import 'package:truthworld/firebase_options.dart';

class StorageUtils {
  /// Instantly generates a direct Firebase Storage HTTP download URL from a gs:// or standard path,
  /// completely bypassing the slow 500ms+ network handshake required by getDownloadURL().
  ///
  /// Only works for publicly readable paths.
  static String getFastDownloadUrl(String pathOrGsUrl) {
    if (pathOrGsUrl.startsWith('http://') ||
        pathOrGsUrl.startsWith('https://')) {
      // It's already an HTTP URL, return as-is.
      // Ensure we append alt=media if it's a firebasestorage URL missing it.
      if (pathOrGsUrl.contains('firebasestorage.googleapis.com') &&
          !pathOrGsUrl.contains('alt=media')) {
        return pathOrGsUrl.contains('?')
            ? '$pathOrGsUrl&alt=media'
            : '$pathOrGsUrl?alt=media';
      }
      return pathOrGsUrl;
    }

    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    final path = pathOrGsUrl.startsWith('gs://')
        ? pathOrGsUrl.replaceAll('gs://$bucket/', '').replaceAll('gs://', '')
        : pathOrGsUrl;

    // Some paths might start with a leading slash, which breaks the URL construction
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    final encodedPath = Uri.encodeComponent(cleanPath);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
  }
}
