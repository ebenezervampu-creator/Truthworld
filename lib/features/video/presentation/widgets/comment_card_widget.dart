import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/animated_interaction_buttons.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Professional Comment Card Widget (Industry Standard)
/// Displays a single comment with like/dislike/reply functionality
class CommentCardWidget extends StatefulWidget {
  const CommentCardWidget({
    required this.comment,
    required this.onLike,
    required this.onDislike,
    required this.onReply,
    required this.isLiked,
    required this.isDisliked,
    required this.isCreatorComment,
    super.key,
    this.onShowReplies,
    this.replyCount = 0,
  });
  final Comment comment;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onReply;
  final bool isLiked;
  final bool isDisliked;
  final bool isCreatorComment;
  final VoidCallback? onShowReplies;
  final int replyCount;

  @override
  State<CommentCardWidget> createState() => _CommentCardWidgetState();
}

class _CommentCardWidgetState extends State<CommentCardWidget> {
  @override
  Widget build(BuildContext context) {
    final isDonated =
        widget.comment.isDonatedComment || widget.comment.donationAmount > 0;
    final donationColor = isDonated
        ? (widget.comment.donationColorHex != null
              ? Color(int.parse(widget.comment.donationColorHex!))
              : const Color(0xFF1E88E5))
        : null;

    if (isDonated) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: donationColor!, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YouTube-style Super Thanks Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: donationColor,
              child: Row(
                children: [
                  UserAvatar(
                    radius: 16,
                    photoUrl: widget.comment.avatarUrl,
                    displayName: widget.comment.displayName,
                    fontSize: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.comment.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(widget.comment.createdAt.toDate()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_money,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.comment.donationCurrency}${widget.comment.donationAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Comment Body & Interactions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommentText(),
                  const SizedBox(height: 12),
                  _buildInteractions(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isCreatorComment
            ? AppColors.brand.withValues(alpha: 0.05)
            : Colors.transparent,
        border: widget.isCreatorComment
            ? const Border(
                left: BorderSide(
                  color: AppColors.brand,
                  width: 3,
                ),
              )
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, name, time, creator badge
          _buildCommentHeader(),
          const SizedBox(height: 12),
          // Comment text with markdown support
          _buildCommentText(),
          const SizedBox(height: 12),
          // Interactions: like, dislike, reply, more
          _buildInteractions(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommentHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        UserAvatar(
          radius: 18,
          photoUrl: widget.comment.avatarUrl,
          displayName: widget.comment.displayName,
          fontSize: 18,
        ),
        const SizedBox(width: 12),
        // Name, channel badge, timestamp
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.comment.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Channel badge
                  if (widget.comment.channelId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Channel',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formatTimeAgo(widget.comment.createdAt.toDate()),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // More options menu
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onSelected: (value) async {
            if (value == 'copy') {
              Clipboard.setData(ClipboardData(text: widget.comment.text));
              HapticFeedback.lightImpact();
              Get.snackbar(
                'Copied',
                'Comment text copied to clipboard',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.bgSurface,
                colorText: AppColors.textPrimary,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
                duration: const Duration(seconds: 2),
                icon: const Icon(
                  Icons.content_copy_rounded,
                  color: Colors.white,
                ),
              );
            } else if (value == 'save') {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                Get.snackbar(
                  'Authentication Required',
                  'Please sign in to save comments.',
                );
                return;
              }
              final docRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('savedComments')
                  .doc(widget.comment.id);

              try {
                final docSnap = await docRef.get();
                if (docSnap.exists) {
                  await docRef.delete();
                  Get.snackbar(
                    'Removed',
                    'Comment removed from Saved Comments',
                  );
                } else {
                  await docRef.set({
                    'text': widget.comment.text,
                    'userName': widget.comment.displayName,
                    'userImage': widget.comment.avatarUrl,
                    'sourceType': 'video',
                    'sourceId': '',
                    'sourceTitle': 'Video',
                    'savedAt': FieldValue.serverTimestamp(),
                  });

                  Get.snackbar(
                    'Saved',
                    'Comment saved to Saved Comments',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.bgSurface,
                    colorText: AppColors.textPrimary,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                    mainButton: TextButton(
                      onPressed: () => Get.toNamed('/saved-comments'),
                      child: const Text(
                        'VIEW',
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
              } catch (e) {
                Get.snackbar('Error', 'Failed to save comment: $e');
              }
            } else if (value == 'report') {
              Get.snackbar('Reported', 'Thank you for your report.');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'copy',
              child: Row(
                children: [
                  Icon(
                    Icons.content_copy_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 12),
                  Text('Copy text'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'save',
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark_outline_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 12),
                  Text('Save comment'),
                ],
              ),
            ),
            if (widget.isCreatorComment)
              const PopupMenuItem<String>(
                value: 'helpful',
                child: Row(
                  children: [
                    Icon(
                      Icons.star_outline_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    SizedBox(width: 12),
                    Text('Mark as Helpful'),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 12),
                  Text('Report'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMENT TEXT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCommentText() {
    final formattedData = ClickableUrlText.formatMarkdownLinks(
      widget.comment.text,
    );
    return MarkdownBody(
      data: formattedData,
      selectable: true,
      onTapLink: (text, href, title) {
        final target = href ?? text;
        if (target.startsWith('mention://')) {
          final handle = target.replaceFirst('mention://', '@');
          ClickableUrlText.navigateToChannelByHandle(handle);
        } else if (target.isNotEmpty) {
          ClickableUrlText.launchUrlString(target);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        a: const TextStyle(
          color: Color(0xFF3EA6FF),
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInteractions() {
    return Row(
      children: [
        // Like button
        AnimatedLikeButton(
          isLiked: widget.isLiked,
          size: 16,
          activeColor: AppColors.brand,
          inactiveColor: AppColors.textSecondary,
          onTap: widget.onLike,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isLiked
                    ? Icons.thumb_up_rounded
                    : Icons.thumb_up_outlined,
                size: 16,
                color: widget.isLiked
                    ? AppColors.brand
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.comment.likeCount > 0
                    ? widget.comment.likeCount.toString()
                    : 'Like',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isLiked
                      ? AppColors.brand
                      : AppColors.textSecondary,
                  fontWeight: widget.isLiked
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Dislike button
        AnimatedDislikeButton(
          isDisliked: widget.isDisliked,
          size: 16,
          activeColor: AppColors.brand,
          inactiveColor: AppColors.textSecondary,
          onTap: widget.onDislike,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isDisliked
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
                size: 16,
                color: widget.isDisliked
                    ? AppColors.brand
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.comment.dislikeCount > 0
                    ? widget.comment.dislikeCount.toString()
                    : 'Dislike',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDisliked
                      ? AppColors.brand
                      : AppColors.textSecondary,
                  fontWeight: widget.isDisliked
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Reply button
        _buildInteractionButton(
          icon: Icons.reply_rounded,
          label: 'Reply',
          isActive: false,
          onTap: widget.onReply,
        ),
        // Creator Heart Badge
        if (widget.comment.isHeartedByCreator)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 20,
                      color: Colors.pink,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 10,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Text(
                  'Hearted by ${widget.comment.creatorHeartName ?? 'Creator'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        // Show replies if available
        if (widget.replyCount > 0) ...[
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onShowReplies,
              child: Text(
                '${widget.replyCount} ${widget.replyCount == 1 ? 'reply' : 'replies'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.brand : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.brand : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }
}
