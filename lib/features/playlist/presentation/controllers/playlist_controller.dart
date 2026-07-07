import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';

import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class PlaylistController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _channelsSubscription;
  StreamSubscription<QuerySnapshot>? _playlistsSubscription;
  // Use a getter to safely retrieve the current user ID
  String get user => FirebaseAuth.instance.currentUser?.uid ?? '';

  var channels = <Channel>[].obs;
  var playlists = <PlaylistModel>[].obs;
  var publicPlaylists = <PlaylistModel>[].obs; // For upload screen
  Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  RxBool isLoading = false.obs;

  // UI State for PlaylistScreen
  final RxBool isSearching = false.obs;
  final RxBool isSearchExpanded = false.obs;
  final RxBool isListView = true.obs;
  final RxString sortBy = 'recent'.obs;
  final RxBool isAscending = false.obs;
  final RxString searchQuery = ''.obs;
  final RxInt refreshTick = 0.obs;
  final RxSet<String> selectedVideoIds = <String>{}.obs;

  // Filter State
  final RxString selectedCategory = 'Playlists'.obs;
  final List<String> categories = [
    'Playlists',
    'Music',
    'Podcasts',
    'Courses',
    'Owned',
    'Saved'
  ];

  void setCategory(String category) => selectedCategory.value = category;

  void toggleView() => isListView.value = !isListView.value;

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) searchQuery.value = '';
  }

  void setSortBy(String newSortBy) {
    if (sortBy.value == newSortBy) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = newSortBy;
      isAscending.value = false;
    }
  }

  void updateSearchQuery(String query) => searchQuery.value = query;

  void toggleVideoSelection(String videoId) {
    if (selectedVideoIds.contains(videoId)) {
      selectedVideoIds.remove(videoId);
    } else {
      selectedVideoIds.add(videoId);
    }
  }

  void refreshPlaylistsTick() => refreshTick.value++;

  Iterable<PlaylistModel> get userCreatedPlaylists {
    final filtered = playlists.where((p) {
      final name = p.playlistName.toLowerCase().trim();
      // Filter out watch later playlists (various spellings)
      final isWatchLater =
          name == 'watch later' ||
          name == 'watchlater' ||
          name == 'watch_later' ||
          name.contains('watch later');

      return !isWatchLater && name.isNotEmpty;
    });

    logger.debug(
      'Playlist filtering: ${playlists.length} total → ${filtered.length} visible',
      tag: 'PLAYLIST',
    );
    return filtered;
  }

  final watchLaterVideoIds = <String>[].obs;
  StreamSubscription? _watchLaterSub;

  void listenToWatchLater() {
    _watchLaterSub?.cancel();
    if (user.isEmpty) {
      watchLaterVideoIds.clear();
      return;
    }
    _watchLaterSub = _firestore
        .collection('users')
        .doc(user)
        .collection('watch_later')
        .snapshots()
        .listen((snapshot) {
      watchLaterVideoIds.value = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  PlaylistModel? getWatchLaterPlaylist() {
    // Return a virtual playlist model populated from watchLaterVideoIds
    return PlaylistModel(
      id: 'watchlater',
      playlistName: 'Watch Later',
      videoIds: watchLaterVideoIds,
      isPublic: false,
      ownerId: user,
      channelId: '',
      createdAt: DateTime.now(),
      thumbnailUrl: '',
    );
  }

  /// Toggle video in "Watch Later" playlist
  Future<void> toggleWatchLater(String videoId) async {
    if (user.isEmpty) {
      Get.snackbar("Auth required", "Please sign in to update Watch Later");
      return;
    }
    try {
      isLoading.value = true;
      final ref = _firestore
          .collection('users')
          .doc(user)
          .collection('watch_later')
          .doc(videoId);

      final isAlreadyIn = watchLaterVideoIds.contains(videoId);
      if (isAlreadyIn) {
        await ref.delete();
        Get.snackbar("Success", "Removed from Watch Later");
      } else {
        await ref.set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        Get.snackbar("Success", "Added to Watch Later");
      }
    } catch (e) {
      logger.debug("❌ Error toggling Watch Later: $e");
      Get.snackbar("Error", "Failed to update Watch Later");
    } finally {
      isLoading.value = false;
    }
  }

  bool isInWatchLater(String videoId) {
    return watchLaterVideoIds.contains(videoId);
  }

  @override
  void onInit() {
    super.onInit();
    fetchChannels();

    // Listen to authentication state changes from AuthService
    // This ensures playlists are fetched only when a user is logged in
    ever(AuthService.to.currentUser, (User? u) {
      if (u != null) {
        fetchPlaylists();
        listenToWatchLater();
      } else {
        // If user logs out, cancel the subscription and clear the list
        _playlistsSubscription?.cancel();
        playlists.clear();
        _watchLaterSub?.cancel();
        watchLaterVideoIds.clear();
      }
    });

    // Initial fetch if user is already authenticated
    if (user.isNotEmpty) {
      fetchPlaylists();
      listenToWatchLater();
    }
  }

  @override
  void onClose() {
    _channelsSubscription?.cancel();
    _playlistsSubscription?.cancel();
    _publicPlaylistsSubscription?.cancel();
    _watchLaterSub?.cancel();
    super.onClose();
  }

  // ===================== Playlist CRUD =====================

  /// Create a new playlist
  Future<PlaylistModel?> createPlayList(
    String playlistName, {
    bool isPublic = false,
    List<String> videoIds = const [],
  }) async {
    try {
      final playlistRef = isPublic
          ? _firestore.collection('public_playlists').doc()
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc();

      String? thumbnailUrl;
      if (videoIds.isNotEmpty) {
        final videoDoc = await _firestore
            .collection('videos')
            .doc(videoIds.first)
            .get();
        if (videoDoc.exists) {
          thumbnailUrl = videoDoc.data()?['thumbnailUrl'];
        }
      }

      // Set sortIndex to current count for proper ordering
      final currentCount = playlists.length;

      // Get channel ID - try selected channel first, then find user's channel
      String channelId = selectedChannel.value?.channelId ?? '';
      if (channelId.isEmpty && channels.isNotEmpty) {
        // Find channel owned by current user
        final userChannel = channels.firstWhere(
          (c) => c.ownerId == user,
          orElse: () => channels.first,
        );
        channelId = userChannel.channelId;
        // Also update selectedChannel for future use
        selectedChannel.value = userChannel;
      }

      final playlist = PlaylistModel(
        id: playlistRef.id,
        playlistName: playlistName,
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

      // Write video items to the subcollection
      for (int i = 0; i < videoIds.length; i++) {
        await playlistRef.collection('items').doc(videoIds[i]).set({
          'videoId': videoIds[i],
          'addedAt': FieldValue.serverTimestamp(),
          'position': i,
        });
      }

      // Add to local list immediately for UI update
      playlists.add(playlist);

      // Refresh to ensure consistency
      refreshPlaylistsTick();

      logger.debug(
        '✅ Created playlist: ${playlist.playlistName} (${playlist.id})',
      );

      Get.snackbar(
        "Success",
        "Playlist created successfully!",
        snackPosition: SnackPosition.BOTTOM,
      );

      return playlist;
    } catch (e) {
      logger.debug("❌ Error creating playlist: $e");
      Get.snackbar(
        "Error",
        "Failed to create playlist!",
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  /// Delete an entire playlist
  Future<void> deletePlaylist(String playlistId, bool isPublic) async {
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc(playlistId);

      await ref.delete();

      Get.snackbar(
        "Success",
        "Playlist deleted successfully!",
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      logger.debug("❌ Error deleting playlist: $e");
      Get.snackbar(
        "Error",
        "Failed to delete playlist!",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Internal helper to update playlist thumbnail based on the first video
  Future<void> _updateThumbnail(
    DocumentReference ref,
    List<String> videoIds,
  ) async {
    if (videoIds.isEmpty) {
      await ref.update({'thumbnailUrl': null});
    } else {
      final videoDoc = await _firestore
          .collection('videos')
          .doc(videoIds.first)
          .get();
      if (videoDoc.exists) {
        await ref.update({'thumbnailUrl': videoDoc.data()?['thumbnailUrl']});
      }
    }
  }

  // ===================== Video Management =====================

  Future<List<String>> fetchPlaylistVideoIds(
    String playlistId,
    bool isPublic,
  ) async {
    try {
      if (playlistId == 'watchlater') {
        return watchLaterVideoIds;
      }
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc(playlistId);

      final snapshot = await ref.collection('items').orderBy('addedAt').get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      logger.debug("❌ Error fetching playlist video IDs: $e");
      return [];
    }
  }

  /// Add multiple videos to a playlist
  Future<void> addMultipleVideosToPlaylist(
    String playlistId,
    List<String> videoIdsToAdd,
    bool isPublic,
  ) async {
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc(playlistId);

      final snapshot = await ref.get();
      if (!snapshot.exists) throw "Playlist not found";

      final currentVideoIds = List<String>.from(snapshot.data()?['videoIds'] ?? []);
      int addedCount = 0;
      
      final currentTotalCount = snapshot.data()?['videoCount'] ?? 0;

      for (var vid in videoIdsToAdd) {
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
        
        // Update thumbnail if it was null or we added the first video
        if (currentVideoIds.length == addedCount ||
            snapshot.data()?['thumbnailUrl'] == null) {
          await _updateThumbnail(ref, currentVideoIds);
        }
        Get.snackbar(
          "Success",
          "Videos added to playlist!",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          "Info",
          "All selected videos are already in the playlist!",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      logger.debug("❌ Error adding videos: $e");
      Get.snackbar(
        "Error",
        "Failed to add videos: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  /// Add video to playlist
  Future<void> addVideoToPlaylist(
    String playlistId,
    String videoId,
    bool isPublic,
  ) async {
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc(playlistId);

      final snapshot = await ref.get();
      if (!snapshot.exists) throw "Playlist not found";

      final itemDoc = await ref.collection('items').doc(videoId).get();
      if (!itemDoc.exists) {
        // Write to subcollection
        await ref.collection('items').doc(videoId).set({
          'videoId': videoId,
          'addedAt': FieldValue.serverTimestamp(),
          'position': (snapshot.data()?['videoCount'] ?? 0),
        });

        // Update parent doc
        final currentVideoIds = List<String>.from(snapshot.data()?['videoIds'] ?? []);
        if (!currentVideoIds.contains(videoId)) {
          currentVideoIds.add(videoId);
        }
        final cappedVideoIds = currentVideoIds.take(10).toList();

        await ref.update({
          'videoIds': cappedVideoIds,
          'videoCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Always update thumbnail when first video added or if null
        if (currentVideoIds.length == 1 || snapshot.data()?['thumbnailUrl'] == null) {
          await _updateThumbnail(ref, currentVideoIds);
        }

        Get.snackbar(
          "Success",
          "Video added to playlist!",
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          "Warning",
          "Video already in playlist!",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      logger.debug("❌ Error adding video: $e");
      Get.snackbar(
        "Error",
        "Failed to add video!",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Remove video from playlist
  Future<void> removeVideoFromPlaylist(
    String playlistId,
    String videoId,
    bool isPublic,
  ) async {
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc(playlistId);

      final snapshot = await ref.get();
      if (!snapshot.exists) throw "Playlist not found";

      final itemDoc = await ref.collection('items').doc(videoId).get();
      if (itemDoc.exists) {
        // Delete from subcollection
        await ref.collection('items').doc(videoId).delete();

        // Get updated videoIds list for cache. We need to fetch from the subcollection to rebuild the first 10 items!
        final itemsSnap = await ref.collection('items').orderBy('addedAt').limit(10).get();
        final newCachedIds = itemsSnap.docs.map((doc) => doc.id).toList();

        // Calculate new total count
        final currentCount = snapshot.data()?['videoCount'] ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        await ref.update({
          'videoIds': newCachedIds,
          'videoCount': newCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _updateThumbnail(ref, newCachedIds);

        Get.snackbar(
          "Success",
          "Video removed from playlist!",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      logger.debug("❌ Error removing video: $e");
      Get.snackbar(
        "Error",
        "Failed to remove video!",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Delete a specific video from **all playlists** (optional)
  Future<void> deleteVideoFromAllPlaylists(String videoId) async {
    try {
      final userPlaylists = await _firestore
          .collection('users')
          .doc(user)
          .collection('playlists')
          .get();

      for (var doc in userPlaylists.docs) {
        final itemDoc = await doc.reference.collection('items').doc(videoId).get();
        if (itemDoc.exists) {
          await doc.reference.collection('items').doc(videoId).delete();
          final itemsSnap = await doc.reference.collection('items').orderBy('addedAt').limit(10).get();
          final newCachedIds = itemsSnap.docs.map((d) => d.id).toList();
          final currentCount = doc.data()['videoCount'] ?? 0;
          final newCount = currentCount > 0 ? currentCount - 1 : 0;

          await doc.reference.update({
            'videoIds': newCachedIds,
            'videoCount': newCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _updateThumbnail(doc.reference, newCachedIds);
        }
      }

      final publicPlaylists = await _firestore
          .collection('public_playlists')
          .limit(50)
          .get();
      for (var doc in publicPlaylists.docs) {
        final itemDoc = await doc.reference.collection('items').doc(videoId).get();
        if (itemDoc.exists) {
          await doc.reference.collection('items').doc(videoId).delete();
          final itemsSnap = await doc.reference.collection('items').orderBy('addedAt').limit(10).get();
          final newCachedIds = itemsSnap.docs.map((d) => d.id).toList();
          final currentCount = doc.data()['videoCount'] ?? 0;
          final newCount = currentCount > 0 ? currentCount - 1 : 0;

          await doc.reference.update({
            'videoIds': newCachedIds,
            'videoCount': newCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _updateThumbnail(doc.reference, newCachedIds);
        }
      }

      Get.snackbar(
        "Success",
        "Video removed from all playlists!",
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      logger.debug("❌ Error deleting video from playlists: $e");
    }
  }

  // ===================== Fetching =====================

  Stream<List<PlaylistModel>> getPrivatePlaylists() {
    if (user.isEmpty) {
      logger.debug('⚠️ getPrivatePlaylists: No user logged in');
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user)
        .collection('playlists')
        .orderBy('sortIndex')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
          logger.debug('❌ getPrivatePlaylists error: $error');
          return <PlaylistModel>[];
        })
        .map(
          (snap) => snap.docs.map(PlaylistModel.fromDocumentSnapshot).toList(),
        );
  }

  Stream<List<PlaylistModel>> getPublicPlaylists() {
    return _firestore
        .collection('public_playlists')
        .orderBy('sortIndex')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
          logger.debug('❌ getPublicPlaylists error: $error');
          return <PlaylistModel>[];
        })
        .map(
          (snap) => snap.docs.map(PlaylistModel.fromDocumentSnapshot).toList(),
        );
  }

  Future<PlaylistModel> getPlaylist(
    String playlistId, {
    required bool isPublic,
  }) async {
    final doc = isPublic
        ? await _firestore.collection('public_playlists').doc(playlistId).get()
        : await _firestore
              .collection('users')
              .doc(user)
              .collection('playlists')
              .doc(playlistId)
              .get();

    if (!doc.exists) throw Exception("Playlist not found");
    return PlaylistModel.fromDocumentSnapshot(doc);
  }

  Future<List<Video>> fetchVideos(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];
    const int batchSize = 10;
    List<Video> videos = [];

    for (var i = 0; i < videoIds.length; i += batchSize) {
      final batchIds = videoIds.skip(i).take(batchSize).toList();
      final snapshot = await _firestore
          .collection('videos')
          .where('id', whereIn: batchIds)
          .get();
      videos.addAll(snapshot.docs.map(Video.fromDocumentSnapshot));
    }

    final Map<String, Video> videoMap = {for (var v in videos) v.id: v};
    return videoIds
        .map((id) => videoMap[id] ?? _getPlaceholderVideo(id))
        .toList();
  }

  Video _getPlaceholderVideo(String id) {
    return Video(
      id: id,
      title: "Video not found",
      description: "",
      thumbnailUrl: "",
      ownerId: "",
      channelId: "",
      channelName: "",
      category: "",
      tags: [],
    );
  }

  // ===================== Share Playlist =====================
  Future<void> sharePlaylist(String playlistId, {String? name}) async {
    try {
      // Find cached playlist in controller state
      PlaylistModel? playlist;
      try {
        playlist = playlists.firstWhere((p) => p.id == playlistId);
      } catch (_) {}
      if (playlist == null) {
        try {
          playlist = publicPlaylists.firstWhere((p) => p.id == playlistId);
        } catch (_) {}
      }

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
        "❌ Error sharing playlist",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> editPlaylist(
    String playlistId,
    String newName,
    bool isPublic,
  ) async {
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc(playlistId);

      await ref.update({
        'name': newName,
        'playlistName': newName,
        'updatedAt': Timestamp.now(),
      });

      // Refresh the playlists to update UI
      refreshPlaylistsTick();

      Get.snackbar(
        "Success",
        "Playlist renamed successfully!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1DB954).withValues(alpha: 0.8),
        colorText: Colors.white,
        margin: const EdgeInsets.all(20),
        borderRadius: 16,
      );
    } catch (e) {
      logger.debug("❌ Error editing playlist: $e");
      Get.snackbar(
        "Error",
        "Failed to rename playlist!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.8),
        colorText: Colors.white,
        margin: const EdgeInsets.all(20),
        borderRadius: 16,
      );
    }
  }

  // ===================== Update Sort Index =====================

  Future<void> updateSortIndex(
    String playlistId,
    int newIndex,
    bool isPublic,
  ) async {
    try {
      final ref = isPublic
          ? _firestore.collection('public_playlists').doc(playlistId)
          : _firestore
                .collection('users')
                .doc(user)
                .collection('playlists')
                .doc(playlistId);

      await ref.update({'sortIndex': newIndex, 'updatedAt': Timestamp.now()});

      refreshPlaylistsTick();
    } catch (e) {
      logger.debug("❌ Error updating sort index: $e");
    }
  }

  // ===================== Toggle Visibility =====================

  Future<void> togglePlaylistVisibility(
    String playlistId,
    bool currentIsPublic,
  ) async {
    try {
      if (currentIsPublic) {
        final doc = await _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .get();
        final playlist = PlaylistModel.fromDocumentSnapshot(doc);
        await _firestore
            .collection('users')
            .doc(user)
            .collection('playlists')
            .doc(playlistId)
            .set(playlist.toMap()..['isPublic'] = false);
        await _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .delete();
      } else {
        final doc = await _firestore
            .collection('users')
            .doc(user)
            .collection('playlists')
            .doc(playlistId)
            .get();
        final playlist = PlaylistModel.fromDocumentSnapshot(doc);
        await _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .set(playlist.toMap()..['isPublic'] = true);
        await _firestore
            .collection('users')
            .doc(user)
            .collection('playlists')
            .doc(playlistId)
            .delete();
      }
      Get.snackbar(
        "Success",
        "Playlist visibility updated!",
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      logger.debug("❌ Error toggling visibility: $e");
      Get.snackbar(
        "Error",
        "Failed to update visibility!",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ===================== Fetch Channels =====================

  void fetchChannels() {
    // Cancel existing subscription
    _channelsSubscription?.cancel();

    // Guard: Only fetch if authenticated (assuming channels collection is protected)
    if (user.isEmpty) {
      logger.debug('⚠️ fetchChannels: No user logged in, skipping listener');
      return;
    }

    _channelsSubscription = _firestore
        .collection("channels")
        .where('ownerId', isEqualTo: user)
        .snapshots()
        .listen(
          (snapshot) {
            channels.value = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .toList();
            logger.debug('✅ Channels loaded: ${channels.length}');
          },
          onError: (error) {
            if (error.toString().contains('permission-denied')) {
              logger.debug(
                '📋 PlaylistController: Permission denied listening to channels. This is expected if the user has no channel yet.',
              );
            } else {
              logger.debug(
                '❌ PlaylistController: Error listening to channels: $error',
              );
            }
          },
        );
  }

  void fetchPlaylists() {
    // Cancel existing subscription to avoid duplicates
    _playlistsSubscription?.cancel();

    if (user.isEmpty) {
      logger.debug('📋 Cannot fetch playlists: no user logged in');
      return;
    }

    _playlistsSubscription = _firestore
        .collection("users")
        .doc(user)
        .collection('playlists')
        .snapshots()
        .listen(
          (snapshot) {
            final loadedPlaylists = snapshot.docs
                .map((doc) {
                  try {
                    return PlaylistModel.fromDocumentSnapshot(doc);
                  } catch (e) {
                    logger.debug('❌ Error parsing playlist ${doc.id}: $e');
                    return null;
                  }
                })
                .where((p) => p != null)
                .cast<PlaylistModel>()
                .toList();

            playlists.value = loadedPlaylists;
            logger.debug('📋 Loaded ${playlists.length} playlists');
          },
          onError: (error) {
            if (error.toString().contains('permission-denied')) {
              logger.debug(
                '📋 PlaylistController: Permission denied listening to playlists for user $user.',
              );
            } else {
              logger.debug(
                '❌ PlaylistController: Error listening to playlists: $error',
              );
            }
          },
        );
  }

  /// Force refresh playlists by manually fetching and updating
  Future<void> refreshPlaylists() async {
    if (user.isEmpty) {
      logger.debug('📋 Cannot refresh playlists: no user logged in');
      return;
    }

    try {
      final snapshot = await _firestore
          .collection("users")
          .doc(user)
          .collection('playlists')
          .get();

      final loadedPlaylists = snapshot.docs
          .map((doc) {
            try {
              return PlaylistModel.fromDocumentSnapshot(doc);
            } catch (e) {
              logger.debug(
                '❌ Error parsing playlist ${doc.id} during refresh: $e',
              );
              return null;
            }
          })
          .where((p) => p != null)
          .cast<PlaylistModel>()
          .toList();

      playlists.value = loadedPlaylists;
      logger.debug('📋 Force refreshed ${playlists.length} playlists');
    } catch (e) {
      logger.debug('❌ Error force refreshing playlists: $e');
    }
  }

  // ===================== Public Playlists for Upload Screen =====================

  StreamSubscription<QuerySnapshot>? _publicPlaylistsSubscription;

  /// Fetch public playlists for upload screen dropdown
  void fetchPublicPlaylists() {
    // Cancel existing subscription
    _publicPlaylistsSubscription?.cancel();

    // Guard: Only fetch if authenticated
    if (user.isEmpty) {
      logger.debug(
        '⚠️ fetchPublicPlaylists: No user logged in, skipping listener',
      );
      return;
    }

    _publicPlaylistsSubscription = _firestore
        .collection('public_playlists')
        .orderBy('sortIndex')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final loadedPlaylists = snapshot.docs
                .map((doc) {
                  try {
                    return PlaylistModel.fromDocumentSnapshot(doc);
                  } catch (e) {
                    logger.debug(
                      '❌ Error parsing public playlist ${doc.id}: $e',
                    );
                    return null;
                  }
                })
                .where((p) => p != null)
                .cast<PlaylistModel>()
                .toList();

            publicPlaylists.value = loadedPlaylists;
            logger.debug(
              '📋 Loaded ${publicPlaylists.length} public playlists',
            );
          },
          onError: (error) {
            if (error.toString().contains('permission-denied')) {
              logger.debug(
                '❌ Error listening to public playlists: Access denied.',
              );
            } else {
              logger.debug('❌ Error listening to public playlists: $error');
            }
          },
        );
  }

  /// Force refresh public playlists
  Future<void> refreshPublicPlaylists() async {
    try {
      final snapshot = await _firestore
          .collection('public_playlists')
          .orderBy('sortIndex')
          .orderBy('createdAt', descending: true)
          .get();

      final loadedPlaylists = snapshot.docs
          .map((doc) {
            try {
              return PlaylistModel.fromDocumentSnapshot(doc);
            } catch (e) {
              logger.debug('❌ Error parsing public playlist ${doc.id}: $e');
              return null;
            }
          })
          .where((p) => p != null)
          .cast<PlaylistModel>()
          .toList();

      publicPlaylists.value = loadedPlaylists;
      logger.debug(
        '📋 Force refreshed ${publicPlaylists.length} public playlists',
      );
    } catch (e) {
      logger.debug('❌ Error refreshing public playlists: $e');
    }
  }
}




