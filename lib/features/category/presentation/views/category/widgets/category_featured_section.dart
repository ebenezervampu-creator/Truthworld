import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_content_sections.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_shimmers_and_states.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_theme_constants.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategoryFeaturedSection extends StatelessWidget {
  const CategoryFeaturedSection({
    required this.controller,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.isMobile = false,
  });

  final CategoryController controller;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategorySectionHeader(
          title: 'Featured Content',
          category: controller.category,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        SizedBox(height: AppTokens.spacing.sm),
        SizedBox(
          height: isDesktop ? 200 : (isTablet ? 180 : 160),
          child: Obx(
            () => StreamBuilder<QuerySnapshot>(
              stream: controller.featuredStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CategoryHorizontalShimmer(
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                  );
                }
                if (snapshot.hasError) {
                  ErrorHandler.log(
                    snapshot.error,
                    tag: 'CategoryFeaturedSection.featuredStream',
                  );
                  return const CategoryErrorWidget(
                    message: 'Unable to load featured content. Please check your connection.',
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const CategoryEmptyWidget(
                    message: 'No featured content available in this category.',
                  );
                }

                final query = controller.debouncedSearchQuery.value.toLowerCase();
                final videos = snapshot.data!.docs
                    .map(Video.fromDocumentSnapshot)
                    .where(
                      (video) =>
                          VideoVisibilityPolicy.isValidVideo(video) &&
                          (query.isEmpty ||
                              video.title.toLowerCase().contains(query) ||
                              video.channelName.toLowerCase().contains(query)),
                    )
                    .toList();

                if (videos.isEmpty) {
                  return const CategoryEmptyWidget(
                    message: 'No matching featured videos found.',
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    return CategoryFeaturedCard(
                      video: videos[index],
                      category: controller.category,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class CategoryFeaturedCard extends StatelessWidget {
  const CategoryFeaturedCard({
    required this.video,
    required this.category,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final Video video;
  final String category;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final cardWidth = isDesktop ? 280.0 : (isTablet ? 240.0 : 200.0);
    final categoryColor = CategoryThemeHelper.getCategoryColor(category, context);

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bgPage.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ColoredBox(
                      color: AppColors.bgSurfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: categoryColor,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: AppColors.bgSurfaceContainerHighest,
                      child: Icon(
                        Icons.video_library_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.bgPage.withValues(alpha: 0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          video.channelName,
                          style: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                            fontSize: isDesktop ? 14 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${CategoryThemeHelper.formatViews(video.views)} views',
                          style: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 0.7),
                            fontSize: isDesktop ? 12 : 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        video.duration,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
