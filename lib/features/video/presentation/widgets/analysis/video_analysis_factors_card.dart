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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
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
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ...factors.entries.map((e) {
            final key = e.key.toString();
            final val = e.value;
            final label = VideoAnalysisHelpers.formatFactorKey(key);
            final numVal = (val is num) ? val.toDouble() : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: context.twTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    numVal <= 5.0 && numVal > 0
                        ? '${numVal.toStringAsFixed(1)} / 5.0'
                        : (numVal > 5 ? '${numVal.toInt()}%' : val.toString()),
                    style: context.twTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: TWTypography.uiFamily,
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
