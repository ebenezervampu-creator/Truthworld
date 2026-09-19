import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Platform overview bar displaying total user, video, channel, report, appeal, and banned counts.
class AdminAnalyticsPlatformOverviewBar extends StatelessWidget {
  const AdminAnalyticsPlatformOverviewBar({
    required this.data,
    super.key,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final totals = data['platformTotals'] as Map<String, dynamic>? ?? {};
    final users = totals['totalUsers'] ?? 0;
    final videos = totals['totalVideos'] ?? 0;
    final channels = totals['totalChannels'] ?? 0;
    final reports = totals['totalReports'] ?? 0;
    final appeals = totals['totalAppeals'] ?? 0;
    final banned = totals['bannedUsers'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        alignment: WrapAlignment.spaceAround,
        children: [
          AdminAnalyticsStatChip(
            label: 'Total Users',
            count: '$users',
            icon: Icons.people_alt_outlined,
          ),
          AdminAnalyticsStatChip(
            label: 'Total Videos',
            count: '$videos',
            icon: Icons.video_library_outlined,
          ),
          AdminAnalyticsStatChip(
            label: 'Total Channels',
            count: '$channels',
            icon: Icons.account_circle_outlined,
          ),
          AdminAnalyticsStatChip(
            label: 'Total Reports',
            count: '$reports',
            icon: Icons.flag_outlined,
          ),
          AdminAnalyticsStatChip(
            label: 'Content Appeals',
            count: '$appeals',
            icon: Icons.gavel_outlined,
          ),
          AdminAnalyticsStatChip(
            label: 'Banned Accounts',
            count: '$banned',
            icon: Icons.block_flipped,
          ),
        ],
      ),
    );
  }
}

/// Stat chip showing metric icon, formatted counter, and label.
class AdminAnalyticsStatChip extends StatelessWidget {
  const AdminAnalyticsStatChip({
    required this.label,
    required this.count,
    required this.icon,
    super.key,
  });

  final String label;
  final String count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
