import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/widgets/channel_verified_badge.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_actions_sheet.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/reply_thread_line_painter.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single row item representing a nested reply with thread line, author, text, reactions, and options.
class CommentReplyItem extends StatelessWidget {
  const CommentReplyItem({
    required this.reply,
    required this.commentId,
    required this.isLastReply,
    required this.commentsController,
    super.key,
    this.videoChannelId,
    this.isTarget = false,
  });

  final Reply reply;
  final String commentId;
  final bool isLastReply;
  final CommentsController commentsController;
  final String? videoChannelId;
  final bool isTarget;

  @override
  Widget build(BuildContext context) {
    final isReplyLiked = commentsController.isReplyLikedByUser(reply.id);
    final isReplyDisliked = commentsController.isReplyDislikedByUser(reply.id);
    final isCreator = reply.channelId.isNotEmpty &&
        reply.channelId == videoChannelId;
    final canNavigate = reply.isChannelAuthor || isCreator;
    final authorDisplayName = reply.displayName;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomPaint(
            size: const Size(40, double.infinity),
            painter: ReplyThreadLinePainter(
              color: Colors.white24,
              isLast: isLastReply,
              branchY: 20,
            ),
          ),
          Expanded(
            child: Container(
              decoration: isTarget
                  ? BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.08),
                      border: const Border(
                        left: BorderSide(
                          color: AppColors.brand,
                          width: 3,
                        ),
                      ),
                    )
                  : null,
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 8,
                right: 16,
                left: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: canNavigate
                        ? () => CommentActionHandler.navigateToChannel(
                              reply.channelId,
                              channelHandle: reply.displayName,
                            )
                        : null,
                    child: MouseRegion(
                      cursor: canNavigate
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: UserAvatar(
                        radius: 12,
                        photoUrl: reply.avatarUrl,
                        displayName: reply.displayName,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: canNavigate
                                  ? () => CommentActionHandler.navigateToChannel(
                                        reply.channelId,
                                        channelHandle: reply.displayName,
                                      )
                                  : null,
                              child: MouseRegion(
                                cursor: canNavigate
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                                child: isCreator
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              authorDisplayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const ChannelVerifiedBadge(size: 11),
                                          ],
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            authorDisplayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (reply.isMember) ...[
                                            const SizedBox(width: 4),
                                            ChannelLoyaltyBadgeWidget(
                                              milestone: reply.loyaltyMilestone ??
                                                  ChannelLoyaltyMilestone.newMember,
                                              tierName: reply.memberTierName,
                                              compact: true,
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeago.format(reply.createdAt.toDate()),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ClickableUrlText(
                          text: reply.text,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => commentsController.toggleReplyLike(
                                commentId: commentId,
                                replyId: reply.id,
                                likeAsChannel: false,
                                replyAuthorId: reply.userId,
                                replyText: reply.text,
                              ),
                              child: Icon(
                                isReplyLiked
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                size: 14,
                                color: isReplyLiked
                                    ? Colors.white
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (reply.likeCount > 0)
                              Text(
                                '${reply.likeCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isReplyLiked
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                              ),
                            const SizedBox(width: 16),
                            InkWell(
                              onTap: () => commentsController.toggleReplyDislike(
                                commentId: commentId,
                                replyId: reply.id,
                                dislikeAsChannel: false,
                              ),
                              child: Icon(
                                isReplyDisliked
                                    ? Icons.thumb_down
                                    : Icons.thumb_down_outlined,
                                size: 14,
                                color: isReplyDisliked
                                    ? Colors.white
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white70,
                      size: 16,
                    ),
                    onPressed: () => CommentActionsSheet.showReplyOptions(
                      context,
                      reply,
                      commentId,
                      commentsController,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
