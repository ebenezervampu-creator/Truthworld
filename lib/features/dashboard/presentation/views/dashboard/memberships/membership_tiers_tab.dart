import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships/membership_tier_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Tab 1: Membership Levels & Included Perks Management.
class MembershipTiersTab extends StatelessWidget {
  const MembershipTiersTab({
    required this.controller,
    required this.onOpenStarterBundles,
    required this.onOpenCreateTier,
    required this.onEditTier,
    required this.onDeleteTier,
    this.isDarkMode = true,
    super.key,
  });

  final MembershipsController controller;
  final bool isDarkMode;
  final VoidCallback onOpenStarterBundles;
  final VoidCallback onOpenCreateTier;
  final void Function(ChannelMembershipTier tier) onEditTier;
  final void Function(ChannelMembershipTier tier) onDeleteTier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Membership Levels & Perks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() {
                        final atMax = controller.hasReachedMaxTiers;
                        final count = controller.tiers.length;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: atMax
                                ? Colors.amber.withValues(alpha: 0.2)
                                : (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: atMax
                                  ? (isDarkMode ? Colors.amber.shade700 : Colors.amber.shade400)
                                  : (isDarkMode ? AppColors.bgDivider : Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            atMax ? '3/3 Tiers (Max)' : '$count/3 Tiers',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: atMax
                                  ? (isDarkMode ? Colors.amber.shade300 : Colors.amber.shade800)
                                  : (isDarkMode ? AppColors.textSecondary : Colors.black87),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage tier pricing, benefits, and loyalty badges offered to fans (up to 3 tiers).',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenStarterBundles,
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text('Starter Templates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black87,
                    side: BorderSide(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() {
                  final atMax = controller.hasReachedMaxTiers;
                  return Tooltip(
                    message: atMax
                        ? 'Channels can have up to 3 membership tiers only'
                        : 'Create a new tier (${controller.remainingTierSlots} slots remaining)',
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (atMax) {
                          AppSnackbar.warning(
                            'Channels can have up to 3 membership tiers only. Please edit or remove an existing tier to add a new one.',
                          );
                          return;
                        }
                        onOpenCreateTier();
                      },
                      icon: Icon(
                        atMax ? Icons.lock_outline_rounded : Icons.add_rounded,
                        color: atMax
                            ? (isDarkMode ? Colors.white60 : Colors.black54)
                            : Colors.black,
                        size: 16,
                      ),
                      label: Text(atMax ? '3/3 Tiers' : 'New Tier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: atMax
                            ? (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200)
                            : AppColors.brand,
                        foregroundColor: atMax
                            ? (isDarkMode ? AppColors.textSecondary : Colors.black54)
                            : Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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
              ],
            ),
          ],
        ),
        // Channel Member Ad-Free Playback Feature Card
        MemberAdFreeFeatureCard(
          controller: controller,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 20),

        Obx(() {
          if (controller.isLoadingTiers.value) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFF1E1E1E),
              highlightColor: AppColors.bgSurfaceHover,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            );
          }

          final tiers = controller.tiers;
          if (tiers.isEmpty) {
            return EmptyTiersView(
              isDarkMode: isDarkMode,
              onApplyStarterBundles: onOpenStarterBundles,
              onCreateTier: onOpenCreateTier,
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (ctx, index) {
              final tier = tiers[index];
              return MembershipTierCard(
                tier: tier,
                isDarkMode: isDarkMode,
                onEdit: () => onEditTier(tier),
                onToggleStatus: () =>
                    controller.toggleTierStatus(tier.id, !tier.isEnabled),
                onDuplicate: () => controller.duplicateTier(tier),
                onDelete: () => onDeleteTier(tier),
              );
            },
          );
        }),
      ],
    );
  }
}

/// Dedicated Card for Creators to enable/disable "No Ads for Members" with 30% platform cut.
class MemberAdFreeFeatureCard extends StatelessWidget {
  const MemberAdFreeFeatureCard({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final MembershipsController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isEnabled = controller.noAdsForMembers.value;
      final isUpdating = controller.isUpdatingSettings.value;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.bgSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled
                ? (isDarkMode ? Colors.amber.shade700 : Colors.amber.shade400)
                : (isDarkMode ? AppColors.bgDivider : Colors.grey.shade300),
            width: isEnabled ? 1.5 : 1,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: isDarkMode ? 0.1 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? Colors.amber.withValues(alpha: 0.15)
                        : (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEnabled ? Icons.block_rounded : Icons.play_circle_outline_rounded,
                    color: isEnabled
                        ? (isDarkMode ? Colors.amber.shade300 : Colors.amber.shade800)
                        : (isDarkMode ? Colors.white : Colors.black87),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Channel Premium (No Ads & Up to 2K for Members)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isEnabled
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isEnabled ? '30% Platform Cut • Channel Premium' : '0% Commission',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isEnabled
                                    ? (isDarkMode ? Colors.amber.shade300 : Colors.amber.shade900)
                                    : (isDarkMode ? Colors.green.shade400 : Colors.green.shade800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Transform channel memberships into a Channel Premium subscription for your audience. Active members unlock zero ads across your channel and high resolutions up to 2K (1440p QHD) video streaming for entire channel videos. TruthWorld takes a 30% platform cut on tiers with this bundle (Creator receives 70%). Tiers without the bundle receive 100% of revenue with 0% platform commission.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildPremiumChip(
                            icon: Icons.block_rounded,
                            label: 'Zero Ads on Channel',
                            isDarkMode: isDarkMode,
                            isEnabled: isEnabled,
                          ),
                          _buildPremiumChip(
                            icon: Icons.high_quality_rounded,
                            label: 'Up to 2K (1440p QHD)',
                            isDarkMode: isDarkMode,
                            isEnabled: isEnabled,
                          ),
                          _buildPremiumChip(
                            icon: Icons.percent_rounded,
                            label: '70% Creator / 30% Platform Cut',
                            isDarkMode: isDarkMode,
                            isEnabled: isEnabled,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isUpdating)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  )
                else
                  Switch.adaptive(
                    value: isEnabled,
                    activeColor: isDarkMode ? Colors.amber.shade400 : Colors.amber.shade700,
                    onChanged: controller.toggleNoAdsForMembers,
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPremiumChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    required bool isEnabled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode
            ? (isEnabled
                ? Colors.amber.withValues(alpha: 0.12)
                : AppColors.bgSurfaceHigh)
            : (isEnabled
                ? Colors.amber.withValues(alpha: 0.15)
                : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEnabled
              ? (isDarkMode
                  ? Colors.amber.shade700.withValues(alpha: 0.5)
                  : Colors.amber.shade300)
              : (isDarkMode ? AppColors.bgDivider : Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
