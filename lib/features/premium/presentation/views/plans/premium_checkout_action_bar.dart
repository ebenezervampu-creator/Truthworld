import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
      final selectedId = ctrl.selectedPlanId.value;
      final isLoading = ctrl.rxIsLoading.value;
      final isUpgrading = ctrl.isUpgrade(selectedId);
      final isCurrent = ctrl.isCurrentPlan(selectedId);
      final isLower = ctrl.isLowerTier(selectedId);
      final effectivePrice = ctrl.getEffectivePrice(selectedId);
      final credit = ctrl.getCreditApplied(selectedId);

      var label = 'Pay with Cashfree';
      var canCheckout = true;

      if (isCurrent) {
        label = 'Current Plan Active';
        canCheckout = false;
      } else if (isLower) {
        label = 'Included in Your Current Plan';
        canCheckout = false;
      } else if (isUpgrading) {
        if (selectedId == 'individual_monthly') {
          label = r'Upgrade to $2 Premium • Pay ₹129 ($2 - ₹40)';
        } else if (selectedId == '4k_factchecked_monthly') {
          if (credit >= 160) {
            label = r'Upgrade to $3 Fact-Checked • Pay ₹80 ($3 - $2)';
          } else {
            label = r'Upgrade to $3 Fact-Checked • Pay ₹209 ($3 - ₹40)';
          }
        } else {
          label = 'Upgrade with Cashfree: Pay ₹${effectivePrice.toInt()}';
        }
      } else {
        if (selectedId == 'audio_monthly') {
          label = r'Pay ₹40 with Cashfree ($0.50 Audio Premium)';
        } else if (selectedId == '4k_factchecked_monthly') {
          label = r'Pay ₹249 with Cashfree ($3 Fact-Checked)';
        } else if (selectedId == 'individual_monthly') {
          label = r'Pay ₹169 with Cashfree ($2 TruthWorld Premium)';
        } else if (selectedId == 'family_monthly') {
          label = 'Pay ₹399 with Cashfree (Family Plan)';
        } else if (selectedId == 'individual_yearly') {
          label = 'Pay ₹1,490 with Cashfree (Annual Plan)';
        } else {
          label = r'Pay ₹169 with Cashfree ($2 TruthWorld Premium)';
        }
      }

      return SizedBox(
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
                      color: Colors.white,
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
      );
    });
  }
}
