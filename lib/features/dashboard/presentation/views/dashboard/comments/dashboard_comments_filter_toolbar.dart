import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comments_video_selector.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Filter Toolbar for Dashboard Comments
/// Contains search text field and horizontal filter chips.
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
            // Search Input Pill
            Container(
              height: 36,
              width: isMobile ? 180 : 220,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.bgDivider,
                ),
              ),
              child: TextField(
                controller: controller.searchController,
                onChanged: controller.setSearchQuery,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search comments...',
                  hintStyle: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller.searchController,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () {
                          controller.searchController.clear();
                          controller.setSearchQuery('');
                        },
                        child: const Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),

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

            // Video Filter Selector Chip for Mobile
            if (isMobile) ...[
              const SizedBox(width: 6),
              DashboardMobileVideoDropdownChip(controller: controller),
            ],
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
            color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
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
                  fontSize: 12,
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
