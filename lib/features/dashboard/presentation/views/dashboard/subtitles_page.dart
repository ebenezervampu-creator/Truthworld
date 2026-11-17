import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'subtitles/subtitles.dart';

/// Redesigned Subtitles Studio Page.
/// 100% responsive across all device sizes (mobile, tablet, desktop).
/// Matches exact theme, architecture, and visual hierarchy of Audio & Video Studio Page.
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
    const surfaceColor = AppColors.appBarSurface;
    const textColor = Colors.white;
    const textSecondaryColor = AppColors.textSecondary;
    const borderColor = AppColors.bgSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return Obx(() {
              if (controller.isLoading && controller.filteredVideos.isEmpty) {
                return const Center(
                  child: StudioLoadingIndicator(
                    message: 'Loading subtitles workspace...',
                  ),
                );
              }

              if (controller.isEmpty && controller.filteredVideos.isEmpty) {
                return _buildEmptyChannelState();
              }

              // Auto-select first video if none is selected
              if (controller.selectedVideo.value == null &&
                  controller.filteredVideos.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (controller.selectedVideo.value == null &&
                      controller.filteredVideos.isNotEmpty) {
                    controller.selectVideo(controller.filteredVideos.first);
                  }
                });
              }

              return Column(
                children: [
                  _buildTopHeader(context, isDesktop),
                  Expanded(
                    child: isDesktop
                        ? _buildDesktopLayout(
                            context: context,
                            surfaceColor: surfaceColor,
                            textColor: textColor,
                            textSecondaryColor: textSecondaryColor,
                            borderColor: borderColor,
                          )
                        : _buildMobileLayout(
                            context: context,
                            surfaceColor: surfaceColor,
                            textColor: textColor,
                            textSecondaryColor: textSecondaryColor,
                            borderColor: borderColor,
                          ),
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP HEADER BAR (Filter Icon + Subtitles Headline matching Audio & Video)
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(BuildContext context, bool isDesktop) {
    final hasDashboardContext = Get.isRegistered<DashboardController>() &&
        Get.find<DashboardController>().selectedIndex.value != 1;
    final showBack = hasDashboardContext || Navigator.of(context).canPop();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(bottom: BorderSide(color: AppColors.bgSurface)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (Get.isRegistered<DashboardController>() &&
                    Get.find<DashboardController>().selectedIndex.value != 1) {
                  Get.find<DashboardController>().setSelectedIndex(1);
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              tooltip: 'Back to Overview',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'Select video',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ChangeVideoDialog.show(
                    context,
                    controller: controller,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Subtitles',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            final isSaving = controller.isSaving.value;
            final hasChanges = controller.hasUnsavedChanges.value;

            if (!hasChanges && !isSaving) {
              return const SizedBox.shrink();
            }

            return ElevatedButton.icon(
              onPressed: isSaving ? null : controller.saveCurrentSubtitles,
              icon: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(Icons.save_rounded,
                      size: 16, color: Colors.black),
              label: Text(
                isSaving ? 'Saving...' : 'Save Changes',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------
  Widget _buildEmptyChannelState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.subtitles_off_rounded,
                size: 52,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'No Videos Available for Subtitles Workspace',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Upload video content first to configure multi-language subtitles and captions.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT (>= 900px)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout({
    required BuildContext context,
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: SubtitlesVideoSidebar(
            controller: controller,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isDarkMode: isDarkMode,
          ),
        ),
        Expanded(
          child: _buildMainWorkspaceContent(
            context: context,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isMobile: false,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (< 900px)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout({
    required BuildContext context,
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return _buildMainWorkspaceContent(
      context: context,
      surfaceColor: surfaceColor,
      textColor: textColor,
      textSecondaryColor: textSecondaryColor,
      borderColor: borderColor,
      isMobile: true,
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN WORKSPACE CONTENT
  // ---------------------------------------------------------------------------
  Widget _buildMainWorkspaceContent({
    required BuildContext context,
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required bool isMobile,
  }) {
    return Obx(() {
      final video = controller.selectedVideo.value;
      if (video == null) {
        return Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.appBarSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 44,
                  color: Colors.white,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select a Video to Manage Subtitles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a video from the library to configure multi-language subtitles and captions.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ChangeVideoDialog.show(
                    context,
                    controller: controller,
                    isDarkMode: isDarkMode,
                  ),
                  icon: const Icon(
                    Icons.video_library_rounded,
                    size: 16,
                    color: Colors.black,
                  ),
                  label: const Text(
                    'Browse Videos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final selectedTab = controller.selectedMainTab.value;
      final showRequests = controller.showRequestsPanel.value;

      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 16 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Underline Tab Bar (Subtitles | Transcripts)
            SubtitlesNavTabs(controller: controller),

            // AI Subtitle Generation Progress Banner
            SubtitlesAiProgressBanner(controller: controller),

            const SizedBox(height: 8),

            // Tab Content
            Expanded(
              child: showRequests
                  ? SubtitlesRequestsPanel(
                      controller: controller,
                      surfaceColor: surfaceColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                      isDarkMode: isDarkMode,
                      isMobile: isMobile,
                    )
                  : (selectedTab == 1
                      ? SubtitlesTranscriptsView(
                          controller: controller,
                          isDarkMode: isDarkMode,
                        )
                      : SubtitlesListSection(
                          video: video,
                          controller: controller,
                          textColor: textColor,
                          textSecondaryColor: textSecondaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          isDarkMode: isDarkMode,
                          onAddSubtitles: () => showAddSubtitlesOptionsSheet(
                            context: context,
                            controller: controller,
                            isDarkMode: isDarkMode,
                          ),
                        )),
            ),
          ],
        ),
      );
    });
  }
}
