import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlaylistCard extends StatelessWidget {

  const PlaylistCard({
    required this.playlist, super.key,
    this.onTap,
  });
  final PlaylistModel playlist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: 'Playlist: ${playlist.name}',
      child: AnimatedContainer(
        duration: AppTheme.animations.normal,
        curve: AppTheme.animations.easeOutCubic,
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
            onTap: onTap,
            borderRadius: AppTheme.radius.circularLg,
            hoverColor: AppTheme.colors.surface.withValues(alpha: 0.8),
            splashColor: AppTheme.colors.primary.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildThumbnail(),
                ),
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing.xs),
                  child: _buildDetails(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius.lg)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (playlist.thumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: playlist.thumbnailUrl,
              fit: BoxFit.cover,
              memCacheWidth: AppTheme.sizes.imageCacheMediumWidth,
              memCacheHeight: AppTheme.sizes.imageCacheMediumHeight,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppTheme.colors.surface,
                highlightColor: AppTheme.colors.border,
                child: Container(color: AppTheme.colors.surface),
              ),
              errorWidget: (context, url, error) => ColoredBox(
                color: AppTheme.colors.surface,
                child: Icon(
                  Icons.playlist_play,
                  size: AppTheme.sizes.iconLg,
                  color: AppTheme.colors.primary,
                ),
              ),
            )
          else
            ColoredBox(
              color: AppTheme.colors.surface,
              child: Icon(
                Icons.playlist_play,
                size: AppTheme.sizes.iconLg,
                color: AppTheme.colors.primary,
              ),
            ),
          Positioned(
            bottom: AppTheme.spacing.xs,
            right: AppTheme.spacing.xs,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing.xs,
                vertical: AppTheme.spacing.xs / 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgPage.withValues(alpha: 0.85),
                borderRadius: AppTheme.radius.circularMd,
              ),
              child: Text(
                '${playlist.videoCount} videos',
                style: AppTheme.typography.caption.copyWith(
                  color: AppTheme.colors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playlist.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.typography.body.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        if (playlist.description.isNotEmpty) ...[
          SizedBox(height: AppTheme.spacing.xs),
          Text(
            playlist.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.typography.bodyMedium.copyWith(
              color: AppTheme.colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}



