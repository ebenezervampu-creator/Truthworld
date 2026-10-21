import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/audio_track_builder.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/video_player_with_audio_tracks.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Synchronized video preview player section with multi-language audio support.
class AudioTracksPreviewPlayer extends StatelessWidget {
  const AudioTracksPreviewPlayer({
    required this.video,
    required this.showPreviewPlayer,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.textSecondaryColor,
    super.key,
  });

  final Video video;
  final RxBool showPreviewPlayer;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final Color textSecondaryColor;

  @override
  Widget build(BuildContext context) {
    final playerTracks = AudioTrackBuilder.fromVideo(video);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Player Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.graphic_eq_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Multi-Language Synchronized Audio Preview',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close Preview',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: () => showPreviewPlayer.value = false,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF27272A)),

          // Player Container
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: VideoPlayerWithAudioTracks(
                videoUrl: video.videoUrl,
                tracks: playerTracks,
                autoPlay: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Workspace navigation tab bar for switching between Tracks & Dubs, and Languages & Layers.
class AudioTracksTabBar extends StatelessWidget {
  const AudioTracksTabBar({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.isMobile,
    required this.onAddLanguage,
    super.key,
  });

  final AudioTracksController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final bool isMobile;
  final VoidCallback onAddLanguage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab selection buttons (scrollable to guarantee zero horizontal overflow)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() {
              final activeTab = controller.activeTab.value;
              return Row(
                children: [
                  AudioTracksTabPill(
                    id: 'tracks',
                    label: 'Audio & Video Tracks',
                    icon: Icons.graphic_eq_rounded,
                    isActive: activeTab == 'tracks',
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                    onTap: () => controller.setActiveTab('tracks'),
                  ),
                  const SizedBox(width: 8),
                  AudioTracksTabPill(
                    id: 'languages',
                    label: 'Languages & Layers (${controller.availableLanguages.length})',
                    icon: Icons.language_rounded,
                    isActive: activeTab == 'languages',
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                    onTap: () => controller.setActiveTab('languages'),
                  ),
                ],
              );
            }),
          ),

          // Scrollable Quick Language Filter Bar (for tracks tab)
          Obx(() {
            if (controller.activeTab.value != 'tracks') {
              return const SizedBox.shrink();
            }
            final activeCode = controller.selectedLanguage.value;

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Language:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...controller.availableLanguages.map((langCode) {
                      final isChosen = langCode == activeCode;
                      final name = controller.getLanguageName(langCode);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => controller.switchLanguageTrack(langCode),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isChosen ? Colors.white : const Color(0xFF161618),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChosen
                                    ? Colors.white
                                    : const Color(0xFF27272A),
                              ),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isChosen ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Quick Add Language Button
                    InkWell(
                      onTap: onAddLanguage,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Add Language',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Custom tab pill button with monochrome high-contrast styling matching Channel Creation.
class AudioTracksTabPill extends StatelessWidget {
  const AudioTracksTabPill({
    required this.id,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.textColor,
    required this.textSecondaryColor,
    required this.onTap,
    super.key,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool isActive;
  final Color textColor;
  final Color textSecondaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.white : const Color(0xFF27272A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
