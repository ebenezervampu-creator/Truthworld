import 'package:flutter/material.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildMembershipsStreamCard(RevenueAnalyticsController controller) {
  final income = controller.membershipsRevenue.value;
  final rawUsd = controller.originalUsdMemberships.value;
  final members = controller.activeMembersCount.value;
  final tiers = controller.activeTiersCount.value;
  final formattedAmount = controller.isViewingINR
      ? '₹${income.toStringAsFixed(2)}'
      : '\$${controller.membershipsRevenueUSD.value.toStringAsFixed(2)}';

  return buildStreamContainer(
    icon: Icons.card_membership_rounded,
    title: 'Channel Memberships & Fan Funding',
    subtitle: '$members Direct Supporter${members == 1 ? '' : 's'} • $tiers Active Tier${tiers == 1 ? '' : 's'}',
    amount: formattedAmount,
    badgeText: rawUsd > 0
        ? '100% Payout • Includes \$${rawUsd.toStringAsFixed(2)} USD'
        : '100% Direct Payout (0% Platform Fee)',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        buildSplitRow(
          label: 'Gross Recurring Income',
          value: rawUsd > 0
              ? '₹${income.toStringAsFixed(2)} (\$${rawUsd.toStringAsFixed(2)} USD)'
              : '₹${income.toStringAsFixed(2)}',
        ),
        if (rawUsd > 0) ...[
          const SizedBox(height: 6),
          buildSplitRow(
            label: 'Currency Conversion',
            value: '1 USD = ₹${RevenueAnalyticsController.usdToInrRate.toStringAsFixed(2)} INR (Live Market)',
          ),
        ],
        const SizedBox(height: 6),
        buildSplitRow(
          label: 'Platform Cut / Commission',
          value: '0.0% (₹0.00)',
        ),
        const SizedBox(height: 6),
        buildSplitRow(
          label: 'Creator Net Payout',
          value: '₹${income.toStringAsFixed(2)}',
          isBold: true,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: controller.navigateToMemberships,
            icon: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 16),
            label: const Text('Manage Memberships & Tiers'),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.bgSurfaceHover,
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildSuperchatStreamCard(RevenueAnalyticsController controller) {
  final amount = controller.superchatRevenue.value;
  final creatorCut = amount; // 100% Creator Retention (0% Platform Fee)

  return buildStreamContainer(
    icon: Icons.bolt_rounded,
    title: 'Superchats & Live Fan Support',
    subtitle:
        'Instant fan contributions and highlighted messages during live streams',
    amount: '₹${amount.toStringAsFixed(2)}',
    badgeText: '100% Direct Payout (0% Platform Fee)',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        buildSplitRow(
          label: 'Gross Live Earnings',
          value: '₹${amount.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 6),
        buildSplitRow(
          label: 'Platform Cut / Commission',
          value: '0.0% (₹0.00)',
        ),
        const SizedBox(height: 6),
        buildSplitRow(
          label: 'Creator Net Payout',
          value: '₹${creatorCut.toStringAsFixed(2)}',
          isBold: true,
        ),
      ],
    ),
  );
}

// ── 3. Video Ads Stream ───────────────────────────────────────────────────
Widget buildAdRevenueStreamCard(RevenueAnalyticsController controller) {
  final amount = controller.adsRevenue.value;
  final views = controller.totalViews.value;
  final creatorCut = amount * 0.70;
  final formattedAmount = controller.formatCurrency(amount);
  final formattedPlatformCut = controller.formatCurrency(amount * 0.30);
  final formattedCreatorCut = controller.formatCurrency(creatorCut);

  final rpm = (views > 0 && amount > 0) ? ((amount / views) * 1000) : 0.0;
  final formattedRpm = controller.formatCurrency(rpm);

  return buildStreamContainer(
    icon: Icons.ondemand_video_rounded,
    title: 'Video Ads & Monetization',
    subtitle: '$views View${views == 1 ? '' : 's'} • Day 1 Monetization Enabled',
    amount: formattedAmount,
    badgeText: '70% Creator Split',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        buildSplitRow(
          label: 'Estimated RPM (Per 1K Views)',
          value: formattedRpm,
        ),
        const SizedBox(height: 6),
        buildSplitRow(
          label: 'Platform Share (30%)',
          value: formattedPlatformCut,
        ),
        const SizedBox(height: 6),
        buildSplitRow(
          label: 'Creator Share (70%)',
          value: formattedCreatorCut,
          isBold: true,
        ),
      ],
    ),
  );
}

Widget buildStreamContainer({
  required IconData icon,
  required String title, required String subtitle, required String amount, required String badgeText, required Widget child, Color? accentColor,
  Color? badgeColor,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E), // Exact Library cardColor
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.bgDivider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.15)),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

Widget buildSplitRow({
  required String label,
  required String value,
  bool isBold = false,
  bool isGreen = false,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        value,
        style: TextStyle(
          color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ],
  );
}
