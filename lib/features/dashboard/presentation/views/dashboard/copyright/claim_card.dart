import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/claim_details_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_formatters.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive card component displaying a single copyright claim item.
class ClaimCard extends StatelessWidget {
  const ClaimCard({
    required this.data,
    required this.isDarkMode,
    super.key,
  });

  final Map<String, dynamic> data;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final videoTitle =
        (data['videoTitle'] ??
                data['channelName'] ??
                data['name'] ??
                'Unknown Content')
            .toString();
    final claimType = (data['noticeType'] ?? 'Copyright Notice').toString();
    final claimant = (data['claimant'] ?? data['owner'] ?? 'Rights Holder')
        .toString();
    final impact =
        (data['impact'] ??
                (data['actionRequired'] == true
                    ? 'Action Required'
                    : 'No Impact'))
            .toString();
    final date = CopyrightFormatters.formatDate(
      data['date'] ?? data['createdAt'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showClaimDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 45,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: const Icon(
                        Icons.video_library_outlined,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            videoTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            claimType,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.bgDivider),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniInfo('Claimant', claimant),
                    _buildMiniInfo('Impact', impact),
                    _buildMiniInfo('Date', date),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClaimDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: Get.context ?? context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          ClaimDetailsBottomSheet(data: data, isDarkMode: isDarkMode),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 80,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
