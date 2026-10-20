import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart' as app_video_card;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_shimmers_and_states.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_theme_constants.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategorySectionHeader extends StatelessWidget {
  const CategorySectionHeader({
    required this.title,
    required this.category,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final String title;
  final String category;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryThemeHelper.getCategoryColor(category, context);

    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: categoryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class CategoryVideoGrid extends StatelessWidget {
  const CategoryVideoGrid({
    required this.videos,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.isMobile = false,
  });

  final List<Video> videos;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (!isMobileDevice && isDesktop)
        ? (screenWidth >= 2400
            ? 5
            : (screenWidth >= 1700
                ? 4
                : (screenWidth >= 1100 ? 3 : 2)))
        : (isDesktop ? 3 : (isTablet ? 3 : 2));
    final childAspectRatio = (!isMobileDevice && isDesktop)
        ? 1.15
        : (isDesktop ? 1.1 : (isTablet ? 1.0 : 0.78));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return app_video_card.VideoCard(
          video: videos[index],
          isGrid: true,
          heroPrefix: 'category_grid',
        );
      },
    );
  }
}

class CategoryVideoList extends StatelessWidget {
  const CategoryVideoList({
    required this.videos,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final List<Video> videos;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return app_video_card.VideoCard(
          video: videos[index],
          heroPrefix: 'category_list',
        );
      },
    );
  }
}

class CategoryNewReleasesSection extends StatelessWidget {
  const CategoryNewReleasesSection({
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
    final gridLimit = isDesktop ? 8 : (isTablet ? 6 : 4);
    const listLimit = 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategorySectionHeader(
          title: 'New Releases',
          category: controller.category,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        SizedBox(height: AppTokens.spacing.sm),
        Obx(
          () => StreamBuilder<QuerySnapshot>(
            stream: controller.newReleasesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return controller.selectedView.value == 'Grid'
                    ? CategoryVideoGridShimmer(
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      )
                    : const CategoryVideoListShimmer();
              }
              if (snapshot.hasError) {
                ErrorHandler.log(
                  snapshot.error,
                  tag: 'CategoryNewReleasesSection.newReleasesStream',
                );
                return const CategoryErrorWidget(
                  message: 'Unable to load new releases at this time. Please check your connection.',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const CategoryEmptyWidget(message: 'No new releases found.');
              }

              final query = controller.debouncedSearchQuery.value.toLowerCase();
              var videos = snapshot.data!.docs
                  .map(Video.fromDocumentSnapshot)
                  .where(
                    (video) =>
                        VideoVisibilityPolicy.isVisibleForFeed(video) &&
                        (query.isEmpty ||
                            video.title.toLowerCase().contains(query) ||
                            video.channelName.toLowerCase().contains(query)),
                  )
                  .toList();

              if (videos.isEmpty) {
                return const CategoryEmptyWidget(message: 'No matching new releases found.');
              }

              final takeLimit = controller.selectedView.value == 'Grid'
                  ? gridLimit
                  : listLimit;
              videos = videos.take(takeLimit).toList();

              return controller.selectedView.value == 'Grid'
                  ? CategoryVideoGrid(
                      videos: videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
                    )
                  : CategoryVideoList(
                      videos: videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    );
            },
          ),
        ),
      ],
    );
  }
}

class CategoryTopContentSection extends StatelessWidget {
  const CategoryTopContentSection({
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
    final gridLimit = isDesktop ? 8 : (isTablet ? 6 : 4);
    const listLimit = 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategorySectionHeader(
          title: 'Top ${controller.category}',
          category: controller.category,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        SizedBox(height: AppTokens.spacing.sm),
        Obx(
          () => StreamBuilder<QuerySnapshot>(
            stream: controller.topContentStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return controller.selectedView.value == 'Grid'
                    ? CategoryVideoGridShimmer(
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      )
                    : const CategoryVideoListShimmer();
              }
              if (snapshot.hasError) {
                ErrorHandler.log(
                  snapshot.error,
                  tag: 'CategoryTopContentSection.topContentStream',
                );
                return const CategoryErrorWidget(
                  message: 'Unable to load top content at this time. Please check your connection.',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const CategoryEmptyWidget(message: 'No top content found.');
              }

              final query = controller.debouncedSearchQuery.value.toLowerCase();
              var videos = snapshot.data!.docs
                  .map(Video.fromDocumentSnapshot)
                  .where(
                    (video) =>
                        VideoVisibilityPolicy.isVisibleForFeed(video) &&
                        (query.isEmpty ||
                            video.title.toLowerCase().contains(query) ||
                            video.channelName.toLowerCase().contains(query)),
                  )
                  .toList();

              if (videos.isEmpty) {
                return const CategoryEmptyWidget(message: 'No matching top content found.');
              }

              final takeLimit = controller.selectedView.value == 'Grid'
                  ? gridLimit
                  : listLimit;
              videos = videos.take(takeLimit).toList();

              return controller.selectedView.value == 'Grid'
                  ? CategoryVideoGrid(
                      videos: videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
                    )
                  : CategoryVideoList(
                      videos: videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    );
            },
          ),
        ),
      ],
    );
  }
}
