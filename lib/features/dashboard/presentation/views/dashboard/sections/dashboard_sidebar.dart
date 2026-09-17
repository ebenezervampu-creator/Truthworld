import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/place_holder_screen.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardDesktopSidebar extends StatelessWidget {
  final DashboardController controller;
  final bool isDarkMode;
  final Animation<double> drawerAnimation;
  final VoidCallback onSignOut;

  const DashboardDesktopSidebar({
    required this.controller,
    required this.isDarkMode,
    required this.drawerAnimation,
    required this.onSignOut,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: drawerAnimation,
      builder: (context, child) {
        return Container(
          width: controller.isDrawerExpanded.value ? 280 : 80,
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
            border: Border(
              right: BorderSide(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : AppColors.bgDivider,
              ),
            ),
          ),
          child: child,
        );
      },
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
        padding: const EdgeInsets.all(16),
        child: controller.isDrawerExpanded.value
            ? Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                    ),
                    onPressed: () {
                      controller.toggleDrawer();
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              )
            : Center(
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black,
                  ),
                  onPressed: () {
                    controller.toggleDrawer();
                    HapticFeedback.lightImpact();
                  },
                ),
              ),
      ),
    );
  }
}

class DashboardSidebarMenu extends StatelessWidget {
  final DashboardController controller;
  final bool isDarkMode;
  final VoidCallback onSignOut;

  const DashboardSidebarMenu({
    required this.controller,
    required this.isDarkMode,
    required this.onSignOut,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      // Core Studio Features
      {
        'icon': Icons.grid_view_rounded,
        'label': 'Studio Home',
        'color': const Color(0xFF6366F1),
        'action': 'select',
        'target': 1,
      },
      {
        'icon': Icons.video_library_rounded,
        'label': 'Content',
        'color': const Color(0xFF10B981),
        'action': 'select',
        'target': 2,
      },
      {
        'icon': Icons.drafts_rounded,
        'label': 'Drafts',
        'color': const Color(0xFFF59E0B),
        'action': 'select',
        'target': 20,
      },
      {
        'icon': Icons.upload_rounded,
        'label': 'Upload',
        'color': const Color(0xFFF59E0B),
        'action': 'route',
        'route': '/upload',
      },

      // Analytics & Engagement
      {
        'icon': Icons.insights_rounded,
        'label': 'Analytics',
        'color': const Color(0xFF3B82F6),
        'action': 'select',
        'target': 3,
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'label': 'Creator Intelligence',
        'color': const Color(0xFF8B5CF6),
        'action': 'select',
        'target': 16,
      },
      {
        'icon': Icons.category_rounded,
        'label': 'Category Insights',
        'color': const Color(0xFF6366F1),
        'action': 'select',
        'target': 19,
      },
      {
        'icon': Icons.forum_rounded,
        'label': 'Comments',
        'color': const Color(0xFF8B5CF6),
        'action': 'select',
        'target': 4,
      },
      {
        'icon': Icons.people_rounded,
        'label': 'Audience',
        'color': const Color(0xFF14B8A6),
        'action': 'select',
        'target': 12,
      },

      // Monetization & Growth
      {
        'icon': Icons.attach_money_rounded,
        'label': 'Earnings',
        'color': const Color(0xFF059669),
        'action': 'select',
        'target': 5,
      },
      {
        'icon': Icons.stars_rounded,
        'label': 'Memberships',
        'color': const Color(0xFFF59E0B),
        'action': 'select',
        'target': 18,
      },
      {
        'icon': Icons.copyright_rounded,
        'label': 'Copyright & Matches',
        'color': const Color(0xFFDC2626),
        'action': 'select',
        'target': 9,
      },

      // Creative Tools
      {
        'icon': Icons.playlist_play_rounded,
        'label': 'Playlists',
        'color': const Color(0xFF3B82F6),
        'action': 'select',
        'target': 17,
      },
      {
        'icon': Icons.spatial_audio_rounded,
        'label': 'Audio Tracks & Dubs',
        'color': const Color(0xFF10B981),
        'action': 'select',
        'target': 7,
      },
      {
        'icon': Icons.view_timeline_rounded,
        'label': 'Chapters',
        'color': const Color(0xFF3B82F6),
        'action': 'select',
        'target': 11,
      },
      {
        'icon': Icons.color_lens_rounded,
        'label': 'Customization',
        'color': const Color(0xFFEC4899),
        'action': 'select',
        'target': 6,
      },
      {
        'icon': Icons.edit_note_rounded,
        'label': 'Subtitles',
        'color': const Color(0xFF7C3AED),
        'action': 'select',
        'target': 10,
      },
      {
        'icon': Icons.topic_rounded,
        'label': 'Topics',
        'color': const Color(0xFFE11D48),
        'action': 'select',
        'target': 14,
      },
      {
        'icon': Icons.verified_user_rounded,
        'label': 'Fact Verification',
        'color': const Color(0xFF10B981),
        'action': 'select',
        'target': 15,
      },

      // System & Recovery
      {
        'icon': Icons.auto_delete_outlined,
        'label': 'Trash & Restore',
        'color': const Color(0xFF94A3B8),
        'action': 'select',
        'target': 13,
      },
    ];

    return Obx(() {
      final selectedIdx = controller.selectedIndex.value;
      final isDrawerExpanded = controller.isDrawerExpanded.value;

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: menuItems.length + 3,
        itemBuilder: (context, index) {
          if (index == menuItems.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
                thickness: 1,
                height: 1,
              ),
            );
          }

          if (index == menuItems.length + 1) {
            return DashboardSidebarItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              color: const Color(0xFF6B7280),
              isSelected: selectedIdx == 8,
              onTap: () => controller.setSelectedIndex(8),
              isDarkMode: isDarkMode,
              isDrawerExpanded: isDrawerExpanded,
            );
          }

          if (index == menuItems.length + 2) {
            return DashboardSidebarItem(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: const Color(0xFFEF4444),
              isSelected: false,
              onTap: () {
                HapticFeedback.lightImpact();
                onSignOut();
              },
              isDarkMode: isDarkMode,
              isDrawerExpanded: isDrawerExpanded,
            );
          }

          final item = menuItems[index];
          final action = item['action'] as String? ?? 'select';
          final icon = item['icon']! as IconData;
          final label = item['label']! as String;
          final color = item['color']! as Color;

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
            color: color,
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
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;
  final bool isDrawerExpanded;

  const DashboardSidebarItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    required this.isDrawerExpanded,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            onTap();
            HapticFeedback.lightImpact();
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isDrawerExpanded ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: color.withValues(alpha: 0.3))
                  : null,
            ),
            child: isDrawerExpanded
                ? Row(
                    children: [
                      Icon(
                        icon,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? color
                                : (isDarkMode
                                      ? AppColors.textPrimary
                                      : Colors.black),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      icon,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class DashboardMobileDrawer extends StatelessWidget {
  final DashboardController controller;
  final bool isDarkMode;
  final VoidCallback onSignOut;

  const DashboardMobileDrawer({
    required this.controller,
    required this.isDarkMode,
    required this.onSignOut,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Creator Studio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
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
