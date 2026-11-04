import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_membership_status_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Desktop right-hand sidebar showing current membership details.
class PremiumDesktopSidebar extends StatelessWidget {
  final PremiumController? controller;

  const PremiumDesktopSidebar({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MEMBERSHIP OVERVIEW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: secondaryText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final ctrl = _effectiveController;
              final _ = ctrl.selectedPlanId.value;
              final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
              final isPremium = auth?.isPremiumUser.value ?? false;
              final planId = auth?.premiumPlanId.value;
              return PremiumMembershipStatusCard(
                isPremium: isPremium,
                planId: planId,
                controller: ctrl,
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Displays more options bottom sheet for mobile and tablet views.
void showPremiumMoreOptionsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: secondaryText,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.feedback_outlined, color: Colors.white),
            title: const Text(
              'Send Feedback',
              style: TextStyle(
                color: primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Get.toNamed('/feedback');
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (AuthService.to.isAuthenticated.value)
            ListTile(
              leading: const Icon(Icons.settings_rounded, color: Colors.white),
              title: const Text(
                'Account Settings',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Get.toNamed('/settings');
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.offline_bolt_rounded, color: Colors.white),
              title: const Text(
                'Simulate Premium Unlock (Debug)',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
                if (auth == null || !auth.isAuthenticated.value) {
                  AppSnackbar.warning(
                    'Please sign in to simulate premium upgrade.',
                    title: 'Sign In Required',
                  );
                } else {
                  final ctrl = Get.isRegistered<PremiumController>()
                      ? Get.find<PremiumController>()
                      : Get.put(PremiumController());
                  await ctrl.upgradeSimulated(ctrl.selectedPlanId.value);
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    ),
  );
}
