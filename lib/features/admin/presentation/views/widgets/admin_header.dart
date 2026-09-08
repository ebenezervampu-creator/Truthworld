import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modular header widget for Admin Dashboard.
class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  const AdminHeader({
    required this.controller,
    required this.isDesktop,
    super.key,
  });

  final AdminController controller;
  final bool isDesktop;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Analytics & Performance',
      'User Management',
      'Appeals & Moderation',
      'Ad Campaigns',
      'Security & Audit Logs',
      'User Feedback',
      'Ad Reports',
      'Alerts Configuration',
      'Help & Support',
      'Team Members & Access',
    ];

    return AppBar(
      backgroundColor: const Color(0xFF181818),
      elevation: 0,
      title: Obx(() {
        final idx = controller.selectedTabIndex.value.clamp(0, titles.length - 1);
        return Text(
          titles[idx],
          style: const TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        );
      }),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: controller.refreshData,
          tooltip: 'Refresh Data',
        ),
        const SizedBox(width: 8),
        _buildUserChip(context),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildUserChip(BuildContext context) {
    final user = AuthService.to.currentUser.value;
    final displayName = user?.displayName ?? 'Admin';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.bgPage,
            child: Icon(Icons.admin_panel_settings, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(
            displayName,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
