import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card displaying the list of channels associated with the user.
class UserChannelsCard extends StatelessWidget {
  final List channels;

  const UserChannelsCard({
    required this.channels,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Associated Channels',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...channels.map((ch) {
            final chData = ch is Map ? ch : {};
            final chName = chData['name'] ?? chData['channelName'] ?? 'Channel';
            final handle = chData['handle'] ?? chData['username'] ?? '';
            final subs = chData['subscriberCount'] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.tv, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$chName ${handle.isNotEmpty ? "(@$handle)" : ""}',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$subs subs',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Card showing the user's trust score and standing assessment.
class UserTrustScoreCard extends StatelessWidget {
  final int score;

  const UserTrustScoreCard({
    required this.score,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor = Colors.red;
    var assessment = 'High Risk';
    if (score >= 75) {
      scoreColor = Colors.green;
      assessment = 'Good Standing';
    } else if (score >= 40) {
      scoreColor = Colors.amber;
      assessment = 'Moderate Risk';
    } else if (score >= 10) {
      scoreColor = Colors.orange;
      assessment = 'Flagged';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trust Score',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                assessment,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: scoreColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scoreColor),
            ),
            child: Text(
              score.toString(),
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: scoreColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing the user's strike count.
class UserStrikeCountCard extends StatelessWidget {
  final int strikes;

  const UserStrikeCountCard({
    required this.strikes,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recorded Strikes',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            strikes.toString(),
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: strikes > 0 ? AppColors.error : Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing the user's upload statistics, approval rate, and rejection rate.
class UserUploadStatisticsCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const UserUploadStatisticsCard({
    required this.stats,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final totalUploads = stats['totalUploads'] ?? 0;
    final approvalRate = stats['approvalRate'] ?? 100;
    final rejectionRate = stats['rejectionRate'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Activity Statistics',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Uploads:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '$totalUploads',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Approval Rate:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '$approvalRate%',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rejection Rate:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '$rejectionRate%',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
