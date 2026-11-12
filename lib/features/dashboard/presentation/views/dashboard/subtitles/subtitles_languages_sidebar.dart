import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/add_language_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesLanguagesSidebar extends StatelessWidget {
  const SubtitlesLanguagesSidebar({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    const primaryText = AppColors.textPrimary;
    const secondaryText = AppColors.textSecondary;
    const cardColor = AppColors.bgSurface;
    const borderColor = AppColors.bgDivider;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with info icon
          Row(
            children: [
              const Text(
                'Languages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Available subtitle language tracks for this video',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Get.snackbar(
                      'Language Tracks',
                      'Manage subtitles across multiple languages to reach a global audience.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: cardColor,
                      colorText: primaryText,
                    );
                  },
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // "+ Add language" full-width button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () {
                final isMobile = MediaQuery.of(context).size.width < 700;
                AddLanguageDialog.show(
                  context,
                  controller,
                  isDarkMode: isDarkMode,
                  isMobile: isMobile,
                );
              },
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'Add language',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D84EC),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Languages list
          Expanded(
            child: Obx(() {
              final languages = controller.displayLanguages;
              final selectedLang = controller.selectedLanguage.value;

              return ListView.separated(
                itemCount: languages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final code = languages[index];
                  final isSelected = code == selectedLang;
                  final status = controller.getLanguageStatus(code);

                  var displayName = controller.getLanguageName(code);
                  if (code == 'en') {
                    displayName = 'English (Original)';
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (!controller.availableLanguages.contains(code)) {
                        controller.addLanguageTrack(code);
                      } else {
                        controller.switchLanguage(code);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF282828) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.textLink.withValues(alpha: 0.8)
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildStatusBadge(status),
                              ],
                            ),
                          ),
                          _buildLanguageMenu(context, code, displayName),
                        ],
                      ),
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

  Widget _buildStatusBadge(SubtitleTrackStatus status) {
    Color bg;
    Color text;
    Border? border;

    switch (status) {
      case SubtitleTrackStatus.published:
        bg = const Color(0xFF143320);
        text = const Color(0xFF4CAF50);
        border = Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.6));
      case SubtitleTrackStatus.draft:
        bg = AppColors.bgSurface;
        text = const Color(0xFFCCCCCC);
        border = Border.all(color: const Color(0xFF444444));
      case SubtitleTrackStatus.notAdded:
        bg = const Color(0xFF202020);
        text = const Color(0xFF888888);
        border = null;
      case SubtitleTrackStatus.generating:
        bg = const Color(0xFF1E293B);
        text = const Color(0xFF38BDF8);
        border = Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.6));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: border,
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: text,
        ),
      ),
    );
  }

  Widget _buildLanguageMenu(BuildContext context, String code, String name) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: AppColors.textSecondary,
      ),
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'select',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text('Edit track', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'download_srt',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text('Download SRT', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'download_vtt',
          child: Row(
            children: [
              Icon(Icons.subtitles_outlined, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text('Download VTT', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text('Export to clipboard', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'select') {
          if (!controller.availableLanguages.contains(code)) {
            controller.addLanguageTrack(code);
          } else {
            controller.switchLanguage(code);
          }
        } else if (val == 'download_srt') {
          controller.downloadSrtTrack(langCode: code);
        } else if (val == 'download_vtt') {
          controller.downloadVttTrack(langCode: code);
        } else if (val == 'copy') {
          controller.exportCurrentTrack();
        }
      },
    );
  }
}
