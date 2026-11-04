import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/notifications/presentation/controllers/notification_view_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_components.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/notifications/presentation/controllers/notification_view_controller.dart';
export 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_components.dart';

/// Backward-compatible alias for UnifiedNotificationItem
typedef UnifiedNotification = UnifiedNotificationItem;

// ==========================================================================
// VIDEO FEED NOTIFICATION SCREEN
// ==========================================================================

/// Declarative, responsive notification center consolidating video uploads
/// and social user interactions (mentions, comments, likes, subscriptions).
class VideoFeedNotificationScreen extends StatelessWidget {
  const VideoFeedNotificationScreen({
    this.channelId,
    this.creatorId,
    super.key,
  });

  final String? channelId;
  final String? creatorId;

  double get maxContentWidth => 720;

  NotificationViewController _resolveController() {
    return Get.isRegistered<NotificationViewController>()
        ? Get.find<NotificationViewController>()
        : Get.put(NotificationViewController());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _resolveController();
    var resolvedChId = channelId ?? '';
    var resolvedCrId = creatorId ?? '';

    if (resolvedChId.isEmpty && (AppFlavor.isStudio || Get.currentRoute.contains('studio'))) {
      if (Get.isRegistered<AuthService>()) {
        final ch = AuthService.to.userChannel ?? AuthService.to.rxUserChannel.value;
        if (ch != null && ch.id.isNotEmpty) {
          resolvedChId = ch.id;
          resolvedCrId = AuthService.to.uid;
        }
      }
    }

    if (resolvedChId.isNotEmpty) {
      controller.setChannelContext(
        channelId: resolvedChId,
        creatorId: resolvedCrId,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [
              NotificationAppBar(viewController: controller),
              SliverToBoxAdapter(
                child: NotificationPillTabs(viewController: controller),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              Obx(() {
                if (controller.feedController.rxIsLoading.value ||
                    controller.userNotificationController.rxIsLoading.value) {
                  return const SliverFillRemaining(
                    child: NotificationLoadingState(),
                  );
                }

                if (controller.feedController.errorMessage.isNotEmpty) {
                  return SliverFillRemaining(
                    child: NotificationErrorState(
                      onRetry: () {
                        controller.feedController.refreshNotifications();
                        controller.userNotificationController.refreshNotifications();
                      },
                    ),
                  );
                }

                final items = controller.getUnifiedNotificationsForTab();
                return _buildGroupedNotificationList(controller, items);
              }),
            ],
          ),
        ),
      ),
      floatingActionButton: NotificationFloatingActions(viewController: controller),
    );
  }

  Widget _buildGroupedNotificationList(
    NotificationViewController controller,
    List<UnifiedNotificationItem> items,
  ) {
    if (items.isEmpty) {
      final tabId = controller.activeTabId;
      if (tabId == 'verifications') {
        return const NotificationEmptyVerificationsState();
      }
      if (tabId == 'studio_alerts') {
        return const NotificationEmptyStudioAlertsState();
      }
      if (tabId == 'topics') {
        return const NotificationEmptyTopicsState();
      }
      if (tabId == 'comments') {
        return const NotificationEmptyCommentsState();
      }
      if (tabId == 'mentions') {
        return const NotificationEmptyMentionsState();
      }
      return const NotificationEmptyGeneralState();
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));

    final todayItems = <UnifiedNotificationItem>[];
    final weekItems = <UnifiedNotificationItem>[];
    final olderItems = <UnifiedNotificationItem>[];

    for (final item in items) {
      if (item.timestamp.isAfter(todayStart) ||
          item.timestamp.isAtSameMomentAs(todayStart)) {
        todayItems.add(item);
      } else if (item.timestamp.isAfter(weekStart) ||
          item.timestamp.isAtSameMomentAs(weekStart)) {
        weekItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final listWidgets = <Widget>[];

    if (todayItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('Today'));
      for (final item in todayItems) {
        listWidgets.add(
          CompactNotificationTile(
            item: item,
            viewController: controller,
          ),
        );
      }
    }

    if (weekItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('This week'));
      for (final item in weekItems) {
        listWidgets.add(
          CompactNotificationTile(
            item: item,
            viewController: controller,
          ),
        );
      }
    }

    if (olderItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('Older'));
      for (final item in olderItems) {
        listWidgets.add(
          CompactNotificationTile(
            item: item,
            viewController: controller,
          ),
        );
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => listWidgets[index],
        childCount: listWidgets.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
