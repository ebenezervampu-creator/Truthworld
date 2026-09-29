import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_comment_item_controller.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_comment_options_sheet.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_comment_reply_input.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_reply_item.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/reply_thread_line_painter.dart';

/// Declarative widget displaying an individual community comment, reply drawer, and nested replies stream.
class CommunityCommentItemWidget extends StatelessWidget {
  const CommunityCommentItemWidget({
    required this.postId,
    required this.commentData,
    required this.currentUid,
    this.postOwnerId,
    super.key,
  });

  final String postId;
  final Map<String, dynamic> commentData;
  final String? currentUid;
  final String? postOwnerId;

  @override
  Widget build(BuildContext context) {
    final commentId = commentData['id'] as String? ?? '';
    final userName =
        commentData['channelName']?.toString().isNotEmpty ?? false
            ? commentData['channelName'].toString()
            : (commentData['userName']?.toString() ?? 'User');
    final userImage =
        commentData['channelProfilePicUrl']?.toString().isNotEmpty ?? false
            ? commentData['channelProfilePicUrl'].toString()
            : (commentData['userImage']?.toString() ??
                commentData['userProfilePicUrl']?.toString() ??
                '');
    final text = commentData['text']?.toString() ?? '';
    final ts =
        commentData['createdAt'] as Timestamp? ??
        commentData['timestamp'] as Timestamp?;
    final timeStr = ts != null ? timeago.format(ts.toDate()) : '';

    return GetBuilder<CommunityCommentItemController>(
      init: CommunityCommentItemController(
        postId: postId,
        commentData: commentData,
        currentUid: currentUid,
        postOwnerId: postOwnerId,
      ),
      tag: '${postId}_$commentId',
      builder: (controller) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    radius: 16,
                    photoUrl: userImage,
                    displayName: userName,
                    fontSize: 11,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Obx(
                              () => InkWell(
                                onTap: controller.toggleCommentLike,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        controller.isLiked.value
                                            ? Icons.thumb_up
                                            : Icons.thumb_up_outlined,
                                        color: controller.isLiked.value
                                            ? Colors.white
                                            : Colors.white70,
                                        size: 16,
                                      ),
                                      if (controller.likeCount.value > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          FormatUtils.formatCount(
                                            controller.likeCount.value,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Obx(
                              () => InkWell(
                                onTap: controller.toggleCommentDislike,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        controller.isDisliked.value
                                            ? Icons.thumb_down
                                            : Icons.thumb_down_outlined,
                                        color: controller.isDisliked.value
                                            ? Colors.white
                                            : Colors.white70,
                                        size: 16,
                                      ),
                                      if (controller.dislikeCount.value >
                                          0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          FormatUtils.formatCount(
                                            controller.dislikeCount.value,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            InkWell(
                              onTap: () {
                                if (!AuthService.to.isAuthenticated.value) {
                                  controller.showSignInPrompt(
                                    'reply to comments',
                                  );
                                  return;
                                }
                                controller.isReplying.value =
                                    !controller.isReplying.value;
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white54,
                                size: 16,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  CommunityCommentOptionsSheet.showCommentOptions(
                                context: context,
                                text: text,
                                isOwner: controller.isOwner,
                                onSave: controller.toggleSaveComment,
                                onDelete: controller.deleteComment,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Obx(() {
                if (!controller.isReplying.value) {
                  return const SizedBox.shrink();
                }
                return CommunityCommentReplyInput(
                  userName: userName,
                  replyController: controller.replyController,
                  onCancel: () => controller.isReplying.value = false,
                  onSubmit: controller.submitReply,
                );
              }),
              _buildRepliesSection(context, controller, commentId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRepliesSection(
    BuildContext context,
    CommunityCommentItemController controller,
    String commentId,
  ) {
    if (controller.repliesStream == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: controller.repliesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final replies = snapshot.data!.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        if (replies.isEmpty) return const SizedBox.shrink();

        return Obx(() {
          final isExpanded = controller.isRepliesExpanded.value;

          if (!isExpanded) {
            final firstReply = replies.first;
            final replyAvatar =
                firstReply['channelProfilePicUrl']?.toString().isNotEmpty ??
                        false
                    ? firstReply['channelProfilePicUrl'].toString()
                    : (firstReply['userImage']?.toString() ??
                        firstReply['userProfilePicUrl']?.toString() ??
                        '');
            final replyName =
                firstReply['channelName']?.toString().isNotEmpty ?? false
                    ? firstReply['channelName'].toString()
                    : (firstReply['userName']?.toString() ?? 'User');

            return InkWell(
              onTap: () => controller.isRepliesExpanded.value = true,
              child: Padding(
                padding: const EdgeInsets.only(left: 44, top: 4),
                child: Row(
                  children: [
                    const CustomPaint(
                      size: Size(20, 24),
                      painter: ReplyThreadLinePainter(
                        color: Colors.white24,
                        isLast: true,
                        branchY: 12,
                      ),
                    ),
                    UserAvatar(
                      radius: 10,
                      photoUrl: replyAvatar,
                      displayName: replyName,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      replies.length == 1
                          ? '• 1 reply'
                          : '• ${replies.length} replies',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
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
            children: List.generate(replies.length, (index) {
              final reply = replies[index];
              final isLastReply = index == replies.length - 1;
              return CommunityReplyItem(
                postId: postId,
                commentId: commentId,
                replyData: reply,
                postOwnerId: postOwnerId,
                isLastReply: isLastReply,
                onReplyToUser: (targetUser) =>
                    controller.prepareReplyToUser(targetUser),
              );
            }),
          );
        });
      },
    );
  }
}
