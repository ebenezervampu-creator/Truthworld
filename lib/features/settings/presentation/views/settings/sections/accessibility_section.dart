import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class AccessibilitySection extends StatelessWidget {
  const AccessibilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Accessibility & Comfort',
      children: [
        _buildReduceMotionTile(context),
        _buildSubtitlesCaptionsTile(context),
        _buildHapticFeedbackTile(context),
        _buildColorBlindTile(context),
      ],
    );
  }

  Widget _buildReduceMotionTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.animation_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Reduce UI Motion & Animations',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Minimize background transitions & motion effects',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.accessibility.value.reduceMotion,
        onChanged: ctrl.toggleReduceMotion,
      ),
    );
  }

  Widget _buildSubtitlesCaptionsTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.closed_caption_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Subtitles & Captions Customization',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Size: ${ctrl.accessibility.value.captionSize} • High Contrast: ${ctrl.accessibility.value.highContrastSubtitles ? "On" : "Off"}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showCaptionsDialog(context),
      ),
    );
  }

  void _showCaptionsDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Captions Customization',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => SwitchListTile(
                title: const Text(
                  'High Contrast Background',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: ctrl.accessibility.value.highContrastSubtitles,
                onChanged: ctrl.toggleHighContrastSubtitles,
              ),
            ),
            ...['Small', 'Medium', 'Large', 'Extra Large'].map(
              (sz) => Obx(
                () => RadioListTile<String>(
                  title: Text(
                    sz,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  value: sz,
                  groupValue: ctrl.accessibility.value.captionSize,
                  onChanged: (val) {
                    if (val != null) ctrl.setCaptionSize(val);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHapticFeedbackTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(
          Icons.vibration_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Haptic Vibration Feedback',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Tactile vibration on player scrubbing & button taps',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        value: ctrl.accessibility.value.hapticFeedback,
        onChanged: ctrl.toggleHapticFeedback,
      ),
    );
  }

  Widget _buildColorBlindTile(BuildContext context) {
    final ctrl = UserSettingsController.to;
    return Obx(
      () => ListTile(
        leading: const Icon(
          Icons.color_lens_outlined,
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Color Blindness Filter Mode',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Filter: ${ctrl.accessibility.value.colorBlindSupport}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        onTap: () => _showColorBlindDialog(context),
      ),
    );
  }

  void _showColorBlindDialog(BuildContext context) {
    final ctrl = UserSettingsController.to;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text(
          'Color Blind Support Mode',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Off', 'Protanopia', 'Deuteranopia', 'Tritanopia']
              .map(
                (mode) => Obx(
                  () => RadioListTile<String>(
                    title: Text(
                      mode,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    value: mode,
                    groupValue: ctrl.accessibility.value.colorBlindSupport,
                    onChanged: (val) {
                      if (val != null) {
                        ctrl.setColorBlindSupport(val);
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

  // ================= 8. ADVANCED & RESET TILES =================


}
