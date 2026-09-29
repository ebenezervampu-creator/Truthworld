import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section showcasing custom channel infrastructure hosting tiers with in-app balance payment.
class ChannelPlansBreakdownSection extends StatelessWidget {
  final ChannelMonetizationController controller;
  final bool isCustom;

  const ChannelPlansBreakdownSection({
    required this.controller,
    required this.isCustom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.twTypography;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Custom Channel Infrastructure Plans',
                style: typography.headline.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select your hosting tier. All plans feature 0% Platform Commission and dedicated storage & bandwidth!',
            style: typography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          Obx(() {
            final isAutoPay = controller.autoPayEnabled.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAutoPay
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                      : AppColors.bgDivider,
                  width: isAutoPay ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAutoPay
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                          : AppColors.bgSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.autorenew_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Auto Pay for Infrastructure Plans',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAutoPay
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : const Color(0xFF3F3F46),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isAutoPay ? 'ACTIVE' : 'OFF',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isAutoPay
                                      ? const Color(0xFF34D399)
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAutoPay
                              ? 'Automatically renew your custom plan monthly to prevent video streaming halts. Cancel anytime.'
                              : 'One-time monthly activation. Requires manual renewal every billing cycle.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isAutoPay,
                    onChanged: controller.toggleAutoPay,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            );
          }),

          Obx(() {
            final currentSelectedPlanId = controller.selectedPlanId.value;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: InfrastructureMeteringService.availablePlans.map((plan) {
                  final isSelected = currentSelectedPlanId == plan.id;
                  return GestureDetector(
                    onTap: () => controller.selectedPlanId.value = plan.id,
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.bgElevated : AppColors.bgSurfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white : AppColors.bgDivider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                plan.title,
                                style: typography.title.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              if (plan.isPopular)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.bgDivider,
                                    ),
                                  ),
                                  child: Text(
                                    'Popular',
                                    style: typography.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plan.priceUSD > 0
                                ? '\$${plan.priceUSD.toStringAsFixed(0)} / mo'
                                : 'Custom Quote',
                            style: typography.headline.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: AppColors.bgDivider, height: 1),
                          const SizedBox(height: 12),
                          ...plan.features.map(
                            (feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: typography.caption.copyWith(
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (plan.priceUSD > 0) ...[
                            const SizedBox(height: 12),
                            Obx(() {
                              final canAfford = controller.spendableBalance.canAfford(plan.priceUSD);
                              final isAutoPay = controller.autoPayEnabled.value;
                              final buttonText = canAfford
                                  ? (isAutoPay ? 'Auto Pay with Balance' : 'Pay with Balance')
                                  : (isAutoPay ? 'Auto Pay via Cashfree' : 'Pay via Cashfree');

                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => controller.subscribePlan(context, plan),
                                  icon: Icon(
                                    canAfford
                                        ? Icons.account_balance_wallet_rounded
                                        : Icons.payment_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  label: Text(
                                    buttonText,
                                    style: typography.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? (isAutoPay ? const Color(0xFF7C3AED) : AppColors.bgSurface)
                                        : AppColors.bgElevated,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Bottom action card permitting creators to schedule a tier change between Standard and Custom.
class ChannelTierUpgradeCard extends StatelessWidget {
  final ChannelMonetizationController controller;
  final bool isCustom;

  const ChannelTierUpgradeCard({
    required this.controller,
    required this.isCustom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final channel = controller.channel;
    final typography = context.twTypography;
    final hasPending = channel.pendingChannelType != null;
    final targetTypeStr = isCustom ? 'Standard' : 'Custom';
    final daysLeft = controller.calculateDaysLeftToSwitch();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCustom
                ? 'Request Switch to Standard Channel'
                : 'Request Switch to Custom Channel (100% Revenue Share)',
            style: typography.headline.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            isCustom
                ? r'Standard channels have $0 upfront monthly cost, a 70/30 split on ads & premium subscriptions, and 100% creator share on superchats & memberships. Switching will take effect at the start of your next billing cycle.'
                : r'Custom channels let you keep 100% of revenue across all sources with flexible infrastructure plans ($15, $30, $45, $100, $200/mo etc.). Requesting a switch locks your request to take effect on the 1st of next month.',
            style: typography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (controller.isUpdating || hasPending)
                ? null
                : controller.scheduleTierChange,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCustom ? AppColors.bgSurfaceHigh : Colors.white,
              foregroundColor: isCustom ? Colors.white : Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: controller.isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    hasPending
                        ? 'Tier Change to $targetTypeStr Scheduled'
                        : 'Schedule Switch to $targetTypeStr (in $daysLeft Days)',
                    style: typography.button.copyWith(
                      color: isCustom ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
