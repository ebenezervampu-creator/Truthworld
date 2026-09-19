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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.bgDivider
              : AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      child: InkWell(
        onTap: () => _showClaimDetails(context),
        borderRadius: BorderRadius.circular(12),
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
                      color: isDarkMode
                          ? AppColors.textPrimary.withValues(alpha: 0.05)
                          : AppColors.bgPage.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.video_library_outlined,
                      size: 20,
                      color: isDarkMode ? Colors.white : Colors.black87,
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
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claimType,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isDarkMode ? Colors.white : Colors.black87,
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
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: isDarkMode
                ? AppColors.textTertiary
                : AppColors.textSecondary,
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
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 12,
              color: isDarkMode ? AppColors.textSecondary : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
