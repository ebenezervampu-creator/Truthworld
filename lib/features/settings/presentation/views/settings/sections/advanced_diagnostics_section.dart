import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdvancedDiagnosticsSection extends StatelessWidget {
  const AdvancedDiagnosticsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Advanced & Diagnostics',
      children: [
        _buildResetSettingsTile(context),
      ],
    );
  }

  Widget _buildResetSettingsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return ListTile(
      leading: const Icon(Icons.restart_alt_outlined, color: Colors.white),
      title: const Text(
        'Reset Settings to Defaults',
        style: TextStyle(fontSize: 16, color: AppColors.error),
      ),
      subtitle: Text(
        'Reset playback, downloads, digital wellbeing or factory reset',
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white),
      onTap: () => _showResetOptionsDialog(context, ctrl),
    );
  }

  void _showResetOptionsDialog(
    BuildContext context,
    UserSettingsController ctrl,
  ) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Reset Settings Options',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Reset Digital Wellbeing',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetWellbeing();
                Get.back();
                AppSnackbar.info(
                  'Digital wellbeing settings restored.',
                  title: 'Wellbeing Reset',
                );
              },
            ),
            ListTile(
              title: const Text(
                'Reset Playback Settings',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetPlayback();
                Get.back();
                AppSnackbar.info(
                  'Playback preferences restored.',
                  title: 'Playback Reset',
                );
              },
            ),
            ListTile(
              title: const Text(
                'Reset Download Preferences',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetDownloads();
                Get.back();
                AppSnackbar.info(
                  'Download settings restored.',
                  title: 'Downloads Reset',
                );
              },
            ),
            ListTile(
              title: const Text(
                'Reset Accessibility Options',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                ctrl.resetAccessibility();
                Get.back();
                AppSnackbar.info(
                  'Accessibility settings restored.',
                  title: 'Accessibility Reset',
                );
              },
            ),
            const Divider(color: AppColors.bgDivider),
            ListTile(
              title: const Text(
                'Factory Reset ALL Settings',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                ctrl.resetAllSettings();
                Get.back();
                AppSnackbar.warning(
                  'All settings restored to default values.',
                  title: 'Factory Reset Complete',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= 9. LEGAL & ABOUT TILES =================


}
