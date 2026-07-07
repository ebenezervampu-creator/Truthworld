import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';

class DownloadsController extends GetxController {
  var searchQuery = ''.obs;
  var isSearching = false.obs;
  var isSearchExpanded = false.obs;
  var sortBy = 'recent'.obs;
  var isAscending = false.obs;
  var videos = <OfflineVideo>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var selectedCategory = 'All'.obs;
  var isListView = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadVideos();
  }

  Future<void> loadVideos() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await getAllVideosData();
      videos.value = data
          .map((e) => OfflineVideo.fromJson(e['meta'] as Map<String, dynamic>))
          .toList();

      // Sort locally based on downloadedAt
      videos.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    } catch (e) {
      errorMessage.value = e.toString();
    }
    isLoading.value = false;
  }

  Future<void> deleteVideoItem(String id) async {
    await deleteVideo(id);
    await loadVideos();
    Get.snackbar(
      'Deleted',
      'Video removed from downloads.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF6366F1),
      colorText: Colors.white,
    );
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

    if (sortBy.value == 'recent') {
      videos.sort(
        (a, b) => isAscending.value
            ? a.downloadedAt.compareTo(b.downloadedAt)
            : b.downloadedAt.compareTo(a.downloadedAt),
      );
    } else if (sortBy.value == 'title') {
      videos.sort(
        (a, b) => isAscending.value
            ? a.title.compareTo(b.title)
            : b.title.compareTo(a.title),
      );
    }

    HapticFeedback.lightImpact();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.lightImpact();
  }

  void playVideo(OfflineVideo offlineVideo) {
    Get.toNamed(
      '/watch?v=${offlineVideo.id}',
      arguments: {'video': Video.fromOffline(offlineVideo), 'isOffline': true},
    );
  }

  List<OfflineVideo> get filteredVideos {
    var filtered = videos.toList();
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (v) =>
                v.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                v.channelName.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }
    return filtered;
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

  Map<String, List<OfflineVideo>> groupVideosByDate(
    List<OfflineVideo> videosList,
  ) {
    final Map<String, List<OfflineVideo>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var video in videosList) {
      final date = video.downloadedAt;
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




