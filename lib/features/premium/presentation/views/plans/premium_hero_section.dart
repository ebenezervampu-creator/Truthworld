import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// YouTube Premium style Hero Banner with trial CTA and membership badge.
class PremiumHeroSection extends StatelessWidget {
  final bool isPremium;
  final String? planId;
  final bool isDesktop;
  final bool isTablet;
  final PremiumController? controller;

  const PremiumHeroSection({
    required this.isPremium,
    this.planId,
    this.isDesktop = false,
    this.isTablet = false,
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

      var trialText = r'7 days free • Then $2/month (₹169)';
      if (selectedId == 'audio_monthly') {
        trialText = r'7 days free • Then $0.50/month (₹40) • Audio Ad-Free';
      } else if (selectedId == '4k_factchecked_monthly') {
        trialText = r'7 days free • Then $3/month (₹249) • Fact-Checked';
      } else if (selectedId == 'family_monthly') {
        trialText = r'7 days free • Then $5/month';
      }

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 40 : (isTablet ? 28 : 20),
          vertical: isDesktop ? 44 : 32,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
          ),
          gradient: const LinearGradient(
            colors: [buttonBg, cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 34, borderRadius: 8),
                const SizedBox(width: 10),
                Text(
                  'Truthworld',
                  style: TextStyle(
                    fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.0,
                    color: primaryText,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              r'Ad-Free Audio ($0.50 / ₹40), Video ($2) & Fact-Checked ($3)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 28 : (isTablet ? 24 : 20),
                fontWeight: FontWeight.bold,
                color: primaryText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: const Text(
                r'Choose the tier that fits you: enjoy ad-free audio playback at $0.50/mo (₹40), all-inclusive ad-free 4K video at $2/mo (₹169), or unlock comprehensive AI fact-checking on every video with on-demand user verification at $3/mo (₹249).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryText,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!isPremium) ...[
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ctrl.purchasePlan(selectedId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.bgPage,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Try 7 Days Free',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.bgPage,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                trialText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Only new members are eligible for trials. Cancel anytime.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ] else ...[
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Active Member',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ctrl.isUpgrade(selectedId))
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ctrl.purchasePlan(selectedId);
                      },
                      icon: const Icon(Icons.upgrade_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'Upgrade for ₹${ctrl.getEffectivePrice(selectedId).toInt()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.bgPage,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
