import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class CommentItemWidget extends StatefulWidget {
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
  State<CommentItemWidget> createState() => CommentItemWidgetState();
}

class CommentItemWidgetState extends State<CommentItemWidget> {
  final RxBool isReplying = false.obs;
  final RxBool _isRepliesExpanded = false.obs;
  final RxString replyText = ''.obs;
  final TextEditingController replyController = TextEditingController();
  final FocusNode replyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    replyController.addListener(() {
      replyText.value = replyController.text;
    });
  }

  @override
  void dispose() {
    replyController.dispose();
    replyFocusNode.dispose();
    super.dispose();
  }

  void _showSignInPrompt() {
    AppSnackbar.warning(
      'Please sign in to proceed',
      title: 'Sign In Required',
      actionLabel: 'SIGN IN',
      onAction: () => AuthService.to.signInWithGoogle(),
    );
  }

  Future<void> _submitReply() async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;

    final commentId = widget.comment.id;
    if (commentId.isEmpty) return;

    if (!AuthService.to.isAuthenticated.value) {
      _showSignInPrompt();
      return;
    }

    try {
      final tag = 'video_${widget.videoId}';
      final commentsController = Get.isRegistered<CommentsController>(tag: tag)
          ? Get.find<CommentsController>(tag: tag)
          : Get.put(CommentsController(), tag: tag);

      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final targetChannelId = hasChannel ? channel?.id : null;
      final targetChannelName = hasChannel
          ? (channel?.handle.isNotEmpty ?? false
                ? channel?.handle
                : channel?.name)
          : null;
      final targetChannelAvatar = AuthService.to.activePhotoUrl.isNotEmpty
          ? AuthService.to.activePhotoUrl
          : null;
      final targetUserAvatar = AuthService.to.activePhotoUrl;

      await commentsController.submitReply(
        commentId: commentId,
        text: text,
        channelId: targetChannelId,
        channelName: targetChannelName,
        channelProfilePicUrl: targetChannelAvatar,
        userProfilePicUrl: targetUserAvatar,
        commentAuthorId: widget.comment.userId,
      );

      replyController.clear();
      isReplying.value = false;

      AppSnackbar.success('Reply posted');
    } catch (e) {
      ErrorHandler.log(e, context: 'VideoScreen.submitReply');
      AppSnackbar.error('Unable to post reply. Please try again.');
    }
  }

  Future<void> _toggleSaveVideoComment(Comment comment, String videoId) async {
    if (!AuthService.to.isAuthenticated.value) {
      _showSignInPrompt();
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection('savedComments')
        .doc(comment.id);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        AppSnackbar.info('Comment removed from Saved Comments');
      } else {
        await docRef.set({
          'text': comment.text,
          'userName': comment.displayName,
          'userImage': comment.avatarUrl,
          'sourceType': 'video',
          'sourceId': videoId,
          'sourceTitle': 'Video',
          'savedAt': FieldValue.serverTimestamp(),
        });

        AppSnackbar.success(
          'Comment saved to Saved Comments',
          title: 'Saved',
          actionLabel: 'VIEW',
          onAction: () => Get.toNamed('/saved-comments'),
        );
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'VideoScreen.saveComment');
      AppSnackbar.error('Unable to save comment. Please try again.');
    }
  }

  void _copyCommentText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    AppSnackbar.info(
      'Comment text copied to clipboard',
      title: 'Copied',
    );
  }

  Future<void> _toggleSaveReply(Reply reply, String videoId) async {
    if (!AuthService.to.isAuthenticated.value) {
      _showSignInPrompt();
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection('savedComments')
        .doc(reply.id);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        AppSnackbar.info(
          'Reply removed from Saved Comments',
          title: 'Removed',
        );
      } else {
        await docRef.set({
          'text': reply.text,
          'userName': reply.displayName,
          'userImage': reply.avatarUrl,
          'sourceType': 'video',
          'sourceId': videoId,
          'sourceTitle': 'Video',
          'savedAt': FieldValue.serverTimestamp(),
        });

        AppSnackbar.success(
          'Reply saved to Saved Comments',
          title: 'Saved',
          actionLabel: 'VIEW',
          onAction: () => Get.toNamed('/saved-comments'),
        );
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'VideoScreen.saveReply');
      AppSnackbar.error('Unable to save reply. Please try again.');
    }
  }

  void _showCommentOptions(
    BuildContext context,
    Comment comment,
    CommentsController commentsController,
  ) {
    final isOwner = AuthService.to.isAuthenticated.value &&
        AuthService.to.uid == comment.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
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
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyCommentText(comment.text);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save comment',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSaveVideoComment(
                    comment,
                    commentsController.video?.id ?? '',
                  );
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.white),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    commentsController.deleteComment(comment.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    AppSnackbar.success('Thank you for your report.', title: 'Reported');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToChannel(String? channelId) async {
    if (channelId == null || channelId.isEmpty) return;
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        barrierDismissible: false,
      );
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .get();
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        Get.offAndToNamed(
          channel.channelRoute,
          arguments: {'channel': channel},
        );
      } else {
        AppSnackbar.warning('Channel not found');
      }
    } catch (e, stackTrace) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentItemWidgetState._navigateToChannel',
      );
      AppSnackbar.warning('Unable to open channel at this time.');
    }
  }

  void _showReplyOptions(
    BuildContext context,
    Reply reply,
    String commentId,
    CommentsController commentsController,
  ) {
    final isOwner = AuthService.to.isAuthenticated.value &&
        AuthService.to.uid == reply.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
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
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyCommentText(reply.text);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save comment',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSaveReply(reply, commentsController.video?.id ?? '');
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.white),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    commentsController.deleteReply(commentId, reply.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    AppSnackbar.success('Thank you for your report.', title: 'Reported');
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
    final comment = widget.comment;
    final userName = comment.displayName;
    final formattedUserName = userName.startsWith('@')
        ? userName
        : '@$userName';
    final text = comment.text;
    final createdAt = comment.createdAt;
    final userProfilePicUrl = comment.avatarUrl;
    final likeCount = comment.likeCount;
    final commentId = comment.id;

    final tag = 'video_${widget.videoId}';
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(), tag: tag);

    return Obx(() {
      final isLiked = commentsController.isCommentLikedByUser(comment);
      final isDisliked = commentsController.isCommentDislikedByUser(comment);

      final isTarget =
          commentsController.targetCommentId.value == comment.id &&
          commentsController.targetReplyId.value == null;

      // Automatically trigger scroll exactly once if it's the target comment
      if (isTarget && !commentsController.hasScrolledToTarget) {
        commentsController.hasScrolledToTarget = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }

      return Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _navigateToChannel(comment.channelId),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: UserAvatar(
                      photoUrl: userProfilePicUrl,
                      displayName: userName,
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToChannel(comment.channelId),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child:
                                  comment.channelId.isNotEmpty &&
                                      comment.channelId ==
                                          commentsController.video?.channelId
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            formattedUserName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(
                                      formattedUserName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(createdAt.toDate()),
                            style: TextStyle(
                              color: Colors.grey.shade500,
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
                                if (likeCount > 0)
                                  Text(
                                    '$likeCount',
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
                            onTap: () =>
                                commentsController.toggleCommentDislike(
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
                                        photoUrl: widget.channelAvatarUrl,
                                        displayName: 'Creator',
                                        fontSize: 8,
                                      ),
                                      const Positioned(
                                        bottom: -3,
                                        right: -3,
                                        child: Icon(
                                          Icons.favorite,
                                          color: Colors.red,
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
                            onTap: () {
                              isReplying.value = !isReplying.value;
                              if (isReplying.value) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted &&
                                      replyFocusNode.canRequestFocus) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(replyFocusNode);
                                  }
                                });
                              }
                            },
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
                  onPressed: () =>
                      _showCommentOptions(context, comment, commentsController),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (isReplying.value)
              Padding(
                key: ValueKey('reply_box_$commentId'),
                padding: const EdgeInsets.only(left: 52, top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        focusNode: replyFocusNode,
                        inputFormatters: TruthworldTextInputFormatters.standard,
                        decoration: InputDecoration(
                          hintText: 'Add a reply...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade800,
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade800,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitReply(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        isReplying.value = false;
                        replyController.clear();
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white70,
                      ),
                    ),
                    IconButton(
                      onPressed: _submitReply,
                      icon: Obx(
                        () => Icon(
                          Icons.send,
                          size: 20,
                          color: replyText.value.isNotEmpty
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (commentId.isNotEmpty) _buildRepliesList(commentId, comment),
          ],
        ),
      );
    });
  }

  Widget _buildRepliesList(String commentId, Comment parentComment) {
    final tag = 'video_${widget.videoId}';
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(), tag: tag);

    return StreamBuilder<List<Reply>>(
      stream: widget.mainController.getRepliesStream(widget.videoId, commentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
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
          if (hasTargetReply && !_isRepliesExpanded.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isRepliesExpanded.value = true;
            });
          }
        }

        return Obx(() {
          final isExpanded = _isRepliesExpanded.value;

          if (!isExpanded) {
            final firstReply = replies.first;
            return InkWell(
              onTap: () => _isRepliesExpanded.value = true,
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
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more,
                    color: Colors.blue,
                    size: 16,
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(replies.length, (index) {
                final reply = replies[index];
                final isLastReply = index == replies.length - 1;
                final isReplyLiked = commentsController.isReplyLikedByUser(
                  reply.id,
                );
                final isReplyDisliked = commentsController
                    .isReplyDislikedByUser(reply.id);

                final isReplyTarget =
                    commentsController.targetReplyId.value == reply.id;

                // Automatically trigger scroll exactly once if it's the target reply
                if (isReplyTarget && !commentsController.hasScrolledToTarget) {
                  commentsController.hasScrolledToTarget = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Scrollable.ensureVisible(
                        context,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                }

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
                          decoration: isReplyTarget
                              ? BoxDecoration(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.08,
                                  ),
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
                                onTap: () =>
                                    _navigateToChannel(reply.channelId),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
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
                                          onTap: () => _navigateToChannel(
                                            reply.channelId,
                                          ),
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child:
                                                reply.channelId.isNotEmpty &&
                                                    reply.channelId ==
                                                        commentsController
                                                            .video
                                                            ?.channelId
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 1.5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          reply.displayName
                                                                  .startsWith(
                                                                    '@',
                                                                  )
                                                              ? reply
                                                                    .displayName
                                                              : '@${reply.displayName}',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        const Icon(
                                                          Icons.check,
                                                          size: 11,
                                                          color: Colors.white70,
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Text(
                                                    reply.displayName
                                                            .startsWith('@')
                                                        ? reply.displayName
                                                        : '@${reply.displayName}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          timeago.format(
                                            reply.createdAt.toDate(),
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reply.text,
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
                                          onTap: () => commentsController
                                              .toggleReplyLike(
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
                                          onTap: () => commentsController
                                              .toggleReplyDislike(
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
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                ),
                                onPressed: () => _showReplyOptions(
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
              }),
              InkWell(
                onTap: () => _isRepliesExpanded.value = false,
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
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_less,
                      color: Colors.blue,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class ReplyThreadLinePainter extends CustomPainter {
  ReplyThreadLinePainter({
    required this.color,
    required this.isLast,
    required this.branchY,
  });
  final Color color;
  final bool isLast;
  final double branchY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    if (isLast) {
      path.moveTo(20, 0);
      path.lineTo(20, branchY - 8);
      path.quadraticBezierTo(20, branchY, 28, branchY);
      path.lineTo(size.width, branchY);
    } else {
      path.moveTo(20, 0);
      path.lineTo(20, size.height);
      path.moveTo(20, branchY);
      path.lineTo(size.width, branchY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ReplyThreadLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isLast != isLast ||
        oldDelegate.branchY != branchY;
  }
}
