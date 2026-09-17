import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_constants.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_membership_status_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive shortcut tile for desktop sidebar navigation.
class PremiumSidebarAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const PremiumSidebarAction({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop right-hand sidebar showing current membership details and quick navigation links.
class PremiumDesktopSidebar extends StatelessWidget {
  final PremiumController? controller;

  const PremiumDesktopSidebar({
    this.controller,
    super.key,
  });

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
              final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
              final isPremium = auth?.isPremiumUser.value ?? false;
              final planId = auth?.premiumPlanId.value;
              return PremiumMembershipStatusCard(
                isPremium: isPremium,
                planId: planId,
                controller: controller,
              );
            }),
            const SizedBox(height: 32),
            const Text(
              'QUICK SHORTCUTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: secondaryText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            PremiumSidebarAction(
              icon: Icons.history_rounded,
              title: 'Watch History',
              onTap: () => Get.toNamed('/watchhistory'),
            ),
            PremiumSidebarAction(
              icon: Icons.video_collection_rounded,
              title: 'My Videos',
              onTap: () => Get.toNamed('/myvideos'),
            ),
            PremiumSidebarAction(
              icon: Icons.file_download_outlined,
              title: 'Offline Downloads',
              onTap: () => Get.toNamed('/downloads'),
            ),
            PremiumSidebarAction(
              icon: Icons.settings_rounded,
              title: 'Account Settings',
              onTap: () => Get.toNamed('/settings'),
            ),
            PremiumSidebarAction(
              icon: Icons.feedback_outlined,
              title: 'Send Feedback',
              onTap: () => Get.toNamed('/feedback'),
            ),
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
        ],
      ),
    ),
  );
}
