import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlayerNotificationsDialog {
  const PlayerNotificationsDialog._();

  static void show(
    BuildContext context,
    ChannelSubscriptionController subCtrl,
    String channelId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notification settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final option = subCtrl.notificationOption.value;
              final notificationsEnabled =
                  subCtrl.notificationsEnabled.value;
              final isAll = notificationsEnabled && option == 'all';
              final isPersonalized =
                  notificationsEnabled && option == 'personalized';
              final isNone = !notificationsEnabled || option == 'none';

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_active,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      'All',
                      style: TextStyle(
                        color: isAll ? PT.primary : AppColors.textPrimary,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get all notifications",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isAll
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      subCtrl.updateNotificationPreference(
                        channelId,
                        'all',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      'Personalized',
                      style: TextStyle(
                        color: isPersonalized
                            ? PT.primary
                            : AppColors.textPrimary,
                        fontWeight: isPersonalized
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      "You'll get personalized notifications",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isPersonalized
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      subCtrl.updateNotificationPreference(
                        channelId,
                        'personalized',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_off_outlined,
                      color: AppColors.textPrimary,
                    ),
                    title: Text(
                      'None',
                      style: TextStyle(
                        color: isNone ? PT.primary : AppColors.textPrimary,
                        fontWeight: isNone
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      'Turn off all notifications',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isNone
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      subCtrl.updateNotificationPreference(
                        channelId,
                        'none',
                      );
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
