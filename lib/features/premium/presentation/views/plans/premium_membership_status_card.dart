import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Key-value information row used in membership cards and sidebars.
class PremiumInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const PremiumInfoRow({
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing active membership status, trial expiry, cancellation, or developer sandbox controls.
class PremiumMembershipStatusCard extends StatelessWidget {
  final bool isPremium;
  final String? planId;
  final PremiumController? controller;

  const PremiumMembershipStatusCard({
    required this.isPremium,
    this.planId,
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
    final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
    final isTrialExpired = auth?.isTrialExpired ?? false;
    final expiresAt = auth?.premiumExpiresAt.value;
    final formattedExpires = auth?.formattedExpiresDate ?? 'N/A';
    final formattedStarted = auth?.formattedStartedDate ?? 'N/A';
    final formattedRemaining = auth?.formattedRemainingTime ?? 'N/A';

    if (isTrialExpired || (!isPremium && expiresAt != null)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.timer_off_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '7-Day Free Trial Expired',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your 7-day free trial ended on $formattedExpires. Premium features (4K, ad-free streaming, background play, and fact-checking) have been paused.',
              style: const TextStyle(
                fontSize: 14,
                color: primaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose a plan below to resume your Premium membership.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    if (isPremium) {
      var planName = r'$2 TruthWorld Premium Plan';
      var planPrice = r'$2/month (₹169)';
      if (planId == 'audio_monthly') {
        planName = r'$0.50 Audio Premium Plan';
        planPrice = r'$0.50/month (₹40)';
      } else if (planId == '4k_factchecked_monthly') {
        planName = r'$3 Premium + Fact-Checked Plan';
        planPrice = r'$3/month (₹249)';
      } else if (planId == 'family_monthly') {
        planName = r'$5 Family Plan';
        planPrice = r'$5/month';
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Membership Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.bgDivider, height: 1),
            const SizedBox(height: 12),
            PremiumInfoRow(label: 'Plan', value: planName),
            PremiumInfoRow(label: 'Price', value: planPrice),
            const PremiumInfoRow(label: 'Billing Cycle', value: '7 Days Free Trial'),
            PremiumInfoRow(label: 'Activated On', value: formattedStarted),
            PremiumInfoRow(label: 'Expires / Renews On', value: formattedExpires),
            PremiumInfoRow(label: 'Time Remaining', value: formattedRemaining),
            if (planId == 'audio_monthly') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.12),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.upgrade_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          r'Upgrades Available ($0.50 / ₹40 Credit Applied)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      r'Upgrade to $2 Premium for ₹129 ($2 - 40 rupees) or $3 Fact-Checked for ₹209 ($3 - 40 rupees). Select a plan below to upgrade.',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (planId == 'individual_monthly') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.12),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.upgrade_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          r'Upgrade to Fact-Checked ($3 - $2)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      r'Upgrade to the $3 Fact-Checked Plan for only ₹80 ($3 - $2) to get every video fact-checked + on-demand verification. Select below to upgrade.',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _effectiveController.cancelSimulated();
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: buttonBg,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text(
                  'Cancel Membership',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Developer Sandbox simulation card (Debug/development only)
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Developer Sandbox Panel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Instantly toggle Premium activation to verify ad-free playback, 4K quality, offline downloads, and fact-checking status locally.',
            style: TextStyle(
              fontSize: 13,
              color: secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.offline_bolt_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Simulate Premium Unlock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgPage,
                ),
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
                final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
                if (auth == null || !auth.isAuthenticated.value) {
                  AppSnackbar.warning(
                    'Please sign in to simulate premium upgrade.',
                    title: 'Sign In Required',
                  );
                } else {
                  await _effectiveController.upgradeSimulated(
                    _effectiveController.selectedPlanId.value,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
