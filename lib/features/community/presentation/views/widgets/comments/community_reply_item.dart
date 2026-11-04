import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_comment_options_sheet.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/community_reply_item_controller.dart';
import 'package:truthworld/features/community/presentation/views/widgets/comments/reply_thread_line_painter.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';
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
    this.targetReplyId,
    super.key,
  });

  final String postId;
  final String commentId;
  final Map<String, dynamic> replyData;
  final String? postOwnerId;
  final String? targetReplyId;
  final bool isLastReply;
  final ValueChanged<String> onReplyToUser;

  @override
  Widget build(BuildContext context) {
    final replyId = replyData['id'] as String? ?? '';
    final rawChannelId = (replyData['channelId']?.toString() ?? '').trim();
    final rawUserId = (replyData['userId']?.toString() ?? '').trim();
    final channelHandle = (replyData['channelHandle']?.toString() ??
        replyData['handle']?.toString() ??
        '').trim();
    final channelName = (replyData['channelName']?.toString() ?? '').trim();
    final channelProfilePicUrl = (replyData['channelProfilePicUrl']?.toString() ??
        replyData['channelAvatarUrl']?.toString() ??
        '').trim();

    final isChannel = replyData['isChannel'] == true ||
        channelHandle.isNotEmpty ||
        (rawChannelId.isNotEmpty && rawChannelId != rawUserId) ||
        channelProfilePicUrl.isNotEmpty ||
        (rawChannelId.isNotEmpty && ChannelMemoryCache.get(rawChannelId) != null);

    final String displayName;
    final String avatarUrl;

    if (isChannel) {
      final handle = () {
        if (channelHandle.isNotEmpty) return channelHandle;
        if (rawChannelId.isNotEmpty) {
          final cached = ChannelMemoryCache.get(rawChannelId);
          if (cached != null && cached.handle.trim().isNotEmpty) {
            return cached.handle.trim();
          }
        }
        if (channelName.isNotEmpty) return channelName;
        return 'channel';
      }();
      displayName = handle.startsWith('@') ? handle : '@$handle';
      avatarUrl = channelProfilePicUrl.isNotEmpty
          ? channelProfilePicUrl
          : (rawChannelId.isNotEmpty
              ? (ChannelMemoryCache.get(rawChannelId)?.avatarUrl ?? '')
              : '');
    } else {
      final rawName = replyData['userName']?.toString() ??
          replyData['displayName']?.toString() ??
          replyData['name']?.toString() ??
          'User';
      displayName = rawName.startsWith('@') ? rawName.substring(1) : rawName;
      avatarUrl = replyData['userProfilePicUrl']?.toString() ??
          replyData['userImage']?.toString() ??
          '';
    }
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
        final isTarget = targetReplyId != null && targetReplyId == replyId;
        if (isTarget) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          });
        }

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
                  child: Container(
                    decoration: isTarget
                        ? BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          )
                        : null,
                    padding: isTarget
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                        : EdgeInsets.zero,
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
                            GestureDetector(
                              onTap: isChannel
                                  ? () => CommentActionHandler.navigateToChannel(
                                        rawChannelId,
                                        channelHandle: displayName,
                                      )
                                  : null,
                              child: MouseRegion(
                                cursor: isChannel
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                                child: UserAvatar(
                                  radius: 10,
                                  photoUrl: avatarUrl,
                                  displayName: displayName,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: isChannel
                                  ? () => CommentActionHandler.navigateToChannel(
                                        rawChannelId,
                                        channelHandle: displayName,
                                      )
                                  : null,
                              child: MouseRegion(
                                cursor: isChannel
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
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
                        ClickableUrlText(
                          text: rText,
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
                              onTap: () => onReplyToUser(displayName),
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
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}
