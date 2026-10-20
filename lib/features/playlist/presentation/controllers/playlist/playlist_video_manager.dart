import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Manager handling video items within playlists (addition, deletion, bulk updates, queries).
class PlaylistVideoManager {
  PlaylistVideoManager({
    required this.getUserId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String Function() getUserId;

  Future<void> updateThumbnail(
    DocumentReference ref,
    List<String> videoIds,
  ) async {
    if (videoIds.isEmpty) {
      await ref.update({'thumbnailUrl': null});
    } else {
      final videoDoc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoIds.first)
          .get();
      if (videoDoc.exists) {
        await ref.update({'thumbnailUrl': videoDoc.data()?['thumbnailUrl']});
      }
    }
  }

  Future<List<String>> fetchPlaylistVideoIds(
    String playlistId,
    bool isPublic, {
    String? ownerId,
    List<String>? watchLaterVideoIds,
  }) async {
    try {
      if (playlistId == 'watchlater') {
        return watchLaterVideoIds ?? [];
      }
      final user = getUserId();
      final targetUser = (ownerId != null && ownerId.isNotEmpty)
          ? ownerId
          : user;
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection(FirestoreCollections.users)
                .doc(targetUser)
                .collection(FirestoreCollections.playlists)
                .doc(playlistId);

      QuerySnapshot snapshot;
      try {
        snapshot = await ref
            .collection('items')
            .orderBy('addedAt')
            .limit(100)
            .getCacheFirst();
      } catch (_) {
        snapshot = await ref.collection('items').limit(100).getCacheFirst();
      }

      if (snapshot.docs.isEmpty) {
        final doc = await ref.getCacheFirst();
        if (doc.exists && doc.data() != null) {
          final rawIds = doc.data()?['videoIds'];
          if (rawIds is List) {
            return List<String>.from(rawIds);
          }
        }
      }

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      logger.debug('❌ Error fetching playlist video IDs: $e');
      return [];
    }
  }

  Future<void> addMultipleVideosToPlaylist(
    String playlistId,
    List<String> videoIdsToAdd,
    bool isPublic,
  ) async {
    final user = getUserId();
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection(FirestoreCollections.users)
                .doc(user)
                .collection(FirestoreCollections.playlists)
                .doc(playlistId);

      final snapshot = await ref.get();
      if (!snapshot.exists) {
        throw const NotFoundException(message: 'Playlist not found');
      }

      final data = snapshot.data();
      final currentVideoIds = List<String>.from(data?['videoIds'] ?? []);
      var addedCount = 0;
      final currentTotalCount = (data?['videoCount'] as num?)?.toInt() ?? 0;

      for (final vid in videoIdsToAdd) {
        final itemDoc = await ref.collection('items').doc(vid).get();
        if (!itemDoc.exists) {
          await ref.collection('items').doc(vid).set({
            'videoId': vid,
            'addedAt': FieldValue.serverTimestamp(),
            'position': currentTotalCount + addedCount,
          });
          if (!currentVideoIds.contains(vid)) {
            currentVideoIds.add(vid);
          }
          addedCount++;
        }
      }

      if (addedCount > 0) {
        final cappedVideoIds = currentVideoIds.take(10).toList();
        await ref.update({
          'videoIds': cappedVideoIds,
          'videoCount': FieldValue.increment(addedCount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (currentVideoIds.length == addedCount ||
            data?['thumbnailUrl'] == null) {
          await updateThumbnail(ref, currentVideoIds);
        }
        AppSnackbar.success('Videos added to playlist!');
      } else {
        AppSnackbar.info('All selected videos are already in the playlist.');
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to add videos to playlist. Please try again.');
    }
  }

  Future<void> addVideoToPlaylist(
    String playlistId,
    String videoId,
    bool isPublic,
  ) async {
    final user = getUserId();
    try {
      var targetRef = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection(FirestoreCollections.users)
                .doc(user)
                .collection(FirestoreCollections.playlists)
                .doc(playlistId);

      var snapshot = await targetRef.get();
      if (!snapshot.exists) {
        final altRef = !isPublic
            ? _firestore.collection('public_playlists').doc(playlistId)
            : _firestore
                  .collection(FirestoreCollections.users)
                  .doc(user)
                  .collection(FirestoreCollections.playlists)
                  .doc(playlistId);
        final altSnapshot = await altRef.get();
        if (altSnapshot.exists) {
          targetRef = altRef;
          snapshot = altSnapshot;
        } else {
          throw const NotFoundException(message: 'Playlist not found');
        }
      }

      final itemDoc = await targetRef.collection('items').doc(videoId).get();
      if (!itemDoc.exists) {
        final data = snapshot.data();
        await targetRef.collection('items').doc(videoId).set({
          'videoId': videoId,
          'addedAt': FieldValue.serverTimestamp(),
          'position': (data?['videoCount'] ?? 0),
        });

        final currentVideoIds = List<String>.from(data?['videoIds'] ?? []);
        if (!currentVideoIds.contains(videoId)) {
          currentVideoIds.add(videoId);
        }
        final cappedVideoIds = currentVideoIds.take(10).toList();

        await targetRef.update({
          'videoIds': cappedVideoIds,
          'videoCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (currentVideoIds.length == 1 || data?['thumbnailUrl'] == null) {
          await updateThumbnail(targetRef, currentVideoIds);
        }

        AppSnackbar.success('Video added to playlist!');
      } else {
        AppSnackbar.info('Video is already in this playlist.');
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to add video to playlist. Please try again.');
    }
  }

  Future<void> removeVideoFromPlaylist(
    String playlistId,
    String videoId,
    bool isPublic,
  ) async {
    final user = getUserId();
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection(FirestoreCollections.users)
                .doc(user)
                .collection(FirestoreCollections.playlists)
                .doc(playlistId);

      final snapshot = await ref.get();
      if (!snapshot.exists) {
        throw const NotFoundException(message: 'Playlist not found');
      }

      final itemDoc = await ref.collection('items').doc(videoId).get();
      if (itemDoc.exists) {
        await ref.collection('items').doc(videoId).delete();

        final itemsSnap = await ref
            .collection('items')
            .orderBy('addedAt')
            .limit(10)
            .get();
        final newCachedIds = itemsSnap.docs.map((doc) => doc.id).toList();

        final data = snapshot.data();
        final currentCount = (data?['videoCount'] as num?)?.toInt() ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        await ref.update({
          'videoIds': newCachedIds,
          'videoCount': newCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await updateThumbnail(ref, newCachedIds);

        AppSnackbar.success('Video removed from playlist!');
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to remove video from playlist. Please try again.',
      );
    }
  }

  Future<void> deleteVideoFromAllPlaylists(String videoId) async {
    final user = getUserId();
    if (user.isEmpty) return;
    try {
      final userPlaylists = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user)
          .collection(FirestoreCollections.playlists)
          .getCacheFirst();

      final publicPlaylists = await _firestore
          .collection('public_playlists')
          .where('ownerId', isEqualTo: user)
          .getCacheFirst();

      final allDocs = [...userPlaylists.docs, ...publicPlaylists.docs];
      if (allDocs.isEmpty) return;

      final affectedDocs = allDocs.where((doc) {
        final videoIds = List<String>.from(
          doc.data()['videoIds'] as List? ?? [],
        );
        return videoIds.contains(videoId);
      }).toList();

      if (affectedDocs.isEmpty) {
        AppSnackbar.success('Video removed from all playlists!');
        return;
      }

      final batch = _firestore.batch();
      for (final doc in affectedDocs) {
        final itemRef = doc.reference.collection('items').doc(videoId);
        batch.delete(itemRef);

        final currentCount = (doc.data()['videoCount'] as num?)?.toInt() ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;
        final currentVideoIds = List<String>.from(
          doc.data()['videoIds'] as List? ?? [],
        );
        currentVideoIds.remove(videoId);

        batch.update(doc.reference, {
          'videoIds': currentVideoIds,
          'videoCount': newCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      for (final doc in affectedDocs) {
        final currentVideoIds = List<String>.from(
          doc.data()['videoIds'] as List? ?? [],
        );
        currentVideoIds.remove(videoId);
        await updateThumbnail(doc.reference, currentVideoIds);
      }

      AppSnackbar.success('Video removed from all playlists!');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to remove video from playlists. Please try again.',
      );
    }
  }

  Future<List<Video>> fetchVideos(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];
    const batchSize = 10;
    final batches = <List<String>>[];

    for (var i = 0; i < videoIds.length; i += batchSize) {
      batches.add(videoIds.skip(i).take(batchSize).toList());
    }

    final snapshots = await Future.wait(
      batches.map(
        (batch) => _firestore
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: batch)
            .getCacheFirst(),
      ),
    );

    final videos = <Video>[];
    for (final snapshot in snapshots) {
      videos.addAll(snapshot.docs.map(Video.fromDocumentSnapshot));
    }

    final videoMap = <String, Video>{for (final v in videos) v.id: v};
    return videoIds
        .map((id) => videoMap[id] ?? _getPlaceholderVideo(id))
        .toList();
  }

  Video _getPlaceholderVideo(String id) {
    return Video(
      id: id,
      title: 'Video not found',
      description: '',
      thumbnailUrl: '',
      ownerId: '',
      channelId: '',
      channelName: '',
      category: '',
      tags: [],
    );
  }
}
