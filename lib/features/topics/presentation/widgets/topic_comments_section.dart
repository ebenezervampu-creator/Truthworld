import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

class TopicCommentsSection extends StatefulWidget {
  final Topic topic;

  const TopicCommentsSection({super.key, required this.topic});

  @override
  State<TopicCommentsSection> createState() => _TopicCommentsSectionState();
}

class _TopicCommentsSectionState extends State<TopicCommentsSection> {
  final Rxn<TopicInteractionController> _controller = Rxn<TopicInteractionController>();
  final RxBool isSortNewest = true.obs;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant TopicCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topic.id != oldWidget.topic.id) {
      _initializeController();
    }
  }

  void _initializeController() {
    final TopicInteractionController currentController;
    if (Get.isRegistered<TopicInteractionController>(tag: widget.topic.id)) {
      currentController = Get.find<TopicInteractionController>(tag: widget.topic.id);
    } else {
      currentController = Get.put(TopicInteractionController(), tag: widget.topic.id);
    }
    currentController.initializeTopic(widget.topic);
    _controller.value = currentController;
  }

  List<Comment> _getSortedComments(List<Comment> rawComments) {
    final list = List<Comment>.from(rawComments);
    if (isSortNewest.value) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }
    return list;
  }

  void _navigateToChannel(String? channelId) async {
    if (channelId == null || channelId.isEmpty) return;
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        barrierDismissible: false,
      );
      final doc = await FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .get();
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        Get.offAndToNamed(channel.channelRoute, arguments: {'channel': channel});
      } else {
        Get.snackbar('Error', 'Channel not found');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      debugPrint('Error navigating to channel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1000;
    final isDesktop = size.width >= 1000;
    final theme = Theme.of(context);

    return Obx(() {
      final controller = _controller.value;
      if (controller == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          ),
        );
      }

      final commentCount = controller.commentCount.value;
      final rawComments = controller.comments;
      final sortedComments = _getSortedComments(rawComments);

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comments Header & Sort Option Row
            Row(
              children: [
                Text(
                  '$commentCount ${commentCount == 1 ? 'Comment' : 'Comments'}',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 24),
                PopupMenuButton<bool>(
                  onSelected: (bool newest) {
                    isSortNewest.value = newest;
                  },
                  offset: const Offset(0, 30),
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<bool>>[
                    PopupMenuItem<bool>(
                      value: false,
                      child: Obx(() {
                        final isSelected = !isSortNewest.value;
                        return Row(
                          children: [
                            Icon(
                              Icons.check, 
                              size: 18, 
                              color: isSelected ? Colors.white : Colors.transparent,
                            ),
                            const SizedBox(width: 8),
                            const Text('Top comments'),
                          ],
                        );
                      }),
                    ),
                    PopupMenuItem<bool>(
                      value: true,
                      child: Obx(() {
                        final isSelected = isSortNewest.value;
                        return Row(
                          children: [
                            Icon(
                              Icons.check, 
                              size: 18, 
                              color: isSelected ? Colors.white : Colors.transparent,
                            ),
                            const SizedBox(width: 8),
                            const Text('Newest first'),
                          ],
                        );
                      }),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sort_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sort by',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Comment Input
            PremiumCommentInput(
              videoId: widget.topic.id,
              onSubmit: (text, postAsChannel, channelId) async {
                await controller.addComment(widget.topic.id, text);
              },
            ),
            const SizedBox(height: 24),

            // Loading/Empty/List Comments
            if (controller.isLoadingComments.value)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: theme.colorScheme.primary),
                ),
              )
            else if (sortedComments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No comments yet. Start the conversation!',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedComments.length,
                itemBuilder: (context, index) {
                  final comment = sortedComments[index];
                  return TopicCommentItemWidget(
                    comment: comment,
                    topicId: widget.topic.id,
                    controller: controller,
                    theme: theme,
                    isMobile: isMobile,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    onNavigateToChannel: _navigateToChannel,
                  );
                },
              ),
          ],
        ),
      );
    });
  }
}

class TopicCommentItemWidget extends StatefulWidget {
  final Comment comment;
  final String topicId;
  final TopicInteractionController controller;
  final ThemeData theme;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final Function(String?) onNavigateToChannel;

