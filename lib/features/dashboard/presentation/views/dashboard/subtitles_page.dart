import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
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

  @override
  Widget build(BuildContext context) {
    const bgColor = AppColors.bgPage;
    final surfaceColor =
        isDarkMode ? const Color(0xFF1E1E1E) : AppColors.bgSurface;
    final textColor =
        isDarkMode ? AppColors.textPrimary : AppColors.textPrimary;
    final textSecondaryColor =
        isDarkMode ? AppColors.textSecondary : AppColors.textSecondary;
    final borderColor =
        isDarkMode ? AppColors.bgDivider : const Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isTablet =
              constraints.maxWidth >= 700 && constraints.maxWidth < 1024;

          return Obx(() {
            if (controller.isLoading && controller.videos.isEmpty) {
              return const StudioLoadingIndicator(
                message: 'Loading subtitles workspace...',
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
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
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
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                    borderColor: borderColor,
                    isDesktop: isDesktop,
                  )
                : _buildMobileLayout(
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                    borderColor: borderColor,
                  );
          });
        },
      ),
    );
  }

  // ===========================================================================
  // DESKTOP & TABLET LAYOUT
  // ===========================================================================

  Widget _buildDesktopLayout({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required bool isDesktop,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Video List Selector
        Container(
          width: isDesktop ? 360 : 290,
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
            color: AppColors.bgPage,
            child: controller.selectedVideo.value == null
                ? SubtitlesEmptySelectionState(
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                  )
                : _buildSubtitleWorkspace(
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                    borderColor: borderColor,
                    isMobile: false,
                  ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MOBILE SINGLE-VIEW LAYOUT
  // ===========================================================================

  Widget _buildMobileLayout({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
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
        : _buildSubtitleWorkspace(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isMobile: true,
          );
  }

  // ===========================================================================
  // SUBTITLE WORKSPACE (MAIN WORK AREA)
  // ===========================================================================

  Widget _buildSubtitleWorkspace({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required bool isMobile,
  }) {
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
