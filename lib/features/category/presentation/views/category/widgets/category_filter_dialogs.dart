import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_theme_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

const List<String> categorySortOptions = [
  'Popularity',
  'Release Date',
  'Views',
  'Trending',
  'Duration',
  'Title',
];

void showCategoryFilterDialog(
  BuildContext context,
  CategoryController controller,
) {
  final categoryColor = CategoryThemeHelper.getCategoryColor(
    controller.category,
    context,
  );

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Filter & Sort',
        style: TextStyle(
          color: Theme.of(dialogContext).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Genre',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Wrap(
                spacing: 8,
                children: controller.genres
                    .map(
                      (genre) => FilterChip(
                        label: Text(genre),
                        selected: controller.selectedGenre.value == genre,
                        onSelected: (_) {
                          controller.selectedGenre.value = genre;
                        },
                        backgroundColor: AppColors.bgSurfaceContainerHighest
                            .withValues(alpha: 0.3),
                        selectedColor: categoryColor.withValues(alpha: 0.2),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: controller.selectedGenre.value == genre
                              ? categoryColor
                              : Theme.of(dialogContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sort by',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Column(
                children: categorySortOptions
                    .map(
                      (option) => RadioMenuButton<String>(
                        value: option,
                        groupValue: controller.selectedSort.value,
                        onChanged: (value) {
                          if (value != null) {
                            controller.selectedSort.value = value;
                          }
                        },
                        child: Text(
                          option,
                          style: TextStyle(
                            color:
                                Theme.of(dialogContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: categoryColor,
          ),
          child: const Text(
            'Apply',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

void showCategorySortDialog(
  BuildContext context,
  CategoryController controller,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Sort by',
        style: TextStyle(
          color: Theme.of(dialogContext).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: categorySortOptions
                .map(
                  (option) => RadioMenuButton<String>(
                    value: option,
                    groupValue: controller.selectedSort.value,
                    onChanged: (value) {
                      if (value != null) {
                        controller.selectedSort.value = value;
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Text(
                      option,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurface,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ),
  );
}
