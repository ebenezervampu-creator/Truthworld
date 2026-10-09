import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';

/// Responsive video grid section supporting list on mobile and masonry grid on desktop/tablet.
class HomeVideoGridSection extends StatelessWidget {
  const HomeVideoGridSection({
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.videos,
    required this.heroPrefix,
    required this.isLoading,
    required this.horizontalPadding,
    required this.formatViews,
    required this.formatTimestamp,
    this.isPosts = false,
    super.key,
  });

  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final List<dynamic> videos;
  final String heroPrefix;
  final bool isLoading;
  final double horizontalPadding;
  final String Function(int) formatViews;
  final String Function(Timestamp) formatTimestamp;
  final bool isPosts;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingGrid(context);
    }
    final displayVideos = (isDesktop && !isPosts)
        ? videos.where((item) => item is! CommunityPostModel).toList()
        : videos;
    if (displayVideos.isEmpty) {
      return _buildEmptyGrid(context);
    }
    return _buildVideoGrid(context, displayVideos);
  }

  Widget _buildVideoGrid(BuildContext context, List<dynamic> videos) {
    if (isMobile) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        sliver: SliverList.separated(
          itemCount: videos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = videos[index];
            if (item is Video) {
              return VideoCard(
                key: ValueKey('feed_${heroPrefix}_${item.id}'),
                video: item,
                isGrid: true,
                heroPrefix: heroPrefix,
                disableHoverPreview: isMobile,
              );
            } else if (item is CommunityPostModel) {
              return CommunityPostCard(
                key: ValueKey('feed_post_${item.id}'),
                post: item,
              );
            } else if (item is AdItem) {
              return HomepageAdCard(
                key: ValueKey('feed_ad_${item.id}'),
                ad: item,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    final crossAxisCount = _calculateCrossAxisCount(context);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: videos.length,
        itemBuilder: (context, index) {
          final item = videos[index];
          if (item is Video) {
            return VideoCard(
              key: ValueKey('feed_${heroPrefix}_${item.id}'),
              video: item,
              isGrid: true,
              heroPrefix: heroPrefix,
              disableHoverPreview: isMobile,
            );
          } else if (item is CommunityPostModel) {
            return CommunityPostCard(
              key: ValueKey('feed_post_${item.id}'),
              post: item,
            );
          } else if (item is AdItem) {
            return HomepageAdCard(
              key: ValueKey('feed_ad_${item.id}'),
              ad: item,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  int _calculateCrossAxisCount(BuildContext context) {
    if (isMobile) return 1;
    if (isTablet) return 2;
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobileDevice) {
      return 2;
    }
    final width = MediaQuery.of(context).size.width;
    if (width >= 2800) return 5;
    if (width >= 2100) return 4;
    if (width >= 1600) return 3;
    return 2;
  }

  Widget _buildLoadingGrid(BuildContext context) {
    final crossAxisCount = _calculateCrossAxisCount(context);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isMobile ? 1.2 : (isDesktop ? 1.25 : 0.85),
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return Shimmer.fromColors(
            baseColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            highlightColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.1),
            child: Container(
              decoration: BoxDecoration(
                color: modernDarkProfessionalTheme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }, childCount: 6),
      ),
    );
  }

  Widget _buildEmptyGrid(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPosts
                    ? Icons.dynamic_feed_outlined
                    : Icons.video_library_outlined,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                isPosts ? 'No community posts found' : 'No videos found',
                style: modernDarkProfessionalTheme.textTheme.titleMedium
                    ?.copyWith(
                      color: modernDarkProfessionalTheme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isPosts
                    ? 'Check back later for new updates from creators'
                    : 'Try selecting a different category',
                style: modernDarkProfessionalTheme.textTheme.bodyMedium
                    ?.copyWith(
                      color: modernDarkProfessionalTheme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String safeSubstring(int start, int end) {
    if (isEmpty) return this;
    if (end > length) end = length;
    return substring(start, end);
  }
}
