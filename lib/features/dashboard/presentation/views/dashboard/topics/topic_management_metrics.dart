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
          color: isSelected ? AppColors.bgSurfaceHover : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.bgDivider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bgDivider),
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
                      color: AppColors.textPrimary,
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
          final hasRejected = controller.rejectedTopicsCount > 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.count(
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
              ),
              if (hasRejected) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => controller.setFilterMode('rejected'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C1515),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${controller.rejectedTopicsCount} ${controller.rejectedTopicsCount == 1 ? 'topic requires' : 'topics require'} action: Gemini AI rejected your details per Community Guidelines. Tap to view and edit to resubmit.',
                            style: const TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Fix Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        });
      },
    );
  }
}
