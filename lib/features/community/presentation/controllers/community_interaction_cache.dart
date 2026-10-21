import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';

/// Centralized, high-performance in-memory session cache for user interactions with community posts.
/// Eliminates N x 4 Firestore queries on every community post card render.
class CommunityInteractionCache {
  static String? _cachedUid;
  static final Set<String> _hiddenPostIds = <String>{};
  static final Set<String> _mutedChannelIds = <String>{};
  static final Set<String> _reportedPostIds = <String>{};
  static final Set<String> _savedPostIds = <String>{};
  static DateTime? _lastFetchTime;
  static Future<void>? _activeFetchFuture;

  /// Ensures user interactions (hidden posts, muted channels, reported posts, saved posts)
  /// are cached in memory for sub-millisecond O(1) checks.
  static Future<void> ensureInitialized(String uid, {bool forceRefresh = false}) {
    if (_cachedUid != uid) {
      reset();
      _cachedUid = uid;
    }

    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < const Duration(minutes: 15)) {
      return Future.value();
    }

    if (_activeFetchFuture != null) {
      return _activeFetchFuture!;
    }

    _activeFetchFuture = _loadUserInteractions(uid).whenComplete(() {
      _activeFetchFuture = null;
    });

    return _activeFetchFuture!;
  }

  static Future<void> _loadUserInteractions(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection(FirestoreCollections.users).doc(uid);

      final results = await Future.wait([
        userRef.collection('hiddenCommunityPosts').limit(500).getCacheFirst(),
        userRef.collection('mutedCommunityChannels').limit(200).getCacheFirst(),
        userRef.collection('reportedCommunityPosts').limit(200).getCacheFirst(),
        userRef.collection('savedCommunityPosts').limit(500).getCacheFirst(),
      ]);

      _hiddenPostIds.clear();
      for (final doc in results[0].docs) {
        _hiddenPostIds.add(doc.id);
      }

      _mutedChannelIds.clear();
      for (final doc in results[1].docs) {
        _mutedChannelIds.add(doc.id);
      }

      _reportedPostIds.clear();
      for (final doc in results[2].docs) {
        _reportedPostIds.add(doc.id);
      }

      _savedPostIds.clear();
      for (final doc in results[3].docs) {
        _savedPostIds.add(doc.id);
      }

      _lastFetchTime = DateTime.now();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommunityInteractionCache._loadUserInteractions',
      );
    }
  }

  /// Checks if a specific post was marked hidden by the user in feeds.
  static bool isPostHidden(String postId) {
    return _hiddenPostIds.contains(postId);
  }

  /// Checks if a channel's community posts were muted by the user in feeds.
  static bool isChannelMuted(String channelId) {
    return _mutedChannelIds.contains(channelId);
  }

  /// Checks if a post has been reported by the user.
  static bool isReported(String postId) {
    return _reportedPostIds.contains(postId);
  }

  /// Checks if a post should be filtered from recommendation/discovery feeds.
  static bool isFeedHidden(String postId, String channelId) {
    return _hiddenPostIds.contains(postId) ||
        _mutedChannelIds.contains(channelId) ||
        _reportedPostIds.contains(postId);
  }

  /// Backward-compatible alias for isFeedHidden.
  static bool isHidden(String postId, String channelId) {
    return isFeedHidden(postId, channelId);
  }

  /// Checks if a post is saved by the user.
  static bool isSaved(String postId) {
    return _savedPostIds.contains(postId);
  }

  /// Optimistically marks a post as hidden.
  static void markHidden(String postId) {
    _hiddenPostIds.add(postId);
  }

  /// Optimistically marks a channel as muted.
  static void markChannelMuted(String channelId) {
    _mutedChannelIds.add(channelId);
  }

  /// Optimistically unmarks a post as hidden.
  static void unmarkHidden(String postId) {
    _hiddenPostIds.remove(postId);
  }

  /// Optimistically unmarks a channel as muted.
  static void unmarkChannelMuted(String channelId) {
    _mutedChannelIds.remove(channelId);
  }

  /// Optimistically marks a post as reported.
  static void markReported(String postId) {
    _reportedPostIds.add(postId);
  }

  /// Optimistically updates saved status of a post.
  static void setSaved(String postId, bool saved) {
    if (saved) {
      _savedPostIds.add(postId);
    } else {
      _savedPostIds.remove(postId);
    }
  }

  /// Clears in-memory cache upon user switch or logout.
  static void reset() {
    _cachedUid = null;
    _hiddenPostIds.clear();
    _mutedChannelIds.clear();
    _reportedPostIds.clear();
    _savedPostIds.clear();
    _lastFetchTime = null;
    _activeFetchFuture = null;
  }
}