  const TopicCommentItemWidget({
    super.key,
    required this.comment,
    required this.topicId,
    required this.controller,
    required this.theme,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.onNavigateToChannel,
  });

  @override
  State<TopicCommentItemWidget> createState() => _TopicCommentItemWidgetState();
}

class _TopicCommentItemWidgetState extends State<TopicCommentItemWidget> {
  final RxBool isReplying = false.obs;
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

  void _submitReply() async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;

    final commentId = widget.comment.id;
    if (commentId.isEmpty) return;

    if (FirebaseAuth.instance.currentUser == null) {
      Get.snackbar('Sign in required', 'Please sign in to reply');
      return;
    }

    try {
      await widget.controller.addReply(widget.topicId, commentId, text);
      replyController.clear();
      isReplying.value = false;
      Get.snackbar('Success', 'Reply posted');
    } catch (e) {
      debugPrint('Error posting reply: $e');
      Get.snackbar('Error', 'Failed to post reply');
    }
  }

  void _showCommentOptions(BuildContext context, Comment comment, TopicInteractionController controller) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == comment.userId;

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
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    controller.deleteComment(widget.topicId, comment.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text('Report', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Get.snackbar('Reported', 'Thank you for your report.');
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
    final String userName = comment.displayName;
    final String formattedUserName = userName.startsWith('@') ? userName : '@$userName';
    final String text = comment.text;
    final Timestamp createdAt = comment.createdAt;
    final String userProfilePicUrl = comment.avatarUrl;
    final int likeCount = comment.likeCount;
    final String commentId = comment.id;

    return Obx(() {
      final isLiked = comment.isLikedByCurrentUser;
      final isDisliked = comment.isDislikedByCurrentUser;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => widget.onNavigateToChannel(comment.channelId),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: UserAvatar(
                      radius: 20,
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
                            onTap: () => widget.onNavigateToChannel(comment.channelId),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
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
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.controller.toggleCommentLike(widget.topicId, comment.id);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: isLiked ? Colors.white : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                if (likeCount > 0)
                                  Text(
                                    '$likeCount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLiked ? Colors.white : Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.controller.toggleCommentDislike(widget.topicId, comment.id);
                            },
                            child: Icon(
                              isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                              size: 16,
                              color: isDisliked ? Colors.white : Colors.grey.shade400,
                            ),
                          ),
                          if (comment.isHeartedByCreator) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Hearted by ${comment.creatorHeartName ?? 'Creator'}',
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
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && replyFocusNode.canRequestFocus) {
                                    FocusScope.of(context).requestFocus(replyFocusNode);
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
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 18),
                  onPressed: () => _showCommentOptions(context, comment, widget.controller),
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
                        decoration: InputDecoration(
                          hintText: 'Add a reply...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade800,
                              width: 1.0,
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
                              width: 1.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.white),
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
                      icon: Obx(() => Icon(
                            Icons.send,
                            size: 20,
                            color: replyText.value.isNotEmpty ? Colors.blue : Colors.grey,
                          )),
                    ),
                  ],
                ),
              ),
            if (commentId.isNotEmpty)
              TopicRepliesSection(
                commentId: comment.id,
                topicId: widget.topicId,
                controller: widget.controller,
                theme: widget.theme,
                isMobile: widget.isMobile,
                isTablet: widget.isTablet,
                isDesktop: widget.isDesktop,
                onNavigateToChannel: widget.onNavigateToChannel,
              ),
          ],
        ),
      );
    });
  }
}

class TopicRepliesSection extends StatefulWidget {
  final String commentId;
  final String topicId;
  final TopicInteractionController controller;
  final ThemeData theme;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final Function(String?) onNavigateToChannel;

  const TopicRepliesSection({
    super.key,
    required this.commentId,
    required this.topicId,
    required this.controller,
    required this.theme,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.onNavigateToChannel,
  });

  @override
  State<TopicRepliesSection> createState() => _TopicRepliesSectionState();
}

class _TopicRepliesSectionState extends State<TopicRepliesSection> {
  final RxBool _isRepliesExpanded = false.obs;

