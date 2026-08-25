import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        border: Border(
          right: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      child: SizedBox(
        width: 250,
        height: double.infinity,
        child: Column(
          children: [
            _buildSidebarHeader(context),
            const Divider(color: Color(0xFF27272A), height: 1),
            Expanded(
              child: _buildSidebarItems(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        children: [
          AppLogo(),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Truthworld',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Advertiser Studio',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.brand,
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
              item['icon']! as IconData,
              color: Colors.white,
              size: 20,
            ),
            title: Text(
              item['title']! as String,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            selected: isSelected,
            selectedTileColor: AppColors.brand.withValues(alpha: 0.12),
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
