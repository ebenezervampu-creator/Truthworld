import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Topic Video Grid Widget
///
/// Features:
/// - Responsive grid layout (desktop/tablet/mobile)
/// - Infinite scroll support
/// - Loading more indicator
/// - Empty state
/// - Skeleton loading
class TopicVideoGrid extends StatelessWidget {
  const TopicVideoGrid({
    required this.videos,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isDesktop,
    required this.isTablet,
    required this.heroPrefix,
    required this.onLoadMore,
    super.key,
    this.isGrid = true,
    this.emptyTitle,
    this.emptySubtitle,
  });
  final List<Video> videos;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isDesktop;
  final bool isTablet;
  final String heroPrefix;
  final VoidCallback onLoadMore;
  final bool isGrid;

  final String? emptyTitle;
  final String? emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty && !isLoadingMore) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Video Grid or List
        if (isGrid) _buildGrid(context) else _buildList(),

        // Loading more indicator
        if (isLoadingMore) _buildLoadingMore(),

        // End of list indicator
        if (!hasMore && videos.isNotEmpty) _buildEndOfList(),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final video = videos[index];

        return RepaintBoundary(
          child: VideoCard(
            video: video,
            isGrid: true,
            heroPrefix: heroPrefix,
          ),
        );
      },
    );
  }

  /// Calculates responsive grid configuration based on width and flags
  static ({int crossAxisCount, double childAspectRatio}) calculateGridConfigForWidth(
    double screenWidth, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    if (screenWidth < 480) {
      return (crossAxisCount: 1, childAspectRatio: 1.05);
    } else if (screenWidth >= 1600) {
      return (crossAxisCount: 5, childAspectRatio: 0.95);
    } else if (screenWidth >= 1024 || isDesktop) {
      return (crossAxisCount: 4, childAspectRatio: 0.95);
    } else if (screenWidth >= 768 || isTablet) {
      return (crossAxisCount: 3, childAspectRatio: 0.95);
    } else {
      return (crossAxisCount: 2, childAspectRatio: 0.9);
    }
  }

  /// Helper to calculate grid config from BuildContext
  static ({int crossAxisCount, double childAspectRatio}) calculateGridConfig(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return calculateGridConfigForWidth(
      MediaQuery.sizeOf(context).width,
      isDesktop: isDesktop,
      isTablet: isTablet,
    );
  }

  Widget _buildGrid(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600 || (!isDesktop && !isTablet && screenWidth < 768);

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: videos.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final video = videos[index];

          return RepaintBoundary(
            child: VideoCard(
              video: video,
              isGrid: true,
              heroPrefix: heroPrefix,
            ),
          );
        },
      );
    }

    final config = calculateGridConfig(
      context,
      isDesktop: isDesktop,
      isTablet: isTablet,
    );

    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: config.crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];

        // RepaintBoundary for performance
        return RepaintBoundary(
          child: VideoCard(
            video: video,
            isGrid: true,
            heroPrefix: heroPrefix,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            color: AppColors.textTertiary,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            emptyTitle ?? 'No videos yet',
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emptySubtitle ?? 'Videos related to this topic will appear here',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }

  Widget _buildEndOfList() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.fromBorderSide(
          BorderSide(
            color: Color(0xFF28282C),
          ),
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'No more videos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Check back later for more videos in this topic.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.normal,
              color: Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading state for video grid
class TopicVideoGridSkeleton extends StatelessWidget {
  const TopicVideoGridSkeleton({
    required this.isDesktop,
    required this.isTablet,
    super.key,
  });
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600 || (!isDesktop && !isTablet && screenWidth < 768);

    if (isMobile) {
      return Shimmer.fromColors(
        baseColor: AppColors.bgSurfaceHover,
        highlightColor: AppColors.bgDivider,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildSkeletonCard(),
        ),
      );
    }

    final config = TopicVideoGrid.calculateGridConfig(
      context,
      isDesktop: isDesktop,
      isTablet: isTablet,
    );

    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceHover,
      highlightColor: AppColors.bgDivider,
      child: MasonryGridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: config.crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        itemCount: 8,
        itemBuilder: (context, index) => _buildSkeletonCard(),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 16:9 Thumbnail placeholder
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          ),
          // Info placeholder
          Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 10,
              bottom: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurface,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                // Title and subtitle placeholder lines
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 140,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
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
