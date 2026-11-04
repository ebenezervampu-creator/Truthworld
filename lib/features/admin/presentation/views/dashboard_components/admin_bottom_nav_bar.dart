import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminMobileBottomNavBar extends StatelessWidget {
  const AdminMobileBottomNavBar({
    required this.controller,
    required this.onOpenDrawer,
    super.key,
  });

  final AdminController controller;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
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
          color: AppColors.bgPage,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          backgroundColor: AppColors.bgPage,
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
              onOpenDrawer();
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
              icon: _buildBadgeIcon(t.icon, t.badge),
              activeIcon: _buildBadgeIcon(t.activeIcon, t.badge),
              label: t.label,
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildBadgeIcon(IconData iconData, int badgeCount) {
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
}
