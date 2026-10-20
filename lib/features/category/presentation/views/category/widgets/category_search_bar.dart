import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_theme_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategorySearchBar extends StatelessWidget {
  const CategorySearchBar({
    required this.controller,
    required this.searchController,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final CategoryController controller;
  final TextEditingController searchController;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryThemeHelper.getCategoryColor(
      controller.category,
      context,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius.lg),
        border: Border.all(
          color: AppColors.bgSurfaceContainerHighest,
        ),
      ),
      child: Obx(
        () => TextField(
          controller: searchController,
          maxLength: 100,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(100),
          style: AppTokens.typography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onChanged: (value) {
            controller.searchQuery.value = value;
          },
          decoration: InputDecoration(
            hintText: 'Search ${controller.category.toLowerCase()} content...',
            hintStyle: AppTokens.typography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixIcon: controller.isSearching.value
                ? Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: categoryColor,
                    ),
                  )
                : Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: AppTokens.sizes.iconMd,
                  ),
            suffixIcon: controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      searchController.clear();
                      controller.clearSearch();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
