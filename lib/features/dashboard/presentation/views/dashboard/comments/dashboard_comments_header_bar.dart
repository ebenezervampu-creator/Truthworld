import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Studio Header Bar for Channel Comments
/// Displays header title, search toggle, and reactive tabs (Videos vs Published vs Held for review).
class DashboardCommentsHeaderBar extends StatelessWidget {
  const DashboardCommentsHeaderBar({
    required this.controller,
    required this.isMobile,
    super.key,
  });

  final DashboardCommentsController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: AppColors.bgDivider,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio Title Row with Search Action
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 12 : 16,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.bgDivider,
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Channel comments',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Manage and reply to viewer comments across all your videos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search Toggle Icon Button
                Obx(() {
                  final isExpanded = controller.isSearchExpanded.value;
                  return IconButton(
                    icon: Icon(
                      isExpanded ? Icons.close_rounded : Icons.search_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                    tooltip: isExpanded ? 'Close search' : 'Search comments',
                    onPressed: controller.toggleSearch,
                  );
                }),
              ],
            ),
          ),

          // In-Header Expandable Search Bar
          Obx(() {
            if (!controller.isSearchExpanded.value &&
                controller.searchQuery.value.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.only(
                left: isMobile ? 16 : 24,
                right: isMobile ? 16 : 24,
                bottom: 12,
              ),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: AppColors.bgDivider,
                  ),
                ),
                child: TextField(
                  controller: controller.searchController,
                  autofocus: controller.isSearchExpanded.value,
                  maxLength: ContentValidator.defaultMaxSearchLength,
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(
                    ContentValidator.defaultMaxSearchLength,
                  ),
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
            );
          }),

          // Tabs: Videos vs Published vs Held for Review
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Obx(() {
                final currentTab = controller.selectedTab.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabButton(
                      title: 'Videos',
                      isSelected: currentTab == 0,
                      onTap: () => controller.setSelectedTab(0),
                    ),
                    const SizedBox(width: 24),
                    _buildTabButton(
                      title: 'Published',
                      isSelected: currentTab == 1,
                      onTap: () => controller.setSelectedTab(1),
                    ),
                    const SizedBox(width: 24),
                    _buildTabButton(
                      title: 'Held for review',
                      isSelected: currentTab == 2,
                      onTap: () => controller.setSelectedTab(2),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.brand : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
