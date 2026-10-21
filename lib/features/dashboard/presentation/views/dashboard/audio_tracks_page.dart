import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'audio_tracks/audio_tracks_widgets.dart';

/// Clean, high-contrast Audio Tracks & Dubbing Studio Page
/// Styled exactly matching Channel Creation Page theme, fonts, and layout.
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
    const bgColor = Color(0xFF0F0F0F);
    const surfaceColor = Color(0xFF161618);
    const textColor = Colors.white;
    const textSecondaryColor = AppColors.textSecondary;
    const borderColor = Color(0xFF27272A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return Obx(() {
              if (controller.isLoading) {
                return const AudioTracksSkeleton();
              }

              if (controller.isEmpty) {
                return _buildEmptyChannelState();
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
  // TOP HEADER BAR (Matching Channel Wizard Top Header)
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(BuildContext context, bool isDesktop) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Audio Tracks & Dubbing',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Configure multi-language audio dubbing, voiceovers, and commentary.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
              onPressed: isSaving ? null : controller.saveCurrentAudioTracks,
              icon: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 16, color: Colors.black),
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
  // EMPTY STATE (Clean Channel Creation style)
  // ---------------------------------------------------------------------------
  Widget _buildEmptyChannelState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music_rounded,
                size: 52,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'No Videos Available for Audio Workspace',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Upload video content first to configure multi-language audio dubbing and voiceovers.',
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
  // MAIN WORKSPACE EDITOR
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
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
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
                  'Select a Video to Manage Audio Tracks',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a video from the library to configure multi-language audio dubbing and voiceovers.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (isMobile) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        AudioTracksDialogs.showMobileVideoPickerSheet(
                      context: context,
                      controller: controller,
                      searchController: controller.searchController,
                      surfaceColor: surfaceColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
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
              ],
            ),
          ),
        );
      }

      final activeTab = controller.activeTab.value;
      final showRequests = controller.showRequestsPanel.value;

      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 16 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Video Banner & Action Bar
            AudioTracksWorkspaceHeader(
              video: video,
              controller: controller,
              showPreviewPlayer: _showPreviewPlayer,
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
              isDarkMode: isDarkMode,
              onChangeVideo: isMobile
                  ? () => AudioTracksDialogs.showMobileVideoPickerSheet(
                        context: context,
                        controller: controller,
                        searchController: controller.searchController,
                        surfaceColor: surfaceColor,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                        borderColor: borderColor,
                        isDarkMode: isDarkMode,
                      )
                  : null,
              onUploadTrack: () => AudioTracksDialogs.showUploadTrackDialog(
                context: context,
                controller: controller,
                isDarkMode: isDarkMode,
              ),
            ),

            // Video Preview Player (when activated)
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

            // Workspace Navigation Tab Bar & Quick Language Filter
            AudioTracksTabBar(
              controller: controller,
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
              isDarkMode: isDarkMode,
              isMobile: isMobile,
              onAddLanguage: () => AudioTracksDialogs.showAddLanguageModal(
                context: context,
                controller: controller,
                isDarkMode: isDarkMode,
              ),
            ),

            // Tab Content
            Expanded(
              child: showRequests
                  ? AudioTracksRequestsGrid(
                      controller: controller,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      onUploadDubForRequest: (langCode) =>
                          AudioTracksDialogs.showUploadTrackDialog(
                        context: context,
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
                          onAddLanguage: () =>
                              AudioTracksDialogs.showAddLanguageModal(
                            context: context,
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
                          onAddDubTrack: () =>
                              AudioTracksDialogs.showUploadTrackDialog(
                            context: context,
                            controller: controller,
                            isDarkMode: isDarkMode,
                          ),
                          onAddCommentary: () =>
                              AudioTracksDialogs.showUploadTrackDialog(
                            context: context,
                            controller: controller,
                            isDarkMode: isDarkMode,
                            defaultRole: 'Director Commentary',
                          ),
                          onPickAndUploadSingleDub: (langCode) =>
                              AudioTracksDialogs.pickAndUploadSingleDub(
                            controller: controller,
                            langCode: langCode,
                          ),
                        )),
            ),
          ],
        ),
      );
    });
  }
}
