import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_checkout_action_bar.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single selectable plan option card with upgrade proration awareness.
class PremiumPlanCard extends StatelessWidget {
  final PremiumPlanDetails plan;
  final bool isSelected;
  final VoidCallback onTap;
  final PremiumController? controller;

  const PremiumPlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    this.controller,
    super.key,
  });

  PremiumController get _effectiveController =>
      controller ??
      (Get.isRegistered<PremiumController>()
          ? Get.find<PremiumController>()
          : Get.put(PremiumController()));

  @override
  Widget build(BuildContext context) {
    final ctrl = _effectiveController;
    final isCurrent = ctrl.isCurrentPlan(plan.id);
    final isUpgrading = ctrl.isUpgrade(plan.id);
    final isLower = ctrl.isLowerTier(plan.id);
    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    final effectivePrice = ctrl.getEffectivePrice(plan.id);
    final credit = ctrl.getCreditApplied(plan.id);
    final effectivePriceUSD = ctrl.getEffectivePriceUSD(plan.id);
    final creditUSD = ctrl.getCreditAppliedUSD(plan.id);

    final usdPrice = ctrl.getPriceUSDForPlan(plan.id);
    final inrPrice = ctrl.getPriceForPlan(plan.id);

    var priceDisplay = '\$${usdPrice.toStringAsFixed(usdPrice == 0.50 ? 2 : 0)}';
    String? originalPrice;
    String? upgradeBadgeText;

    if (isCurrent) {
      priceDisplay = 'Active';
    } else if (isLower) {
      priceDisplay = 'Included';
    } else if (isUpgrading) {
      originalPrice = priceDisplay;
      if (isIndian) {
        priceDisplay = ctrl.formatAmountINR(effectivePrice);
        upgradeBadgeText = 'Save ${ctrl.formatAmountINR(credit)}';
      } else {
        priceDisplay = ctrl.formatAmountUSD(effectivePriceUSD);
        upgradeBadgeText = 'Save ${ctrl.formatAmountUSD(creditUSD)}';
      }
    }

    return InkWell(
      onTap: isCurrent || isLower
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? buttonBg : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : (isCurrent
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.textPrimary.withValues(alpha: 0.08)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isCurrent
                    ? Icons.check_circle_rounded
                    : (isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                color: isCurrent ? AppColors.success : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                plan.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successContainer,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.success.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: const Text(
                                  'CURRENT PLAN',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (originalPrice != null) ...[
                                Text(
                                  originalPrice,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                    color: secondaryText,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                priceDisplay,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : primaryText,
                                ),
                              ),
                            ],
                          ),
                          if (plan.priceLabel.contains('/') && !isCurrent && !isLower) ...[
                            Builder(
                              builder: (context) {
                                final periodText = isIndian
                                    ? '/month (${ctrl.formatAmountINR(inrPrice)})'
                                    : '/month';
                                return Text(
                                  periodText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: secondaryText,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.textPrimary.withValues(alpha: 0.15)
                              : buttonBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.textPrimary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          plan.tagline,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                      if (upgradeBadgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            upgradeBadgeText,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    plan.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: secondaryText,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of available subscription plans with reactive selection.
class PremiumPlansList extends StatelessWidget {
  final List<PremiumPlanDetails> plans;
  final PremiumController? controller;

  const PremiumPlansList({
    this.plans = kDefaultPremiumPlans,
    this.controller,
    super.key,
  });

  PremiumController get _effectiveController =>
      controller ??
      (Get.isRegistered<PremiumController>()
          ? Get.find<PremiumController>()
          : Get.put(PremiumController()));

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctrl = _effectiveController;
      final selectedId = ctrl.selectedPlanId.value;

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: plans.length,
        separatorBuilder: (context, idx) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final plan = plans[idx];
          return PremiumPlanCard(
            plan: plan,
            isSelected: selectedId == plan.id,
            onTap: () => ctrl.selectPlan(plan.id),
            controller: ctrl,
          );
        },
      );
    });
  }
}

/// Section containing the plans list and checkout CTA button.
class PremiumPlanSelectorSection extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final PremiumController? controller;

  const PremiumPlanSelectorSection({
    this.isDesktop = false,
    this.isTablet = false,
    this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;

    Widget buildHeader(bool isPremium) {
      final title = isPremium
          ? 'Upgrade or Change Your Plan'
          : 'Choose the plan that fits for you';

      final subtitle = isPremium
          ? 'Switch to higher tiers anytime. Your existing plan payment is automatically credited at today’s exchange rate.'
          : 'Ad-free videos, background play, offline downloads, and verified fact-checking.';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: secondaryText,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    final header = auth != null
        ? Obx(() => buildHeader(auth.isPremiumUser.value))
        : buildHeader(false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 20),
        PremiumPlansList(controller: controller),
        const SizedBox(height: 24),
        PremiumCheckoutButton(controller: controller),
      ],
    );
  }
}
