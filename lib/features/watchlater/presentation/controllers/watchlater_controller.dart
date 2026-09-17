import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/watch_later.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchLaterController extends BaseController {
  final RxList<Video> watchLaterVideos = <Video>[].obs;
  final RxBool rxIsLoading = false.obs;

  @override
  bool get isLoading => rxIsLoading.value || state == ViewState.loading;

  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxString selectedCategory = 'All'.obs;
  final RxString sortBy = 'recent'.obs; // recent, views, likes, title
  final RxBool isAscending = false.obs;
  final RxBool showFab = true.obs;

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    fetchWatchLaterVideos();
  }

  void _onScroll() {
    if (scrollController.offset > 100 && showFab.value) {
      showFab.value = false;
    } else if (scrollController.offset <= 100 && !showFab.value) {
      showFab.value = true;
    }
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
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'WatchLaterController.fetchWatchLaterVideos',
          );
          rxIsLoading.value = false;
          setViewState(ViewState.error);
        }
      },
      onError: (error, stackTrace) {
        ErrorHandler.log(
          error,
          stackTrace: stackTrace,
          tag: 'WatchLaterController.fetchWatchLaterVideos',
        );
        rxIsLoading.value = false;
        setViewState(ViewState.error);
        AppSnackbar.error('Unable to load Watch Later videos. Please try again.');
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

      AppSnackbar.success('Video removed from Watch Later.');
    } catch (e) {
      logException(e);
      AppSnackbar.error('Unable to remove video from Watch Later. Please try again.');
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

                AppSnackbar.success('Watch Later list cleared.');
              } catch (e) {
                logException(e);
                AppSnackbar.error('Unable to clear Watch Later. Please try again.');
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
      searchController.clear();
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void setCategory(String category) {
    selectedCategory.value = category;
  }

  void updateSort(String value) {
    if (sortBy.value == value) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = value;
      isAscending.value = false;
    }
  }

  void sortVideos(List<Video> videos) {
    if (sortBy.value == 'recent' && !isAscending.value) return;

    switch (sortBy.value) {
      case 'recent':
        videos.sort(
          (a, b) => isAscending.value
              ? a.uploadedAt.compareTo(b.uploadedAt)
              : b.uploadedAt.compareTo(a.uploadedAt),
        );
      case 'views':
        videos.sort(
          (a, b) => isAscending.value
              ? a.views.compareTo(b.views)
              : b.views.compareTo(a.views),
        );
      case 'likes':
        videos.sort(
          (a, b) => isAscending.value
              ? a.likeCount.compareTo(b.likeCount)
              : b.likeCount.compareTo(a.likeCount),
        );
      case 'title':
        videos.sort(
          (a, b) => isAscending.value
              ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
              : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
    }
  }

  Map<String, List<Video>> groupVideosByDate(List<Video> videos) {
    final groups = <String, List<Video>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final video in videos) {
      final uploadDate = video.uploadedAt.toDate();
      final date = DateTime(uploadDate.year, uploadDate.month, uploadDate.day);
      String key;
      if (date == today) {
        key = 'Today';
      } else if (date == yesterday) {
        key = 'Yesterday';
      } else {
        key = '${date.day} ${_getMonthName(date.month)} ${date.year}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(video);
    }
    return groups;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  void deleteWatchLaterItem(String videoId) => removeFromWatchLater(videoId);

  void clearAllWatchLater() => clearAll();

  void playAll() {
    if (watchLaterVideos.isNotEmpty) {
      MiniplayerNavigationHelper.navigateToVideoScreen(
        video: watchLaterVideos.first,
      );
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
