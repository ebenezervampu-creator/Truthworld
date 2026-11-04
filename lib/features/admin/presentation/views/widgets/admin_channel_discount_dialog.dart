import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for Super Admin to grant or update AI dubbing and subtitles discounts for a particular channel.
/// Supports Free (100%), 50% discount, custom discount %, or reset to standard (0%).
void showAdminChannelDiscountDialog({
  required BuildContext context,
  required AdminController controller,
  required Map<String, dynamic> channel,
}) {
  if (!controller.isSuperAdmin) {
    AppSnackbar.warning('Only Super Admins can configure channel discounts.');
    return;
  }

  final channelId = (channel['id'] ?? channel['channelId'] ?? '').toString();
  final channelName = (channel['name'] ?? channel['channelName'] ?? 'Channel').toString();
  final channelHandle = (channel['handle'] ?? '').toString();

  // Initial values from channel doc
  final currentDubType = (channel['dubbingDiscountType'] ?? 'none').toString();
  final currentDubPercent = (channel['dubbingDiscountPercent'] as num?)?.toDouble() ?? 0.0;
  final currentSubType = (channel['subtitlesDiscountType'] ?? 'none').toString();
  final currentSubPercent = (channel['subtitlesDiscountPercent'] as num?)?.toDouble() ?? 0.0;

  final selectedDubType = currentDubType.obs; // 'none', '50%', 'free', 'custom'
  final customDubPercent = (currentDubPercent > 0 ? currentDubPercent.round() : 25).obs;
  final dubCustomCtrl = TextEditingController(
    text: currentDubPercent > 0 ? currentDubPercent.round().toString() : '25',
  );

  final selectedSubType = currentSubType.obs; // 'none', '50%', 'free', 'custom'
  final customSubPercent = (currentSubPercent > 0 ? currentSubPercent.round() : 25).obs;
  final subCustomCtrl = TextEditingController(
    text: currentSubPercent > 0 ? currentSubPercent.round().toString() : '25',
  );

  final isSaving = false.obs;

  void applyQuickPreset(String mode) {
    if (mode == 'both_free') {
      selectedDubType.value = 'free';
      selectedSubType.value = 'free';
    } else if (mode == 'both_fifty') {
      selectedDubType.value = '50%';
      selectedSubType.value = '50%';
    } else if (mode == 'both_standard') {
      selectedDubType.value = 'none';
      selectedSubType.value = 'none';
    }
  }

  unawaited(
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgPage,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Channel AI Discounts',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'SUPER ADMIN ONLY',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Provide free or discounted dubbing & subtitles for this channel',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel Summary Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_circle_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channelName,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (channelHandle.isNotEmpty)
                              Text(
                                channelHandle,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick presets row
                const Text(
                  'QUICK PRESETS',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetButton(
                      label: 'Both 100% Free',
                      icon: Icons.card_giftcard_rounded,
                      color: AppColors.success,
                      onTap: () => applyQuickPreset('both_free'),
                    ),
                    _PresetButton(
                      label: 'Both 50% Off',
                      icon: Icons.percent_rounded,
                      color: AppColors.info,
                      onTap: () => applyQuickPreset('both_fifty'),
                    ),
                    _PresetButton(
                      label: 'Reset to Standard (0%)',
                      icon: Icons.restart_alt_rounded,
                      color: AppColors.textTertiary,
                      onTap: () => applyQuickPreset('both_standard'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. Dubbing Discount Section
                _buildDiscountSection(
                  title: 'AI Audio Dubbing Discount',
                  subtitle: 'Applies when this channel generates AI dubbing tracks',
                  icon: Icons.record_voice_over_rounded,
                  accentColor: AppColors.info,
                  selectedType: selectedDubType,
                  customPercent: customDubPercent,
                  customCtrl: dubCustomCtrl,
                ),
                const SizedBox(height: 20),

                // 2. Subtitles Discount Section
                _buildDiscountSection(
                  title: 'AI Subtitles Discount',
                  subtitle: 'Applies when this channel generates multilingual subtitles',
                  icon: Icons.subtitles_rounded,
                  accentColor: AppColors.textLink,
                  selectedType: selectedSubType,
                  customPercent: customSubPercent,
                  customCtrl: subCustomCtrl,
                ),
                const SizedBox(height: 16),

                // Live Summary Banner
                Obx(() {
                  final dubLabel = _formatDiscountLabel(selectedDubType.value, customDubPercent.value);
                  final subLabel = _formatDiscountLabel(selectedSubType.value, customSubPercent.value);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Active Benefit for Creator: Dubbing is $dubLabel, Subtitles are $subLabel. This rate applies authoritatively in Creator Studio upload & localization.',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.warning,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Obx(() {
            return ElevatedButton.icon(
              onPressed: isSaving.value
                  ? null
                  : () async {
                      isSaving.value = true;
                      try {
                        final dubType = selectedDubType.value;
                        final dubPct = dubType == 'free'
                            ? 100.0
                            : (dubType == '50%'
                                ? 50.0
                                : (dubType == 'none'
                                    ? 0.0
                                    : customDubPercent.value.toDouble().clamp(0.0, 100.0)));

                        final subType = selectedSubType.value;
                        final subPct = subType == 'free'
                            ? 100.0
                            : (subType == '50%'
                                ? 50.0
                                : (subType == 'none'
                                    ? 0.0
                                    : customSubPercent.value.toDouble().clamp(0.0, 100.0)));

                        final success = await controller.updateChannelAiDiscounts(
                          channelId: channelId,
                          dubbingDiscountType: dubType,
                          dubbingDiscountPercent: dubPct,
                          subtitlesDiscountType: subType,
                          subtitlesDiscountPercent: subPct,
                        );

                        if (success) {
                          Get.back();
                        }
                      } finally {
                        isSaving.value = false;
                      }
                    },
              icon: isSaving.value
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 16, color: Colors.black),
              label: Text(
                isSaving.value ? 'Saving...' : 'Apply Discounts',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

Widget _buildDiscountSection({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accentColor,
  required RxString selectedType,
  required RxInt customPercent,
  required TextEditingController customCtrl,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textTertiary,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 10),
      Obx(() {
        final current = selectedType.value;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _OptionChip(
              label: 'Standard (0%)',
              isSelected: current == 'none',
              onTap: () => selectedType.value = 'none',
            ),
            _OptionChip(
              label: '50% Discount',
              isSelected: current == '50%',
              onTap: () => selectedType.value = '50%',
            ),
            _OptionChip(
              label: '100% Free',
              isSelected: current == 'free',
              activeColor: AppColors.success,
              onTap: () => selectedType.value = 'free',
            ),
            _OptionChip(
              label: 'Custom %',
              isSelected: current == 'custom',
              onTap: () => selectedType.value = 'custom',
            ),
          ],
        );
      }),
      Obx(() {
        if (selectedType.value != 'custom') {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: customCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: AppColors.bgSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgElevated),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.brand),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 0;
                    customPercent.value = parsed.clamp(0, 100);
                  },
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Enter discount percentage (0% to 100%)',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

String _formatDiscountLabel(String type, int customPct) {
  if (type == 'free') return '100% Free';
  if (type == '50%') return '50% Discount';
  if (type == 'custom') return '$customPct% Custom Discount';
  return 'Standard (0% Discount)';
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.textLink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveActiveColor.withValues(alpha: 0.18)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? effectiveActiveColor
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
