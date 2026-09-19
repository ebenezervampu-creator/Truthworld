import 'package:flutter/material.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

  Widget buildRevenueHeroMetricCard(RevenueAnalyticsController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF18181B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF312E81)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Estimated Revenue',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Currency View Toggle (INR vs USD)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildRevenueCurrencyToggleChip(
                          label: '₹ INR',
                          isSelected: controller.isViewingINR,
                          onTap: () => controller.setCurrencyView('INR'),
                        ),
                        buildRevenueCurrencyToggleChip(
                          label: r'$ USD',
                          isSelected: !controller.isViewingINR,
                          onTap: () => controller.setCurrencyView('USD'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.revenueChange.value,
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                controller.isViewingINR
                    ? '₹${controller.totalRevenue.value.toStringAsFixed(2)}'
                    : '\$${controller.totalRevenueUSD.value.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              if (controller.originalUsdMemberships.value > 0) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    controller.isViewingINR
                        ? '(Includes \$${controller.originalUsdMemberships.value.toStringAsFixed(2)} USD @ ₹${RevenueAnalyticsController.usdToInrRate.toStringAsFixed(2)}/\$)'
                        : '(Bank Payout: ₹${controller.totalRevenue.value.toStringAsFixed(2)} INR)',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildRevenuePillTag(
                icon: Icons.verified_rounded,
                label: '0% Platform Fee on Fan Support',
                color: const Color(0xFF10B981),
              ),
              buildRevenuePillTag(
                icon: Icons.calendar_today_rounded,
                label: 'Last 28 days',
                color: const Color(0xFF6366F1),
              ),
              if (controller.originalUsdMemberships.value > 0)
                buildRevenuePillTag(
                  icon: Icons.currency_exchange_rounded,
                  label: 'Exchange Rate: 1 USD = ₹${RevenueAnalyticsController.usdToInrRate.toStringAsFixed(2)} INR',
                  color: const Color(0xFFF59E0B),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildRevenueCurrencyToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget buildRevenuePillTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


