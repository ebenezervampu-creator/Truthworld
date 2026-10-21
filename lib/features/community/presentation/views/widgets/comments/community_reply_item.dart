import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_comment_options_sheet.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_reply_item_controller.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/reply_thread_line_painter.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Declarative widget displaying an individual reply within a threaded comment hierarchy.
class CommunityReplyItem extends StatelessWidget {
  const CommunityReplyItem({
    required this.postId,
    required this.commentId,
    required this.replyData,
    required this.onReplyToUser,
    required this.isLastReply,
    this.postOwnerId,
    super.key,
  });

  final String postId;
  final String commentId;
  final Map<String, dynamic> replyData;
  final String? postOwnerId;
  final bool isLastReply;
  final ValueChanged<String> onReplyToUser;

  @override
  Widget build(BuildContext context) {
    final replyId = replyData['id'] as String? ?? '';
    final isChannel = replyData['isChannel'] == true &&
        (replyData['channelId']?.toString().isNotEmpty ?? false);
    final rawName = isChannel &&
            (replyData['channelName']?.toString().isNotEmpty ?? false)
        ? replyData['channelName'].toString()
        : (replyData['userName']?.toString() ??
            replyData['displayName']?.toString() ??
            replyData['name']?.toString() ??
            'User');
    final rName = rawName.startsWith('@') ? rawName.substring(1) : rawName;
    final rImage = isChannel &&
            (replyData['channelProfilePicUrl']?.toString().isNotEmpty ?? false)
        ? replyData['channelProfilePicUrl'].toString()
        : (replyData['userImage']?.toString() ??
            replyData['userProfilePicUrl']?.toString() ??
            '');
    final rText = ContentValidator.cleanProfanity(replyData['text']?.toString() ?? '');
    final rTs =
        replyData['createdAt'] as Timestamp? ??
        replyData['timestamp'] as Timestamp?;
    final rTimeStr = rTs != null ? timeago.format(rTs.toDate()) : '';

    return GetBuilder<CommunityReplyItemController>(
      init: CommunityReplyItemController(
        postId: postId,
        commentId: commentId,
        replyData: replyData,
        postOwnerId: postOwnerId,
      ),
      tag: '${commentId}_$replyId',
      builder: (controller) {
        return IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomPaint(
                  size: const Size(20, double.infinity),
                  painter: ReplyThreadLinePainter(
                    color: Colors.white24,
                    isLast: isLastReply,
                    branchY: 16,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: 6,
                      left: 6,
                      right: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              radius: 10,
                              photoUrl: rImage,
                              displayName: rName,
                              fontSize: 9,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              rName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            if (isChannel) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brand,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'Channel',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                            if (rTimeStr.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                rTimeStr,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Obx(
                              () => InkWell(
                                onTap: controller.toggleReplyLike,
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
                                        size: 14,
                                      ),
                                      if (controller.likeCount.value > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          FormatUtils.formatCount(
                                            controller.likeCount.value,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
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
                                onTap: controller.toggleReplyDislike,
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
                                        size: 14,
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
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              onTap: () => onReplyToUser(rName),
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
                                    fontSize: 11,
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
                                size: 14,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  CommunityCommentOptionsSheet.showReplyOptions(
                                context: context,
                                text: rText,
                                isOwner: controller.isOwner,
                                onSave: controller.saveReply,
                                onDelete: controller.deleteReply,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
