import 'package:flutter/material.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Header row for the comparison table.
TableRow buildPremiumTableHeaderRow() {
  return const TableRow(
    decoration: BoxDecoration(color: buttonBg),
    children: [
      Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Features',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Free',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: secondaryText,
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Premium',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
    ],
  );
}

/// Data row for the comparison table.
TableRow buildPremiumTableRow(
  String feature,
  String freeVal,
  String premiumVal,
) {
  return TableRow(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          feature,
          style: const TextStyle(
            fontSize: 14,
            color: secondaryText,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          freeVal,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          premiumVal,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
    ],
  );
}

/// Section comparing Free vs Premium tier benefits.
class PremiumComparisonSection extends StatelessWidget {
  const PremiumComparisonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compare Free vs Premium',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(1.2),
              },
              children: [
                buildPremiumTableHeaderRow(),
                buildPremiumTableRow(
                  'Ad-Free Audio Mode',
                  'With Ads',
                  r'Ad-Free ($0.50, $2, $3)',
                ),
                buildPremiumTableRow(
                  'Ad-Free Video Playback',
                  'With Ads',
                  r'Ad-Free ($2, $3)',
                ),
                buildPremiumTableRow(
                  'Every Video Fact-Checked',
                  'Standard',
                  r'Every Video Verified ($3)',
                ),
                buildPremiumTableRow(
                  'On-Demand User Fact-Check',
                  'No',
                  r'User Can Fact-Check ($3)',
                ),
                buildPremiumTableRow(
                  'Offline Downloads',
                  'No',
                  r'Unlimited ($2, $3)',
                ),
                buildPremiumTableRow(
                  'Background & PiP Play',
                  'No',
                  r'Included ($2, $3)',
                ),
                buildPremiumTableRow(
                  'Stream Quality',
                  'Up to 1080p',
                  r'4K Ultra HD ($2, $3)',
                ),
                buildPremiumTableRow(
                  'Multilingual AI Dubbing',
                  'Basic',
                  r'Unlocked ($2, $3)',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
