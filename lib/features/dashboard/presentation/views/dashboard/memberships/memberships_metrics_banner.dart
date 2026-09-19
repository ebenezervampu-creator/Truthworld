import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 0% Platform Commission Guarantee Banner for Creators.
class CommissionNoticeBanner extends StatelessWidget {
  const CommissionNoticeBanner({
    super.key,
    this.isDarkMode = true,
  });

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
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
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '0% Platform Commission Guarantee',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '100% of your channel memberships & recurring fan support revenues go directly to your creator account without any platform cuts or commission fees.',
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
      final currencySymbol = controller.primaryCurrencySymbol;
      final isUsd = currencySymbol == r'$';
      final currencyFormat = NumberFormat.currency(
        symbol: currencySymbol,
        decimalDigits: 2,
      );
      final rate = Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;
      final incomeSubtitle = isUsd && mrr > 0
          ? '≈ ₹${(mrr * rate).toStringAsFixed(2)} Payout'
          : '100% Direct Payout';

      return Row(
        children: [
          Expanded(
            child: MembershipMetricTile(
              title: 'Active Members',
              value: activeMembers.toString(),
              subtitle: 'Direct Supporters',
              icon: Icons.people_alt_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MembershipMetricTile(
              title: 'Monthly Fan Income',
              value: currencyFormat.format(mrr),
              subtitle: incomeSubtitle,
              icon: Icons.account_balance_wallet_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MembershipMetricTile(
              title: 'Active Tiers',
              value: '$activeTiers Tiers',
              subtitle: 'Published & Live',
              icon: Icons.workspace_premium_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MembershipMetricTile(
              title: 'Platform Fee Rate',
              value: '0.0%',
              subtitle: 'Zero Commission',
              icon: Icons.verified_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
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
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppColors.bgDivider
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: isDarkMode ? Colors.white : Colors.black87, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          item['title'] as String,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
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
