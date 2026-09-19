import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_models_and_helpers.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_reply_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_replies_section.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Presentation widget rendering an individual topic comment and its interaction controls.
class TopicCommentItemWidget extends StatelessWidget {
  const TopicCommentItemWidget({
    required this.comment,
    required this.topicId,
    required this.controller,
    required this.theme,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.onNavigateToChannel,
    super.key,
  });

  final Comment comment;
  final String topicId;
  final TopicInteractionController controller;
  final ThemeData theme;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final void Function(String?) onNavigateToChannel;

  void _showCommentOptions(BuildContext context) {
    final isOwner = AuthService.to.isAuthenticated.value &&
        AuthService.to.uid == comment.userId;

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
                  copyCommentTextToClipboard(comment.text);
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
                  toggleSaveTopicComment(comment: comment, topicId: topicId);
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
                    controller.deleteComment(topicId, comment.id);
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
    final formattedUserName = comment.displayName;
    final text = comment.text;
    final createdAt = comment.createdAt;
    final userProfilePicUrl = comment.avatarUrl;
    final likeCount = comment.likeCount;
    final commentId = comment.id;

    final replyController = Get.isRegistered<TopicCommentReplyController>(
      tag: comment.id,
    )
        ? Get.find<TopicCommentReplyController>(tag: comment.id)
        : Get.put(TopicCommentReplyController(), tag: comment.id);

    return Obx(() {
      final interaction = controller.userCommentInteractions[comment.id] ??
          {
            'isLiked': comment.isLikedByCurrentUser,
            'isDisliked': comment.isDislikedByCurrentUser,
          };
      final isLiked = interaction['isLiked'] ?? false;
      final isDisliked = interaction['isDisliked'] ?? false;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => onNavigateToChannel(comment.channelId),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: UserAvatar(
                      photoUrl: userProfilePicUrl,
                      displayName: formattedUserName,
                      backgroundColor: AppColors.info,
                      textColor: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () =>
                                  onNavigateToChannel(comment.channelId),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  formattedUserName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(createdAt.toDate()),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (!AuthService.to.isAuthenticated.value) {
                                showTopicSignInPrompt('like comments');
                                return;
                              }
                              HapticFeedback.lightImpact();
                              controller.toggleCommentLike(
                                topicId,
                                comment.id,
                              );
                            },
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                if (likeCount > 0)
                                  Text(
                                    '$likeCount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLiked
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () {
                              if (!AuthService.to.isAuthenticated.value) {
                                showTopicSignInPrompt('dislike comments');
                                return;
                              }
                              HapticFeedback.lightImpact();
                              controller.toggleCommentDislike(
                                topicId,
                                comment.id,
                              );
                            },
                            child: Icon(
                              isDisliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          if (comment.isHeartedByCreator) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message:
                                  'Hearted by ${comment.creatorHeartName ?? 'Creator'}',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      UserAvatar(
                                        radius: 8,
                                        photoUrl: comment.avatarUrl,
                                        displayName: 'Creator',
                                        fontSize: 8,
                                      ),
                                      const Positioned(
                                        bottom: -3,
                                        right: -3,
                                        child: Icon(
                                          Icons.favorite,
                                          color: AppColors.error,
                                          size: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () =>
                                replyController.startReplying(context),
                            child: const Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
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
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => _showCommentOptions(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (replyController.isReplying.value)
              Padding(
                key: ValueKey('reply_box_$commentId'),
                padding: const EdgeInsets.only(left: 52, top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController.replyController,
                        focusNode: replyController.replyFocusNode,
                        inputFormatters:
                            TruthworldTextInputFormatters.standard,
                        decoration: const InputDecoration(
                          hintText: 'Add a reply...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.textPrimary,
                              width: 1.5,
                            ),
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => replyController.submitReply(
                          topicId: topicId,
                          commentId: comment.id,
                          controller: controller,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: replyController.cancelReplying,
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => replyController.submitReply(
                        topicId: topicId,
                        commentId: comment.id,
                        controller: controller,
                      ),
                      icon: const Icon(
                        Icons.send,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            if (commentId.isNotEmpty)
              TopicRepliesSection(
                commentId: comment.id,
                topicId: topicId,
                controller: controller,
                theme: theme,
                isMobile: isMobile,
                isTablet: isTablet,
                isDesktop: isDesktop,
                onNavigateToChannel: onNavigateToChannel,
              ),
          ],
        ),
      );
    });
  }
}
