import 'package:flutter/material.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modular sidebar navigation widget for Admin Dashboard.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    required this.controller,
    super.key,
  });

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.bgSurface,
      child: Column(
        children: [
          _buildSidebarHeader(context),
          const Divider(color: AppColors.bgDivider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(context, index: 0, icon: Icons.dashboard_outlined, label: 'Analytics'),
                _buildNavItem(context, index: 1, icon: Icons.people_outline, label: 'Users'),
                _buildNavItem(context, index: 2, icon: Icons.gavel_outlined, label: 'Appeals'),
                _buildNavItem(context, index: 3, icon: Icons.campaign_outlined, label: 'Ads'),
                _buildNavItem(context, index: 4, icon: Icons.security_outlined, label: 'Security'),
                _buildNavItem(context, index: 5, icon: Icons.feedback_outlined, label: 'Feedback'),
                _buildNavItem(context, index: 6, icon: Icons.flag_outlined, label: 'Ad Reports'),
                _buildNavItem(context, index: 7, icon: Icons.add_alert_outlined, label: 'Alerts Config'),
                _buildNavItem(context, index: 8, icon: Icons.help_outline, label: 'Help & Support'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Console',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Truthworld System',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = controller.selectedTabIndex.value == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        title: Text(
          label,
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
          controller.selectedTabIndex.value = index;
        },
      ),
    );
  }
}
