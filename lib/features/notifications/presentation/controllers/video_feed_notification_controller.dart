import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/notifications/data/services/video_feed_notification_service.dart';

class VideoFeedNotificationController extends GetxController {
  final VideoFeedNotificationService _service = VideoFeedNotificationService();

  var notifications = <Video>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var selectedTimeFilter = 'all'.obs;
  var selectedSeenFilter = 'all'.obs;
  var selectedCategory = 'all'.obs;
  var searchQuery = ''.obs;
  var isSearching = false.obs;

  StreamSubscription<List<Video>>? _subscription;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';

  @override
  void onInit() {
    super.onInit();
    _listenToNotifications();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToNotifications() {
    isLoading.value = true;
    errorMessage.value = '';

    _subscription = _service
        .getVideoNotificationsStream(userId, limit: 100)
        .listen(
          (notificationList) {
            notifications.value = notificationList;
            isLoading.value = false;
          },
          onError: (error) {
            errorMessage.value = error.toString();
            isLoading.value = false;
          },
        );
  }

  void setTimeFilter(String filter) {
    selectedTimeFilter.value = filter;
    HapticFeedback.selectionClick();
  }

  void setSeenFilter(String filter) {
    selectedSeenFilter.value = filter;
    HapticFeedback.selectionClick();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.selectionClick();
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
  }

  Future<void> markVideoAsSeen(String videoId) async {
    await _service.markVideoAsSeen(userId, videoId);
    final index = notifications.indexWhere((n) => n.id == videoId);
    if (index != -1) {
      notifications[index].isSeen = true;
      notifications.refresh();
    }
  }

  Future<void> markAllAsSeen() async {
    try {
      final videoIds = notifications.map((n) => n.id).toList();
      await _service.markAllAsSeen(userId, videoIds);
      for (var notification in notifications) {
        notification.isSeen = true;
      }
      notifications.refresh();
      AppSnackbar.show(
        'Success',
        'All videos marked as seen',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to mark all as seen',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    }
  }

  Future<void> refreshNotifications() async {
    try {
      final fresh = await _service.getVideoNotificationsOnce(userId);
      notifications.value = fresh;
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  List<Video> get filteredNotifications {
    var filtered = notifications.toList();

    // Search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((n) {
        return n.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            n.channelName.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Time filter
    final now = DateTime.now();
    switch (selectedTimeFilter.value) {
      case 'today':
        filtered = filtered.where((n) {
          return n.uploadedAt.toDate().year == now.year &&
              n.uploadedAt.toDate().month == now.month &&
              n.uploadedAt.toDate().day == now.day;
        }).toList();
        break;
      case 'this_week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered
            .where((n) => n.uploadedAt.toDate().isAfter(weekAgo))
            .toList();
        break;
      case 'this_month':
        filtered = filtered.where((n) {
          return n.uploadedAt.toDate().year == now.year &&
              n.uploadedAt.toDate().month == now.month;
        }).toList();
        break;
    }

    // Seen filter
    switch (selectedSeenFilter.value) {
      case 'unseen':
        filtered = filtered.where((n) => !n.isSeen).toList();
        break;
      case 'seen':
        filtered = filtered.where((n) => n.isSeen).toList();
        break;
    }

    // Category filter
    if (selectedCategory.value != 'all') {
      filtered = filtered
          .where((n) => n.category == selectedCategory.value)
          .toList();
    }

    return filtered;
  }

  List<String> get availableCategories {
    final categories = notifications.map((n) => n.category).toSet().toList();
    categories.sort();
    return ['all', ...categories];
  }

  int get unseenCount => notifications.where((n) => !n.isSeen).length;
  int get todayCount {
    final now = DateTime.now();
    return notifications.where((n) {
      final uploadDate = n.uploadedAt.toDate();
      return uploadDate.year == now.year &&
          uploadDate.month == now.month &&
          uploadDate.day == now.day;
    }).length;
  }
}
