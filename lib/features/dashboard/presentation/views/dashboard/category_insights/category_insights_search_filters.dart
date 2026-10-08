import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Search field and category filter chips bar for category insights.
class CategoryInsightsSearchFilters extends StatelessWidget {
  const CategoryInsightsSearchFilters({required this.controller, super.key});
  final CategoryInsightsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgDivider),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: (val) => controller.searchQuery.value = val,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFamily: TWTypography.uiFamily,
              ),
              decoration: const InputDecoration(
                hintText: 'Search categories...',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontFamily: TWTypography.uiFamily,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All Categories',
                  filter: CategoryInsightsFilter.all,
                  icon: Icons.grid_view_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Most Liked by Users',
                  filter: CategoryInsightsFilter.mostLiked,
                  icon: Icons.thumb_up_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Untouched (0 Channels)',
                  filter: CategoryInsightsFilter.untouched,
                  icon: Icons.check_box_outline_blank_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Content Gaps & Demand',
                  filter: CategoryInsightsFilter.contentGaps,
                  icon: Icons.insights_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Fastest Growing Userbase',
                  filter: CategoryInsightsFilter.fastestGrowing,
                  icon: Icons.bolt_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required CategoryInsightsFilter filter,
    required IconData icon,
  }) {
    return Obx(() {
      final isSelected = controller.activeFilter.value == filter;
      return InkWell(
        onTap: () => controller.activeFilter.value = filter,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.bgSurfaceHover : AppColors.bgPage,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.textSecondary : AppColors.bgDivider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontFamily: TWTypography.uiFamily,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
