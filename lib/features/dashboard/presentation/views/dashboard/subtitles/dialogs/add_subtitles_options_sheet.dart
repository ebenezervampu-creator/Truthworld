import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/generate_ai_subtitles_page.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Bottom sheet displaying subtitle addition options:
/// 1. Generate Subtitles (AI)
/// 2. Add files (Import)
void showAddSubtitlesOptionsSheet({
  required BuildContext context,
  required SubtitlesController controller,
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
                    'Add Subtitles',
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
                'Choose how you would like to create or add subtitles.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgSurface, height: 1),
              const SizedBox(height: 16),

              // Option 1: Generate Subtitles (Starter & Pro)
              _buildAddOptionCard(
                icon: Icons.auto_awesome_rounded,
                iconBg: AppColors.brand.withValues(alpha: 0.15),
                iconColor: Colors.white,
                title: 'Generate Subtitles',
                subtitle:
                    'Starter (\$0.50) or Pro (\$0.75) • Universal 3.5 Pro, Sarvam Indic & Chirp STT + Gemini 2.5/4 Argon',
                extraBadge: Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.bgElevated),
                        ),
                        child: const Text(
                          'Starter \$0.50',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Pro \$0.75',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                      ));
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Add files
              _buildAddOptionCard(
                icon: Icons.upload_file_rounded,
                iconBg: AppColors.bgSurface,
                iconColor: Colors.white,
                title: 'Add files',
                subtitle:
                    'Upload existing subtitle files (.srt, .vtt, .txt, .json) from your device',
                onTap: () {
                  Get.back<void>();
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
