/// Pure utility to canonicalize and compare Google Cloud Storage and Firebase Storage object references.
/// Handles:
/// - `firebasestorage.googleapis.com/v0/b/{bucket}/o/{urlEncodedPath}`
/// - `storage.googleapis.com/{bucket}/{path}`
/// - `{bucket}.storage.googleapis.com/{path}` (virtual-hosted form)
/// - `gs://{bucket}/{path}`
/// Ignoring query parameters, download tokens, and alternate URL formats.
/// Never throws; returns null on decode error or invalid format.
class StorageCanonicalizer {
  StorageCanonicalizer._();

  /// Returns canonical `{bucket}/{decodedPath}` or host/path fallback.
  /// Returns null if [rawUrl] is null, blank, or on a decode error / invalid format.
  /// Never throws.
  static String? canonicalStorageObject(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final clean = rawUrl.trim();

    try {
      // 1. gs://{bucket}/{path}
      if (clean.startsWith('gs://')) {
        final withoutScheme = clean.substring('gs://'.length);
        final slashIdx = withoutScheme.indexOf('/');
        if (slashIdx != -1) {
          final bucket = withoutScheme.substring(0, slashIdx);
          final rawPath = withoutScheme.substring(slashIdx + 1);
          final decodedPath = Uri.decodeComponent(rawPath).replaceAll(RegExp('^/+'), '');
          return decodedPath.isEmpty ? bucket : '$bucket/$decodedPath';
        }
        return withoutScheme;
      }

      final uri = Uri.parse(clean);
      final host = uri.host.toLowerCase();

      // 2. firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}
      if (host.contains('firebasestorage.googleapis.com')) {
        final segs = uri.pathSegments;
        final bIdx = segs.indexOf('b');
        final oIdx = segs.indexOf('o');
        if (bIdx != -1 && bIdx + 1 < segs.length && oIdx != -1 && oIdx + 1 < segs.length) {
          final bucket = segs[bIdx + 1];
          final rawPath = segs.sublist(oIdx + 1).join('/');
          final decodedPath = Uri.decodeComponent(rawPath).replaceAll(RegExp('^/+'), '');
          return decodedPath.isEmpty ? bucket : '$bucket/$decodedPath';
        }
      }

      // 3. storage.googleapis.com/{bucket}/{path} (path-style)
      if (host == 'storage.googleapis.com') {
        final segs = uri.pathSegments;
        if (segs.isNotEmpty) {
          final bucket = segs[0];
          final rawPath = segs.sublist(1).join('/');
          final decodedPath = Uri.decodeComponent(rawPath).replaceAll(RegExp('^/+'), '');
          return decodedPath.isEmpty ? bucket : '$bucket/$decodedPath';
        }
      }

      // 4. <bucket>.storage.googleapis.com/{path} (virtual-hosted style)
      if (host.endsWith('.storage.googleapis.com')) {
        final bucket = host.substring(0, host.length - '.storage.googleapis.com'.length);
        if (bucket.isNotEmpty) {
          final rawPath = uri.pathSegments.join('/');
          final decodedPath = Uri.decodeComponent(rawPath).replaceAll(RegExp('^/+'), '');
          return decodedPath.isEmpty ? bucket : '$bucket/$decodedPath';
        }
      }

      // 5. Default fallback: host + decoded path (ignoring query params, tokens, fragments)
      final rawPath = uri.pathSegments.join('/');
      final decodedPath = Uri.decodeComponent(rawPath).replaceAll(RegExp('^/+'), '');
      return decodedPath.isEmpty ? host : '$host/$decodedPath';
    } catch (_) {
      return null;
    }
  }

  /// Returns true if [urlA] and [urlB] resolve to the exact same storage object.
  static bool isSameStorageObject(String? urlA, String? urlB) {
    if (urlA == null || urlB == null) return false;
    final canonA = canonicalStorageObject(urlA);
    final canonB = canonicalStorageObject(urlB);
    if (canonA == null || canonB == null) return false;
    return canonA == canonB;
  }
}
