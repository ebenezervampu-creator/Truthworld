import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive modal sheet / dialog presenting all real-time Admin notifications
/// covering moderation queues (videos, images, channels, topics), reports, appeals, security alerts, and system logs.
class AdminNotificationsModal extends StatelessWidget {
  AdminNotificationsModal({
    required this.controller,
    super.key,
  });

  final AdminController controller;

  final RxString _searchQuery = ''.obs;
  final RxString _selectedTab = 'all'.obs;

  static void show(
    BuildContext context, {
    required AdminController controller,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (isDesktop) {
      Get.dialog(
        Dialog(
          backgroundColor: AppColors.bgPage,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.bgSurface),
          ),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 560,
              maxHeight: 720,
            ),
            child: AdminNotificationsModal(controller: controller),
          ),
        ),
      );
    } else {
      Get.bottomSheet(
        SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: AdminNotificationsModal(controller: controller),
          ),
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifCtrl = Get.isRegistered<UserNotificationController>()
        ? Get.find<UserNotificationController>()
        : Get.put(UserNotificationController(), permanent: true);

    return Column(
      children: [
        _buildHeader(context, notifCtrl),
        _buildSearchBar(),
        _buildCategoryFilterPills(),
        const Divider(color: AppColors.bgSurface, height: 1),
        Expanded(
          child: Obx(() {
            final query = _searchQuery.value.trim().toLowerCase();
            final tab = _selectedTab.value;

            var list = notifCtrl.adminNotifications;

            // 1. Tab segment filtering
            if (tab == 'queues') {
              list = list.where((n) {
                final t = n.type.toLowerCase();
                return t.contains('video') ||
                    t.contains('content') ||
                    t.contains('image') ||
                    t.contains('thumbnail') ||
                    t.contains('channel') ||
                    t.contains('topic') ||
                    t.contains('kyc');
              }).toList();
            } else if (tab == 'reports') {
              list = list.where((n) {
                final t = n.type.toLowerCase();
                return t.contains('report');
              }).toList();
            } else if (tab == 'appeals') {
              list = list.where((n) {
                final t = n.type.toLowerCase();
                return t.contains('appeal') || t.contains('dispute');
              }).toList();
            } else if (tab == 'security') {
              list = list.where((n) {
                final t = n.type.toLowerCase();
                return t.contains('security') ||
                    t.contains('alert') ||
                    t.contains('log') ||
                    t.contains('team') ||
                    t.contains('admin_invite');
              }).toList();
            }

            // 2. Keyword search filtering
            if (query.isNotEmpty) {
              list = list.where((n) {
                final matchTitle = n.title.toLowerCase().contains(query);
                final matchBody = n.message.toLowerCase().contains(query);
                final matchType = n.type.toLowerCase().contains(query);
                final matchId = n.id.toLowerCase().contains(query);
                return matchTitle || matchBody || matchType || matchId;
              }).toList();
            }

            if (list.isEmpty) {
              return _buildEmptyState(tab);
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(
                color: AppColors.bgSurface,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = list[index];
                return _buildNotificationTile(context, item, notifCtrl);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, UserNotificationController notifCtrl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.bgSurface),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Moderation Alerts',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Obx(() {
                  final count = notifCtrl.adminNotifications.where((n) => !n.read).length;
                  return Text(
                    count > 0 ? '$count unread moderation alerts' : 'All queues clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: count > 0 ? AppColors.error : AppColors.textSecondary,
                      fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }),
              ],
            ),
          ),
          Obx(() {
            final unread = notifCtrl.adminNotifications.where((n) => !n.read).length;
            if (unread > 0) {
              return TextButton(
                onPressed: () => notifCtrl.markAllAsRead(),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            onPressed: () => Get.back(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: TextField(
          onChanged: (val) => _searchQuery.value = val,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          cursorColor: AppColors.error,
          decoration: InputDecoration(
            hintText: 'Search escalations, reports, appeals...',
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 18),
            suffixIcon: Obx(() {
              if (_searchQuery.value.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 16),
                  onPressed: () => _searchQuery.value = '',
                );
              }
              return const SizedBox.shrink();
            }),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterPills() {
    final tabs = [
      {'id': 'all', 'label': 'All'},
      {'id': 'queues', 'label': 'Queues'},
      {'id': 'reports', 'label': 'Reports'},
      {'id': 'appeals', 'label': 'Appeals'},
      {'id': 'security', 'label': 'Security'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tabs.map((t) {
          final id = t['id']!;
          final label = t['label']!;
          return Obx(() {
            final isSelected = _selectedTab.value == id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _selectedTab.value = id;
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    UserNotification item,
    UserNotificationController notifCtrl,
  ) {
    final iconData = _resolveIcon(item.type);
    final iconColor = _resolveIconColor(item.type);

    return InkWell(
      onTap: () {
        if (!item.read) {
          notifCtrl.markAsRead(item.id);
        }
        Get.back();
        NotificationNavigationHandler.navigateToAlertNotification(item);
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        color: item.read ? Colors.transparent : Colors.white.withValues(alpha: 0.03),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(iconData, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.read ? FontWeight.w500 : FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.read)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        NotificationNavigationHandler.formatNotificationTimestamp(item.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatTypeBadge(item.type),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String tab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.textTertiary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Moderation Alerts',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tab == 'all'
                  ? 'All queues and moderation streams are completely clear.'
                  : 'No alerts found in the selected category.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _resolveIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('video') || t.contains('content') || t == 'moderation_escalation') {
      return Icons.videocam_rounded;
    }
    if (t.contains('report')) {
      return Icons.flag_rounded;
    }
    if (t.contains('channel') || t.contains('kyc')) {
      return Icons.verified_user_rounded;
    }
    if (t.contains('image') || t.contains('thumbnail')) {
      return Icons.image_rounded;
    }
    if (t.contains('topic')) {
      return Icons.tag_rounded;
    }
    if (t.contains('appeal') || t.contains('dispute')) {
      return Icons.gavel_rounded;
    }
    if (t.contains('user')) {
      return Icons.person_rounded;
    }
    if (t.contains('ad')) {
      return Icons.campaign_rounded;
    }
    if (t.contains('security') || t.contains('alert')) {
      return Icons.shield_rounded;
    }
    if (t.contains('log')) {
      return Icons.history_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _resolveIconColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('report') || t.contains('security') || t.contains('escalation')) {
      return AppColors.error;
    }
    if (t.contains('channel') || t.contains('kyc')) {
      return AppColors.success;
    }
    if (t.contains('video') || t.contains('image') || t.contains('content')) {
      return AppColors.warning;
    }
    if (t.contains('appeal') || t.contains('dispute')) {
      return AppColors.info;
    }
    if (t.contains('topic')) {
      return AppColors.info;
    }
    if (t.contains('ad')) {
      return AppColors.info;
    }
    return AppColors.textSecondary;
  }

  String _formatTypeBadge(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
