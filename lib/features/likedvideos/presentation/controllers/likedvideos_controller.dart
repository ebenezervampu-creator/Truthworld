import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class LikedVideosController extends GetxController {
  var searchQuery = ''.obs;
  var isSearching = false.obs;
  var isSearchExpanded = false.obs;
  var sortBy = 'recent'.obs;
  var isAscending = false.obs;
  var videos = <Video>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var selectedCategory = 'All'.obs;
  var isListView = true.obs;

  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _listenToVideos();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToVideos() {
    isLoading.value = true;
    errorMessage.value = '';

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      errorMessage.value = 'User not authenticated';
      isLoading.value = false;
      return;
    }

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('likedVideos')
        .orderBy('timestamp', descending: !isAscending.value)
        .snapshots()
        .listen(
      (snapshot) async {
        if (snapshot.docs.isEmpty) {
          videos.value = [];
          isLoading.value = false;
          return;
        }

        final videoIds = snapshot.docs.map((d) => d.id).toList();
        final videoDocs = await _fetchVideosInBatches(videoIds);
        
        // Re-order to match the liked timestamp order from snapshot
        // Use a map for faster lookup
        final videoMap = {for (var v in videoDocs) v.id: v};
        final orderedVideos = videoIds
            .where((id) => videoMap.containsKey(id))
            .map((id) => videoMap[id]!)
            .toList();

        videos.value = orderedVideos;
        isLoading.value = false;
      },
      onError: (error) {
        errorMessage.value = error.toString();
        isLoading.value = false;
        debugPrint('LikedVideos Firestore Error: $error');
      },
    );
  }

  Future<List<Video>> _fetchVideosInBatches(List<String> videoIds) async {
    const batchSize = 10;
    final List<Video> allVideos = [];

    for (int i = 0; i < videoIds.length; i += batchSize) {
      final batch = videoIds.sublist(
        i,
        i + batchSize > videoIds.length ? videoIds.length : i + batchSize,
      );

      final batchDocs = await FirebaseFirestore.instance
          .collection('videos')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allVideos.addAll(
        batchDocs.docs.map((doc) => Video.fromDocumentSnapshot(doc)),
      );
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

  Future<void> removeFromLikedVideos(String videoId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedVideos')
          .doc(videoId)
          .delete();

      Get.snackbar(
        'Removed',
        'Video removed from Liked Videos.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF6366F1),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.favorite_border, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove from likes: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
    }
  }

  List<Video> get filteredVideos => filteredAndSortedVideos;

  List<Video> get filteredAndSortedVideos {
    var filtered = videos.toList();

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((video) {
        return video.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.category.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

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
    final Map<String, List<Video>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var video in videos) {
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}




