import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 4 Core metric summary cards for the Admin Analytics dashboard.
class AdminAnalyticsMetricsCards extends StatelessWidget {
  const AdminAnalyticsMetricsCards({
    required this.constraints,
    required this.data,
    super.key,
  });

  final BoxConstraints constraints;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final isSmall = constraints.maxWidth < 900;
    final cardWidth =
        isSmall ? constraints.maxWidth : (constraints.maxWidth - 48) / 4;

    final safetyScore = data['safetyScore'] ?? 100;
    final totalModerated =
        data['totalModerated'] ?? data['totalModerated24h'] ?? 0;
    final autoApprovalRate =
        data['autoApprovalRate'] ?? data['autoApproveRate'] ?? 100;
    final activeViolations = data['activeViolations'] ?? 0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        AdminAnalyticsMetricCard(
          title: 'Platform Safety Score',
          value: '$safetyScore/100',
          subtitle: safetyScore >= 80
              ? 'Optimal Platform Health'
              : (safetyScore >= 50
                  ? 'Moderate Risk'
                  : 'High Risk Backlog'),
          color: safetyScore >= 80
              ? const Color(0xFF4CAF50)
              : (safetyScore >= 50 ? Colors.amber : AppColors.error),
          icon: Icons.shield_outlined,
          width: cardWidth,
        ),
        AdminAnalyticsMetricCard(
          title: 'Total Content Moderated',
          value: '$totalModerated',
          subtitle: 'Videos, Posts, Media & Reports',
          color: AppColors.textPrimary,
          icon: Icons.fact_check_outlined,
          width: cardWidth,
        ),
        AdminAnalyticsMetricCard(
          title: 'Auto-Approved Rate',
          value: '$autoApprovalRate%',
          subtitle: 'Clean Content Pass Rate',
          color: const Color(0xFF42A5F5),
          icon: Icons.verified_user_outlined,
          width: cardWidth,
        ),
        AdminAnalyticsMetricCard(
          title: 'Active Violations',
          value: '$activeViolations',
          subtitle: activeViolations > 0
              ? 'Pending action or unresolved reports'
              : 'Zero active violations',
          color:
              activeViolations > 0 ? AppColors.error : const Color(0xFF4CAF50),
          icon: Icons.warning_amber_rounded,
          width: cardWidth,
        ),
      ],
    );
  }
}

/// Single metric card container with title, value, subtitle, icon, and dynamic color accent.
class AdminAnalyticsMetricCard extends StatelessWidget {
  const AdminAnalyticsMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.width,
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
