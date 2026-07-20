import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:shimmer/shimmer.dart';

/// Topic Video Grid Widget
///
/// Features:
/// - Responsive grid layout (desktop/tablet/mobile)
/// - Infinite scroll support
/// - Loading more indicator
/// - Empty state
/// - Skeleton loading
class TopicVideoGrid extends StatelessWidget {
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

  const TopicVideoGrid({
    super.key,
    required this.videos,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isDesktop,
    required this.isTablet,
    required this.heroPrefix,
    required this.onLoadMore,
    this.isGrid = true,
    this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty && !isLoadingMore) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Video Grid or List
        isGrid ? _buildGrid() : _buildList(),

        // Loading more indicator
        if (isLoadingMore) _buildLoadingMore(),

        // End of list indicator
        if (!hasMore && videos.isNotEmpty) _buildEndOfList(),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];

        return RepaintBoundary(
          child: VideoCard(
            video: video,
            isGrid: false,
            heroPrefix: heroPrefix,
          ),
        );
      },
    );
  }


  Widget _buildGrid() {
    // Determine grid configuration based on screen size
    int crossAxisCount;
    double childAspectRatio;

    if (isDesktop) {
      crossAxisCount = 4;
      childAspectRatio = 0.95;
    } else if (isTablet) {
      crossAxisCount = 3;
      childAspectRatio = 0.95;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.9;
    }

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
          Icon(
            Icons.videocam_off_rounded,
            color: AppColors.textTertiary,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            emptyTitle ?? 'No videos yet',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emptySubtitle ?? 'Videos related to this topic will appear here',
            style: TextStyle(
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
      child: Center(
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No more videos',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading state for video grid
class TopicVideoGridSkeleton extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  const TopicVideoGridSkeleton({
    super.key,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    int crossAxisCount;
    double childAspectRatio;

    if (isDesktop) {
      crossAxisCount = 4;
      childAspectRatio = 0.95;
    } else if (isTablet) {
      crossAxisCount = 3;
      childAspectRatio = 0.95;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.9;
    }

    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceHover,
      highlightColor: Colors.white12,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail placeholder
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              // Info placeholder
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
}





