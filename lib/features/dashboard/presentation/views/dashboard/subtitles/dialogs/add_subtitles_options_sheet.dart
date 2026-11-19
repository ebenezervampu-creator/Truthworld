import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/add_subtitle_track_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/generate_ai_subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_cues_editor.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_list_section.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Bottom sheet displaying subtitle addition options:
/// 1. Generate Subtitles (AI)
/// 2. Copy from Available Subtitles (if existing track has subtitles)
/// 3. Create Track Manually
/// 4. Add files (Import)
void showAddSubtitlesOptionsSheet({
  required BuildContext context,
  required SubtitlesController controller,
  required bool isDarkMode,
  String? targetLanguageCode,
}) {
  final targetName = targetLanguageCode != null
      ? controller.getLanguageName(targetLanguageCode)
      : null;
  final availableTracksWithSubs = controller.availableLanguagesWithSubtitles;
  final sourceLangForCopy = availableTracksWithSubs.isNotEmpty
      ? (availableTracksWithSubs.contains('en')
          ? 'en'
          : availableTracksWithSubs.first)
      : null;
  final sourceLangName = sourceLangForCopy != null
      ? controller.getLanguageName(sourceLangForCopy)
      : null;

  Get.bottomSheet<void>(
    Material(
      color: AppColors.bgPage,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    targetName != null ? 'Add $targetName Subtitles' : 'Add Subtitles',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back<void>(),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                targetName != null
                    ? 'Choose how to create or transcribe $targetName subtitles.'
                    : 'Choose how you would like to create or add subtitles.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgSurface, height: 1),
              const SizedBox(height: 16),

              // Option 1: Generate Subtitles (Ultra)
              _buildAddOptionCard(
                icon: Icons.auto_awesome_rounded,
                iconBg: AppColors.brand.withValues(alpha: 0.15),
                iconColor: Colors.white,
                title: 'Generate Subtitles',
                subtitle: targetName != null
                    ? 'Ultra (\$0.50 / 10m) • Transcribe and generate $targetName with Universal 3.7 Pro'
                    : 'Ultra (\$0.50 / 10m) • Universal 3.7 Pro + Google Cloud Translation v3',
                extraBadge: Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Ultra \$0.50',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  Get.to(() => GenerateAiSubtitlesPage(
                        controller: controller,
                        isDarkMode: isDarkMode,
                        initialTier: 'ultra',
                        initialLanguage: targetLanguageCode,
                      ));
                },
              ),
              const SizedBox(height: 12),

              // Option 2 (if available track has subtitles): Copy Timings from Available Track
              if (sourceLangForCopy != null &&
                  targetLanguageCode != null &&
                  normalizeLanguageCode(sourceLangForCopy) !=
                      normalizeLanguageCode(targetLanguageCode)) ...[
                _buildAddOptionCard(
                  icon: Icons.copy_all_rounded,
                  iconBg: AppColors.bgSurface,
                  iconColor: Colors.white,
                  title: 'Copy from $sourceLangName Subtitles',
                  subtitle:
                      'Duplicate all time intervals and cues from $sourceLangName to translate into $targetName',
                  onTap: () async {
                    Get.back<void>();
                    await controller.copyCuesFromTrack(
                      sourceLangCode: sourceLangForCopy,
                      targetLangCode: targetLanguageCode,
                    );
                    if (context.mounted) {
                      showSubtitlesCuesEditorModal(
                        context: context,
                        controller: controller,
                        langCode: targetLanguageCode,
                        isDarkMode: isDarkMode,
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Option 3: Create Track Manually / Copy Timings in Dedicated Studio
              _buildAddOptionCard(
                icon: Icons.edit_note_rounded,
                iconBg: AppColors.bgSurface,
                iconColor: Colors.white,
                title: 'Create Track Manually',
                subtitle:
                    'Start with blank cues or customize track in dedicated subtitle editor',
                onTap: () {
                  Get.back<void>();
                  Get.to(() => AddSubtitleTrackPage(
                        controller: controller,
                        isDarkMode: isDarkMode,
                        initialLanguage: targetLanguageCode,
                      ));
                },
              ),
              const SizedBox(height: 12),

              // Option 4: Add files
              _buildAddOptionCard(
                icon: Icons.upload_file_rounded,
                iconBg: AppColors.bgSurface,
                iconColor: Colors.white,
                title: 'Add files',
                subtitle:
                    'Upload existing subtitle files (.srt, .vtt, .txt, .json) from your device',
                onTap: () {
                  Get.back<void>();
                  if (targetLanguageCode != null) {
                    controller.switchLanguage(targetLanguageCode);
                  }
                  controller.importSubtitleFile();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

Widget _buildAddOptionCard({
  required IconData icon,
  required Color iconBg,
  required Color iconColor,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  Widget? extraBadge,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.bgSurface),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (extraBadge != null) extraBadge,
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}
