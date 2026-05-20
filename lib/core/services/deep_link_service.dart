// ignore_for_file: avoid_print
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Centralized deep-link service for Truthworld.
///
/// Single source of truth for:
/// - Share URL generation (video, channel, playlist)
/// - Content loading from Firestore (with timeout + retry)
/// - Share sheet invocation
///
/// All loader screens and share buttons should use this service to ensure
/// consistent URL patterns and cost-effective Firestore reads.
class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  // ═══════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ═══════════════════════════════════════════════════════════════════

  static const String baseUrl = 'https://www.Truthworld.in';
  static const Duration _loadTimeout = Duration(seconds: 10);
  static const int _maxRetries = 2;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════
  // URL BUILDERS (single source of truth)
  // ═══════════════════════════════════════════════════════════════════

  /// Generates a shareable video URL.
  /// Pattern: https://www.Truthworld.in/watch/{videoId}
  static String videoUrl(String videoId) => '$baseUrl/watch/$videoId';

  /// Generates a shareable channel URL.
  /// Pattern: https://www.Truthworld.in/channel/{channelId}
  static String channelUrl(String channelId) => '$baseUrl/channel/$channelId';

  /// Generates a shareable playlist URL.
  /// Pattern: https://www.Truthworld.in/playlist/{playlistId}
  static String playlistUrl(String playlistId) =>
      '$baseUrl/playlist/$playlistId';

  // ═══════════════════════════════════════════════════════════════════
  // SHARE FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Share a video with title and URL.
  Future<void> shareVideo(String videoId, String videoTitle) async {
    try {
      final url = videoUrl(videoId);
      // ignore: deprecated_member_use
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out "$videoTitle" on Truthworld:\n$url',
          subject: videoTitle,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing video: $e');
    }
  }

  /// Share a channel with name and URL.
  Future<void> shareChannel(String channelId, {String? channelName}) async {
    try {
      final url = channelUrl(channelId);
      final text = channelName != null
          ? 'Check out "$channelName" on Truthworld:\n$url'
          : 'Check out this channel on Truthworld:\n$url';
      // ignore: deprecated_member_use
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: channelName ?? 'Truthworld Channel',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing channel: $e');
    }
  }

  /// Share a playlist with name and URL.
  Future<void> sharePlaylist(String playlistId, String playlistName) async {
    try {
      final url = playlistUrl(playlistId);
      // ignore: deprecated_member_use
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out "$playlistName" playlist on Truthworld:\n$url',
          subject: playlistName,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing playlist: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTENT LOADERS (with timeout + retry)
  // ═══════════════════════════════════════════════════════════════════

  /// Load a video by ID. Cost: 1 Firestore read.
  /// Returns null if not found or on error.
  Future<Video?> loadVideo(String videoId) async {
    return _withRetry<Video?>(() async {
      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .get()
          .timeout(_loadTimeout);

      if (!doc.exists) return null;
      return Video.fromDocumentSnapshot(doc);
    });
  }

  /// Load a channel by ID. Cost: 1 Firestore read.
  /// Also checks by customUrl if document ID doesn't match.
  Future<Channel?> loadChannel(String channelId) async {
    return _withRetry<Channel?>(() async {
      // Direct lookup by document ID (fastest, 1 read)
      final doc = await _firestore
          .collection('channels')
          .doc(channelId)
          .get()
          .timeout(_loadTimeout);

      if (doc.exists) return Channel.fromDocumentSnapshot(doc);

      // Fallback: search by customUrl (for vanity URLs)
      final querySnap = await _firestore
          .collection('channels')
          .where('customUrlLowercase', isEqualTo: channelId.toLowerCase())
          .limit(1)
          .get()
          .timeout(_loadTimeout);

      if (querySnap.docs.isNotEmpty) {
        return Channel.fromDocumentSnapshot(querySnap.docs.first);
      }

      return null;
    });
  }

  /// Load a playlist by ID. Cost: 1-2 Firestore reads.
  /// Checks public first, then user's private playlists.
  Future<PlaylistModel?> loadPlaylist(String playlistId) async {
    return _withRetry<PlaylistModel?>(() async {
      // 1) Check public playlists (1 read)
      final publicDoc = await _firestore
          .collection('public_playlists')
          .doc(playlistId)
          .get()
          .timeout(_loadTimeout);

      if (publicDoc.exists) {
        return PlaylistModel.fromDocumentSnapshot(publicDoc);
      }

      // 2) Check user's private playlists (1 read)
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final privateDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('playlists')
            .doc(playlistId)
            .get()
            .timeout(_loadTimeout);

        if (privateDoc.exists) {
          return PlaylistModel.fromDocumentSnapshot(privateDoc);
        }
      }

      return null;
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // RETRY HELPER
  // ═══════════════════════════════════════════════════════════════════

  /// Executes [action] with retry logic and timeout.
  /// Returns null on all failures after retries.
  Future<T?> _withRetry<T>(Future<T?> Function() action) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await action();
      } on TimeoutException {
        debugPrint('DeepLink: Timeout (attempt ${attempt + 1}/$_maxRetries)');
        if (attempt == _maxRetries) return null;
        // Exponential backoff: 500ms, 1000ms
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } on FirebaseException catch (e) {
        debugPrint('DeepLink: Firebase error: ${e.message}');
        if (attempt == _maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        debugPrint('DeepLink: Unexpected error: $e');
        return null;
      }
    }
    return null;
  }
}