  @override
  Widget build(BuildContext context) {
    final repliesRef = FirebaseFirestore.instance
        .collection('topics')
        .doc(widget.topicId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!.docs
            .map((doc) => Reply.fromDocumentSnapshot(doc))
            .toList();

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
                      branchY: 18.0,
                    ),
                  ),
                  UserAvatar(
                    radius: 10,
                    photoUrl: firstReply.avatarUrl,
                    displayName: firstReply.displayName,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    replies.length == 1 ? '• 1 reply' : '• ${replies.length} replies',
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

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomPaint(
                        size: const Size(40, double.infinity),
                        painter: ReplyThreadLinePainter(
                          color: Colors.white24,
                          isLast: isLastReply,
                          branchY: 20.0,
                        ),
                      ),
                      Expanded(
                        child: TopicReplyItemWidget(
                          reply: reply,
                          commentId: widget.commentId,
                          topicId: widget.topicId,
                          controller: widget.controller,
                          theme: widget.theme,
                          isMobile: widget.isMobile,
                          isTablet: widget.isTablet,
                          isDesktop: widget.isDesktop,
                          onNavigateToChannel: widget.onNavigateToChannel,
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
                        branchY: 18.0,
                      ),
                    ),
                    const Text(
                      '• Hide replies',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 13,
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

class TopicReplyItemWidget extends StatelessWidget {
  final Reply reply;
  final String commentId;
  final String topicId;
  final TopicInteractionController controller;
  final ThemeData theme;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final Function(String?) onNavigateToChannel;

  const TopicReplyItemWidget({
    super.key,
    required this.reply,
    required this.commentId,
    required this.topicId,
    required this.controller,
    required this.theme,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.onNavigateToChannel,
  });

  void _showReplyOptions(BuildContext context, Reply reply, TopicInteractionController controller) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == reply.userId;

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
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    controller.deleteReply(topicId, commentId, reply.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text('Report', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Get.snackbar('Reported', 'Thank you for your report.');
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
    final avatarRadius = 12.0;

    final formattedUserName = reply.displayName.startsWith('@') ? reply.displayName : '@${reply.displayName}';

    return Obx(() {
      final interaction = controller.userReplyInteractions[reply.id] ?? {'isLiked': false, 'isDisliked': false};
      final isLiked = interaction['isLiked'] ?? false;
      final isDisliked = interaction['isDisliked'] ?? false;

      return Container(
        padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16, left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            GestureDetector(
              onTap: () => onNavigateToChannel(reply.channelId),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: UserAvatar(
                  radius: avatarRadius,
                  photoUrl: reply.avatarUrl,
                  displayName: reply.displayName,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => onNavigateToChannel(reply.channelId),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Text(
                            formattedUserName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeago.format(reply.createdAt.toDate()),
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

                  // Action Row (Like / Dislike)
                  Row(
                    children: [
                      // Like
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 14,
                          color: isLiked ? Colors.white : Colors.grey.shade400,
                        ),
                        onPressed: () {
                          if (FirebaseAuth.instance.currentUser == null) {
                            Get.snackbar('Authentication Required', 'Please sign in to react.');
                            return;
                          }
                          HapticFeedback.lightImpact();
                          controller.toggleReplyLike(topicId, commentId, reply.id);
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      if (reply.likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${reply.likeCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),

                      // Dislike
                      IconButton(
                        icon: Icon(
                          isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                          size: 14,
                          color: isDisliked ? Colors.white : Colors.grey.shade400,
                        ),
                        onPressed: () {
                          if (FirebaseAuth.instance.currentUser == null) {
                            Get.snackbar('Authentication Required', 'Please sign in to react.');
                            return;
                          }
                          HapticFeedback.lightImpact();
                          controller.toggleReplyDislike(topicId, commentId, reply.id);
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      if (reply.dislikeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${reply.dislikeCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 16),
              onPressed: () => _showReplyOptions(context, reply, controller),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }
}

class ReplyThreadLinePainter extends CustomPainter {
  final Color color;
  final bool isLast;
  final double branchY;

  ReplyThreadLinePainter({
    required this.color,
    required this.isLast,
    required this.branchY,
  });

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
