import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shows an industry-standard modal sheet for downloading subtitles in multiple formats.
void showSubtitlesDownloadSheet({
  required BuildContext context,
  required SubtitlesController controller,
  required bool isDarkMode,
}) {
  final currentLangCode = controller.selectedLanguage.value;
  final currentLangName = controller.getLanguageName(currentLangCode);
  final videoTitle = controller.selectedVideo.value?.title ?? 'Video';

  Get.bottomSheet<void>(
    Material(
      color: AppColors.bgPage,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Download Subtitles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currentLangName ($currentLangCode) • $videoTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back<void>(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.bgSurface, height: 1),
              const SizedBox(height: 8),

              // Format options
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildDownloadOption(
                      icon: Icons.subtitles_rounded,
                      title: 'SubRip Subtitle (.srt)',
                      subtitle:
                          'Standard timed subtitle format for YouTube & media players',
                      badge: 'SRT',
                      onTap: () {
                        Get.back<void>();
                        controller.downloadSrtTrack();
                      },
                    ),
                    _buildDownloadOption(
                      icon: Icons.video_settings_rounded,
                      title: 'WebVTT Subtitle (.vtt)',
                      subtitle:
                          'HTML5 web video subtitle standard with cue styling',
                      badge: 'VTT',
                      onTap: () {
                        Get.back<void>();
                        controller.downloadVttTrack();
                      },
                    ),
                    _buildDownloadOption(
                      icon: Icons.description_outlined,
                      title: 'Plain Text Transcript (.txt)',
                      subtitle:
                          'Clean spoken dialogue transcript without timestamps',
                      badge: 'TXT',
                      onTap: () {
                        Get.back<void>();
                        controller.downloadTxtTranscript();
                      },
                    ),
                    _buildDownloadOption(
                      icon: Icons.data_object_rounded,
                      title: 'Timed Segments JSON (.json)',
                      subtitle:
                          'Structured data with start/end millisecond precision',
                      badge: 'JSON',
                      onTap: () {
                        Get.back<void>();
                        controller.downloadJsonTrack();
                      },
                    ),
                    const Divider(color: AppColors.bgSurface, height: 16),
                    _buildDownloadOption(
                      icon: Icons.copy_all_rounded,
                      title: 'Copy to Clipboard',
                      subtitle:
                          'Instantly copy current language subtitles to clipboard',
                      badge: 'COPY',
                      onTap: () {
                        Get.back<void>();
                        controller.copyToClipboard();
                      },
                    ),
                    _buildDownloadOption(
                      icon: Icons.archive_outlined,
                      title: 'Download All Tracks (ZIP)',
                      subtitle:
                          'Export an archive containing all available language tracks',
                      badge: 'ZIP',
                      onTap: () {
                        Get.back<void>();
                        controller.downloadAllTracks();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

Widget _buildDownloadOption({
  required IconData icon,
  required String title,
  required String subtitle,
  required String badge,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.bgSurface),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.bgElevated),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.download_rounded,
              size: 18,
              color: Colors.white,
            ),
          ],
        ),
      ),
    ),
  );
}
