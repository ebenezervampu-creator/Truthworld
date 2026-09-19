import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Bottom action buttons for community post upload (Save Draft, Schedule, Publish).
class CommunityUploadActionButtons
    extends GetView<CommunityPostUploadController> {
  const CommunityUploadActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isScheduled = controller.isScheduled.value;
      final scheduledDate = controller.scheduledDate.value;
      final isUploading = controller.isUploading.value;

      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          // 1. Save as draft button
          OutlinedButton(
            onPressed: controller.handleSaveDraftSubmit,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              backgroundColor: const Color(0xFF141414),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: BorderSide(color: context.colors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save as draft',
              style: context.twTypography.button.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),

          // 2. Schedule for Later
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isScheduled
                    ? Colors.white.withValues(alpha: 0.6)
                    : context.colors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isScheduled,
                  onChanged: (val) => controller.isScheduled.value = val,
                  activeColor: Colors.white,
                  activeTrackColor: context.colors.surfaceContainerHigh,
                  inactiveThumbColor: context.colors.textTertiary,
                  inactiveTrackColor: context.colors.surfaceContainer,
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: isScheduled
                      ? () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: scheduledDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime:
                                  TimeOfDay.fromDateTime(scheduledDate),
                            );
                            if (time != null) {
                              controller.scheduledDate.value = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                time.hour,
                                time.minute,
                              );
                            }
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.textPrimary, // White icon
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isScheduled
                              ? DateFormat('dd MMM, hh:mm a')
                                  .format(scheduledDate)
                              : 'Schedule for later',
                          style: context.twTypography.body.copyWith(
                            fontSize: 12,
                            fontWeight: isScheduled
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isScheduled
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Review & Publish button
          ElevatedButton(
            onPressed: isUploading ? null : controller.handlePublishSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    isScheduled ? 'Schedule & Publish' : 'Review & Publish',
                    style: context.twTypography.button.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
          ),
        ],
      );
    });
  }
}
