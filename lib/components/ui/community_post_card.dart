import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/commnuity/data/models/community_post_model.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/components/ui/user_avatar.dart';

class CommunityPostCard extends StatelessWidget {
  final CommunityPostModel post;
  final VoidCallback? onTap;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: 'Community Post: ${post.title}',
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
                _buildImages(),
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

  Widget _buildImages() {
    if (post.images.isEmpty) {
      return SizedBox(
        height: 120,
        child: Container(
          color: AppTheme.colors.surface,
          child: Icon(
            Icons.article,
            size: AppTheme.sizes.iconLg,
            color: AppTheme.colors.primary,
          ),
        ),
      );
    }

    if (post.images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius.lg)),
        child: CachedNetworkImage(
          imageUrl: post.images.first,
          fit: BoxFit.cover,
          height: 150,
          memCacheWidth: AppTheme.sizes.imageCacheMediumWidth,
          memCacheHeight: AppTheme.sizes.imageCacheMediumHeight,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: AppTheme.colors.surface,
            highlightColor: AppTheme.colors.border,
            child: Container(color: AppTheme.colors.surface),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppTheme.colors.surface,
            child: Icon(Icons.error),
          ),
        ),
      );
    }

    // Multiple images grid
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius.lg)),
      child: SizedBox(
        height: 150,
        child: GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: post.images.length > 4 ? 3 : 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: post.images.take(4).length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: post.images[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppTheme.colors.surface,
                highlightColor: AppTheme.colors.border,
                child: Container(color: AppTheme.colors.surface),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.colors.surface,
                child: Icon(Icons.error),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          post.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.typography.body.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        SizedBox(height: AppTheme.spacing.xs),
        Row(
          children: [
            UserAvatar(
              radius: 12,
              photoUrl: post.channelImage,
              displayName: post.channelName,
              fontSize: 12,
            ),
            SizedBox(width: AppTheme.spacing.xs),
            Expanded(
              child: Text(
                post.channelName,
                style: AppTheme.typography.bodyMedium.copyWith(
                  color: AppTheme.colors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacing.xs),
        Row(
          children: [
            Icon(Icons.thumb_up_outlined, size: 14, color: AppTheme.colors.textTertiary),
            SizedBox(width: 4),
            Text(
              '${post.likes}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.thumb_down_outlined, size: 14, color: AppTheme.colors.textTertiary),
            SizedBox(width: 4),
            Text(
              '${post.dislikeCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.comment_outlined, size: 14, color: AppTheme.colors.textTertiary),
            SizedBox(width: 4),
            Text(
              '${post.commentCount}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
            Icon(Icons.visibility_outlined, size: 14, color: AppTheme.colors.textTertiary),
            SizedBox(width: 4),
            Text(
              '${post.views}',
              style: AppTheme.typography.caption.copyWith(
                color: AppTheme.colors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}



