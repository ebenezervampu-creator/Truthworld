import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';

/// Manager handling Watch Later playlist synchronization and video toggling.
class PlaylistWatchLaterManager {
  PlaylistWatchLaterManager({
    required this.getUserId,
    FirebaseFirestore? firestore,
    RxBool? rxIsLoading,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _rxIsLoading = rxIsLoading ?? false.obs;

  final FirebaseFirestore _firestore;
  final String Function() getUserId;
  final RxBool _rxIsLoading;

  final RxList<String> watchLaterVideoIds = <String>[].obs;
  final RxString firstVideoThumbnail = ''.obs;
  StreamSubscription<QuerySnapshot>? _watchLaterSub;

  void listenToWatchLater() {
    _watchLaterSub?.cancel();
    final user = getUserId();
    if (user.isEmpty) {
      watchLaterVideoIds.clear();
      firstVideoThumbnail.value = '';
      return;
    }

    _watchLaterSub = _firestore
        .collection(FirestoreCollections.users)
        .doc(user)
        .collection('watch_later')
        .snapshots()
        .listen(
          (snapshot) {
            watchLaterVideoIds.value =
                snapshot.docs.map((doc) => doc.id).toList();
            if (watchLaterVideoIds.isNotEmpty) {
              _fetchFirstThumbnail(watchLaterVideoIds.first);
            } else {
              firstVideoThumbnail.value = '';
            }
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(
              error,
              stackTrace: stackTrace,
              tag: 'PlaylistWatchLaterManager.listenToWatchLater',
            );
          },
        );
  }

  Future<void> _fetchFirstThumbnail(String videoId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();
      if (doc.exists) {
        firstVideoThumbnail.value = doc.data()?['thumbnailUrl'] ?? '';
      }
    } catch (_) {}
  }

  PlaylistModel? getWatchLaterPlaylist() {
    return PlaylistModel(
      id: 'watchlater',
      playlistName: 'Watch Later',
      videoIds: List<String>.from(watchLaterVideoIds),
      videoCount: watchLaterVideoIds.length,
      thumbnailUrl: firstVideoThumbnail.value,
      isPublic: false,
      ownerId: getUserId(),
      channelId: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<bool> toggleWatchLater(
    String videoId, {
    bool showFeedback = true,
  }) async {
    final user = getUserId();
    if (user.isEmpty) {
      if (showFeedback) {
        AppSnackbar.warning('Please sign in to update Watch Later.');
      }
      return false;
    }

    final isAlreadyIn = watchLaterVideoIds.contains(videoId);
    // Optimistic UI update so button state and counts react immediately
    if (isAlreadyIn) {
      watchLaterVideoIds.remove(videoId);
    } else {
      if (!watchLaterVideoIds.contains(videoId)) {
        watchLaterVideoIds.add(videoId);
      }
    }

    try {
      _rxIsLoading.value = true;
      final ref = _firestore
          .collection(FirestoreCollections.users)
          .doc(user)
          .collection('watch_later')
          .doc(videoId);

      if (isAlreadyIn) {
        await ref.delete().timeout(const Duration(seconds: 8));
        if (showFeedback) {
          AppSnackbar.success('Removed from Watch Later');
        }
      } else {
        final now = FieldValue.serverTimestamp();
        await ref.set({
          'id': videoId,
          'videoId': videoId,
          'userId': user,
          'addedAt': now,
          'createdAt': now,
        }).timeout(const Duration(seconds: 8));
        if (showFeedback) {
          AppSnackbar.success('Saved to Watch Later');
        }
      }
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      if (isAlreadyIn) {
        if (!watchLaterVideoIds.contains(videoId)) {
          watchLaterVideoIds.add(videoId);
        }
      } else {
        watchLaterVideoIds.remove(videoId);
      }
      ErrorHandler.log(e, context: 'PlaylistWatchLaterManager.toggleWatchLater');
      if (showFeedback) {
        AppSnackbar.error('Unable to update Watch Later. Please try again.');
      }
      return false;
    } finally {
      _rxIsLoading.value = false;
    }
  }

  bool isInWatchLater(String videoId) {
    return watchLaterVideoIds.contains(videoId);
  }

  void dispose() {
    _watchLaterSub?.cancel();
  }
}
