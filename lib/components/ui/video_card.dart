import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/watch_history_service.dart';

/// VideoCard: Optimized, reusable video card component
///
/// Features:
/// - Supports grid and list layouts
/// - Tokenized spacing, sizing, and colors
/// - Optimized image caching
/// - Semantic accessibility
/// - Performance optimized with const constructors
@immutable
class VideoCard extends StatelessWidget {
  final Video video;
  final bool isGrid;
  final String heroPrefix;

  final VoidCallback? onTap;

  const VideoCard({
    super.key,
    required this.video,
    this.isGrid = false,
    this.heroPrefix = 'video_card',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: 'Video: ${video.title} by ${video.channelName}',
      onTap: () => Get.toNamed(
        "/videoscreen",
        arguments: {'video': video, 'heroTag': '${heroPrefix}_${video.id}'},
      ),
      child: AnimatedContainer(
        duration: AppTheme.animations.normal,
        curve: AppTheme.animations.easeOutCubic,
        // No bottom margin for grid to eliminate unused space
        margin: isGrid ? EdgeInsets.zero : EdgeInsets.only(bottom: AppTheme.spacing.md),
        decoration: BoxDecoration(
          color: AppTheme.colors.surface,
          borderRadius: AppTheme.radius.circularLg,
          border: Border.all(
            color: AppTheme.colors.border.withValues(alpha: 0.3),
            width: AppTheme.components.dividerThickness,
          ),
          boxShadow: AppTheme.shadows.elevationMd,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTheme.radius.circularLg,
          child: InkWell(
            onTap:
                onTap ??
                () => Get.toNamed(
                  "/videoscreen",
                  arguments: {
                    'video': video,
                    'heroTag': '${heroPrefix}_${video.id}',
                  },
                ),
            borderRadius: AppTheme.radius.circularLg,
            hoverColor: AppTheme.colors.surface.withValues(alpha: 0.8),
            splashColor: AppTheme.colors.primary.withValues(alpha: 0.2),
            child: isGrid
                ? _buildGridContent(context)
                : _buildListContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThumbnail(
            AppTheme.sizes.thumbnailMediumWidth,
            AppTheme.sizes.thumbnailMediumHeight,
          ),
          SizedBox(width: AppTheme.spacing.sm),
          Expanded(child: _buildDetails(context)),
        ],
      ),
    );
  }

  Widget _buildGridContent(BuildContext context) {
    // Grid layout with thumbnail on top, details below - compact version
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Only take needed space
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildThumbnail(
            double.infinity,
            0, // AspectRatio handles height
            isTopRoundedOnly: true,
          ),
        ),
        // Compact padding - minimal space after thumbnail
        Padding(
          padding: EdgeInsets.only(
            left: AppTheme.spacing.xs,
            right: AppTheme.spacing.xs,
            top: AppTheme.spacing.xs,
            bottom: 0, // No bottom padding to eliminate unused space
          ),
          child: _buildDetails(context, isGrid: true),
        ),
      ],
    );
  }

  Widget _buildThumbnail(
    double? width,
    double? height, {
    bool isTopRoundedOnly = false,
  }) {
    final borderRadius = isTopRoundedOnly
        ? BorderRadius.vertical(top: Radius.circular(AppTheme.radius.lg))
        : AppTheme.radius.circularLg;

    return Hero(
      tag: '${heroPrefix}_${video.id}',
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              width: width,
              height: height,
              memCacheWidth: AppTheme.sizes.imageCacheMediumWidth,
              memCacheHeight: AppTheme.sizes.imageCacheMediumHeight,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppTheme.colors.surface,
                highlightColor: AppTheme.colors.border,
                child: Container(color: AppTheme.colors.surface),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.colors.surface,
                child: Icon(
                  Icons.play_circle_outline,
                  size: AppTheme.sizes.iconLg,
                  color: AppTheme.colors.primary,
                ),
              ),
            ),
            // Duration badge
            Positioned(
              bottom: AppTheme.spacing.xs,
              right: AppTheme.spacing.xs,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing.xs,
                  vertical: AppTheme.spacing.xs / 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: AppTheme.radius.circularMd,
                ),
                child: Text(
                  video.duration,
                  style: GoogleFonts.robotoMono(
                    color: AppTheme.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            // Watch progress bar (YouTube style)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Obx(() {
                final progress = WatchHistoryService.to.getProgress(video.id);
                if (progress <= 0) return const SizedBox.shrink();

                return Container(
                  height: 3,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (progress / 100).clamp(0.0, 1.0),
                      child: Container(
                        color: Colors.red,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, {bool isGrid = false}) {
    // YouTube-style layout: avatar on left, title and metadata on right
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Channel Avatar (shown in both grid and list for YouTube style)
        _buildChannelAvatar(),
        SizedBox(width: AppTheme.spacing.sm),
        // Title and metadata
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Video title
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.typography.body.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                semanticsLabel: 'Video title: ${video.title}',
              ),
              SizedBox(height: AppTheme.spacing.xs),
              // Channel name
              Text(
                video.channelName,
                style: AppTheme.typography.bodyMedium.copyWith(
                  color: AppTheme.colors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Views and date
              Text(
                '${_formatNumber(video.views)} views â€¢ ${_formatDate(video.uploadedAt)}',
                style: AppTheme.typography.caption.copyWith(
                  color: AppTheme.colors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelAvatar() {
    return SizedBox(
      width: AppTheme.sizes.avatarSm,
      height: AppTheme.sizes.avatarSm,
      child: CircleAvatar(
        radius: AppTheme.sizes.avatarSm / 2,
        backgroundColor: AppTheme.colors.primary,
        child: ClipOval(
          child: video.channelImage.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: video.channelImage,
                  width: AppTheme.sizes.avatarSm,
                  height: AppTheme.sizes.avatarSm,
                  fit: BoxFit.cover,
                  memCacheWidth: AppTheme.sizes.imageCacheSmallWidth,
                  memCacheHeight: AppTheme.sizes.imageCacheSmallHeight,
                  errorWidget: (context, url, error) => Icon(
                    Icons.account_circle,
                    size: AppTheme.sizes.iconMd,
                    color: AppTheme.colors.textPrimary,
                  ),
                )
              : Icon(
                  Icons.account_circle,
                  size: AppTheme.sizes.iconMd,
                  color: AppTheme.colors.textPrimary,
                ),
        ),
      ),
    );
  }

  // Unreferenced method removed

  // Unreferenced method removed

  /// Format large numbers (e.g., 1000000 -> 1M)
  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  /// Format timestamp into readable date
  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      // More concise date format for grid cards
      return DateFormat.yMMMd().format(date);
    }
    return timestamp.toString();
  }
}





