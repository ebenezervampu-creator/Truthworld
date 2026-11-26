import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/upload_device_track_dialogs.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/upload_generate_subtitles_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_audio_track_dubbing_page.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Unified 4-option bottom sheet for adding multi-language subtitles and audio tracks
/// directly from the video player in Step 2.
void showUploadAddLanguageOptionsSheet({
  required BuildContext context,
  required UploadController controller,
  required bool isDarkMode,
}) {
  Get.bottomSheet<void>(
    Material(
      color: AppColors.bgPage,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
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
                    const Text(
                      'Add Language & Tracks',
                      style: TextStyle(
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
                const Text(
                  'Choose how you would like to create or add subtitles and audio tracks.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.bgSurface, height: 1),
                const SizedBox(height: 16),

                // ── SECTION 1: SUBTITLES ──
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Subtitles',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Option 1: Generate Subtitles (AI)
                _buildAddOptionCard(
                  icon: Icons.auto_awesome_rounded,
                  iconBg: AppColors.brand.withValues(alpha: 0.15),
                  iconColor: Colors.white,
                  title: 'Generate Subtitles',
                  subtitle: 'Auto-generate multi-language subtitles & captions with AI',
                  onTap: () {
                    Get.back<void>();
                    showUploadGenerateSubtitlesSheet(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: Upload Subtitles from device
                _buildAddOptionCard(
                  icon: Icons.upload_file_rounded,
                  iconBg: AppColors.bgSurface,
                  iconColor: Colors.white,
                  title: 'Upload Subtitles from device',
                  subtitle: 'Upload existing subtitle files (.srt, .vtt) from your device',
                  onTap: () {
                    Get.back<void>();
                    UploadDeviceTrackDialogs.showUploadSubtitleDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
                const SizedBox(height: 18),

                // ── SECTION 2: AUDIO TRACKS ──
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Audio Tracks',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Option 3: Generate Audio tracks (AI)
                _buildAddOptionCard(
                  icon: Icons.auto_awesome_rounded,
                  iconBg: AppColors.brand.withValues(alpha: 0.15),
                  iconColor: Colors.white,
                  title: 'Generate Audio tracks',
                  subtitle: 'Auto-generate multi-language audio track & voiceover with AI',
                  onTap: () {
                    Get.back<void>();
                    Get.to(() => const UploadAudioTrackDubbingPage());
                  },
                ),
                const SizedBox(height: 10),

                // Option 4: Upload Audio track from device video/Audio
                _buildAddOptionCard(
                  icon: Icons.audio_file_rounded,
                  iconBg: AppColors.bgSurface,
                  iconColor: Colors.white,
                  title: 'Upload Audio track from device video/Audio',
                  subtitle: 'Upload existing audio or video files (.mp3, .wav, .m4a, .mp4, .mov) from your device',
                  onTap: () {
                    Get.back<void>();
                    UploadDeviceTrackDialogs.showUploadAudioTrackDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}
