import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

  class VideoAnalysisFactorsCard extends StatelessWidget {
  final Map<dynamic, dynamic> factors;

  const VideoAnalysisFactorsCard({required this.factors, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CREDIBILITY FACTORS',
            style: context.twTypography.overline.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textTertiary,
              letterSpacing: 1.0,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
          const SizedBox(height: 12),
          ...factors.entries.map((e) {
            final key = e.key.toString();
            final val = e.value;
            final label = VideoAnalysisHelpers.formatFactorKey(key);
            final numVal = (val is num) ? val.toDouble() : 0.0;
            final factorPercent = numVal <= 5.0 && numVal > 0
                ? (numVal / 5.0).clamp(0.0, 1.0)
                : (numVal > 5 ? (numVal / 100.0).clamp(0.0, 1.0) : 0.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: context.twTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontFamily: TWTypography.uiFamily,
                          ),
                        ),
                      ),
                      Text(
                        numVal <= 5.0 && numVal > 0
                            ? '${numVal.toStringAsFixed(1)} / 5.0'
                            : (numVal > 5 ? '${numVal.toInt()}%' : val.toString()),
                        style: context.twTypography.label.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                    ],
                  ),
                  if (factorPercent > 0) ...[
                    const SizedBox(height: 5),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: factorPercent),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, animVal, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Container(
                            height: 3.5,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.08),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: animVal,
                              child: Container(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

}
