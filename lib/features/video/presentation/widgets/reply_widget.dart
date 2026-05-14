import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

/// Professional Reply Widget (Industry Standard)
/// Displays nested replies with indentation and interaction options
class ReplyWidget extends StatefulWidget {
  final Reply reply;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onReply;
  final bool isLiked;
  final bool isDisliked;
  final bool isCreatorReply;
  final int replyLevel; // For nested indentation

  const ReplyWidget({
    super.key,
    required this.reply,
    required this.onLike,
    required this.onDislike,
    required this.onReply,
    required this.isLiked,
    required this.isDisliked,
    required this.isCreatorReply,
    this.replyLevel = 0,
  });

  @override
  State<ReplyWidget> createState() => _ReplyWidgetState();
}

class _ReplyWidgetState extends State<ReplyWidget> {
  @override
  Widget build(BuildContext context) {
    // Indentation based on reply level
    final indent = 16.0 * (widget.replyLevel + 1).clamp(0, 3);

    return Padding(
      padding: EdgeInsets.only(left: indent.toDouble()),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isCreatorReply
              ? AppColors.brand.withValues(alpha: 0.08)
              : AppTheme.secondaryBackground.withValues(alpha: 0.3),
          border: widget.isCreatorReply
              ? Border(
                  left: BorderSide(
                    color: AppColors.brand,
                    width: 2,
                  ),
                )
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildReplyHeader(),
            const SizedBox(height: 8),
            // Reply text
            Text(
              widget.reply.text,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            // Interactions
            _buildReplyInteractions(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReplyHeader() {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 14,
          backgroundImage: NetworkImage(widget.reply.userProfilePicUrl),
          backgroundColor: AppTheme.secondaryBackground,
        ),
        const SizedBox(width: 8),
        // Name and time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.reply.userName,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Creator badge
                  if (widget.isCreatorReply)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'Creator',
                          style: GoogleFonts.roboto(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // Channel badge
                  if (widget.reply.channelId.isNotEmpty && !widget.isCreatorReply)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'Channel',
                          style: GoogleFonts.roboto(
                            fontSize: 9,
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
                _formatTimeAgo(widget.reply.createdAt.toDate()),
                style: GoogleFonts.roboto(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReplyInteractions() {
    return Row(
      children: [
        // Like
        _buildReplyInteractionButton(
          icon: widget.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: widget.reply.likeCount > 0
              ? widget.reply.likeCount.toString()
              : 'Like',
          isActive: widget.isLiked,
          onTap: widget.onLike,
        ),
        const SizedBox(width: 10),
        // Dislike
        _buildReplyInteractionButton(
          icon: widget.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
          label: widget.reply.dislikeCount > 0
              ? widget.reply.dislikeCount.toString()
              : 'Dislike',
          isActive: widget.isDisliked,
          onTap: widget.onDislike,
        ),
        const SizedBox(width: 10),
        // Reply
        _buildReplyInteractionButton(
          icon: Icons.reply_rounded,
          label: 'Reply',
          isActive: false,
          onTap: widget.onReply,
        ),
      ],
    );
  }

  Widget _buildReplyInteractionButton({
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
              size: 14,
              color: isActive ? AppColors.brand : AppColors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 11,
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






