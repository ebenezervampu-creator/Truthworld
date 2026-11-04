import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 6: Video Category Dropdown selector
class CreateContentCategorySection extends StatelessWidget {
  const CreateContentCategorySection({
    required this.uploadController,
    super.key,
  });

  final UploadController uploadController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentCategory = uploadController.selectedCategory.value;
      final categories = uploadController.videoCategories;
      final channel = uploadController.selectedChannel.value;

      var effectiveCategory = currentCategory;
      if (effectiveCategory.isEmpty || effectiveCategory == 'Other') {
        final channelCat = uploadController.resolveChannelFirstCategory(channel);
        if (channelCat.isNotEmpty && channelCat != 'Other') {
          effectiveCategory = channelCat;
          if (uploadController.selectedCategory.value != effectiveCategory) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              uploadController.selectedCategory.value = effectiveCategory;
            });
          }
        }
      }

      final selectedVal = categories.contains(effectiveCategory)
          ? effectiveCategory
          : (categories.isNotEmpty ? categories.first : '');

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '6. Category',
              style: context.themeTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedVal,
              decoration: InputDecoration(
                fillColor: const Color(0xFF0F0F11),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              dropdownColor: const Color(0xFF161618),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  uploadController.selectCategory(val);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the category that best fits your video.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Section 7: Video Visibility Section — Dropdown selector exactly like Category
class CreateContentVisibilitySection extends StatelessWidget {
  const CreateContentVisibilitySection({
    required this.uploadController,
    super.key,
  });

  final UploadController uploadController;

  static const List<String> visibilityOptions = [
    'Public',
    'Private',
    'Unlisted',
    'Members only',
    'Subscribers only',
    'Schedule',
  ];

  Future<void> _pickScheduleDate(BuildContext context) async {
    final now = DateTime.now();
    final current = uploadController.scheduledDate.value.isAfter(now)
        ? uploadController.scheduledDate.value
        : now.add(const Duration(hours: 2));

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1F1F23),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1F1F23),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      uploadController.scheduledDate.value = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
    }
  }

  Future<void> _pickScheduleTime(BuildContext context) async {
    final current = uploadController.scheduledDate.value;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1F1F23),
              onSurface: Colors.white,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF1F1F23),
              hourMinuteColor: Color(0xFF2B2B30),
              hourMinuteTextColor: Colors.white,
              dialBackgroundColor: Color(0xFF2B2B30),
              dialHandColor: Colors.white,
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      uploadController.scheduledDate.value = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isScheduled = uploadController.isScheduled.value;
      final currentVisibility = uploadController.selectedVisibility.value;
      final scheduledDate = uploadController.scheduledDate.value;

      String selectedVal;
      if (isScheduled) {
        selectedVal = 'Schedule';
      } else {
        final normalized =
            currentVisibility.trim().toLowerCase().replaceAll('_', ' ');
        selectedVal = visibilityOptions.firstWhere(
          (opt) => opt.toLowerCase() == normalized,
          orElse: () => 'Public',
        );
      }

      if (!isScheduled &&
          uploadController.selectedVisibility.value != selectedVal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          uploadController.selectedVisibility.value = selectedVal;
        });
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '7. Visibility',
              style: context.themeTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedVal),
              value: selectedVal,
              decoration: InputDecoration(
                fillColor: const Color(0xFF0F0F11),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              dropdownColor: const Color(0xFF161618),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: visibilityOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  if (val == 'Schedule') {
                    uploadController.isScheduled.value = true;
                    final now = DateTime.now();
                    if (uploadController.scheduledDate.value.isBefore(now)) {
                      final tomorrow = now.add(const Duration(days: 1));
                      uploadController.scheduledDate.value = DateTime(
                        tomorrow.year,
                        tomorrow.month,
                        tomorrow.day,
                        9,
                        0,
                      );
                    }
                  } else {
                    uploadController.isScheduled.value = false;
                    uploadController.selectedVisibility.value = val;
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Choose when to publish and who can see your video.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            if (isScheduled) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Date Picker Tile
                  InkWell(
                    onTap: () => _pickScheduleDate(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM, yyyy').format(scheduledDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Time Picker Tile
                  InkWell(
                    onTap: () => _pickScheduleTime(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('hh:mm a').format(scheduledDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.public_outlined,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Time zone: Local time zone (${DateTime.now().timeZoneName})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Video will be private until published',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Before you publish, check the following:\n• Do kids appear in this video? Follow child safety guidelines.\n• Ensure your content meets our Community Guidelines.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
