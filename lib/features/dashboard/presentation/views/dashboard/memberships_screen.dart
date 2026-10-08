import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships/memberships_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

// Export ChannelMembershipTier and ChannelMember for backward compatibility
export 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart'
    show ChannelMember, ChannelMembershipTier, StarterTierBundle, StarterTierBundleType;
export 'memberships/memberships_widgets.dart';

/// Redesigned Industry-Standard Studio Channel Memberships & Fan Funding Screen.
class MembershipsScreen extends StatelessWidget {
  const MembershipsScreen({
    super.key,
    this.channelId,
    this.isDarkMode = true,
  });

  final String? channelId;
  final bool isDarkMode;

  MembershipsController get _controller {
    if (Get.isRegistered<MembershipsController>()) {
      final ctrl = Get.find<MembershipsController>();
      if (channelId != null && channelId!.isNotEmpty) {
        ctrl.setChannelId(channelId!);
      }
      return ctrl;
    }
    return Get.put(MembershipsController(initialChannelId: channelId));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Channel Memberships & Fan Funding',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 20,
            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
        ),
        actions: [
          IconButton(
            tooltip: 'Preview Fan Experience',
            icon: Icon(
              Icons.visibility_outlined,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
              size: 20,
            ),
            onPressed: () => showFanPreviewModal(
              context: context,
              controller: controller,
              isDarkMode: isDarkMode,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Obx(() {
              final atMax = controller.hasReachedMaxTiers;
              return Tooltip(
                message: atMax
                    ? 'Channels are limited to 3 membership tiers'
                    : 'Create a new tier (${controller.remainingTierSlots} slots remaining)',
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (atMax) {
                      AppSnackbar.warning(
                        'Channels can have up to 3 membership tiers only. Please edit or remove an existing tier to add a new one.',
                      );
                      return;
                    }
                    showCreateOrEditTierDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    );
                  },
                  icon: Icon(
                    atMax ? Icons.lock_outline_rounded : Icons.add_rounded,
                    color: atMax
                        ? (isDarkMode ? Colors.white60 : Colors.black54)
                        : Colors.black,
                    size: 18,
                  ),
                  label: Text(atMax ? '3/3 Tiers' : 'Add Tier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: atMax
                        ? (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200)
                        : AppColors.brand,
                    foregroundColor: atMax
                        ? (isDarkMode ? AppColors.textSecondary : Colors.black54)
                        : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Commission Notice Banner (reflects 0% Guarantee OR 30% Platform Cut when Member Ad-Free is enabled)
            CommissionNoticeBanner(
              controller: controller,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),

            // Top Key Performance Indicators (KPIs)
            MembershipsMetricsSummary(
              controller: controller,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 24),

            // Sub-Navigation Tabs
            MembershipsSubTabBar(
              controller: controller,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),

            // Dynamic Tab Views
            Obx(() {
              switch (controller.selectedTab.value) {
                case 0:
                  return MembershipTiersTab(
                    controller: controller,
                    isDarkMode: isDarkMode,
                    onOpenStarterBundles: () => showStarterBundlesDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    ),
                    onOpenCreateTier: () => showCreateOrEditTierDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    ),
                    onEditTier: (tier) => showCreateOrEditTierDialog(
                      context: context,
                      controller: controller,
                      tier: tier,
                      isDarkMode: isDarkMode,
                    ),
                    onDeleteTier: (tier) => showConfirmDeleteTierDialog(
                      context: context,
                      controller: controller,
                      tier: tier,
                      isDarkMode: isDarkMode,
                    ),
                  );
                case 1:
                  return MembersListTab(
                    controller: controller,
                    isDarkMode: isDarkMode,
                  );
                case 2:
                  return MembershipsAnalyticsTab(
                    controller: controller,
                    isDarkMode: isDarkMode,
                  );
                default:
                  return MembershipTiersTab(
                    controller: controller,
                    isDarkMode: isDarkMode,
                    onOpenStarterBundles: () => showStarterBundlesDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    ),
                    onOpenCreateTier: () => showCreateOrEditTierDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    ),
                    onEditTier: (tier) => showCreateOrEditTierDialog(
                      context: context,
                      controller: controller,
                      tier: tier,
                      isDarkMode: isDarkMode,
                    ),
                    onDeleteTier: (tier) => showConfirmDeleteTierDialog(
                      context: context,
                      controller: controller,
                      tier: tier,
                      isDarkMode: isDarkMode,
                    ),
                  );
              }
            }),
          ],
        ),
      ),
    );
  }
}
