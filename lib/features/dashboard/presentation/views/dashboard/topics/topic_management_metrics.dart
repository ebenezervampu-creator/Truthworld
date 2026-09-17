import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single summary metric card for the Topic Studio dashboard.
class TopicMetricSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isSelected;

  const TopicMetricSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.isSelected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF27272A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive bar containing the 4 primary topic metrics cards.
class TopicMetricsBar extends StatelessWidget {
  final TopicManagementController controller;

  const TopicMetricsBar({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Obx(() {
          return GridView.count(
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            childAspectRatio: isMobile ? 1.8 : 2.4,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              TopicMetricSummaryCard(
                title: 'Total Topics',
                value: '${controller.totalTopicsCount}',
                icon: Icons.topic_rounded,
                onTap: () => controller.setFilterMode('all'),
                isSelected: controller.activeFilterMode.value == 'all',
              ),
              TopicMetricSummaryCard(
                title: 'Linked Videos',
                value: '${controller.totalVideosCount}',
                icon: Icons.video_library_rounded,
                onTap: () => controller.setFilterMode('all'),
              ),
              TopicMetricSummaryCard(
                title: 'Public Topics',
                value: '${controller.publicTopicsCount}',
                icon: Icons.public_rounded,
                onTap: () => controller.setFilterMode('public'),
                isSelected: controller.activeFilterMode.value == 'public',
              ),
              TopicMetricSummaryCard(
                title: 'Private Topics',
                value: '${controller.privateTopicsCount}',
                icon: Icons.lock_rounded,
                onTap: () => controller.setFilterMode('private'),
                isSelected: controller.activeFilterMode.value == 'private',
              ),
            ],
          );
        });
      },
    );
  }
}
