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
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Player Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Multi-Language Synchronized Audio Player Preview',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close Preview',
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                  onPressed: () => showPreviewPlayer.value = false,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Player Container
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: SizedBox(
              height: 260,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Obx(() {
                final activeTab = controller.activeTab.value;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
            ],
          ),

          // Scrollable Quick Language Filter Bar (for tracks tab)
          Obx(() {
            if (controller.activeTab.value != 'tracks') return const SizedBox.shrink();
            final activeCode = controller.selectedLanguage.value;

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Language:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...controller.availableLanguages.map((langCode) {
                      final isChosen = langCode == activeCode;
                      final name = controller.getLanguageName(langCode);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: isChosen,
                          onSelected: (_) => controller.switchLanguageTrack(langCode),
                          selectedColor: AppColors.brand,
                          backgroundColor: const Color(0xFF1E1E1E),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isChosen ? Colors.black : AppColors.textPrimary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.bgDivider),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }),
                    // Quick Add Language Button
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                      label: const Text('Add Language'),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      backgroundColor: const Color(0xFF1E1E1E),
                      onPressed: onAddLanguage,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.bgDivider),
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

/// Custom tab pill button with active indicator state.
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
          color: isActive ? AppColors.brand.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.brand : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? textColor : textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
