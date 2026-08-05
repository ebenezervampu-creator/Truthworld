import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class MyVideosController extends BaseController {
  RxString searchQuery = ''.obs;
  RxBool isSearching = false.obs;
  RxBool isSearchExpanded = false.obs;
  RxString sortBy = 'recent'.obs;
  RxBool isAscending = false.obs;
  RxList<Video> videos = <Video>[].obs;
  RxBool rxIsLoading = true.obs;
  RxString rxErrorMessage = ''.obs;
  RxString selectedCategory = 'All'.obs;

  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _listenToVideos();
  }

  void _listenToVideos() {
    rxIsLoading.value = true;
    rxErrorMessage.value = '';

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      rxErrorMessage.value = 'User not authenticated';
      rxIsLoading.value = false;
      return;
    }

    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .where('ownerId', isEqualTo: currentUser.uid);

    // SERVER-SIDE SORTING: Requires composite indexes (ownerId + field)
    switch (sortBy.value) {
      case 'recent':
        query = query.orderBy('uploadedAt', descending: !isAscending.value);
      case 'views':
        query = query.orderBy('views', descending: !isAscending.value);
      case 'likes':
        query = query.orderBy('likeCount', descending: !isAscending.value);
      case 'title':
        query = query.orderBy('title', descending: !isAscending.value);
    }

    _subscription?.cancel();
    final sub = query.snapshots().listen(
      (snapshot) {
        videos.value = snapshot.docs.map(Video.fromDocumentSnapshot).toList();
        rxIsLoading.value = false;
      },
      onError: (error) {
        rxErrorMessage.value = error.toString();
        rxIsLoading.value = false;
        debugPrint('MyVideos Firestore Error: $error');
      },
    );
    _subscription = sub;
    trackSubscription(sub);
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
    HapticFeedback.lightImpact();
  }

  void setSortBy(String value) {
    if (sortBy.value == value) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = value;
      isAscending.value = false;
    }

    // RE-FETCH with new server-side sorting
    _listenToVideos();
    HapticFeedback.lightImpact();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  void retryFetch() {
    _subscription?.cancel();
    _listenToVideos();
    HapticFeedback.mediumImpact();
  }

  Future<void> toggleVideoVisibility(Video video) async {
    try {
      final newVisibility = video.visibility == 'public' ? 'private' : 'public';
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .update({'visibility': newVisibility});

      Get.snackbar(
        'Success',
        'Video is now ${newVisibility.capitalizeFirst}.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF10B981),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(
          Icons.check_circle_outline,
          color: AppColors.textPrimary,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update video visibility: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline, color: AppColors.textPrimary),
      );
    }
  }

  /// Deletes a video from Firestore.
  Future<void> deleteVideo(Video video) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .delete();
      Get.snackbar(
        'Video Deleted',
        '"${video.title}" was successfully deleted.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF6366F1),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(
          Icons.delete_sweep_rounded,
          color: AppColors.textPrimary,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete video: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline, color: AppColors.textPrimary),
      );
    }
  }

  List<Video> get filteredAndSortedVideos {
    var filtered = videos.toList();

    // Apply search filter (Client-side)
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((video) {
        return video.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.description.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            video.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.tags.any(
              (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()),
            );
      }).toList();
    }

    // Sorting is now handled server-side in _listenToVideos
    return filtered;
  }

  String formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  String formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
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
}
