import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

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
    final surfaceColor = isDarkMode
        ? AppColors.bgSurface
        : AppColors.textPrimary;
    final textColor = isDarkMode
        ? AppColors.textPrimary
        : Colors.black;
    final textSecondaryColor = isDarkMode
        ? AppColors.textSecondary
        : Colors.black;
    final borderColor = isDarkMode
        ? AppColors.bgDivider
        : AppColors.bgDivider;

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
                    color: AppColors.error,
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
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(
                      'Retry',
                      style: AppTextStyles.buttonText.copyWith(
                        color: Colors.black,
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
                  Icon(
                    Icons.subtitles_off_rounded,
                    size: 80,
                    color: textSecondaryColor.withValues(alpha: 0.5),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP & TABLET SPLIT-SCREEN LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE SINGLE-VIEW LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

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
              // Back banner to return to video list
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

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

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
                color: AppColors.brand,
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
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF94A3B8),
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
                        color: AppColors.textSecondary,
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
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
                            Icon(
                              Icons.translate_rounded,
                              size: 10,
                              color: trackCount > 0
                                  ? const Color(0xFF10B981)
                                  : textSecondaryColor,
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

  Widget _buildEmptySelectionState(Color textColor, Color textSecondaryColor) {
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
                color: AppColors.brand,
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
              'Choose a video from the sidebar menu to view existing translation tracks, add new localized cue timings, and sync directly to your video streams.',
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

  Widget _buildSubtitleWorkspace(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    final video = controller.selectedVideo.value!;

    return Column(
      children: [
        // Workspace Top Bar: Responsive Header Layout
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            width: 44,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Subtitles & Multi-Language Audio Tracks',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ),
                        Obx(() {
                          if (!controller.hasUnsavedChanges.value) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.3),
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
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildRequestsButton(),
                          const SizedBox(width: 8),
                          _buildExportButton(textColor, borderColor),
                          const SizedBox(width: 8),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        width: 50,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontSize: 16,
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
                                  margin: const EdgeInsets.only(
                                    left: 8,
                                    right: 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.3),
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
                            'Subtitles & Multi-Language Audio Tracks',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildRequestsButton(),
                    const SizedBox(width: 8),
                    _buildDownloadSrtButton(textColor, borderColor),
                    const SizedBox(width: 8),
                    _buildExportButton(textColor, borderColor),
                    const SizedBox(width: 8),
                    _buildSaveButton(),
                  ],
                ),
        ),

        // Language Track Selector Ribbon
        Container(
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
                      // Show pending indicator if this language has no subtitle URL yet
                      final subs = controller.selectedVideo.value?.mediaSubtitles ?? {};
                      final hasSub = subs.containsKey(code) && (subs[code]?.isNotEmpty ?? false);
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
                                  color: AppColors.textTertiary,
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
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppColors.brand,
                tooltip: 'Add Language Track',
                onPressed: _showAddLanguageDialog,
              ),
            ],
          ),
        ),

        // Main Editor Timeline & Cue List
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

  Widget _buildRequestsButton() {
    return Obx(() {
      final hasReqs = controller.languageRequests
          .where((r) => r.type == 'subtitle')
          .isNotEmpty;
      final showRequests = controller.showRequestsPanel.value;
      return Badge(
        isLabelVisible: hasReqs && !showRequests,
        label: Text(
          '${controller.languageRequests.where((r) => r.type == 'subtitle').length}',
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
            size: 16,
            color: showRequests ? AppColors.error : AppColors.brand,
          ),
          label: Text(
            showRequests ? 'Close Requests' : 'Viewer Requests',
            style: AppTextStyles.buttonText.copyWith(
              fontSize: 12,
              color: showRequests ? AppColors.error : AppColors.brand,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: showRequests ? AppColors.error : AppColors.brand,
            side: BorderSide(
              color: showRequests
                  ? AppColors.error.withValues(alpha: 0.5)
                  : AppColors.brand.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
      );
    });
  }

  Widget _buildDownloadSrtButton(Color textColor, Color borderColor) {
    return ElevatedButton.icon(
      onPressed: () => controller.downloadSrtTrack(),
      icon: const Icon(Icons.download_rounded, size: 16, color: Colors.black),
      label: Text(
        'Download SRT',
        style: AppTextStyles.buttonText.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  Widget _buildExportButton(Color textColor, Color borderColor) {
    return OutlinedButton.icon(
      onPressed: () => controller.downloadVttTrack(),
      icon: const Icon(
        Icons.file_download_outlined,
        size: 16,
        color: AppColors.textPrimary,
      ),
      label: Text(
        'Download VTT',
        style: AppTextStyles.buttonText.copyWith(
          fontSize: 12,
          color: textColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Obx(() {
      return ElevatedButton.icon(
        onPressed: controller.isSaving.value
            ? null
            : () => controller.saveCurrentSubtitles(),
        icon: controller.isSaving.value
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textPrimary,
                  ),
                ),
              )
            : const Icon(Icons.save_rounded, size: 16),
        label: Text(
          controller.isSaving.value ? 'Saving...' : 'Save Changes',
          style: AppTextStyles.buttonText.copyWith(
            fontSize: 12,
            color: AppColors.textPrimary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      );
    });
  }

  Widget _buildMainCuesEditor(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Obx(() {
      if (controller.currentCues.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 48,
                color: textSecondaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No Subtitle Cues Defined',
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 16,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => controller.addNewCue(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Add First Cue',
                  style: AppTextStyles.buttonText.copyWith(
                    color: AppColors.brand,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand),
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Header Table column row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                const SizedBox(width: 40),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // Cues List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: controller.currentCues.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cue = controller.currentCues[index];
                return _buildCueCardItem(
                  cue,
                  index,
                  surfaceColor,
                  textColor,
                  textSecondaryColor,
                  borderColor,
                );
              },
            ),
          ),

          // Workspace Bottom Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => controller.addNewCue(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    'Add Subtitle Segment',
                    style: AppTextStyles.buttonText.copyWith(
                      color: AppColors.brand,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCueCardItem(
    SubtitleCue cue,
    int index,
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimingBadge(cue, index, textColor, textSecondaryColor),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: textSecondaryColor.withValues(alpha: 0.7),
                  onPressed: () => controller.deleteCue(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
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
                hintText: 'Enter subtitle text...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: textSecondaryColor,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                fillColor: Colors.transparent,
              ),
              onChanged: (val) => controller.updateCueText(index, val),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimingBadge(cue, index, textColor, textSecondaryColor),
          const SizedBox(width: 16),
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
                hintText: 'Enter subtitle text...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: textSecondaryColor,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                fillColor: Colors.transparent,
              ),
              onChanged: (val) => controller.updateCueText(index, val),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: textSecondaryColor.withValues(alpha: 0.6),
            onPressed: () => controller.deleteCue(index),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingBadge(
    SubtitleCue cue,
    int index,
    Color textColor,
    Color textSecondaryColor,
  ) {
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF242424)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () =>
                    controller.shiftCueTiming(index, shiftMilliseconds: -500),
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 14,
                  color: textSecondaryColor,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cue.startTime.split('.').first,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => controller.shiftCueTiming(index),
                child: Icon(
                  Icons.add_circle_outline,
                  size: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Icon(
            Icons.arrow_downward_rounded,
            size: 12,
            color: textSecondaryColor,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => controller.shiftCueTiming(
                  index,
                  isStart: false,
                  shiftMilliseconds: -500,
                ),
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 14,
                  color: textSecondaryColor,
                ),
              ),
              Text(
                cue.endTime.split('.').first,
                style: AppTextStyles.labelMedium.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              InkWell(
                onTap: () => controller.shiftCueTiming(index, isStart: false),
                child: Icon(
                  Icons.add_circle_outline,
                  size: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                  color: AppColors.brand,
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
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${reqs.length}',
                      style: AppTextStyles.badge.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 48,
                        color: textSecondaryColor.withValues(alpha: 0.4),
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
                                color: AppColors.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.people_alt_rounded,
                                    size: 12,
                                    color: AppColors.brand,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${r.count}',
                                    style: AppTextStyles.badge.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brand,
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
                                    color: AppColors.success,
                                  ),
                                  label: Text(
                                    'Provisioned',
                                    style: AppTextStyles.buttonText.copyWith(
                                      fontSize: 12,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    disabledForegroundColor: AppColors.success,
                                    side: const BorderSide(
                                      color: AppColors.success,
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    controller.addLanguageTrack(langCode);
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 14),
                                  label: Text(
                                    'Add Track',
                                    style: AppTextStyles.buttonText.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: AppColors.textPrimary,
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
                                    ? AppColors.brand
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
                                    ? AppColors.brand
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
                          color: AppColors.brand,
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
                          icon: const Icon(Icons.file_open_rounded, size: 14),
                          label: Text(
                            'Choose',
                            style: AppTextStyles.buttonText.copyWith(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: AppColors.textPrimary,
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
                            color: AppColors.brand,
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
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        child: controller.isUploadingFile.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                'Upload & Save',
                                style: AppTextStyles.buttonText.copyWith(
                                  color: AppColors.textPrimary,
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
