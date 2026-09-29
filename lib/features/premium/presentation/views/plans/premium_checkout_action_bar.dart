import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Primary call-to-action button for initiating plan purchase via Cashfree.
class PremiumCheckoutButton extends StatelessWidget {
  final PremiumController? controller;

  const PremiumCheckoutButton({
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
      final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final selectedId = ctrl.selectedPlanId.value;
      final isLoading = ctrl.rxIsLoading.value;
      final isUpgrading = ctrl.isUpgrade(selectedId);
      final isCurrent = ctrl.isCurrentPlan(selectedId);
      final isLower = ctrl.isLowerTier(selectedId);
      final effectivePrice = ctrl.getEffectivePrice(selectedId);
      final credit = ctrl.getCreditApplied(selectedId);
      final effectivePriceUSD = ctrl.getEffectivePriceUSD(selectedId);
      final creditUSD = ctrl.getCreditAppliedUSD(selectedId);

      final isAutoPay = ctrl.isAutoPay.value;
      final periodText = selectedId.contains('yearly') ? 'year' : 'month';

      var label = isAutoPay ? 'Pay with Auto Pay' : 'Pay (One-Time)';
      var canCheckout = true;

      if (isCurrent) {
        label = 'Current Plan Active';
        canCheckout = false;
      } else if (isLower) {
        label = 'Included in Your Current Plan';
        canCheckout = false;
      } else if (isUpgrading) {
        final autoPrefix = isAutoPay ? 'Upgrade with Auto Pay' : 'Upgrade (One-Time)';
        if (isIndian) {
          if (selectedId == 'individual_monthly') {
            label = '$autoPrefix • Pay ₹129';
          } else if (selectedId == '4k_factchecked_monthly') {
            if (credit >= 160) {
              label = '$autoPrefix • Pay ₹80';
            } else {
              label = '$autoPrefix • Pay ₹209';
            }
          } else {
            label = '$autoPrefix • Pay ₹${effectivePrice.toInt()}';
          }
        } else {
          if (selectedId == 'individual_monthly') {
            label = '$autoPrefix • Pay \$1.50';
          } else if (selectedId == '4k_factchecked_monthly') {
            if (creditUSD >= 2.0) {
              label = '$autoPrefix • Pay \$1';
            } else {
              label = '$autoPrefix • Pay \$2.50';
            }
          } else {
            label = '$autoPrefix • Pay \$${effectivePriceUSD.toStringAsFixed(effectivePriceUSD == 0.5 || effectivePriceUSD == 1.5 || effectivePriceUSD == 2.5 ? 2 : 0)}';
          }
        }
      } else {
        final autoSuffix = isAutoPay ? 'with Auto Pay' : '(One-Time)';
        if (isIndian) {
          if (selectedId == 'audio_monthly') {
            label = 'Pay ₹40 $autoSuffix';
          } else if (selectedId == '4k_factchecked_monthly') {
            label = 'Pay ₹249 $autoSuffix';
          } else if (selectedId == 'individual_monthly') {
            label = 'Pay ₹169 $autoSuffix';
          } else if (selectedId == 'family_monthly') {
            label = 'Pay ₹400 $autoSuffix';
          } else if (selectedId == 'individual_yearly') {
            label = 'Pay ₹1,490 $autoSuffix';
          } else {
            label = 'Pay ₹169 $autoSuffix';
          }
        } else {
          if (selectedId == 'audio_monthly') {
            label = 'Pay \$0.50 $autoSuffix';
          } else if (selectedId == '4k_factchecked_monthly') {
            label = 'Pay \$3 $autoSuffix';
          } else if (selectedId == 'individual_monthly') {
            label = 'Pay \$2 $autoSuffix';
          } else if (selectedId == 'family_monthly') {
            label = 'Pay \$5 $autoSuffix';
          } else if (selectedId == 'individual_yearly') {
            label = 'Pay \$18 $autoSuffix';
          } else {
            label = 'Pay \$2 $autoSuffix';
          }
        }
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canCheckout) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAutoPay
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                      : const Color(0xFF27272A),
                  width: isAutoPay ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAutoPay
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                          : const Color(0xFF27272A),
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
                              'Auto Pay',
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
                                isAutoPay ? 'RECOMMENDED' : 'ONE-TIME',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isAutoPay
                                      ? const Color(0xFF34D399)
                                      : Colors.white70,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isAutoPay
                              ? 'Automatically renews every $periodText. Hassle-free, cancel anytime in settings.'
                              : 'One-time payment for one $periodText. Requires manual renewal when it ends.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: isAutoPay,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      ctrl.toggleAutoPay(val);
                    },
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (isLoading || !canCheckout)
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      ctrl.purchasePlan(selectedId);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                disabledBackgroundColor: AppColors.textPrimary.withValues(alpha: 0.2),
                disabledForegroundColor: AppColors.textPrimary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: canCheckout ? 4 : 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCurrent
                              ? Icons.check_circle_outline_rounded
                              : (isUpgrading
                                  ? Icons.upgrade_rounded
                                  : Icons.lock_outline_rounded),
                          color: canCheckout ? Colors.black : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: canCheckout ? AppColors.bgPage : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      );
    });
  }
}
