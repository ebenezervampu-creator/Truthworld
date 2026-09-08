import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(context),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: Obx(
              () => ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (controller.isTabAllowed('analytics'))
                    _buildNavItem(context, index: 0, icon: Icons.dashboard_outlined, label: 'Analytics'),
                  if (controller.isTabAllowed('users'))
                    _buildNavItem(context, index: 1, icon: Icons.people_outline, label: 'Users'),
                  if (controller.isTabAllowed('appeals'))
                    _buildNavItem(context, index: 2, icon: Icons.gavel_outlined, label: 'Appeals'),
                  if (controller.isTabAllowed('ads'))
                    _buildNavItem(context, index: 3, icon: Icons.campaign_outlined, label: 'Ads'),
                  if (controller.isTabAllowed('security'))
                    _buildNavItem(context, index: 4, icon: Icons.security_outlined, label: 'Security'),
                  if (controller.isTabAllowed('feedbacks'))
                    _buildNavItem(context, index: 5, icon: Icons.feedback_outlined, label: 'Feedback'),
                  if (controller.isTabAllowed('ad_reports'))
                    _buildNavItem(context, index: 6, icon: Icons.flag_outlined, label: 'Ad Reports'),
                  if (controller.isTabAllowed('alerts'))
                    _buildNavItem(context, index: 7, icon: Icons.add_alert_outlined, label: 'Alerts Config'),
                  if (controller.isTabAllowed('help'))
                    _buildNavItem(context, index: 8, icon: Icons.help_outline, label: 'Help & Support'),
                  if (controller.isTabAllowed('team'))
                    _buildNavItem(context, index: 9, icon: Icons.group_outlined, label: 'Team Members'),
                ],
              ),
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
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Truthworld System',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
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
            fontFamily: TWTypography.uiFamily,
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
