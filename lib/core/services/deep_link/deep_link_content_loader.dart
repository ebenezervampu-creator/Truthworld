import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link/deep_link_cache_manager.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Mixin providing asynchronous Firestore content hydration with caching, timeouts, and retry logic.
mixin DeepLinkContentLoader on DeepLinkCacheManager {
  static const Duration _loadTimeout = Duration(seconds: 10);
  static const int _maxRetries = 2;

  FirebaseFirestore? firestoreOverride;
  FirebaseFirestore get firestore =>
      firestoreOverride ?? FirebaseFirestore.instance;

  /// Load a video by ID. Checks in-memory cache first, then Firestore.
  /// Returns null if not found or on error.
  Future<Video?> loadVideo(String videoId) async {
    final cached = getVideoFromCache(videoId);
    if (cached != null) return cached;

    return _withRetry<Video?>(() async {
      final doc = await firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .getCacheFirst()
          .timeout(_loadTimeout);

      if (!doc.exists) return null;
      final video = Video.fromDocumentSnapshot(doc);
      cacheVideo(video);
      return video;
    });
  }

  /// Load a channel by ID or handle. Checks in-memory cache first, then Firestore.
  Future<Channel?> loadChannel(String channelIdOrHandle) async {
    final cached = getChannelFromCache(channelIdOrHandle);
    if (cached != null) return cached;

    return _withRetry<Channel?>(() async {
      var clean = channelIdOrHandle.trim();
      if (clean.startsWith('@')) {
        clean = clean.substring(1);
      }

      // Direct lookup by document ID (fastest, 1 read)
      final doc = await firestore
          .collection(FirestoreCollections.channels)
          .doc(channelIdOrHandle)
          .getCacheFirst()
          .timeout(_loadTimeout);

      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        cacheChannel(channel);
        return channel;
      }

      // Fallback 1: search by handleLowercase
      final queryByHandle = await firestore
          .collection(FirestoreCollections.channels)
          .where('handleLowercase', isEqualTo: clean.toLowerCase())
          .limit(1)
          .getCacheFirst()
          .timeout(_loadTimeout);

      if (queryByHandle.docs.isNotEmpty) {
        final channel = Channel.fromDocumentSnapshot(queryByHandle.docs.first);
        cacheChannel(channel);
        return channel;
      }

      // Fallback 2: search by customUrl
      final querySnap = await firestore
          .collection(FirestoreCollections.channels)
          .where('customUrlLowercase', isEqualTo: clean.toLowerCase())
          .limit(1)
          .getCacheFirst()
          .timeout(_loadTimeout);

      if (querySnap.docs.isNotEmpty) {
        final channel = Channel.fromDocumentSnapshot(querySnap.docs.first);
        cacheChannel(channel);
        return channel;
      }

      return null;
    });
  }

  /// Load a playlist by ID. Checks in-memory cache first, then Firestore.
  Future<PlaylistModel?> loadPlaylist(String playlistId) async {
    final cached = getPlaylistFromCache(playlistId);
    if (cached != null) return cached;

    if (playlistId == 'watchlater' || playlistId == 'watch_later') {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId.isEmpty) return null;

      return _withRetry<PlaylistModel?>(() async {
        final snap = await firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection('watch_later')
            .getCacheFirst()
            .timeout(_loadTimeout);

        final videoIds = snap.docs.map((d) => d.id).toList();
        var thumb = '';
        if (videoIds.isNotEmpty) {
          try {
            final firstVid = await firestore
                .collection(FirestoreCollections.videos)
                .doc(videoIds.first)
                .getCacheFirst()
                .timeout(_loadTimeout);
            if (firstVid.exists) {
              thumb = firstVid.data()?['thumbnailUrl'] ?? '';
            }
          } catch (_) {}
        }

        final wl = PlaylistModel(
          id: 'watchlater',
          playlistName: 'Watch Later',
          videoIds: videoIds,
          videoCount: videoIds.length,
          thumbnailUrl: thumb,
          isPublic: false,
          ownerId: userId,
          channelId: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        cachePlaylist(wl);
        return wl;
      });
    }

    return _withRetry<PlaylistModel?>(() async {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      final futures = <Future<DocumentSnapshot>>[
        firestore
            .collection('public_playlists')
            .doc(playlistId)
            .getCacheFirst()
            .timeout(_loadTimeout),
      ];

      if (userId != null) {
        futures.add(
          firestore
              .collection(FirestoreCollections.users)
              .doc(userId)
              .collection(FirestoreCollections.playlists)
              .doc(playlistId)
              .getCacheFirst()
              .timeout(_loadTimeout),
        );
      }

      final docs = await Future.wait(futures);

      for (final doc in docs) {
        if (doc.exists) {
          final playlist = PlaylistModel.fromDocumentSnapshot(doc);
          cachePlaylist(playlist);
          return playlist;
        }
      }

      return null;
    });
  }

  /// Executes [action] with retry logic and timeout.
  /// Returns null on all failures after retries.
  Future<T?> _withRetry<T>(Future<T?> Function() action) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await action();
      } on TimeoutException {
        debugPrint('DeepLink: Timeout (attempt ${attempt + 1}/$_maxRetries)');
        if (attempt == _maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } on FirebaseException catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DeepLinkService._withRetry.firebase',
        );
        if (attempt == _maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DeepLinkService._withRetry.unexpected',
        );
        return null;
      }
    }
    return null;
  }
}
