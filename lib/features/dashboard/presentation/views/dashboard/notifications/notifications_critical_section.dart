import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/notifications_notification_card.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Sticky urgent notification section grouping all critical policy and moderation alerts.
class ChannelNotificationsCriticalSection extends StatelessWidget {
  const ChannelNotificationsCriticalSection({
    required this.controller,
    required this.channelId,
    super.key,
  });

  final ChannelNotificationsController controller;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final criticalItems = controller.filteredNotifications
        .where((n) => n.priority == NotificationPriority.critical)
        .toList();

    if (criticalItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFF87171),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ACTION REQUIRED',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Color(0xFFF87171),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 12),
          ...criticalItems.map(
            (n) => ChannelNotificationsNotificationCard(
              controller: controller,
              notification: n,
              channelId: channelId,
              isCriticalStyle: true,
            ),
          ),
        ],
      ),
    );
  }
}
