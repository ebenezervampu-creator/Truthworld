import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist/playlist_sync_manager.dart';

/// Manager coordinating Playlist creation, deletion, editing, visibility toggling, sort indexing, and sharing.
class PlaylistCrudManager with ContentValidationMixin {
  PlaylistCrudManager({
    required this.getUserId,
    required this.syncManager,
    required this.refreshPlaylistsTick,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String Function() getUserId;
  final PlaylistSyncManager syncManager;
  final VoidCallback refreshPlaylistsTick;

  Future<PlaylistModel?> createPlayList(
    String playlistName, {
    bool isPublic = false,
    List<String> videoIds = const [],
    String description = '',
    String customThumbnailUrl = '',
  }) async {
    final user = getUserId();
    final nameVal = await validateContent(
      playlistName,
      fieldName: 'Playlist Name',
    );
    if (!nameVal.isValid) {
      AppSnackbar.warning(nameVal.message);
      return null;
    }

    if (description.trim().isNotEmpty) {
      final descVal = await validateContent(
        description,
        fieldName: 'Playlist Description',
      );
      if (!descVal.isValid) {
        AppSnackbar.warning(descVal.message);
        return null;
      }
    }

    try {
      final playlistRef = isPublic
          ? _firestore.collection('public_playlists').doc()
          : _firestore
                .collection(FirestoreCollections.users)
                .doc(user)
                .collection(FirestoreCollections.playlists)
                .doc();

      var thumbnailUrl =
          customThumbnailUrl.isNotEmpty ? customThumbnailUrl : null;
      if ((thumbnailUrl == null || thumbnailUrl.isEmpty) &&
          videoIds.isNotEmpty) {
        final videoDoc = await _firestore
            .collection(FirestoreCollections.videos)
            .doc(videoIds.first)
            .get();
        if (videoDoc.exists) {
          thumbnailUrl = videoDoc.data()?['thumbnailUrl'];
        }
      }

      final currentCount = syncManager.playlists.length;

      var channelId = syncManager.selectedChannel.value?.channelId ?? '';
      if (channelId.isEmpty && syncManager.channels.isNotEmpty) {
        final userChannel = syncManager.channels.firstWhere(
          (c) => c.ownerId == user,
          orElse: () => syncManager.channels.first,
        );
        channelId = userChannel.channelId;
        syncManager.selectedChannel.value = userChannel;
      }

      final playlist = PlaylistModel(
        id: playlistRef.id,
        playlistName: playlistName,
        description: description,
        videoIds: videoIds.take(10).toList(),
        videoCount: videoIds.length,
        isPublic: isPublic,
        ownerId: user,
        channelId: channelId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        thumbnailUrl: thumbnailUrl ?? '',
        sortIndex: currentCount,
      );

      await playlistRef.set(playlist.toMap());

      for (var i = 0; i < videoIds.length; i++) {
        await playlistRef.collection('items').doc(videoIds[i]).set({
          'videoId': videoIds[i],
          'addedAt': FieldValue.serverTimestamp(),
          'position': i,
        });
      }

      if (isPublic) {
        if (!syncManager.publicPlaylists.any((p) => p.id == playlist.id)) {
          syncManager.publicPlaylists.add(playlist);
        }
      } else {
        if (!syncManager.playlists.any((p) => p.id == playlist.id)) {
          syncManager.playlists.add(playlist);
        }
      }

      refreshPlaylistsTick();

      logger.debug(
        '✅ Created playlist: ${playlist.playlistName} (${playlist.id})',
      );

      AppSnackbar.success('Playlist created successfully!');
      return playlist;
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to create playlist. Please try again.');
      return null;
    }
  }

  Future<void> deletePlaylist(String playlistId, bool isPublic) async {
    final user = getUserId();
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection(FirestoreCollections.users)
                .doc(user)
                .collection(FirestoreCollections.playlists)
                .doc(playlistId);

      await ref.update({
        'status': 'deletion_pending',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      });

      try {
        await _firestore.collection(FirestoreCollections.playlists).doc(playlistId).update({
          'status': 'deletion_pending',
          'deletionRequestedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      AppSnackbar.success('Playlist moved to Trash. It will be retained for 30 days.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to move playlist to Trash. Please try again.');
    }
  }

  Future<PlaylistModel> getPlaylist(
    String playlistId, {
    required bool isPublic,
  }) async {
    final user = getUserId();
    final doc = isPublic
        ? await _firestore.collection('public_playlists').doc(playlistId).get()
        : await _firestore
              .collection(FirestoreCollections.users)
              .doc(user)
              .collection(FirestoreCollections.playlists)
              .doc(playlistId)
              .get();

    if (!doc.exists) {
      throw const NotFoundException(message: 'Playlist not found');
    }
    return PlaylistModel.fromDocumentSnapshot(doc);
  }

  Future<void> editPlaylist(
    String playlistId,
    String newName,
    bool isPublic,
  ) async {
    final validation = ContentValidator.validate(
      newName,
      fieldName: 'Playlist Name',
      maxLength: 100,
    );
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    final user = getUserId();
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection(FirestoreCollections.users)
                .doc(user)
                .collection(FirestoreCollections.playlists)
                .doc(playlistId);

      await ref.update({
        'name': newName,
        'playlistName': newName,
        'status': 'underReview',
        'geminiApproved': null,
        'moderationReason': null,
        'updatedAt': Timestamp.now(),
      });

      refreshPlaylistsTick();
      AppSnackbar.success('Playlist renamed successfully!');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to rename playlist. Please try again.');
    }
  }

  Future<void> updateSortIndex(
    String playlistId,
    int newIndex,
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

      await ref.update({'sortIndex': newIndex, 'updatedAt': Timestamp.now()});
      refreshPlaylistsTick();
    } catch (e) {
      logger.debug('❌ Error updating sort index: $e');
    }
  }

  Future<void> togglePlaylistVisibility(
    String playlistId,
    bool currentIsPublic,
  ) async {
    final user = getUserId();
    try {
      if (currentIsPublic) {
        final doc = await _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .get();
        final playlist = PlaylistModel.fromDocumentSnapshot(doc);
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(user)
            .collection(FirestoreCollections.playlists)
            .doc(playlistId)
            .set(
              playlist.toMap()
                ..['isPublic'] = false
                ..['status'] = 'underReview'
                ..['geminiApproved'] = null
                ..['moderationReason'] = null,
            );
        await _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .delete();
      } else {
        final doc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(user)
            .collection(FirestoreCollections.playlists)
            .doc(playlistId)
            .get();
        final playlist = PlaylistModel.fromDocumentSnapshot(doc);
        await _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .set(
              playlist.toMap()
                ..['isPublic'] = true
                ..['status'] = 'underReview'
                ..['geminiApproved'] = null
                ..['moderationReason'] = null,
            );
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(user)
            .collection(FirestoreCollections.playlists)
            .doc(playlistId)
            .delete();
      }
      AppSnackbar.success('Playlist visibility updated!');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update playlist visibility. Please try again.',
      );
    }
  }

  Future<void> sharePlaylist(String playlistId, {String? name}) async {
    try {
      final playlist = syncManager.playlists
              .firstWhereOrNull((p) => p.id == playlistId) ??
          syncManager.publicPlaylists
              .firstWhereOrNull((p) => p.id == playlistId);

      final playlistName = name ?? playlist?.playlistName ?? 'Playlist';
      final thumbnailUrl = playlist?.thumbnailUrl;
      final videoCount = playlist?.videoCount;

      Get.find<MainController>().sharePlaylist(
        playlistId,
        playlistName,
        thumbnailUrl: thumbnailUrl,
        videoCount: videoCount,
      );
    } catch (e, stackTrace) {
      logger.error(
        '❌ Error sharing playlist',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
