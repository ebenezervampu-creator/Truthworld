import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildAudienceGenderDemographicsCard({
  required AudienceController controller,
  required bool isDarkMode,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
  final genderMap = controller.genderDistribution;
  final malePct = genderMap['Male'] ?? 0.0;
  final femalePct = genderMap['Female'] ?? 0.0;
  final otherPct = genderMap['User specified / Other'] ?? 0.0;
  final hasGenderData = (malePct + femalePct + otherPct) > 0;

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
                Icons.people_outline_rounded,
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
                    'Viewer Gender Distribution',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Proportional viewer demographic breakdown',
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
        const SizedBox(height: 20),

        // Multi-color segmented progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: hasGenderData
                ? Row(
                    children: [
                      if (malePct > 0)
                        Expanded(
                          flex: (malePct * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.info),
                        ),
                      if (femalePct > 0)
                        Expanded(
                          flex: (femalePct * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.brandVariant),
                        ),
                      if (otherPct > 0)
                        Expanded(
                          flex: (otherPct * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.warning),
                        ),
                    ],
                  )
                : Container(color: AppColors.progressTrack),
          ),
        ),
        const SizedBox(height: 20),

        // Breakdown Items
        buildAudienceGenderLegendItem(
          label: 'Male',
          percentage: malePct,
          color: AppColors.info,
          icon: Icons.male_rounded,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
        const SizedBox(height: 12),
        buildAudienceGenderLegendItem(
          label: 'Female',
          percentage: femalePct,
          color: AppColors.brandVariant,
          icon: Icons.female_rounded,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
        const SizedBox(height: 12),
        buildAudienceGenderLegendItem(
          label: 'User specified / Other',
          percentage: otherPct,
          color: AppColors.warning,
          icon: Icons.transgender_rounded,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
        if (!hasGenderData) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viewer gender distribution updates dynamically as audience members complete their profiles.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: subtitleColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

Widget buildAudienceGenderLegendItem({
  required String label,
  required double percentage,
  required Color color,
  required IconData icon,
  required Color textColor,
  required Color subtitleColor,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
      Text(
        '${percentage.toStringAsFixed(1)}%',
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    ],
  );
}
