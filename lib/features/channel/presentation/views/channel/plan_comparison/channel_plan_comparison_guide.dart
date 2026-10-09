import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Recommendation guide helping creators choose between Standard and Custom.
class PlanRecommendationGuideCard extends StatelessWidget {
  const PlanRecommendationGuideCard({
    required this.isDesktop,
    required this.isDark,
    super.key,
  });

  final bool isDesktop;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final standardCard = _buildRecommendationBox(
      title: 'Choose Standard Channel If:',
      badge: 'BEST FOR STARTING OUT',
      badgeColor: const Color(0xFF3B82F6),
      icon: Icons.check_circle_outline_rounded,
      points: const [
        'You want \$0 upfront commitment and zero monthly hosting fees.',
        'You upload short or medium videos within the 10 min/day daily quota.',
        'You are comfortable with 70% rev-share on ads and premium views.',
        'You want TruthWorld to handle all storage, CDN bandwidth, and transcoding.',
        'You want 100% direct fan funding (Superchats & Memberships) at 0% fee.',
      ],
      isDark: isDark,
    );

    final customCard = _buildRecommendationBox(
      title: 'Choose Custom Channel If:',
      badge: 'MAXIMUM EARNING POWER',
      badgeColor: const Color(0xFF8B5CF6),
      icon: Icons.rocket_launch_outlined,
      points: const [
        'You want 100% gross revenue retention on ALL advertising and subscriptions.',
        'You upload long-form content, podcasts, documentaries, or movies (up to 24 hours).',
        'You need unlimited video uploads per day without daily duration limits.',
        'You want dedicated cloud storage (50 GB to 800 GB+) and global CDN bandwidth.',
        'You have an existing following or plan to scale a professional media business.',
      ],
      isDark: isDark,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFF34D399),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which Channel Type is Right for You?',
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quick decision checklist based on your content strategy',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: standardCard),
              const SizedBox(width: 16),
              Expanded(child: customCard),
            ],
          )
        else
          Column(
            children: [
              standardCard,
              const SizedBox(height: 16),
              customCard,
            ],
          ),
      ],
    );
  }

  static Widget _buildRecommendationBox({
    required String title,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required List<String> points,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(icon, size: 20, color: badgeColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...points.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: badgeColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                      ),
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

/// Frequently asked questions about Standard vs Custom channel tiers.
class PlanComparisonFaqWidget extends StatelessWidget {
  const PlanComparisonFaqWidget({
    required this.isDark,
    super.key,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'Can I change my channel plan later?',
        'a':
            'Yes! You can switch or upgrade between Standard and Custom anytime directly in Channel Settings. Your existing videos, subscribers, and comments remain intact.',
      },
      {
        'q': 'Why does Custom Channel charge an infrastructure fee?',
        'a':
            r'Custom channels keep 100% of all gross ad revenue and premium subscriptions (TruthWorld takes 0% commission). To sustain this without rev-share cuts, infrastructure plans ($15, $30, $45, $100, $200/mo) cover raw cloud storage and CDN bandwidth transparently at cost.',
      },
      {
        'q': 'How does the 10 min/day upload limit on Standard work?',
        'a':
            'Standard channels receive a daily budget of 10 minutes of video. You can upload one 10-minute video, or split it into several shorter videos (e.g. two 5-minute videos or three 3-minute videos). The allowance resets every 24 hours.',
      },
      {
        'q': 'How does cash withdrawal work for each plan?',
        'a':
            'Standard channels can cash out once overall account earnings reach the \$100 threshold. Custom channels unlock cash withdrawals on a per-video basis once each video reaches 1,000 views and 10 hours watch time, with 100% creator retention.',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.quiz_outlined,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 10),
          ...faqs.map((faq) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq['q']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    faq['a']!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
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
