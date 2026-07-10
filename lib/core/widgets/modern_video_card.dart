import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class ModernVideoListCard extends StatefulWidget {
  final Video video;
  final int index;
  final ColorScheme colorScheme;
  final BoxConstraints constraints;
  final String heroPrefix;
  final Color accentColor;

  const ModernVideoListCard({
    super.key,
    required this.video,
    required this.index,
    required this.colorScheme,
    required this.constraints,
    this.heroPrefix = 'video_list',
    this.accentColor = const Color(0xFFDC143C),
  });

  @override
  State<ModernVideoListCard> createState() => _ModernVideoListCardState();
}

class _ModernVideoListCardState extends State<ModernVideoListCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractionStyles.interactiveCard(
      onTap: () {
        Get.toNamed(
          '/watch?v=${widget.video.id}',
          arguments: {
            'video': widget.video,
            'heroTag': '${widget.heroPrefix}_${widget.video.id}',
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
    final thumbnailWidth = Responsive.isMobile(context.screenWidth)
        ? 120.0
        : Responsive.isTablet(context.screenWidth)
        ? 140.0
        : 160.0;
    final thumbnailHeight = Responsive.isMobile(context.screenWidth)
        ? 90.0
        : Responsive.isTablet(context.screenWidth)
        ? 105.0
        : 120.0;

    return Hero(
      tag: '${widget.heroPrefix}_${widget.video.id}',
      child: Container(
        width: thumbnailWidth,
        height: thumbnailHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: ComponentStyles.shadowSmall,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              SizedBox(
                width: thumbnailWidth,
                height: thumbnailHeight,
                child: CachedNetworkImage(
                  imageUrl: widget.video.thumbnailUrl.replaceAll(' ', '%20'),
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (thumbnailWidth * MediaQuery.of(context).devicePixelRatio)
                          .toInt(),
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: widget.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    highlightColor: widget.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.1),
                    child: Container(
                      color: widget.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accentColor.withValues(alpha: 0.3),
                          widget.accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: (thumbnailWidth * 0.3).clamp(24, 48),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: context.isMobileSmall ? 4 : 6,
                right: context.isMobileSmall ? 4 : 6,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.layoutSpacing / 2,
                    vertical: context.layoutSpacing / 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.video.duration,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontSize:
                          (AppTextStyles.labelSmall.fontSize ?? 11) *
                          context.fontScale,
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
          widget.video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Responsive.isMobile(context.screenWidth)
              ? AppTextStyles.videoTitleSmall.copyWith(
                  fontSize:
                      (AppTextStyles.videoTitleSmall.fontSize ?? 16) *
                      context.fontScale,
                )
              : AppTextStyles.videoTitleLarge.copyWith(
                  fontSize:
                      (AppTextStyles.videoTitleLarge.fontSize ?? 20) *
                      context.fontScale,
                ),
        ),
        SizedBox(height: context.layoutSpacing / 2),
        Row(
          children: [
            CircleAvatar(
              radius: Responsive.isMobileSmall(context.screenWidth)
                  ? 10
                  : Responsive.isMobile(context.screenWidth)
                  ? 12
                  : 14,
              backgroundColor: widget.accentColor.withValues(alpha: 0.2),
              child: ClipOval(
                child: widget.video.channelImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.video.channelImage.replaceAll(
                          ' ',
                          '%20',
                        ),
                        width:
                            (Responsive.isMobileSmall(context.screenWidth)
                                ? 10
                                : Responsive.isMobile(context.screenWidth)
                                ? 12
                                : 14) *
                            2,
                        height:
                            (Responsive.isMobileSmall(context.screenWidth)
                                ? 10
                                : Responsive.isMobile(context.screenWidth)
                                ? 12
                                : 14) *
                            2,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            ((Responsive.isMobileSmall(context.screenWidth)
                                        ? 10
                                        : Responsive.isMobile(
                                            context.screenWidth,
                                          )
                                        ? 12
                                        : 14) *
                                    2 *
                                    MediaQuery.of(context).devicePixelRatio)
                                .toInt(),
                        errorWidget: (context, url, error) =>
                            _buildChannelPlaceholder(),
                      )
                    : _buildChannelPlaceholder(),
              ),
            ),
            SizedBox(width: context.layoutSpacing / 2),
            Expanded(
              child: Text(
                widget.video.channelName,
                style: Responsive.isMobile(context.screenWidth)
                    ? AppTextStyles.channelNameSmall.copyWith(
                        fontSize:
                            (AppTextStyles.channelNameSmall.fontSize ?? 12) *
                            context.fontScale,
                      )
                    : AppTextStyles.channelName.copyWith(
                        fontSize:
                            (AppTextStyles.channelName.fontSize ?? 14) *
                            context.fontScale,
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                '${widget.video.views}',
                context,
              ),
            ),
            SizedBox(width: context.layoutSpacing),
            Flexible(
              child: _buildStatChip(
                Icons.favorite_rounded,
                '${widget.video.likeCount}',
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
        color: widget.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
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
            color: widget.accentColor,
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

  Widget _buildChannelPlaceholder() {
    return Center(
      child: Text(
        widget.video.channelName.isNotEmpty
            ? widget.video.channelName[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize:
              (Responsive.isMobileSmall(context.screenWidth) ? 8 : 10) *
              context.fontScale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ModernVideoGridCard extends StatefulWidget {
  final Video video;
  final int index;
  final ColorScheme colorScheme;
  final BoxConstraints constraints;
  final String heroPrefix;
  final Color accentColor;

  const ModernVideoGridCard({
    super.key,
    required this.video,
    required this.index,
    required this.colorScheme,
    required this.constraints,
    this.heroPrefix = 'video_grid',
    this.accentColor = const Color(0xFFDC143C), // AppColors.brand
  });

  @override
  State<ModernVideoGridCard> createState() => _ModernVideoGridCardState();
}

class _ModernVideoGridCardState extends State<ModernVideoGridCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractionStyles.interactiveCard(
      onTap: () {
        Get.toNamed('/watch?v=${widget.video.id}', arguments: {'video': widget.video});
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
      tag: '${widget.heroPrefix}_${widget.video.id}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: CachedNetworkImage(
              imageUrl: widget.video.thumbnailUrl.replaceAll(' ', '%20'),
              fit: BoxFit.cover,
              memCacheWidth:
                  (widget.constraints.maxWidth *
                          MediaQuery.of(context).devicePixelRatio)
                      .toInt(),
              placeholder: (context, url) => Container(
                color: widget.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.accentColor.withValues(alpha: 0.3),
                      widget.accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 32,
                    color: AppColors.textPrimary,
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
              widget.video.title,
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
                  '${widget.video.views}',
                  context,
                ),
              ),
              Flexible(
                child: _buildStatChip(
                  Icons.favorite_rounded,
                  '${widget.video.likeCount}',
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
            color: widget.accentColor,
          ),
          SizedBox(width: context.layoutSpacing / 4),
          Text(
            value,
            style: AppTextStyles.videoMetadataSmall.copyWith(
              fontSize:
                  (AppTextStyles.videoMetadataSmall.fontSize ?? 9) *
                  context.fontScale,
              color: widget.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}





