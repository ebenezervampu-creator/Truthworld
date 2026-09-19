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

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.2),
        ),
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
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '$matchPercent% MATCH',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Uploaded: $uploadedAt',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Re-uploaded on channel: $channelName • $views views',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : Colors.black,
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
                  icon: Icon(
                    Icons.email_outlined,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    size: 16,
                  ),
                  label: const Text('Contact Uploader'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black,
                    side: BorderSide(
                      color: isDarkMode ? AppColors.bgDivider : Colors.grey,
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
                  label: const Text('Request Video Removal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textPrimary,
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
