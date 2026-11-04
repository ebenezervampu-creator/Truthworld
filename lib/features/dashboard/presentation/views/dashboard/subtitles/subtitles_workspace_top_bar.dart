import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/subtitles_download_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesWorkspaceTopBar extends StatelessWidget {
  const SubtitlesWorkspaceTopBar({
    required this.video,
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.isMobile,
    super.key,
  });

  final Video video;
  final SubtitlesController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Column(
          children: [
            // Row 1: Back + Thumbnail + Title + Save + Overflow Menu
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  tooltip: 'Back to Videos',
                  onPressed: () => controller.selectVideo(null),
                ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 44,
                    height: 28,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 44,
                      height: 28,
                      color: Colors.black26,
                      child: const Icon(
                        Icons.video_library_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              video.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          Obx(() {
                            if (!controller.hasUnsavedChanges.value) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'Unsaved',
                                style: AppTextStyles.badge.copyWith(
                                  fontSize: 9,
                                  color: AppColors.warning,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      Text(
                        'Subtitles & Transcripts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Save button
                SubtitlesSaveButton(
                  controller: controller,
                  isDarkMode: isDarkMode,
                  compact: true,
                ),
                const SizedBox(width: 4),

                // More Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  tooltip: 'More Actions',
                  color: surfaceColor,
                  constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
                  onSelected: (val) {
                    switch (val) {
                      case 'download':
                        showSubtitlesDownloadSheet(
                          context: context,
                          controller: controller,
                          isDarkMode: isDarkMode,
                        );
                      case 'import':
                        controller.importSubtitleFile();
                      case 'preview':
                        controller.toggleVideoPreview();
                      case 'requests':
                        controller.toggleRequestsPanel();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Download Subtitles',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.upload_file_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Import Subtitle File',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'preview',
                      child: Row(
                        children: [
                          Icon(
                            controller.showVideoPreview.value
                                ? Icons.videocam_off_rounded
                                : Icons.videocam_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.showVideoPreview.value
                                  ? 'Hide Video Preview'
                                  : 'Show Video Preview',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'requests',
                      child: Row(
                        children: [
                          const Icon(Icons.mark_chat_unread_rounded,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.showRequestsPanel.value
                                  ? 'Hide Viewer Requests'
                                  : 'Viewer Requests',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Tablet & Desktop Top Bar
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isVeryWide = availableWidth >= 1180;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  width: 52,
                  height: 32,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 52,
                    height: 32,
                    color: Colors.black26,
                    child: const Icon(
                      Icons.video_library_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Obx(() {
                          if (!controller.hasUnsavedChanges.value) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Unsaved',
                              style: AppTextStyles.badge.copyWith(
                                fontSize: 10,
                                color: AppColors.warning,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    Text(
                      'Multi-Language Subtitles & Timed Transcripts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Actions Row (Tablet / Desktop - Responsive with safety scroll containment)
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Video Preview Toggle Button
                      SubtitlesPreviewButton(
                        controller: controller,
                        compact: !isVeryWide,
                      ),
                      const SizedBox(width: 8),

                      // Viewer Requests Toggle Button
                      SubtitlesRequestsButton(
                        controller: controller,
                        compact: !isVeryWide,
                      ),
                      const SizedBox(width: 8),

                      // More Actions Menu (with Download Subtitles)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white, size: 20),
                        tooltip: 'More Actions',
                        color: surfaceColor,
                        onSelected: (val) {
                          switch (val) {
                            case 'download':
                              showSubtitlesDownloadSheet(
                                context: context,
                                controller: controller,
                                isDarkMode: isDarkMode,
                              );
                            case 'import':
                              controller.importSubtitleFile();
                            case 'preview':
                              controller.toggleVideoPreview();
                            case 'requests':
                              controller.toggleRequestsPanel();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Download Subtitles',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.white)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'import',
                            child: Row(
                              children: [
                                Icon(Icons.upload_file_rounded,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Import Subtitle File',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Save Changes Button
                      SubtitlesSaveButton(
                        controller: controller,
                        isDarkMode: isDarkMode,
                        compact: !isVeryWide,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SubtitlesDownloadDropdownMenu extends StatelessWidget {
  const SubtitlesDownloadDropdownMenu({
    required this.controller,
    required this.textColor,
    required this.borderColor,
    super.key,
  });

  final SubtitlesController controller;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Download Subtitles in Various Formats',
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      onSelected: (val) {
        switch (val) {
          case 'srt':
            controller.downloadSrtTrack();
          case 'vtt':
            controller.downloadVttTrack();
          case 'txt':
            controller.downloadTxtTranscript();
          case 'json':
            controller.downloadJsonTrack();
          case 'clipboard':
            controller.copyToClipboard();
          case 'all':
            controller.downloadAllTracks();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'srt',
          child: Row(
            children: [
              Icon(Icons.subtitles_rounded, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SubRip Subtitle (.srt)',
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'vtt',
          child: Row(
            children: [
              Icon(Icons.video_settings_rounded, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'WebVTT Subtitle (.vtt)',
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'txt',
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plain Text Transcript (.txt)',
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'json',
          child: Row(
            children: [
              Icon(Icons.data_object_rounded, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Timed Segments JSON (.json)',
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'clipboard',
          child: Row(
            children: [
              Icon(Icons.copy_all_rounded, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Copy Transcript to Clipboard',
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'all',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Download All Tracks (ZIP)',
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              'Download',
              style: AppTextStyles.buttonText.copyWith(
                fontSize: 12,
                color: textColor,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class SubtitlesRequestsButton extends StatelessWidget {
  const SubtitlesRequestsButton({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final SubtitlesController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reqs = controller.languageRequests
          .where((r) => r.type == 'subtitle')
          .toList();
      final showRequests = controller.showRequestsPanel.value;
      return Badge(
        isLabelVisible: reqs.isNotEmpty && !showRequests,
        label: Text(
          '${reqs.length}',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.brand,
        child: OutlinedButton.icon(
          onPressed: controller.toggleRequestsPanel,
          icon: Icon(
            showRequests ? Icons.close_rounded : Icons.mark_chat_unread_rounded,
            size: 15,
            color: Colors.white,
          ),
          label: Text(
            compact
                ? (showRequests ? 'Close' : 'Requests')
                : (showRequests ? 'Close Requests' : 'Viewer Requests'),
            style: AppTextStyles.buttonText.copyWith(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.bgDivider),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: 6,
            ),
          ),
        ),
      );
    });
  }
}

class SubtitlesSaveButton extends StatelessWidget {
  const SubtitlesSaveButton({
    required this.controller,
    required this.isDarkMode,
    this.compact = false,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasChanges = controller.hasUnsavedChanges.value;
      final saving = controller.isSaving.value;

      return ElevatedButton.icon(
        onPressed: (!hasChanges || saving)
            ? null
            : controller.saveCurrentSubtitles,
        icon: saving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Icon(Icons.save_rounded, size: 15, color: Colors.black),
        label: Text(
          saving
              ? (compact ? 'Saving' : 'Saving...')
              : (compact ? 'Save' : 'Save Changes'),
          style: AppTextStyles.buttonText.copyWith(
            fontSize: 12,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.bgSurfaceHover,
          disabledForegroundColor: AppColors.textDisabled,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: 6,
          ),
        ),
      );
    });
  }
}

class SubtitlesPreviewButton extends StatelessWidget {
  const SubtitlesPreviewButton({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final SubtitlesController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showPreview = controller.showVideoPreview.value;
      return OutlinedButton.icon(
        onPressed: controller.toggleVideoPreview,
        icon: Icon(
          showPreview ? Icons.videocam_rounded : Icons.videocam_outlined,
          size: 15,
          color: Colors.white,
        ),
        label: Text(
          compact
              ? (showPreview ? 'Hide' : 'Preview')
              : (showPreview ? 'Hide Video' : 'Video Preview'),
          style: AppTextStyles.buttonText.copyWith(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: showPreview ? AppColors.brand : AppColors.bgDivider,
          ),
          backgroundColor: showPreview
              ? AppColors.brand.withValues(alpha: 0.1)
              : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 8,
          ),
        ),
      );
    });
  }
}
