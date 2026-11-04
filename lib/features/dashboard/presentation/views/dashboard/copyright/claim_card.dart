import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/claim_details_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_dialogs.dart';
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
    final videoTitle = (data['videoTitle'] ??
            data['channelName'] ??
            data['name'] ??
            'Unknown Content')
        .toString();
    final claimType = (data['noticeType'] ?? 'Copyright Notice').toString();
    final claimant =
        (data['claimant'] ?? data['owner'] ?? 'Rights Holder').toString();
    final impact = (data['impact'] ??
            (data['actionRequired'] == true
                ? 'Action Required'
                : 'No Impact'))
        .toString();
    final date = CopyrightFormatters.formatDate(
      data['date'] ?? data['createdAt'],
    );
    final claimId = (data['id'] ?? data['claimId'] ?? '').toString();

    final cardBg = isDarkMode ? AppColors.bgSurface : Colors.white;
    final borderColor =
        isDarkMode ? AppColors.bgDivider : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                // Top Row: Thumbnail + Video Title + Claim Type + Chevron
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 88,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.bgSurfaceHigh
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.bgDivider
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 22,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                          Positioned(
                            bottom: 3,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'HD',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            videoTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  claimType,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontSize: 12,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: isDarkMode
                          ? AppColors.textTertiary
                          : Colors.grey.shade400,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
                ),
                const SizedBox(height: 12),

                // Bottom Meta Info: Claimant | Impact | Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniInfo('Claimant', claimant),
                    _buildMiniInfo('Impact', impact),
                    _buildMiniInfo('Date', date),
                  ],
                ),

                const SizedBox(height: 12),
                // Direct Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showClaimDetails(context),
                      icon: const Icon(Icons.info_outline, size: 15),
                      label: const Text('See Details'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
                        textStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => CopyrightDialogs.showDisputeClaim(
                        context: context,
                        claimId: claimId.isNotEmpty ? claimId : videoTitle,
                        videoTitle: videoTitle,
                        claimant: claimant,
                        isDarkMode: isDarkMode,
                      ),
                      icon: const Icon(Icons.gavel_outlined, size: 14),
                      label: const Text('Dispute'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDarkMode ? AppColors.textPrimary : Colors.black87,
                        side: BorderSide(
                          color: isDarkMode
                              ? AppColors.bgDivider
                              : Colors.grey.shade400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 11,
            color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 90,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.textSecondary : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
