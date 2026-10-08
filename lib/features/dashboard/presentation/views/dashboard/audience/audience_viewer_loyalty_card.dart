import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildAudienceViewerLoyaltyAndSettingCard({
  required AudienceController controller,
  required bool isDarkMode,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
  final retPct = controller.returningPercentage;
  final newPct = controller.newViewersPercentage;
  final urban = controller.urbanPercentage.value;
  final rural = controller.ruralPercentage.value;

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
                Icons.loyalty_rounded,
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
                    'Audience Loyalty & Reach Setting',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Retention behavior and geographic community reach',
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

        // Returning vs New Viewers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'New Viewers vs Returning Viewers',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  color: subtitleColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${newPct.toStringAsFixed(0)}% New / ${retPct.toStringAsFixed(0)}% Ret',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: (newPct > 0 || retPct > 0)
                ? Row(
                    children: [
                      if (newPct > 0)
                        Expanded(
                          flex: (newPct * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.info),
                        ),
                      if (retPct > 0)
                        Expanded(
                          flex: (retPct * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.brandVariant),
                        ),
                    ],
                  )
                : Container(color: AppColors.progressTrack),
          ),
        ),
        const SizedBox(height: 20),

        // Urban vs Rural Scope
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Urban vs Rural Reach',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  color: subtitleColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${urban.toStringAsFixed(0)}% Urban / ${rural.toStringAsFixed(0)}% Rural',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: (urban > 0 || rural > 0)
                ? Row(
                    children: [
                      if (urban > 0)
                        Expanded(
                          flex: (urban * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.success),
                        ),
                      if (rural > 0)
                        Expanded(
                          flex: (rural * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.warning),
                        ),
                    ],
                  )
                : Container(color: AppColors.progressTrack),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            buildAudienceSmallBadge(
              label:
                  '${NumberFormat.compact().format(controller.returningViewers.value)} Returning',
              color: AppColors.brandVariant,
              textColor: textColor,
            ),
            const SizedBox(width: 8),
            buildAudienceSmallBadge(
              label:
                  '${NumberFormat.compact().format(controller.newViewers)} New',
              color: AppColors.info,
              textColor: textColor,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildAudienceSmallBadge({
  required String label,
  required Color color,
  required Color textColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: TWTypography.uiFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    ),
  );
}
