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
            _syncWatchLaterVideos(snapshot.docs);
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

  Future<void> _syncWatchLaterVideos(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) {
      watchLaterVideoIds.clear();
      firstVideoThumbnail.value = '';
      return;
    }

    final candidateIds = <String>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final vid = (data?['videoId'] as String?)?.trim();
      final id = (vid != null && vid.isNotEmpty) ? vid : doc.id.trim();
      if (id.isNotEmpty && !candidateIds.contains(id)) {
        candidateIds.add(id);
      }
    }

    if (candidateIds.isEmpty) {
      watchLaterVideoIds.clear();
      firstVideoThumbnail.value = '';
      return;
    }

    // Initial update from candidate documents
    watchLaterVideoIds.value = candidateIds;

    try {
      const batchSize = 10;
      final batches = <List<String>>[];
      for (var i = 0; i < candidateIds.length; i += batchSize) {
        batches.add(candidateIds.skip(i).take(batchSize).toList());
      }

      final snapshots = await Future.wait(
        batches.map(
          (batch) => _firestore
              .collection(FirestoreCollections.videos)
              .where(FieldPath.documentId, whereIn: batch)
              .get(),
        ),
      );

      final validVideoMap = <String, Map<String, dynamic>>{};
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final status = (data['status'] as String?)?.toLowerCase();
          if (status == null ||
              status == 'active' ||
              status == 'ready' ||
              status == 'processed') {
            validVideoMap[doc.id] = data;
          }
        }
      }

      final validIds = candidateIds.where(validVideoMap.containsKey).toList();

      var thumb = '';
      for (final id in validIds) {
        final t = (validVideoMap[id]?['thumbnailUrl'] as String?)?.trim() ?? '';
        if (t.isNotEmpty) {
          thumb = t;
          break;
        }
      }

      if (validIds.isNotEmpty) {
        watchLaterVideoIds.value = validIds;
        if (thumb.isNotEmpty) {
          firstVideoThumbnail.value = thumb;
        }
      } else if (candidateIds.isNotEmpty) {
        // Fallback for single doc query or offline cache
        await _fetchFirstThumbnail(candidateIds.first);
      } else {
        firstVideoThumbnail.value = '';
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PlaylistWatchLaterManager._syncWatchLaterVideos',
      );
      if (candidateIds.isNotEmpty && firstVideoThumbnail.value.isEmpty) {
        await _fetchFirstThumbnail(candidateIds.first);
      }
    }
  }

  Future<void> _fetchFirstThumbnail(String videoId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();
      if (doc.exists) {
        final t = (doc.data()?['thumbnailUrl'] as String?)?.trim() ?? '';
        if (t.isNotEmpty) {
          firstVideoThumbnail.value = t;
        }
      }
    } catch (_) {}
  }

  void setFirstThumbnail(String url) {
    if (url.trim().isNotEmpty && firstVideoThumbnail.value != url.trim()) {
      firstVideoThumbnail.value = url.trim();
    }
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

  Future<bool> clearWatchLater() async {
    final user = getUserId();
    if (user.isEmpty) {
      AppSnackbar.warning('Please sign in to update Watch Later.');
      return false;
    }

    try {
      _rxIsLoading.value = true;
      final collection = _firestore
          .collection(FirestoreCollections.users)
          .doc(user)
          .collection('watch_later');

      while (true) {
        final snapshots = await collection.limit(450).get();
        if (snapshots.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshots.docs.length < 450) break;
      }

      watchLaterVideoIds.clear();
      firstVideoThumbnail.value = '';
      AppSnackbar.success('Watch Later list cleared.');
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'PlaylistWatchLaterManager.clearWatchLater',
      );
      AppSnackbar.error('Unable to clear Watch Later. Please try again.');
      return false;
    } finally {
      _rxIsLoading.value = false;
    }
  }

  void dispose() {
    _watchLaterSub?.cancel();
  }
}
