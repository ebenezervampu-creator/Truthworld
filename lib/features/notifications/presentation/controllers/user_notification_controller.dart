import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';

class UserNotificationController extends GetxController {
  final UserNotificationService _service = UserNotificationService();
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';

  RxList<UserNotification> notifications = <UserNotification>[].obs;
  RxBool isLoading = true.obs;
  RxString selectedSeverityFilter = 'all'.obs;
  RxString selectedTypeFilter = 'all'.obs;
  RxString searchQuery = ''.obs;
  RxBool isSearching = false.obs;

  StreamSubscription<List<UserNotification>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _listenToCloudNotifications();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  /// Real-time Firestore stream — notifications appear instantly without refresh
  void _listenToCloudNotifications() {
    isLoading.value = true;

    _subscription = _service
        .getNotificationsStream(userId, limit: 100)
        .listen(
          (list) {
            notifications.value = list;
            isLoading.value = false;
          },
          onError: (e) {
            debugPrint('Error in real-time cloud notifications stream: $e');
            isLoading.value = false;
            // Fallback to callable on stream error
            _fetchFromCloudFunction();
          },
        );
  }

  /// Fallback fetch via callable Cloud Function
  Future<void> _fetchFromCloudFunction() async {
    try {
      final list = await _service.fetchNotificationsViaCallable(limit: 100);
      notifications.value = list;
    } catch (e) {
      debugPrint('Error fetching cloud notifications via Cloud Function: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void setSeverityFilter(String severity) {
    selectedSeverityFilter.value = severity;
    HapticFeedback.selectionClick();
  }

  void setTypeFilter(String typeFilter) {
    selectedTypeFilter.value = typeFilter;
    HapticFeedback.selectionClick();
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
  }

  Future<void> markAsRead(String notificationId) async {
    // Optimistic update first
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      notifications[index].read = true;
      notifications.refresh();
    }
    await _service.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    final unreadIds = notifications
        .where((n) => !n.read)
        .map((n) => n.id)
        .toList();
    if (unreadIds.isEmpty) return;

    // Optimistic update
    for (final n in notifications) {
      n.read = true;
    }
    notifications.refresh();
    HapticFeedback.mediumImpact();

    await _service.markAllAsReadBatch(userId, unreadIds);
  }

  Future<void> refreshNotifications() async {
    // Cancel existing subscription and re-listen for fresh data
    _subscription?.cancel();
    _listenToCloudNotifications();
  }

  List<UserNotification> get filteredNotifications {
    var filtered = notifications.toList();

    // Search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.message.toLowerCase().contains(query);
      }).toList();
    }

    // Apply severity filter
    if (selectedSeverityFilter.value != 'all') {
      filtered = filtered
          .where(
            (n) =>
                n.severity.name.toLowerCase() ==
                selectedSeverityFilter.value.toLowerCase(),
          )
          .toList();
    }

    // Apply type category filter
    if (selectedTypeFilter.value != 'all') {
      filtered = filtered
          .where((n) => n.typeCategory == selectedTypeFilter.value)
          .toList();
    }

    return filtered;
  }

  int get unreadCount => notifications.where((n) => !n.read).length;
}
