import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class SubtitlesPage extends StatelessWidget {
  const SubtitlesPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  final String channelId;
  final bool isDarkMode;

  SubtitlesController get controller {
    final ctrl = Get.isRegistered<SubtitlesController>()
        ? Get.find<SubtitlesController>()
        : Get.put(SubtitlesController());
    if (channelId.isNotEmpty && ctrl.channelId.value != channelId) {
      ctrl.setChannelContext(channelId);
    }
    return ctrl;
  }

  bool get isMobile =>
      (Get.context != null ? MediaQuery.of(Get.context!).size.width : 800) < 700;
  bool get isTablet =>
      (Get.context != null ? MediaQuery.of(Get.context!).size.width : 800) >= 700 &&
      (Get.context != null ? MediaQuery.of(Get.context!).size.width : 800) < 1024;
  bool get isDesktop =>
      (Get.context != null ? MediaQuery.of(Get.context!).size.width : 800) >= 1024;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppColors.bgPage : AppColors.bgPage;
    final surfaceColor =
        isDarkMode ? AppColors.bgSurface : AppColors.textPrimary;
    final textColor =
        isDarkMode ? AppColors.textPrimary : Colors.black;
    final textSecondaryColor =
        isDarkMode ? AppColors.textSecondary : Colors.black87;
    final borderColor =
        isDarkMode ? AppColors.bgDivider : AppColors.bgDivider;

    return Scaffold(
      backgroundColor: bgColor,
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          );
        }

        if (controller.isError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage.isNotEmpty
                        ? controller.errorMessage
                        : 'An error occurred loading subtitles',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 18,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.onInit(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Retry',
                      style: AppTextStyles.buttonText.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.subtitles_off_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Videos Found',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload videos to your channel to manage subtitles.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 15,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return isDesktop || isTablet
            ? _buildDesktopLayout(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              )
            : _buildMobileLayout(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              );
      }),
    );
  }

  // ===========================================================================
  // DESKTOP & TABLET LAYOUT
  // ===========================================================================

  Widget _buildDesktopLayout(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Video List Selector
        Container(
          width: isDesktop ? 380 : 300,
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: [
              _buildSearchHeader(surfaceColor, textColor, borderColor),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: controller.filteredVideos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final video = controller.filteredVideos[index];
                    final isSelected =
                        controller.selectedVideo.value?.id == video.id;
                    return _buildVideoSelectorCard(
                      video: video,
                      isSelected: isSelected,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Right Column: Active Video Subtitle Editor
        Expanded(
          child: ColoredBox(
            color: isDarkMode
                ? AppColors.bgPage
                : const Color(0xFFF1F5F9),
            child: controller.selectedVideo.value == null
                ? _buildEmptySelectionState(textColor, textSecondaryColor)
                : _buildSubtitleWorkspace(
                    surfaceColor,
                    textColor,
                    textSecondaryColor,
                    borderColor,
                  ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MOBILE SINGLE-VIEW LAYOUT
  // ===========================================================================

  Widget _buildMobileLayout(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return controller.selectedVideo.value == null
        ? Column(
            children: [
              _buildSearchHeader(surfaceColor, textColor, borderColor),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.filteredVideos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final video = controller.filteredVideos[index];
                    return _buildVideoSelectorCard(
                      video: video,
                      isSelected: false,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                    );
                  },
                ),
              ),
            ],
          )
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: surfaceColor,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => controller.selectVideo(null),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.selectedVideo.value?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Expanded(
                child: _buildSubtitleWorkspace(
                  surfaceColor,
                  textColor,
                  textSecondaryColor,
                  borderColor,
                ),
              ),
            ],
          );
  }

  // ===========================================================================
  // LEFT COLUMN COMPONENTS
  // ===========================================================================

  Widget _buildSearchHeader(
    Color surfaceColor,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.subtitles_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Select Video',
                style: AppTextStyles.pageTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF242424)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Search videos...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  fontSize: 14,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onChanged: (value) => controller.setSearchQuery(value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSelectorCard({
    required Video video,
    required bool isSelected,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    final trackCount = video.mediaSubtitles.length;

    return InkWell(
      onTap: () => controller.selectVideo(video),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.brand.withValues(alpha: 0.5)
                : borderColor.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : AppColors.bgDivider,
                    ),
                    errorWidget: (context, url, error) => ColoredBox(
                      color: isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : AppColors.bgDivider,
                      child: const Icon(
                        Icons.video_file_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.brand : textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        DateFormat(
                          'MMM d, yyyy',
                        ).format(video.uploadedAt.toDate()),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: trackCount > 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : textSecondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.translate_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$trackCount',
                              style: AppTextStyles.badge.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: trackCount > 0
                                    ? const Color(0xFF10B981)
                                    : textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySelectionState(
    Color textColor,
    Color textSecondaryColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a video to edit subtitles',
              style: AppTextStyles.pageTitle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a video from the sidebar to manage subtitle tracks, generate multi-language captions with Truthworld AI, and sync with the video timeline.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                color: textSecondaryColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUBTITLE WORKSPACE (MAIN WORK AREA)
  // ===========================================================================

  Widget _buildSubtitleWorkspace(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    final video = controller.selectedVideo.value!;

    return Column(
      children: [
        // 1. Top Action Bar
        _buildWorkspaceTopBar(
          video: video,
          surfaceColor: surfaceColor,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          borderColor: borderColor,
        ),

        // 2. Truthworld AI Live Generation Progress Banner
        _buildAiProgressBanner(surfaceColor, borderColor),

        // 3. Synchronized Video Player Preview & Overlay
        _buildVideoPlayerPreview(surfaceColor, borderColor, textColor),

        // 4. Language Track Selector Ribbon
        _buildLanguageRibbon(
          surfaceColor: surfaceColor,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          borderColor: borderColor,
        ),

        // 5. Main Editor & Requests Panel (Split / Tabbed)
        Expanded(
          child: isMobile
              ? Obx(() {
                  if (controller.showRequestsPanel.value) {
                    return _buildRequestsPanel(
                      surfaceColor,
                      textColor,
                      textSecondaryColor,
                      borderColor,
                    );
                  }
                  return _buildMainCuesEditor(
                    surfaceColor,
                    textColor,
                    textSecondaryColor,
                    borderColor,
                  );
                })
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildMainCuesEditor(
                        surfaceColor,
                        textColor,
                        textSecondaryColor,
                        borderColor,
                      ),
                    ),
                    Obx(() {
                      if (!controller.showRequestsPanel.value) {
                        return const SizedBox.shrink();
                      }
                      return _buildRequestsPanel(
                        surfaceColor,
                        textColor,
                        textSecondaryColor,
                        borderColor,
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. WORKSPACE TOP BAR
  // ===========================================================================

  Widget _buildWorkspaceTopBar({
    required Video video,
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
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
                    onPressed: () => _showGenerateAIModal(Get.context!),
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
                    onPressed: () => controller.importSubtitleFile(),
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
                  _buildDownloadDropdownMenu(textColor, borderColor),
                  const SizedBox(width: 6),

                  // Viewer Requests Toggle Button
                  _buildRequestsButton(),
                  const SizedBox(width: 6),

                  // Save Changes Button
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadDropdownMenu(Color textColor, Color borderColor) {
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

  Widget _buildRequestsButton() {
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
          onPressed: () => controller.toggleRequestsPanel(),
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

  Widget _buildSaveButton() {
    return Obx(() {
      final hasChanges = controller.hasUnsavedChanges.value;
      final saving = controller.isSaving.value;

      return ElevatedButton.icon(
        onPressed: (!hasChanges || saving)
            ? null
            : () => controller.saveCurrentSubtitles(),
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

  // ===========================================================================
  // 2. TRUTHWORLD AI PROGRESS BANNER
  // ===========================================================================

  Widget _buildAiProgressBanner(Color surfaceColor, Color borderColor) {
    return Obx(() {
      if (!controller.isGeneratingAI.value) return const SizedBox.shrink();

      final progress = controller.aiJobProgress.value;
      final status = controller.aiJobStatus.value.isNotEmpty
          ? controller.aiJobStatus.value
          : 'Processing video audio & preparing subtitle tracks...';

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Truthworld AI Subtitle Generation in Progress',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '$progress%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA78BFA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              status,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: const Color(0xFFDDD6FE),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? (progress / 100.0).clamp(0.0, 1.0) : null,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ===========================================================================
  // 3. SYNCHRONIZED VIDEO PLAYER PREVIEW & OVERLAY
  // ===========================================================================

  Widget _buildVideoPlayerPreview(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    return Obx(() {
      final isExpanded = controller.showVideoPreview.value;

      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Column(
          children: [
            // Collapse / Expand Toggle Bar
            InkWell(
              onTap: () => controller.toggleVideoPreview(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_filled_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Video Player & Real-time Subtitle Sync Preview',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),

            if (isExpanded) ...[
              Divider(height: 1, color: borderColor),
              Container(
                padding: const EdgeInsets.all(12),
                color: isDarkMode
                    ? const Color(0xFF0F0F0F)
                    : const Color(0xFF0F172A),
                child: Column(
                  children: [
                    // Video Viewport with Live Subtitle Overlay
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 220,
                          maxWidth: 420,
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (controller.isVideoPlayerInitialized.value &&
                                    controller.videoPlayerController != null)
                                  VideoPlayer(controller.videoPlayerController!)
                                else
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.video_library_rounded,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Synchronized Video Preview',
                                        style: AppTextStyles.caption.copyWith(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Subtitle Overlay Box
                                Obx(() {
                                  final activeIdx =
                                      controller.activeCueIndex.value;
                                  if (activeIdx >= 0 &&
                                      activeIdx < controller.currentCues.length) {
                                    final text =
                                        controller.currentCues[activeIdx].text;
                                    if (text.trim().isNotEmpty) {
                                      return Positioned(
                                        bottom: 12,
                                        left: 16,
                                        right: 16,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.8),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              text,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                shadows: [
                                                  Shadow(
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Video Scrubber & Playhead Controls
                    _buildVideoControlsBar(),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildVideoControlsBar() {
    return Obx(() {
      final pos = controller.currentVideoPosition.value;
      final dur = controller.videoDuration.value;
      final isPlaying = controller.isVideoPlaying.value;

      final posMs = pos.inMilliseconds.toDouble();
      final durMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
      final clampedPos = posMs.clamp(0.0, durMs);

      return Column(
        children: [
          // Scrubber Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.brand,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: clampedPos,
              max: durMs,
              onChanged: (val) {
                controller.seekTo(Duration(milliseconds: val.toInt()));
              },
            ),
          ),

          // Action Buttons Bar
          Row(
            children: [
              // Play/Pause
              IconButton(
                onPressed: () => controller.togglePlayPause(),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                tooltip: isPlaying ? 'Pause' : 'Play',
              ),

              // Skip -5s
              IconButton(
                onPressed: () {
                  final target = pos - const Duration(seconds: 5);
                  controller.seekTo(
                    target < Duration.zero ? Duration.zero : target,
                  );
                },
                icon: const Icon(
                  Icons.replay_5_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                tooltip: 'Rewind 5s',
              ),

              // Skip +5s
              IconButton(
                onPressed: () {
                  final target = pos + const Duration(seconds: 5);
                  controller.seekTo(
                    target > dur ? dur : target,
                  );
                },
                icon: const Icon(
                  Icons.forward_5_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                tooltip: 'Forward 5s',
              ),

              const SizedBox(width: 8),

              // Timecode display
              Text(
                '${SubtitlesController.formatDurationToTimecode(pos).split('.').first} / ${SubtitlesController.formatDurationToTimecode(dur).split('.').first}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),

              const Spacer(),

              // Add Cue at Current Playhead
              OutlinedButton.icon(
                onPressed: () => controller.addCueAtCurrentTime(),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  '+ Cue at Playhead',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  // ===========================================================================
  // 4. LANGUAGE TRACK SELECTOR RIBBON
  // ===========================================================================

  Widget _buildLanguageRibbon({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF141414)
            : AppColors.bgDivider,
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
                itemCount: controller.availableLanguages.length,
                itemBuilder: (context, index) {
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
                              fontWeight: FontWeight.w500,
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
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: Colors.white,
            tooltip: 'Add Language Track',
            onPressed: _showAddLanguageDialog,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. MAIN CUES EDITOR & TOOLBAR
  // ===========================================================================

  Widget _buildMainCuesEditor(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Column(
      children: [
        // Cues Toolbar (Search, Find & Replace, Shift Timings, Sort, Clear)
        _buildCuesToolbar(surfaceColor, textColor, borderColor),

        // Cues Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: surfaceColor.withValues(alpha: 0.4),
          child: Row(
            children: [
              SizedBox(
                width: isMobile ? 140 : 180,
                child: Text(
                  'Timing Interval',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textSecondaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Subtitle Text Cue',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textSecondaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 70),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),

        // Cues List / Scrollable Empty State
        Expanded(
          child: Obx(() {
            final cues = controller.filteredCues;
            if (cues.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 44,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                controller.searchQueryInCues.value.isNotEmpty
                                    ? 'No subtitles match "${controller.searchQueryInCues.value}"'
                                    : 'No Subtitle Cues Defined',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontSize: 15,
                                  color: textSecondaryColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => controller.addNewCue(),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Add First Cue',
                                      style: AppTextStyles.buttonText.copyWith(
                                        color: textColor,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textColor,
                                      side: BorderSide(color: borderColor),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        controller.addCueAtCurrentTime(),
                                    icon: const Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Add at Playhead',
                                      style: AppTextStyles.buttonText.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: cues.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cue = cues[index];
                return _buildCueCardItem(
                  cue,
                  index,
                  surfaceColor,
                  textColor,
                  textSecondaryColor,
                  borderColor,
                );
              },
            );
          }),
        ),

        // Workspace Bottom Add Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.addNewCue(),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Add Subtitle Segment',
                  style: AppTextStyles.buttonText.copyWith(
                    color: textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => controller.addCueAtCurrentTime(),
                icon: const Icon(Icons.timer_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Add at Playhead',
                  style: AppTextStyles.buttonText.copyWith(
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CUES TOOLBAR
  // ===========================================================================

  Widget _buildCuesToolbar(
    Color surfaceColor,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Filter Search Bar
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                style: TextStyle(fontSize: 13, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search within subtitles...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                onChanged: (v) => controller.setCueSearchQuery(v),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Find & Replace
          IconButton(
            icon: const Icon(Icons.find_replace_rounded, size: 18, color: Colors.white),
            tooltip: 'Find & Replace Text',
            onPressed: () => _showFindReplaceDialog(Get.context!),
          ),

          // Shift Timings
          IconButton(
            icon: const Icon(Icons.timelapse_rounded, size: 18, color: Colors.white),
            tooltip: 'Shift All Timings',
            onPressed: () => _showShiftTimingsDialog(Get.context!),
          ),

          // Sort Chronologically
          IconButton(
            icon: const Icon(Icons.sort_rounded, size: 18, color: Colors.white),
            tooltip: 'Sort Chronologically',
            onPressed: () => controller.sortCuesChronologically(),
          ),

          // Clear Cues
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.white),
            tooltip: 'Clear All Cues in Current Track',
            onPressed: () {
              Get.dialog<void>(
                AlertDialog(
                  title: const Text('Clear All Subtitles?'),
                  content: const Text(
                    'Are you sure you want to clear all subtitle segments in this language track? This action cannot be undone unless you reload without saving.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Get.back<void>();
                        controller.clearAllCues();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CUE CARD ITEM (SYNCHRONIZED WITH VIDEO)
  // ===========================================================================

  Widget _buildCueCardItem(
    SubtitleCue cue,
    int index,
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Obx(() {
      final isActive = controller.activeCueIndex.value == index;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
              : surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : borderColor,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timing Steppers & Playhead sync
            _buildTimingBadge(
              cue,
              index,
              textColor,
              textSecondaryColor,
            ),
            const SizedBox(width: 12),

            // Subtitle Text Field
            Expanded(
              child: TextFormField(
                key: ValueKey(
                  '${controller.selectedLanguage.value}_${cue.id}_$index',
                ),
                initialValue: cue.text,
                maxLines: null,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  color: textColor,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter subtitle segment text...',
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: textSecondaryColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  fillColor: Colors.transparent,
                ),
                onChanged: (val) => controller.updateCueText(index, val),
              ),
            ),
            const SizedBox(width: 8),

            // Actions: Duplicate & Delete
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  color: Colors.white,
                  tooltip: 'Duplicate Cue',
                  onPressed: () => controller.duplicateCue(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: Colors.white,
                  tooltip: 'Delete Cue',
                  onPressed: () => controller.deleteCue(index),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTimingBadge(
    SubtitleCue cue,
    int index,
    Color textColor,
    Color textSecondaryColor,
  ) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF242424)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // Start Time row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () =>
                    controller.shiftCueTiming(index, shiftMilliseconds: -500),
                child: const Icon(
                  Icons.remove_circle_outline,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              Tooltip(
                message: 'Seek Video to Cue',
                child: InkWell(
                  onTap: () => controller.seekToCue(index),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cue.startTime.split('.').first,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => controller.shiftCueTiming(index),
                child: const Icon(
                  Icons.add_circle_outline,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location_rounded, size: 12),
                color: Colors.white,
                tooltip: 'Set Start to Video Playhead',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => controller.setStartToCurrentTime(index),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Icon(
            Icons.arrow_downward_rounded,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(height: 2),
          // End Time row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => controller.shiftCueTiming(
                  index,
                  isStart: false,
                  shiftMilliseconds: -500,
                ),
                child: const Icon(
                  Icons.remove_circle_outline,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              Text(
                cue.endTime.split('.').first,
                style: AppTextStyles.labelMedium.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              InkWell(
                onTap: () => controller.shiftCueTiming(index, isStart: false),
                child: const Icon(
                  Icons.add_circle_outline,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location_rounded, size: 12),
                color: Colors.white,
                tooltip: 'Set End to Video Playhead',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => controller.setEndToCurrentTime(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REQUESTS PANEL
  // ===========================================================================

  Widget _buildRequestsPanel(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Container(
      width: isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_chat_unread_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Viewer Requests',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Obx(() {
                  final reqs = controller.languageRequests
                      .where((r) => r.type == 'subtitle')
                      .toList();
                  if (reqs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${reqs.length}',
                      style: AppTextStyles.badge.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: Obx(() {
              final reqs = controller.languageRequests
                  .where((r) => r.type == 'subtitle')
                  .toList();
              if (controller.isLoadingRequests.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                );
              }
              if (reqs.isEmpty) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.translate_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No requests yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reqs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final r = reqs[index];
                  final matchingLanguage = supportedLanguages.firstWhereOrNull(
                    (l) => l.name.toLowerCase() == r.language.toLowerCase(),
                  );
                  final langCode = matchingLanguage?.code ?? r.language;
                  final isAlreadyAdded = controller.availableLanguages.contains(
                    langCode,
                  );

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    matchingLanguage?.name ?? r.language,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  if (matchingLanguage != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      matchingLanguage.nativeName,
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 12,
                                        color: textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.people_alt_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${r.count}',
                                    style: AppTextStyles.badge.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: isAlreadyAdded
                              ? OutlinedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Provisioned',
                                    style: AppTextStyles.buttonText.copyWith(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    disabledForegroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: AppColors.bgDivider,
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    controller.addLanguageTrack(langCode);
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                  label: Text(
                                    'Add Track',
                                    style: AppTextStyles.buttonText.copyWith(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DIALOGS & MODALS
  // ===========================================================================

  void _showGenerateAIModal(BuildContext context) {
    final textColor = isDarkMode ? AppColors.textPrimary : Colors.black;
    final selectedLangs = <String>{'en', 'hi', 'te', 'es'}.obs;
    final priorityMode = 'standard'.obs;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final cost = ChannelWalletService.calculateAIFeatureCost(
              selectedFeatures: {'subtitles'},
              targetLanguages: selectedLangs.toList(),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Generate Subtitles with Truthworld AI',
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Transcribe spoken dialogue with speech recognition and automatically translate into 130+ languages.',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Mode Selector
                Text(
                  'Processing Priority Mode',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Standard (Queue)'),
                        selected: priorityMode.value == 'standard',
                        onSelected: (s) {
                          if (s) priorityMode.value = 'standard';
                        },
                        selectedColor: const Color(0xFF8B5CF6),
                        labelStyle: TextStyle(
                          color: priorityMode.value == 'standard'
                              ? Colors.white
                              : textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('High Priority (Express)'),
                        selected: priorityMode.value == 'high',
                        onSelected: (s) {
                          if (s) priorityMode.value = 'high';
                        },
                        selectedColor: const Color(0xFF8B5CF6),
                        labelStyle: TextStyle(
                          color: priorityMode.value == 'high'
                              ? Colors.white
                              : textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick Select / Target Languages Selection
                Row(
                  children: [
                    Text(
                      'Target Languages (${selectedLangs.length})',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        selectedLangs.addAll(['en', 'hi', 'te', 'ta', 'es', 'fr', 'de', 'ja']);
                      },
                      child: const Text('Select Popular', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: selectedLangs.clear,
                      child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Multi-select Chips
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: supportedLanguages.map((lang) {
                        final isSel = selectedLangs.contains(lang.code);
                        return FilterChip(
                          label: Text('${lang.name} (${lang.nativeName})'),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(lang.code);
                            } else {
                              selectedLangs.remove(lang.code);
                            }
                          },
                          selectedColor: const Color(0xFF8B5CF6),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : textColor,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cost summary & Action
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wallet_rounded, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated Wallet Cost:',
                        style: AppTextStyles.caption.copyWith(fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '\$${cost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: selectedLangs.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            controller.triggerSubtitlesGeneration(
                              targetLanguages: selectedLangs.toList(),
                              priorityMode: priorityMode.value,
                            );
                          },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Start AI Subtitle Pipeline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  void _showShiftTimingsDialog(BuildContext context) {
    final offsetController = TextEditingController(text: '1000');
    Get.dialog<void>(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timelapse_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Shift Subtitle Timings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shift all cues forward (+) or backward (-) in time across the active language track.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('-1000ms (-1s)'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(-1000);
                  },
                ),
                ActionChip(
                  label: const Text('-500ms'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(-500);
                  },
                ),
                ActionChip(
                  label: const Text('+500ms'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(500);
                  },
                ),
                ActionChip(
                  label: const Text('+1000ms (+1s)'),
                  onPressed: () {
                    Get.back<void>();
                    controller.shiftAllCues(1000);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: offsetController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Custom Offset (Milliseconds)',
                hintText: 'e.g. -250 or 750',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final ms = int.tryParse(offsetController.text.trim()) ?? 0;
              Get.back<void>();
              controller.shiftAllCues(ms);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply Shift'),
          ),
        ],
      ),
    );
  }

  void _showFindReplaceDialog(BuildContext context) {
    final findCtrl = TextEditingController();
    final replaceCtrl = TextEditingController();

    Get.dialog<void>(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.find_replace_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Find and Replace'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findCtrl,
              decoration: const InputDecoration(
                labelText: 'Find Text',
                hintText: 'Enter word or phrase to find...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replaceCtrl,
              decoration: const InputDecoration(
                labelText: 'Replace With',
                hintText: 'Enter replacement text...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final find = findCtrl.text;
              final replace = replaceCtrl.text;
              Get.back<void>();
              controller.replaceTextInCues(find, replace);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
  }

  void _showAddLanguageDialog() {
    final dialogActiveTab = 0.obs;
    final dialogSelectedLang = Rxn<TranslationLanguage>();
    final dialogTitleController = TextEditingController();
    final dialogTitleError = RxnString();
    final dialogPickedFile = Rxn<PlatformFile>();

    final availableToAdd = supportedLanguages
        .where((lang) => !controller.availableLanguages.contains(lang.code))
        .toList();

    Get.dialog<void>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Obx(() {
          return Container(
            width: isMobile ? double.infinity : 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Subtitle Track',
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => dialogActiveTab.value = 0,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: dialogActiveTab.value == 0
                                  ? (isDarkMode
                                      ? Colors.black45
                                      : AppColors.textPrimary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Create Manually',
                              style: AppTextStyles.buttonText.copyWith(
                                fontWeight: dialogActiveTab.value == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                                color: dialogActiveTab.value == 0
                                    ? Colors.white
                                    : (isDarkMode
                                        ? AppColors.textSecondary
                                        : Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => dialogActiveTab.value = 1,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: dialogActiveTab.value == 1
                                  ? (isDarkMode
                                      ? Colors.black45
                                      : AppColors.textPrimary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Upload File',
                              style: AppTextStyles.buttonText.copyWith(
                                fontWeight: dialogActiveTab.value == 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                                color: dialogActiveTab.value == 1
                                    ? Colors.white
                                    : (isDarkMode
                                        ? AppColors.textSecondary
                                        : Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (dialogActiveTab.value == 0) ...[
                  Text(
                    'Select a target language to prepare empty localized cue timings.',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.bgDivider
                              : Colors.black12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableToAdd.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final lang = availableToAdd[index];
                          return ListTile(
                            title: Text(
                              lang.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              lang.nativeName,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            onTap: () {
                              Get.back<void>();
                              controller.addLanguageTrack(lang.code);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Get.back<void>(),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.buttonText.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  DropdownButtonFormField<TranslationLanguage>(
                    initialValue: dialogSelectedLang.value,
                    hint: Text(
                      'Select target language',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                    dropdownColor: isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : AppColors.textPrimary,
                    items: supportedLanguages.map((lang) {
                      return DropdownMenuItem<TranslationLanguage>(
                        value: lang,
                        child: Text(
                          '${lang.name} (${lang.nativeName})',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      dialogSelectedLang.value = val;
                      if (val != null &&
                          dialogTitleController.text.trim().isEmpty) {
                        dialogTitleController.text = val.name;
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      labelStyle: TextStyle(fontSize: 13),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dialogTitleController,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Subtitle Track Title',
                      hintText: 'e.g., Spanish (Latin America)',
                      errorText: dialogTitleError.value,
                      labelStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        if (controller.profanityFilter.hasProfanity(val)) {
                          dialogTitleError.value =
                              'Title contains inappropriate language.';
                        } else {
                          dialogTitleError.value = null;
                        }
                      } else {
                        dialogTitleError.value = null;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.textDisabled
                            : AppColors.textSecondary,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dialogPickedFile.value != null
                                ? '${dialogPickedFile.value!.name} (${(dialogPickedFile.value!.size / 1024).toStringAsFixed(1)} KB)'
                                : 'No subtitle file selected (.vtt, .srt)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: dialogPickedFile.value != null
                                  ? (isDarkMode
                                      ? AppColors.textPrimary
                                      : Colors.black)
                                  : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['vtt', 'srt', 'txt'],
                                withData: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                dialogPickedFile.value = result.files.first;
                              }
                            } on Exception catch (e) {
                              controller.showError('Failed to pick file: $e');
                            }
                          },
                          icon: const Icon(Icons.file_open_rounded, size: 14, color: Colors.white),
                          label: Text(
                            'Choose',
                            style: AppTextStyles.buttonText.copyWith(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back<void>(),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.buttonText.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: controller.isUploadingFile.value
                            ? null
                            : () async {
                                if (dialogSelectedLang.value == null) {
                                  controller.showError(
                                    'Please select a language.',
                                  );
                                  return;
                                }
                                final title = dialogTitleController.text.trim();
                                if (title.isEmpty) {
                                  controller.showError(
                                    'Please enter a track title.',
                                  );
                                  return;
                                }
                                if (dialogPickedFile.value == null) {
                                  controller.showError(
                                    'Please select a subtitle file.',
                                  );
                                  return;
                                }

                                final check = await controller.validateContent(
                                  title,
                                  fieldName: 'Track Title',
                                );
                                if (!check.isValid) {
                                  dialogTitleError.value = check.message;
                                  controller.showError(check.message);
                                  return;
                                }

                                final langCode = dialogSelectedLang.value!.code;
                                final file = dialogPickedFile.value!;
                                Get.back<void>();

                                await controller.uploadSubtitleTrack(
                                  languageCode: langCode,
                                  title: title,
                                  file: file,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: controller.isUploadingFile.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Upload & Save',
                                style: AppTextStyles.buttonText.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
