import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/add_subtitle_track_page.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesLanguageRibbon extends StatelessWidget {
  const SubtitlesLanguageRibbon({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.isMobile,
    super.key,
  });

  final SubtitlesController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Text(
            'Tracks:',
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.availableLanguages.length + 1,
                itemBuilder: (context, index) {
                  // Last item is "+ Add Track" button
                  if (index == controller.availableLanguages.length) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 8,
                        bottom: 8,
                      ),
                      child: ActionChip(
                        avatar: const Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Add Track',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: AppColors.bgSurfaceHover,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: AppColors.brand.withValues(alpha: 0.3),
                          ),
                        ),
                        onPressed: () => Get.to(() => AddSubtitleTrackPage(
                              controller: controller,
                              isDarkMode: isDarkMode,
                            )),
                      ),
                    );
                  }

                  final code = controller.availableLanguages[index];
                  final isSelected =
                      controller.selectedLanguage.value == code;
                  final langName = controller.getLanguageName(code);
                  final subs =
                      controller.selectedVideo.value?.mediaSubtitles ?? {};
                  final hasSub = subs.containsKey(code) &&
                      (subs[code]?.isNotEmpty ?? false);
                  final isPending = !hasSub;

                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 8,
                      top: 8,
                      bottom: 8,
                    ),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            langName,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: isSelected ? Colors.black : textColor,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          if (isPending && !isSelected) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.hourglass_empty_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) controller.switchLanguage(code);
                      },
                      selectedColor: AppColors.brand,
                      backgroundColor: surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.brand
                              : isPending
                                  ? AppColors.textTertiary.withValues(alpha: 0.5)
                                  : borderColor,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                },
              );
            }),
          ),
          // Delete Language Track Option (if more than 1)
          Obx(() {
            if (controller.availableLanguages.length <= 1) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: Colors.white,
              tooltip: 'Delete Current Language Track',
              onPressed: () {
                final currentLang = controller.selectedLanguage.value;
                Get.dialog<void>(
                  AlertDialog(
                    title: const Text('Delete Language Track'),
                    content: Text(
                      'Are you sure you want to remove the "${controller.getLanguageName(currentLang)}" subtitle track?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back<void>(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Get.back<void>();
                          controller.deleteLanguageTrack(currentLang);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
