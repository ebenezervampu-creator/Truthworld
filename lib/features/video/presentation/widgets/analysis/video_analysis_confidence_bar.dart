import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

  class VideoAnalysisConfidenceBar extends StatelessWidget {
  final double value;

  const VideoAnalysisConfidenceBar({required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final color = clamped >= 0.75
        ? AppColors.success
        : (clamped >= 0.45 ? AppColors.warning : AppColors.error);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SYSTEM CONFIDENCE',
              style: context.twTypography.overline.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${(clamped * 100).toInt()}%',
              style: context.twTypography.label.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.5), color],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

}
