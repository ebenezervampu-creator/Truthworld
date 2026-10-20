import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildAudienceSearchBar({
  required AudienceController controller,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
  return Container(
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor),
    ),
    child: TextField(
      maxLength: 100,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: TruthworldTextInputFormatters.withLimit(100),
      style: TextStyle(
        fontFamily: TWTypography.uiFamily,
        color: textColor,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText:
            'Search global view matrix by Country Name or Code (e.g. United States, US, India, IN)...',
        hintStyle: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: subtitleColor,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onChanged: (val) => controller.updateSearchQuery(val),
    ),
  );
}

Widget buildAudienceCountryCard({
  required CountryAudienceItem item,
  required bool isDarkMode,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row Header: Country code & name
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                item.countryCode,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.countryName,
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Viewers bar meter breakdown
        buildAudienceGaugeRow(
          label: 'Country Viewers',
          count: item.viewers,
          percentage: item.viewerPercentage,
          color: AppColors.info,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
        const SizedBox(height: 12),
        // Subscribers bar meter breakdown
        buildAudienceGaugeRow(
          label: 'Mapped Subscribers',
          count: item.subscribers,
          percentage: item.subscriberPercentage,
          color: AppColors.brand,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
      ],
    ),
  );
}

Widget buildAudienceGaugeRow({
  required String label,
  required int count,
  required double percentage,
  required Color color,
  required Color textColor,
  required Color subtitleColor,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
          Row(
            children: [
              Text(
                NumberFormat.decimalPattern().format(count),
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    color: subtitleColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: percentage > 0 ? (percentage / 100).clamp(0.01, 1.0) : 0,
          backgroundColor: AppColors.progressTrack,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
        ),
      ),
    ],
  );
}
