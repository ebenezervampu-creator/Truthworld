import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Moderation funnel queue cards showing approved, rejected, and pending content breakdown.
class AdminAnalyticsContentFunnel extends StatelessWidget {
  const AdminAnalyticsContentFunnel({
    required this.constraints,
    required this.data,
    super.key,
  });

  final BoxConstraints constraints;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final breakdown = data['breakdown'] as Map<String, dynamic>? ?? {};
    final vStats = breakdown['videos'] as Map<String, dynamic>? ?? {};
    final mStats = breakdown['media'] as Map<String, dynamic>? ?? {};
    final cStats = breakdown['channels'] as Map<String, dynamic>? ?? {};
    final rStats = breakdown['reports'] as Map<String, dynamic>? ?? {};
    final aStats = breakdown['appeals'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content Moderation Funnel',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Breakdown of review actions and compliance statuses across queues',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AdminAnalyticsFunnelCard(
                  title: 'Videos Queue',
                  total: vStats['total'] ?? 0,
                  approved: vStats['approved'] ?? 0,
                  rejected: vStats['rejected'] ?? 0,
                  pending: vStats['pending'] ?? 0,
                  icon: Icons.video_collection_outlined,
                ),
                const SizedBox(width: 16),
                AdminAnalyticsFunnelCard(
                  title: 'Media & Posts',
                  total: mStats['total'] ?? 0,
                  approved: mStats['approved'] ?? 0,
                  rejected: mStats['rejected'] ?? 0,
                  pending: mStats['pending'] ?? 0,
                  icon: Icons.image_outlined,
                ),
                const SizedBox(width: 16),
                AdminAnalyticsFunnelCard(
                  title: 'Channels Queue',
                  total: cStats['total'] ?? 0,
                  approved: cStats['approved'] ?? 0,
                  rejected: cStats['rejected'] ?? 0,
                  pending: cStats['pending'] ?? 0,
                  icon: Icons.tv_outlined,
                ),
                const SizedBox(width: 16),
                AdminAnalyticsFunnelCard(
                  title: 'User Reports',
                  total: rStats['total'] ?? 0,
                  approved: rStats['resolved'] ?? 0,
                  rejected: rStats['dismissed'] ?? 0,
                  pending: rStats['pending'] ?? 0,
                  approvedLabel: 'Resolved',
                  rejectedLabel: 'Dismissed',
                  icon: Icons.report_problem_outlined,
                ),
                const SizedBox(width: 16),
                AdminAnalyticsFunnelCard(
                  title: 'Appeals',
                  total: aStats['total'] ?? 0,
                  approved: aStats['overturned'] ?? 0,
                  rejected: aStats['upheld'] ?? 0,
                  pending: aStats['pending'] ?? 0,
                  approvedLabel: 'Overturned',
                  rejectedLabel: 'Upheld',
                  icon: Icons.gavel_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single queue funnel card showing queue icon, title, total count, and sub-status rows.
class AdminAnalyticsFunnelCard extends StatelessWidget {
  const AdminAnalyticsFunnelCard({
    required this.title,
    required this.total,
    required this.approved,
    required this.rejected,
    required this.pending,
    required this.icon,
    this.approvedLabel = 'Approved',
    this.rejectedLabel = 'Rejected',
    super.key,
  });

  final String title;
  final int total;
  final int approved;
  final int rejected;
  final int pending;
  final IconData icon;
  final String approvedLabel;
  final String rejectedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$total',
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 8),
          AdminAnalyticsMiniStatusRow(
            label: approvedLabel,
            count: approved,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 4),
          AdminAnalyticsMiniStatusRow(
            label: rejectedLabel,
            count: rejected,
            color: AppColors.error,
          ),
          const SizedBox(height: 4),
          AdminAnalyticsMiniStatusRow(
            label: 'Pending',
            count: pending,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }
}

/// Mini status row displaying label and colored count.
class AdminAnalyticsMiniStatusRow extends StatelessWidget {
  const AdminAnalyticsMiniStatusRow({
    required this.label,
    required this.count,
    required this.color,
    super.key,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
