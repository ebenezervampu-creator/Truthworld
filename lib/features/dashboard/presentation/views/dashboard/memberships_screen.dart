import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      backgroundColor: isDarkMode ? AppColors.bgPage : const Color(0xFFF8FAFC),
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
            icon: const Icon(
              Icons.visibility_outlined,
              color: AppColors.textPrimary,
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
            child: ElevatedButton.icon(
              onPressed: () => showCreateOrEditTierDialog(
                context: context,
                controller: controller,
                isDarkMode: isDarkMode,
              ),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.black,
                size: 18,
              ),
              label: const Text('Add Tier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
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
