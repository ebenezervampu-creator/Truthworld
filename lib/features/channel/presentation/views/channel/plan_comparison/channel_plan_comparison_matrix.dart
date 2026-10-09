import 'package:flutter/material.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_comparison/channel_plan_comparison_models.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Detailed comparison matrix showing side-by-side breakdown for each feature.
class PlanComparisonMatrixWidget extends StatelessWidget {
  const PlanComparisonMatrixWidget({
    required this.isDesktop,
    required this.isDark,
    super.key,
  });

  final bool isDesktop;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                color: Color(0xFF818CF8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detailed Feature Comparison',
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Every metric compared side-by-side across both plans',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Section Blocks
        ...ChannelPlanComparisonData.sections.map((section) {
          return _buildSectionCard(section);
        }),
      ],
    );
  }

  Widget _buildSectionCard(PlanComparisonSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                Icon(section.icon, size: 20, color: const Color(0xFF818CF8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        section.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.bgDivider),
          // Features
          ...section.features.map((feature) {
            return _buildFeatureRow(feature);
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(PlanComparisonFeature feature) {
    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFF1F5F9),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Feature Name & details
            Expanded(
              flex: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (feature.icon != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        feature.icon,
                        size: 16,
                        color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                          ),
                        ),
                        if (feature.details != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              feature.details!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Standard Value
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: feature.standardWins
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: feature.standardWins
                      ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3))
                      : null,
                ),
                child: Text(
                  feature.standardValue,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: feature.standardWins ? FontWeight.bold : FontWeight.w500,
                    color: feature.standardWins
                        ? const Color(0xFF60A5FA)
                        : (isDark ? AppColors.textPrimary : const Color(0xFF334155)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Custom Value
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: feature.customWins
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: feature.customWins
                      ? Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        feature.customValue,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: feature.customWins ? FontWeight.bold : FontWeight.w500,
                          color: feature.customWins
                              ? const Color(0xFFA78BFA)
                              : (isDark ? AppColors.textPrimary : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                    if (feature.customWins)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Color(0xFFA78BFA),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout: Stacked cards
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (feature.icon != null) ...[
                Icon(
                  feature.icon,
                  size: 15,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          if (feature.details != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                feature.details!,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                ),
              ),
            ),
          const SizedBox(height: 6),
          // Standard & Custom values stacked on mobile
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Standard',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feature.standardValue,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2E1065).withValues(alpha: 0.3)
                        : const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feature.customValue,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: feature.customWins ? FontWeight.w600 : FontWeight.normal,
                          color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
