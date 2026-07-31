import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

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
        title: const Text('Clear Watch History?'),
        content: const Text(
          'This will remove all videos from your viewing history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel'),
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
                for (final doc in snapshots.docs) {
                  batch.delete(doc.reference);
                }

                await batch.commit();
                Get.snackbar('Success', 'Watch history cleared');
              } catch (e) {
                Get.snackbar('Error', 'Failed to clear history: $e');
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

  Future<void> deleteHistoryRange(
    DateTime start,
    DateTime end,
    String label,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    try {
      setViewState(ViewState.loading);
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('watch_history');

      final snapshots = await collection
          .where('watchedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('watchedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (snapshots.docs.isEmpty) {
        setViewState(ViewState.idle);
        Get.snackbar('History', 'No history found for $label');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      setViewState(ViewState.idle);
      Get.snackbar('Success', 'Cleared history for $label');
    } catch (e) {
      setViewState(ViewState.idle);
      Get.snackbar('Error', 'Failed to clear history: $e');
    }
  }

  Future<void> deleteLast24Hours() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 24));
    await deleteHistoryRange(start, now, 'last 24 hours');
  }

  Future<void> deleteToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    await deleteHistoryRange(startOfDay, now, 'today');
  }

  Future<void> deleteYesterday() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final startOfYesterday = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
    );
    final endOfYesterday = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      23,
      59,
      59,
    );
    await deleteHistoryRange(startOfYesterday, endOfYesterday, 'yesterday');
  }

  Future<void> deleteThisWeek() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfFirstDay = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    await deleteHistoryRange(startOfFirstDay, now, 'this week');
  }

  Future<void> deletePreviousWeek() async {
    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfPrevWeek = startOfThisWeek.subtract(const Duration(seconds: 1));
    final startOfPrevWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final startOfPrevWeekDay = DateTime(
      startOfPrevWeek.year,
      startOfPrevWeek.month,
      startOfPrevWeek.day,
    );
    await deleteHistoryRange(
      startOfPrevWeekDay,
      endOfPrevWeek,
      'previous week',
    );
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

  @override
  void onClose() {
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
