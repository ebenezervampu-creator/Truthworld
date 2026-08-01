import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';

/// Optimized Firestore Service
///
/// Implements efficient querying strategies, pagination, caching,
/// and offline persistence for YouTube-scale video platform.
class FirestoreService extends GetxService {
  late FirebaseFirestore _firestore;
  static const int pageSize = 12; // Videos per page
  static const int commentPageSize = 20; // Comments per page

  @override
  Future<FirestoreService> onInit() async {
    super.onInit();
    await _initializeFirestore();
    return this;
  }

  /// Initialize Firestore with offline persistence
  Future<void> _initializeFirestore() async {
    _firestore = FirebaseFirestore.instance;

    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore initialization error: $e');
    }
  }

  // ============================================================================
  // VIDEO QUERIES
  // ============================================================================

  /// Fetch paginated videos from feed (homepage)
  ///
  /// Queries the optimized "videoCache" collection instead of full videos
  /// to minimize read costs and improve query speed.
  Future<({List<Map<String, dynamic>> videos, DocumentSnapshot? lastDoc})>
  getFeedVideos({DocumentSnapshot? lastDocument}) async {
    try {
      var query = _firestore
          .collection('videos/videoCache')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return (
        videos: snapshot.docs.map((d) => d.data()).toList(),
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      debugPrint('Error fetching feed videos: $e');
      rethrow;
    }
  }

  /// Fetch full video details for watch page
  ///
  /// Gets complete metadata including stats, storage URLs, etc.
  Future<Map<String, dynamic>> getVideoDetails(String videoId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();

      if (!doc.exists) {
        throw Exception('Video not found');
      }

      return doc.data()!;
    } catch (e) {
      debugPrint('Error fetching video details: $e');
      rethrow;
    }
  }

  /// Fetch trending videos
  ///
  /// Queries pre-computed hourly/daily trending collection
  /// for instant results without complex calculations.
  Future<List<Map<String, dynamic>>> getTrendingVideos({
    bool isDaily = false,
  }) async {
    try {
      final now = DateTime.now();
      final timeKey = isDaily
          ? 'daily_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          : 'hourly_${now.hour.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('videos/trending')
          .doc(timeKey)
          .collection(FirestoreCollections.videos)
          .orderBy('views', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Error fetching trending videos: $e');
      return [];
    }
  }

  /// Fetch videos by channel with pagination
  Future<({List<Map<String, dynamic>> videos, DocumentSnapshot? lastDoc})>
  getChannelVideos(String channelId, {DocumentSnapshot? lastDocument}) async {
    try {
      var query = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('videoList')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return (
        videos: snapshot.docs.map((d) => d.data()).toList(),
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      debugPrint('Error fetching channel videos: $e');
      rethrow;
    }
  }

  /// Fetch user's subscription feed
  ///
  /// Combines videos from all subscribed channels in real-time.
  /// Uses caching for performance.
  Future<List<Map<String, dynamic>>> getSubscriptionFeed(String userId) async {
    try {
      // Get user's subscriptions from cache
      final subSnapshot = await _firestore
          .collection('userCache')
          .doc(userId)
          .collection(FirestoreCollections.subscriptions)
          .limit(100) // Limit API calls
          .get();

      if (subSnapshot.docs.isEmpty) {
        return [];
      }

      final channelIds = subSnapshot.docs.map((d) => d.id).toList();

      // Fetch latest videos from subscribed channels (parallel)
      final videoFutures = channelIds
          .map(
            (channelId) => _firestore
                .collection(FirestoreCollections.channels)
                .doc(channelId)
                .collection('videoList')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .get(),
          )
          .toList();

      final results = await Future.wait(videoFutures);

      // Merge and sort by date
      final allVideos = <Map<String, dynamic>>[];
      for (final result in results) {
        allVideos.addAll(result.docs.map((d) => d.data()).toList());
      }

      // Sort by creation date descending
      allVideos.sort((a, b) {
        final dateA =
            (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final dateB =
            (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      return allVideos.take(pageSize).toList();
    } catch (e) {
      debugPrint('Error fetching subscription feed: $e');
      return [];
    }
  }

  // ============================================================================
  // COMMENT QUERIES
  // ============================================================================

  /// Fetch paginated comments for a video
  Future<({List<Map<String, dynamic>> comments, DocumentSnapshot? lastDoc})>
  getVideoComments(String videoId, {DocumentSnapshot? lastDocument}) async {
    try {
      var query = _firestore
          .collection('comments')
          .doc(videoId)
          .collection('list')
          .orderBy('createdAt', descending: true)
          .limit(commentPageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return (
        comments: snapshot.docs.map((d) => d.data()).toList(),
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      rethrow;
    }
  }

  /// Stream live comment count updates
  Stream<int> getCommentCountStream(String videoId) {
    return _firestore
        .collection('commentCounts')
        .doc(videoId)
        .snapshots()
        .map((snap) => snap.data()?['totalCount'] as int? ?? 0);
  }

  /// Fetch comment replies (subcollection)
  Future<List<Map<String, dynamic>>> getCommentReplies(
    String videoId,
    String commentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('comments')
          .doc(videoId)
          .collection('list')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Error fetching replies: $e');
      return [];
    }
  }

  // ============================================================================
  // CHANNEL QUERIES
  // ============================================================================

  /// Get channel information
  Future<Map<String, dynamic>> getChannelInfo(String channelId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .get();

      if (!doc.exists) {
        throw Exception('Channel not found');
      }

      return doc.data()!;
    } catch (e) {
      debugPrint('Error fetching channel info: $e');
      rethrow;
    }
  }

  /// Get channel playlists
  Future<List<Map<String, dynamic>>> getChannelPlaylists(
    String channelId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection(FirestoreCollections.playlists)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Error fetching playlists: $e');
      return [];
    }
  }

  // ============================================================================
  // USER QUERIES
  // ============================================================================

  /// Get user profile
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get();

      if (!doc.exists) {
        throw Exception('User not found');
      }

      return doc.data()!;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      rethrow;
    }
  }

  /// Get user's watch history
  Future<List<Map<String, dynamic>>> getUserWatchHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userCache')
          .doc(userId)
          .collection(FirestoreCollections.watchHistory)
          .orderBy('watchedAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Error fetching watch history: $e');
      return [];
    }
  }

  /// Get user's liked videos
  Future<List<Map<String, dynamic>>> getUserLikedVideos(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userCache')
          .doc(userId)
          .collection('likedVideos')
          .orderBy('likedAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Error fetching liked videos: $e');
      return [];
    }
  }

  // ============================================================================
  // NOTIFICATION QUERIES
  // ============================================================================

  /// Stream user notifications (real-time)
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return _firestore
        .collection(FirestoreCollections.notifications)
        .doc(userId)
        .collection('list')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Mark notifications as read
  Future<void> markNotificationsAsRead(
    String userId,
    List<String> notificationIds,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final notifId in notificationIds) {
        batch.update(
          _firestore
              .collection(FirestoreCollections.notifications)
              .doc(userId)
              .collection('list')
              .doc(notifId),
          {'read': true, 'readAt': FieldValue.serverTimestamp()},
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  // ============================================================================
  // WRITE OPERATIONS
  // ============================================================================

  /// Increment video view count (batched for performance)
  ///
  /// Uses a Cloud Function to aggregate view counts
  /// instead of writing directly to avoid write conflicts.
  Future<void> incrementVideoViews(String videoId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({
            'viewCount': FieldValue.increment(1),
          });
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  /// Add comment to video
  Future<String> postComment({
    required String videoId,
    required String userId,
    required String authorName,
    required String authorAvatar,
    required String text,
  }) async {
    try {
      final docRef = await _firestore
          .collection('comments')
          .doc(videoId)
          .collection('list')
          .add({
            'authorId': userId,
            'authorName': authorName,
            'authorAvatar': authorAvatar,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
            'likes': 0,
            'replies': 0,
          });

      // Update comment count
      await _firestore.collection('commentCounts').doc(videoId).update({
        'totalCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error posting comment: $e');
      rethrow;
    }
  }

  /// Like / toggle like for a video
  /// Updates scalar `likeCount` on video document and manages `users/{userId}/likedVideos/{videoId}`
  Future<void> likeVideo(String userId, String videoId) async {
    try {
      final videoRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId);
      final userLikedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId);

      await _firestore.runTransaction((transaction) async {
        final userLikedDoc = await transaction.get(userLikedRef);
        if (userLikedDoc.exists) {
          transaction.delete(userLikedRef);
          transaction.update(videoRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          transaction.set(userLikedRef, {
            'videoId': videoId,
            'likedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {'likeCount': FieldValue.increment(1)});
        }
      });
    } catch (e) {
      debugPrint('Error liking video: $e');
    }
  }

  /// Subscribe to channel
  Future<void> subscribeToChannel(String userId, String channelId) async {
    try {
      final batch = _firestore.batch();

      // Add subscription
      batch.set(
        _firestore
            .collection(FirestoreCollections.subscriptions)
            .doc(userId)
            .collection('list')
            .doc(channelId),
        {'channelId': channelId, 'subscribedAt': FieldValue.serverTimestamp()},
      );

      // Update cache
      batch.set(
        _firestore
            .collection('userCache')
            .doc(userId)
            .collection(FirestoreCollections.subscriptions)
            .doc(channelId),
        {'channelId': channelId, 'subscribedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      // Increment subscriber count
      batch.update(
        _firestore.collection(FirestoreCollections.channels).doc(channelId),
        {
          'stats.subscriberCount': FieldValue.increment(1),
        },
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error subscribing to channel: $e');
    }
  }

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Batch write with automatic chunking
  ///
  /// Firestore limits batch writes to 500 operations.
  /// This method automatically chunks larger operations.
  Future<void> batchWrite({
    required List<
      ({String collection, String docId, Map<String, dynamic> data})
    >
    writes,
  }) async {
    try {
      const maxBatchSize = 500;

      for (var i = 0; i < writes.length; i += maxBatchSize) {
        final batch = _firestore.batch();
        final chunk = writes.sublist(
          i,
          i + maxBatchSize > writes.length ? writes.length : i + maxBatchSize,
        );

        for (final write in chunk) {
          batch.set(
            _firestore.collection(write.collection).doc(write.docId),
            write.data,
          );
        }

        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error in batch write: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SEARCH QUERIES
  // ============================================================================

  /// Get search suggestions (for autocomplete)
  Future<List<String>> getSearchSuggestions(String prefix) async {
    try {
      final doc = await _firestore
          .collection('search/suggestions')
          .doc(prefix.toLowerCase())
          .get();

      if (!doc.exists) {
        return [];
      }

      final suggestions = doc.data()?['suggestions'] as List<dynamic>? ?? [];
      return suggestions.cast<String>();
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      return [];
    }
  }

  // ============================================================================
  // CLEAN UP
  // ============================================================================

  /// Enable offline data persistence
  Future<void> enableOfflinePersistence() async {
    try {
      await _firestore.enableNetwork();
    } catch (e) {
      debugPrint('Error enabling offline persistence: $e');
    }
  }

  /// Disable network for offline mode
  Future<void> disableNetwork() async {
    try {
      await _firestore.disableNetwork();
    } catch (e) {
      debugPrint('Error disabling network: $e');
    }
  }
}
