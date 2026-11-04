import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    required this.controller,
    this.onCloseDrawer,
    super.key,
  });

  final AdminController controller;
  final VoidCallback? onCloseDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(
                    size: 24,
                    borderRadius: 6,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TruthWorld',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Text(
                      'Console',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 16),

          // Navigation list
          Expanded(
            child: Obx(() {
              final hasManagementTabs = controller.isTabAllowed('users') ||
                  controller.isTabAllowed('team') ||
                  controller.isTabAllowed('ads') ||
                  controller.isTabAllowed('ad_reports') ||
                  controller.isTabAllowed('analytics') ||
                  controller.isTabAllowed('appeals') ||
                  controller.isTabAllowed('feedbacks') ||
                  controller.isTabAllowed('broadcast');

              final hasSystemTabs = controller.isTabAllowed('alerts') ||
                  controller.isTabAllowed('security') ||
                  controller.isTabAllowed('help');

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (controller.isTabAllowed('dashboard'))
                    AdminNavItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      tabId: 'dashboard',
                      controller: controller,
                      onTap: onCloseDrawer,
                    ),
                  if (controller.isTabAllowed('videos'))
                    AdminNavItem(
                      icon: Icons.video_library_outlined,
                      activeIcon: Icons.video_library_rounded,
                      label: 'Video Queue',
                      tabId: 'videos',
                      badgeCount: controller.pendingVideos.value,
                      controller: controller,
                      onTap: onCloseDrawer,
                    ),
                  if (controller.isTabAllowed('topics'))
                    AdminNavItem(
                      icon: Icons.tag_rounded,
                      activeIcon: Icons.tag_rounded,
                      label: 'Topics Queue',
                      tabId: 'topics',
                      badgeCount: controller.pendingTopics.value,
                      controller: controller,
                      onTap: onCloseDrawer,
                    ),
                  if (controller.isTabAllowed('images'))
                    AdminNavItem(
                      icon: Icons.image_outlined,
                      activeIcon: Icons.image_rounded,
                      label: 'Image Queue',
                      tabId: 'images',
                      badgeCount: controller.pendingImages.value,
                      controller: controller,
                      onTap: onCloseDrawer,
                    ),
                  if (controller.isTabAllowed('channels'))
                    AdminNavItem(
                      icon: Icons.account_circle_outlined,
                      activeIcon: Icons.account_circle_rounded,
                      label: 'Channel Queue',
                      tabId: 'channels',
                      badgeCount: controller.pendingChannels.value,
                      controller: controller,
                      onTap: onCloseDrawer,
                    ),
                  if (controller.isTabAllowed('reports'))
                    AdminNavItem(
                      icon: Icons.report_gmailerrorred_rounded,
                      activeIcon: Icons.report_gmailerrorred_rounded,
                      label: 'Video Reports',
                      tabId: 'reports',
                      badgeCount: controller.pendingReports.value,
                      controller: controller,
                      onTap: onCloseDrawer,
                    ),
                  if (controller.isTabAllowed('logs'))
                    AdminNavItem(
                      icon: Icons.history_edu_outlined,
                      activeIcon: Icons.history_edu_rounded,
                      label: 'Audit History Logs',
                      tabId: 'logs',
                      controller: controller,
                      onTap: onCloseDrawer,
                    ),
                  if (hasManagementTabs) ...[
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'MANAGEMENT',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (controller.isTabAllowed('users'))
                      AdminNavItem(
                        icon: Icons.people_outline_rounded,
                        activeIcon: Icons.people_rounded,
                        label: 'User Management',
                        tabId: 'users',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('team'))
                      AdminNavItem(
                        icon: Icons.badge_outlined,
                        activeIcon: Icons.badge_rounded,
                        label: 'Team Members',
                        tabId: 'team',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('ads'))
                      AdminNavItem(
                        icon: Icons.campaign_outlined,
                        activeIcon: Icons.campaign_rounded,
                        label: 'Ad Campaigns',
                        tabId: 'ads',
                        badgeCount: controller.pendingAds.value,
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('ad_reports'))
                      AdminNavItem(
                        icon: Icons.report_problem_outlined,
                        activeIcon: Icons.report_problem_rounded,
                        label: 'Advertiser Reports',
                        tabId: 'ad_reports',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('analytics'))
                      AdminNavItem(
                        icon: Icons.analytics_outlined,
                        activeIcon: Icons.analytics_rounded,
                        label: 'Analytics',
                        tabId: 'analytics',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('appeals'))
                      AdminNavItem(
                        icon: Icons.gavel_outlined,
                        activeIcon: Icons.gavel_rounded,
                        label: 'Appeals',
                        tabId: 'appeals',
                        badgeCount: controller.pendingAppeals.value,
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('feedbacks'))
                      AdminNavItem(
                        icon: Icons.feedback_outlined,
                        activeIcon: Icons.feedback_rounded,
                        label: 'User Feedbacks',
                        tabId: 'feedbacks',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('broadcast'))
                      AdminNavItem(
                        icon: Icons.cell_tower_rounded,
                        activeIcon: Icons.cell_tower_rounded,
                        label: 'Push Broadcast',
                        tabId: 'broadcast',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                  ],
                  if (hasSystemTabs) ...[
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'SYSTEM',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (controller.isTabAllowed('alerts'))
                      AdminNavItem(
                        icon: Icons.notifications_outlined,
                        activeIcon: Icons.notifications_rounded,
                        label: 'Alerts & Escalation',
                        tabId: 'alerts',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('security'))
                      AdminNavItem(
                        icon: Icons.shield_outlined,
                        activeIcon: Icons.shield_rounded,
                        label: 'Security',
                        tabId: 'security',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                    if (controller.isTabAllowed('help'))
                      AdminNavItem(
                        icon: Icons.help_outline_rounded,
                        activeIcon: Icons.help_rounded,
                        label: 'Help & Support',
                        tabId: 'help',
                        controller: controller,
                        onTap: onCloseDrawer,
                      ),
                  ],
                ],
              );
            }),
          ),

          // User Profile Info
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          Obx(() {
            final email = controller.isAdmin.value
                ? (FirebaseAuth.instance.currentUser?.email ??
                    (controller.currentAdminEmail.value.isNotEmpty
                        ? controller.currentAdminEmail.value
                        : 'Admin User'))
                : 'Not Logged In';
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.bgSurface,
                    child: Text(
                      email[0].toUpperCase(),
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.currentAdminRoles.isNotEmpty
                              ? controller.currentAdminRoles.join(', ')
                              : 'Moderation Administrator',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AdminNavItem extends StatelessWidget {
  const AdminNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.tabId,
    required this.controller,
    this.badgeCount = 0,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String tabId;
  final AdminController controller;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.currentTab.value == tabId;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: isSelected ? AppColors.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              controller.currentTab.value = tabId;
              controller.selectedVideo.value = null;
              controller.selectedImage.value = null;
              controller.selectedChannel.value = null;
              controller.selectedReport.value = null;
              controller.selectedAppeal.value = null;
              if (tabId == 'analytics') {
                controller.fetchAnalytics();
              } else if (tabId == 'users') {
                controller.fetchUsers();
              }
              onTap?.call();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
