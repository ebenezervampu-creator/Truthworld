import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/services/auth_service.dart';

class WatchHistoryController extends BaseController {
  final searchQuery = ''.obs;
  final isSearching = false.obs;
  final sortBy = 'recent'.obs; // recent, views, likes, title
  final isAscending = false.obs;
  final showFab = true.obs;
  final refreshTrigger = 0.obs;
  final isHistoryPaused = false.obs;
  final selectedCategory = 'All'.obs;

  void retry() => refreshTrigger.value++;

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _loadHistorySettings();
  }

  void _loadHistorySettings() {
    final storage = GetStorage();
    isHistoryPaused.value = storage.read<bool>('watch_history_paused') ?? false;
  }

  void toggleHistoryPaused() {
    isHistoryPaused.value = !isHistoryPaused.value;
    final storage = GetStorage();
    storage.write('watch_history_paused', isHistoryPaused.value);
    Get.snackbar(
      isHistoryPaused.value ? 'History Paused' : 'History Resumed',
      isHistoryPaused.value 
        ? 'Your viewing history will no longer be saved.' 
        : 'Your viewing history will now be saved.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.colors.surface.withValues(alpha: 0.9),
      colorText: AppTheme.colors.textPrimary,
    );
  }

  Future<void> deleteHistoryItem(String videoId) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('watch_history')
          .doc(videoId)
          .delete();
      
      Get.snackbar(
        'Item Removed',
        'Video removed from watch history',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove item: $e');
    }
  }

  Future<void> clearAllHistory() async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    Get.dialog(
      AlertDialog(
        title: Text('Clear Watch History?'),
        content: Text('This will remove all videos from your viewing history. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                final batch = FirebaseFirestore.instance.batch();
                final collection = FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('watch_history');
                
                final snapshots = await collection.get();
                for (var doc in snapshots.docs) {
                  batch.delete(doc.reference);
                }
                
                await batch.commit();
                Get.snackbar('Success', 'Watch history cleared');
              } catch (e) {
                Get.snackbar('Error', 'Failed to clear history: $e');
              }
            },
            child: Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> deleteLast24Hours() async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

    try {
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('watch_history');
      
      final snapshots = await collection
          .where('watchedAt', isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
          .get();

      if (snapshots.docs.isEmpty) {
        Get.snackbar('History', 'No history found from the last 24 hours');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      Get.snackbar('Success', 'Cleared history from the last 24 hours');
    } catch (e) {
      Get.snackbar('Error', 'Failed to clear recent history: $e');
    }
  }

  void _onScroll() {
    if (scrollController.offset > 100 && showFab.value) {
      showFab.value = false;
    } else if (scrollController.offset <= 100 && !showFab.value) {
      showFab.value = true;
    }
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
    // If sorting by recent and not ascending (default), we keep Firestore's watchedAt order
    if (sortBy.value == 'recent' && !isAscending.value) return;

    switch (sortBy.value) {
      case 'recent':
        // Note: For true 'recent' sort by watchedAt, we'd need that metadata in the Video object 
        // or sort in the StreamBuilder. Since we are sorting the fetched Video list:
        videos.sort(
          (a, b) => isAscending.value
              ? a.uploadedAt.compareTo(b.uploadedAt)
              : b.uploadedAt.compareTo(a.uploadedAt),
        );
        break;
      case 'views':
        videos.sort(
          (a, b) => isAscending.value
              ? a.views.compareTo(b.views)
              : b.views.compareTo(a.views),
        );
        break;
      case 'likes':
        videos.sort(
          (a, b) => isAscending.value
              ? a.likeCount.compareTo(b.likeCount)
              : b.likeCount.compareTo(a.likeCount),
        );
        break;
      case 'title':
        videos.sort(
          (a, b) => isAscending.value
              ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
              : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
    }
  }

  Map<String, List<Video>> groupVideosByDate(List<Video> videos) {
    final Map<String, List<Video>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var video in videos) {
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  void onClose() {
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}





