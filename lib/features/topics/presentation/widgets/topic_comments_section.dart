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
  late final TopicInteractionController controller;
  final RxBool isSortNewest = true.obs;

  @override
  void initState() {
    super.initState();

    // Retrieve or initialize the controller for this topic
    if (Get.isRegistered<TopicInteractionController>(tag: widget.topic.id)) {
      controller = Get.find<TopicInteractionController>(tag: widget.topic.id);
    } else {
      controller = Get.put(TopicInteractionController(), tag: widget.topic.id);
    }
    
    // Always initialize the topic when entering the comments section
    controller.initializeTopic(widget.topic);
  }

  @override
  void didUpdateWidget(covariant TopicCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topic.id != oldWidget.topic.id) {
      late final TopicInteractionController newController;
      if (Get.isRegistered<TopicInteractionController>(tag: widget.topic.id)) {
        newController = Get.find<TopicInteractionController>(tag: widget.topic.id);
      } else {
        newController = Get.put(TopicInteractionController(), tag: widget.topic.id);
      }
      setState(() {
        controller = newController;
      });
      controller.initializeTopic(widget.topic);
    }
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : (isTablet ? 16 : 20),
                    vertical: isMobile ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      isMobile ? 20 : (isTablet ? 24 : 28),
                    ),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: isMobile ? 16 : (isTablet ? 18 : 20),
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: isMobile ? 6 : (isTablet ? 8 : 10)),
                      Text(
                        '$commentCount ${commentCount == 1 ? 'Comment' : 'Comments'}',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<bool>(
                  initialValue: isSortNewest.value,
                  onSelected: (value) => isSortNewest.value = value,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sort_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        isSortNewest.value ? 'Newest first' : 'Top comments',
                        style: GoogleFonts.roboto(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: false,
                      child: Text('Top comments', style: TextStyle(color: theme.colorScheme.onSurface)),
                    ),
                    PopupMenuItem(
                      value: true,
                      child: Text('Newest first', style: TextStyle(color: theme.colorScheme.onSurface)),
                    ),
                  ],
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

class _TopicCommentItemWidgetState extends State<TopicCommentItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  final RxBool _isHovered = false.obs;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    if (widget.isDesktop) {
      _isHovered.value = isHovered;
      if (isHovered) {
        _hoverController.forward();
      } else {
        _hoverController.reverse();
      }
    }
  }

  void _showReplyInput(BuildContext context, String commentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: widget.theme.colorScheme.shadow.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Replying',
                        style: GoogleFonts.roboto(
                          textStyle: widget.theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: widget.theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => Get.back(),
                        iconSize: 20,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                PremiumCommentInput(
                  videoId: commentId,
                  isReply: true,
                  onSubmit: (text, postAsChannel, channelId) async {
                    await widget.controller.addReply(widget.topicId, commentId, text);
                    Get.back();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final userName = comment.displayName;

    final avatarRadius = widget.isMobile
        ? 18.0
        : widget.isTablet
            ? 20.0
            : 22.0;

    final horizontalPadding = widget.isMobile
        ? 16.0
        : widget.isTablet
            ? 20.0
            : 24.0;
    final verticalPadding = widget.isMobile
        ? 16.0
        : widget.isTablet
            ? 20.0
            : 24.0;

    return AnimatedBuilder(
      animation: _hoverAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _hoverAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: Obx(() {
              final isHovered = _isHovered.value;
              final isLiked = comment.isLikedByCurrentUser;
              final isDisliked = comment.isDislikedByCurrentUser;

              return Container(
                margin: EdgeInsets.symmetric(
                  vertical: verticalPadding / 2,
                ),
                padding: EdgeInsets.all(
                  widget.isMobile
                      ? 16
                      : widget.isTablet
                      ? 20
                      : 24,
                ),
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(
                    widget.isMobile
                        ? 16
                        : widget.isTablet
                        ? 20
                        : 24,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.theme.colorScheme.shadow.withValues(
                        alpha: isHovered ? 0.15 : 0.08,
                      ),
                      blurRadius: isHovered ? 16 : 8,
                      offset: Offset(0, isHovered ? 6 : 2),
                    ),
                  ],
                  border: Border.all(
                    color: widget.theme.colorScheme.outline.withValues(
                      alpha: isHovered ? 0.3 : 0.1,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () => widget.onNavigateToChannel(comment.channelId),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  widget.theme.colorScheme.primary.withValues(alpha: 0.2),
                                  widget.theme.colorScheme.primary.withValues(alpha: 0.1),
                                ],
                              ),
                              border: Border.all(
                                color: widget.theme.colorScheme.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: UserAvatar(
                              radius: avatarRadius,
                              photoUrl: comment.avatarUrl,
                              displayName: userName,
                              backgroundColor: Colors.transparent,
                              textColor: widget.theme.colorScheme.primary,
                              fontSize: widget.isMobile
                                  ? 14
                                  : widget.isTablet
                                  ? 16
                                  : 18,
                              showBorder: false,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: widget.isMobile
                              ? 12
                              : widget.isTablet
                              ? 16
                              : 20,
                        ),

                        // Content details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => widget.onNavigateToChannel(comment.channelId),
                                    child: Text(
                                      userName,
                                      style: GoogleFonts.roboto(
                                        fontWeight: FontWeight.w500,
                                        fontSize: widget.isMobile ? 13 : (widget.isTablet ? 14 : 15),
                                        color: widget.theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: widget.isMobile
                                        ? 8
                                        : widget.isTablet
                                        ? 10
                                        : 12,
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: widget.isMobile
                                          ? 6
                                          : widget.isTablet
                                          ? 8
                                          : 10,
                                      vertical: widget.isMobile
                                          ? 2
                                          : widget.isTablet
                                          ? 3
                                          : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(
                                        widget.isMobile
                                            ? 8
                                            : widget.isTablet
                                            ? 10
                                            : 12,
                                      ),
                                    ),
                                    child: Text(
                                      timeago.format(comment.createdAt.toDate()),
                                      style: GoogleFonts.roboto(
                                        color: widget.theme.colorScheme.onSurfaceVariant,
                                        fontSize: widget.isMobile
                                            ? 11
                                            : widget.isTablet
                                            ? 12
                                            : 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: widget.isMobile
                                    ? 8
                                    : widget.isTablet
                                    ? 10
                                    : 12,
                              ),
                              Text(
                                comment.text,
                                style: GoogleFonts.roboto(
                                  fontSize: widget.isMobile ? 14 : (widget.isTablet ? 15 : 16),
                                  color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(
                                height: widget.isMobile
                                    ? 12
                                    : widget.isTablet
                                    ? 14
                                    : 16,
                              ),

                              // Like / Dislike / Reply Row
                              Row(
                                children: [
                                  // Like
                                  IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                      size: 18,
                                      color: widget.theme.colorScheme.onSurface,
                                    ),
                                    onPressed: () {
                                      if (FirebaseAuth.instance.currentUser == null) {
                                        Get.snackbar('Authentication Required', 'Please sign in to react.');
                                        return;
                                      }
                                      HapticFeedback.lightImpact();
                                      widget.controller.toggleCommentLike(widget.topicId, comment.id);
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  if (comment.likeCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${comment.likeCount}',
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        color: widget.theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 16),

                                  // Dislike
                                  IconButton(
                                    icon: Icon(
                                      isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                                      size: 18,
                                      color: widget.theme.colorScheme.onSurface,
                                    ),
                                    onPressed: () {
                                      if (FirebaseAuth.instance.currentUser == null) {
                                        Get.snackbar('Authentication Required', 'Please sign in to react.');
                                        return;
                                      }
                                      HapticFeedback.lightImpact();
                                      widget.controller.toggleCommentDislike(widget.topicId, comment.id);
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  if (comment.dislikeCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${comment.dislikeCount}',
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        color: widget.theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(width: 16),
                                  // Creator Heart Avatar Badge (if applicable)
                                  if (comment.isHeartedByCreator)
                                    Stack(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black, width: 1),
                                          ),
                                          child: UserAvatar(
                                            radius: 12,
                                            photoUrl: comment.avatarUrl,
                                            displayName: userName,
                                            backgroundColor: widget.theme.colorScheme.surface,
                                            fontSize: 12,
                                            showBorder: false,
                                          ),
                                        ),
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(1),
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.favorite,
                                              size: 10,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                  const SizedBox(width: 16),
                                  InkWell(
                                    onTap: () {
                                      if (FirebaseAuth.instance.currentUser == null) {
                                        Get.snackbar('Authentication Required', 'Please sign in to reply.');
                                        return;
                                      }
                                      HapticFeedback.lightImpact();
                                      _showReplyInput(context, comment.id);
                                    },
                                    child: Text(
                                      'Reply',
                                      style: GoogleFonts.roboto(
                                        color: widget.theme.colorScheme.onSurface,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                    SizedBox(
                      height: widget.isMobile
                          ? 12
                          : widget.isTablet
                          ? 16
                          : 20,
                    ),
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
            }),
          ),
        );
      },
    );
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

class _TopicRepliesSectionState extends State<TopicRepliesSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  final RxBool _isExpanded = false.obs;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

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

        return Stack(
          children: [
            // L-shaped connecting line
            Positioned(
              left: widget.isMobile ? -15 : -20,
              top: -10,
              bottom: 12,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    height: 2,
                    width: 15,
                    color: widget.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(
                left: widget.isMobile ? 10 : 20,
                top: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      _isExpanded.value = !_isExpanded.value;
                      if (_isExpanded.value) {
                        _expansionController.forward();
                      } else {
                        _expansionController.reverse();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Obx(() {
                        final isExpanded = _isExpanded.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Small Creator Avatar placeholder (topic avatar if available, otherwise default)
                            UserAvatar(
                              radius: 10,
                              photoUrl: '', // Topic comments replies toggle uses default fallback
                              displayName: 'Topic Creator',
                              backgroundColor: widget.theme.colorScheme.primary.withValues(alpha: 0.2),
                              fontSize: 10,
                              showBorder: false,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                              style: GoogleFonts.roboto(
                                color: widget.theme.colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: widget.theme.colorScheme.primary,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  SizeTransition(
                    sizeFactor: _expansionAnimation,
                    child: Container(
                      margin: EdgeInsets.only(
                        top: widget.isMobile
                            ? 12
                            : widget.isTablet
                            ? 16
                            : 20,
                      ),
                      child: Column(
                        children: replies.map((reply) {
                          return TopicReplyItemWidget(
                            reply: reply,
                            commentId: widget.commentId,
                            topicId: widget.topicId,
                            controller: widget.controller,
                            theme: widget.theme,
                            isMobile: widget.isMobile,
                            isTablet: widget.isTablet,
                            isDesktop: widget.isDesktop,
                            onNavigateToChannel: widget.onNavigateToChannel,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
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

  @override
  Widget build(BuildContext context) {
    final avatarRadius = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;

    final formattedUserName = reply.userName;

    return Obx(() {
      final interaction = controller.userReplyInteractions[reply.id] ?? {'isLiked': false, 'isDisliked': false};
      final isLiked = interaction['isLiked'] ?? false;
      final isDisliked = interaction['isDisliked'] ?? false;

      return Container(
        margin: EdgeInsets.only(
          bottom: isMobile
              ? 12
              : isTablet
              ? 16
              : 20,
        ),
        padding: EdgeInsets.all(
          isMobile
              ? 12
              : isTablet
              ? 16
              : 20,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(
            isMobile
                ? 12
                : isTablet
                ? 16
                : 20,
          ),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            GestureDetector(
              onTap: () => onNavigateToChannel(reply.channelId),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.secondary.withValues(alpha: 0.2),
                      theme.colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: UserAvatar(
                  radius: avatarRadius,
                  photoUrl: reply.userProfilePicUrl,
                  displayName: reply.userName,
                  backgroundColor: Colors.transparent,
                  textColor: theme.colorScheme.secondary,
                  fontSize: isMobile
                      ? 10
                      : isTablet
                      ? 12
                      : 14,
                  showBorder: false,
                ),
              ),
            ),
            SizedBox(
              width: isMobile
                  ? 10
                  : isTablet
                  ? 12
                  : 16,
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => onNavigateToChannel(reply.channelId),
                        child: Text(
                          formattedUserName,
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile
                                ? 12
                                : isTablet
                                ? 13
                                : 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? 6
                            : isTablet
                            ? 8
                            : 10,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile
                              ? 4
                              : isTablet
                              ? 6
                              : 8,
                          vertical: isMobile
                              ? 2
                              : isTablet
                              ? 3
                              : 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(
                            isMobile
                                ? 6
                                : isTablet
                                ? 8
                                : 10,
                          ),
                        ),
                        child: Text(
                          timeago.format(reply.createdAt.toDate()),
                          style: GoogleFonts.roboto(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: isMobile
                                ? 10
                                : isTablet
                                ? 11
                                : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.text,
                    style: GoogleFonts.roboto(
                      fontSize: isMobile ? 13 : 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Action Row (Like / Dislike)
                  Row(
                    children: [
                      // Like
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface,
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
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),

                      // Dislike
                      IconButton(
                        icon: Icon(
                          isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface,
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
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
