import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/widgets/channel_verified_badge.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';

/// Header row displaying comment author, verified channel badge, loyalty badge, timestamp, and creator heart.
class CommentAuthorHeader extends StatelessWidget {
  const CommentAuthorHeader({
    required this.comment,
    required this.channelAvatarUrl,
    super.key,
    this.videoChannelId,
  });

  final Comment comment;
  final String channelAvatarUrl;
  final String? videoChannelId;

  @override
  Widget build(BuildContext context) {
    final formattedUserName = comment.displayName;
    final isChannelCreator = comment.channelId.isNotEmpty &&
        comment.channelId == videoChannelId;
    final canNavigate = comment.isChannelAuthor || isChannelCreator;

    return Row(
      children: [
        Flexible(
          child: GestureDetector(
            onTap: canNavigate
                ? () => CommentActionHandler.navigateToChannel(
                      comment.channelId,
                      channelHandle: comment.displayName,
                    )
                : null,
            child: MouseRegion(
              cursor: canNavigate
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: isChannelCreator
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              formattedUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const ChannelVerifiedBadge(size: 13),
                        ],
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            formattedUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (comment.isMember) ...[
                          const SizedBox(width: 6),
                          ChannelLoyaltyBadgeWidget(
                            milestone: comment.loyaltyMilestone ??
                                ChannelLoyaltyMilestone.newMember,
                            tierName: comment.memberTierName,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeago.format(comment.createdAt.toDate()),
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Creator heart badge displayed when the video owner hearts a comment.
class CommentCreatorHeartBadge extends StatelessWidget {
  const CommentCreatorHeartBadge({
    required this.channelAvatarUrl,
    super.key,
    this.creatorHeartName,
  });

  final String channelAvatarUrl;
  final String? creatorHeartName;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Hearted by ${creatorHeartName ?? 'Creator'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(
                radius: 8,
                photoUrl: channelAvatarUrl,
                displayName: creatorHeartName ?? 'Creator',
                fontSize: 8,
              ),
              const Positioned(
                bottom: -3,
                right: -3,
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
