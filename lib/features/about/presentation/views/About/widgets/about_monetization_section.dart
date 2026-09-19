import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section detailing TruthWorld's creator-first revenue split and monetization architecture.
class AboutMonetizationSection extends StatelessWidget {
  const AboutMonetizationSection({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    super.key,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    final revenueCards = [
      _buildRevenueCard(
        '100%',
        'Net Ad Revenue to Creators',
        'Creators receive 100% of video ad earnings, deducting only transparent pass-through bandwidth and infrastructure costs.',
      ),
      _buildRevenueCard(
        '75%',
        'Subscription Revenue to Creators',
        'Direct creator support with 75% going to creators and 25% allocated for platform infrastructure and continuous AI research.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Creator-First Monetization',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A fair, transparent revenue model that treats creators as equal partners.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 44),
          if (isDesktop)
            Row(
              children: [
                Expanded(child: revenueCards[0]),
                const SizedBox(width: 20),
                Expanded(child: revenueCards[1]),
              ],
            )
          else
            Column(
              children: [
                revenueCards[0],
                const SizedBox(height: 16),
                revenueCards[1],
              ],
            ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: const Text(
              'Truthworld sustains platform operations through strategic non-intrusive discovery placements, preserving creator margins without compromise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard(String pct, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            pct,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 44,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
