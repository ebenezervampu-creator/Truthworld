import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Premium reply display widget matching comment styling
class PremiumReplyWidget extends StatefulWidget {
  final Reply reply;
  final CommentsController controller;
  final Function(Reply)? onReportTap;
  final bool isCreatorView;

  const PremiumReplyWidget({
    required this.reply,
    required this.controller,
    this.onReportTap,
    this.isCreatorView = false,
    super.key,
  });

  @override
  State<PremiumReplyWidget> createState() => _PremiumReplyWidgetState();
}

class _PremiumReplyWidgetState extends State<PremiumReplyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _playLikeAnimation() {
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? 24 : 48,
        right: isMobile ? 12 : 16,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgSurface.withAlpha(150)
            : const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? AppColors.bgDivider.withAlpha(30)
              : const Color(0xFFF0F0F0),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Time
            _buildHeader(isDark, isMobile),
            const SizedBox(height: 10),

            // Reply text
            _buildReplyText(isDark),
            const SizedBox(height: 10),

            // Like info and interactions
            _buildInteractionBar(isDark, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isMobile) {
    return Row(
      children: [
        // Avatar
        InkWell(
          onTap: () {
            // Profile navigation
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.brand.withAlpha(80),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: widget.reply.userProfilePicUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: Colors.grey[300]),
                errorWidget: (_, _, _) =>
                    Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 16),
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Name and timestamp
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.reply.userName,
                    style: GoogleFonts.roboto(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Badge if reply is from channel
                  if (widget.reply.channelName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withAlpha(180),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Creator',
                        style: GoogleFonts.roboto(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                timeago.format(widget.reply.createdAt.toDate()),
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyText(bool isDark) {
    return Text(
      widget.reply.text,
      style: GoogleFonts.roboto(
        fontSize: 13,
        height: 1.4,
        color: isDark ? Colors.white.withAlpha(220) : Colors.black87,
      ),
    );
  }

  Widget _buildInteractionBar(bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Like info text
        if (widget.reply.likeCount > 0 || widget.reply.dislikeCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                children: [
                  if (widget.reply.likeCount > 0)
                    TextSpan(
                      text: '👍 ${widget.reply.likeCount}',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brand,
                      ),
                    ),
                  if (widget.reply.dislikeCount > 0) ...[
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: '👎 ${widget.reply.dislikeCount}',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Action buttons
        Row(
          children: [
            // Like button
            _buildInteractionButton(
              icon: Icons.thumb_up_outlined,
              label: 'Like',
              isActive: false,
              onTap: () {
                _playLikeAnimation();
              },
              color: isDark ? Colors.white54 : Colors.grey[700] ?? Colors.grey,
              activeColor: AppColors.brand,
              isMobile: isMobile,
            ),
            const SizedBox(width: 10),

            // Dislike button
            _buildInteractionButton(
              icon: Icons.thumb_down_outlined,
              label: 'Dislike',
              isActive: false,
              onTap: () {},
              color: isDark ? Colors.white54 : Colors.grey[700] ?? Colors.grey,
              activeColor: const Color(0xFFFF6B6B),
              isMobile: isMobile,
            ),
            const Spacer(),

            // Report button
            if (widget.onReportTap != null)
              InkWell(
                onTap: () => widget.onReportTap!(widget.reply),
                child: Tooltip(
                  message: 'Report reply',
                  child: Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
    required Color activeColor,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      child: ScaleTransition(
        scale: label == 'Like' ? _likeScaleAnimation : AlwaysStoppedAnimation(1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeColor : color,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isActive ? activeColor : color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}






