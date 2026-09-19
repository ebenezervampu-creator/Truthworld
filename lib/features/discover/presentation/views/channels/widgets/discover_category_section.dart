import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_category_card.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Responsive grid of discover categories.
class DiscoverCategoryGrid extends StatelessWidget {
  const DiscoverCategoryGrid({
    required this.controller,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final DiscoverChannelsController controller;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = controller.categories[index + 1]; // Skip 'All'
          return DiscoverCategoryCard(
            category: category,
            onTap: () => controller.selectCategory(category['name'] as String),
          );
        },
        childCount: controller.categories.length - 1,
      ),
    );
  }
}

/// Sliver header displayed when a specific category is actively selected.
class DiscoverSelectedCategoryHeader extends StatelessWidget {
  const DiscoverSelectedCategoryHeader({
    required this.selectedCategory,
    required this.onBack,
    super.key,
  });

  final String selectedCategory;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final catImage = getCategoryImage(selectedCategory);

    return SliverToBoxAdapter(
      child: Container(
        height: 110,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: catImage,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: buttonBg),
              errorWidget: (context, url, error) =>
                  Container(color: buttonBg),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.bgPage.withValues(alpha: 0.9),
                    AppColors.bgPage.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Material(
                    color: buttonBg.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onBack();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedCategory,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exploring $selectedCategory channels',
                          style: const TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
