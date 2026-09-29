import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters/chapter_dialogs.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Timeline and row widgets for chapters management.
class ChaptersTimelineView {
  const ChaptersTimelineView._();

  /// Empty timeline state when a selected video has 0 chapters.
  static Widget buildEmptyTimelineState(
    BuildContext context, {
    required ChaptersController controller,
    required Color textColor,
    required Color textSecondaryColor,
    required bool isDarkMode,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.toc_rounded,
            size: 64,
            color: textSecondaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Timeline is Empty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create manual chapters or import video description timestamps.',
            style: TextStyle(
              fontSize: 13,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => ChapterDialogs.showEditChapterDialog(
                  context,
                  controller: controller,
                  index: -1,
                  isDarkMode: isDarkMode,
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.black),
                label: const Text('Add Intro at 00:00'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: controller.autoDetectChapters,
                icon: const Icon(Icons.psychology, color: Colors.white),
                label: const Text('AI Auto-Detect'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Individual chapter row on the timeline.
  static Widget buildTimelineRow(
    BuildContext context, {
    required ChaptersController controller,
    required int index,
    required VideoChapter chapter,
    required int total,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required Color surfaceColor,
    required bool isDarkMode,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical Timeline Line & Circle Indicator
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              if (index < total)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.brand.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Chapter content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Card(
                color: surfaceColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                child: InkWell(
                  onTap: () => ChapterDialogs.showEditChapterDialog(
                    context,
                    controller: controller,
                    index: index,
                    chapter: chapter,
                    isDarkMode: isDarkMode,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Timestamp block
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            chapter.formattedStartTime,
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Title block
                        Expanded(
                          child: Text(
                            chapter.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                            ),
                          ),
                        ),

                        // Quick action shift buttons
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          tooltip: 'Shift back 5s',
                          onPressed: () =>
                              controller.shiftChapterTiming(index, -5000),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          tooltip: 'Shift forward 5s',
                          onPressed: () =>
                              controller.shiftChapterTiming(index, 5000),
                        ),
                        const VerticalDivider(),

                        // Delete button
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Get.dialog(
                              AlertDialog(
                                backgroundColor: surfaceColor,
                                title: const Text('Delete Chapter'),
                                content: Text(
                                  'Are you sure you want to delete "${chapter.title}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: Get.back,
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      controller.deleteChapter(index);
                                      Get.back();
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Button to add a new chapter timestamp at the end of the timeline.
  static Widget buildAddChapterButton(
    BuildContext context, {
    required ChaptersController controller,
    required Color borderColor,
    required bool isDarkMode,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector dot
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          Expanded(
            child: InkWell(
              onTap: () => ChapterDialogs.showEditChapterDialog(
                context,
                controller: controller,
                index: -1,
                isDarkMode: isDarkMode,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: borderColor,
                    style: BorderStyle.none,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Card(
                  elevation: 0,
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: borderColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Add New Milestone Chapter',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
