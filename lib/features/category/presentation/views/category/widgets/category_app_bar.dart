import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_filter_dialogs.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_hero_section.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategoryAppBar extends StatelessWidget {
  const CategoryAppBar({
    required this.controller,
    required this.heroAnimation,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.onToggleSearch,
  });

  final CategoryController controller;
  final Animation<double> heroAnimation;
  final bool isDesktop;
  final bool isTablet;
  final VoidCallback? onToggleSearch;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 300.0 : (isTablet ? 250.0 : 200.0),
      pinned: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.95),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceContainerHighest.withValues(
            alpha: 0.8,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: Get.back,
        ),
      ),
      actions: [
        Obx(
          () => CategoryAppBarAction(
            icon: controller.isSearchVisible.value
                ? Icons.close_rounded
                : Icons.search_rounded,
            onPressed: onToggleSearch ?? () {
              controller.isSearchVisible.value = !controller.isSearchVisible.value;
              if (!controller.isSearchVisible.value) {
                controller.clearSearch();
              }
            },
            tooltip: controller.isSearchVisible.value
                ? 'Close Search'
                : 'Search',
          ),
        ),
        Obx(
          () => CategoryAppBarAction(
            icon: controller.selectedView.value == 'Grid'
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded,
            onPressed: () {
              controller.selectedView.value =
                  controller.selectedView.value == 'Grid' ? 'List' : 'Grid';
              HapticFeedback.lightImpact();
            },
            tooltip: 'Toggle View',
          ),
        ),
        CategoryAppBarAction(
          icon: Icons.filter_list_rounded,
          onPressed: () => showCategoryFilterDialog(context, controller),
          tooltip: 'Filter & Sort',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: heroAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * heroAnimation.value),
              child: Opacity(
                opacity: heroAnimation.value,
                child: child,
              ),
            );
          },
          child: CategoryHeroSection(
            category: controller.category,
            isDesktop: isDesktop,
            isTablet: isTablet,
          ),
        ),
      ),
    );
  }
}

class CategoryAppBarAction extends StatelessWidget {
  const CategoryAppBarAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
