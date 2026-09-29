import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 💎 Premium Subscription Revenue Card
///
/// Displays the watch-time-weighted premium subscription revenue earned by
/// this channel from TruthWorld's monthly distribution run. Shows:
/// - Total creator share received this month
/// - Transparent algorithm breakdown (70/30 split, watch-time weighting)
/// - Distribution status (when the last run settled)
///
/// Revenue source: `distributePremiumRevenue` Cloud Function runs monthly
/// and writes to `channels/{id}.premiumSubsRevenueTotal`.
class PremiumSubsRevenueCard extends StatelessWidget {
  const PremiumSubsRevenueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RevenueAnalyticsController.to;

    return Obx(() {
      final amount = controller.premiumSubsRevenue.value;
      final amountFormatted = controller.isViewingINR
          ? '₹${amount.toStringAsFixed(2)}'
          : '\$${controller.premiumSubsRevenueUSD.value.toStringAsFixed(2)}';

      return _PremiumSubsCard(
        amount: amount,
        amountFormatted: amountFormatted,
      );
    });
  }
}

class _PremiumSubsCard extends StatelessWidget {
  final double amount;
  final String amountFormatted;

  const _PremiumSubsCard({
    required this.amount,
    required this.amountFormatted,
  });

  static const Color _accentColor = Color(0xFF7C3AED); // purple
  static const Color _cardBg = Color(0xFF121218);
  static const Color _borderColor = Color(0xFF27272A);

  @override
  Widget build(BuildContext context) {
    final controller = RevenueAnalyticsController.to;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Subscription Share',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Watch-time weighted monthly distribution',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amountFormatted,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Creator Share Badge ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '70% Creator Split · Watch-Time Proportional',
              style: TextStyle(
                color: _accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Revenue Split Row ───────────────────────────────────────────
          _splitRow(
            label: 'Gross Subscriber Pool (Your Share)',
            value: amount > 0
                ? '₹${(amount / 0.70).toStringAsFixed(2)}'
                : '₹0.00',
          ),
          const SizedBox(height: 6),
          _splitRow(
            label: 'Platform Share (30%)',
            value: amount > 0
                ? '₹${(amount / 0.70 * 0.30).toStringAsFixed(2)}'
                : '₹0.00',
          ),
          const SizedBox(height: 6),
          _splitRow(
            label: 'Creator Share (70%)',
            value: amountFormatted,
            isBold: true,
          ),

          const SizedBox(height: 14),

          // ── How It's Calculated Expandable ─────────────────────────────
          Obx(() {
            final isExpanded = controller.isPremiumInfoExpanded.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: controller.isPremiumInfoExpanded.toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Text(
                        'How is this calculated?',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _accentColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _algorithmStep(
                          step: '1',
                          title: 'Individual Subscriber Pool',
                          desc: "Each premium subscriber's monthly payment (e.g. \u20b9169) "
                              'creates their own personal allocation pool. '
                              '70% goes to creators, 30% to TruthWorld.',
                        ),
                        const SizedBox(height: 10),
                        _algorithmStep(
                          step: '2',
                          title: 'Watch-Time Weighting',
                          desc:
                              "The subscriber's 70% creator pool is split proportionally "
                              'across channels based on how many seconds they watched '
                              'each channel during the billing month (min. 10 sec threshold).',
                        ),
                        const SizedBox(height: 10),
                        _algorithmStep(
                          step: '3',
                          title: "Your Channel's Share",
                          desc:
                              "Your share = (your watch seconds / subscriber's total watch seconds) "
                              "× (subscription amount × 70%). Each subscriber's "
                              'contribution is fully transparent and auditable.',
                        ),
                        const SizedBox(height: 10),
                        _algorithmStep(
                          step: '4',
                          title: 'Monthly Settlement',
                          desc:
                              'The distribution engine runs automatically on the 1st of '
                              'each month for the previous month. All credits are added to '
                              'your revenue statement and withdrawable balance.',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),

          // ── Transparency Notice ─────────────────────────────────────────
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: AppColors.textSecondary,
                size: 14,
              ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Full per-subscriber allocation records are available in your '
                  'revenue statement for complete transparency.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _splitRow({
    required String label,
    required String value,
    bool isBold = false,
    bool isGreen = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isGreen
                ? const Color(0xFF10B981)
                : (isBold ? AppColors.textPrimary : AppColors.textSecondary),
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _algorithmStep({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: _accentColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
