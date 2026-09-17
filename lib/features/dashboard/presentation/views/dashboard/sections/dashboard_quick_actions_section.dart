import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardQuickActionsSection extends StatelessWidget {
  final bool isDarkMode;
  final bool isMobile;
  final bool isDesktop;
  final bool isTablet;
  final VoidCallback onCreateTopic;
  final VoidCallback onViewAnalytics;

  const DashboardQuickActionsSection({
    required this.isDarkMode,
    required this.isMobile,
    required this.isDesktop,
    required this.isTablet,
    required this.onCreateTopic,
    required this.onViewAnalytics,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'title': 'Upload Video',
        'icon': Icons.cloud_upload_rounded,
        'color': const Color(0xFF10B981),
        'onTap': () => Get.toNamed('/upload'),
      },
      {
        'title': 'Create Topic',
        'icon': Icons.topic_rounded,
        'color': const Color(0xFFEF4444),
        'onTap': onCreateTopic,
      },
      {
        'title': 'Create Post',
        'icon': Icons.edit_rounded,
        'color': const Color(0xFF3B82F6),
        'onTap': () => Get.toNamed('/upload/community'),
      },
      {
        'title': 'View Analytics',
        'icon': Icons.bar_chart_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': onViewAnalytics,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final mobileAspectRatio = textScale > 1.15 ? 1.15 : 1.35;
            final isCompactMobile = constraints.maxWidth < 360;
            final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : (isCompactMobile ? 1 : 2));
            final childAspectRatio = isDesktop
                ? 1.5
                : (isTablet ? 1.6 : (isCompactMobile ? 2.5 : mobileAspectRatio));

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Opacity(
                        opacity: value,
                        child: DashboardQuickActionCard(
                          action: action,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class DashboardQuickActionCard extends StatelessWidget {
  final Map<String, dynamic> action;
  final bool isDarkMode;

  const DashboardQuickActionCard({
    required this.action,
    required this.isDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final onTap = action['onTap'];
            if (onTap is VoidCallback) {
              onTap();
            }
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action['title'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
