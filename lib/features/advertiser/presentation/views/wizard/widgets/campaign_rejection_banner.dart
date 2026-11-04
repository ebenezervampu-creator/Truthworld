import 'package:flutter/material.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Rejection alert banner displayed when editing a previously rejected campaign.
class CampaignRejectionBanner extends StatelessWidget {
  final AdItem? existingCampaign;

  const CampaignRejectionBanner({
    required this.existingCampaign,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (existingCampaign?.status != 'verification_rejected') {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campaign Rejected - Action Required',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  existingCampaign?.moderationReason ??
                      'Please update your campaign details below to address the violation and resubmit.',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
