import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/repositories/library_repository_impl.dart';
import 'package:truthworld/domain/repositories/library_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class LikedVideosController extends BaseController {
  final LibraryRepository _libraryRepository;

  LikedVideosController({
    LibraryRepository? libraryRepository,
  }) : _libraryRepository = libraryRepository ??
            (Get.isRegistered<LibraryRepository>()
                ? Get.find<LibraryRepository>()
                : LibraryRepositoryImpl());

  RxString searchQuery = ''.obs;
  RxBool isSearching = false.obs;
  RxBool isSearchExpanded = false.obs;
  RxString sortBy = 'recent'.obs;
  RxBool isAscending = false.obs;
  RxList<Video> videos = <Video>[].obs;
  RxBool rxIsLoading = true.obs;
  RxString rxErrorMessage = ''.obs;
  RxString selectedCategory = 'All'.obs;
  RxBool isListView = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchLikedVideos();
  }

  Future<void> fetchLikedVideos() async {
    rxIsLoading.value = true;
    rxErrorMessage.value = '';

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      rxErrorMessage.value = 'User not authenticated';
      rxIsLoading.value = false;
      return;
    }

    try {
      final result = await _libraryRepository.getLikedVideos(currentUser.uid, limit: 50);
      if (result.isFailure) {
        rxErrorMessage.value = result.exceptionOrNull?.displayMessage ?? 'Unable to load liked videos';
        rxIsLoading.value = false;
        return;
      }

      final likedDocs = result.dataOrNull ?? [];
      if (likedDocs.isEmpty) {
        videos.value = [];
        rxIsLoading.value = false;
        return;
      }

      final videoIds = likedDocs.map((d) => d['id'] as String).toList();
      final videoDocs = await _fetchVideosInBatches(videoIds);

      final videoMap = {for (final v in videoDocs) v.id: v};
      final orderedVideos = videoIds
          .where(videoMap.containsKey)
          .map((id) => videoMap[id]!)
          .toList();

      videos.value = orderedVideos;
      rxIsLoading.value = false;
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace: stackTrace,
        tag: 'LikedVideosController.fetchLikedVideos',
      );
      rxErrorMessage.value = AppException.from(error, stackTrace).displayMessage;
      rxIsLoading.value = false;
    }
  }

  Future<List<Video>> _fetchVideosInBatches(List<String> videoIds) async {
    const batchSize = 10;
    final batches = <List<String>>[];

    for (var i = 0; i < videoIds.length; i += batchSize) {
      batches.add(
        videoIds.sublist(
          i,
          i + batchSize > videoIds.length ? videoIds.length : i + batchSize,
        ),
      );
    }

    final results = await Future.wait(
      batches.map(
        (batch) => FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: batch)
            .getCacheFirst(),
      ),
    );

    final allVideos = <Video>[];
    for (final snap in results) {
      allVideos.addAll(snap.docs.map(Video.fromDocumentSnapshot));
    }

    return allVideos;
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

  void toggleView() {
    isListView.value = !isListView.value;
    HapticFeedback.lightImpact();
  }

  void setSortBy(String value) {
    if (sortBy.value == value) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = value;
      isAscending.value = false;
    }

    fetchLikedVideos();
    HapticFeedback.lightImpact();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  void retryFetch() {
    fetchLikedVideos();
    HapticFeedback.mediumImpact();
  }

  Future<void> removeFromLikedVideos(String videoId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      videos.removeWhere((v) => v.id == videoId);

      final result = await _libraryRepository.toggleLikeVideo(currentUser.uid, videoId);
      if (result.isFailure) {
        AppSnackbar.error('Unable to remove video from likes. Please try again.');
        return;
      }

      AppSnackbar.info('Video removed from Liked Videos.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to remove video from likes. Please try again.');
    }
  }

  List<Video> get filteredVideos => filteredAndSortedVideos;

  List<Video> get filteredAndSortedVideos {
    var filtered = videos.toList();

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((video) {
        return video.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.description.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            video.category.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

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
      final date = video.uploadedAt.toDate();
      final dateOnly = DateTime(date.year, date.month, date.day);
      String key;
      if (dateOnly == today) {
        key = 'Today';
      } else if (dateOnly == yesterday) {
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
