import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';

import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';

class UserNotificationController extends BaseController {
  final UserNotificationService _service = UserNotificationService();

  RxList<UserNotification> notifications = <UserNotification>[].obs;
  RxBool rxIsLoading = true.obs;
  RxString selectedSeverityFilter = 'all'.obs;
  RxString selectedTypeFilter = 'all'.obs;
  RxString searchQuery = ''.obs;
  RxBool isSearching = false.obs;

  StreamSubscription<List<UserNotification>>? _subscription;
  String _currentUserId = '';

  String get userId {
    if (_currentUserId.isNotEmpty) return _currentUserId;
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
  }

  @override
  void onInit() {
    super.onInit();
    _listenToAuthChanges();
  }

  @override
  void onClose() {
    // BaseController.onClose() handles all tracked subscriptions via trackSubscription()
    super.onClose();
  }

  void _listenToAuthChanges() {
    // Track auth subscription for automatic disposal on controller close
    trackSubscription(
      FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          final newUid = user?.uid ?? '';
          if (newUid != _currentUserId) {
            _currentUserId = newUid;
            if (newUid.isEmpty || (user?.isAnonymous ?? false)) {
              _subscription?.cancel();
              _subscription = null;
              notifications.clear();
              rxIsLoading.value = false;
            } else {
              _listenToCloudNotifications();
            }
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UserNotificationController._listenToAuthChanges',
        ),
      ),
    );

    final initialUser = FirebaseAuth.instance.currentUser;
    if (initialUser != null && !initialUser.isAnonymous) {
      _currentUserId = initialUser.uid;
      _listenToCloudNotifications();
    } else {
      rxIsLoading.value = false;
    }
  }

  /// Real-time Firestore stream — notifications appear instantly without refresh
  void _listenToCloudNotifications() {
    _subscription?.cancel();
    final uid = userId;
    if (uid == 'guest_user' || uid.isEmpty) {
      notifications.clear();
      rxIsLoading.value = false;
      return;
    }

    rxIsLoading.value = true;

    // Track subscription for automatic cleanup in BaseController.onClose()
    _subscription = trackSubscription(
      _service
          .getNotificationsStream(uid, limit: 100)
          .listen(
            (list) {
              notifications.value = list;
              rxIsLoading.value = false;
            },
            onError: (e, stackTrace) {
              ErrorHandler.log(
                e,
                stackTrace: stackTrace,
                tag: 'UserNotificationController.getNotificationsStream',
              );
              rxIsLoading.value = false;
              // Fallback to callable on stream error
              _fetchFromCloudFunction();
            },
          ),
    );
  }

  /// Fallback fetch via callable Cloud Function
  Future<void> _fetchFromCloudFunction() async {
    try {
      final list = await _service.fetchNotificationsViaCallable(limit: 100);
      notifications.value = list;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'UserNotificationController.fetchFromCloudFunction',
      );
    } finally {
      rxIsLoading.value = false;
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
