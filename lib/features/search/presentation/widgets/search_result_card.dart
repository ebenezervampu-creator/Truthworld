import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const SearchResultCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.radius.circularLg,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppTheme.spacing.sm,
          horizontal: AppTheme.spacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildThumbnailOrAvatar(),
            SizedBox(width: AppTheme.spacing.md),
            Expanded(child: _buildDetails()),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailOrAvatar() {
    if (result.type == ResultType.channel) {
      return Container(
        width: 160,
        alignment: Alignment.center,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: result.thumbnail,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppTheme.colors.surface),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.colors.surface,
                child: Icon(Icons.person, color: AppTheme.colors.textSecondary, size: 40),
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: AppTheme.radius.circularMd,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: result.thumbnail,
            width: 160,
            height: 90,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 160,
              height: 90,
              color: AppTheme.colors.surface,
            ),
            errorWidget: (context, url, error) => Container(
              width: 160,
              height: 90,
              color: AppTheme.colors.surface,
              child: Icon(
                result.type == ResultType.playlist ? Icons.playlist_play : Icons.video_library,
                color: Colors.white24,
              ),
            ),
          ),
          if (result.type == ResultType.playlist)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 60,
                color: Colors.black.withValues(alpha: 0.6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${result.views}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.playlist_play, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.typography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (result.type != ResultType.channel)
                    Row(
                      children: [
                        if (result.channelImage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundImage: CachedNetworkImageProvider(result.channelImage),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            result.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.typography.caption.copyWith(
                              color: AppTheme.colors.textSecondary,
                            ),
                          ),
                        ),
                        if (result.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.check_circle, size: 12, color: Colors.blue),
                          ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    result.type == ResultType.channel
                        ? '${_formatCount(result.views)} Subscribers'
                        : (result.type == ResultType.playlist
                            ? 'Playlist • ${result.views} videos'
                            : '${_formatCount(result.views)} views • ${timeago.format(result.createdAt.toDate())}'),
                    style: AppTheme.typography.caption.copyWith(
                      color: AppTheme.colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (result.type == ResultType.channel)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Obx(() {
                  final subController = Get.isRegistered<SubscriptionController>()
                      ? Get.find<SubscriptionController>()
                      : Get.put(SubscriptionController());
                  final isSubscribed = subController.isSubscribed(result.id);
                  
                  return TextButton(
                    onPressed: () async {
                      if (isSubscribed) {
                        await subController.unsubscribeFromChannel(result.id);
                      } else {
                        await subController.subscribeToChannel(result.id);
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: isSubscribed ? Colors.grey[850] : Colors.white,
                      foregroundColor: isSubscribed ? Colors.white70 : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      isSubscribed ? 'Subscribed' : 'Subscribe',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                }),
              ),
          ],
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}
