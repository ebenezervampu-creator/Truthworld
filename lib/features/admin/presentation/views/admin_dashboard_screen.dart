import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_video_player_controller.dart';
import 'package:truthworld/features/admin/presentation/views/ad_reports_tab.dart';
import 'package:truthworld/features/admin/presentation/views/ads_tab.dart';
import 'package:truthworld/features/admin/presentation/views/alerts_config_tab.dart';
import 'package:truthworld/features/admin/presentation/views/analytics_tab.dart';
import 'package:truthworld/features/admin/presentation/views/appeals_tab.dart';
import 'package:truthworld/features/admin/presentation/views/feedbacks_tab.dart';
import 'package:truthworld/features/admin/presentation/views/help_support_tab.dart';
import 'package:truthworld/features/admin/presentation/views/security_tab.dart';
import 'package:truthworld/features/admin/presentation/views/team_management_tab.dart';
import 'package:truthworld/features/admin/presentation/views/user_management_tab.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  AdminDashboardScreen({super.key}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdminController.to.ensureSubscriptionsStarted();
    });
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final controller = AdminController.to;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildHeader(context, controller, isDesktop),
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: AppColors.bgSurface,
              child: SafeArea(
                child: _buildSidebar(context, controller),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (desktop only)
            if (isDesktop) _buildSidebar(context, controller),

            // Main Workspace
            Expanded(
              child: Obx(() {
                final currentTab = controller.currentTab.value;
                if (!controller.isTabAllowed(currentTab)) {
                  final allowed = controller.getAllowedTabs();
                  final target = allowed.isNotEmpty ? allowed.first : 'help';
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (controller.currentTab.value != target) {
                      controller.currentTab.value = target;
                    }
                  });
                  return _buildTabForId(target, context, controller);
                }
                return _buildTabForId(currentTab, context, controller);
              }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Obx(() {
        if (controller.selectedItemIds.isNotEmpty) {
          return _buildBulkActionBar(context, controller);
        }
        return isDesktop
            ? const SizedBox.shrink()
            : _buildMobileBottomNavigationBar(context, controller);
      }),
    );
  }

  // Bulk Action Bar (Docked at bottom during item selection)
  Widget _buildBulkActionBar(BuildContext context, AdminController controller) {
    final count = controller.selectedItemIds.length;
    final tab = controller.currentTab.value;
    final contentType = tab == 'images'
        ? 'image'
        : (tab == 'topics'
            ? 'topic'
            : (tab == 'channels'
                ? 'channel'
                : 'video'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count selected',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: controller.clearSelection,
              icon: const Icon(Icons.close, color: Colors.white, size: 16),
              label: const Text(
                'Deselect All',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            // Reject Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCF6679),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: controller.isBulkActionSubmitting.value
                  ? null
                  : () => controller.bulkModerate(
                        contentType,
                        'reject',
                        'Bulk rejection by administrator',
                      ),
              icon: const Icon(Icons.block, color: Colors.white, size: 16),
              label: const Text('Bulk Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            // Approve Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2BA640),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: controller.isBulkActionSubmitting.value
                  ? null
                  : () => controller.bulkModerate(
                        contentType,
                        'approve',
                        'Bulk approval by administrator',
                      ),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              label: const Text('Bulk Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabForId(
    String tabId,
    BuildContext context,
    AdminController controller,
  ) {
    switch (tabId) {
      case 'videos':
        return _buildVideoQueueTab(context, controller);
      case 'topics':
        return _buildTopicQueueTab(context, controller);
      case 'images':
        return _buildImageQueueTab(context, controller);
      case 'channels':
        return _buildChannelQueueTab(context, controller);
      case 'reports':
        return _buildReportsQueueTab(context, controller);
      case 'logs':
        return _buildAuditLogsTab(context, controller);
      case 'users':
        return UserManagementTab(controller: controller);
      case 'ads':
        return AdsTab(controller: controller);
      case 'ad_reports':
        return AdReportsTab(controller: controller);
      case 'analytics':
        return AnalyticsTab(controller: controller);
      case 'alerts':
        return AlertsConfigTab(controller: controller);
      case 'appeals':
        return AppealsTab(controller: controller);
      case 'security':
        return SecurityTab(controller: controller);
      case 'feedbacks':
        return FeedbacksTab(controller: controller);
      case 'team':
        return TeamManagementTab(controller: controller);
      case 'help':
        return HelpSupportTab(controller: controller);
      default:
        return _buildOverviewTab(context, controller);
    }
  }

  // Mobile Bottom Navigation Bar (Filtered by assigned roles)
  Widget _buildMobileBottomNavigationBar(
    BuildContext context,
    AdminController controller,
  ) {
    return Obx(() {
      final allMobileTabs = [
        (
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          badge: 0,
        ),
        (
          id: 'videos',
          label: 'Videos',
          icon: Icons.video_library_outlined,
          activeIcon: Icons.video_library,
          badge: controller.pendingVideos.value,
        ),
        (
          id: 'topics',
          label: 'Topics',
          icon: Icons.tag_rounded,
          activeIcon: Icons.tag_rounded,
          badge: controller.pendingTopics.value,
        ),
        (
          id: 'images',
          label: 'Posts',
          icon: Icons.image_outlined,
          activeIcon: Icons.image,
          badge: controller.pendingImages.value,
        ),
        (
          id: 'channels',
          label: 'Channels',
          icon: Icons.workspace_premium_outlined,
          activeIcon: Icons.workspace_premium,
          badge: controller.pendingChannels.value,
        ),
        (
          id: 'appeals',
          label: 'Appeals',
          icon: Icons.gavel_outlined,
          activeIcon: Icons.gavel,
          badge: controller.pendingAppeals.value,
        ),
        (
          id: 'users',
          label: 'Users',
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          badge: 0,
        ),
        (
          id: 'team',
          label: 'Team',
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge_rounded,
          badge: 0,
        ),
        (
          id: 'ads',
          label: 'Ads',
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
          badge: controller.pendingAds.value,
        ),
        (
          id: 'help',
          label: 'Help',
          icon: Icons.help_outline_rounded,
          activeIcon: Icons.help_rounded,
          badge: 0,
        ),
      ];

      final allowedTabs = allMobileTabs
          .where((t) => controller.isTabAllowed(t.id))
          .toList();

      if (allowedTabs.length < 2) {
        return const SizedBox.shrink();
      }

      final currentTab = controller.currentTab.value;
      var currentIndex = allowedTabs.indexWhere((t) => t.id == currentTab);
      if (currentIndex == -1) currentIndex = 0;

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          backgroundColor: const Color(0xFF181818),
          selectedItemColor: Colors.white,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          onTap: (index) {
            final targetTab = allowedTabs[index].id;
            controller.currentTab.value = targetTab;
            controller.selectedVideo.value = null;
            controller.selectedImage.value = null;
            controller.selectedChannel.value = null;
            controller.selectedReport.value = null;
            controller.selectedAppeal.value = null;
            controller.selectedAd.value = null;
            if (targetTab == 'analytics') {
              controller.fetchAnalytics();
            } else if (targetTab == 'appeals') {
              controller.fetchAppeals();
            } else if (targetTab == 'users') {
              controller.fetchUsers();
            }
          },
          items: allowedTabs.map((t) {
            return BottomNavigationBarItem(
              icon: _buildBadgeIcon(t.icon, t.badge, false),
              activeIcon: _buildBadgeIcon(t.activeIcon, t.badge, true),
              label: t.label,
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildBadgeIcon(IconData iconData, int badgeCount, bool isActive) {
    const iconColor = Colors.white;
    if (badgeCount <= 0) {
      return Icon(iconData, color: iconColor);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData, color: iconColor),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 14,
              minHeight: 14,
            ),
            child: Text(
              '$badgeCount',
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  // Sidebar widget
  Widget _buildSidebar(BuildContext context, AdminController controller) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                  controller.isTabAllowed('feedbacks');

              final hasSystemTabs = controller.isTabAllowed('alerts') ||
                  controller.isTabAllowed('security') ||
                  controller.isTabAllowed('help');

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (controller.isTabAllowed('dashboard'))
                    _buildNavItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      tabId: 'dashboard',
                      controller: controller,
                      context: context,
                    ),
                  if (controller.isTabAllowed('videos'))
                    _buildNavItem(
                      icon: Icons.video_library_outlined,
                      activeIcon: Icons.video_library_rounded,
                      label: 'Video Queue',
                      tabId: 'videos',
                      badgeCount: controller.pendingVideos.value,
                      controller: controller,
                      context: context,
                    ),
                  if (controller.isTabAllowed('topics'))
                    _buildNavItem(
                      icon: Icons.tag_rounded,
                      activeIcon: Icons.tag_rounded,
                      label: 'Topics Queue',
                      tabId: 'topics',
                      badgeCount: controller.pendingTopics.value,
                      controller: controller,
                      context: context,
                    ),
                  if (controller.isTabAllowed('images'))
                    _buildNavItem(
                      icon: Icons.image_outlined,
                      activeIcon: Icons.image_rounded,
                      label: 'Image Queue',
                      tabId: 'images',
                      badgeCount: controller.pendingImages.value,
                      controller: controller,
                      context: context,
                    ),
                  if (controller.isTabAllowed('channels'))
                    _buildNavItem(
                      icon: Icons.account_circle_outlined,
                      activeIcon: Icons.account_circle_rounded,
                      label: 'Channel Queue',
                      tabId: 'channels',
                      badgeCount: controller.pendingChannels.value,
                      controller: controller,
                      context: context,
                    ),
                  if (controller.isTabAllowed('reports'))
                    _buildNavItem(
                      icon: Icons.report_gmailerrorred_rounded,
                      activeIcon: Icons.report_gmailerrorred_rounded,
                      label: 'Video Reports',
                      tabId: 'reports',
                      badgeCount: controller.pendingReports.value,
                      controller: controller,
                      context: context,
                    ),
                  if (controller.isTabAllowed('logs'))
                    _buildNavItem(
                      icon: Icons.history_edu_outlined,
                      activeIcon: Icons.history_edu_rounded,
                      label: 'Audit History Logs',
                      tabId: 'logs',
                      controller: controller,
                      context: context,
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
                      _buildNavItem(
                        icon: Icons.people_outline_rounded,
                        activeIcon: Icons.people_rounded,
                        label: 'User Management',
                        tabId: 'users',
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('team'))
                      _buildNavItem(
                        icon: Icons.badge_outlined,
                        activeIcon: Icons.badge_rounded,
                        label: 'Team Members',
                        tabId: 'team',
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('ads'))
                      _buildNavItem(
                        icon: Icons.campaign_outlined,
                        activeIcon: Icons.campaign_rounded,
                        label: 'Ad Campaigns',
                        tabId: 'ads',
                        badgeCount: controller.pendingAds.value,
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('ad_reports'))
                      _buildNavItem(
                        icon: Icons.report_problem_outlined,
                        activeIcon: Icons.report_problem_rounded,
                        label: 'Advertiser Reports',
                        tabId: 'ad_reports',
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('analytics'))
                      _buildNavItem(
                        icon: Icons.analytics_outlined,
                        activeIcon: Icons.analytics_rounded,
                        label: 'Analytics',
                        tabId: 'analytics',
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('appeals'))
                      _buildNavItem(
                        icon: Icons.gavel_outlined,
                        activeIcon: Icons.gavel_rounded,
                        label: 'Appeals',
                        tabId: 'appeals',
                        badgeCount: controller.pendingAppeals.value,
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('feedbacks'))
                      _buildNavItem(
                        icon: Icons.feedback_outlined,
                        activeIcon: Icons.feedback_rounded,
                        label: 'User Feedbacks',
                        tabId: 'feedbacks',
                        controller: controller,
                        context: context,
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
                      _buildNavItem(
                        icon: Icons.notifications_outlined,
                        activeIcon: Icons.notifications_rounded,
                        label: 'Alerts & Escalation',
                        tabId: 'alerts',
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('security'))
                      _buildNavItem(
                        icon: Icons.shield_outlined,
                        activeIcon: Icons.shield_rounded,
                        label: 'Security',
                        tabId: 'security',
                        controller: controller,
                        context: context,
                      ),
                    if (controller.isTabAllowed('help'))
                      _buildNavItem(
                        icon: Icons.help_outline_rounded,
                        activeIcon: Icons.help_rounded,
                        label: 'Help & Support',
                        tabId: 'help',
                        controller: controller,
                        context: context,
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
                ? (FirebaseAuth.instance.currentUser?.email ?? 'Admin User')
                : 'Not Logged In';
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF212121),
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

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String tabId,
    required AdminController controller,
    required BuildContext context,
    int badgeCount = 0,
  }) {
    return Obx(() {
      final isSelected = controller.currentTab.value == tabId;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: isSelected
              ? const Color(0xFF212121)
              : Colors.transparent,
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
              if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                Navigator.of(context).pop();
              }
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
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

  // Header Widget (AppBar)
  Widget _buildHeader(
    BuildContext context,
    AdminController controller,
    bool isDesktop,
  ) {
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
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            )
          : null,
      title: Obx(() {
        var title = 'Dashboard Overview';
        if (controller.currentTab.value == 'videos') {
          title = 'Video Verification Queue';
        }
        if (controller.currentTab.value == 'topics') {
          title = 'Topics Verification Queue';
        }
        if (controller.currentTab.value == 'images') {
          title = 'Image Moderation Grid';
        }
        if (controller.currentTab.value == 'channels') {
          title = 'Channel Verification Queue';
        }
        if (controller.currentTab.value == 'reports') {
          title = 'Video Reports Review';
        }
        if (controller.currentTab.value == 'logs') title = 'Audit History Logs';
        if (controller.currentTab.value == 'users') title = 'User Management';
        if (controller.currentTab.value == 'analytics') {
          title = 'Safety Analytics';
        }
        if (controller.currentTab.value == 'alerts') {
          title = 'Alerts & Escalation';
        }
        if (controller.currentTab.value == 'appeals') title = 'Content Appeals';
        if (controller.currentTab.value == 'security') {
          title = 'Security Center';
        }
        if (controller.currentTab.value == 'feedbacks') {
          title = 'User Feedbacks & Feedback Requests';
        }
        if (controller.currentTab.value == 'team') {
          title = 'Admin Team & Security';
        }
        if (controller.currentTab.value == 'help') {
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
          onPressed: () => _showChangePasswordDialog(context, controller),
          tooltip: 'Change Admin Password',
          icon: const Icon(
            Icons.key_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
        IconButton(
          onPressed: () => controller.refreshAllData(),
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
            onPressed: () => controller.signOutAdmin(),
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

  void _showChangePasswordDialog(
    BuildContext context,
    AdminController controller,
  ) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final isSaving = false.obs;
    final isObscureCurrent = true.obs;
    final isObscureNew = true.obs;

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Change Admin Password',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Obx(
                () => Text(
                  'Updating credentials for ${controller.currentAdminEmail.value.isNotEmpty ? controller.currentAdminEmail.value : "Authorized Administrator"}.',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Current Password
              Obx(
                () => TextField(
                  controller: currentPassCtrl,
                  obscureText: isObscureCurrent.value,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    hintText: 'Enter existing password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscureCurrent.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: isObscureCurrent.toggle,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // New Password
              Obx(
                () => TextField(
                  controller: newPassCtrl,
                  obscureText: isObscureNew.value,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter new password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(Icons.key_rounded, color: Colors.white),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscureNew.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: isObscureNew.toggle,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Confirm New Password
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  hintText: 'Re-enter new password',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back,
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  Obx(
                    () => ElevatedButton(
                      onPressed: isSaving.value
                          ? null
                          : () async {
                              final current = currentPassCtrl.text.trim();
                              final newPass = newPassCtrl.text.trim();
                              final confirm = confirmPassCtrl.text.trim();

                              if (current.isEmpty || newPass.isEmpty) {
                                Get.snackbar('Error', 'Please fill in all password fields.');
                                return;
                              }
                              if (newPass != confirm) {
                                Get.snackbar('Error', 'New passwords do not match.');
                                return;
                              }
                              isSaving.value = true;
                              final success = await controller.changeAdminPassword(
                                currentPassword: current,
                                newPassword: newPass,
                              );
                              isSaving.value = false;
                              if (success) {
                                Get.back();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSaving.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Formatting helpers
  String _formatTimestamp(dynamic val) {
    if (val == null) return 'N/A';
    DateTime? dt;
    if (val is Timestamp) {
      dt = val.toDate();
    } else if (val is String) {
      dt = DateTime.tryParse(val);
    }
    if (dt == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  // TAB 1: OVERVIEW TAB
  Widget _buildOverviewTab(BuildContext context, AdminController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1200
                  ? 6
                  : (constraints.maxWidth > 800
                        ? 3
                        : (constraints.maxWidth > 500 ? 2 : 1));
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: cols >= 6 ? 1.35 : (cols >= 2 ? 1.5 : 2.2),
                children: [
                  _buildStatCard(
                    title: 'Pending Video Reviews',
                    value: controller.pendingVideos,
                    subtitle: 'Awaiting manual decision',
                    icon: Icons.video_collection_outlined,
                  ),
                  _buildStatCard(
                    title: 'Pending Topic Reviews',
                    value: controller.pendingTopics,
                    subtitle: 'Awaiting topic verification',
                    icon: Icons.tag_rounded,
                  ),
                  _buildStatCard(
                    title: 'Pending Image Reviews',
                    value: controller.pendingImages,
                    subtitle: 'Flagged by SafeSearch',
                    icon: Icons.photo_library_outlined,
                  ),
                  _buildStatCard(
                    title: 'Pending Channel Reviews',
                    value: controller.pendingChannels,
                    subtitle: 'AI verification warnings',
                    icon: Icons.account_circle_outlined,
                  ),
                  _buildStatCard(
                    title: 'Pending Video Reports',
                    value: controller.pendingReports,
                    subtitle: 'User submitted reports',
                    icon: Icons.report_problem_outlined,
                  ),
                  _buildStatCard(
                    title: 'Total Quarantined Records',
                    value: RxInt(controller.auditLogs.length),
                    subtitle: 'Audit registry entries',
                    icon: Icons.history_toggle_off_rounded,
                  ),
                  _buildStatCard(
                    title: 'Verification System Status',
                    value: RxString('Healthy'),
                    subtitle: 'AI pipelines active',
                    icon: Icons.health_and_safety_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Recent Activity Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Moderation Feed (Real-time)',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final list = [
                    ...controller.videos.map((v) => {'type': 'video', ...v}),
                    ...controller.topics.map((t) => {'type': 'topic', ...t}),
                    ...controller.images.map(
                      (img) => {'type': 'image', ...img},
                    ),
                    ...controller.channels.map(
                      (ch) => {'type': 'channel', ...ch},
                    ),
                    ...controller.reports.map((r) => {'type': 'report', ...r}),
                  ];
                  list.sort((a, b) {
                    final timeA =
                        a['createdAt'] ?? a['flaggedAt'] ?? a['updatedAt'];
                    final timeB =
                        b['createdAt'] ?? b['flaggedAt'] ?? b['updatedAt'];
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    final dtA = timeA is Timestamp
                        ? timeA.toDate()
                        : (timeA is num
                            ? DateTime.fromMillisecondsSinceEpoch(timeA.toInt())
                            : (DateTime.tryParse(timeA.toString()) ??
                                DateTime.fromMillisecondsSinceEpoch(0)));
                    final dtB = timeB is Timestamp
                        ? timeB.toDate()
                        : (timeB is num
                            ? DateTime.fromMillisecondsSinceEpoch(timeB.toInt())
                            : (DateTime.tryParse(timeB.toString()) ??
                                DateTime.fromMillisecondsSinceEpoch(0)));
                    return dtB.compareTo(dtA);
                  });

                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No recent activity records available.',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.take(6).length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final type = item['type'] as String;
                      final isVideo = type == 'video';
                      final isTopic = type == 'topic';
                      final isChannel = type == 'channel';
                      final isReport = type == 'report';

                      var titleText = 'Unknown Item';
                      if (isVideo) {
                        titleText = item['title'] ?? 'Untitled Video';
                      } else if (isTopic) {
                        titleText = '#${item['title'] ?? item['name'] ?? 'Untitled Topic'}';
                      } else if (isChannel) {
                        titleText =
                            item['channelName'] ??
                            item['name'] ??
                            'Unnamed Channel';
                      } else if (isReport) {
                        final reasonMap = item['reason'];
                        final reason = reasonMap is Map
                            ? (reasonMap['label'] ?? 'General')
                            : (reasonMap?.toString() ?? 'General');
                        titleText = 'Report: $reason';
                      } else {
                        titleText = item['fileName'] ?? 'Flagged Image';
                      }

                      final timestamp =
                          item['createdAt'] ??
                          item['flaggedAt'] ??
                          item['updatedAt'];

                      var status = 'pending';
                      if (isVideo) {
                        status = item['moderation']?['status'] ?? 'pending';
                      } else if (isTopic) {
                        status = item['status'] ?? 'underReview';
                      } else if (isChannel) {
                        status = item['status'] ?? 'underReview';
                      } else if (isReport) {
                        status = item['status'] ?? 'pending';
                      } else {
                        status = item['status'] ?? 'PENDING';
                      }

                      var iconData = Icons.help_outline;
                      if (isVideo) {
                        iconData = Icons.movie_outlined;
                      } else if (isTopic) {
                        iconData = Icons.tag_rounded;
                      } else if (isChannel) {
                        iconData = Icons.account_circle_outlined;
                      } else if (isReport) {
                        iconData = Icons.report_gmailerrorred_rounded;
                      } else {
                        iconData = Icons.image_outlined;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF212121),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                iconData,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildStatusBadge(status),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required Rx value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Obx(() {
            final displayValue = value.value.toString();
            return Text(
              displayValue,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // TAB 2: VIDEOS QUEUE TAB (With Filter Tabs, Gemini Verification Gateway Results, and Override Reject)
  Widget _buildVideoQueueTab(BuildContext context, AdminController controller) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.videoFilterTab.value;
      final allVideos = controller.videos;
      final filteredList = controller.filteredVideos.where((v) {
        if (currentFilter == 'approved') {
          return controller.isVideoApproved(v);
        } else if (currentFilter == 'pending') {
          return controller.isVideoPending(v);
        } else if (currentFilter == 'rejected') {
          return controller.isVideoRejected(v);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFF181818),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (v) => controller.searchQuery.value = v,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search videos by title, ID, or channel...',
                        hintStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final allSelected = filteredList.isNotEmpty &&
                        filteredList.every((v) => controller.selectedItemIds.contains(v['id']));
                    if (allSelected) {
                      controller.clearSelection();
                    } else {
                      controller.selectAllItems(filteredList);
                    }
                  },
                  icon: Icon(
                    filteredList.isNotEmpty &&
                            filteredList.every((v) => controller.selectedItemIds.contains(v['id']))
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    filteredList.isNotEmpty &&
                            filteredList.every((v) => controller.selectedItemIds.contains(v['id']))
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    controller,
                    'pending',
                    'Pending (${allVideos.where(controller.isVideoPending).length})',
                    controller.videoFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'all',
                    'All Videos (${allVideos.length})',
                    controller.videoFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'approved',
                    'Approved (${allVideos.where(controller.isVideoApproved).length})',
                    controller.videoFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'rejected',
                    'Rejected (${allVideos.where(controller.isVideoRejected).length})',
                    controller.videoFilterTab,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      Widget listWidget;
      if (filteredList.isEmpty) {
        listWidget = Column(
          children: [
            filterBar,
            const Expanded(
              child: Center(
                child: Text(
                  'No videos found in this view.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        listWidget = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.separated(
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  itemBuilder: (context, index) {
                    final video = filteredList[index];
                    final isSelected = controller.selectedVideo.value?['id'] == video['id'];
                    final title = video['title'] ?? 'Untitled Video';
                    final mod = video['moderation'] as Map<String, dynamic>?;
                    final status = mod?['status'] ?? video['status'] ?? 'pending';
                    final isTimeout = mod?['violationCategories']?.contains('timeout_passthrough') == true;

                    return Material(
                      color: isSelected ? const Color(0xFF212121) : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.selectedVideo.value = video;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                                child: Checkbox(
                                  value: controller.selectedItemIds.contains(video['id']),
                                  activeColor: const Color(0xFF2BA640),
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                  onChanged: (_) => controller.toggleItemSelection((video['id'] ?? '').toString()),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF212121),
                                  borderRadius: BorderRadius.circular(6),
                                  image: video['thumbnailUrl'] != null &&
                                          video['thumbnailUrl'].toString().isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(video['thumbnailUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: video['thumbnailUrl'] == null ||
                                        video['thumbnailUrl'].toString().isEmpty
                                    ? const Icon(
                                        Icons.videocam_rounded,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontFamily: TWTypography.brandFamily,
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'User: ${video['userId'] ?? video['ownerId'] ?? 'Unknown'}',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _buildStatusBadge(status.toString()),
                                        if (isTimeout) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'TIMEOUT',
                                              style: TextStyle(
                                                fontFamily: TWTypography.brandFamily,
                                                color: AppColors.error,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }

      final inspectorWidget = Obx(() {
        final selected = controller.selectedVideo.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a video to inspect details and moderation controls',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final videoUrl = (selected['originalUrl'] ??
                selected['videoUrl'] ??
                selected['mediaUrl'] ??
                selected['hlsUrl'] ??
                selected['url'])
            ?.toString();
        final mod = selected['moderation'] as Map<String, dynamic>?;
        final status = (mod?['status'] ?? selected['status'] ?? 'pending').toString();
        final gatewayDecision = selected['gatewayDecision'] as Map<String, dynamic>?;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedVideo.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Videos',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              Text(
                selected['title'] ?? 'Untitled Video',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Gemini Verification Gateway Status Box
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (status == 'approved'
                          ? AppColors.success
                          : (status == 'rejected'
                                ? AppColors.error
                                : AppColors.warning))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (status == 'approved'
                            ? AppColors.success
                            : (status == 'rejected'
                                  ? AppColors.error
                                  : AppColors.warning))
                        .withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'approved'
                              ? Icons.verified_user_rounded
                              : (status == 'rejected'
                                    ? Icons.block_flipped
                                    : Icons.gavel_rounded),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verification Gateway Decision: ${status.toUpperCase()}',
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  color: status == 'approved'
                                      ? AppColors.success
                                      : (status == 'rejected'
                                            ? AppColors.error
                                            : AppColors.warning),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (mod?['overriddenByAdmin'] == true) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  '⚡ Overridden by Admin',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (mod?['reason'] != null || mod?['moderationReason'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${mod?['reason'] ?? mod?['moderationReason']}',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Video Player Frame
              if ((videoUrl != null && videoUrl.isNotEmpty) || selected.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: AppColors.bgPage,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AdminVideoPlayer(
                        key: ValueKey(selected['id'] ?? videoUrl),
                        url: videoUrl ?? '',
                        videoData: selected,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No video URL metadata present.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Technical Metadata
              const Text(
                'Verification & Technical Metadata',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                _MetadataRow('Video ID', selected['id']),
                _MetadataRow('Description', selected['description'] ?? 'None'),
                _MetadataRow('Pipeline Status', status),
                _MetadataRow(
                  'Verification Gateway Decision',
                  gatewayDecision?['status'] ?? mod?['status'] ?? 'N/A',
                ),
                _MetadataRow(
                  'Confidence Score',
                  (mod?['confidenceScore'] ?? gatewayDecision?['confidence'] ?? 'N/A').toString(),
                ),
                _MetadataRow(
                  'Uploaded At',
                  _formatTimestamp(selected['createdAt']),
                ),
              ]),
              const SizedBox(height: 32),

              // Action buttons (Enables rejection of ANY video at any time, including approved videos!)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'approve',
                            true,
                          ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      status == 'approved' ? 'Approved (Re-confirm)' : 'Approve Video',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'reject',
                            true,
                          ),
                    icon: const Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      status == 'approved'
                          ? 'Override & Reject Video'
                          : 'Reject Video & Quarantine',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedVideo.value != null
            ? inspectorWidget
            : listWidget;
      }

      return Row(
        children: [
          Expanded(flex: 2, child: listWidget),
          Expanded(flex: 3, child: inspectorWidget),
        ],
      );
    });
  }

  // TAB: TOPICS QUEUE TAB
  Widget _buildTopicQueueTab(BuildContext context, AdminController controller) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.topicFilterTab.value;
      final allTopics = controller.topics;

      final filteredList = allTopics.where((t) {
        if (currentFilter == 'approved') {
          return controller.isTopicApproved(t);
        } else if (currentFilter == 'pending') {
          return controller.isTopicPending(t);
        } else if (currentFilter == 'rejected') {
          return controller.isTopicRejected(t);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181818),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                controller,
                'pending',
                'Pending (${allTopics.where(controller.isTopicPending).length})',
                controller.topicFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'all',
                'All Topics (${allTopics.length})',
                controller.topicFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'approved',
                'Approved (${allTopics.where(controller.isTopicApproved).length})',
                controller.topicFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'rejected',
                'Rejected (${allTopics.where(controller.isTopicRejected).length})',
                controller.topicFilterTab,
              ),
            ],
          ),
        ),
      );

      Widget listWidget;
      if (filteredList.isEmpty) {
        listWidget = Column(
          children: [
            filterBar,
            const Expanded(
              child: Center(
                child: Text(
                  'No topics found in this view.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        listWidget = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.separated(
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  itemBuilder: (context, index) {
                    final topic = filteredList[index];
                    final isSelected =
                        controller.selectedTopic.value?['id'] == topic['id'];
                    final title = topic['title'] ?? topic['name'] ?? 'Untitled Topic';
                    final handle = topic['handle'] ?? topic['slug'] ?? 'none';
                    final status = topic['status'] ?? (topic['isApproved'] == true || topic['geminiApproved'] == true ? 'active' : 'underReview');
                    final thumbUrl = topic['thumbnailUrl'] ?? topic['coverImageUrl'] ?? topic['imageUrl'];

                    return Material(
                      color: isSelected ? const Color(0xFF212121) : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.selectedTopic.value = topic;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF212121),
                                  borderRadius: BorderRadius.circular(8),
                                  image: thumbUrl != null && thumbUrl.toString().isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(thumbUrl.toString()),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: thumbUrl == null || thumbUrl.toString().isEmpty
                                    ? const Icon(
                                        Icons.tag_rounded,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#$title',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.brandFamily,
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Handle: @$handle • Category: ${topic['category'] ?? 'General'}',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildStatusBadge(status.toString()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }

      final inspectorWidget = Obx(() {
        final selected = controller.selectedTopic.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a topic to inspect details and verification controls',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final title = selected['title'] ?? selected['name'] ?? 'Untitled Topic';
        final handle = selected['handle'] ?? selected['slug'] ?? 'none';
        final status = (selected['status'] ?? (selected['isApproved'] == true || selected['geminiApproved'] == true ? 'active' : 'underReview')).toString();
        final thumbUrl = selected['thumbnailUrl'] ?? selected['coverImageUrl'] ?? selected['imageUrl'];
        final reason = selected['moderationReason'] ?? selected['rejectionReason'] ?? selected['reason'];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedTopic.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Topics',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              Text(
                '#$title',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Gemini Topic Verification Gateway Status Box
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (controller.isTopicApproved(selected)
                          ? AppColors.success
                          : (controller.isTopicRejected(selected)
                                ? AppColors.error
                                : AppColors.warning))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (controller.isTopicApproved(selected)
                            ? AppColors.success
                            : (controller.isTopicRejected(selected)
                                  ? AppColors.error
                                  : AppColors.warning))
                        .withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          controller.isTopicApproved(selected)
                              ? Icons.verified_user_rounded
                              : (controller.isTopicRejected(selected)
                                    ? Icons.block_flipped
                                    : Icons.gavel_rounded),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verification Gateway Decision: ${status.toUpperCase()}',
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  color: controller.isTopicApproved(selected)
                                      ? AppColors.success
                                      : (controller.isTopicRejected(selected)
                                            ? AppColors.error
                                            : AppColors.warning),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (selected['manuallyVerified'] == true || selected['overriddenByAdmin'] == true) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  '⚡ Manually Verified / Overridden by Admin',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (reason != null && reason.toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reason Log: $reason',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Thumbnail Frame if available
              if (thumbUrl != null && thumbUrl.toString().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(thumbUrl.toString()),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Technical Metadata
              const Text(
                'Topic Verification & Metadata',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                _MetadataRow('Topic ID', (selected['id'] ?? 'N/A').toString()),
                _MetadataRow('Title', title.toString()),
                _MetadataRow('Handle / Slug', '@$handle'),
                _MetadataRow('Category', (selected['category'] ?? 'General').toString()),
                _MetadataRow('Description', (selected['description'] ?? 'None').toString()),
                _MetadataRow('Owner / Creator ID', (selected['ownerId'] ?? selected['userId'] ?? selected['creatorId'] ?? 'Unknown').toString()),
                _MetadataRow('Status', status),
                _MetadataRow(
                  'Created At',
                  _formatTimestamp(selected['createdAt']),
                ),
                if (selected['updatedAt'] != null)
                  _MetadataRow(
                    'Updated At',
                    _formatTimestamp(selected['updatedAt']),
                  ),
              ]),
              const SizedBox(height: 32),

              // Action buttons (Approve / Reject)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'approve',
                            false,
                            isTopic: true,
                          ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      controller.isTopicApproved(selected)
                          ? 'Approved (Re-confirm)'
                          : 'Approve Topic',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'reject',
                            false,
                            isTopic: true,
                          ),
                    icon: const Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      controller.isTopicApproved(selected)
                          ? 'Override & Reject Topic'
                          : 'Reject Topic & Quarantine',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedTopic.value != null
            ? inspectorWidget
            : listWidget;
      }

      return Row(
        children: [
          Expanded(flex: 2, child: listWidget),
          Expanded(flex: 3, child: inspectorWidget),
        ],
      );
    });
  }

  Widget _buildFilterChip(
    AdminController controller,
    String value,
    String label,
    RxString targetProperty,
  ) {
    return Obx(() {
      final isSelected = targetProperty.value == value;
      return ChoiceChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: Colors.white,
        backgroundColor: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
        labelStyle: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: Colors.black,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
        onSelected: (selected) {
          if (selected) {
            targetProperty.value = value;
          }
        },
      );
    });
  }

  Widget _buildChannelQueueTab(
    BuildContext context,
    AdminController controller,
  ) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.channelFilterTab.value;
      final allChannels = controller.channels;

      final filteredList = allChannels.where((c) {
        if (currentFilter == 'pending') {
          return controller.isChannelPending(c);
        } else if (currentFilter == 'active') {
          return controller.isChannelActive(c);
        } else if (currentFilter == 'rejected') {
          return controller.isChannelRejected(c);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181818),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                controller,
                'pending',
                'Pending (${allChannels.where(controller.isChannelPending).length})',
                controller.channelFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'all',
                'All Channels (${allChannels.length})',
                controller.channelFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'active',
                'Active (${allChannels.where(controller.isChannelActive).length})',
                controller.channelFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'rejected',
                'Rejected (${allChannels.where(controller.isChannelRejected).length})',
                controller.channelFilterTab,
              ),
            ],
          ),
        ),
      );

      Widget listWidget;
      if (filteredList.isEmpty) {
        listWidget = Column(
          children: [
            filterBar,
            const Expanded(
              child: Center(
                child: Text(
                  'No channels found in this view.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        listWidget = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.separated(
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  itemBuilder: (context, index) {
                    final channel = filteredList[index];
                    final isSelected =
                        controller.selectedChannel.value?['id'] == channel['id'];
                    final title =
                        channel['channelName'] ?? channel['name'] ?? 'Unnamed Channel';
                    final status = channel['status'] ?? 'underReview';

                    return Material(
                      color: isSelected ? const Color(0xFF212121) : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.selectedChannel.value = channel;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF212121),
                                  shape: BoxShape.circle,
                                  image:
                                      channel['avatarUrl'] != null &&
                                          channel['avatarUrl'].toString().isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(channel['avatarUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child:
                                    channel['avatarUrl'] == null ||
                                        channel['avatarUrl'].toString().isEmpty
                                    ? const Icon(
                                        Icons.face_rounded,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontFamily: TWTypography.brandFamily,
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Handle: @${channel['handle'] ?? channel['customUrl'] ?? 'none'}',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildStatusBadge(status.toString()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }

      final inspectorWidget = Obx(() {
        final selected = controller.selectedChannel.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a channel to inspect avatars, banners, and verification results',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final avatarUrl = selected['avatarUrl'];
        final bannerUrl = selected['bannerImageUrl'] ?? selected['bannerUrl'];
        final status = selected['status'] ?? 'underReview';
        final verificationResponse =
            selected['moderationReason'] ?? 'Channel Verification Gateway verified.';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedChannel.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Channels',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              // Channel Banner Image
              if (bannerUrl != null && bannerUrl.toString().isNotEmpty) ...[
                const Text(
                  'Channel Banner Preview',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(bannerUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        avatarUrl != null && avatarUrl.toString().isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    backgroundColor: const Color(0xFF212121),
                    child: avatarUrl == null || avatarUrl.toString().isEmpty
                        ? const Icon(
                            Icons.face_rounded,
                            size: 30,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected['channelName'] ??
                              selected['name'] ??
                              'Unnamed Channel',
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${selected['handle'] ?? selected['customUrl'] ?? 'none'} • Owner: ${selected['ownerId'] ?? selected['userId'] ?? 'Unknown'}',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Gemini Channel Verification Gateway Status Box
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      (status == 'active'
                              ? AppColors.success
                              : (status == 'verificationRejected'
                                    ? AppColors.error
                                    : AppColors.warning))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        (status == 'active'
                                ? AppColors.success
                                : (status == 'verificationRejected'
                                      ? AppColors.error
                                      : AppColors.warning))
                            .withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification Gateway: ${status == 'active' ? 'APPROVED / ACTIVE' : (status == 'verificationRejected' ? 'REJECTED' : 'UNDER REVIEW')}',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: status == 'active'
                                  ? AppColors.success
                                  : (status == 'verificationRejected'
                                        ? AppColors.error
                                        : AppColors.warning),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verification Log: $verificationResponse',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'approve',
                            false,
                          ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Approve Channel Verification',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'reject',
                            false,
                          ),
                    icon: const Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Reject Verification',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedChannel.value != null
            ? inspectorWidget
            : listWidget;
      }

      return Row(
        children: [
          Expanded(flex: 2, child: listWidget),
          Expanded(flex: 3, child: inspectorWidget),
        ],
      );
    });
  }

  Widget _buildReportsQueueTab(
    BuildContext context,
    AdminController controller,
  ) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.reportFilterTab.value;
      final allReports = controller.reports;

      final filteredList = allReports.where((r) {
        if (currentFilter == 'pending') {
          return controller.isReportPending(r);
        } else if (currentFilter == 'resolved') {
          return controller.isReportResolved(r);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181818),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                controller,
                'pending',
                'Pending (${allReports.where(controller.isReportPending).length})',
                controller.reportFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'all',
                'All Reports (${allReports.length})',
                controller.reportFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'resolved',
                'Resolved (${allReports.where(controller.isReportResolved).length})',
                controller.reportFilterTab,
              ),
            ],
          ),
        ),
      );

      Widget listWidget;
      if (filteredList.isEmpty) {
        listWidget = Column(
          children: [
            filterBar,
            const Expanded(
              child: Center(
                child: Text(
                  'No video reports found in this view.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        listWidget = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.separated(
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  itemBuilder: (context, index) {
                    final report = filteredList[index];
            final isSelected =
                controller.selectedReport.value?['id'] == report['id'];

            final reasonMap = report['reason'] ??
                report['reportReason'] ??
                report['category'] ??
                report['issue'];
            final reason = reasonMap is Map
                ? (reasonMap['label'] ??
                    reasonMap['name'] ??
                    reasonMap['title'] ??
                    'User Reported Content')
                : (reasonMap?.toString().isNotEmpty == true
                    ? reasonMap.toString()
                    : 'User Reported Content');
            final status = report['status'] ?? 'pending';
            final reporter = report['userEmail'] ??
                report['reporterEmail'] ??
                report['reporterId'] ??
                report['userId'] ??
                'Anonymous User';

            return Material(
              color: isSelected ? const Color(0xFF212121) : Colors.transparent,
              child: InkWell(
                onTap: () {
                  controller.selectedReport.value = report;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF212121),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.report_gmailerrorred_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reason,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reporter: $reporter',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            _buildStatusBadge(status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  ),
);
      }

      final inspectorWidget = Obx(() {
        final selected = controller.selectedReport.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a report to inspect details',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final videoId = selected['videoId'] as String?;
        final video = controller.videos.firstWhereOrNull(
          (v) => v['id'] == videoId,
        );
        final status = selected['status'] ?? 'pending';

        final reasonMap = selected['reason'] ??
            selected['reportReason'] ??
            selected['category'] ??
            selected['issue'];
        final reason = reasonMap is Map
            ? (reasonMap['label'] ??
                reasonMap['name'] ??
                reasonMap['title'] ??
                'User Reported Content')
            : (reasonMap?.toString().isNotEmpty == true
                ? reasonMap.toString()
                : 'User Reported Content');
        final comment = selected['comment'] ??
            selected['reportComment'] ??
            selected['details'] ??
            selected['description'] ??
            'No detailed description provided.';
        final reporterEmail = selected['userEmail'] ??
            selected['reporterEmail'] ??
            selected['reporterId'] ??
            selected['userId'] ??
            'Anonymous User';
        final createdAtStr = _formatTimestamp(selected['createdAt'] ?? selected['reportedAt'] ?? selected['timestamp']);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedReport.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Reports',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              // Status Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (status == 'pending' || status == 'PENDING')
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : (status == 'resolved_rejected'
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (status == 'pending' || status == 'PENDING')
                        ? AppColors.warning.withValues(alpha: 0.3)
                        : (status == 'resolved_rejected'
                              ? AppColors.error.withValues(alpha: 0.3)
                              : AppColors.success.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (status == 'pending' || status == 'PENDING')
                              ? Icons.hourglass_empty_rounded
                              : (status == 'resolved_rejected'
                                    ? Icons.cancel_outlined
                                    : Icons.check_circle_outline_rounded),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (status == 'pending' || status == 'PENDING')
                                ? 'UNDER MANUAL REVIEW'
                                : (status == 'resolved_rejected'
                                      ? 'REPORT RESOLVED: VIDEO REJECTED'
                                      : 'REPORT RESOLVED: DISMISSED'),
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color:
                                  (status == 'pending' || status == 'PENDING')
                                  ? AppColors.warning
                                  : (status == 'resolved_rejected'
                                        ? AppColors.error
                                        : AppColors.success),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (selected['resolutionComment'] != null &&
                        selected['resolutionComment']
                            .toString()
                            .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Resolution Note: ${selected['resolutionComment']}',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Video Section
              const Text(
                'Reported Video Details',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (video != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (video['thumbnailUrl'] != null &&
                          video['thumbnailUrl'].toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            video['thumbnailUrl'],
                            width: 120,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 120,
                                  height: 68,
                                  color: const Color(0xFF212121),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                  ),
                                ),
                          ),
                        )
                      else
                        Container(
                          width: 120,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFF212121),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.movie_creation_outlined,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video['title'] ?? 'Untitled Video',
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Channel: ${video['channelName'] ?? 'Unknown'}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${video['moderation']?['status'] ?? 'unknown'}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    'Video ID: $videoId (Video details not cached or video deleted)',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Report Info Section
              const Text(
                'Report Submission Info',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                _MetadataRow('Report ID', selected['id']),
                _MetadataRow('Reporter', reporterEmail),
                _MetadataRow('Reason', reason),
                _MetadataRow('Submitted At', createdAtStr),
              ]),
              const SizedBox(height: 24),

              // Reporter Comment block
              const Text(
                'Reporter Comment',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons (Only if pending)
              if (status == 'pending' || status == 'PENDING')
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'dismiss',
                              false,
                              isReport: true,
                            ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Dismiss Report (Keep Video)',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'reject',
                              false,
                              isReport: true,
                            ),
                      icon: const Icon(
                        Icons.block_flipped,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reject Video & Resolve',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedReport.value != null
            ? inspectorWidget
            : listWidget;
      }

      return Row(
        children: [
          Expanded(flex: 2, child: listWidget),
          Expanded(flex: 3, child: inspectorWidget),
        ],
      );
    });
  }

  // TAB 3: IMAGES QUEUE TAB
  Widget _buildImageQueueTab(BuildContext context, AdminController controller) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.imageFilterTab.value;
      final allImages = controller.images;
      final filteredList = controller.filteredImages.where((img) {
        if (currentFilter == 'approved') {
          return controller.isImagePostApproved(img);
        } else if (currentFilter == 'pending') {
          return controller.isImagePostPending(img);
        } else if (currentFilter == 'rejected') {
          return controller.isImagePostRejected(img);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFF181818),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (v) => controller.searchQuery.value = v,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search media by category, ID, author...',
                        hintStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final allSelected = filteredList.isNotEmpty &&
                        filteredList.every((img) => controller.selectedItemIds.contains(img['id']));
                    if (allSelected) {
                      controller.clearSelection();
                    } else {
                      controller.selectAllItems(filteredList);
                    }
                  },
                  icon: Icon(
                    filteredList.isNotEmpty &&
                            filteredList.every((img) => controller.selectedItemIds.contains(img['id']))
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    filteredList.isNotEmpty &&
                            filteredList.every((img) => controller.selectedItemIds.contains(img['id']))
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    controller,
                    'pending',
                    'Pending (${allImages.where(controller.isImagePostPending).length})',
                    controller.imageFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'all',
                    'All Posts (${allImages.length})',
                    controller.imageFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'approved',
                    'Approved (${allImages.where(controller.isImagePostApproved).length})',
                    controller.imageFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'rejected',
                    'Rejected (${allImages.where(controller.isImagePostRejected).length})',
                    controller.imageFilterTab,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      Widget listWidget;
      if (filteredList.isEmpty) {
        listWidget = Column(
          children: [
            filterBar,
            const Expanded(
              child: Center(
                child: Text(
                  'No community posts or media found in this view.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        listWidget = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final img = filteredList[index];
                    final isSelected =
                        controller.selectedImage.value?['id'] == img['id'];
                    final rawUrl = _extractImageUrl(img);
                    final displayUrl = rawUrl.isNotEmpty
                        ? StorageUtils.getFastDownloadUrl(rawUrl)
                        : '';
                    final statusDisplay = _getImagePostStatusDisplay(controller, img);

            return GestureDetector(
              onTap: () {
                controller.selectedImage.value = img;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: displayUrl.isNotEmpty
                                ? Image.network(
                                    displayUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: 350,
                                    cacheHeight: 350,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.white,
                                          ),
                                        ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Checkbox(
                              value: controller.selectedItemIds.contains(img['id']),
                              activeColor: const Color(0xFF2BA640),
                              checkColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              onChanged: (_) => controller.toggleItemSelection((img['id'] ?? '').toString()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            img['title'] ?? img['fileName'] ?? 'Image File',
                            style: const TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF212121),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  img['category'] ?? 'Post',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(statusDisplay),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  ),
);
      }

      final inspectorWidget = Obx(() {
        final selected = controller.selectedImage.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select an image to inspect details',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final rawUrl = _extractImageUrl(selected);
        final displayUrl = rawUrl.isNotEmpty
            ? StorageUtils.getFastDownloadUrl(rawUrl)
            : '';
        final scores =
            selected['detailedScores'] as Map<String, dynamic>? ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedImage.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Images',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              Text(
                selected['title'] ?? selected['fileName'] ?? 'Inspect Image',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Image Frame
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: const Color(0xFF181818),
                  constraints: const BoxConstraints(maxHeight: 280),
                  width: double.infinity,
                  child: displayUrl.isNotEmpty
                      ? Image.network(
                          displayUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 600,
                          cacheHeight: 600,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Safe Search Scores
              const Text(
                'AI SafeSearch Violations',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSafeSearchChip('Adult', scores['adult']),
                  _buildSafeSearchChip('Racy', scores['racy']),
                  _buildSafeSearchChip('Violence', scores['violence']),
                  _buildSafeSearchChip('Medical', scores['medical']),
                  _buildSafeSearchChip('Spoof', scores['spoof']),
                ],
              ),
              const SizedBox(height: 24),

              // Metadata Details Table
              const Text(
                'Verification Metadata',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                _MetadataRow('Document ID', (selected['id'] ?? selected['docId'] ?? 'N/A').toString()),
                _MetadataRow('Uploader ID', (selected['userId'] ?? selected['ownerId'] ?? selected['uploaderId'] ?? 'Anonymous').toString()),
                _MetadataRow(
                  'Trigger Category',
                  (selected['category'] ?? 'Community Post').toString(),
                ),
                _MetadataRow(
                  'AI Reason Log',
                  (selected['reason'] ?? selected['moderationReason'] ?? selected['aiReasonLog'] ?? (controller.isImagePostApproved(selected) ? 'Approved by SafeSearch AI filters.' : 'Flagged by SafeSearch filters.')).toString(),
                ),
                _MetadataRow('Severity Score', '${selected['score'] ?? selected['severityScore'] ?? 0} / 5'),
                _MetadataRow('GCS Path / URL', rawUrl.isNotEmpty ? rawUrl : 'N/A'),
                _MetadataRow(
                  'Flagged / Created At',
                  _formatTimestamp(selected['flaggedAt'] ?? selected['createdAt'] ?? selected['timestamp']),
                ),
              ]),
              const SizedBox(height: 32),

              // Action buttons
              if (controller.isImagePostPending(selected))
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'approve',
                              false,
                            ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Approve Image',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'reject',
                              false,
                            ),
                      icon: const Icon(
                        Icons.block_flipped,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reject & Quarantine',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                )
              else if (controller.isImagePostApproved(selected))
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'reject',
                              false,
                            ),
                      icon: const Icon(
                        Icons.block_flipped,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Revoke & Reject',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'approve',
                              false,
                            ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Override & Approve Image',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedImage.value != null
            ? inspectorWidget
            : listWidget;
      }

      return Row(
        children: [
          Expanded(flex: 2, child: listWidget),
          Expanded(flex: 3, child: inspectorWidget),
        ],
      );
    });
  }

  // TAB 4: AUDIT LOGS TAB
  Widget _buildAuditLogsTab(BuildContext context, AdminController controller) {
    return Obx(() {
      final logs = controller.auditLogs;

      if (logs.isEmpty) {
        return const Center(
          child: Text(
            'No audit or rejection logs recorded.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
            ),
          ),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 20,
              columns: const [
                DataColumn(
                  label: Text(
                    'Category',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Action',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Target / Resource',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actor / Admin',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Reason',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date & Time',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              rows: logs.map((log) {
                final isAction = log['logType'] == 'admin_action';
                final displayType = log['displayType'] ?? (isAction ? 'Admin Action' : 'Quarantine');
                final action = log['action'] ?? (isAction ? 'Admin Action' : 'Image Quarantine');
                final target = log['target'] ?? log['originalPath'] ?? log['userId'] ?? log['id'] ?? 'N/A';
                final actor = log['actor'] ?? log['adminEmail'] ?? log['adminId'] ?? 'System';
                final reason = log['reason'] ?? 'N/A';
                final timestamp = log['timestamp'] ?? log['rejectedAt'] ?? log['createdAt'];

                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAction
                              ? const Color(0xFF42A5F5).withValues(alpha: 0.15)
                              : const Color(0xFFCF6679).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          displayType.toString(),
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: isAction ? const Color(0xFF42A5F5) : const Color(0xFFCF6679),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        action.toString(),
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          target.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        actor.toString(),
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          reason.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatTimestamp(timestamp),
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    });
  }

  // Dialog window for approval/rejection input notes
  void _showDecisionDialog(
    BuildContext context,
    AdminController controller,
    String id,
    String action,
    bool isVideo, {
    bool isTopic = false,
    bool isChannel = false,
    bool isReport = false,
  }) {
    final textCtrl = TextEditingController();

    unawaited(
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF181818),
          title: Text(
            'Confirm Manual ${action.capitalizeFirst}',
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Are you sure you want to manually $action this resource? '
                '${action == 'reject' ? 'This action logs an audit/moderation record.' : ''}',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter review reason (optional)...',
                  hintStyle: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textTertiary,
                  ),
                  fillColor: AppColors.bgInput,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                if (isReport) {
                  await controller.moderateReport(id, action, textCtrl.text);
                } else if (isTopic) {
                  await controller.moderateTopic(id, action, textCtrl.text);
                } else if (isChannel) {
                  await controller.moderateChannel(id, action, textCtrl.text);
                } else if (isVideo) {
                  await controller.moderateVideo(id, action, textCtrl.text);
                } else {
                  await controller.moderateImage(id, action, textCtrl.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: (action == 'approve' || action == 'dismiss')
                    ? AppColors.success
                    : AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Confirm ${action.capitalizeFirst}',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SafeSearch ratings chip helper
  Widget _buildSafeSearchChip(String label, dynamic val) {
    final score = int.tryParse(val?.toString() ?? '0') ?? 0;
    var scoreColor = AppColors.success;
    if (score >= 3) scoreColor = AppColors.warning;
    if (score >= 5) scoreColor = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: scoreColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _extractImageUrl(Map<String, dynamic> img) {
    if (img['images'] is List && (img['images'] as List).isNotEmpty) {
      final first = (img['images'] as List).first;
      if (first != null && first.toString().trim().isNotEmpty) {
        return first.toString().trim();
      }
    }
    for (final key in [
      'imageUrl',
      'avatarUrl',
      'bannerUrl',
      'coverImageUrl',
      'coverUrl',
      'mediaUrl',
      'url',
      'image',
      'photoUrl',
      'thumbnailUrl',
      'thumbnail',
      'photo',
      'posterUrl',
      'downloadUrl',
      'processedUrl',
      'attachmentUrl',
      'gcsUri',
      'filePath',
      'gcsPath',
    ]) {
      final val = img[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return '';
  }

  String _getImagePostStatusDisplay(
    AdminController controller,
    Map<String, dynamic> img,
  ) {
    if (controller.isImagePostRejected(img)) {
      return 'REJECTED';
    }
    if (controller.isImagePostPending(img)) {
      final s = (img['status'] ?? img['moderation']?['status'] ?? 'PENDING')
          .toString()
          .toUpperCase();
      if (s == 'VERIFICATIONREJECTED' || s == 'VERIFICATION_REJECTED') {
        return 'FLAGGED (AI)';
      }
      if (s == 'FLAGGED' || s == 'FLAGGED_FOR_REVIEW') {
        return 'FLAGGED';
      }
      return s;
    }
    if (controller.isImagePostApproved(img)) {
      return 'APPROVED';
    }
    return (img['status'] ?? 'PENDING').toString().toUpperCase();
  }

  // Status Badge Builder
  Widget _buildStatusBadge(String status) {
    var color = AppColors.textPrimary;
    final txt = status.toUpperCase();

    if (txt == 'APPROVED' ||
        txt == 'PUBLISHED' ||
        txt == 'ACTIVE' ||
        txt == 'PASSED' ||
        txt == 'SUCCESS' ||
        txt == 'RESOLVED_DISMISSED' ||
        txt == 'RESOLVED') {
      color = AppColors.success;
    } else if (txt == 'REJECTED' ||
        txt == 'ERROR' ||
        txt == 'FAILED' ||
        txt == 'RESOLVED_REJECTED') {
      color = AppColors.error;
    } else if (txt.contains('PENDING') ||
        txt.contains('FLAGGED') ||
        txt.contains('VERIFICATION') ||
        txt.contains('REVIEW') ||
        txt == 'PROCESSING' ||
        txt == 'UNDERREVIEW') {
      color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Metadata Table Builder
  Widget _buildMetadataTable(List<_MetadataRow> rows) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: rows.map((row) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
              child: Text(
                row.label,
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                row.value,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _MetadataRow {
  const _MetadataRow(this.label, this.value);
  final String label;
  final String value;
}

// GetX Video Player wrapper
class AdminVideoPlayer extends StatefulWidget {
  const AdminVideoPlayer({
    required this.url,
    super.key,
    this.videoData,
  });
  final String url;
  final Map<String, dynamic>? videoData;

  @override
  State<AdminVideoPlayer> createState() => _AdminVideoPlayerState();
}

class _AdminVideoPlayerState extends State<AdminVideoPlayer> {
  late String _tag;
  late AdminVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = widget.videoData?['id'] ?? widget.url;
    _tag = 'admin_player_${videoId}_${DateTime.now().millisecondsSinceEpoch}';
    _controller = Get.put(
      AdminVideoPlayerController(widget.url, videoData: widget.videoData),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<AdminVideoPlayerController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_controller.error.value != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  _controller.error.value!,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _controller.retry(),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  label: const Text(
                    'Retry',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgSurfaceHover,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      if (!_controller.isPlayerInitialized.value || _controller.chewieCtrl == null) {
        return const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      }
      return Chewie(controller: _controller.chewieCtrl!);
    });
  }
}
