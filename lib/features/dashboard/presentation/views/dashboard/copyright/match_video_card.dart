import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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
    final originalVideoTitle = (data['originalVideoTitle'] ?? '').toString();

    final cardBg = isDarkMode ? AppColors.bgSurface : Colors.white;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;
    final borderColor =
        isDarkMode ? AppColors.bgDivider : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Match percentage pill + Uploaded date + Options menu
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
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : Colors.grey.shade600,
                  ),
                  onSelected: (val) {
                    if (val == 'archive') {
                      controller.archiveMatch(docId);
                      AppSnackbar.info('Match moved to archive.');
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Archive Match'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Video Title & Match Comparison
            Text(
              title,
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            if (originalVideoTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 14,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Matches your video: $originalVideoTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Re-uploaded on channel: $channelName • $views views',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
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
                    color: primaryTextColor,
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
                    foregroundColor: primaryTextColor,
                    side: BorderSide(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : Colors.grey.shade400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
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
