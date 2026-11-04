import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships/member_avatar_stack.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 0% Platform Commission Guarantee Banner OR 30% Platform Cut Banner for Creators.
class CommissionNoticeBanner extends StatelessWidget {
  const CommissionNoticeBanner({
    super.key,
    this.controller,
    this.isDarkMode = true,
  });

  final MembershipsController? controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    Widget buildBanner({
      required bool isNoAdsActive,
      required bool isCustom,
    }) {
      final bannerTitle = isNoAdsActive
          ? 'Channel Premium Active (30% Platform Cut • 70% Creator Take-Home)'
          : (isCustom
              ? 'Pro Channel: 0% Platform Commission Guarantee'
              : 'Standard Channel: 90% Creator Revenue (10% Platform Fee)');
      final bannerSubtitle = isNoAdsActive
          ? 'Your channel members enjoy 100% ad-free viewing and 4K Ultra HD streaming across all your videos. TruthWorld retains a 30% revenue share on memberships to fund high-bitrate streaming without ads, and 70% goes directly to you.'
          : (isCustom
              ? '100% of your channel memberships & recurring fan support revenues go directly to your creator account without any platform cuts (SaaS infrastructure tier).'
              : '90% of your channel memberships & recurring fan support revenues go directly to your creator account (10% platform fee covers payment processing & hosting).');

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isNoAdsActive
                ? const [Color(0xFF92400E), AppColors.warning]
                : const [Color(0xFF065F46), AppColors.success],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isNoAdsActive ? AppColors.warning : AppColors.success)
                  .withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNoAdsActive ? Icons.workspace_premium_rounded : Icons.stars_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bannerTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bannerSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (controller != null) {
      return Obx(() => buildBanner(
            isNoAdsActive: controller!.noAdsForMembers.value,
            isCustom: controller!.isCustomChannel.value,
          ));
    }
    return buildBanner(isNoAdsActive: false, isCustom: false);
  }
}

/// Key Performance Indicators (KPIs) Summary Bar.
class MembershipsMetricsSummary extends StatelessWidget {
  const MembershipsMetricsSummary({
    required this.controller,
    this.isDarkMode = true,
    super.key,
  });

  final MembershipsController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeMembers = controller.totalActiveMembers;
      final mrr = controller.monthlyRecurringRevenue;
      final activeTiers = controller.activeTiersCount;
      final isNoAds = controller.noAdsForMembers.value;
      final creatorMrr = controller.creatorMonthlyRecurringRevenue;
      final displayMrr = isNoAds ? creatorMrr : mrr;

      final currencySymbol = controller.primaryCurrencySymbol;
      final isUsd = currencySymbol == r'$';
      final currencyFormat = NumberFormat.currency(
        symbol: currencySymbol,
        decimalDigits: 2,
      );
      final rate = Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;
      final isCustom = controller.isCustomChannel.value;
      final incomeSubtitle = isNoAds
          ? '70% Net Take-Home (30% Platform Cut)'
          : (isCustom
              ? (isUsd && mrr > 0
                  ? '≈ ₹${(mrr * rate).toStringAsFixed(2)} Payout (100%)'
                  : '100% Direct Payout (0% Cut)')
              : '90% Net Payout (10% Fee)');

      final activeMemberList = controller.members
          .where((m) => m.status.toLowerCase() == 'active')
          .toList();

      final activeMembersTile = MembershipMetricTile(
        title: 'Active Members',
        value: activeMembers.toString(),
        subtitle: activeMembers == 1 ? '1 Active Supporter' : 'Direct Supporters',
        icon: Icons.people_alt_rounded,
        isDarkMode: isDarkMode,
        members: activeMemberList,
        onTap: () => controller.selectedTab.value = 1,
      );

      final monthlyIncomeTile = MembershipMetricTile(
        title: 'Monthly Fan Income',
        value: currencyFormat.format(displayMrr),
        subtitle: incomeSubtitle,
        icon: Icons.account_balance_wallet_rounded,
        isDarkMode: isDarkMode,
        onTap: () => controller.selectedTab.value = 2,
      );

      final activeTiersTile = MembershipMetricTile(
        title: 'Active Tiers',
        value: '$activeTiers Tiers',
        subtitle: 'Published & Live',
        icon: Icons.workspace_premium_rounded,
        isDarkMode: isDarkMode,
        onTap: () => controller.selectedTab.value = 0,
      );

      final platformFeeTile = MembershipMetricTile(
        title: 'Platform Fee Rate',
        value: isNoAds ? '30.0%' : '0.0%',
        subtitle: isNoAds ? 'Channel Premium' : 'Zero Commission',
        icon: Icons.verified_rounded,
        isDarkMode: isDarkMode,
        onTap: () => controller.selectedTab.value = 2,
      );

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 640;
          if (isMobile) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: activeMembersTile),
                    const SizedBox(width: 10),
                    Expanded(child: monthlyIncomeTile),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: activeTiersTile),
                    const SizedBox(width: 10),
                    Expanded(child: platformFeeTile),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: activeMembersTile),
              const SizedBox(width: 12),
              Expanded(child: monthlyIncomeTile),
              const SizedBox(width: 12),
              Expanded(child: activeTiersTile),
              const SizedBox(width: 12),
              Expanded(child: platformFeeTile),
            ],
          );
        },
      );
    });
  }
}

/// Individual KPI Tile for Studio Memberships.
class MembershipMetricTile extends StatelessWidget {
  const MembershipMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.isDarkMode = true,
    this.members,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool isDarkMode;
  final List<ChannelMember>? members;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tileContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 17,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (members != null && members!.isNotEmpty) ...[
                const SizedBox(width: 8),
                MemberAvatarStack(
                  members: members!,
                  avatarRadius: 10,
                  maxDisplay: 3,
                  isDarkMode: isDarkMode,
                  borderWidth: 1.5,
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: tileContent,
      );
    }
    return tileContent;
  }
}

/// Studio Memberships Sub-Tab Navigation Bar.
class MembershipsSubTabBar extends StatelessWidget {
  const MembershipsSubTabBar({
    required this.controller,
    this.isDarkMode = true,
    super.key,
  });

  final MembershipsController controller;
  final bool isDarkMode;

  static const List<Map<String, dynamic>> _tabs = [
    {'title': 'Tiers & Perks', 'icon': Icons.layers_rounded},
    {'title': 'Members & Community', 'icon': Icons.people_outline_rounded},
    {'title': 'Analytics & Payouts', 'icon': Icons.insights_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final curTab = controller.selectedTab.value;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.bgSurface : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final isSelected = curTab == index;
            final item = _tabs[index];
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.selectedTab.value = index,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode ? AppColors.bgSurfaceHigh : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 15,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : (isSelected ? Colors.black87 : Colors.black54),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item['title'] as String,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? (isDarkMode
                                      ? AppColors.textPrimary
                                      : Colors.black87)
                                : (isDarkMode
                                      ? AppColors.textSecondary
                                      : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      );
    });
  }
}
