import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header banner displaying screen title, description, unread counter, and mark-all-as-read button.
class IntelligenceHeaderBanner extends StatelessWidget {
  const IntelligenceHeaderBanner({
    required this.controller,
    super.key,
  });

  final CreatorIntelligenceController controller;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final titleSection = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: const Icon(
            Icons.notifications_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: isMobile ? 20 : 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Real-time channel milestones, updates & verification audits',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actionSection = Row(
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          isMobile ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        Obx(() {
          if (controller.unreadCount.value > 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.infoContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${controller.unreadCount.value} UNREAD',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        OutlinedButton.icon(
          onPressed: controller.markAllAsRead,
          icon: const Icon(
            Icons.done_all_rounded,
            size: 16,
            color: Colors.white,
          ),
          label: const Text(
            'Mark all as read',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.bgDivider),
            backgroundColor: AppColors.bgSurfaceHover,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: AppColors.bgDivider,
          ),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: 14),
                actionSection,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleSection),
                const SizedBox(width: 16),
                actionSection,
              ],
            ),
    );
  }
}

/// Horizontal category filter chips for creator intelligence categories.
class IntelligenceFilterChips extends StatelessWidget {
  const IntelligenceFilterChips({
    required this.controller,
    super.key,
  });

  final CreatorIntelligenceController controller;

  static const List<Map<String, dynamic>> categories = [
    {'id': 'all', 'label': 'All Insights', 'icon': Icons.clear_all_rounded},
    {
      'id': 'critical',
      'label': 'Critical & Policy',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'id': 'growth',
      'label': 'Milestones & Growth',
      'icon': Icons.emoji_events_rounded,
    },
    {
      'id': 'verification',
      'label': 'Fact Verification',
      'icon': Icons.verified_user_rounded,
    },
    {
      'id': 'performance',
      'label': 'Performance Spike',
      'icon': Icons.trending_up_rounded,
    },
    {
      'id': 'coach',
      'label': 'AI Creator Coach',
      'icon': Icons.auto_awesome_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Obx(() {
        final currentCategory = controller.selectedCategory.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final catId = cat['id']! as String;
            final isSelected = currentCategory == catId;

            return ChoiceChip(
              avatar: Icon(
                cat['icon']! as IconData,
                size: 15,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              label: Text(
                cat['label']! as String,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  controller.selectedCategory.value = catId;
                }
              },
              selectedColor: AppColors.bgSurfaceHigh,
              backgroundColor: AppColors.bgSurface,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.bgDivider,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
