import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// All Topics section presenting a responsive grid of topic category cards
/// matching the exact uploaded UI design.
class ExploreTopicsAllCategoriesGrid extends StatelessWidget {
  const ExploreTopicsAllCategoriesGrid({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.isMobile = false,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    // Filter out 'all' to show the concrete browseable categories
    final allCategories = TopicCategoriesConfig.categories
        .where((cat) => cat.id.toLowerCase() != 'all')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Topics',
                style: TextStyle(
                  fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Explore all available topics',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),

        // Responsive Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 2);
            final childAspectRatio = isDesktop ? 1.7 : (isTablet ? 1.6 : 1.45);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: allCategories.length,
              itemBuilder: (context, index) {
                final category = allCategories[index];
                return _AllTopicCategoryCard(
                  category: category,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.selectCategory(category.title);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _AllTopicCategoryCard extends StatelessWidget {
  const _AllTopicCategoryCard({
    required this.category,
    required this.onTap,
  });

  final TopicCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Artwork
              CachedNetworkImage(
                imageUrl: category.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const ColoredBox(
                  color: cardColor,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: secondaryText,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 0.8, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),

              // Bottom Title, Count & Circular Arrow
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                              letterSpacing: -0.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          if (controller != null)
                            Obx(() {
                              final countText = controller
                                  .getAuthenticTopicCountText(category);
                              return Text(
                                countText.isNotEmpty ? countText : 'Topics',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryText.withValues(alpha: 0.75),
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            })
                          else
                            Text(
                              'Topics',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryText.withValues(alpha: 0.75),
                                shadows: const [
                                  Shadow(
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action Circular Arrow Button
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                        border: Border.all(
                          color: AppColors.textPrimary.withValues(alpha: 0.35),
                          width: 1.1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: primaryText,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
