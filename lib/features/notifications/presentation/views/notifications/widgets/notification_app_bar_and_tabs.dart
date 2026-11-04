import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/notifications/presentation/controllers/notification_view_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Sliver app bar featuring reactive search bar, back navigation, and batch mark-as-read menu.
class NotificationAppBar extends StatelessWidget {
  const NotificationAppBar({
    required this.viewController,
    super.key,
  });

  final NotificationViewController viewController;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.bgPage,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: Get.back,
      ),
      title: Obx(
        () => viewController.feedController.isSearching.value
            ? NotificationSearchBar(viewController: viewController)
            : const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
      actions: [
        Obx(
          () => IconButton(
            icon: Icon(
              viewController.feedController.isSearching.value
                  ? Icons.close_rounded
                  : Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: viewController.toggleSearching,
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.textPrimary,
          ),
          onSelected: (value) {
            if (value == 'mark_all_read') {
              viewController.markAllActiveTabAsRead();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_all_read',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Mark all as read',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Integrated search input field in the notification app bar.
class NotificationSearchBar extends StatelessWidget {
  const NotificationSearchBar({
    required this.viewController,
    super.key,
  });

  final NotificationViewController viewController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: viewController.searchController,
      maxLength: ContentValidator.defaultMaxSearchLength,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: TruthworldTextInputFormatters.withLimit(
        ContentValidator.defaultMaxSearchLength,
      ),
      autofocus: true,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: const InputDecoration(
        hintText: 'Search notifications...',
        hintStyle: TextStyle(color: AppColors.textSecondary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: viewController.onSearchChanged,
    );
  }
}

/// Horizontal category tab pills (All, Verifications, Studio Alerts, Topics, Comments, Mentions).
class NotificationPillTabs extends StatelessWidget {
  const NotificationPillTabs({
    required this.viewController,
    super.key,
  });

  final NotificationViewController viewController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Obx(() {
        final tabs = viewController.activeTabs;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            return _buildPillButton(
              title: tabs[index].title,
              index: index,
            );
          },
        );
      }),
    );
  }

  Widget _buildPillButton({required String title, required int index}) {
    return Obx(() {
      final isSelected = viewController.selectedTabIndex.value == index;
      return GestureDetector(
        onTap: () => viewController.selectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textPrimary : const Color(0xFF272727),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
            ),
          ),
        ),
      );
    });
  }
}

/// Floating action button cluster (scroll to top and mark active notifications read).
class NotificationFloatingActions extends StatelessWidget {
  const NotificationFloatingActions({
    required this.viewController,
    super.key,
  });

  final NotificationViewController viewController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = viewController.getUnifiedNotificationsForTab();
      final hasUnread = items.any((item) => !item.isSeen);
      final showScroll = viewController.showScrollToTop.value;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showScroll)
            FloatingActionButton(
              heroTag: 'scroll_top',
              mini: true,
              onPressed: viewController.scrollToTop,
              backgroundColor: AppColors.bgSurface,
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          const SizedBox(height: 12),
          if (hasUnread)
            FloatingActionButton.extended(
              heroTag: 'mark_seen',
              onPressed: () {
                viewController.markAllActiveTabAsRead();
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.done_all_rounded, color: AppColors.bgPage),
              label: const Text(
                'Mark All Read',
                style: TextStyle(
                  color: AppColors.bgPage,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppColors.textPrimary,
              elevation: 8,
            ),
        ],
      );
    });
  }
}
