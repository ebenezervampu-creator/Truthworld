import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters/chapter_dialogs.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/services/storyboard_service.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/storyboard_thumbnail_widget.dart';
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Create manual chapters or import video description timestamps.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
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
              OutlinedButton.icon(
                onPressed: controller.autoDetectChapters,
                icon: Icon(
                  Icons.psychology,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                label: Text(
                  'AI Auto-Detect',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDarkMode ? AppColors.bgDivider : Colors.black26,
                  ),
                ),
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
    bool? isMobile,
  }) {
    final effectiveIsMobile =
        isMobile ?? (MediaQuery.of(context).size.width < 600);
    final video = controller.selectedVideo.value;
    final isExceeding =
        video != null &&
        video.durationValue > Duration.zero &&
        chapter.startTime >= video.durationValue;
    final canShiftForward = !isExceeding &&
        !(video != null &&
            video.durationValue > Duration.zero &&
            chapter.startTime + const Duration(seconds: 5) >=
                video.durationValue);

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
                  color: isExceeding ? AppColors.error : AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isExceeding ? AppColors.error : AppColors.brand)
                          .withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? AppColors.textPrimary : Colors.black87,
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
          SizedBox(width: effectiveIsMobile ? 10 : 16),

          // Chapter content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                color: surfaceColor,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isExceeding
                        ? AppColors.error.withValues(alpha: 0.8)
                        : borderColor,
                    width: isExceeding ? 1.5 : 1,
                  ),
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
                    padding: EdgeInsets.all(effectiveIsMobile ? 12 : 16),
                    child: effectiveIsMobile
                        ? _buildMobileChapterCardContent(
                            context,
                            controller: controller,
                            index: index,
                            chapter: chapter,
                            video: video,
                            isExceeding: isExceeding,
                            canShiftForward: canShiftForward,
                            textColor: textColor,
                            textSecondaryColor: textSecondaryColor,
                            borderColor: borderColor,
                            surfaceColor: surfaceColor,
                            isDarkMode: isDarkMode,
                          )
                        : _buildDesktopChapterCardContent(
                            context,
                            controller: controller,
                            index: index,
                            chapter: chapter,
                            video: video,
                            isExceeding: isExceeding,
                            canShiftForward: canShiftForward,
                            textColor: textColor,
                            textSecondaryColor: textSecondaryColor,
                            borderColor: borderColor,
                            surfaceColor: surfaceColor,
                            isDarkMode: isDarkMode,
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

  static Widget _buildMobileChapterCardContent(
    BuildContext context, {
    required ChaptersController controller,
    required int index,
    required VideoChapter chapter,
    required dynamic video,
    required bool isExceeding,
    required bool canShiftForward,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required Color surfaceColor,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Header Row: Drag handle, Timestamp, Exceeds pill, and compact Action buttons
        Row(
          children: [
            // Reorder drag handle
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: textSecondaryColor,
                    size: 16,
                  ),
                ),
              ),
            ),

            // Timestamp block
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: (isExceeding
                        ? AppColors.error
                        : (isDarkMode ? AppColors.brand : Colors.black87))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                chapter.formattedStartTime,
                style: TextStyle(
                  color: isExceeding
                      ? AppColors.error
                      : (isDarkMode ? AppColors.brand : Colors.black87),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),

            if (isExceeding) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Exceeds duration${video != null ? ' (${video.duration})' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Quick action shift buttons
            IconButton(
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              tooltip: 'Shift back 5s',
              onPressed: () => controller.shiftChapterTiming(index, -5000),
            ),
            const SizedBox(width: 2),
            IconButton(
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: canShiftForward
                    ? (isDarkMode ? Colors.white : Colors.black87)
                    : (isDarkMode ? Colors.white24 : Colors.black26),
              ),
              tooltip: 'Shift forward 5s',
              onPressed: canShiftForward
                  ? () => controller.shiftChapterTiming(index, 5000)
                  : null,
            ),
            const SizedBox(width: 4),
            Container(
              width: 1,
              height: 16,
              color: borderColor,
            ),
            const SizedBox(width: 4),
            // Delete button
            IconButton(
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.error,
              ),
              tooltip: 'Delete chapter',
              onPressed: () => _showDeleteConfirmation(
                context,
                controller: controller,
                index: index,
                chapter: chapter,
                surfaceColor: surfaceColor,
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Chapter thumbnail & title row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 72,
                height: 40,
                color: isDarkMode ? AppColors.bgInput : Colors.grey.shade200,
                child: _buildChapterThumbnail(chapter, video, isDarkMode),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                chapter.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColor,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildDesktopChapterCardContent(
    BuildContext context, {
    required ChaptersController controller,
    required int index,
    required VideoChapter chapter,
    required dynamic video,
    required bool isExceeding,
    required bool canShiftForward,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required Color surfaceColor,
    required bool isDarkMode,
  }) {
    return Row(
      children: [
        // Reorder drag handle
        ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: textSecondaryColor,
                size: 16,
              ),
            ),
          ),
        ),

        // Chapter Thumbnail Box
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 80,
            height: 45,
            color: isDarkMode ? AppColors.bgInput : Colors.grey.shade200,
            child: _buildChapterThumbnail(chapter, video, isDarkMode),
          ),
        ),
        const SizedBox(width: 12),

        // Timestamp block
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: (isExceeding
                    ? AppColors.error
                    : (isDarkMode ? AppColors.brand : Colors.black87))
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            chapter.formattedStartTime,
            style: TextStyle(
              color: isExceeding
                  ? AppColors.error
                  : (isDarkMode ? AppColors.brand : Colors.black87),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Title block with optional warning badge
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  chapter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
              if (isExceeding) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Exceeds duration${video != null ? ' (${video.duration})' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Quick action shift buttons
        IconButton(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(4),
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          tooltip: 'Shift back 5s',
          onPressed: () => controller.shiftChapterTiming(index, -5000),
        ),
        IconButton(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(4),
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: canShiftForward
                ? (isDarkMode ? Colors.white : Colors.black87)
                : (isDarkMode ? Colors.white24 : Colors.black26),
          ),
          tooltip: 'Shift forward 5s',
          onPressed: canShiftForward
              ? () => controller.shiftChapterTiming(index, 5000)
              : null,
        ),
        const SizedBox(width: 4),
        Container(
          width: 1,
          height: 20,
          color: borderColor,
        ),
        const SizedBox(width: 4),

        // Delete button
        IconButton(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(4),
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          tooltip: 'Delete chapter',
          onPressed: () => _showDeleteConfirmation(
            context,
            controller: controller,
            index: index,
            chapter: chapter,
            surfaceColor: surfaceColor,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  static void _showDeleteConfirmation(
    BuildContext context, {
    required ChaptersController controller,
    required int index,
    required VideoChapter chapter,
    required Color surfaceColor,
    required Color textColor,
    required bool isDarkMode,
  }) {
    Get.dialog(
      AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          'Delete Chapter',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${chapter.title}"?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
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
  }

  /// Button to add a new chapter timestamp at the end of the timeline.
  static Widget buildAddChapterButton(
    BuildContext context, {
    required ChaptersController controller,
    required Color borderColor,
    required bool isDarkMode,
    bool? isMobile,
  }) {
    final effectiveIsMobile =
        isMobile ?? (MediaQuery.of(context).size.width < 600);

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
          SizedBox(width: effectiveIsMobile ? 10 : 16),

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
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: borderColor,
                    style: BorderStyle.none,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: borderColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add New Milestone Chapter',
                          style: TextStyle(
                            color:
                                isDarkMode ? AppColors.brand : Colors.black87,
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

  static Widget _buildChapterThumbnail(
    VideoChapter chapter,
    dynamic video,
    bool isDarkMode,
  ) {
    if (chapter.thumbnailUrl != null && chapter.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: chapter.thumbnailUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 160,
        memCacheHeight: 90,
        errorWidget: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_rounded,
            size: 16,
            color: Colors.white54,
          ),
        ),
      );
    }

    if (video is Video) {
      final track = StoryboardService.generateHighDensityTrack(
        totalDuration: video.durationValue,
        multiSheetUrls: video.storyboardVariants,
        singleSheetUrl: video.storyboardUrl,
        thumbnailVariants: video.thumbnailVariants,
      );
      if (track.isNotEmpty) {
        return StoryboardThumbnailWidget(
          position: chapter.startTime,
          storyboardTrack: track,
          fallbackThumbnailUrl: video.thumbnailUrl,
          width: 80,
          height: 45,
          borderRadius: BorderRadius.zero,
        );
      }
      if (video.thumbnailUrl.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: video.thumbnailUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const Center(
            child: Icon(
              Icons.movie_creation_outlined,
              size: 16,
              color: Colors.white54,
            ),
          ),
        );
      }
    }

    return const Center(
      child: Icon(
        Icons.movie_creation_outlined,
        size: 18,
        color: Colors.white54,
      ),
    );
  }
}
