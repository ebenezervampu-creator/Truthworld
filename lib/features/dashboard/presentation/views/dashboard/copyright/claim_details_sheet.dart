import 'package:flutter/material.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Claim details',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: 20,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Video affected', videoAffected),
          _buildDetailRow('Claim type', claimType),
          _buildDetailRow('Claimant', claimant),
          _buildDetailRow('Policy', policy),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
