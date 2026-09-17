import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/generate_ai_subtitles_modal.dart';
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMobile ? 10 : 12,
      ),
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
              width: 48,
              height: 30,
              fit: BoxFit.cover,
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
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Unsaved',
                          style: AppTextStyles.badge.copyWith(
                            fontSize: 10,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                Text(
                  'Multi-Language Subtitles & Timed Transcripts',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Actions Row
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Generate with Truthworld AI Button
                  ElevatedButton.icon(
                    onPressed: () => GenerateAiSubtitlesModal.show(
                      context,
                      controller,
                      isDarkMode: isDarkMode,
                    ),
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Generate with AI',
                      style: AppTextStyles.buttonText.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Import Subtitle File Button
                  OutlinedButton.icon(
                    onPressed: controller.importSubtitleFile,
                    icon: const Icon(
                      Icons.upload_file_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Import',
                      style: AppTextStyles.buttonText.copyWith(
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Download Dropdown Menu
                  SubtitlesDownloadDropdownMenu(
                    controller: controller,
                    textColor: textColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 6),

                  // Viewer Requests Toggle Button
                  SubtitlesRequestsButton(controller: controller),
                  const SizedBox(width: 6),

                  // Save Changes Button
                  SubtitlesSaveButton(
                    controller: controller,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
              Text('SubRip Subtitle (.srt)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'vtt',
          child: Row(
            children: [
              Icon(Icons.video_settings_rounded, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Text('WebVTT Subtitle (.vtt)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'txt',
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Text('Plain Text Transcript (.txt)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'json',
          child: Row(
            children: [
              Icon(Icons.data_object_rounded, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Text('Timed Segments JSON (.json)', style: TextStyle(fontSize: 13)),
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
              Text('Copy Transcript to Clipboard', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'all',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Text('Download All Tracks (ZIP)', style: TextStyle(fontSize: 13)),
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
    super.key,
  });

  final SubtitlesController controller;

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
            showRequests ? 'Close Requests' : 'Viewer Requests',
            style: AppTextStyles.buttonText.copyWith(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.bgDivider),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;

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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_rounded, size: 15, color: Colors.white),
        label: Text(
          saving ? 'Saving...' : 'Save Changes',
          style: AppTextStyles.buttonText.copyWith(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDarkMode
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFCBD5E1),
          disabledForegroundColor:
              isDarkMode ? Colors.white38 : Colors.black38,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      );
    });
  }
}
