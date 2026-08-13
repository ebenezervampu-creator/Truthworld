import 'package:flutter/material.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modular sidebar widget for Advertiser Portal.
class AdvertiserSidebar extends StatelessWidget {
  const AdvertiserSidebar({
    required this.controller,
    super.key,
    this.isDrawer = false,
  });

  final AdvertiserPortalController controller;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF161616),
      child: SizedBox(
        width: 250,
        height: double.infinity,
        child: Column(
          children: [
            _buildSidebarHeader(context),
            const Divider(color: AppColors.bgDivider),
            Expanded(
              child: _buildSidebarItems(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Truthworld',
                style: context.typography.logo.copyWith(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Advertiser Studio',
                style: AppTextStyles.badge.copyWith(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItems(BuildContext context) {
    final items = [
      {'icon': Icons.dashboard_outlined, 'title': 'Overview'},
      {'icon': Icons.campaign_outlined, 'title': 'Campaigns'},
      {'icon': Icons.add_chart_outlined, 'title': 'Create Ad'},
      {'icon': Icons.analytics_outlined, 'title': 'Analytics'},
      {'icon': Icons.account_balance_wallet_outlined, 'title': 'Billing'},
      {'icon': Icons.settings_outlined, 'title': 'Settings'},
    ];

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = controller.selectedIndex.value == index;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: ListTile(
            leading: Icon(
              item['icon'] as IconData,
              color: Colors.white,
              size: 20,
            ),
            title: Text(
              item['title'] as String,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            selected: isSelected,
            selectedTileColor: AppColors.bgSurfaceHover,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () {
              controller.selectedIndex.value = index;
              if (isDrawer) {
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
    );
  }
}
