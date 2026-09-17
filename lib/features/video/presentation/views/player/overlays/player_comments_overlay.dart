import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/player_settings_panels.dart';
import 'package:truthworld/theme/app_theme.dart';

class CommentsOverlay extends StatelessWidget {
  const CommentsOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final tag = 'video_${ctrl.tag}';
    final hasCommentsCtrl = Get.isRegistered<CommentsController>(tag: tag);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // Absorb taps
      child: Container(
        decoration: BoxDecoration(
          color: PT.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PT.border),
        ),
        child: Column(
          children: [
            Obx(
              () => PanelHeader(
                title: 'Comments',
                onBack: null,
                onClose: () {
                  ctrl.showCommentsPopup.value = false;
                  ctrl.startHideTimer();
                },
                onContinue: () {
                  ctrl.toggleCommentsAutoPlay();
                  ctrl.startHideTimer();
                },
                continueLabel: ctrl.isCommentsAutoPlay.value ? 'Pause' : 'Play',
              ),
            ),
            Expanded(
              child: Obx(() {
                ctrl.showCommentsPopup.value;
                if (!hasCommentsCtrl) {
                  return const Center(
                    child: Text(
                      'Comments not initialized',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                final commentsController = Get.find<CommentsController>(
                  tag: tag,
                );

                if (commentsController.isLoadingComments.value &&
                    commentsController.comments.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: 4,
                    itemBuilder: (context, index) => const ShimmerCommentCard(),
                  );
                }

                if (commentsController.commentsError.value != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: ${commentsController.commentsError.value}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  );
                }

                if (commentsController.comments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: commentsController.comments.length,
                  itemBuilder: (context, index) {
                    final comment = commentsController.comments[index];
                    return FullscreenCommentItem(
                      comment: comment,
                      controller: commentsController,
                    );
                  },
                );
              }),
            ),
            if (hasCommentsCtrl)
              FullscreenCommentInput(
                commentsController: Get.find<CommentsController>(tag: tag),
              ),
          ],
        ),
      ),
    );
  }
}

class FullscreenCommentItem extends StatelessWidget {
  const FullscreenCommentItem({
    required this.comment,
    required this.controller,
    super.key,
  });
  final Comment comment;
  final CommentsController controller;

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = controller.isCommentLikedByUser(comment);
    final isDisliked = controller.isCommentDislikedByUser(comment);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          ClipOval(
            child: comment.avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: comment.avatarUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 32,
                    height: 32,
                    color: AppColors.textSecondary,
                    child: const Icon(
                      Icons.person,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Comment Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username + Date
                Row(
                  children: [
                    Expanded(
                      child: comment.id.startsWith('sponsor_ad_')
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    comment.displayName,
                                    style: const TextStyle(
                                      color: AppColors.bgPage,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 11,
                                  color: AppColors.warning,
                                ),
                              ],
                            )
                          : Text(
                              comment.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Comment text
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                // Interactions: Like / Dislike
                Row(
                  children: [
                    // Like button
                    InkWell(
                      onTap: () => controller.toggleCommentLike(
                        commentId: comment.id,
                        likeAsChannel: false,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_outlined,
                              size: 14,
                              color: isLiked
                                  ? PT.primary
                                  : AppColors.textSecondary,
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likeCount}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dislike button
                    InkWell(
                      onTap: () => controller.toggleCommentDislike(
                        commentId: comment.id,
                        dislikeAsChannel: false,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isDisliked
                              ? Icons.thumb_down_rounded
                              : Icons.thumb_down_outlined,
                          size: 14,
                          color: isDisliked
                              ? PT.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullscreenCommentInput extends StatefulWidget {
  const FullscreenCommentInput({required this.commentsController, super.key});
  final CommentsController commentsController;

  @override
  State<FullscreenCommentInput> createState() => _FullscreenCommentInputState();
}

class _FullscreenCommentInputState extends State<FullscreenCommentInput> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final RxBool _isSubmitting = false.obs;

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final validation = ContentValidator.validate(
      text,
      fieldName: 'Comment',
      maxLength: 1000,
    );
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    _isSubmitting.value = true;
    try {
      if (!AuthService.to.isAuthenticated.value) {
        throw Exception('Please sign in to comment');
      }
      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final shouldPostAsChannel = hasChannel;
      final targetChannelId = shouldPostAsChannel ? channel?.id : null;
      final targetChannelName = shouldPostAsChannel
          ? (channel?.handle.isNotEmpty ?? false
                ? channel?.handle
                : channel?.name)
          : null;
      final targetChannelAvatar = shouldPostAsChannel
          ? channel?.avatarUrl
          : null;
      final targetUserAvatar = AuthService.to.activePhotoUrl;

      await widget.commentsController.submitComment(
        text: text,
        channelId: targetChannelId,
        channelName: targetChannelName,
        channelProfilePicUrl: targetChannelAvatar,
        userProfilePicUrl: targetUserAvatar,
      );
      _textCtrl.clear();
      _focusNode.unfocus();
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to post comment. Please try again.');
    } finally {
      _isSubmitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final authService = AuthService.to;
      if (!authService.isAuthenticated.value) {
        return Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black26,
          child: Center(
            child: TextButton.icon(
              onPressed: authService.signInWithGoogle,
              icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Sign in to comment',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }

      final photoUrl = authService.activePhotoUrl;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.3),
          border: Border(
            top: BorderSide(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            ClipOval(
              child: photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 28,
                      height: 28,
                      color: AppColors.textSecondary,
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                inputFormatters: TruthworldTextInputFormatters.standard,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              if (_isSubmitting.value) {
                return SizedBox(
                  width: 20,
                  height: 20,
                  child: Shimmer.fromColors(
                    baseColor: PT.primary.withValues(alpha: 0.3),
                    highlightColor: PT.primary,
                    child: const Icon(
                      Icons.send_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                );
              } else {
                return IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: PT.primary,
                    size: 20,
                  ),
                  onPressed: _submit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                );
              }
            }),
          ],
        ),
      );
    });
  }
}

class FloatingAutoPlayCommentOverlay extends StatelessWidget {
  const FloatingAutoPlayCommentOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!ctrl.isCommentsAutoPlay.value) return const SizedBox.shrink();
      final comment = ctrl.currentAutoPlayComment.value;
      if (comment == null) return const SizedBox.shrink();

      final hasChannel =
          comment.channelName != null && comment.channelName!.trim().isNotEmpty;
      final authorHandle = hasChannel
          ? (comment.channelName!.startsWith('@')
                ? comment.channelName!
                : '@${comment.channelName}')
          : comment.userName;

      return Positioned(
        top: ctrl.isFullScreen.value ? 48 : 16,
        left: 20,
        right: 20,
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              // Tap floating comment opens comments section
              ctrl.showCommentsPopup.value = true;
              ctrl.startHideTimer();
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgPage.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Author avatar
                  ClipOval(
                    child: comment.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: comment.avatarUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 28,
                            height: 28,
                            color: AppColors.textSecondary,
                            child: const Icon(
                              Icons.person,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Comment text & author
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          authorHandle,
                          style: TextStyle(
                            color: hasChannel
                                ? AppColors.brandHover
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          comment.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
