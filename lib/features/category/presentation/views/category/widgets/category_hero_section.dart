import 'package:flutter/material.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_theme_constants.dart';

class CategoryHeroSection extends StatelessWidget {
  const CategoryHeroSection({
    required this.category,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final String category;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryThemeHelper.getCategoryColor(category, context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withValues(alpha: 0.8),
            categoryColor.withValues(alpha: 0.4),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: CategoryPatternPainter(categoryColor)),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CategoryThemeHelper.getCategoryIcon(category),
                  color: Colors.white,
                  size: isDesktop ? 48 : (isTablet ? 44 : 40),
                ),
                const SizedBox(height: 12),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: isDesktop ? 36 : (isTablet ? 32 : 28),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover the best ${category.toLowerCase()} content',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
