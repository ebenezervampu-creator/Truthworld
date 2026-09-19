import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchHistoryController extends BaseController {
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxString sortBy = 'recent'.obs; // recent, views, likes, title
  final RxBool isAscending = false.obs;
  final RxBool showFab = true.obs;
  final RxInt refreshTrigger = 0.obs;
  final RxBool isHistoryPaused = false.obs;
  final RxString selectedCategory = 'All'.obs;

  final RxList<Video> historyVideos = <Video>[].obs;
  final RxBool rxIsLoading = false.obs;
  final RxString rxErrorMessage = ''.obs;

  Future<void> fetchHistory({bool refresh = false}) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      historyVideos.clear();
      setViewState(ViewState.empty);
      return;
    }

    if (!refresh && historyVideos.isNotEmpty) return;

    rxIsLoading.value = true;
    rxErrorMessage.value = '';
    setViewState(ViewState.loading);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history')
          .orderBy('watchedAt', descending: true)
          .limit(100)
          .get();

      final parsed = snapshot.docs.map((doc) {
        final data = doc.data();
        final durationRaw = (data['duration'] != null &&
                data['duration'] != '0:00' &&
                data['duration'] != '00:00')
            ? data['duration']
            : (data['videoDuration'] ?? data['durationMs']);
        return Video(
          id: (data['videoId'] as String?) ?? doc.id,
          channelId: (data['channelId'] as String?) ?? '',
          channelName: (data['channelName'] as String?) ?? '',
          channelAvatarUrl: (data['channelImage'] as String?) ??
              (data['channelAvatarUrl'] as String?) ??
              '',
          title: (data['title'] as String?) ?? 'Unknown Video',
          description: (data['description'] as String?) ?? '',
          thumbnailUrl: (data['thumbnailUrl'] as String?) ?? '',
          videoUrl: (data['videoUrl'] as String?) ?? '',
          ownerId: (data['ownerId'] as String?) ?? '',
          views: (data['views'] as int?) ?? 0,
          likeCount: (data['likeCount'] as int?) ?? 0,
          duration: durationRaw,
          uploadedAt: (data['watchedAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          language: (data['language'] as String?) ?? 'en',
          category: (data['category'] as String?) ?? 'General',
          tags: List<String>.from(
            (data['tags'] as Iterable<dynamic>?) ?? [],
          ),
          factCheckUrl: (data['factCheckUrl'] as String?) ?? '',
          mediaSubtitles: const {},
          audioTracks: const {},
          chapters: const [],
        );
      }).toList();

      historyVideos.value = parsed;
      rxIsLoading.value = false;
      setViewState(parsed.isEmpty ? ViewState.empty : ViewState.success);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'WatchHistoryController.fetchHistory',
      );
      rxErrorMessage.value = 'Unable to load watch history. Please try again.';
      rxIsLoading.value = false;
      handleError(e);
    }
  }

  void retry() {
    fetchHistory(refresh: true);
    refreshTrigger.value++;
  }

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _loadHistorySettings();
    fetchHistory();
  }

  void _loadHistorySettings() {
    final storage = GetStorage();
    isHistoryPaused.value = storage.read<bool>('watch_history_paused') ?? false;
  }

  void toggleHistoryPaused() {
    isHistoryPaused.value = !isHistoryPaused.value;
    final storage = GetStorage();
    storage.write('watch_history_paused', isHistoryPaused.value);
    if (isHistoryPaused.value) {
      AppSnackbar.info(
        'Your viewing history will no longer be saved.',
        title: 'History Paused',
      );
    } else {
      AppSnackbar.success(
        'Your viewing history will now be saved.',
        title: 'History Resumed',
      );
    }
  }

  Future<void> deleteHistoryItem(String videoId) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return;

    historyVideos.removeWhere((v) => v.id == videoId);

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history')
          .doc(videoId)
          .delete();

      AppSnackbar.success('Video removed from watch history');
    } catch (e) {
      ErrorHandler.log(e, context: 'WatchHistoryController.removeItem');
      AppSnackbar.error('Unable to remove video from history. Please try again.');
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
              historyVideos.clear();
              try {
                final collection = FirebaseFirestore.instance
                    .collection(FirestoreCollections.users)
                    .doc(userId)
                    .collection('watch_history');

                // Delete in safe chunks of 450 to respect Firestore 500 operations per batch limit
                while (true) {
                  final snapshots = await collection.limit(450).get();
                  if (snapshots.docs.isEmpty) break;
                  final batch = FirebaseFirestore.instance.batch();
                  for (final doc in snapshots.docs) {
                    batch.delete(doc.reference);
                  }
                  await batch.commit();
                  if (snapshots.docs.length < 450) break;
                }
                AppSnackbar.success('Watch history cleared');
              } catch (e) {
                ErrorHandler.log(e, context: 'WatchHistoryController.clearAllHistory');
                AppSnackbar.error('Unable to clear watch history. Please try again.');
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
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('watch_history');

      var deletedCount = 0;
      while (true) {
        final snapshots = await collection
            .where('watchedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('watchedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .limit(450)
            .get();

        if (snapshots.docs.isEmpty) {
          if (deletedCount == 0) {
            setViewState(ViewState.idle);
            AppSnackbar.info('No history found for $label');
            return;
          }
          break;
        }

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        deletedCount += snapshots.docs.length;
        if (snapshots.docs.length < 450) break;
      }

      setViewState(ViewState.idle);
      AppSnackbar.success('Cleared history for $label');
    } catch (e) {
      setViewState(ViewState.idle);
      ErrorHandler.log(e, context: 'WatchHistoryController.deleteHistoryRange');
      AppSnackbar.error('Unable to clear history. Please try again.');
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
    final todayYear = now.year;
    final todayMonth = now.month;
    final todayDay = now.day;

    final yesterday = DateTime(todayYear, todayMonth, todayDay).subtract(const Duration(days: 1));
    final yesterdayYear = yesterday.year;
    final yesterdayMonth = yesterday.month;
    final yesterdayDay = yesterday.day;

    for (final video in videos) {
      final uploadDate = video.uploadedAt.toDate();
      final uYear = uploadDate.year;
      final uMonth = uploadDate.month;
      final uDay = uploadDate.day;

      final String key;
      if (uYear == todayYear && uMonth == todayMonth && uDay == todayDay) {
        key = 'Today';
      } else if (uYear == yesterdayYear && uMonth == yesterdayMonth && uDay == yesterdayDay) {
        key = 'Yesterday';
      } else {
        key = '$uDay ${_getMonthName(uMonth)} $uYear';
      }

      groups.putIfAbsent(key, () => <Video>[]).add(video);
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
