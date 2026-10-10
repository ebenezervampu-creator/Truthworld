import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Complete Video Details (A - Z Technical Specifications & Metadata).
/// Collapsible / structured inspection card providing creators and channel
/// managers with exhaustive metadata, streaming profiles, and storage artifacts.
class VideoTechnicalDetailsCard extends StatelessWidget {
  const VideoTechnicalDetailsCard({
    required this.video,
    required this.isDarkMode,
    super.key,
  });

  final Video video;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final uploadDate = DateFormat('MMM d, yyyy • h:mm a').format(
      video.uploadedAt.toDate(),
    );
    final durationMin = video.durationValue.inMinutes;
    final durationSec = video.durationValue.inSeconds % 60;
    final durationFormatted = '${durationMin}m ${durationSec}s (${video.durationValue.inSeconds}s total)';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          leading: const Icon(
            Icons.inventory_2_outlined,
            size: 20,
            color: Colors.white,
          ),
          title: Text(
            'Complete Video Details (A - Z Technical Inventory)',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: TWTypography.brandFamily,
            ),
          ),
          subtitle: Text(
            'Technical specifications, adaptive streaming profiles, content rights, & storage artifacts.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          children: [
            const Divider(color: AppColors.bgDivider, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section A: Video Identifiers & Core Metadata
                  _buildSectionHeader('1. Core Identifiers & Metadata', Icons.fingerprint_rounded),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    label: 'Video ID',
                    value: video.id,
                    onCopy: () => _copyToClipboard(video.id, 'Video ID'),
                  ),
                  _buildMetaRow(
                    label: 'Channel ID',
                    value: video.channelId,
                    onCopy: () => _copyToClipboard(video.channelId, 'Channel ID'),
                  ),
                  _buildMetaRow(label: 'Upload Timestamp', value: uploadDate),
                  _buildMetaRow(label: 'Duration', value: durationFormatted),
                  _buildMetaRow(
                    label: 'Format / Aspect Ratio',
                    value: video.isShort
                        ? 'TruthShort (9:16 Vertical Video)'
                        : 'Standard (16:9 Landscape Video)',
                  ),
                  _buildMetaRow(
                    label: 'Content Category',
                    value: video.category.isNotEmpty ? video.category : 'General',
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.bgDivider, height: 1),
                  const SizedBox(height: 16),

                  // Section B: Transcoding & Adaptive Streaming Formats
                  _buildSectionHeader('2. Transcoding & Streaming Resolutions', Icons.high_quality_rounded),
                  const SizedBox(height: 8),
                  _buildResolutionsRow(video),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    label: 'HLS Master Playlist',
                    value: video.hlsUrl.isNotEmpty
                        ? 'Available (Adaptive Bitrate Ready)'
                        : 'Single Bitrate MP4',
                  ),
                  _buildMetaRow(
                    label: 'Pipeline State',
                    value: video.status.name.toUpperCase(),
                    badgeColor: video.status.name == 'ready' || video.status.name == 'published'
                        ? AppColors.success
                        : AppColors.warning,
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.bgDivider, height: 1),
                  const SizedBox(height: 16),

                  // Section C: Distribution, Rights & Community Permissions
                  _buildSectionHeader('3. Distribution, Rights & Engagement', Icons.shield_outlined),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    label: 'Visibility',
                    value: video.visibility.toUpperCase(),
                    badgeColor: video.visibility.toLowerCase() == 'public'
                        ? AppColors.success
                        : AppColors.info,
                  ),
                  _buildMetaRow(
                    label: 'Monetization Status',
                    value: video.isMonetized ? 'Active (Monetized)' : 'Standard (Unmonetized)',
                  ),
                  _buildMetaRow(
                    label: 'Community Comments',
                    value: video.enableComments ? 'Enabled (Open Discussion)' : 'Disabled',
                  ),
                  _buildMetaRow(
                    label: 'Video Clipping / Remixing',
                    value: video.allowClipping ? 'Allowed by Creator' : 'Restricted',
                  ),
                  _buildMetaRow(
                    label: 'Like / Dislike Counts',
                    value: video.showLikeCount ? 'Visible to Viewers' : 'Hidden by Creator',
                  ),
                  _buildMetaRow(
                    label: 'Audience Classification',
                    value: video.isKidFriendly
                        ? 'Certified Kid-Friendly (COPPA Compliant)'
                        : 'Standard Audience (Not Made for Kids)',
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.bgDivider, height: 1),
                  const SizedBox(height: 16),

                  // Section D: Direct Cloud Storage Artifacts
                  _buildSectionHeader('4. Cloud Storage & Direct Artifacts', Icons.cloud_done_outlined),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    label: 'Source Storage URL',
                    value: video.originalUrl.isNotEmpty ? video.originalUrl : 'N/A',
                    onCopy: video.originalUrl.isNotEmpty
                        ? () => _copyToClipboard(video.originalUrl, 'Source Storage URL')
                        : null,
                  ),
                  _buildMetaRow(
                    label: 'Speech Transcript',
                    value: video.transcriptionUrl.isNotEmpty && !video.transcriptionUrl.contains('placeholder')
                        ? 'Generated (Stored in GCS)'
                        : 'Not Available',
                    badgeColor: video.transcriptionUrl.isNotEmpty && !video.transcriptionUrl.contains('placeholder')
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  _buildMetaRow(
                    label: 'Fact-Check JSON Disclosure',
                    value: video.factCheckUrl.isNotEmpty
                        ? 'Available (Stored in GCS)'
                        : 'Not Generated',
                    badgeColor: video.factCheckUrl.isNotEmpty
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.labelMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow({
    required String label,
    required String value,
    VoidCallback? onCopy,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (badgeColor != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      value,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 11,
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (onCopy != null)
                  InkWell(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionsRow(Video video) {
    final availableLabels = video.adaptiveResolutions
        .map((r) => r.label.toLowerCase().replaceAll('p', ''))
        .toSet();
    const standardProfiles = ['1080', '720', '480', '360'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              'Transcoded Resolutions',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: standardProfiles.map((res) {
                final isAvailable = availableLabels.contains(res);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.bgSurfaceHover,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isAvailable
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.bgDivider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle_rounded : Icons.pending_outlined,
                        size: 11,
                        color: isAvailable ? AppColors.success : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        res,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? AppColors.success : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.info('$label copied to clipboard');
  }
}
