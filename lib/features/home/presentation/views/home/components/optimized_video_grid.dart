import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/home/presentation/views/home/components/avatar.dart';
import 'package:truthworld/features/home/presentation/views/home/components/home_theme.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Optimized video grid using SliverList instead of StaggeredGrid
/// Provides better scroll performance with cacheExtent and RepaintBoundary
class OptimizedVideoGrid extends StatelessWidget {
  final List<Video> videos;
  final bool isLoading;
  final bool isMobile;
  final double horizontalPadding;
  final String Function(int) formatViews;
  final String Function(dynamic) formatTimestamp;
  final String heroPrefix;

  const OptimizedVideoGrid({
    required this.videos, required this.isLoading, required this.isMobile, required this.horizontalPadding, required this.formatViews, required this.formatTimestamp, required this.heroPrefix, super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingGrid(context);
    }

    if (videos.isEmpty) {
      return _buildEmptyGrid(context);
    }

    return _buildOptimizedVideoGrid(context);
  }

  Widget _buildOptimizedVideoGrid(BuildContext context) {
    // Calculate cross axis count based on screen size
    final crossAxisCount = isMobile ? 1 : 3;
    final cardWidth = (MediaQuery.of(context).size.width - 
        (horizontalPadding * 2) - (crossAxisCount - 1) * 8) / crossAxisCount;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Pre-cache images ahead of time (2 items ahead)
            if (index + 2 < videos.length) {
              _precacheNextImages(context, index);
            }

            // Calculate grid position
            final row = index ~/ crossAxisCount;
            final col = index % crossAxisCount;

            return RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: 8,
                  right: col == crossAxisCount - 1 ? 0 : 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    crossAxisCount,
                    (colIndex) {
                      final videoIndex = row * crossAxisCount + colIndex;
                      if (videoIndex >= videos.length) {
                        return const SizedBox.shrink();
                      }
                      return Expanded(
                        child: colIndex == col 
                            ? _buildOptimizedVideoCard(
                                context, 
                                videos[videoIndex], 
                                cardWidth,
                              )
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          childCount: (videos.length / crossAxisCount).ceil(),
        ),
      ),
    );
  }

  void _precacheNextImages(BuildContext context, int currentIndex) {
    for (var i = 1; i <= 2 && currentIndex + i < videos.length; i++) {
      final thumbnailUrl = videos[currentIndex + i].thumbnailUrl;
      if (thumbnailUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(thumbnailUrl), context);
      }
    }
  }

  Widget _buildOptimizedVideoCard(
    BuildContext context,
    Video video,
    double cardWidth,
  ) {
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: HomeTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            MiniplayerNavigationHelper.navigateToVideoScreen(
              video: video,
              routeArguments: {'video': video},
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOptimizedThumbnail(context, video, cardWidth),
              _buildOptimizedVideoInfo(context, video),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizedThumbnail(
    BuildContext context,
    Video video,
    double cardWidth,
  ) {
    final thumbnailHeight = cardWidth * 9 / 16;

    return Hero(
      tag: '${heroPrefix}_${video.id}',
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: (cardWidth * 2).toInt(),
                memCacheHeight: (thumbnailHeight * 2).toInt(),
                placeholder: (context, url) => _buildThumbnailShimmer(),
                errorWidget: (context, url, error) => _buildThumbnailError(),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    video.duration,
                    style: const TextStyle(
                      color: Colors.white,
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
    );
  }

  Widget _buildOptimizedVideoInfo(BuildContext context, Video video) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            imageUrl: video.channelImage,
            radius: 18,
            placeholderText: video.channelName.safeSubstring(0, 1).toUpperCase(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomeTheme.darkOnSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatViews(video.views)} views • ${formatTimestamp(video.uploadedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomeTheme.darkOnSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: HomeTheme.darkOnSurfaceVariant,
            ),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailShimmer() {
    return Shimmer.fromColors(
      baseColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
      highlightColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.1),
      child: Container(
        color: HomeTheme.darkSurfaceVariant,
      ),
    );
  }

  Widget _buildThumbnailError() {
    return const ColoredBox(
      color: HomeTheme.darkSurfaceVariant,
      child: Icon(
        Icons.error_outline,
        color: HomeTheme.darkOnSurfaceVariant,
        size: 32,
      ),
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    final crossAxisCount = isMobile ? 1 : 3;
    return SliverToBoxAdapter(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 6, // Show 6 skeleton cards
        itemBuilder: (context, index) => _buildSkeletonCard(context),
      ),
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: HomeTheme.darkSurfaceVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: HomeTheme.darkSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        color: HomeTheme.darkSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        color: HomeTheme.darkSurfaceVariant,
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

  Widget _buildEmptyGrid(BuildContext context) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(64.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 64,
                color: HomeTheme.darkOnSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No videos available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: HomeTheme.darkOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later for new content',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomeTheme.darkOnSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
