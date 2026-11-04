import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/widgets/channel_verified_badge.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Header for Community Post Card
/// Displays channel avatar, channel name, formatted timestamp, and options menu button.
class CommunityPostHeader extends StatelessWidget {
  const CommunityPostHeader({
    required this.post,
    required this.onOpenOptions,
    super.key,
  });

  final CommunityPostModel post;
  final VoidCallback onOpenOptions;

  void _navigateToChannel() {
    CommentActionHandler.navigateToChannel(
      post.channelId,
      channelHandle: post.channelName,
    );
  }

  String _formatTimestamp() {
    try {
      return timeago.format(post.uploadedAt);
    } catch (_) {
      return '${post.uploadedAt.day}/${post.uploadedAt.month}/${post.uploadedAt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          InkWell(
            onTap: _navigateToChannel,
            borderRadius: BorderRadius.circular(20),
            child: UserAvatar(
              photoUrl: post.channelImage,
              displayName: post.channelName,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _navigateToChannel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (post.showVerifiedBadge ||
                            (DeepLinkService.instance
                                    .getChannelFromCache(post.channelId)
                                    ?.showVerifiedBadge ??
                                false) ||
                            (DeepLinkService.instance
                                    .getChannelFromCache(post.channelName)
                                    ?.showVerifiedBadge ??
                                false)) ...[
                          const SizedBox(width: 4),
                          const ChannelVerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white, // Rule compliance: white icon
            ),
            onPressed: onOpenOptions,
          ),
        ],
      ),
    );
  }
}
