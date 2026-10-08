import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/data/services/video_feed_notification_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class VideoFeedNotificationController extends BaseController {
  final VideoFeedNotificationService _service = VideoFeedNotificationService();

  RxList<Video> notifications = <Video>[].obs;
  RxBool rxIsLoading = true.obs;
  RxString rxErrorMessage = ''.obs;
  RxString selectedTimeFilter = 'all'.obs;
  RxString selectedSeenFilter = 'all'.obs;
  RxString selectedCategory = 'all'.obs;
  RxString searchQuery = ''.obs;
  RxBool isSearching = false.obs;

  StreamSubscription<List<Video>>? _subscription;
  StreamSubscription<User?>? _authSubscription;
  String _currentUserId = '';

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
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToAuthChanges() {
    final authStream = Get.isRegistered<AuthService>()
        ? AuthService.to.currentUser.stream
        : FirebaseAuth.instance.authStateChanges();

    _authSubscription = authStream.listen(
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
            _listenToNotifications();
          }
        }
      },
      onError: (e, stackTrace) => ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoFeedNotificationController._listenToAuthChanges',
      ),
    );

    final initialUser = Get.isRegistered<AuthService>()
        ? AuthService.to.user
        : FirebaseAuth.instance.currentUser;
    if (initialUser != null && !initialUser.isAnonymous) {
      _currentUserId = initialUser.uid;
      _listenToNotifications();
    } else {
      rxIsLoading.value = false;
    }
  }

  void _listenToNotifications() {
    _subscription?.cancel();
    final uid = userId;
    if (uid == 'guest_user' || uid.isEmpty) {
      notifications.clear();
      rxIsLoading.value = false;
      return;
    }

    rxIsLoading.value = true;
    rxErrorMessage.value = '';

    _subscription = _service
        .getVideoNotificationsStream(uid, limit: 100)
        .listen(
          (notificationList) {
            notifications.value = notificationList;
            rxIsLoading.value = false;
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(error, stackTrace: stackTrace is StackTrace ? stackTrace : null);
            rxErrorMessage.value = AppException.from(error).displayMessage;
            rxIsLoading.value = false;
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
      for (final notification in notifications) {
        notification.isSeen = true;
      }
      notifications.refresh();
      AppSnackbar.success('All videos marked as seen');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to mark all videos as seen. Please try again.');
    }
  }

  Future<void> refreshNotifications() async {
    try {
      final fresh = await _service.getVideoNotificationsOnce(userId);
      notifications.value = fresh;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace);
      rxErrorMessage.value = AppException.from(e).displayMessage;
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
      case 'this_week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered
            .where((n) => n.uploadedAt.toDate().isAfter(weekAgo))
            .toList();
      case 'this_month':
        filtered = filtered.where((n) {
          return n.uploadedAt.toDate().year == now.year &&
              n.uploadedAt.toDate().month == now.month;
        }).toList();
    }

    // Seen filter
    switch (selectedSeenFilter.value) {
      case 'unseen':
        filtered = filtered.where((n) => !n.isSeen).toList();
      case 'seen':
        filtered = filtered.where((n) => n.isSeen).toList();
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
