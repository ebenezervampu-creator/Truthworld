import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/dashboard_components/admin_change_password_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  const AdminHeader({
    required this.controller,
    required this.isDesktop,
    required this.onOpenDrawer,
    super.key,
  });

  final AdminController controller;
  final bool isDesktop;
  final VoidCallback onOpenDrawer;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF181818),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: isDesktop ? 24 : 8,
      leading: !isDesktop
          ? IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
              ),
              onPressed: onOpenDrawer,
            )
          : null,
      title: Obx(() {
        var title = 'Dashboard Overview';
        final tab = controller.currentTab.value;
        if (tab == 'videos') {
          title = 'Video Verification Queue';
        } else if (tab == 'topics') {
          title = 'Topics Verification Queue';
        } else if (tab == 'images') {
          title = 'Image Moderation Grid';
        } else if (tab == 'channels') {
          title = 'Channel Verification Queue';
        } else if (tab == 'reports') {
          title = 'Video Reports Review';
        } else if (tab == 'logs') {
          title = 'Audit History Logs';
        } else if (tab == 'users') {
          title = 'User Management';
        } else if (tab == 'analytics') {
          title = 'Safety Analytics';
        } else if (tab == 'alerts') {
          title = 'Alerts & Escalation';
        } else if (tab == 'appeals') {
          title = 'Content Appeals';
        } else if (tab == 'security') {
          title = 'Security Center';
        } else if (tab == 'feedbacks') {
          title = 'User Feedbacks & Feedback Requests';
        } else if (tab == 'team') {
          title = 'Admin Team & Security';
        } else if (tab == 'help') {
          title = 'Admin Help & Support';
        }
        return Text(
          title,
          style: const TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        );
      }),
      actions: [
        IconButton(
          onPressed: () => AdminChangePasswordDialog.show(context, controller),
          tooltip: 'Change Admin Password',
          icon: const Icon(
            Icons.key_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
        IconButton(
          onPressed: controller.refreshAllData,
          tooltip: 'Refresh & Sync All Queues',
          icon: const Icon(
            Icons.sync_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: controller.signOutAdmin,
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
      ),
    );
  }
}
