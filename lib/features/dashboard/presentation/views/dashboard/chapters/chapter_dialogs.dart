import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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
            Icon(
              Icons.download_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Import Timestamps',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
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
                    color: (isDarkMode ? AppColors.brand : Colors.black87)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: isDarkMode ? AppColors.brand : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Video Duration: ${video.duration} (timestamps exceeding this will be skipped)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isDarkMode ? AppColors.brand : Colors.black87,
                          ),
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
                  maxLength: 5000,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(5000),
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
    final currentThumbnailUrl = RxnString(chapter?.thumbnailUrl);
    final isUploading = false.obs;

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
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                index == -1
                    ? 'Create Milestone Chapter'
                    : 'Edit Milestone Chapter',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 450,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
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
                    color: (isDarkMode ? AppColors.brand : Colors.black87)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isDarkMode ? AppColors.brand : Colors.black87)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: isDarkMode ? AppColors.brand : Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Video Duration: ${video.duration}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                isDarkMode ? AppColors.brand : Colors.black87,
                          ),
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
                maxLength: 10,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
                  LengthLimitingTextInputFormatter(10),
                ],
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
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(100),
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
              const SizedBox(height: 16),

              // Chapter Thumbnail Section
              Text(
                'Chapter Thumbnail',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),

              Obx(() {
                final customThumb = currentThumbnailUrl.value;
                final bool hasCustom =
                    customThumb != null && customThumb.isNotEmpty;

                // Resolve frame from video variants/storyboard for current timestamp
                final autoThumb = (video != null)
                    ? controller.resolveChapterThumbnail(
                        video,
                        _parseTimeString(timeController.text.trim()) ??
                            Duration.zero,
                      )
                    : null;

                final displayUrl = hasCustom
                    ? customThumb
                    : (autoThumb ?? video?.thumbnailUrl ?? '');

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 16:9 Thumbnail Preview Container
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: MediaQuery.of(context).size.width < 400
                                  ? 110
                                  : 130,
                              height: MediaQuery.of(context).size.width < 400
                                  ? 62
                                  : 73,
                              color: Colors.black26,
                              child: isUploading.value
                                  ? const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : (displayUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: displayUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              const Center(
                                            child: Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.movie_creation_outlined,
                                            color: Colors.white54,
                                            size: 28,
                                          ),
                                        )),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Thumbnail badge & helper text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (hasCustom
                                        ? AppColors.brand
                                        : (isDarkMode
                                            ? Colors.white12
                                            : Colors.black12)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    hasCustom
                                        ? 'Custom Thumbnail'
                                        : (autoThumb != null
                                            ? 'HD Frame at Timestamp'
                                            : 'Video Cover Fallback'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: hasCustom
                                          ? Colors.black // Rule: Black text on white/brand
                                          : textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  hasCustom
                                      ? 'Custom chapter artwork will be used across the video player and chapters drawer.'
                                      : 'Capture a frame from this timestamp or upload a custom graphic.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondaryColor,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Capture Frame button
                          OutlinedButton.icon(
                            onPressed: isUploading.value
                                ? null
                                : () async {
                                    final parsedTime = _parseTimeString(
                                          timeController.text.trim(),
                                        ) ??
                                        Duration.zero;
                                    if (video != null) {
                                      isUploading.value = true;
                                      try {
                                        final frame = await controller
                                            .captureHighQualityChapterFrame(
                                          videoId: video.id,
                                          startTime: parsedTime,
                                        );
                                        if (frame != null &&
                                            frame.isNotEmpty) {
                                          currentThumbnailUrl.value = frame;
                                          AppSnackbar.success(
                                            'High-definition frame at ${VideoDurationUtils.formatDuration(parsedTime)} captured!',
                                          );
                                        } else {
                                          currentThumbnailUrl.value =
                                              video.thumbnailUrl;
                                          AppSnackbar.info(
                                            'Using video frame thumbnail. You can also upload a custom image.',
                                          );
                                        }
                                      } catch (_) {
                                        final fallback = controller
                                            .resolveChapterThumbnail(
                                          video,
                                          parsedTime,
                                        );
                                        currentThumbnailUrl.value =
                                            fallback ?? video.thumbnailUrl;
                                        AppSnackbar.info(
                                          'Captured frame from video preview track.',
                                        );
                                      } finally {
                                        isUploading.value = false;
                                      }
                                    }
                                  },
                            icon: Icon(
                              Icons.camera_alt_outlined,
                              size: 15,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            label: Text(
                              'Capture Frame',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              side: BorderSide(
                                color: isDarkMode
                                    ? AppColors.bgDivider
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),

                          // Upload Image button
                          OutlinedButton.icon(
                            onPressed: isUploading.value
                                ? null
                                : () async {
                                    if (video == null) return;
                                    try {
                                      final result =
                                          await FilePicker.pickFiles(
                                        type: FileType.image,
                                        withData: true,
                                      );
                                      if (result != null &&
                                          result.files.isNotEmpty) {
                                        final picked = result.files.first;
                                        if (picked.size > 2 * 1024 * 1024) {
                                          AppSnackbar.warning(
                                            'Selected image exceeds the 2MB limit.',
                                          );
                                          return;
                                        }
                                        if (picked.bytes != null) {
                                          isUploading.value = true;
                                          final url = await controller
                                              .uploadChapterThumbnail(
                                            videoId: video.id,
                                            bytes: picked.bytes!,
                                            fileName: picked.name,
                                          );
                                          if (url != null &&
                                              url.isNotEmpty) {
                                            currentThumbnailUrl.value = url;
                                            AppSnackbar.success(
                                              'Custom chapter thumbnail uploaded successfully!',
                                            );
                                          }
                                        }
                                      }
                                    } catch (e, s) {
                                      ErrorHandler.log(
                                        e,
                                        stackTrace: s,
                                        tag: 'ChapterDialogs.uploadThumbnail',
                                      );
                                      AppSnackbar.error(
                                        'Failed to select image. Please try again.',
                                      );
                                    } finally {
                                      isUploading.value = false;
                                    }
                                  },
                            icon: Icon(
                              Icons.upload_file_rounded,
                              size: 15,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            label: Text(
                              'Upload Image',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              side: BorderSide(
                                color: isDarkMode
                                    ? AppColors.bgDivider
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),

                          // Reset to auto button (if custom thumb is active)
                          if (hasCustom)
                            TextButton.icon(
                              onPressed: isUploading.value
                                  ? null
                                  : () {
                                      currentThumbnailUrl.value = null;
                                    },
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 15,
                                color: AppColors.error,
                              ),
                              label: const Text(
                                'Reset to Auto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                        ],
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
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final timeVal = timeController.text.trim();

              final validation = ContentValidator.validate(
                title,
                maxLength: 100,
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

              final duration = _parseTimeString(timeVal);

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
                success = controller.addChapter(
                  title,
                  duration,
                  thumbnailUrl: currentThumbnailUrl.value,
                );
              } else {
                success = controller.updateChapter(
                  index,
                  title: title,
                  startTime: duration,
                  thumbnailUrl: currentThumbnailUrl.value,
                  clearThumbnail: currentThumbnailUrl.value == null,
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

  static Duration? _parseTimeString(String timeVal) {
    if (timeVal.isEmpty) return null;
    final parts = timeVal.split(':');
    try {
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      } else if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      } else if (parts.length == 1) {
        return Duration(seconds: int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }
}
