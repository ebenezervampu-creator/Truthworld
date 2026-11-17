import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/logger_service.dart';
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

  /// Generates media playback headers with active Firebase App Check token and Origin protection.
  /// This ensures ExoPlayer, AVPlayer, and Web media loaders can stream from Cloud Storage / CDN
  /// with device attestation, blocking external scrapers, hotlinking, and unauthorized downloaders.
  static Future<Map<String, String>> getMediaHeaders({
    bool isHlsOrCmaf = false,
    String? userAuthToken,
    String? targetUrl,
  }) async {
    final isGoogleStorage = targetUrl != null &&
        (targetUrl.contains('firebasestorage.googleapis.com') ||
         targetUrl.contains('storage.googleapis.com'));

    final headers = <String, String>{
      'Origin': 'https://truthworld.in',
      'Referer': 'https://truthworld.in/',
    };
    if (isHlsOrCmaf) {
      headers['Accept'] =
          'application/vnd.apple.mpegurl, application/x-mpegURL, video/mp4;q=0.9, */*;q=0.8';
      headers['Cache-Control'] = 'no-cache';
    } else {
      headers['Accept'] = '*/*';
    }

    // Google Cloud / Firebase Storage REST endpoints do NOT accept Firebase Auth ID tokens in the
    // Authorization: Bearer header. GCS expects Google Cloud OAuth2 tokens (ya29....), so passing
    // a Firebase user JWT causes HTTP 401 or HTTP 500 errors.
    if (!isGoogleStorage) {
      var token = userAuthToken;
      if (token == null || token.isEmpty) {
        try {
          final currentAuthUser = FirebaseAuth.instance.currentUser;
          if (currentAuthUser != null) {
            token = await currentAuthUser.getIdToken();
          }
        } catch (_) {
          // Guest user or offline mode
        }
      }

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
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
  static Map<String, String> getSyncMediaHeaders({
    bool isHlsOrCmaf = false,
    String? userAuthToken,
    String? targetUrl,
  }) {
    final isGoogleStorage = targetUrl != null &&
        (targetUrl.contains('firebasestorage.googleapis.com') ||
         targetUrl.contains('storage.googleapis.com'));

    final headers = <String, String>{
      'Origin': 'https://truthworld.in',
      'Referer': 'https://truthworld.in/',
    };
    if (isHlsOrCmaf) {
      headers['Accept'] =
          'application/vnd.apple.mpegurl, application/x-mpegURL, video/mp4;q=0.9, */*;q=0.8';
      headers['Cache-Control'] = 'no-cache';
    } else {
      headers['Accept'] = '*/*';
    }
    if (!isGoogleStorage && userAuthToken != null && userAuthToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $userAuthToken';
    }
    if (_cachedAppCheckToken != null && _cachedAppCheckToken!.isNotEmpty) {
      headers['X-Firebase-AppCheck'] = _cachedAppCheckToken!;
    }
    return headers;
  }

  /// Identifies whether a storage path or URL points to a public, shareable visual asset
  /// (e.g. video thumbnails, channel avatars, banners, topic covers, community post images).
  /// Public assets are served openly via Google Cloud CDN (cdn.truthworld.in) without requiring
  /// auth tokens, allowing seamless OpenGraph previews on WhatsApp, X, and search engines.
  static bool isPublicAsset(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return false;
    final decoded = pathOrUrl.contains('%')
        ? (Uri.tryParse(pathOrUrl) != null ? Uri.decodeComponent(pathOrUrl) : pathOrUrl)
        : pathOrUrl;
    final lower = decoded.toLowerCase();
    return lower.contains('thumbnails/') ||
        lower.contains('thumbnail/') ||
        lower.contains('covers/') ||
        lower.contains('avatars/') ||
        lower.contains('banners/') ||
        lower.contains('channel_avatars/') ||
        lower.contains('channel_banners/') ||
        lower.contains('community_posts/') ||
        lower.contains('community_images/') ||
        lower.contains('topic_cards/') ||
        lower.contains('channel_images/') ||
        lower.contains('topics/') ||
        lower.contains('playlists/') ||
        lower.contains('chapters/') ||
        lower.contains('storyboards/') ||
        lower.contains('subtitles/') ||
        lower.contains('transcripts/');
  }

  /// Identifies whether a storage path or URL represents streaming video media
  /// (e.g. original videos, adaptive HLS/DASH resolutions, dubbed audio tracks).
  /// Video media is strictly gated ("Netflix-style") and requires valid TruthWorld
  /// session attestation, App Check verification, or signed session tokens.
  static bool isVideoAsset(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return false;
    final decoded = pathOrUrl.contains('%')
        ? (Uri.tryParse(pathOrUrl) != null ? Uri.decodeComponent(pathOrUrl) : pathOrUrl)
        : pathOrUrl;
    final lower = decoded.toLowerCase();
    return lower.contains('videos/') ||
        lower.contains('resolutions/') ||
        lower.contains('audiotracks/') ||
        lower.contains('audio/') ||
        lower.contains('dubbing_results/') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.m3u8') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.m4s') ||
        lower.contains('.m3u8?') ||
        lower.contains('.mp4?');
  }

  /// Extracts the clean storage object path relative to the bucket root.
  /// Handles gs://, storage.googleapis.com, firebasestorage, and raw relative paths.
  static String extractCleanPath(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return '';
    var clean = pathOrUrl.trim();
    final defaultBucket = DefaultFirebaseOptions.currentPlatform.storageBucket;

    // 1. Strip gs://
    if (clean.startsWith('gs://')) {
      clean = clean.replaceFirst('gs://$defaultBucket/', '').replaceFirst('gs://', '');
      return clean.startsWith('/') ? clean.substring(1) : clean;
    }

    // 2. Strip firebasestorage.googleapis.com or raw /o/ path prefixes (e.g. b/<bucket>/o/<path>)
    if (clean.contains('/o/')) {
      final oIndex = clean.indexOf('/o/');
      final rawPath = clean.substring(oIndex + 3);
      final noQuery = rawPath.split('?').first;
      final decoded = Uri.tryParse(noQuery) != null ? Uri.decodeComponent(noQuery) : noQuery;
      return decoded.startsWith('/') ? decoded.substring(1) : decoded;
    }

    // 3. Strip firebasestorage.googleapis.com without /o/ (rare edge case)
    if (clean.contains('firebasestorage.googleapis.com')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        final segments = uri.pathSegments;
        final oIndex = segments.indexOf('o');
        if (oIndex != -1 && oIndex + 1 < segments.length) {
          final rawEncoded = segments.sublist(oIndex + 1).join('/');
          final decoded = Uri.decodeComponent(rawEncoded);
          final noQuery = decoded.split('?').first;
          return noQuery.startsWith('/') ? noQuery.substring(1) : noQuery;
        }
      }
    }

    // 4. Strip storage.googleapis.com (direct GCS URLs)
    if (clean.contains('storage.googleapis.com')) {
      final uri = Uri.tryParse(clean);
      if (uri != null && uri.pathSegments.length >= 2) {
        final rawPath = uri.pathSegments.sublist(1).join('/');
        final noQuery = rawPath.split('?').first;
        return noQuery.startsWith('/') ? noQuery.substring(1) : noQuery;
      }
    }

    // 5. Strip cdn.truthworld.in
    if (clean.contains('cdn.truthworld.in')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        final rawPath = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        return rawPath.split('?').first;
      }
    }

    final noQuery = clean.split('?').first;
    return noQuery.startsWith('/') ? noQuery.substring(1) : noQuery;
  }

  /// Clears the in-memory fast download URL cache.
  static void clearFastUrlCache() {
    _fastUrlCache.clear();
  }

  /// Instantly generates a direct Google Cloud CDN / HTTP download URL from a gs://, storage.googleapis.com,
  /// or standard path, completely bypassing slow network roundtrips and high direct egress rates.
  ///
  /// - Public visual assets (thumbnails, avatars, banners) are routed through Google Cloud CDN
  ///   (`https://cdn.truthworld.in/<path>`) for open sharing, WhatsApp link previews, and global edge caching
  ///   when [AppConfig.enableCdnThumbnails] or [forceCdn] is enabled.
  /// - If an asset already contains an authentic download token (e.g. from Firebase Storage), that working token
  ///   is preserved unless CDN routing is explicitly forced, eliminating 403 Forbidden decoding errors.
  /// - Video streaming assets (MP4s, HLS playlists, audio tracks) maintain secure gating and require
  ///   active TruthWorld session / App Check attestation so they only play within TruthWorld ("Netflix-style").
  ///
  /// Results are cached in RAM for 0ms subsequent lookups.
  static String getFastDownloadUrl(
    String pathOrGsUrl, {
    bool? forceCdn,
  }) {
    if (pathOrGsUrl.isEmpty) return '';
    final cached = _fastUrlCache[pathOrGsUrl];
    if (cached != null) return cached;

    String result;
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    final cleanPath = extractCleanPath(pathOrGsUrl);
    final shouldCdn = forceCdn ?? AppConfig.enableCdnThumbnails;

    // ── Tier 1: Public Visual Media (Thumbnails, Avatars, Covers) ───────────
    // Open for universal sharing (WhatsApp, X, Facebook, Google Indexer) & 30-day Google Cloud CDN caching.
    if (isPublicAsset(pathOrGsUrl) || isPublicAsset(cleanPath)) {
      if (shouldCdn) {
        final cdnBase = AppConfig.cdnBaseUrl.isNotEmpty
            ? AppConfig.cdnBaseUrl
            : 'https://cdn.truthworld.in';
        result = '$cdnBase/$cleanPath';
        _fastUrlCache[pathOrGsUrl] = result;
        return result;
      }
      // If CDN is disabled or not provisioned, fallback cleanly to Firebase Storage URL
      if (pathOrGsUrl.contains('token=')) {
        result = pathOrGsUrl;
        _fastUrlCache[pathOrGsUrl] = result;
        return result;
      }
      final encodedPath = Uri.encodeComponent(cleanPath);
      result =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
      _fastUrlCache[pathOrGsUrl] = result;
      return result;
    }

    // ── Tier 2: Protected Video Media (Gated / In-App Playback Only) ────────
    // If it's already an authorized URL with download token or CDN signature, preserve it
    if (pathOrGsUrl.contains('token=') || pathOrGsUrl.contains('Signature=')) {
      result = pathOrGsUrl;
      _fastUrlCache[pathOrGsUrl] = result;
      return result;
    }

    if (pathOrGsUrl.startsWith('https://storage.googleapis.com/') ||
        pathOrGsUrl.startsWith('http://storage.googleapis.com/')) {
      final uri = Uri.tryParse(pathOrGsUrl);
      if (uri != null && uri.pathSegments.length >= 2) {
        final targetBucket = uri.pathSegments.first;
        final rawPath = uri.pathSegments.sublist(1).join('/');
        final encodedPath = Uri.encodeComponent(rawPath);
        result =
            'https://firebasestorage.googleapis.com/v0/b/$targetBucket/o/$encodedPath?alt=media';
      } else {
        result = pathOrGsUrl;
      }
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
      final encodedPath = Uri.encodeComponent(cleanPath);
      result =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
    }

    _fastUrlCache[pathOrGsUrl] = result;
    return result;
  }

  /// Resolves an authenticated, gated video streaming URL for in-app playback ("Netflix-style").
  ///
  /// Binds the active session token, App Check attestation, or CDN signed token to the video stream URL
  /// ensuring the media can only be streamed inside TruthWorld.
  static String resolveGatedVideoUrl(
    String pathOrUrl, {
    String? sessionToken,
    String? cdnSignature,
  }) {
    if (pathOrUrl.isEmpty) return '';
    final cleanPath = extractCleanPath(pathOrUrl);

    // If using Google Cloud CDN with signed token
    if (cdnSignature != null && cdnSignature.isNotEmpty) {
      final cdnBase = AppConfig.cdnBaseUrl.isNotEmpty
          ? AppConfig.cdnBaseUrl
          : 'https://cdn.truthworld.in';
      final separator = cdnSignature.startsWith('?') ? '' : '?';
      return '$cdnBase/$cleanPath$separator$cdnSignature';
    }

    // If session token provided, append as session parameter
    if (sessionToken != null && sessionToken.isNotEmpty) {
      final base = getFastDownloadUrl(pathOrUrl);
      final separator = base.contains('?') ? '&' : '?';
      return '$base${separator}tw_session=$sessionToken';
    }

    return getFastDownloadUrl(pathOrUrl);
  }

  /// Extracts a reliable Firebase Storage Reference from any path or URL format
  /// (gs://, storage.googleapis.com, firebasestorage.googleapis.com, or relative path).
  static Reference? getStorageRef(String urlOrPath) {
    final clean = urlOrPath.trim();
    if (clean.isEmpty) return null;
    final defaultBucket = DefaultFirebaseOptions.currentPlatform.storageBucket;

    if (clean.startsWith('gs://')) {
      try {
        return FirebaseStorage.instance.refFromURL(clean);
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'StorageUtils.getStorageRef.gs');
      }
      final stripped = clean
          .replaceFirst('gs://$defaultBucket/', '')
          .replaceFirst('gs://', '');
      final path = stripped.startsWith('/') ? stripped.substring(1) : stripped;
      return FirebaseStorage.instance.ref(path);
    }

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        final uri = Uri.parse(clean);
        // Case 1: https://storage.googleapis.com/<bucket>/<path>
        if (uri.host.contains('storage.googleapis.com')) {
          final segments = uri.pathSegments;
          if (segments.length >= 2) {
            final targetBucket = segments.first;
            final targetPath = segments.sublist(1).join('/');
            if (targetBucket.isNotEmpty && targetBucket != defaultBucket) {
              return FirebaseStorage.instanceFor(bucket: targetBucket)
                  .ref(targetPath);
            }
            return FirebaseStorage.instance.ref(targetPath);
          }
        }
        // Case 2: https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encodedPath>
        if (uri.host.contains('firebasestorage.googleapis.com') || uri.path.contains('/o/')) {
          final segments = uri.pathSegments;
          final bIndex = segments.indexOf('b');
          final oIndex = segments.indexOf('o');
          final targetBucket = (bIndex != -1 && bIndex + 1 < segments.length)
              ? segments[bIndex + 1]
              : defaultBucket;
          if (oIndex != -1 && oIndex + 1 < segments.length) {
            final encodedPath = segments.sublist(oIndex + 1).join('/');
            final decodedPath = Uri.decodeComponent(encodedPath);
            if (targetBucket != null && targetBucket.isNotEmpty && targetBucket != defaultBucket) {
              return FirebaseStorage.instanceFor(bucket: targetBucket)
                  .ref(decodedPath);
            }
            return FirebaseStorage.instance.ref(decodedPath);
          }
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'StorageUtils.getStorageRef.http',
        );
      }
      return null;
    }

    // Case 3: Raw path containing /o/ (e.g. b/<bucket>/o/<path> or /o/<path>)
    if (clean.contains('/o/')) {
      final cleanPath = extractCleanPath(clean);
      return FirebaseStorage.instance.ref(cleanPath);
    }

    // Relative storage path: e.g. "videos/.../original.mp4"
    final cleanPath = clean.startsWith('/') ? clean.substring(1) : clean;
    return FirebaseStorage.instance.ref(cleanPath);
  }

  /// Asynchronously resolves direct Google CDN or Firebase Storage HTTP download URLs.
  /// If a raw storage path, gs://, storage.googleapis.com URL, or firebasestorage URL without
  /// token is provided, securely resolves a signed token download URL.
  static Future<String> resolveUrl(String pathOrUrl) async {
    final clean = pathOrUrl.trim();
    if (clean.isEmpty) return '';

    final cached = _fastUrlCache[clean];
    if (cached != null && cached.isNotEmpty) {
      // Only return cached URL if it already has a download token, is CDN-routed, or is third-party.
      // Do NOT return cached untokenized Firebase Storage URLs that were generated by getFastDownloadUrl.
      if (cached.contains('token=') ||
          cached.contains('cdn.truthworld.in') ||
          cached.contains('Signature=') ||
          (!cached.contains('firebasestorage.googleapis.com') && !cached.contains('storage.googleapis.com'))) {
        return cached;
      }
    }

    // If it's already an authorized Firebase Storage URL with a download token, use it directly
    if (clean.contains('firebasestorage.googleapis.com') &&
        clean.contains('token=')) {
      final formatted = !clean.contains('alt=media')
          ? (clean.contains('?') ? '$clean&alt=media' : '$clean?alt=media')
          : clean;
      _fastUrlCache[clean] = formatted;
      return formatted;
    }

    // If it's an external third-party URL (neither GCS nor Firebase Storage), return as-is
    if ((clean.startsWith('http://') || clean.startsWith('https://')) &&
        !clean.contains('storage.googleapis.com') &&
        !clean.contains('firebasestorage.googleapis.com')) {
      _fastUrlCache[clean] = clean;
      return clean;
    }

    // Resolve token URL via FirebaseStorage Reference
    final ref = getStorageRef(clean);
    if (ref != null) {
      try {
        final tokenUrl =
            await ref.getDownloadURL().timeout(const Duration(seconds: 4));
        _fastUrlCache[clean] = tokenUrl;
        return tokenUrl;
      } catch (e, s) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('object-not-found') ||
            errStr.contains('not-found') ||
            errStr.contains('unauthorized') ||
            errStr.contains('permission-denied') ||
            errStr.contains('channel-error') ||
            errStr.contains('canceled') ||
            errStr.contains('retry-limit-exceeded') ||
            errStr.contains('retry') ||
            errStr.contains('timeoutexception') ||
            errStr.contains('timeout')) {
          logger.info(
            'StorageUtils.resolveUrl probe miss or timeout: $clean',
            tag: 'StorageUtils.resolveUrl',
          );
        } else {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'StorageUtils.resolveUrl.ref.getDownloadURL',
          );
        }
      }
    }

    return getFastDownloadUrl(clean);
  }

  /// Configures reasonable retry timeouts on Firebase Storage to prevent 10-minute retry loops
  static void configureRetryLimits() {
    if (!kIsWeb) {
      try {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          return;
        }
      } catch (_) {}
    }
    try {
      FirebaseStorage.instance.setMaxOperationRetryTime(const Duration(seconds: 8));
      FirebaseStorage.instance.setMaxDownloadRetryTime(const Duration(seconds: 15));
      FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 30));
    } catch (e) {
      logger.info('FirebaseStorage retry limits setup notice: $e', tag: 'StorageUtils');
    }
  }

  /// Safely downloads bytes from a Firebase Storage reference with an explicit timeout,
  /// preventing [firebase_storage/retry-limit-exceeded] stalls when probing missing objects.
  static Future<Uint8List?> getDataWithTimeout(
    Reference ref, {
    Duration timeout = const Duration(seconds: 4),
    int maxSize = 10 * 1024 * 1024,
  }) async {
    // 1. If public asset (subtitles, transcripts, avatars, thumbnails, etc.),
    // prefer direct fast HTTPS request via AppHttpClient.
    // This avoids triggering native Android Firebase Storage StreamDownloadTask
    // exceptions (FirebaseNoSignedInUserException & 404 stack traces in logcat)
    // when probing optional or absent candidate files.
    if (isPublicAsset(ref.fullPath)) {
      try {
        final fastUrl = getFastDownloadUrl(ref.fullPath, forceCdn: false);
        final uri = Uri.tryParse(fastUrl);
        if (uri != null) {
          final headers = <String, String>{
            'Connection': 'keep-alive',
            'Accept': '*/*',
          };
          final token = _cachedAppCheckToken ?? await getAppCheckToken();
          if (token != null && token.isNotEmpty) {
            headers['X-Firebase-AppCheck'] = token;
          }
          final res = await AppHttpClient.get(uri, headers: headers, timeout: timeout);
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            return res.bodyBytes;
          }
          if (res.statusCode == 404) {
            return null;
          }
        }
      } catch (_) {
        // Fallback to native SDK if HTTP network transport error occurs
      }
    }

    try {
      return await ref.getData(maxSize).timeout(timeout);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('object-not-found') ||
          errStr.contains('not-found') ||
          errStr.contains('unauthorized') ||
          errStr.contains('permission-denied') ||
          errStr.contains('retry-limit-exceeded') ||
          errStr.contains('channel-error') ||
          errStr.contains('timeoutexception') ||
          errStr.contains('timeout') ||
          errStr.contains('canceled')) {
        logger.info(
          'Storage ref getData probe miss or timeout: ${ref.fullPath}',
          tag: 'StorageUtils.getData',
        );
      } else {
        logger.warning(
          'Storage ref getData error: ${ref.fullPath} ($e)',
          tag: 'StorageUtils.getData',
        );
      }
      return null;
    }
  }
}
