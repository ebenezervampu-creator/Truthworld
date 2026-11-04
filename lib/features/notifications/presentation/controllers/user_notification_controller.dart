import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';

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
  final RxString currentChannelId = ''.obs;

  StreamSubscription<List<UserNotification>>? _subscription;
  String _currentUserId = '';

  void setChannelId(String chId) {
    if (currentChannelId.value != chId) {
      currentChannelId.value = chId;
      final uid = userId;
      if (uid.isNotEmpty && uid != 'guest_user') {
        _listenToCloudNotifications();
      }
    }
  }

  String get userId {
    if (_currentUserId.isNotEmpty) return _currentUserId;
    if (Get.isRegistered<AuthService>() && AuthService.to.user != null) {
      return AuthService.to.user!.uid;
    }
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
    final authStream = Get.isRegistered<AuthService>()
        ? AuthService.to.currentUser.stream
        : FirebaseAuth.instance.authStateChanges();

    // Track auth subscription for automatic disposal on controller close
    trackSubscription(
      authStream.listen(
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

    final initialUser = Get.isRegistered<AuthService>()
        ? AuthService.to.user
        : FirebaseAuth.instance.currentUser;
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
          .getNotificationsStream(
            uid,
            channelId: currentChannelId.value.isNotEmpty ? currentChannelId.value : null,
          )
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
      notifications[index] = notifications[index].copyWith(
        read: true,
        status: NotificationLifecycle.read,
      );
      notifications.refresh();
    }
    await _service.markAsRead(notificationId, userId: userId);
  }

  Future<void> deleteNotification(String notificationId) async {
    notifications.removeWhere((n) => n.id == notificationId);
    notifications.refresh();
    await _service.deleteNotification(notificationId, userId: userId);
  }

  Future<void> markAllAsRead() async {
    final List<UserNotification> list;
    if (AppFlavor.isStudio) {
      list = studioNotifications;
    } else if (AppFlavor.isAdvertiser) {
      list = advertiserNotifications;
    } else if (AppFlavor.isAdmin) {
      list = adminNotifications;
    } else {
      list = consumerNotifications;
    }
    final unreadIds = list
        .where((n) => !n.read)
        .map((n) => n.id)
        .toList();
    if (unreadIds.isEmpty) return;

    // Optimistic update
    for (final n in list) {
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

  List<UserNotification> get consumerNotifications =>
      notifications.where((n) => n.isConsumerNotification).toList();

  List<UserNotification> get studioNotifications =>
      notifications.where((n) => n.isStudioNotification).toList();

  List<UserNotification> get advertiserNotifications =>
      notifications.where((n) => n.isAdvertiserNotification).toList();

  List<UserNotification> get adminNotifications =>
      notifications.where((n) => n.isAdminNotification).toList();

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

  int get unreadCount {
    if (AppFlavor.isStudio) {
      return notifications.where((n) => !n.read && n.isStudioNotification).length;
    }
    if (AppFlavor.isAdvertiser) {
      return notifications.where((n) => !n.read && n.isAdvertiserNotification).length;
    }
    if (AppFlavor.isAdmin) {
      return notifications.where((n) => !n.read && n.isAdminNotification).length;
    }
    return notifications.where((n) => !n.read && n.isConsumerNotification).length;
  }
}
