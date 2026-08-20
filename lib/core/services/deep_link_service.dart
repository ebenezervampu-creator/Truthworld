import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Centralized deep-link service for TruthWorld.
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

  static const String baseUrl = 'https://www.truthworld.in';
  static const Duration _loadTimeout = Duration(seconds: 10);
  static const int _maxRetries = 2;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════
  // URL BUILDERS (single source of truth)
  // ═══════════════════════════════════════════════════════════════════

  /// Generates a shareable video URL.
  /// Pattern: https://www.truthworld.in/watch/{videoId}
  static String videoUrl(String videoId) => '$baseUrl/watch/$videoId';

  /// Generates a shareable channel URL.
  /// Pattern: https://www.truthworld.in/channel/{channelId}
  static String channelUrl(String channelId) => '$baseUrl/channel/$channelId';

  /// Generates a shareable playlist URL.
  /// Pattern: https://www.truthworld.in/playlist/{playlistId}
  static String playlistUrl(String playlistId) =>
      '$baseUrl/playlist/$playlistId';

  /// Generates a shareable topic URL.
  /// Pattern: https://www.truthworld.in/T/{id_or_slug_or_handle}
  static String topicUrl(String slugOrHandle) {
    var clean = slugOrHandle.trim();
    if (clean.startsWith('T/')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('t/')) {
      clean = clean.substring(2);
    }
    return '$baseUrl/T/$clean';
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARE FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Share a video with title and URL.
  Future<void> shareVideo(
    String videoId,
    String videoTitle, {
    String? channelName,
  }) async {
    try {
      final url = videoUrl(videoId);
      final byChannel = (channelName != null &&
              channelName.isNotEmpty &&
              channelName != 'Channel' &&
              !videoTitle.toLowerCase().contains(channelName.toLowerCase()))
          ? ' by $channelName'
          : '';
      await SharePlus.instance.share(
        ShareParams(
          text: 'Watch "$videoTitle"$byChannel on TruthWorld:\n$url',
          subject: videoTitle,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing video: $e');
    }
  }

  /// Share a channel with name, handle, and URL.
  Future<void> shareChannel(
    String channelId, {
    String? channelName,
    String? handle,
  }) async {
    try {
      final url = channelUrl(channelId);
      final cleanHandle = (handle ?? '').replaceAll(RegExp('^@'), '').trim();
      final handleStr = cleanHandle.isNotEmpty ? ' (@$cleanHandle)' : '';
      final text = channelName != null
          ? 'Check out $channelName$handleStr on TruthWorld:\n$url'
          : 'Check out this channel on TruthWorld:\n$url';
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: channelName ?? 'TruthWorld Channel',
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
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out "$playlistName" playlist on TruthWorld:\n$url',
          subject: playlistName,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing playlist: $e');
    }
  }

  /// Share a topic with name and URL.
  Future<void> shareTopic(String slugOrHandle, String topicTitle) async {
    try {
      final url = topicUrl(slugOrHandle);
      final cleanTitle = topicTitle.replaceAll(RegExp('^[#Tt]/'), '').trim();
      await SharePlus.instance.share(
        ShareParams(
          text: 'Explore #$cleanTitle on TruthWorld:\n$url',
          subject: '#$cleanTitle',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing topic: $e');
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
          .collection(FirestoreCollections.videos)
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
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .get()
          .timeout(_loadTimeout);

      if (doc.exists) return Channel.fromDocumentSnapshot(doc);

      // Fallback: search by customUrl (for vanity URLs)
      final querySnap = await _firestore
          .collection(FirestoreCollections.channels)
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
      final userId = FirebaseAuth.instance.currentUser?.uid;

      final futures = <Future<DocumentSnapshot>>[
        _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .get()
            .timeout(_loadTimeout),
      ];

      if (userId != null) {
        futures.add(
          _firestore
              .collection(FirestoreCollections.users)
              .doc(userId)
              .collection(FirestoreCollections.playlists)
              .doc(playlistId)
              .get()
              .timeout(_loadTimeout),
        );
      }

      final docs = await Future.wait(futures);

      for (final doc in docs) {
        if (doc.exists) {
          return PlaylistModel.fromDocumentSnapshot(doc);
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
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
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
