import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_filter_dialogs.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_theme_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategoryFilterChips extends StatelessWidget {
  const CategoryFilterChips({
    required this.controller,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final CategoryController controller;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryThemeHelper.getCategoryColor(
      controller.category,
      context,
    );

    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...controller.genres.map(
              (genre) => Container(
                margin: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    genre,
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: controller.selectedGenre.value == genre,
                  onSelected: (_) {
                    controller.selectedGenre.value = genre;
                    HapticFeedback.lightImpact();
                  },
                  backgroundColor: AppColors.bgSurfaceContainerHighest
                      .withValues(alpha: 0.3),
                  selectedColor: categoryColor.withValues(alpha: 0.2),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: controller.selectedGenre.value == genre
                        ? categoryColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  side: BorderSide(
                    color: controller.selectedGenre.value == genre
                        ? categoryColor
                        : AppColors.bgSurfaceContainerHighest,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: ActionChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      controller.selectedSort.value,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w500,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
                onPressed: () => showCategorySortDialog(context, controller),
                backgroundColor: categoryColor.withValues(alpha: 0.1),
                side: BorderSide(
                  color: categoryColor.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
