import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Responsive grid displaying available topic categories or skeleton shimmers.
class ExploreTopicsCategoryGrid extends StatelessWidget {
  const ExploreTopicsCategoryGrid({
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
      if (controller.isLoadingCategories.value &&
          controller.availableCategories.isEmpty) {
        return ExploreTopicsCategorySkeletonGrid(
          isDesktop: isDesktop,
          isTablet: isTablet,
          isMobile: isMobile,
        );
      }
      final categories = controller.availableCategories;
      if (categories.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = categories[index];
            return ExploreTopicsCategoryCard(category: category);
          },
          childCount: categories.length,
        ),
      );
    });
  }
}

/// Shimmer placeholder grid shown while categories are being loaded.
class ExploreTopicsCategorySkeletonGrid extends StatelessWidget {
  const ExploreTopicsCategorySkeletonGrid({
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
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Shimmer.fromColors(
            baseColor: cardColor,
            highlightColor: buttonBg,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
        childCount: 4,
      ),
    );
  }
}

/// Visual card representing a single topic category with image cover and title.
class ExploreTopicsCategoryCard extends StatelessWidget {
  const ExploreTopicsCategoryCard({
    required this.category,
    super.key,
  });

  final TopicCategory category;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          controller?.selectCategory(category.title);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
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
                imageUrl: category.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: cardColor,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      bgColor.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    category.title,
                    style: const TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header row displayed when a specific category filter is active,
/// providing a back-button to return to all categories.
class ExploreTopicsSelectedCategoryHeader extends StatelessWidget {
  const ExploreTopicsSelectedCategoryHeader({
    super.key,
    this.isTablet = false,
  });

  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Material(
                color: buttonBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.selectCategory('All');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(
              () => Text(
                controller.selectedCategory.value,
                style: TextStyle(
                  fontSize: isTablet ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
