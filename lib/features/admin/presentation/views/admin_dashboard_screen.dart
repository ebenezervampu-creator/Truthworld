import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_video_player_controller.dart';
import 'package:truthworld/features/admin/presentation/views/ad_reports_tab.dart';
import 'package:truthworld/features/admin/presentation/views/ads_tab.dart';
import 'package:truthworld/features/admin/presentation/views/alerts_config_tab.dart';
import 'package:truthworld/features/admin/presentation/views/analytics_tab.dart';
import 'package:truthworld/features/admin/presentation/views/appeals_tab.dart';
import 'package:truthworld/features/admin/presentation/views/audit_logs_tab.dart';
import 'package:truthworld/features/admin/presentation/views/channel_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/feedbacks_tab.dart';
import 'package:truthworld/features/admin/presentation/views/help_support_tab.dart';
import 'package:truthworld/features/admin/presentation/views/image_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/overview_tab.dart';
import 'package:truthworld/features/admin/presentation/views/reports_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/security_tab.dart';
import 'package:truthworld/features/admin/presentation/views/team_management_tab.dart';
import 'package:truthworld/features/admin/presentation/views/topic_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/user_management_tab.dart';
import 'package:truthworld/features/admin/presentation/views/video_queue_tab.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/admin/presentation/views/audit_logs_tab.dart';
export 'package:truthworld/features/admin/presentation/views/channel_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/image_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/overview_tab.dart';
export 'package:truthworld/features/admin/presentation/views/reports_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/topic_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/video_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
export 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';

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

  // Mobile Bottom Navigation Bar (Clean 4-tab layout + drawer launcher)
  Widget _buildMobileBottomNavigationBar(
    BuildContext context,
    AdminController controller,
  ) {
    return Obx(() {
      final primaryDefinitions = [
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
          id: 'appeals',
          label: 'Appeals',
          icon: Icons.gavel_outlined,
          activeIcon: Icons.gavel,
          badge: controller.pendingAppeals.value,
        ),
      ];

      final allowedPrimary = primaryDefinitions
          .where((t) => controller.isTabAllowed(t.id))
          .toList();

      final otherPendingCount = controller.pendingTopics.value +
          controller.pendingImages.value +
          controller.pendingChannels.value +
          controller.pendingAds.value;

      final navItems = [
        ...allowedPrimary,
        (
          id: 'more',
          label: 'More',
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view_rounded,
          badge: otherPendingCount,
        ),
      ];

      final currentTab = controller.currentTab.value;
      var currentIndex = allowedPrimary.indexWhere((t) => t.id == currentTab);
      if (currentIndex == -1) {
        // Active tab is one of the secondary tabs accessible via the drawer
        currentIndex = navItems.length - 1;
      }

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
          selectedFontSize: 12,
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
            if (index == navItems.length - 1 && navItems[index].id == 'more') {
              _scaffoldKey.currentState?.openDrawer();
              return;
            }
            final targetTab = navItems[index].id;
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
          items: navItems.map((t) {
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
                                AppSnackbar.warning('Please fill in all password fields.');
                                return;
                              }
                              if (newPass != confirm) {
                                AppSnackbar.warning('New passwords do not match.');
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
  // ========================================================================
  // EXTRACTED ADMIN QUEUE TABS (BACKWARD-COMPATIBILITY DELEGATORS)
  // ========================================================================
  Widget _buildOverviewTab(BuildContext context, AdminController controller) =>
      OverviewTab(controller: controller);

  Widget _buildVideoQueueTab(BuildContext context, AdminController controller) =>
      VideoQueueTab(controller: controller);

  Widget _buildTopicQueueTab(BuildContext context, AdminController controller) =>
      TopicQueueTab(controller: controller);

  Widget _buildChannelQueueTab(BuildContext context, AdminController controller) =>
      ChannelQueueTab(controller: controller);

  Widget _buildReportsQueueTab(BuildContext context, AdminController controller) =>
      ReportsQueueTab(controller: controller);

  Widget _buildImageQueueTab(BuildContext context, AdminController controller) =>
      ImageQueueTab(controller: controller);

  Widget _buildAuditLogsTab(BuildContext context, AdminController controller) =>
      AuditLogsTab(controller: controller);

  Widget _buildStatusBadge(String status) => AdminStatusBadge(status: status);

  Widget _buildMetadataTable(List<MetadataRow> rows) =>
      AdminMetadataTable(rows: rows);

  Widget _buildFilterChip(
    AdminController controller,
    String value,
    String label,
    RxString targetProperty,
  ) =>
      AdminFilterChip(
        controller: controller,
        value: value,
        label: label,
        targetProperty: targetProperty,
      );

  Widget _buildSafeSearchChip(String label, dynamic val) =>
      AdminSafeSearchChip(label: label, val: val);

  void _showDecisionDialog(
    BuildContext context,
    AdminController controller,
    String id,
    String action,
    bool isVideo, {
    bool isTopic = false,
    bool isChannel = false,
    bool isReport = false,
  }) =>
      showAdminDecisionDialog(
        context,
        controller,
        id,
        action,
        isVideo,
        isTopic: isTopic,
        isChannel: isChannel,
        isReport: isReport,
      );
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
