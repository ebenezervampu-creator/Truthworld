import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/copyright_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_formatters.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card component representing an unauthorized re-upload match with actions.
class MatchVideoCard extends StatelessWidget {
  const MatchVideoCard({
    required this.docId,
    required this.data,
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final String docId;
  final Map<String, dynamic> data;
  final CopyrightController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Re-uploaded Video').toString();
    final channelName =
        (data['channelName'] ?? data['uploader'] ?? 'Other Channel').toString();
    final matchPercent = (data['matchPercentage'] ?? 95).toString();
    final views = (data['viewCount'] ?? 0).toString();
    final uploadedAt = CopyrightFormatters.formatDate(
      data['uploadedAt'] ?? data['createdAt'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '$matchPercent% MATCH',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Uploaded: $uploadedAt',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Re-uploaded on channel: $channelName • $views views',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.bgDivider),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => CopyrightDialogs.showContactUploader(
                    context: context,
                    channelName: channelName,
                    videoTitle: title,
                    isDarkMode: isDarkMode,
                  ),
                  icon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                  label: const Text(
                    'Contact Uploader',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.bgDivider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => CopyrightDialogs.showRequestRemoval(
                    context: context,
                    controller: controller,
                    videoId: docId,
                    title: title,
                    channelName: channelName,
                    isDarkMode: isDarkMode,
                  ),
                  icon: const Icon(
                    Icons.gavel_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'Request Video Removal',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
