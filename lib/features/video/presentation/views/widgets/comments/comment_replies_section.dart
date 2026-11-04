import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_item_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_reply_item.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/reply_thread_line_painter.dart';

/// Section managing the replies stream, collapsed summary count, and expanded replies thread.
class CommentRepliesSection extends StatelessWidget {
  const CommentRepliesSection({
    required this.videoId,
    required this.commentId,
    required this.mainController,
    required this.controller,
    super.key,
    this.videoChannelId,
  });

  final String videoId;
  final String commentId;
  final MainController mainController;
  final CommentItemController controller;
  final String? videoChannelId;

  @override
  Widget build(BuildContext context) {
    final tag = 'video_$videoId';
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(), tag: tag);

    return StreamBuilder<List<Reply>>(
      stream: mainController.getRepliesStream(videoId, commentId),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data ?? [];
        if (replies.isEmpty) {
          return const SizedBox.shrink();
        }

        // Auto-expand replies if this comment contains the target reply
        final targetReplyId = commentsController.targetReplyId.value;
        if (targetReplyId != null && targetReplyId.isNotEmpty) {
          final hasTargetReply = replies.any((r) => r.id == targetReplyId);
          if (hasTargetReply && !controller.isRepliesExpanded.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.setRepliesExpanded(true);
            });
          }
        }

        return Obx(() {
          final isExpanded = controller.isRepliesExpanded.value;

          if (!isExpanded) {
            final firstReply = replies.first;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.setRepliesExpanded(true),
                child: Row(
                children: [
                  CustomPaint(
                    size: const Size(40, 36),
                    painter: ReplyThreadLinePainter(
                      color: Colors.white24,
                      isLast: true,
                      branchY: 18,
                    ),
                  ),
                  UserAvatar(
                    radius: 10,
                    photoUrl: firstReply.avatarUrl,
                    displayName: firstReply.displayName,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    replies.length == 1
                        ? '• 1 reply'
                        : '• ${replies.length} replies',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(replies.length, (index) {
                final reply = replies[index];
                final isLastReply = index == replies.length - 1;
                final isReplyTarget =
                    commentsController.targetReplyId.value == reply.id;

                if (isReplyTarget && !commentsController.hasScrolledToTarget) {
                  commentsController.hasScrolledToTarget = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  });
                }

                return CommentReplyItem(
                  reply: reply,
                  commentId: commentId,
                  isLastReply: isLastReply,
                  commentsController: commentsController,
                  videoChannelId: videoChannelId,
                  isTarget: isReplyTarget,
                );
              }),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.setRepliesExpanded(false),
                  child: Row(
                    children: [
                      CustomPaint(
                        size: const Size(40, 36),
                        painter: ReplyThreadLinePainter(
                          color: Colors.white24,
                          isLast: true,
                          branchY: 18,
                        ),
                      ),
                      const Text(
                        'Hide replies',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_less,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}
