import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_dialogs.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet displaying detailed information about a copyright claim.
class ClaimDetailsBottomSheet extends StatelessWidget {
  const ClaimDetailsBottomSheet({
    required this.data,
    required this.isDarkMode,
    super.key,
  });

  final Map<String, dynamic> data;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final videoAffected = (data['videoTitle'] ?? 'Unknown').toString();
    final claimType = (data['noticeType'] ?? 'Content ID').toString();
    final claimant = (data['claimant'] ?? 'Rights Holder').toString();
    final policy = (data['policy'] ?? 'Monetized by claimant').toString();
    final claimId = (data['id'] ?? data['claimId'] ?? '').toString();

    final bgColor = isDarkMode ? AppColors.bgSurface : Colors.white;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.copyright,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Claim Details',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: primaryTextColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Channel Impact Notice Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Channel not affected: Content ID claims do not count toward copyright strikes.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            _buildDetailRow('Video affected', videoAffected, primaryTextColor, secondaryTextColor),
            _buildDetailRow('Claim type', claimType, primaryTextColor, secondaryTextColor),
            _buildDetailRow('Claimant', claimant, primaryTextColor, secondaryTextColor),
            _buildDetailRow('Policy', policy, primaryTextColor, secondaryTextColor),

            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
            ),
            const SizedBox(height: 16),

            // Action row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(
                        color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade400,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      CopyrightDialogs.showDisputeClaim(
                        context: context,
                        claimId: claimId.isNotEmpty ? claimId : videoAffected,
                        videoTitle: videoAffected,
                        claimant: claimant,
                        isDarkMode: isDarkMode,
                      );
                    },
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: const Text(
                      'Dispute Claim',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 12,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
