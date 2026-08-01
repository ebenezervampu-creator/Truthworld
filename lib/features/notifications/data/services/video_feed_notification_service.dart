import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class VideoFeedNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int defaultVideoLimit = 50;

  // 🔥 O(1) MATERIALIZED FEED STREAM
  Stream<List<Video>> getVideoNotificationsStream(
    String userId, {
    int limit = defaultVideoLimit,
  }) {
    if (userId == 'guest_user' || userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection('feed_inbox')
        .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_mapInboxToVideo).toList();
        });
  }

  // 🔥 FETCH NOTIFICATIONS ONCE
  Future<List<Video>> getVideoNotificationsOnce(
    String userId, {
    int limit = defaultVideoLimit,
  }) async {
    if (userId == 'guest_user' || userId.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('feed_inbox')
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map(_mapInboxToVideo).toList();
    } catch (e) {
      debugPrint('Error fetching materialized notifications once: $e');
      return [];
    }
  }

  // 🔥 MARK VIDEO AS SEEN
  Future<void> markVideoAsSeen(String userId, String videoId) async {
    if (userId == 'guest_user' || userId.isEmpty) return;
    try {
      // Explicitly flag the specific feed inbox document
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('feed_inbox')
          .doc(videoId)
          .update({'isSeen': true});
    } catch (e) {
      debugPrint('Error marking video as seen: $e');
    }
  }

  // 🔥 MARK ALL AS SEEN
  Future<void> markAllAsSeen(String userId, List<String> videoIds) async {
    if (userId == 'guest_user' || userId.isEmpty || videoIds.isEmpty) return;
    try {
      // Update last seen notifications timestamp only (no unbounded array)
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .update({
            'lastSeenNotifications': FieldValue.serverTimestamp(),
          });

      // 2. Perform optimal batched status propagation across local collection
      final batch = _firestore.batch();
      for (final vid in videoIds) {
        final ref = _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection('feed_inbox')
            .doc(vid);
        batch.update(ref, {'isSeen': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error batch marking all as seen: $e');
    }
  }

  // 🔥 INTERNAL DOCUMENT MAPPER
  Video _mapInboxToVideo(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final id = doc.id;
    final title = data['title'] as String? ?? '';
    final channelId = data['channelId'] as String? ?? '';
    final channelName = data['channelName'] as String? ?? '';
    final channelImage = data['channelImage'] as String? ?? '';
    final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final isSeen = data['isSeen'] as bool? ?? false;

    var createdAt = Timestamp.now();
    if (data['uploadedAt'] is Timestamp) {
      createdAt = data['uploadedAt'] as Timestamp;
    } else if (data['createdAt'] is Timestamp) {
      createdAt = data['createdAt'] as Timestamp;
    }

    var viewCount = 0;
    if (data['views'] is int) {
      viewCount = data['views'] as int;
    } else if (data['viewCount'] is int) {
      viewCount = data['viewCount'] as int;
    } else {
      viewCount = int.tryParse(data['views']?.toString() ?? '0') ?? 0;
    }

    var durationValue = Duration.zero;
    final durStr = data['duration']?.toString() ?? '';
    if (durStr.isNotEmpty && durStr.contains(':')) {
      final parts = durStr.split(':');
      if (parts.length == 3) {
        durationValue = Duration(
          hours: int.tryParse(parts[0]) ?? 0,
          minutes: int.tryParse(parts[1]) ?? 0,
          seconds: int.tryParse(parts[2]) ?? 0,
        );
      } else if (parts.length == 2) {
        durationValue = Duration(
          minutes: int.tryParse(parts[0]) ?? 0,
          seconds: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    final video = Video(
      id: id,
      title: title,
      description: '',
      thumbnailUrl: thumbnailUrl,
      ownerId: channelId,
      channelId: channelId,
      channelName: channelName,
      channelAvatarUrl: channelImage,
      category: category,
      tags: const [],
      viewCount: viewCount,
      vDurationValue: durationValue,
      createdAt: createdAt,
    );
    video.isSeen = isSeen;
    return video;
  }
}
