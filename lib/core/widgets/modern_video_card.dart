import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/channel_verified_badge.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class ModernVideoListCard extends StatelessWidget {
  const ModernVideoListCard({
    required this.video,
    required this.index,
    required this.colorScheme,
    required this.constraints,
    super.key,
    this.heroPrefix = 'video_list',
    this.accentColor = const Color(0xFFDC143C),
  });
  final Video video;
  final int index;
  final ColorScheme colorScheme;
  final BoxConstraints constraints;
  final String heroPrefix;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return InteractionStyles.interactiveCard(
      onTap: () {
        MiniplayerNavigationHelper.navigateToVideoScreen(
          video: video,
          routeArguments: {
            'video': video,
            'heroTag': '${heroPrefix}_${video.id}',
          },
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: context.layoutSpacing),
        decoration: ComponentStyles.getCardDecoration(),
        child: Padding(
          padding: context.cardPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(context),
              SizedBox(width: context.layoutSpacing),
              Expanded(child: _buildVideoDetails(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final isMobile = Responsive.isMobile(context.screenWidth);
    final isTablet = Responsive.isTablet(context.screenWidth);
    final thumbnailWidth = isMobile
        ? (Responsive.isMobileSmall(context.screenWidth) ? 100.0 : 120.0)
        : (isTablet ? 160.0 : 200.0);

    return Hero(
      tag: '${heroPrefix}_${video.id}',
      child: SizedBox(
        width: thumbnailWidth,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl.replaceAll(' ', '%20'),
                  fit: BoxFit.cover,
                  memCacheWidth: kIsWeb
                      ? null
                      : (thumbnailWidth *
                              MediaQuery.of(context).devicePixelRatio)
                          .toInt()
                          .clamp(640, 1920),
                  filterQuality: FilterQuality.medium,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: colorScheme.surfaceContainerHighest,
                    highlightColor:
                        colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    child: Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.3),
                          accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.video_library_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: context.layoutSpacing / 2,
                right: context.layoutSpacing / 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.layoutSpacing / 2,
                    vertical: context.layoutSpacing / 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    video.duration,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: (Responsive.isMobileSmall(context.screenWidth)
                              ? 8
                              : 10) *
                          context.fontScale,
                      fontWeight: FontWeight.bold,
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

  Widget _buildVideoDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          video.title,
          style: Responsive.isMobile(context.screenWidth)
              ? AppTextStyles.videoTitle.copyWith(
                  fontSize: (AppTextStyles.videoTitle.fontSize ?? 14) *
                      context.fontScale,
                )
              : AppTextStyles.videoTitleLarge.copyWith(
                  fontSize: (AppTextStyles.videoTitleLarge.fontSize ?? 16) *
                      context.fontScale,
                ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: context.layoutSpacing / 2),
        Row(
          children: [
            CircleAvatar(
              radius: Responsive.isMobileSmall(context.screenWidth)
                  ? 8
                  : Responsive.isMobile(context.screenWidth)
                  ? 10
                  : 12,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              child: ClipOval(
                child: video.channelImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.channelImage.replaceAll(' ', '%20'),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: kIsWeb
                            ? null
                            : (24 * MediaQuery.of(context).devicePixelRatio)
                                .toInt(),
                        placeholder: (context, url) =>
                            _buildChannelPlaceholder(context),
                        errorWidget: (context, url, error) {
                          if (kIsWeb) {
                            return Image.network(
                              video.channelImage.replaceAll(' ', '%20'),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, err, stack) =>
                                  _buildChannelPlaceholder(context),
                            );
                          }
                          return _buildChannelPlaceholder(context);
                        },
                      )
                    : _buildChannelPlaceholder(context),
              ),
            ),
            SizedBox(width: context.layoutSpacing / 2),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      video.channelName,
                      style: Responsive.isMobile(context.screenWidth)
                          ? AppTextStyles.channelName.copyWith(
                              fontSize: (AppTextStyles.channelName.fontSize ?? 12) *
                                  context.fontScale,
                            )
                          : AppTextStyles.channelNameLarge.copyWith(
                              fontSize:
                                  (AppTextStyles.channelNameLarge.fontSize ?? 14) *
                                  context.fontScale,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (video.showVerifiedBadge) ...[
                    const SizedBox(width: 4),
                    const ChannelVerifiedBadge(size: 13),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.layoutSpacing / 2),
        Row(
          children: [
            Flexible(
              child: _buildStatChip(
                Icons.visibility_rounded,
                FormatUtils.formatCount(video.views),
                context,
              ),
            ),
            SizedBox(width: context.layoutSpacing),
            Flexible(
              child: _buildStatChip(
                Icons.favorite_rounded,
                FormatUtils.formatCount(video.likeCount),
                context,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.layoutSpacing / 2,
        vertical: context.layoutSpacing / 8,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Responsive.isMobileSmall(context.screenWidth)
                ? 10
                : Responsive.isMobile(context.screenWidth)
                ? 12
                : 16,
            color: Colors.white,
          ),
          SizedBox(width: context.layoutSpacing / 4),
          Text(
            value,
            style: Responsive.isMobile(context.screenWidth)
                ? AppTextStyles.videoMetadataSmall.copyWith(
                    fontSize:
                        (AppTextStyles.videoMetadataSmall.fontSize ?? 10) *
                        context.fontScale,
                  )
                : AppTextStyles.videoMetadata.copyWith(
                    fontSize:
                        (AppTextStyles.videoMetadata.fontSize ?? 12) *
                        context.fontScale,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPlaceholder(BuildContext context) {
    return Center(
      child: Text(
        video.channelName.isNotEmpty
            ? video.channelName[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize:
              (Responsive.isMobileSmall(context.screenWidth) ? 8 : 10) *
              context.fontScale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ModernVideoGridCard extends StatelessWidget {
  const ModernVideoGridCard({
    required this.video,
    required this.index,
    required this.colorScheme,
    required this.constraints,
    super.key,
    this.heroPrefix = 'video_grid',
    this.accentColor = const Color(0xFFDC143C), // AppColors.brand
  });
  final Video video;
  final int index;
  final ColorScheme colorScheme;
  final BoxConstraints constraints;
  final String heroPrefix;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return InteractionStyles.interactiveCard(
      onTap: () {
        MiniplayerNavigationHelper.navigateToVideoScreen(
          video: video,
          routeArguments: {'video': video},
        );
      },
      child: Container(
        decoration: ComponentStyles.getCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildThumbnail(context)),
            Expanded(flex: 2, child: _buildVideoDetails(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Hero(
      tag: '${heroPrefix}_${video.id}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl.replaceAll(' ', '%20'),
              fit: BoxFit.cover,
              memCacheWidth: kIsWeb
                  ? null
                  : (constraints.maxWidth *
                          MediaQuery.of(context).devicePixelRatio)
                      .toInt()
                      .clamp(640, 1920),
              filterQuality: FilterQuality.medium,
              placeholder: (context, url) => Container(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.3),
                      accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoDetails(BuildContext context) {
    return Padding(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Use minimum size
        children: [
          Flexible(
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.videoTitleMedium.copyWith(
                fontSize:
                    (AppTextStyles.videoTitleMedium.fontSize ?? 18) *
                    context.fontScale,
              ),
            ),
          ),
          SizedBox(height: context.layoutSpacing / 4), // Reduced spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildStatChip(
                  Icons.visibility_rounded,
                  FormatUtils.formatCount(video.views),
                  context,
                ),
              ),
              Flexible(
                child: _buildStatChip(
                  Icons.favorite_rounded,
                  FormatUtils.formatCount(video.likeCount),
                  context,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.layoutSpacing / 2,
        vertical: context.layoutSpacing / 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Responsive.isMobileSmall(context.screenWidth)
                ? 8
                : Responsive.isMobile(context.screenWidth)
                ? 10
                : 14,
            color: Colors.white,
          ),
          SizedBox(width: context.layoutSpacing / 4),
          Text(
            value,
            style: AppTextStyles.videoMetadataSmall.copyWith(
              fontSize:
                  (AppTextStyles.videoMetadataSmall.fontSize ?? 9) *
                  context.fontScale,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
