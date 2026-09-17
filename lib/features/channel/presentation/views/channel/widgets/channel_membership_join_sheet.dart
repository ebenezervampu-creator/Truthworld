import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_membership_join_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet allowing fans to view and join a creator's Channel Membership tiers.
class ChannelMembershipJoinSheet extends StatelessWidget {
  const ChannelMembershipJoinSheet({
    required this.channelId,
    this.channel,
    super.key,
  });

  final String channelId;
  final Channel? channel;

  static void show(BuildContext context, {required String channelId, Channel? channel}) {
    final tag = 'join_membership_$channelId';
    if (!Get.isRegistered<ChannelMembershipJoinController>(tag: tag)) {
      Get.put(
        ChannelMembershipJoinController(channelId: channelId, channel: channel),
        tag: tag,
      );
    }
    Get.bottomSheet(
      ChannelMembershipJoinSheet(channelId: channelId, channel: channel),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    ).whenComplete(() {
      if (Get.isRegistered<ChannelMembershipJoinController>(tag: tag)) {
        Get.delete<ChannelMembershipJoinController>(tag: tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tag = 'join_membership_$channelId';
    final controller = Get.isRegistered<ChannelMembershipJoinController>(tag: tag)
        ? Get.find<ChannelMembershipJoinController>(tag: tag)
        : Get.put(
            ChannelMembershipJoinController(channelId: channelId, channel: channel),
            tag: tag,
          );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          _buildHeader(context, controller),

          // Content Area
          Flexible(
            child: Obx(() {
              if (controller.isLoadingTiers.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              }

              if (controller.tiers.isEmpty) {
                return _buildEmptyTiers();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prominently display current active membership if user has joined
                    if (controller.isMember.value && controller.currentMembership.value != null) ...[
                      _buildCurrentMembershipBanner(context, controller),
                      const SizedBox(height: 14),
                    ],

                    // Section title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          controller.isMember.value ? 'Membership Plans' : 'Select a Tier',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (controller.isMember.value)
                          const Text(
                            'Select plan to upgrade',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tier selection pills
                    _buildTierSelector(controller),
                    const SizedBox(height: 16),

                    // Active tier detail card
                    _buildTierDetailCard(context, controller),
                  ],
                ),
              );
            }),
          ),

          // Bottom Action Bar
          Obx(() => _buildBottomBar(context, controller)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ChannelMembershipJoinController controller) {
    final channelName = channel?.name ?? 'Channel';
    final avatarUrl = channel?.avatarUrl ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.bgPage,
            backgroundImage: avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person_rounded, size: 20, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() {
              final isMember = controller.isMember.value;
              final cur = controller.currentMembership.value;
              final title = isMember ? '$channelName Member' : 'Join $channelName';
              final subtitle = isMember && cur != null
                  ? 'Active Plan: ${cur.tierName} • Manage perks or upgrade'
                  : 'Unlock exclusive badges, perks & support the creator';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            onPressed: () => Get.back<void>(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMembershipBanner(
    BuildContext context,
    ChannelMembershipJoinController controller,
  ) {
    final cur = controller.currentMembership.value;
    if (cur == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF132B20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cur.tierName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CURRENT',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cur.price > 0
                      ? 'Active Membership • ${cur.formattedPrice} / month'
                      : 'Active Membership',
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTiers() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.stars_outlined, color: Colors.white, size: 48),
          SizedBox(height: 12),
          Text(
            'Memberships Coming Soon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'This channel has not published any membership tiers yet. Check back soon!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector(ChannelMembershipJoinController controller) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: controller.tiers.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tier = controller.tiers[index];
          final isSelected = controller.selectedTierIndex.value == index;
          final isCurrentTier = controller.isMember.value &&
              controller.currentMembership.value?.tierId == tier.id;

          return InkWell(
            onTap: () => controller.selectTier(index),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? tier.badgeColor.withValues(alpha: 0.2)
                    : (isCurrentTier ? const Color(0xFF132B20) : AppColors.bgPage),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? tier.badgeColor
                      : (isCurrentTier
                          ? const Color(0xFF10B981).withValues(alpha: 0.6)
                          : AppColors.bgDivider),
                  width: isSelected || isCurrentTier ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCurrentTier ? const Color(0xFF10B981) : tier.badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCurrentTier ? '${tier.name} (Current)' : tier.name,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isCurrentTier ? const Color(0xFF34D399) : AppColors.textSecondary),
                      fontSize: 13,
                      fontWeight: isSelected || isCurrentTier ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTierDetailCard(
    BuildContext context,
    ChannelMembershipJoinController controller,
  ) {
    final tier = controller.selectedTier;
    if (tier == null) return const SizedBox.shrink();

    final isCurrentTier =
        controller.isMember.value && controller.currentMembership.value?.tierId == tier.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tier.badgeColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tier price & badge icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tier.formattedPrice} / month',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Loyalty Badge Preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tier.badgeColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tier.badgeColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _resolveBadgeIcon(tier.badgeIcon),
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Loyalty Badge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tier.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tier.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const Divider(color: AppColors.bgDivider, height: 24),

          // Perks list
          const Text(
            'Included Member Perks:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...tier.perks.map((perk) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        perk,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          if (isCurrentTier) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'You are currently an active member of this tier.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else if (controller.isMember.value) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upgrade_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tier.price > (controller.currentMembership.value?.price ?? 0)
                          ? 'Upgrade your membership to unlock all exclusive perks in ${tier.name}.'
                          : 'Switch your active plan to ${tier.name}.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ChannelMembershipJoinController controller,
  ) {
    final tier = controller.selectedTier;
    if (tier == null || controller.tiers.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCurrentTier =
        controller.isMember.value && controller.currentMembership.value?.tierId == tier.id;
    final isUpgrading = controller.isMember.value && !isCurrentTier;
    final currentTierPrice = controller.currentMembership.value?.price ?? 0;
    final isHigher = tier.price > currentTierPrice;
    final actionLabel = isUpgrading
        ? (isHigher ? 'Upgrade to ${tier.name}' : 'Switch to ${tier.name}')
        : 'Join';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.bgDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (isCurrentTier) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: controller.isProcessing.value
                      ? null
                      : controller.cancelMembership,
                  child: const Text('Cancel Membership'),
                ),
              ),
            ] else ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: controller.isProcessing.value
                      ? null
                      : controller.joinSelectedTier,
                  child: controller.isProcessing.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Text(
                          '$actionLabel for ${tier.formattedPrice} / month',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _resolveBadgeIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'crown':
        return Icons.emoji_events_rounded;
      case 'heart':
        return Icons.favorite_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'shield':
        return Icons.shield_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}
