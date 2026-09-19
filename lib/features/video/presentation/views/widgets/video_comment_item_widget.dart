import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_item_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'comments/comment_item_barrel.dart';

/// Single item widget rendering a top-level video comment with author info,
/// interactions (like, dislike, reply, options), and expandable nested replies.
class CommentItemWidget extends StatelessWidget {
  const CommentItemWidget({
    required this.comment,
    required this.videoId,
    required this.channelAvatarUrl,
    required this.mainController,
    required this.textSecondary,
    super.key,
  });

  final Comment comment;
  final String videoId;
  final String channelAvatarUrl;
  final MainController mainController;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final commentId = comment.id;
    final commentsTag = 'video_$videoId';
    final commentsController = Get.isRegistered<CommentsController>(tag: commentsTag)
        ? Get.find<CommentsController>(tag: commentsTag)
        : Get.put(CommentsController(), tag: commentsTag);

    final itemTag = 'comment_$commentId';
    final itemController = Get.isRegistered<CommentItemController>(tag: itemTag)
        ? Get.find<CommentItemController>(tag: itemTag)
        : Get.put(CommentItemController(), tag: itemTag);

    return Obx(() {
      final isLiked = commentsController.isCommentLikedByUser(comment);
      final isDisliked = commentsController.isCommentDislikedByUser(comment);

      final isTarget =
          commentsController.targetCommentId.value == comment.id &&
          commentsController.targetReplyId.value == null;

      if (isTarget && !commentsController.hasScrolledToTarget) {
        commentsController.hasScrolledToTarget = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        });
      }

      final isDonated = comment.isDonatedComment || comment.donationAmount > 0;
      Color? donationColor;
      if (isDonated &&
          comment.donationColorHex != null &&
          comment.donationColorHex!.isNotEmpty) {
        try {
          donationColor = Color(int.parse(comment.donationColorHex!));
        } catch (_) {}
      }
      donationColor ??= const Color(0xFF1E88E5);

      BoxDecoration? containerDecoration;
      if (isTarget) {
        containerDecoration = BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.08),
          border: const Border(
            left: BorderSide(
              color: AppColors.brand,
              width: 3,
            ),
          ),
        );
      } else if (isDonated) {
        containerDecoration = BoxDecoration(
          color: donationColor.withValues(alpha: 0.05),
          border: Border(
            left: BorderSide(
              color: donationColor,
              width: 3,
            ),
          ),
        );
      }

      return Container(
        decoration: containerDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => CommentActionHandler.navigateToChannel(comment.channelId),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: UserAvatar(
                      photoUrl: comment.avatarUrl,
                      displayName: comment.displayName,
                      backgroundColor: Colors.blue,
                      textColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommentAuthorHeader(
                        comment: comment,
                        channelAvatarUrl: channelAvatarUrl,
                        videoChannelId: commentsController.video?.channelId,
                      ),
                      if (isDonated) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: donationColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: donationColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite,
                                color: donationColor,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Super Thanks ${comment.donationCurrency}${comment.donationAmount >= 1 && comment.donationAmount == comment.donationAmount.truncateToDouble() ? comment.donationAmount.toInt() : comment.donationAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: donationColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        comment.text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => commentsController.toggleCommentLike(
                              commentId: commentId,
                              likeAsChannel: false,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: isLiked
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                if (comment.likeCount > 0)
                                  Text(
                                    '${comment.likeCount}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLiked
                                          ? Colors.white
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => commentsController.toggleCommentDislike(
                              commentId: commentId,
                              dislikeAsChannel: false,
                            ),
                            child: Icon(
                              isDisliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined,
                              size: 16,
                              color: isDisliked
                                  ? Colors.white
                                  : Colors.grey.shade400,
                            ),
                          ),
                          if (comment.isHeartedByCreator) ...[
                            const SizedBox(width: 8),
                            CommentCreatorHeartBadge(
                              channelAvatarUrl: channelAvatarUrl,
                              creatorHeartName: comment.creatorHeartName,
                            ),
                            const SizedBox(width: 8),
                          ],
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => itemController.toggleReplying(context),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                  onPressed: () => CommentActionsSheet.showCommentOptions(
                    context,
                    comment,
                    commentsController,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (itemController.isReplying.value)
              CommentReplyInputBox(
                commentId: commentId,
                controller: itemController,
                onSubmit: () => itemController.submitReply(
                  commentId: commentId,
                  videoId: videoId,
                  commentAuthorId: comment.userId,
                ),
              ),
            if (commentId.isNotEmpty)
              CommentRepliesSection(
                videoId: videoId,
                commentId: commentId,
                mainController: mainController,
                controller: itemController,
                videoChannelId: commentsController.video?.channelId,
              ),
          ],
        ),
      );
    });
  }
}
