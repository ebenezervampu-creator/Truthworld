import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
                  Text(
                    'Membership Levels & Perks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage tier pricing, benefits, and loyalty badges offered to fans.',
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
                ElevatedButton.icon(
                  onPressed: onOpenCreateTier,
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.black,
                    size: 16,
                  ),
                  label: const Text('New Tier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
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
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        Obx(() {
          if (controller.isLoadingTiers.value) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.brand),
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
