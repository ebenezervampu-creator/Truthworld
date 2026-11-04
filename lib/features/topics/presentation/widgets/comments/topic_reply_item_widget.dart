import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_models_and_helpers.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Presentation widget rendering an individual threaded reply to a topic comment.
class TopicReplyItemWidget extends StatelessWidget {
  const TopicReplyItemWidget({
    required this.reply,
    required this.commentId,
    required this.topicId,
    required this.controller,
    required this.theme,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.onNavigateToChannel,
    super.key,
  });

  final Reply reply;
  final String commentId;
  final String topicId;
  final TopicInteractionController controller;
  final ThemeData theme;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final void Function(String?) onNavigateToChannel;

  void _showReplyOptions(BuildContext context) {
    final isOwner = AuthService.to.isAuthenticated.value &&
        AuthService.to.uid == reply.userId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.content_copy_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Copy text',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  copyCommentTextToClipboard(reply.text);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save comment',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  toggleSaveTopicReply(reply: reply, topicId: topicId);
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.white),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    controller.deleteReply(topicId, commentId, reply.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Report',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    AppSnackbar.info(
                      'Thank you for your report.',
                      title: 'Reported',
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const avatarRadius = 12.0;
    final formattedUserName = reply.displayName;

    final argReplyId = Get.arguments is Map ? (Get.arguments['replyId'] as String?) : null;
    final paramReplyId = Get.parameters['replyId'];
    final targetReplyId = (argReplyId != null && argReplyId.isNotEmpty)
        ? argReplyId
        : ((paramReplyId != null && paramReplyId.isNotEmpty) ? paramReplyId : null);
    final isTargetReply = targetReplyId != null && targetReplyId == reply.id;

    if (isTargetReply) {
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

    return Obx(() {
      final interaction = controller.userReplyInteractions[reply.id] ??
          {'isLiked': false, 'isDisliked': false};
      final isLiked = interaction['isLiked'] ?? false;
      final isDisliked = interaction['isDisliked'] ?? false;

      return Container(
        decoration: isTargetReply
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              )
            : null,
        padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16, left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: reply.isChannelAuthor
                  ? () => onNavigateToChannel(reply.channelId)
                  : null,
              child: MouseRegion(
                cursor: reply.isChannelAuthor
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: UserAvatar(
                  radius: avatarRadius,
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
                      Flexible(
                        child: GestureDetector(
                          onTap: reply.isChannelAuthor
                              ? () => onNavigateToChannel(reply.channelId)
                              : null,
                          child: MouseRegion(
                            cursor: reply.isChannelAuthor
                                ? SystemMouseCursors.click
                                : SystemMouseCursors.basic,
                            child: Text(
                              formattedUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeago.format(reply.createdAt.toDate()),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (!AuthService.to.isAuthenticated.value) {
                            showTopicSignInPrompt('react to replies');
                            return;
                          }
                          HapticFeedback.lightImpact();
                          controller.toggleReplyLike(
                            topicId,
                            commentId,
                            reply.id,
                          );
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      if (reply.likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${reply.likeCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          isDisliked
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (!AuthService.to.isAuthenticated.value) {
                            showTopicSignInPrompt('react to replies');
                            return;
                          }
                          HapticFeedback.lightImpact();
                          controller.toggleReplyDislike(
                            topicId,
                            commentId,
                            reply.id,
                          );
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      if (reply.dislikeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${reply.dislikeCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 16,
              ),
              onPressed: () => _showReplyOptions(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }
}
