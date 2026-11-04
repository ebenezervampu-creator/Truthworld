import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for Admin to inspect and manually increase a Standard channel's upload quota.
void showAdminChannelQuotaDialog({
  required BuildContext context,
  required AdminController controller,
  required Map<String, dynamic> channel,
}) {
  final currentSeconds = (channel['customDailyVideoDurationSeconds'] as num?)?.toInt() ??
      (channel['maxDailyVideoDurationSeconds'] as num?)?.toInt() ??
      600;
  final currentMinutes = (currentSeconds / 60).round().clamp(10, 1440);

  final selectedMinutes = currentMinutes.obs;
  final customMinutesCtrl = TextEditingController();
  final reasonCtrl = TextEditingController(
    text: channel['quotaIncreaseReason']?.toString() ?? '',
  );

  const presets = [10, 15, 20, 30, 45, 60, 120];

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
                color: AppColors.info.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.textLink,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channel Upload Quota',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Increase or manage daily upload duration limit',
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
          width: 480,
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
                        Icons.tv_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel['channelName'] ?? channel['name'] ?? 'Channel',
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${channel['handle'] ?? channel['customUrl'] ?? 'none'} • Current: ${ContentValidationMixin.formatDurationMinutesSeconds(currentSeconds)}/day',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Quick Presets (Daily Upload Allowance)',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Preset Pills
                Obx(() {
                  final active = selectedMinutes.value;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((mins) {
                      final isSelected = active == mins;
                      final label = mins == 10
                          ? '10m (Default)'
                          : mins >= 60
                              ? '${mins ~/ 60}h/day'
                              : '${mins}m/day';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            selectedMinutes.value = mins;
                            customMinutesCtrl.clear();
                          }
                        },
                        selectedColor: Colors.white,
                        backgroundColor: AppColors.bgSurface,
                        labelStyle: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 16),

                // Custom Minute Input
                const Text(
                  'Or Enter Custom Daily Minutes',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customMinutesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed >= 2) {
                      selectedMinutes.value = parsed;
                    }
                  },
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 25, 40, 90 (in minutes)',
                    hintStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    suffixText: 'minutes / day',
                    suffixStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    fillColor: AppColors.bgInput,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quota Note / Reason
                const Text(
                  'Admin Reason / Audit Note',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLength: 300,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(300),
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., Creator requested extra daily time for documentary series...',
                    hintStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    fillColor: AppColors.bgInput,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Obx(() {
                  final mins = selectedMinutes.value;
                  final isStandardDefault = mins == 10;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isStandardDefault ? AppColors.success : AppColors.info)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isStandardDefault ? AppColors.success : AppColors.info)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isStandardDefault ? Icons.check_circle_outline : Icons.info_outline,
                          size: 16,
                          color: isStandardDefault ? AppColors.success : AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isStandardDefault
                                ? 'Resetting to standard 10 minutes/day quota.'
                                : 'Granting $mins minutes/day. Single video limit will also allow up to $mins minutes.',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 11,
                              color: isStandardDefault ? AppColors.success : AppColors.info,
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
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final mins = selectedMinutes.value;
              if (mins < 2) {
                AppSnackbar.warning('Video upload quota must be at least 2 minutes.');
                return;
              }
              final reason = reasonCtrl.text.trim();
              Get.back();
              await controller.updateChannelQuota(
                channelId: channel['id'],
                dailyDurationMinutes: mins,
                maxVideoDurationMinutes: mins,
                reason: reason.isNotEmpty ? reason : 'Admin manual quota update to $mins min/day',
              );
            },
            icon: const Icon(
              Icons.bolt_rounded,
              size: 18,
              color: Colors.black,
            ),
            label: const Text(
              'Save Quota Changes',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
