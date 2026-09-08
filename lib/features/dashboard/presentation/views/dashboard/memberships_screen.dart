import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// Export ChannelMembershipTier and ChannelMember for backward compatibility
export 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart'
    show ChannelMember, ChannelMembershipTier, StarterTierBundle, StarterTierBundleType;

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
            onPressed: () => _showFanPreviewModal(context, controller, isDarkMode),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateOrEditTierDialog(
                context: context,
                controller: controller,
                isDarkMode: isDarkMode,
              ),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
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
            // 0% Platform Commission Guarantee Banner
            _buildCommissionNoticeBanner(isDarkMode),
            const SizedBox(height: 20),

            // Top Key Performance Indicators (KPIs)
            _buildMetricsSummary(controller, isDarkMode),
            const SizedBox(height: 24),

            // Sub-Navigation Tabs
            _buildSubTabBar(controller, isDarkMode),
            const SizedBox(height: 20),

            // Dynamic Tab Views
            Obx(() {
              switch (controller.selectedTab.value) {
                case 0:
                  return _buildTiersTab(context, controller, isDarkMode);
                case 1:
                  return _buildMembersTab(context, controller, isDarkMode);
                case 2:
                  return _buildAnalyticsTab(context, controller, isDarkMode);
                default:
                  return _buildTiersTab(context, controller, isDarkMode);
              }
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TOP BANNER & METRICS
  // ==========================================================================

  Widget _buildCommissionNoticeBanner(bool isDarkMode) {
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

  Widget _buildMetricsSummary(MembershipsController controller, bool isDarkMode) {
    final currencyFormat = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Obx(() {
      final activeMembers = controller.totalActiveMembers;
      final mrr = controller.monthlyRecurringRevenue;
      final activeTiers = controller.activeTiersCount;

      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Active Members',
              value: activeMembers.toString(),
              subtitle: 'Direct Supporters',
              icon: Icons.people_alt_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              title: 'Monthly Fan Income',
              value: currencyFormat.format(mrr),
              subtitle: '100% Direct Payout',
              icon: Icons.account_balance_wallet_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              title: 'Active Tiers',
              value: '$activeTiers Tiers',
              subtitle: 'Published & Live',
              icon: Icons.workspace_premium_rounded,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
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

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required bool isDarkMode,
  }) {
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
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white, size: 18),
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

  Widget _buildSubTabBar(MembershipsController controller, bool isDarkMode) {
    final tabs = [
      {'title': 'Tiers & Perks', 'icon': Icons.layers_rounded},
      {'title': 'Members & Community', 'icon': Icons.people_outline_rounded},
      {'title': 'Analytics & Payouts', 'icon': Icons.insights_rounded},
    ];

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
          children: List.generate(tabs.length, (index) {
            final isSelected = curTab == index;
            final item = tabs[index];
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
                        item['icon']! as IconData,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['title']! as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isDarkMode ? AppColors.textPrimary : Colors.black87)
                              : (isDarkMode ? AppColors.textSecondary : Colors.black54),
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

  // ==========================================================================
  // TAB 1: TIERS & PERKS
  // ==========================================================================

  Widget _buildTiersTab(
    BuildContext context,
    MembershipsController controller,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showStarterBundlesDialog(context, controller, isDarkMode),
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text('Starter Templates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    side: BorderSide(
                      color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showCreateOrEditTierDialog(
                    context: context,
                    controller: controller,
                    isDarkMode: isDarkMode,
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text('New Tier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            return _buildEmptyTiersView(context, controller, isDarkMode);
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (ctx, index) {
              final tier = tiers[index];
              return _buildTierCard(context, controller, tier, isDarkMode);
            },
          );
        }),
      ],
    );
  }

  Widget _buildEmptyTiersView(
    BuildContext context,
    MembershipsController controller,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Membership Tiers Created Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              r'Set up membership levels (e.g. Bronze $1.99/mo, Silver VIP $4.99/mo, Gold Patron $9.99/mo) so fans can support your channel directly with 0% platform commission.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showStarterBundlesDialog(context, controller, isDarkMode),
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text('Setup Default Starter Tiers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCreateOrEditTierDialog(
                  context: context,
                  controller: controller,
                  isDarkMode: isDarkMode,
                ),
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text('Create Custom Tier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  side: BorderSide(
                    color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade400,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context,
    MembershipsController controller,
    ChannelMembershipTier tier,
    bool isDarkMode,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tier.isEnabled
              ? (isDarkMode ? AppColors.bgDivider : Colors.grey.shade200)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: tier.badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tier.badgeColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          tier.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!tier.isEnabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PAUSED',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${tier.price.toStringAsFixed(2)} / mo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showCreateOrEditTierDialog(
                        context: context,
                        controller: controller,
                        tier: tier,
                        isDarkMode: isDarkMode,
                      );
                    } else if (val == 'toggle') {
                      controller.toggleTierStatus(tier.id, !tier.isEnabled);
                    } else if (val == 'duplicate') {
                      controller.duplicateTier(tier);
                    } else if (val == 'delete') {
                      _confirmDeleteTier(context, controller, tier, isDarkMode);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Edit Tier',
                            style: TextStyle(
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            tier.isEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            tier.isEnabled ? 'Pause Tier' : 'Enable Tier',
                            style: TextStyle(
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Duplicate Tier',
                            style: TextStyle(
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text('Delete Tier', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (tier.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tier.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
            ),
            const SizedBox(height: 14),
            Text(
              'INCLUDED PERKS & BENEFITS (${tier.perks.length}):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            if (tier.perks.isEmpty)
              const Text(
                '• Loyalty badge beside name in comments',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tier.perks.map((perk) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgSurfaceHigh
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          perk,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 2: MEMBERS & COMMUNITY
  // ==========================================================================

  Widget _buildMembersTab(
    BuildContext context,
    MembershipsController controller,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscribed Channel Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fans actively supporting your channel through recurring memberships.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
              ],
            ),
            // Tier Filter Dropdown
            Obx(() {
              final tiers = controller.tiers;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.bgSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                  ),
                ),
                child: DropdownButton<String>(
                  value: controller.selectedTierFilter.value,
                  underline: const SizedBox.shrink(),
                  dropdownColor: isDarkMode ? AppColors.bgSurfaceHigh : Colors.white,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Tiers',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                    ),
                    ...tiers.map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                          ),
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null) controller.selectedTierFilter.value = val;
                  },
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        Obx(() {
          final members = controller.filteredMembers;

          if (members.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Members Subscribed Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When fans subscribe to your membership tiers, their profiles, perks status, and contribution history will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              final member = members[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.bgSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                      backgroundImage: member.userAvatarUrl.isNotEmpty
                          ? NetworkImage(member.userAvatarUrl)
                          : null,
                      child: member.userAvatarUrl.isEmpty
                          ? Text(
                              member.userName.isNotEmpty ? member.userName[0].toUpperCase() : 'M',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.userName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Joined: ${member.joinedAt != null ? DateFormat.yMMMd().format(member.joinedAt!) : 'Recently'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        member.tierName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '\$${member.price.toStringAsFixed(2)}/mo',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // TAB 3: ANALYTICS & PAYOUTS
  // ==========================================================================

  Widget _buildAnalyticsTab(
    BuildContext context,
    MembershipsController controller,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fan Funding & Revenue Projections',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Industry benchmarks and instant recurring earnings breakdown.',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? AppColors.textSecondary : Colors.black54,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Creator Payout Terms',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '100% TO CREATOR',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFeatureRow('Platform Cut / Commission', '0.0% (Zero platform fees)', isDarkMode),
              _buildFeatureRow('Payout Frequency', 'Monthly Automatic Transfer', isDarkMode),
              _buildFeatureRow('Billing Cycle', '30-Day Recurring Fan Subscription', isDarkMode),
              _buildFeatureRow('Payment Protection', 'Encrypted Bank & Wallet Processing', isDarkMode),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DIALOGS: CREATE / EDIT TIER
  // ==========================================================================

  void _showCreateOrEditTierDialog({
    required BuildContext context,
    required MembershipsController controller,
    required bool isDarkMode,
    ChannelMembershipTier? tier,
  }) {
    final isEditing = tier != null;
    final nameController = TextEditingController(text: tier?.name ?? '');
    final priceController = TextEditingController(
      text: tier != null ? tier.price.toStringAsFixed(2) : '4.99',
    );
    final descController = TextEditingController(text: tier?.description ?? '');
    final customPerkController = TextEditingController();

    final activePerks = <String>[
      if (tier != null)
        ...tier.perks
      else ...[
        'Loyalty badge beside channel comments',
        'Custom emojis in live chat',
        'Early access to new videos',
      ],
    ].obs;

    final selectedColorHex = (tier?.badgeColorHex ?? '0xFFF59E0B').obs;
    final nameRx = (tier?.name ?? 'Silver VIP').obs;
    final priceRx = (tier?.price ?? 4.99).obs;
    final isSubmitting = false.obs;

    nameController.addListener(() {
      nameRx.value = nameController.text.trim().isEmpty ? 'Tier Name' : nameController.text.trim();
    });

    priceController.addListener(() {
      final p = double.tryParse(priceController.text.trim());
      if (p != null) priceRx.value = p;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Membership Tier' : 'Create Membership Tier',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Scrollable Form Content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tier Name
                          Text(
                            'TIER NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            style: TextStyle(
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Bronze Supporter, Silver VIP, Gold Patron',
                              hintStyle: TextStyle(
                                color: isDarkMode ? AppColors.textSecondary : Colors.black38,
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? AppColors.bgInput
                                  : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Monthly Price
                          Text(
                            'MONTHLY PRICE (USD)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  style: TextStyle(
                                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: r'$ ',
                                    prefixStyle: TextStyle(
                                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    filled: true,
                                    fillColor: isDarkMode
                                        ? AppColors.bgInput
                                        : const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Quick Price Preset Pills
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [0.99, 1.99, 2.99, 4.99, 9.99, 19.99, 24.99].map((p) {
                              return GestureDetector(
                                onTap: () {
                                  priceController.text = p.toStringAsFixed(2);
                                  priceRx.value = p;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '\$${p.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Badge Color Picker
                          Text(
                            'TIER BADGE COLOR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Obx(() {
                            return Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: MembershipsController.presetBadgeColors.map((colorMap) {
                                final hex = colorMap['hex']! as String;
                                final color = colorMap['color']! as Color;
                                final isSelected = selectedColorHex.value == hex;

                                return GestureDetector(
                                  onTap: () => selectedColorHex.value = hex,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(alpha: 0.6),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(Icons.check, size: 16, color: Colors.white),
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            );
                          }),
                          const SizedBox(height: 16),

                          // Description
                          Text(
                            'DESCRIPTION / WELCOME MESSAGE (OPTIONAL)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: descController,
                            maxLines: 2,
                            style: TextStyle(
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Briefly tell your fans what makes this tier special...',
                              hintStyle: TextStyle(
                                color: isDarkMode ? AppColors.textSecondary : Colors.black38,
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? AppColors.bgInput
                                  : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Perks Manager
                          Text(
                            'TIER PERKS & BENEFITS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Popular Perk Suggestions Chips
                          Text(
                            'Quick-add popular perks:',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: MembershipsController.popularPerkSuggestions.map((suggestion) {
                              return ActionChip(
                                label: Text(
                                  '+ $suggestion',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                  ),
                                ),
                                backgroundColor: isDarkMode
                                    ? AppColors.bgSurfaceHigh
                                    : Colors.grey.shade100,
                                onPressed: () {
                                  if (!activePerks.contains(suggestion)) {
                                    activePerks.add(suggestion);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          // Custom Perk Input
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: customPerkController,
                                  style: TextStyle(
                                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add custom perk (e.g. VIP Discord Role)...',
                                    hintStyle: TextStyle(
                                      color: isDarkMode ? AppColors.textSecondary : Colors.black38,
                                    ),
                                    filled: true,
                                    fillColor: isDarkMode
                                        ? AppColors.bgInput
                                        : const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (val) {
                                    final t = val.trim();
                                    if (t.isNotEmpty && !activePerks.contains(t)) {
                                      activePerks.add(t);
                                      customPerkController.clear();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final t = customPerkController.text.trim();
                                  if (t.isNotEmpty && !activePerks.contains(t)) {
                                    activePerks.add(t);
                                    customPerkController.clear();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade300,
                                  foregroundColor: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                ),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Selected Active Perks List
                          Obx(() {
                            if (activePerks.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'No perks added yet. Choose from above or type a custom one.',
                                  style: TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                              );
                            }

                            return Column(
                              children: activePerks.map((p) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? AppColors.bgSurfaceHigh
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          p,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                        onPressed: () => activePerks.remove(p),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Divider(
                    height: 1,
                    color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Obx(() {
                        final loading = isSubmitting.value || controller.isSaving.value;

                        return ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  final name = nameController.text.trim();
                                  final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                                  final desc = descController.text.trim();
                                  final perks = activePerks.toList();
                                  final badgeHex = selectedColorHex.value;

                                  if (name.isEmpty) {
                                    AppSnackbar.show('Error', 'Please enter a tier name.');
                                    return;
                                  }
                                  if (price <= 0) {
                                    AppSnackbar.show('Error', r'Price must be greater than $0.00.');
                                    return;
                                  }
                                  if (perks.isEmpty) {
                                    AppSnackbar.show('Error', 'Please add at least one perk.');
                                    return;
                                  }

                                  isSubmitting.value = true;
                                  bool success;

                                  if (isEditing) {
                                    success = await controller.updateTier(
                                      tier.copyWith(
                                        name: name,
                                        price: price,
                                        description: desc,
                                        perks: perks,
                                        badgeColorHex: badgeHex,
                                      ),
                                    );
                                  } else {
                                    success = await controller.createTier(
                                      name: name,
                                      price: price,
                                      description: desc,
                                      perks: perks,
                                      badgeColorHex: badgeHex,
                                    );
                                  }

                                  isSubmitting.value = false;
                                  if (success && dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(isEditing ? 'Save Changes' : 'Create Tier'),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  // ==========================================================================
  // STARTER TEMPLATES DIALOG
  // ==========================================================================

  void _showStarterBundlesDialog(
    BuildContext context,
    MembershipsController controller,
    bool isDarkMode,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Starter Membership Bundles',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Launch standard YouTube/Patreon membership setups with 1 click.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: MembershipsController.starterBundles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (ctx, index) {
                      final bundle = MembershipsController.starterBundles[index];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    bundle.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogCtx);
                                    await controller.setupStarterBundle(bundle);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  child: const Text('Apply Setup'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bundle.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: bundle.tiers.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? AppColors.bgSurface : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: t.badgeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${t.name} (\$${t.price.toStringAsFixed(2)})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FAN EXPERIENCE PREVIEW MODAL
  // ==========================================================================

  void _showFanPreviewModal(
    BuildContext context,
    MembershipsController controller,
    bool isDarkMode,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDarkMode ? AppColors.bgPage : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Fan Experience Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'This is how your membership tiers appear to fans on your channel & video watch pages.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.bgDivider),
                const SizedBox(height: 16),

                Flexible(
                  child: Obx(() {
                    final tiers = controller.tiers.where((t) => t.isEnabled).toList();

                    if (tiers.isEmpty) {
                      return const Center(
                        child: Text(
                          'No enabled tiers to preview. Please create or enable a tier first.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: tiers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (ctx, index) {
                        final tier = tiers[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: tier.badgeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        tier.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '\$${tier.price.toStringAsFixed(2)} / month',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...tier.perks.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            p,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: null, // Disabled in preview mode
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.8),
                                    disabledForegroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Join ${tier.name}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTier(
    BuildContext context,
    MembershipsController controller,
    ChannelMembershipTier tier,
    bool isDarkMode,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        title: Text(
          'Delete Tier "${tier.name}"?',
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to remove this tier? Active subscribers will not be affected until the end of their current billing cycle.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteTier(tier.id, tier.name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
