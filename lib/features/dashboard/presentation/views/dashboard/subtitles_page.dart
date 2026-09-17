import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles.dart';
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
              SubtitlesSearchHeader(
                controller: controller,
                surfaceColor: surfaceColor,
                textColor: textColor,
                borderColor: borderColor,
                isDarkMode: isDarkMode,
              ),
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
                    return SubtitlesVideoSelectorCard(
                      video: video,
                      isSelected: isSelected,
                      controller: controller,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                      isDarkMode: isDarkMode,
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
                ? SubtitlesEmptySelectionState(
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                  )
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
              SubtitlesSearchHeader(
                controller: controller,
                surfaceColor: surfaceColor,
                textColor: textColor,
                borderColor: borderColor,
                isDarkMode: isDarkMode,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.filteredVideos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final video = controller.filteredVideos[index];
                    return SubtitlesVideoSelectorCard(
                      video: video,
                      isSelected: false,
                      controller: controller,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                      isDarkMode: isDarkMode,
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
        SubtitlesWorkspaceTopBar(
          video: video,
          controller: controller,
          surfaceColor: surfaceColor,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          borderColor: borderColor,
          isDarkMode: isDarkMode,
          isMobile: isMobile,
        ),

        // 2. Truthworld AI Live Generation Progress Banner
        SubtitlesAiProgressBanner(controller: controller),

        // 3. Synchronized Video Player Preview & Overlay
        SubtitlesPlayerPreview(
          controller: controller,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          isDarkMode: isDarkMode,
        ),

        // 4. Language Track Selector Ribbon
        SubtitlesLanguageRibbon(
          controller: controller,
          surfaceColor: surfaceColor,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          borderColor: borderColor,
          isDarkMode: isDarkMode,
          isMobile: isMobile,
        ),

        // 5. Main Editor & Requests Panel (Split / Tabbed)
        Expanded(
          child: isMobile
              ? Obx(() {
                  if (controller.showRequestsPanel.value) {
                    return SubtitlesRequestsPanel(
                      controller: controller,
                      surfaceColor: surfaceColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                      isDarkMode: isDarkMode,
                      isMobile: isMobile,
                    );
                  }
                  return SubtitlesCuesEditor(
                    controller: controller,
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                    borderColor: borderColor,
                    isDarkMode: isDarkMode,
                    isMobile: isMobile,
                  );
                })
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SubtitlesCuesEditor(
                        controller: controller,
                        surfaceColor: surfaceColor,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                        borderColor: borderColor,
                        isDarkMode: isDarkMode,
                        isMobile: isMobile,
                      ),
                    ),
                    Obx(() {
                      if (!controller.showRequestsPanel.value) {
                        return const SizedBox.shrink();
                      }
                      return SubtitlesRequestsPanel(
                        controller: controller,
                        surfaceColor: surfaceColor,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                        borderColor: borderColor,
                        isDarkMode: isDarkMode,
                        isMobile: isMobile,
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }
}
