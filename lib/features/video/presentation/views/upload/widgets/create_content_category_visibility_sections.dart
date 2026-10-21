import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 4: Video Category Dropdown selector
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
      final selectedVal = categories.contains(currentCategory)
          ? currentCategory
          : (categories.isNotEmpty ? categories.first : 'Other');

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
              '4. Category',
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

/// Section 5: Video Visibility cards (Public, Private, Unlisted, Members only, Subscribers only)
class CreateContentVisibilitySection extends StatelessWidget {
  const CreateContentVisibilitySection({
    required this.uploadController,
    super.key,
  });

  final UploadController uploadController;

  static const List<Map<String, dynamic>> _visibilityOptions = [
    {
      'value': 'Public',
      'title': 'Public',
      'subtitle': 'Anyone can view this video',
      'icon': Icons.public,
    },
    {
      'value': 'Private',
      'title': 'Private',
      'subtitle': 'Only you can view this video',
      'icon': Icons.lock_outline,
    },
    {
      'value': 'Unlisted',
      'title': 'Unlisted',
      'subtitle': 'Anyone with the link can view this video',
      'icon': Icons.link,
    },
    {
      'value': 'Members only',
      'title': 'Members only',
      'subtitle': 'Only channel members can view this video',
      'icon': Icons.card_membership_rounded,
    },
    {
      'value': 'Subscribers only',
      'title': 'Subscribers only',
      'subtitle': 'Only channel subscribers can view this video',
      'icon': Icons.people_alt_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentVisibility = uploadController.selectedVisibility.value;

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
              '5. Visibility',
              style: context.themeTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose who can view this video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ..._visibilityOptions.map((opt) {
              final isSelected = currentVisibility.toLowerCase() ==
                  (opt['value'] as String).toLowerCase();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => uploadController.selectedVisibility.value =
                      opt['value'] as String,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(opt['icon'] as IconData,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                opt['subtitle'] as String,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

