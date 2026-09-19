import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Row of 3 animated score rings (TRUTH, HONESTY, LOGIC).
class FactCheckMetricsRow extends StatelessWidget {
  const FactCheckMetricsRow({
    required this.truth,
    required this.honesty,
    required this.rationality,
    super.key,
  });

  final double truth;
  final double honesty;
  final double rationality;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        FactCheckMetricRing(
          label: 'TRUTH',
          score: truth,
          color: AppColors.success,
          icon: Icons.fact_check_outlined,
        ),
        FactCheckMetricRing(
          label: 'HONESTY',
          score: honesty,
          color: AppColors.info,
          icon: Icons.face_outlined,
        ),
        FactCheckMetricRing(
          label: 'LOGIC',
          score: rationality,
          color: AppColors.brandHover,
          icon: Icons.psychology_outlined,
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }
}

/// Circular progress metric indicator ring with score and label.
class FactCheckMetricRing extends StatelessWidget {
  const FactCheckMetricRing({
    required this.label,
    required this.score,
    required this.color,
    required this.icon,
    super.key,
  });

  final String label;
  final double score;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 4,
                backgroundColor: AppColors.bgDivider,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Icon(icon, color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${score.toInt()}%',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Confidence progress bar with gradient and shimmer.
class FactCheckConfidenceBar extends StatelessWidget {
  const FactCheckConfidenceBar({
    required this.confidence,
    super.key,
  });

  final double confidence;

  @override
  Widget build(BuildContext context) {
    // confidence is 0.0 to 1.0
    final value = confidence > 1.0 ? confidence / 100 : confidence;
    final color = value >= 0.8
        ? AppColors.success
        : (value >= 0.5 ? AppColors.warning : AppColors.error);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ANALYSIS CONFIDENCE',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgDivider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: 1000.ms,
              height: 6,
              width: (MediaQuery.of(context).size.width - 48) * value,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.5), color],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
                ],
              ),
            ).animate().shimmer(delay: 500.ms, duration: 2000.ms),
          ],
        ),
      ],
    );
  }
}

/// Row displaying total claims and verified counts.
class FactCheckStatsRow extends StatelessWidget {
  const FactCheckStatsRow({
    required this.stats,
    super.key,
  });

  final Map<dynamic, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FactCheckStatCard(
          label: 'Total Claims',
          value: '${stats['totalClaims'] ?? 0}',
          icon: Icons.article_outlined,
          color: AppColors.info,
        ),
        const SizedBox(width: 12),
        FactCheckStatCard(
          label: 'Verified',
          value: '${stats['correct'] ?? stats['verifiedClaims'] ?? 0}',
          icon: Icons.check_circle_outlined,
          color: AppColors.success,
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }
}

/// Stat card container displaying icon, value, and label.
class FactCheckStatCard extends StatelessWidget {
  const FactCheckStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTextStyles.titleLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
