import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/dashboard_components/admin_notifications_modal.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive notification bell with real-time unread badge for TruthWorld Admin Console.
/// Displays unread admin moderation/alert count and opens the Admin Notifications Modal on tap.
class AdminNotificationBell extends StatelessWidget {
  const AdminNotificationBell({
    required this.controller,
    super.key,
  });

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    final notifCtrl = Get.isRegistered<UserNotificationController>()
        ? Get.find<UserNotificationController>()
        : Get.put(UserNotificationController(), permanent: true);

    return Obx(() {
      final count = notifCtrl.adminNotifications.where((n) => !n.read).length;

      return IconButton(
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.error,
          child: Icon(
            count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        onPressed: () {
          AdminNotificationsModal.show(context, controller: controller);
        },
        tooltip: 'Admin Moderation Alerts',
      );
    });
  }
}
