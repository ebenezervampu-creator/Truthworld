import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Featured Topics strip section displaying curated prominent topic categories
/// with photographic hero artwork, responsive layout, and interactive mode pills.
class ExploreTopicsFeaturedSection extends StatelessWidget {
  const ExploreTopicsFeaturedSection({
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

    return Obx(() {
      final available = controller.availableCategories;
      final featuredList = available.isNotEmpty
          ? available.take(3).toList()
          : TopicCategoriesConfig.categories
              .where((c) => c.id != 'all')
              .take(3)
              .toList();

      return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = isMobile || constraints.maxWidth < 720;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Featured Topics',
                          style: TextStyle(
                            fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Popular topics you may like',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Filter Mode Pills: Discover, Trending, Newest, Popular
                        _buildFilterPills(controller, isNarrow: true),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Featured Topics',
                                style: TextStyle(
                                  fontSize:
                                      isDesktop ? 22 : (isTablet ? 20 : 18),
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Popular topics you may like',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Filter Mode Pills: Discover, Trending, Newest, Popular
                        Flexible(
                          child: _buildFilterPills(controller),
                        ),
                      ],
                    ),
            ),

            // Featured Cards Responsive Layout
            if (isNarrow)
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: featuredList.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 280,
                      child: _FeaturedTopicCard(
                        category: featuredList[index],
                        onTap: () {
                          HapticFeedback.lightImpact();
                          controller.selectCategory(featuredList[index].title);
                        },
                      ),
                    );
                  },
                ),
              )
            else
              Row(
                children: [
                  for (var i = 0; i < featuredList.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: isDesktop ? 1.45 : 1.35,
                        child: _FeaturedTopicCard(
                          category: featuredList[i],
                          onTap: () {
                            HapticFeedback.lightImpact();
                            controller.selectCategory(featuredList[i].title);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
    });
  }

  Widget _buildFilterPills(
    ExploreTopicsController controller, {
    bool isNarrow = false,
  }) {
    final modes = [
      (ExploreMode.discover, 'Discover'),
      (ExploreMode.trending, 'Trending'),
      (ExploreMode.newest, 'Newest'),
      (ExploreMode.popular, 'Popular'),
    ];

    return Obx(() {
      final currentMode = controller.exploreMode.value;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: modes.map((entry) {
            final mode = entry.$1;
            final label = entry.$2;
            final isSelected = currentMode == mode;

            return Padding(
              padding: EdgeInsets.only(
                right: isNarrow ? 8 : 0,
                left: isNarrow ? 0 : 8,
              ),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.setExploreMode(mode);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : buttonBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black : secondaryText,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _FeaturedTopicCard extends StatelessWidget {
  const _FeaturedTopicCard({
    required this.category,
    required this.onTap,
  });

  final TopicCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Artwork
              CachedNetworkImage(
                imageUrl: category.effectiveHeroImageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const ColoredBox(
                  color: cardColor,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: secondaryText,
                      size: 32,
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
                    stops: const [0.0, 0.4, 0.85, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),

              // Bottom Content
              Padding(
                padding: const EdgeInsets.all(16),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                              letterSpacing: -0.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.featuredSubtitle.isNotEmpty
                                ? category.featuredSubtitle
                                : category.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.8),
                              height: 1.3,
                              shadows: const [
                                Shadow(
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action Circular Arrow Button
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                        border: Border.all(
                          color: AppColors.textPrimary.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: primaryText,
                          size: 16,
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
