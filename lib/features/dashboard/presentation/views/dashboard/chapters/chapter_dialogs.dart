import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/video/data/models/video/video_duration_utils.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal dialogs for importing and editing video chapters.
class ChapterDialogs {
  const ChapterDialogs._();

  /// Shows dialog to import description timestamps.
  static void showImportDialog(
    BuildContext context, {
    required ChaptersController controller,
    required bool isDarkMode,
  }) {
    final textController = TextEditingController();
    final surfaceColor = isDarkMode
        ? AppColors.bgSurface
        : AppColors.textPrimary;
    final textColor = isDarkMode ? AppColors.textPrimary : Colors.black;
    final textSecondaryColor = isDarkMode
        ? AppColors.textSecondary
        : Colors.black;

    final video = controller.selectedVideo.value;
    final videoDuration = video?.durationValue ?? Duration.zero;

    Get.dialog(
      AlertDialog(
        backgroundColor: surfaceColor,
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Import Timestamps',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste video chapters/timestamps directly. Any matching timestamps will be imported and merged.',
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondaryColor,
                ),
              ),
              if (video != null && videoDuration > Duration.zero) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Video Duration: ${video.duration} (timestamps exceeding this will be skipped)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.bgInput : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? AppColors.bgDivider : Colors.black12,
                  ),
                ),
                child: TextField(
                  controller: textController,
                  maxLines: 8,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        '00:00 Introduction\n01:30 Foundational Rules\n04:15 Core Topic Details',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: textSecondaryColor.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              controller.importFromTimestampFormat(textController.text);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Import & Parse'),
          ),
        ],
      ),
    );
  }

  /// Shows dialog to create or edit a milestone chapter.
  static void showEditChapterDialog(
    BuildContext context, {
    required ChaptersController controller,
    required int index,
    required bool isDarkMode,
    VideoChapter? chapter,
  }) {
    final titleController = TextEditingController(text: chapter?.title ?? '');

    final video = controller.selectedVideo.value;
    final videoDuration = video?.durationValue ?? Duration.zero;

    var timeText = '';
    if (chapter != null) {
      timeText = chapter.formattedStartTime;
    } else {
      if (controller.currentChapters.isNotEmpty) {
        final last = controller.currentChapters.last.startTime;
        var next = last + const Duration(minutes: 1);

        // Constrain suggested timestamp to stay strictly within video duration
        if (videoDuration > Duration.zero && next >= videoDuration) {
          final tenSecNext = last + const Duration(seconds: 10);
          if (tenSecNext < videoDuration) {
            next = tenSecNext;
          } else if (last < videoDuration) {
            final oneSecNext = last + const Duration(seconds: 1);
            if (oneSecNext < videoDuration) {
              next = oneSecNext;
            } else {
              next = last;
            }
          } else {
            next = Duration.zero;
          }
        }

        timeText = VideoDurationUtils.formatDuration(next);
      } else {
        timeText = '00:00';
      }
    }

    final timeController = TextEditingController(text: timeText);

    final surfaceColor = isDarkMode
        ? AppColors.bgSurface
        : AppColors.textPrimary;
    final textColor = isDarkMode ? AppColors.textPrimary : Colors.black;
    final textSecondaryColor = isDarkMode
        ? AppColors.textSecondary
        : Colors.black;

    Get.dialog(
      AlertDialog(
        backgroundColor: surfaceColor,
        title: Row(
          children: [
            Icon(
              index == -1
                  ? Icons.add_circle_outline_rounded
                  : Icons.edit_note_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              index == -1
                  ? 'Create Milestone Chapter'
                  : 'Edit Milestone Chapter',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provide the timestamp and content description for this milestone.',
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondaryColor,
                ),
              ),
              if (video != null && videoDuration > Duration.zero) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Video Duration: ${video.duration}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Timestamp Field
              Text(
                'Start Timestamp (MM:SS or HH:MM:SS)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: timeController,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 02:45',
                  helperText: (video != null && videoDuration > Duration.zero)
                      ? 'Allowed: 00:00 to < ${video.duration}'
                      : null,
                  helperStyle: TextStyle(
                    fontSize: 11,
                    color: textSecondaryColor,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              Text(
                'Chapter Title',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                inputFormatters: TruthworldTextInputFormatters.standard,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. Introducing the core architecture',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final timeVal = timeController.text.trim();

              final validation = ContentValidator.validate(
                title,
                fieldName: 'Chapter Title',
              );
              if (!validation.isValid) {
                controller.showError(validation.message);
                return;
              }

              if (timeVal.isEmpty) {
                controller.showError('Timestamp cannot be empty.');
                return;
              }

              // Parse time string
              final parts = timeVal.split(':');
              Duration? duration;
              try {
                if (parts.length == 3) {
                  duration = Duration(
                    hours: int.parse(parts[0]),
                    minutes: int.parse(parts[1]),
                    seconds: int.parse(parts[2]),
                  );
                } else if (parts.length == 2) {
                  duration = Duration(
                    minutes: int.parse(parts[0]),
                    seconds: int.parse(parts[1]),
                  );
                } else if (parts.length == 1) {
                  duration = Duration(seconds: int.parse(parts[0]));
                }
              } catch (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'ChapterDialogs.parseDuration',
                );
              }

              if (duration == null || duration < Duration.zero) {
                controller.showError(
                  'Invalid timestamp format. Use MM:SS or HH:MM:SS.',
                );
                return;
              }

              if (video != null && videoDuration > Duration.zero) {
                if (duration >= videoDuration) {
                  controller.showError(
                    'Timestamp (${VideoDurationUtils.formatDuration(duration)}) cannot exceed video duration (${video.duration}).',
                  );
                  return;
                }
              }

              final bool success;
              if (index == -1) {
                success = controller.addChapter(title, duration);
              } else {
                success = controller.updateChapter(
                  index,
                  title: title,
                  startTime: duration,
                );
              }

              if (success) {
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: Text(index == -1 ? 'Create' : 'Apply Changes'),
          ),
        ],
      ),
    );
  }
}
