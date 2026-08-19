import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/watch_later.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchLaterController extends BaseController {
  final RxList<Video> watchLaterVideos = <Video>[].obs;
  final RxBool rxIsLoading = false.obs;

  @override
  bool get isLoading => rxIsLoading.value || state == ViewState.loading;

  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void onInit() {
    super.onInit();
    fetchWatchLaterVideos();
  }

  void fetchWatchLaterVideos() {
    rxIsLoading.value = true;
    setViewState(ViewState.loading);

    final userId = AuthService.to.uid.isNotEmpty
        ? AuthService.to.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    if (userId.isEmpty) {
      rxIsLoading.value = false;
      watchLaterVideos.clear();
      setViewState(ViewState.empty);
      return;
    }

    _subscription?.cancel();
    final sub = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection('watch_later')
        .snapshots()
        .listen(
      (snapshot) async {
        if (snapshot.docs.isEmpty) {
          watchLaterVideos.value = [];
          rxIsLoading.value = false;
          setViewState(ViewState.empty);
          return;
        }

        try {
          final parsedVideos = <Video>[];
          final missingVideoIds = <String>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final docId = doc.id;
            final videoId = data['videoId'] as String? ?? docId;

            if (data.containsKey('title') && data.containsKey('videoUrl')) {
              parsedVideos.add(Video.fromDocumentSnapshot(doc));
            } else if (data.containsKey('videoTitle')) {
              final wl = WatchLater.fromDocumentSnapshot(doc);
              parsedVideos.add(
                Video(
                  id: wl.videoId.isNotEmpty ? wl.videoId : wl.id,
                  title: wl.videoTitle,
                  description: '',
                  thumbnailUrl: wl.videoThumbnailUrl,
                  ownerId: wl.userId,
                  channelId: wl.channelId,
                  channelName: wl.channelName,
                  channelAvatarUrl: wl.channelImage,
                  category: 'General',
                  tags: const [],
                  viewCount: wl.views,
                  duration: wl.duration,
                  uploadedAt: wl.uploadedAt,
                ),
              );
            } else {
              missingVideoIds.add(videoId);
            }
          }

          if (missingVideoIds.isNotEmpty) {
            final fetchedVideos = await _fetchVideosInBatches(missingVideoIds);
            parsedVideos.addAll(fetchedVideos);
          }

          final videoMap = {for (final v in parsedVideos) v.id: v};
          final ordered = <Video>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final docId = doc.id;
            final vId = data['videoId'] as String? ?? docId;
            if (videoMap.containsKey(vId)) {
              ordered.add(videoMap[vId]!);
            } else if (videoMap.containsKey(docId)) {
              ordered.add(videoMap[docId]!);
            }
          }

          watchLaterVideos.value = ordered;
          rxIsLoading.value = false;
          setViewState(
            watchLaterVideos.isEmpty ? ViewState.empty : ViewState.success,
          );
        } catch (e) {
          logException(e);
          rxIsLoading.value = false;
          setViewState(ViewState.error);
        }
      },
      onError: (error) {
        logException(error);
        rxIsLoading.value = false;
        setViewState(ViewState.error);
        showError('Error fetching Watch Later videos: $error');
      },
    );

    _subscription = sub;
    trackSubscription(sub);
  }

  Future<List<Video>> _fetchVideosInBatches(List<String> videoIds) async {
    const batchSize = 10;
    final allVideos = <Video>[];

    for (var i = 0; i < videoIds.length; i += batchSize) {
      final batch = videoIds.sublist(
        i,
        i + batchSize > videoIds.length ? videoIds.length : i + batchSize,
      );

      final batchDocs = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allVideos.addAll(
        batchDocs.docs.map(Video.fromDocumentSnapshot),
      );
    }

    return allVideos;
  }

  Future<void> removeFromWatchLater(String videoId) async {
    final userId = AuthService.to.uid.isNotEmpty
        ? AuthService.to.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    if (userId.isEmpty) return;

    try {
      final watchLaterRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_later');

      final docRef = watchLaterRef.doc(videoId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
      } else {
        final querySnap = await watchLaterRef
            .where('videoId', isEqualTo: videoId)
            .get();
        for (final doc in querySnap.docs) {
          await doc.reference.delete();
        }
      }

      watchLaterVideos.removeWhere((v) => v.id == videoId);

      Get.snackbar(
        'Removed',
        'Video removed from Watch Later.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.colors.surface,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(
          Icons.watch_later_outlined,
          color: AppColors.textPrimary,
        ),
      );
    } catch (e) {
      logException(e);
      showError('Failed to remove video: $e');
    }
  }

  Future<void> clearAll() async {
    final userId = AuthService.to.uid.isNotEmpty
        ? AuthService.to.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    if (userId.isEmpty) return;

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.colors.surface,
        title: const Text(
          'Clear Watch Later?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove all videos from your Watch Later list.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                final collection = FirebaseFirestore.instance
                    .collection(FirestoreCollections.users)
                    .doc(userId)
                    .collection('watch_later');

                final snapshots = await collection.get();
                final batch = FirebaseFirestore.instance.batch();
                for (final doc in snapshots.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();
                watchLaterVideos.clear();
                setViewState(ViewState.empty);

                Get.snackbar(
                  'Cleared',
                  'Watch Later list cleared.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.colors.surface,
                  colorText: AppColors.textPrimary,
                  margin: const EdgeInsets.all(16),
                  borderRadius: 12,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.textPrimary,
                  ),
                );
              } catch (e) {
                logException(e);
                showError('Failed to clear Watch Later: $e');
              }
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  List<Video> get filteredVideos {
    if (searchQuery.value.trim().isEmpty) {
      return watchLaterVideos;
    }
    final q = searchQuery.value.trim().toLowerCase();
    return watchLaterVideos.where((video) {
      return video.title.toLowerCase().contains(q) ||
          video.channelName.toLowerCase().contains(q) ||
          video.category.toLowerCase().contains(q);
    }).toList();
  }

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
  }

  void playAll() {
    if (watchLaterVideos.isNotEmpty) {
      Get.toNamed(
        '/videoscreen',
        arguments: {'video': watchLaterVideos.first},
      );
    }
  }
}
