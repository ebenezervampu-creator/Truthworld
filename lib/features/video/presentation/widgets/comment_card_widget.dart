import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/comment.dart';

/// Professional Comment Card Widget (Industry Standard)
/// Displays a single comment with like/dislike/reply functionality
class CommentCardWidget extends StatefulWidget {
  final Comment comment;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onReply;
  final bool isLiked;
  final bool isDisliked;
  final bool isCreatorComment;
  final VoidCallback? onShowReplies;
  final int replyCount;

  const CommentCardWidget({
    super.key,
    required this.comment,
    required this.onLike,
    required this.onDislike,
    required this.onReply,
    required this.isLiked,
    required this.isDisliked,
    required this.isCreatorComment,
    this.onShowReplies,
    this.replyCount = 0,
  });

  @override
  State<CommentCardWidget> createState() => _CommentCardWidgetState();
}

class _CommentCardWidgetState extends State<CommentCardWidget> {

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isCreatorComment
            ? AppColors.brand.withValues(alpha: 0.05)
            : Colors.transparent,
        border: widget.isCreatorComment
            ? Border(
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
        CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(widget.comment.userProfilePicUrl),
          onBackgroundImageError: (exception, stackTrace) {
            // Fallback to placeholder
          },
          child: widget.comment.userProfilePicUrl.isEmpty
              ? const Icon(Icons.person)
              : null,
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
                    widget.comment.userName,
                    style: GoogleFonts.roboto(
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
                        child: Text(
                          'Channel',
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formatTimeAgo(widget.comment.createdAt.toDate()),
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // More options menu
        PopupMenuButton(
          child: Icon(
            Icons.more_vert,
            size: 18,
            color: AppColors.textSecondary,
          ),
          itemBuilder: (context) => [
            if (widget.isCreatorComment)
              PopupMenuItem(
                child: Text('Mark as Helpful'),
              ),
            PopupMenuItem(
              child: Text('Report'),
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
    return MarkdownBody(
      data: widget.comment.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.roboto(
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.5,
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
        _buildInteractionButton(
          icon: widget.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: widget.comment.likeCount > 0
              ? widget.comment.likeCount.toString()
              : 'Like',
          isActive: widget.isLiked,
          onTap: widget.onLike,
        ),
        const SizedBox(width: 12),
        // Dislike button
        _buildInteractionButton(
          icon: widget.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
          label: widget.comment.dislikeCount > 0
              ? widget.comment.dislikeCount.toString()
              : 'Dislike',
          isActive: widget.isDisliked,
          onTap: widget.onDislike,
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
                    Icon(
                      Icons.favorite,
                      size: 20,
                      color: Colors.pink,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
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
                  style: GoogleFonts.roboto(
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
                style: GoogleFonts.roboto(
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
              style: GoogleFonts.roboto(
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






