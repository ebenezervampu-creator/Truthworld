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
  StreamSubscription<QuerySnapshot>? _watchLaterSub;

  void listenToWatchLater() {
    _watchLaterSub?.cancel();
    final user = getUserId();
    if (user.isEmpty) {
      watchLaterVideoIds.clear();
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

  PlaylistModel? getWatchLaterPlaylist() {
    return PlaylistModel(
      id: 'watchlater',
      playlistName: 'Watch Later',
      videoIds: watchLaterVideoIds,
      isPublic: false,
      ownerId: getUserId(),
      channelId: '',
      createdAt: DateTime.now(),
    );
  }

  Future<void> toggleWatchLater(String videoId) async {
    final user = getUserId();
    if (user.isEmpty) {
      AppSnackbar.warning('Please sign in to update Watch Later.');
      return;
    }

    try {
      _rxIsLoading.value = true;
      final ref = _firestore
          .collection(FirestoreCollections.users)
          .doc(user)
          .collection('watch_later')
          .doc(videoId);

      final isAlreadyIn = watchLaterVideoIds.contains(videoId);
      if (isAlreadyIn) {
        await ref.delete();
        AppSnackbar.success('Removed from Watch Later');
      } else {
        await ref.set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        AppSnackbar.success('Added to Watch Later');
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'PlaylistWatchLaterManager.toggleWatchLater');
      AppSnackbar.error('Unable to update Watch Later. Please try again.');
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
