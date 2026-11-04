import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/place_holder_screen.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardDesktopSidebar extends StatelessWidget {
  final DashboardController controller;
  final bool isDarkMode;
  final Animation<double> drawerAnimation;
  final VoidCallback? onSignOut;

  const DashboardDesktopSidebar({
    required this.controller,
    required this.isDarkMode,
    required this.drawerAnimation,
    this.onSignOut,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: controller.isDrawerExpanded.value ? 280 : 80,
        decoration: const BoxDecoration(
          color: AppColors.bgPage,
          border: Border(
            right: BorderSide(
              color: AppColors.bgDivider,
            ),
          ),
        ),
        child: Column(
          children: [
            DashboardSidebarHeader(
              controller: controller,
              isDarkMode: isDarkMode,
            ),
            Expanded(
              child: DashboardSidebarMenu(
                controller: controller,
                isDarkMode: isDarkMode,
                onSignOut: onSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSidebarHeader extends StatelessWidget {
  final DashboardController controller;
  final bool isDarkMode;

  const DashboardSidebarHeader({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: controller.isDrawerExpanded.value
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'STUDIO NAVIGATION',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Collapse navigation sidebar',
                    child: IconButton(
                      tooltip: 'Collapse sidebar',
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        controller.toggleDrawer();
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                ],
              )
            : Center(
                child: Semantics(
                  button: true,
                  label: 'Expand navigation sidebar',
                  child: IconButton(
                    tooltip: 'Expand sidebar',
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      controller.toggleDrawer();
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class DashboardSidebarMenu extends StatelessWidget {
  final DashboardController controller;
  final bool isDarkMode;
  final VoidCallback? onSignOut;

  const DashboardSidebarMenu({
    required this.controller,
    required this.isDarkMode,
    this.onSignOut,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedIdx = controller.selectedIndex.value;
      final isDrawerExpanded = controller.isDrawerExpanded.value;
      final isMonetized = controller.isChannelMonetizationActive;

      final menuItems = [
        // Core Studio Features
        {
          'icon': Icons.grid_view_rounded,
          'label': 'Studio Home',
          'action': 'select',
          'target': 1,
        },
        {
          'icon': Icons.video_library_rounded,
          'label': 'Content',
          'action': 'select',
          'target': 2,
        },
        {
          'icon': Icons.upload_rounded,
          'label': 'Upload',
          'action': 'route',
          'route': '/upload',
        },

        // Analytics & Engagement
        {
          'icon': Icons.insights_rounded,
          'label': 'Analytics',
          'action': 'select',
          'target': 3,
        },
        {
          'icon': Icons.forum_rounded,
          'label': 'Comments',
          'action': 'select',
          'target': 4,
        },
        {
          'icon': Icons.people_rounded,
          'label': 'Audience',
          'action': 'select',
          'target': 12,
        },

        // Monetization & Growth
        {
          'icon': Icons.attach_money_rounded,
          'label': 'Earnings',
          'action': 'select',
          'target': 5,
        },
        if (isMonetized)
          {
            'icon': Icons.stars_rounded,
            'label': 'Memberships',
            'action': 'select',
            'target': 18,
          },
        {
          'icon': Icons.copyright_rounded,
          'label': 'Copyright & Matches',
          'action': 'select',
          'target': 9,
        },

        // Creative Tools
        {
          'icon': Icons.spatial_audio_rounded,
          'label': 'AudioTracks & VideoTracks',
          'action': 'select',
          'target': 7,
        },
        {
          'icon': Icons.view_timeline_rounded,
          'label': 'Chapters',
          'action': 'select',
          'target': 11,
        },
        {
          'icon': Icons.color_lens_rounded,
          'label': 'Customization',
          'action': 'select',
          'target': 6,
        },
        {
          'icon': Icons.edit_note_rounded,
          'label': 'Subtitles',
          'action': 'select',
          'target': 10,
        },
        {
          'icon': Icons.verified_rounded,
          'label': 'Fact-Checks & Verification',
          'action': 'select',
          'target': 15,
        },
      ];

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: menuItems.length + 2,
        itemBuilder: (context, index) {
          if (index == menuItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                color: AppColors.bgDivider,
                thickness: 1,
                height: 1,
              ),
            );
          }

          if (index == menuItems.length + 1) {
            return DashboardSidebarItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isSelected: selectedIdx == 8,
              onTap: () => controller.setSelectedIndex(8),
              isDarkMode: isDarkMode,
              isDrawerExpanded: isDrawerExpanded,
            );
          }

          final item = menuItems[index];
          final action = item['action'] as String? ?? 'select';
          final icon = item['icon']! as IconData;
          final label = item['label']! as String;

          VoidCallback onTapCallback;
          var isSelected = false;

          if (action == 'select') {
            final target = item['target'] as int? ?? (index + 1);
            isSelected = selectedIdx == target;
            onTapCallback = () => controller.setSelectedIndex(target);
          } else if (action == 'route') {
            final route = item['route'] as String?;
            onTapCallback = () {
              if (route != null && route.isNotEmpty) Get.toNamed(route);
            };
          } else if (action == 'placeholder') {
            onTapCallback = () {
              Get.to(
                () => PlaceholderScreen(
                  icon: icon,
                  featureName: label,
                  isDarkMode: isDarkMode,
                ),
              );
            };
          } else {
            onTapCallback = () => controller.setSelectedIndex(index + 1);
          }

          return DashboardSidebarItem(
            icon: icon,
            label: label,
            isSelected: isSelected,
            onTap: onTapCallback,
            isDarkMode: isDarkMode,
            isDrawerExpanded: isDrawerExpanded,
          );
        },
      );
    });
  }
}

class DashboardSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDestructive;
  final VoidCallback onTap;
  final bool isDarkMode;
  final bool isDrawerExpanded;

  const DashboardSidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    required this.isDrawerExpanded,
    this.isDestructive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isDestructive
        ? AppColors.error
        : (isSelected ? AppColors.textPrimary : AppColors.textSecondary);

    final bgColor = isSelected
        ? AppColors.bgSurface
        : Colors.transparent;

    final itemWidget = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            onTap();
            HapticFeedback.lightImpact();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isDrawerExpanded ? 10 : 14,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppColors.bgDivider)
                  : null,
            ),
            child: isDrawerExpanded
                ? Row(
                    children: [
                      Icon(
                        icon,
                        color: fgColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: fgColor,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      icon,
                      color: fgColor,
                      size: 20,
                    ),
                  ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: isDrawerExpanded
          ? itemWidget
          : Tooltip(
              message: label,
              preferBelow: false,
              waitDuration: const Duration(milliseconds: 300),
              child: itemWidget,
            ),
    );
  }
}

class DashboardMobileDrawer extends StatelessWidget {
  final DashboardController controller;
  final bool isDarkMode;
  final VoidCallback? onSignOut;

  const DashboardMobileDrawer({
    required this.controller,
    required this.isDarkMode,
    this.onSignOut,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgPage,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.appBarSurface,
              border: Border(
                bottom: BorderSide(color: AppColors.bgDivider),
              ),
            ),
            child: const Row(
              children: [
                AppLogo(size: 36, borderRadius: 8),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creator Studio',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Channel Management',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: DashboardSidebarMenu(
              controller: controller,
              isDarkMode: isDarkMode,
              onSignOut: onSignOut,
            ),
          ),
        ],
      ),
    );
  }
}
