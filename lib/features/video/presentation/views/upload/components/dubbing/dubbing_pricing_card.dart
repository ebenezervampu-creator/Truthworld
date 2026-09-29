import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Live pricing breakdown card for dubbing selection.
class DubbingPricingCard extends StatelessWidget {
  const DubbingPricingCard({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final totalSelected = controller.selectedLanguages.length;
      final cost = controller.calculatedCost;
      final flatRate = controller.flatDubbingRatePerLang;
      final wallet = controller.walletBalance;
      final isInsufficient = controller.isInsufficientBalance;

      return Material(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isInsufficient
                  ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Live Pricing Breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${flatRate.toStringAsFixed(2)} / lang',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics table
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildMetricRow('Target Dubbing Languages:', '$totalSelected'),
                  const SizedBox(height: 6),
                  _buildMetricRow(
                    'Flat Rate per Language:',
                    '\$${flatRate.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  _buildMetricRow(
                    'Included Matching Subtitles:',
                    'Free ($totalSelected languages)',
                    highlightColor: const Color(0xFF34D399),
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  _buildMetricRow(
                    'Total Dubbing Cost:',
                    '\$${cost.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Wallet Balance & Topup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isInsufficient
                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInsufficient
                      ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                      : Colors.white10,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: isInsufficient
                            ? const Color(0xFFF87171)
                            : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Wallet Balance: \$${wallet.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isInsufficient
                              ? const Color(0xFFF87171)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (controller.channel != null)
                    GestureDetector(
                      onTap: () {
                        ChannelWalletTopupSheet.show(
                          context,
                          channel: controller.channel!,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '+ Add Money',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (isInsufficient) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Insufficient wallet balance (\$${wallet.toStringAsFixed(2)} available vs \$${cost.toStringAsFixed(2)} required). Please top up channel wallet or reduce selected languages.',
                style: const TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 10),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: Colors.white60,
                iconColor: Colors.white,
                title: const Text(
                  'View Dubbing Duration Tiers',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: ChannelWalletService.dubbingDurationTiers.map((tier) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tier.name} (${tier.durationLabel})',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          tier.standardFlatRatePerLanguage == tier.customFlatRatePerLanguage
                              ? '\$${tier.standardFlatRatePerLanguage.toStringAsFixed(2)} / lang (At-Cost)'
                              : '\$${tier.standardFlatRatePerLanguage.toStringAsFixed(2)} Std / \$${tier.customFlatRatePerLanguage.toStringAsFixed(2)} Partner',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  });
  }


  Widget _buildMetricRow(
    String label,
    String value, {
    Color? highlightColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white70,
            fontSize: isTotal ? 13 : 11.5,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlightColor ?? Colors.white,
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

}
