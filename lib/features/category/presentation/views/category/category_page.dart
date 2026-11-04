import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_page_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// MODERNIZED CATEGORY PAGE
// ==========================================================================

class CategoryPage extends GetView<CategoryController> {
  const CategoryPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: controller.fadeAnimation,
      child: SlideTransition(
        position: controller.slideAnimation,
        child: ScaleTransition(
          scale: controller.scaleAnimation,
          child: _buildResponsiveLayout(context),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kCategoryDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kCategoryMobileBreakpoint &&
            constraints.maxWidth < kCategoryDesktopBreakpoint;
        final isMobile = constraints.maxWidth < kCategoryMobileBreakpoint;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: CustomScrollView(
              controller: controller.scrollController,
              slivers: [
                if (!isDashboard)
                  CategoryAppBar(
                    controller: controller,
                    heroAnimation: controller.heroAnimation,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    onToggleSearch: () {
                      controller.isSearchVisible.value =
                          !controller.isSearchVisible.value;
                      if (!controller.isSearchVisible.value) {
                        controller.searchController.clear();
                        controller.clearSearch();
                      }
                    },
                  ),
                SliverToBoxAdapter(
                  child: _buildMainContent(
                    context,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: CategoryThemeHelper.getResponsiveHorizontalPadding(context),
        vertical: AppTokens.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => controller.isSearchVisible.value
                ? Column(
                    children: [
                      CategorySearchBar(
                        controller: controller,
                        searchController: controller.searchController,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                      ),
                      SizedBox(height: AppTokens.spacing.md),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          CategoryFilterChips(
            controller: controller,
            isDesktop: isDesktop,
            isTablet: isTablet,
          ),
          SizedBox(height: AppTokens.spacing.md),
          Obx(() {
            if (controller.debouncedSearchQuery.value.isNotEmpty) {
              return CategorySearchResultsSection(
                controller: controller,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryFeaturedSection(
                  controller: controller,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
                SizedBox(height: AppTokens.spacing.md),
                CategoryNewReleasesSection(
                  controller: controller,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
                SizedBox(height: AppTokens.spacing.md),
                CategoryTopContentSection(
                  controller: controller,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
              ],
            );
          }),
          SizedBox(height: AppTokens.spacing.md),
        ],
      ),
    );
  }
}
