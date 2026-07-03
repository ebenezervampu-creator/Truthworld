import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller_v2.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/player_settings_panels.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';

class CommentsOverlay extends StatelessWidget {
  final TowerPlayerController ctrl;
  const CommentsOverlay({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final tag = 'video_${ctrl.tag}';
    final hasCommentsCtrl = Get.isRegistered<CommentsControllerV2>(tag: tag);

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
            PanelHeader(
              title: 'Comments',
              onBack: null,
              onClose: () {
                ctrl.showCommentsPopup.value = false;
                ctrl.startHideTimer();
              },
            ),
            Expanded(
              child: Obx(() {
                if (!hasCommentsCtrl) {
                  return const Center(
                    child: Text(
                      'Comments not initialized',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final commentsController = Get.find<CommentsControllerV2>(
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
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: ${commentsController.commentsError.value}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }

                if (commentsController.comments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
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
                commentsController: Get.find<CommentsControllerV2>(tag: tag),
              ),
          ],
        ),
      ),
    );
  }
}

class FullscreenCommentItem extends StatelessWidget {
  final Comment comment;
  final CommentsControllerV2 controller;
  const FullscreenCommentItem({
    super.key,
    required this.comment,
    required this.controller,
  });

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
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.white38,
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
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    comment.displayName,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 11,
                                  color: Colors.amber,
                                ),
                              ],
                            )
                          : Text(
                              comment.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
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
                    color: Colors.white,
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
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_outlined,
                              size: 14,
                              color: isLiked ? PT.primary : Colors.white54,
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likeCount}',
                                style: const TextStyle(
                                  color: Colors.white54,
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
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isDisliked
                              ? Icons.thumb_down_rounded
                              : Icons.thumb_down_outlined,
                          size: 14,
                          color: isDisliked ? PT.primary : Colors.white54,
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
  final CommentsControllerV2 commentsController;
  const FullscreenCommentInput({super.key, required this.commentsController});

  @override
  State<FullscreenCommentInput> createState() => _FullscreenCommentInputState();
}

class _FullscreenCommentInputState extends State<FullscreenCommentInput> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _isSubmitting = false.obs;

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _isSubmitting.value = true;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Please sign in to comment');
      }
      await widget.commentsController.submitComment(
        text: text,
        userProfilePicUrl: currentUser.photoURL ?? '',
      );
      _textCtrl.clear();
      _focusNode.unfocus();
    } catch (e) {
      AppSnackbar.show(
        'Error',
        'Failed to post comment: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isSubmitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.black26,
        child: const Center(
          child: Text(
            'Sign in to comment',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          ClipOval(
            child:
                currentUser.photoURL != null && currentUser.photoURL!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: currentUser.photoURL!,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 28,
                    height: 28,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
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
                    color: Colors.white,
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
  }
}
