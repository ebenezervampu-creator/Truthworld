import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'audio_tracks/audio_tracks_widgets.dart';

/// 100% Responsive, Industry-Standard Creator Studio Multi-Language Audio Tracks & Dubs Page.
class AudioTracksPage extends GetView<AudioTracksController> {
  AudioTracksPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  }) {
    final ctrl = Get.isRegistered<AudioTracksController>()
        ? controller
        : Get.put(AudioTracksController());
    ctrl.setChannelContext(channelId);
  }

  final String channelId;
  final bool isDarkMode;

  final RxBool _showPreviewPlayer = false.obs;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 600 && width < 1024;

    final surfaceColor = isDarkMode
        ? const Color(0xFF1E1E1E)
        : AppColors.bgSurface;
    const bgColor = AppColors.bgPage;
    final textColor = isDarkMode
        ? AppColors.textPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.textSecondary
        : AppColors.textSecondary;
    final borderColor = isDarkMode
        ? AppColors.bgDivider
        : const Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading) {
            return _buildAudioTracksSkeleton();
          }

          if (controller.isEmpty) {
            return _buildEmptyChannelState(textColor, textSecondaryColor);
          }

          if (isDesktop) {
            return _buildDesktopLayout(
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
            );
          }

          if (isTablet) {
            return _buildTabletLayout(
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
            );
          }

          return _buildMobileLayout(
            context: context,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------
  Widget _buildEmptyChannelState(Color textColor, Color textSecondaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.library_music_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Audio Workspace Scope Available',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Upload video content to configure multi-language audio dubbing, voiceovers, and commentary tracks.',
              style: TextStyle(fontSize: 14, color: textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT (>= 1024px)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: AudioTracksVideoSidebar(
            controller: controller,
            searchController: controller.searchController,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isDarkMode: isDarkMode,
          ),
        ),
        VerticalDivider(width: 1, color: borderColor),
        Expanded(
          child: _buildMainWorkspaceEditor(
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
  // TABLET LAYOUT (600px - 1023px)
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 270,
          child: AudioTracksVideoSidebar(
            controller: controller,
            searchController: controller.searchController,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isDarkMode: isDarkMode,
            compact: true,
          ),
        ),
        VerticalDivider(width: 1, color: borderColor),
        Expanded(
          child: _buildMainWorkspaceEditor(
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
  // MOBILE LAYOUT (< 600px)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout({
    required BuildContext context,
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    final selectedVideo = controller.selectedVideo.value;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              if (selectedVideo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: selectedVideo.thumbnailUrl,
                    width: 48,
                    height: 34,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.video_library_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedVideo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Audio & Dubbing Workspace',
                        style: TextStyle(fontSize: 11, color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'Select a Video',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => AudioTracksDialogs.showMobileVideoPickerSheet(
                  context: context,
                  controller: controller,
                  searchController: controller.searchController,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  textSecondaryColor: textSecondaryColor,
                  borderColor: borderColor,
                  isDarkMode: isDarkMode,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Change',
                  style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildMainWorkspaceEditor(
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isMobile: true,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN WORKSPACE EDITOR (RIGHT PANEL / MOBILE CONTAINER)
  // ---------------------------------------------------------------------------
  Widget _buildMainWorkspaceEditor({
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required bool isMobile,
  }) {
    return Builder(builder: (editorContext) {
      return Obx(() {
        final video = controller.selectedVideo.value;
        if (video == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app_rounded, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Select a Video to Manage Audio Tracks',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a video from the list to add dubbing, voiceovers, or commentary.',
                  style: TextStyle(fontSize: 13, color: textSecondaryColor),
                ),
              ],
            ),
          );
        }

        final activeTab = controller.activeTab.value;
        final showRequests = controller.showRequestsPanel.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile)
              AudioTracksWorkspaceHeader(
                video: video,
                controller: controller,
                showPreviewPlayer: _showPreviewPlayer,
                surfaceColor: surfaceColor,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
                borderColor: borderColor,
                isDarkMode: isDarkMode,
                onUploadTrack: () => AudioTracksDialogs.showUploadTrackDialog(
                  context: editorContext,
                  controller: controller,
                  isDarkMode: isDarkMode,
                ),
              ),
            if (isMobile)
              AudioTracksMobileToolbar(
                video: video,
                controller: controller,
                showPreviewPlayer: _showPreviewPlayer,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                onUploadTrack: () => AudioTracksDialogs.showUploadTrackDialog(
                  context: editorContext,
                  controller: controller,
                  isDarkMode: isDarkMode,
                ),
              ),
            Obx(() {
              if (!_showPreviewPlayer.value) return const SizedBox.shrink();
              return AudioTracksPreviewPlayer(
                video: video,
                showPreviewPlayer: _showPreviewPlayer,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
              );
            }),
            AudioTracksTabBar(
              controller: controller,
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
              isDarkMode: isDarkMode,
              isMobile: isMobile,
              onAddLanguage: () => AudioTracksDialogs.showAddLanguageModal(
                context: editorContext,
                controller: controller,
                isDarkMode: isDarkMode,
              ),
            ),
            Expanded(
              child: showRequests
                  ? AudioTracksRequestsGrid(
                      controller: controller,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      onUploadDubForRequest: (langCode) => AudioTracksDialogs.showUploadTrackDialog(
                        context: editorContext,
                        controller: controller,
                        isDarkMode: isDarkMode,
                        defaultLangCode: langCode,
                      ),
                    )
                  : (activeTab == 'languages'
                      ? AudioTracksLanguagesManager(
                          controller: controller,
                          textColor: textColor,
                          textSecondaryColor: textSecondaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          isDarkMode: isDarkMode,
                          onAddLanguage: () => AudioTracksDialogs.showAddLanguageModal(
                            context: editorContext,
                            controller: controller,
                            isDarkMode: isDarkMode,
                          ),
                        )
                      : AudioTracksListSection(
                          video: video,
                          controller: controller,
                          textColor: textColor,
                          textSecondaryColor: textSecondaryColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          isDarkMode: isDarkMode,
                          onAddDubTrack: () => AudioTracksDialogs.showUploadTrackDialog(
                            context: editorContext,
                            controller: controller,
                            isDarkMode: isDarkMode,
                          ),
                          onAddCommentary: () => AudioTracksDialogs.showUploadTrackDialog(
                            context: editorContext,
                            controller: controller,
                            isDarkMode: isDarkMode,
                            defaultRole: 'Director Commentary',
                          ),
                          onPickAndUploadSingleDub: (langCode) => AudioTracksDialogs.pickAndUploadSingleDub(
                            controller: controller,
                            langCode: langCode,
                          ),
                        )),
            ),
          ],
        );
      });
    });
  }

  Widget _buildAudioTracksSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: AppColors.bgSurfaceHover,
      child: Column(
        children: [
          // Top header skeleton
          Container(
            height: 60,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bgDivider),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Video selector sidebar skeleton
                Container(
                  width: 280,
                  margin: const EdgeInsets.only(left: 16, bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                ),
                const SizedBox(width: 16),
                // Main audio tracks workspace skeleton
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 16, bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
