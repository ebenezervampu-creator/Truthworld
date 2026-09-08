import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlaylistsManagementController extends BaseController
    with ContentValidationMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Reactive State
  final RxString searchQuery = ''.obs;
  final RxList<PlaylistModel> playlistsList = <PlaylistModel>[].obs;
  final RxBool rxIsLoading = false.obs;
  final RxString activeFilterMode =
      'all'.obs; // 'all' | 'public' | 'unlisted' | 'private'
  final RxString activeSortMode =
      'recent'.obs; // 'recent' | 'videos_desc' | 'title_asc' | 'oldest'
  final RxBool isGridView = true.obs;
  late final TextEditingController searchController = trackTextController(TextEditingController());

  // Cache for loaded videos
  final RxMap<String, Video> cachedVideos = <String, Video>{}.obs;

  // Stream Subscription
  StreamSubscription<List<PlaylistModel>>? _playlistsSubscription;

  void setFilterMode(String mode) {
    activeFilterMode.value = mode;
  }

  void setSortMode(String mode) {
    activeSortMode.value = mode;
  }

  void toggleViewMode() {
    isGridView.value = !isGridView.value;
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  // Summary Metrics Getters
  int get totalPlaylistsCount => playlistsList.length;
  int get totalVideosCount =>
      playlistsList.fold(0, (acc, p) => acc + p.videoCount);
  int get publicPlaylistsCount =>
      playlistsList
          .where((p) => p.visibility == PlaylistVisibility.public)
          .length;
  int get unlistedPlaylistsCount =>
      playlistsList
          .where((p) => p.visibility == PlaylistVisibility.unlisted)
          .length;
  int get privatePlaylistsCount =>
      playlistsList
          .where((p) => p.visibility == PlaylistVisibility.private)
          .length;

  /// Computed filtered and sorted playlists
  List<PlaylistModel> get filteredPlaylists {
    final query = searchQuery.value.trim().toLowerCase();
    final filter = activeFilterMode.value;

    final list = playlistsList.where((p) {
      // Filter by mode
      if (filter == 'public' && p.visibility != PlaylistVisibility.public) {
        return false;
      }
      if (filter == 'unlisted' && p.visibility != PlaylistVisibility.unlisted) {
        return false;
      }
      if (filter == 'private' && p.visibility != PlaylistVisibility.private) {
        return false;
      }

      // Filter by search query
      if (query.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesDesc = p.description.toLowerCase().contains(query);
        final matchesId = p.id.toLowerCase().contains(query);
        if (!matchesName && !matchesDesc && !matchesId) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort
    switch (activeSortMode.value) {
      case 'videos_desc':
        list.sort((a, b) => b.videoCount.compareTo(a.videoCount));
      case 'title_asc':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'oldest':
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'recent':
      default:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return list;
  }

  /// Real-time stream for channel playlists
  Stream<List<PlaylistModel>> fetchChannelPlaylists(String channelId) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final targetChannelId = channelId.isNotEmpty ? channelId : currentUid;

    if (targetChannelId.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection(FirestoreCollections.playlists)
        .where('channelId', isEqualTo: targetChannelId)
        .snapshots()
        .asyncMap((channelSnap) async {
          final itemsMap = <String, PlaylistModel>{};
          for (final doc in channelSnap.docs) {
            itemsMap[doc.id] = PlaylistModel.fromDocumentSnapshot(doc);
          }

          if (currentUid.isNotEmpty && currentUid != targetChannelId) {
            try {
              final ownerSnap = await _firestore
                  .collection(FirestoreCollections.playlists)
                  .where('ownerId', isEqualTo: currentUid)
                  .get();
              for (final doc in ownerSnap.docs) {
                itemsMap[doc.id] = PlaylistModel.fromDocumentSnapshot(doc);
              }
            } catch (e) {
              debugPrint('Error fetching owner playlists: $e');
            }
          }

          final list = itemsMap.values.toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list;
        });
  }

  /// Fetch videos for channel to select in playlist builder
  Future<List<Video>> fetchChannelVideos(String channelId) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final userChannelId = Get.isRegistered<AuthService>()
          ? (AuthService.to.userChannel?.id ?? '')
          : '';

      final targetIds = <String>{};
      if (channelId.isNotEmpty) targetIds.add(channelId);
      if (userChannelId.isNotEmpty) targetIds.add(userChannelId);
      if (currentUid.isNotEmpty) targetIds.add(currentUid);

      final videos = <Video>[];
      final seenIds = <String>{};

      void addVideoDocs(Iterable<QueryDocumentSnapshot> docs) {
        for (final doc in docs) {
          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            try {
              final video = Video.fromDocumentSnapshot(doc);
              videos.add(video);
              cachedVideos[video.id] = video;
            } catch (e) {
              debugPrint('Error parsing video ${doc.id}: $e');
            }
          }
        }
      }

      // Query root collection by channelId, ownerId, userId
      for (final id in targetIds) {
        try {
          final q1 = await _firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: id)
              .get();
          addVideoDocs(q1.docs);
        } catch (_) {}

        try {
          final q2 = await _firestore
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: id)
              .get();
          addVideoDocs(q2.docs);
        } catch (_) {}

        try {
          final q3 = await _firestore
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: id)
              .get();
          addVideoDocs(q3.docs);
        } catch (_) {}

        // Also check channel subcollection channels/{id}/videos
        try {
          final qSub = await _firestore
              .collection(FirestoreCollections.channels)
              .doc(id)
              .collection(FirestoreCollections.videos)
              .get();
          addVideoDocs(qSub.docs);
        } catch (_) {}
      }

      // Sort newest videos first
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return videos;
    } catch (e) {
      debugPrint('Error fetching channel videos: $e');
      return [];
    }
  }

  /// Fetch full video objects by their IDs
  Future<List<Video>> fetchVideosByIds(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];

    final result = <Video>[];
    final missingIds = <String>[];

    for (final id in videoIds) {
      if (cachedVideos.containsKey(id)) {
        result.add(cachedVideos[id]!);
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isNotEmpty) {
      // Chunk into batches of 10 for Firestore whereIn query limit
      for (var i = 0; i < missingIds.length; i += 10) {
        final end = (i + 10 < missingIds.length) ? i + 10 : missingIds.length;
        final batch = missingIds.sublist(i, end);
        try {
          final snap = await _firestore
              .collection(FirestoreCollections.videos)
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          for (final doc in snap.docs) {
            final video = Video.fromDocumentSnapshot(doc);
            cachedVideos[video.id] = video;
            result.add(video);
          }
        } catch (e) {
          debugPrint('Error batch fetching videos: $e');
        }
      }
    }

    // Maintain order according to input videoIds list
    final ordered = <Video>[];
    for (final id in videoIds) {
      final v = result.firstWhereOrNull((video) => video.id == id);
      if (v != null) ordered.add(v);
    }
    return ordered;
  }

  /// Upload playlist custom thumbnail
  Future<String?> uploadPlaylistThumbnail(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final ref = _storage.ref().child('thumbnails/playlists/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': user.uid,
          'uploaded': DateTime.now().toString(),
        },
      );
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading playlist thumbnail: $e');
      return null;
    }
  }

  /// Create a new playlist
  Future<bool> createPlaylist({
    required String channelId,
    required String name,
    required String description,
    required PlaylistVisibility visibility,
    required List<String> selectedVideoIds,
    String customThumbnailUrl = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      AppSnackbar.show(
        'Required',
        'Please enter a playlist title.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }

    final nameVal = ContentValidator.validate(cleanName, fieldName: 'Playlist Title');
    if (!nameVal.isValid) {
      AppSnackbar.show(
        'Inappropriate Content',
        nameVal.message,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }

    final cleanDesc = description.trim();
    if (cleanDesc.isNotEmpty) {
      final descVal = ContentValidator.validate(
        cleanDesc,
        fieldName: 'Playlist Description',
      );
      if (!descVal.isValid) {
        AppSnackbar.show(
          'Inappropriate Content',
          descVal.message,
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }
    }

    rxIsLoading.value = true;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final docRef = _firestore.collection(FirestoreCollections.playlists).doc();

      var thumbnailUrl = customThumbnailUrl;
      if (thumbnailUrl.isEmpty && selectedVideoIds.isNotEmpty) {
        final firstVid = cachedVideos[selectedVideoIds.first];
        if (firstVid != null && firstVid.thumbnailUrl.isNotEmpty) {
          thumbnailUrl = firstVid.thumbnailUrl;
        } else {
          final doc = await _firestore
              .collection(FirestoreCollections.videos)
              .doc(selectedVideoIds.first)
              .get();
          if (doc.exists) {
            thumbnailUrl = doc.data()?['thumbnailUrl'] ?? '';
          }
        }
      }

      final playlist = PlaylistModel(
        id: docRef.id,
        name: cleanName,
        playlistName: cleanName,
        description: cleanDesc,
        ownerId: currentUid,
        channelId: channelId.isNotEmpty ? channelId : currentUid,
        thumbnailUrl: thumbnailUrl,
        videoCount: selectedVideoIds.length,
        videoIds: selectedVideoIds,
        visibility: visibility,
        isPublic: visibility == PlaylistVisibility.public,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        sortIndex: playlistsList.length,
        status: 'active',
      );

      await docRef.set(playlist.toMap());

      // Also write items to subcollection for indexing
      for (var i = 0; i < selectedVideoIds.length; i++) {
        await docRef.collection('items').doc(selectedVideoIds[i]).set({
          'videoId': selectedVideoIds[i],
          'addedAt': FieldValue.serverTimestamp(),
          'position': i,
        });
      }

      AppSnackbar.show(
        'Success',
        'Playlist "$cleanName" created successfully.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
      return true;
    } catch (e) {
      debugPrint('Error creating playlist: $e');
      AppSnackbar.show(
        'Error',
        'Failed to create playlist: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Update playlist metadata
  Future<bool> updatePlaylistMetadata({
    required String playlistId,
    required String name,
    required String description,
    required PlaylistVisibility visibility,
    String? customThumbnailUrl,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    final nameVal = ContentValidator.validate(cleanName, fieldName: 'Playlist Title');
    if (!nameVal.isValid) {
      AppSnackbar.show(
        'Inappropriate Content',
        nameVal.message,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }

    final cleanDesc = description.trim();
    if (cleanDesc.isNotEmpty) {
      final descVal = ContentValidator.validate(
        cleanDesc,
        fieldName: 'Playlist Description',
      );
      if (!descVal.isValid) {
        AppSnackbar.show(
          'Inappropriate Content',
          descVal.message,
          backgroundColor: AppColors.error,
          colorText: AppColors.textPrimary,
        );
        return false;
      }
    }

    try {
      final updateData = <String, dynamic>{
        'name': cleanName,
        'playlistName': cleanName,
        'description': cleanDesc,
        'visibility': visibility.name,
        'isPublic': visibility == PlaylistVisibility.public,
        'updatedAt': Timestamp.now(),
      };

      if (customThumbnailUrl != null && customThumbnailUrl.isNotEmpty) {
        updateData['thumbnailUrl'] = customThumbnailUrl;
      }

      await _firestore
          .collection(FirestoreCollections.playlists)
          .doc(playlistId)
          .update(updateData);

      AppSnackbar.show(
        'Updated',
        'Playlist details updated.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
      return true;
    } catch (e) {
      debugPrint('Error updating playlist: $e');
      AppSnackbar.show(
        'Error',
        'Failed to update playlist: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }
  }

  /// Update playlist video ordering and list
  Future<bool> updatePlaylistVideos({
    required PlaylistModel playlist,
    required List<String> videoIds,
  }) async {
    try {
      var thumbnailUrl = playlist.thumbnailUrl;
      if (videoIds.isNotEmpty &&
          (thumbnailUrl.isEmpty || !videoIds.contains(thumbnailUrl))) {
        final firstVid = cachedVideos[videoIds.first];
        if (firstVid != null && firstVid.thumbnailUrl.isNotEmpty) {
          thumbnailUrl = firstVid.thumbnailUrl;
        }
      }

      await _firestore
          .collection(FirestoreCollections.playlists)
          .doc(playlist.id)
          .update({
            'videoIds': videoIds,
            'videoCount': videoIds.length,
            'thumbnailUrl': thumbnailUrl,
            'updatedAt': Timestamp.now(),
          });

      // Update items subcollection
      final itemsRef = _firestore
          .collection(FirestoreCollections.playlists)
          .doc(playlist.id)
          .collection('items');

      final existingDocs = await itemsRef.get();
      for (final doc in existingDocs.docs) {
        if (!videoIds.contains(doc.id)) {
          await doc.reference.delete();
        }
      }

      for (var i = 0; i < videoIds.length; i++) {
        await itemsRef.doc(videoIds[i]).set({
          'videoId': videoIds[i],
          'addedAt': FieldValue.serverTimestamp(),
          'position': i,
        }, SetOptions(merge: true));
      }

      AppSnackbar.show(
        'Saved',
        'Playlist videos updated.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
      return true;
    } catch (e) {
      debugPrint('Error updating playlist videos: $e');
      AppSnackbar.show(
        'Error',
        'Failed to save video changes: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }
  }

  /// Delete a playlist
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.playlists)
          .doc(playlistId)
          .delete();

      AppSnackbar.show(
        'Deleted',
        'Playlist deleted successfully.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return true;
    } catch (e) {
      debugPrint('Error deleting playlist: $e');
      AppSnackbar.show(
        'Error',
        'Failed to delete playlist: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return false;
    }
  }

  /// Copy playlist link to clipboard
  void copyPlaylistLink(PlaylistModel playlist) {
    final link = 'https://truthworld.tv/playlist/${playlist.id}';
    Clipboard.setData(ClipboardData(text: link));
    AppSnackbar.show(
      'Link Copied',
      'Playlist link copied to clipboard.',
      backgroundColor: AppColors.bgSurfaceHigh,
      colorText: AppColors.textPrimary,
    );
  }

  @override
  void onClose() {
    _playlistsSubscription?.cancel();
    super.onClose();
  }
}
