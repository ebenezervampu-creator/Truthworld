import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_membership_join_controller.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet allowing fans to view and join a creator's Channel Membership tiers.
/// Styled strictly according to the Library screen UI, fonts, and dark theme design tokens.
class ChannelMembershipJoinSheet extends StatelessWidget {
  const ChannelMembershipJoinSheet({
    required this.channelId,
    this.channel,
    super.key,
  });

  final String channelId;
  final Channel? channel;

  static void show(BuildContext context, {required String channelId, Channel? channel}) {
    final effectiveChannel = channel ?? ChannelMemoryCache.get(channelId);
    if (effectiveChannel != null && !effectiveChannel.isMonetizationActive) {
      AppSnackbar.info('Channel memberships are only available for monetized channels.');
      return;
    }

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
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Bar
          _buildHeader(context, controller),

          // Content Area
          Flexible(
            child: Obx(() {
              if (controller.isLoadingTiers.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                    ),
                  ),
                );
              }

              final currentChannel = controller.channelData.value ?? channel;
              if (currentChannel != null && !currentChannel.isMonetizationActive && !controller.isMember.value) {
                return _buildUnmonetizedState();
              }

              if (controller.tiers.isEmpty) {
                return _buildEmptyTiers();
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prominently display current active membership if user has joined
                    if (controller.isMember.value && controller.currentMembership.value != null) ...[
                      _buildCurrentMembershipBanner(context, controller),
                      const SizedBox(height: 16),
                    ],

                    // Section title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          controller.isMember.value ? 'Membership Plans' : 'Select a Tier',
                          style: const TextStyle(
                            color: primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (controller.isMember.value)
                          const Text(
                            'Select plan to upgrade',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tier selection pills (Library chip style)
                    _buildTierSelector(controller),
                    const SizedBox(height: 18),

                    // Active tier detail card
                    _buildTierDetailCard(context, controller),
                  ],
                ),
              );
            }),
          ),

          // Bottom Action Bar (Retains Auto Pay switch and Join CTA)
          Obx(() => _buildBottomBar(context, controller)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ChannelMembershipJoinController controller) {
    final channelName = channel?.name ?? 'Channel';
    final avatarUrl = channel?.avatarUrl ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.bgDivider.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          UserAvatar(
            photoUrl: avatarUrl,
            displayName: channelName,
            backgroundColor: buttonBg,
            textColor: primaryText,
            fontSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() {
              final isMember = controller.isMember.value;
              final cur = controller.currentMembership.value;
              final title = isMember ? '$channelName Member' : 'Join $channelName';
              final subtitle = isMember && cur != null
                  ? 'Active: ${cur.tierName} • Manage perks & plan'
                  : 'Unlock exclusive badges, perks & support creator';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: primaryText, size: 22),
            onPressed: () => Get.back<void>(),
            tooltip: 'Close',
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
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: AppColors.success,
              size: 20,
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
                          color: primaryText,
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
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'CURRENT',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  cur.price > 0
                      ? 'Active Membership • ${cur.formattedPriceForUser()} / month'
                      : 'Active Membership',
                  style: const TextStyle(
                    color: secondaryText,
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

  Widget _buildUnmonetizedState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_outlined, color: primaryText, size: 48),
          SizedBox(height: 16),
          Text(
            'Memberships Unavailable',
            style: TextStyle(
              color: primaryText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Channel memberships and fan funding are only available for monetized channels.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTiers() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.stars_outlined, color: primaryText, size: 48),
          SizedBox(height: 16),
          Text(
            'Memberships Coming Soon',
            style: TextStyle(
              color: primaryText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This channel has not published any membership tiers yet. Check back soon!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector(ChannelMembershipJoinController controller) {
    return SizedBox(
      height: 38,
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
            onTap: () {
              HapticFeedback.selectionClick();
              controller.selectTier(index);
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : (isCurrentTier
                        ? AppColors.successContainer
                        : buttonBg),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : (isCurrentTier
                          ? AppColors.success.withValues(alpha: 0.5)
                          : AppColors.textPrimary.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCurrentTier) ...[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  Text(
                    isCurrentTier ? '${tier.name} (Current)' : tier.name,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black87
                          : (isCurrentTier ? AppColors.success : primaryText),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    final isCurrentTier =
        controller.isMember.value && controller.currentMembership.value?.tierId == tier.id;

    final isUsdOriginal = tier.currency.toUpperCase() == 'USD';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bgDivider.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tier title, price & Loyalty Badge preview
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.name,
                      style: const TextStyle(
                        color: primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          tier.formattedPriceForUser(isIndian),
                          style: const TextStyle(
                            color: primaryText,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ month',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (isIndian && isUsdOriginal) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(~${tier.formattedPrice})',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isIndian && isUsdOriginal) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.currency_exchange_rounded,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '1 USD ≈ ₹${rate.toStringAsFixed(2)} INR · Live market rate',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Loyalty Badge Preview
              ChannelLoyaltyBadgeWidget(
                milestone: controller.isMember.value &&
                        controller.currentMembership.value?.joinedAt != null
                    ? ChannelLoyaltyBadge.milestoneFromJoinedAt(
                        controller.currentMembership.value!.joinedAt,
                      )
                    : ChannelLoyaltyMilestone.newMember,
                tierName: tier.name,
              ),
            ],
          ),

          if (tier.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tier.description,
              style: const TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.bgDivider, height: 1),
          ),

          // Zero Ads & 4K badge if channel enabled
          if (controller.isAdFreeChannel) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.bgDivider.withValues(alpha: 0.6),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: primaryText,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Channel Premium: Zero Ads & 4K Streaming',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Members enjoy zero ads and unlock 4K Ultra HD on all channel videos.',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Perks list
          const Text(
            'INCLUDED MEMBER PERKS',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...tier.perks.map((perk) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: primaryText,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        perk,
                        style: const TextStyle(
                          color: primaryText,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          if (isCurrentTier) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are currently an active member of this tier.',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (controller.isMember.value) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.infoContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upgrade_rounded, color: AppColors.info, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tier.price > (controller.currentMembership.value?.price ?? 0)
                          ? 'Upgrade your membership to unlock all exclusive perks in ${tier.name}.'
                          : 'Switch your active plan to ${tier.name}.',
                      style: const TextStyle(
                        color: primaryText,
                        fontSize: 12,
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
    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    final currentTierPrice = controller.currentMembership.value?.price ?? 0;
    final isHigher = tier.price > currentTierPrice;
    final isAutoPay = controller.isAutoPay.value;
    final autoPaySuffix = isAutoPay ? 'with Auto Pay for' : '(One-Time) for';
    final actionLabel = isUpgrading
        ? (isHigher ? 'Upgrade to ${tier.name}' : 'Switch to ${tier.name}')
        : 'Join';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: AppColors.bgDivider.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Auto Pay Toggle Card
            if (!isCurrentTier) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: AppColors.bgElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        color: primaryText,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Auto Pay',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAutoPay
                                      ? AppColors.textPrimary.withValues(alpha: 0.12)
                                      : AppColors.bgElevated,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isAutoPay ? 'RECURRING' : 'ONE-TIME',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: isAutoPay
                                        ? primaryText
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAutoPay
                                ? 'Auto-renews monthly so loyalty badges stay active. Cancel anytime.'
                                : 'Valid for 1 month only. No automatic renewal.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: isAutoPay,
                      onChanged: (val) {
                        controller.toggleAutoPay(val);
                      },
                      activeColor: Colors.black,
                      activeTrackColor: Colors.white,
                      inactiveThumbColor: AppColors.textTertiary,
                      inactiveTrackColor: AppColors.bgElevated,
                    ),
                  ],
                ),
              ),
            ],

            // Action Button (Join / Upgrade / Cancel)
            Row(
              children: [
                if (isCurrentTier) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: controller.isProcessing.value
                          ? null
                          : controller.cancelMembership,
                      child: controller.isProcessing.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                              ),
                            )
                          : const Text(
                              'Cancel Membership',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
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
                              '$actionLabel $autoPaySuffix ${tier.formattedPriceForUser(isIndian)}${isAutoPay ? ' / month' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.1,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Secured by Cashfree • ${CurrencyLocalizationService.to.paymentMethodsSummary}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
