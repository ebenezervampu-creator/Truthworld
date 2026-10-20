import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_models.dart';

/// Screen-level controller managing UI tabs, scrolling, search, and unified notification aggregation.
class NotificationViewController extends BaseController {
  final VideoFeedNotificationController feedController =
      Get.isRegistered<VideoFeedNotificationController>()
          ? Get.find<VideoFeedNotificationController>()
          : Get.put(VideoFeedNotificationController());

  final UserNotificationController userNotificationController =
      Get.isRegistered<UserNotificationController>()
          ? Get.find<UserNotificationController>()
          : Get.put(UserNotificationController());

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxInt selectedTabIndex = 0.obs;
  final RxBool showScrollToTop = false.obs;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final shouldShow = scrollController.offset > 400;
    if (showScrollToTop.value != shouldShow) {
      showScrollToTop.value = shouldShow;
    }
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    searchController.dispose();
    super.onClose();
  }

  void selectTab(int index) {
    if (selectedTabIndex.value != index) {
      selectedTabIndex.value = index;
      HapticFeedback.selectionClick();
    }
  }

  void toggleSearching() {
    feedController.toggleSearching();
    if (!feedController.isSearching.value) {
      searchController.clear();
    }
  }

  void onSearchChanged(String value) {
    feedController.searchQuery.value = value;
    userNotificationController.searchQuery.value = value;
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      HapticFeedback.lightImpact();
    }
  }

  List<UnifiedNotificationItem> getUnifiedNotificationsForTab() {
    final items = <UnifiedNotificationItem>[];
    final activeTab = selectedTabIndex.value;
    final query = feedController.searchQuery.value.trim().toLowerCase();

    // 1. Video upload notifications (only for "All" tab)
    if (activeTab == 0) {
      for (final v in feedController.notifications) {
        if (query.isNotEmpty) {
          final titleMatch = v.title.toLowerCase().contains(query);
          final channelMatch = v.channelName.toLowerCase().contains(query);
          if (!titleMatch && !channelMatch) continue;
        }
        items.add(
          UnifiedNotificationItem(
            video: v,
            timestamp: v.uploadedAt.toDate(),
            isSeen: v.isSeen,
          ),
        );
      }
    }

    // 2. User notifications based on tab (Strictly excluding Studio notifications in Consumer App)
    for (final n in userNotificationController.notifications) {
      if (n.isStudioNotification || !n.isConsumerNotification) continue;

      final typeLower = n.type.toLowerCase();
      final isMention = typeLower == 'mention';

      var belongsToTab = false;
      if (activeTab == 0) {
        belongsToTab = true;
      } else if (activeTab == 1) {
        belongsToTab =
            typeLower == 'new_video_topic' || typeLower.contains('topic');
      } else if (activeTab == 2) {
        belongsToTab = !isMention &&
            (typeLower.contains('comment') ||
                typeLower.contains('reply') ||
                typeLower.contains('like') ||
                n.typeCategory == 'social');
      } else if (activeTab == 3) {
        belongsToTab = isMention;
      }

      if (!belongsToTab) continue;

      if (query.isNotEmpty) {
        final titleMatch = n.title.toLowerCase().contains(query);
        final messageMatch = n.message.toLowerCase().contains(query);
        if (!titleMatch && !messageMatch) continue;
      }

      items.add(
        UnifiedNotificationItem(
          alert: n,
          timestamp: n.createdAt,
          isSeen: n.read,
        ),
      );
    }

    // Sort by timestamp descending
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  void markAllActiveTabAsRead() {
    final items = getUnifiedNotificationsForTab();
    final unreadItems = items.where((item) => !item.isSeen).toList();

    if (unreadItems.isEmpty) return;

    final hasUnreadVideos = unreadItems.any((item) => item.video != null);
    final hasUnreadAlerts = unreadItems.any((item) => item.alert != null);

    if (hasUnreadVideos) {
      feedController.markAllAsSeen();
    }
    if (hasUnreadAlerts) {
      userNotificationController.markAllAsRead();
    }

    AppSnackbar.info(
      'Marked active notifications as read',
      title: 'Notifications updated',
    );
  }
}
