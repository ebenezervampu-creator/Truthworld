import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildAudienceAgeDemographicsCard({
  required AudienceController controller,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
  final ageMap = controller.ageDistribution;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viewer Age Groups',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Audience distribution by age brackets',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...ageMap.entries.map((entry) {
          final isTop = entry.value >= 30.0 && entry.value > 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                      color: isTop ? textColor : subtitleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value > 0
                          ? (entry.value / 100).clamp(0.01, 1.0)
                          : 0.0,
                      backgroundColor: AppColors.progressTrack,
                      valueColor: AlwaysStoppedAnimation(
                        isTop ? AppColors.brand : AppColors.progressBuffered,
                      ),
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${entry.value.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
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
