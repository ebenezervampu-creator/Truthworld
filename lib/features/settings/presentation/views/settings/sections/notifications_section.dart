import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class NotificationsSection extends StatelessWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Notifications',
      children: [
        _buildPushNotificationTile(context),
        _buildChannelAlertsTile(context),
      ],
    );
  }

  Widget _buildPushNotificationTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.notifications_active_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Push Notifications',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Master switch for all push alerts',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.pushNotificationsEnabled.value,
        onChanged: ctrl.togglePushNotifications,
      ),
    );
  }

  Widget _buildChannelAlertsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.subscriptions_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Subscription & Channel Alerts',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Level: ${ctrl.channelAlerts.value}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showChannelAlertsDialog(context),
      ),
    );
  }

  void _showChannelAlertsDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Channel Notification Alerts',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['All', 'Personalized', 'None']
              .map(
                (opt) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      opt,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: opt,
                    groupValue: ctrl.channelAlerts.value,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setChannelAlerts(val);
                        Get.back();
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ================= 6. PRIVACY & HISTORY TILES =================


}
