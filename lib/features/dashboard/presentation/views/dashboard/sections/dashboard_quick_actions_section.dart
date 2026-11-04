import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_interactive_card.dart';
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
        'onTap': () => Get.toNamed('/upload'),
      },
      {
        'title': 'Create Topic',
        'icon': Icons.topic_rounded,
        'onTap': onCreateTopic,
      },
      {
        'title': 'Create Post',
        'icon': Icons.edit_rounded,
        'onTap': () => Get.toNamed('/upload/community'),
      },
      {
        'title': 'View Analytics',
        'icon': Icons.bar_chart_rounded,
        'onTap': onViewAnalytics,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
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
                  duration: Duration(milliseconds: 280 + (index * 60)),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 14 * (1 - value)),
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
    return StudioInteractiveCard(
      onTap: () {
        final onTap = action['onTap'];
        if (onTap is VoidCallback) {
          onTap();
        }
        HapticFeedback.lightImpact();
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              action['icon'] as IconData,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              action['title'] as String,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
