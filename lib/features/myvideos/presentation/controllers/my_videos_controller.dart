import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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

  @override
  void onInit() {
    super.onInit();
    fetchVideos();
  }

  Future<void> fetchVideos() async {
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

    try {
      final snapshot = await query.limit(50).getCacheFirst();
      videos.value = snapshot.docs.map(Video.fromDocumentSnapshot).toList();
      rxIsLoading.value = false;
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace: stackTrace,
        tag: 'MyVideosController.fetchVideos',
      );
      rxErrorMessage.value = AppException.from(error, stackTrace).displayMessage;
      rxIsLoading.value = false;
    }
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
    fetchVideos();
    HapticFeedback.lightImpact();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  void retryFetch() {
    fetchVideos();
    HapticFeedback.mediumImpact();
  }

  Future<void> changeVideoVisibility(String videoId, String visibility) async {
    try {
      final normalizedVisibility = visibility.trim().toLowerCase();
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({
        'visibility': normalizedVisibility,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      try {
        await FirebaseFirestore.instance
            .collection('shorts')
            .doc(videoId)
            .update({
          'visibility': normalizedVisibility,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'MyVideosController.updateShortVisibility',
        );
      }

      // Update local state if present
      final index = videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        videos[index] = videos[index].copyWith(visibility: normalizedVisibility);
      }

      String displayName;
      switch (normalizedVisibility) {
        case 'public':
          displayName = 'Public';
        case 'private':
          displayName = 'Private';
        case 'members':
        case 'members_only':
          displayName = 'Members Only';
        case 'subscribers':
        case 'subscribers_only':
          displayName = 'Subscribers Only';
        case 'unlisted':
          displayName = 'Unlisted';
        default:
          displayName = visibility;
      }

      AppSnackbar.success('Video access is now set to "$displayName".');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to update video visibility. Please try again.');
    }
  }

  Future<void> toggleVideoVisibility(Video video) async {
    try {
      final newVisibility = video.visibility == 'public' ? 'private' : 'public';
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .update({'visibility': newVisibility});

      AppSnackbar.success('Video is now ${newVisibility.capitalizeFirst}.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to update video visibility. Please try again.');
    }
  }

  /// Moves a video to Trash (soft delete with 30-day retention grace period).
  Future<void> deleteVideo(Video video) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .update({
        'status': 'deletion_pending',
        'visibility': 'private',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (video.isShort) {
        try {
          await FirebaseFirestore.instance
              .collection('shorts')
              .doc(video.id)
              .update({
            'status': 'deletion_pending',
            'visibility': 'private',
            'deletionRequestedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'MyVideosController.updateShortDeletionPending',
          );
        }
      }

      // Immediately remove from local list for snappy UI
      videos.removeWhere((v) => v.id == video.id);

      AppSnackbar.success('"${video.title}" moved to Trash. It will be retained for 30 days.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to move video to Trash. Please try again.');
    }
  }

  Future<void> _safeDeleteStorageUrl(String urlOrPath) async {
    final clean = urlOrPath.trim();
    if (clean.isEmpty) return;
    try {
      if (clean.startsWith('gs://') || clean.contains('firebasestorage.googleapis.com')) {
        await FirebaseStorage.instance.refFromURL(clean).delete();
      } else if (!clean.startsWith('http://') &&
          !clean.startsWith('https://') &&
          !clean.startsWith('blob:') &&
          !clean.startsWith('assets/')) {
        await FirebaseStorage.instance.ref(clean).delete();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'MyVideosController.safeDeleteStorageUrl',
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
    if (views >= 1000000000) {
      return '${(views / 1000000000).toStringAsFixed(1)}B';
    } else if (views >= 1000000) {
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

  /// Whether current authenticated user has an active channel.
  bool get hasChannel {
    if (!Get.isRegistered<AuthService>()) return false;
    final auth = AuthService.to;
    return auth.hasChannel.value || auth.userChannel != null;
  }

  /// Handles user tapping the upload/add button.
  /// Prevents navigation to the upload screen if user does not have a channel.
  void handleUploadTap() {
    if (Get.isRegistered<AuthService>()) {
      final auth = AuthService.to;
      if (!auth.isAuthenticated.value) {
        AppNavigator.toNamed('/auth');
        return;
      }
      if (!hasChannel) {
        showCreateChannelPrompt();
        return;
      }
    } else if (!hasChannel) {
      showCreateChannelPrompt();
      return;
    }

    AppNavigator.toUpload();
  }

  /// Displays a friendly dialog prompting user to create a channel first.
  void showCreateChannelPrompt() {
    final context = Get.context ?? Get.overlayContext;
    if (context == null) return;

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgPage,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.video_call_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Channel required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'You need a channel to upload videos. Would you like to create one now?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back,
                    child: const Text(
                      'Not now',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      AppNavigator.back();
                      AppNavigator.toChannelWizard();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.bgPage,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Create Channel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
