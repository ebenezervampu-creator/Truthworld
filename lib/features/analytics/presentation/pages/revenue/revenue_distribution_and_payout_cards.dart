import 'package:flutter/material.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildRevenueDistributionCard(RevenueAnalyticsController controller) {
  final total = controller.totalRevenue.value;
  final memberships = controller.membershipsRevenue.value;
  final superchats = controller.superchatRevenue.value;
  final ads = controller.adsRevenue.value;
  final watchTime = controller.watchTimeRevenue.value;

  final memPct = total > 0 ? (memberships / total) : (memberships > 0 ? 1.0 : 0.0);
  final scPct = total > 0 ? (superchats / total) : 0.0;
  final adsPct = total > 0 ? (ads / total) : 0.0;
  final wtPct = total > 0 ? (watchTime / total) : 0.0;

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
        const Text(
          'Revenue Distribution',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Contribution by earning method for this channel',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (memPct > 0)
                  Expanded(
                    flex: (memPct * 1000).toInt().clamp(1, 1000),
                    child: Container(color: Colors.white),
                  ),
                if (scPct > 0)
                  Expanded(
                    flex: (scPct * 1000).toInt().clamp(1, 1000),
                    child: Container(color: const Color(0xFFD4D4D8)),
                  ),
                if (adsPct > 0)
                  Expanded(
                    flex: (adsPct * 1000).toInt().clamp(1, 1000),
                    child: Container(color: const Color(0xFFA1A1AA)),
                  ),
                if (wtPct > 0)
                  Expanded(
                    flex: (wtPct * 1000).toInt().clamp(1, 1000),
                    child: Container(color: const Color(0xFF71717A)),
                  ),
                if (total == 0)
                  Expanded(
                    child: Container(color: const Color(0xFF27272A)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            buildRevenueLegendItem(
              label: 'Memberships: ${(memPct * 100).toStringAsFixed(0)}%',
              color: Colors.white,
            ),
            buildRevenueLegendItem(
              label: 'Superchats: ${(scPct * 100).toStringAsFixed(0)}%',
              color: const Color(0xFFD4D4D8),
            ),
            buildRevenueLegendItem(
              label: 'Ads: ${(adsPct * 100).toStringAsFixed(0)}%',
              color: const Color(0xFFA1A1AA),
            ),
            buildRevenueLegendItem(
              label: 'Watch Time: ${(wtPct * 100).toStringAsFixed(0)}%',
              color: const Color(0xFF71717A),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildRevenueLegendItem({required String label, required Color color}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ],
  );
}

// ── Payout Terms & AI Usability ────────────────────────────────────────────
Widget buildPayoutAndUsabilityCard(RevenueAnalyticsController controller) {
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Creator Payout & Terms',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '• Payout Schedule: YouTube-style monthly cycle — open on the 1st of every month with a 1-day grace period on Day 2 (Min ₹100 threshold • Missed earnings roll over automatically).\n'
          '• Two-Phase Settlement: Direct fan tips and memberships clear after a 7-day anti-chargeback hold; ad revenue finalizes at calendar month end.\n'
          '• Zero-Debt Guarantee: Payout is protected at a floor of ₹0.00 — creator balance never goes negative.\n'
          '• Instant AI Features: Unwithdrawn revenue can be used anytime for AI Subtitles and Dubbing!',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.navigateToMonetization,
            icon: const Icon(Icons.tune_rounded, color: Colors.black, size: 16),
            label: const Text(
              'Monetization & Payout Settings',
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
