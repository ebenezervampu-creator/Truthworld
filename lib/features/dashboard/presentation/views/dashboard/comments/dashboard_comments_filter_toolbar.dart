import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Filter Toolbar for Dashboard Comments
/// Contains clean, horizontal filter chips for fast comment triage.
class DashboardCommentsFilterToolbar extends StatelessWidget {
  const DashboardCommentsFilterToolbar({
    required this.controller,
    required this.isMobile,
    super.key,
  });

  final DashboardCommentsController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: AppColors.bgDivider,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Active Video Filter Chip (if filtering comments for a specific video)
            Obx(() {
              final selectedVideo = controller.selectedVideo;
              if (selectedVideo == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.brand,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.ondemand_video_rounded,
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isMobile ? 120 : 200),
                        child: Text(
                          selectedVideo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => controller.selectVideo(null),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Filter Chips
            _buildFilterChip('all', 'All', null),
            const SizedBox(width: 6),
            _buildFilterChip(
              'unanswered',
              "I haven't responded",
              Icons.reply_rounded,
            ),
            const SizedBox(width: 6),
            _buildFilterChip('answered', 'Responded', Icons.check_rounded),
            const SizedBox(width: 6),
            _buildFilterChip(
              'hearted',
              'With Creator Heart',
              Icons.favorite_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String id, String label, IconData? icon) {
    return Obx(() {
      final isSelected = controller.selectedFilterChip.value == id;
      return GestureDetector(
        onTap: () {
          controller.selectedFilterChip.value = id;
          controller.setCommentFilter(id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? Colors.white : AppColors.bgDivider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.black : AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
