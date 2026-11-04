import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modular drawer widget for Advertiser Portal navigation.
class AdvertiserDrawer extends StatelessWidget {
  const AdvertiserDrawer({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return AdvertiserSidebar(
      controller: controller,
      isDrawer: true,
    );
  }
}

/// Modular sidebar widget for Advertiser Portal navigation.
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
    if (isDrawer) {
      return _buildDrawer(context, controller);
    }
    return _buildSidebar(context, controller);
  }

  Widget _buildDrawer(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Drawer(
      backgroundColor: AppColors.appBarSurface,
      child: Column(
        children: [
          _buildSidebarHeader(context),
          const Divider(color: AppColors.bgSurface, height: 1),
          Expanded(
            child: _buildSidebarItems(context, controller, isDrawer: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBarSurface,
        border: Border(
          right: BorderSide(color: AppColors.bgSurface),
        ),
      ),
      child: SizedBox(
        width: 250,
        height: double.infinity,
        child: Column(
          children: [
            _buildSidebarHeader(context),
            const Divider(color: AppColors.bgSurface, height: 1),
            Expanded(
              child: _buildSidebarItems(context, controller, isDrawer: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          AppLogo(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Truthworld',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'ADVERTISER STUDIO',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItems(
    BuildContext context,
    AdvertiserPortalController controller, {
    required bool isDrawer,
  }) {
    final icons = <IconData>[
      Icons.dashboard_rounded,
      Icons.campaign_rounded,
      Icons.analytics_rounded,
      Icons.subtitles_rounded,
      Icons.translate_rounded,
      Icons.account_balance_wallet_rounded,
      Icons.groups_rounded,
      Icons.handshake_rounded,
      Icons.perm_media_rounded,
      Icons.settings_rounded,
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (int i = 0; i < controller.tabTitles.length; i++)
          Material(
            color: Colors.transparent,
            child: ListTile(
              selected: controller.selectedIndex.value == i,
              selectedTileColor: AppColors.brand.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: Icon(
                icons[i],
                color: Colors.white,
                size: 20,
              ),
              title: Text(
                controller.tabTitles[i],
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: controller.selectedIndex.value == i
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: controller.selectedIndex.value == i
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                controller.selectedIndex.value = i;
                if (isDrawer) {
                  Get.back();
                }
              },
            ),
          ),
      ],
    );
  }
}
