import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/video/data/models/claim_comment.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 ClaimCommentTile
///
/// Renders an evidence-backed community deliberation note with stance indicators,
/// source citation chips, and helpfulness voting.
class ClaimCommentTile extends StatelessWidget {
  const ClaimCommentTile({
    required this.comment,
    required this.controller,
    this.isEmbeddedInVideoView = false,
    this.targetCommentId,
    super.key,
  });

  final ClaimComment comment;
  final ClaimCommentsController controller;
  final bool isEmbeddedInVideoView;
  final String? targetCommentId;

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.to.uid;
    final isOwner = currentUid.isNotEmpty && comment.userId == currentUid;
    final isHelpful = comment.isHelpfulBy(currentUid);
    final isUnhelpful = comment.isUnhelpfulBy(currentUid);

    final isTarget = targetCommentId != null && targetCommentId == comment.id;
    if (isTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTarget ? Colors.white.withValues(alpha: 0.06) : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTarget ? Colors.white : _getStanceBorderColor(comment.stance),
          width: isTarget ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Stance Pill, Date, Options
          Row(
            children: [
              GestureDetector(
                onTap: comment.isChannelAuthor
                    ? () => CommentActionHandler.navigateToChannel(
                          comment.channelId,
                          channelHandle: comment.displayName,
                        )
                    : null,
                child: MouseRegion(
                  cursor: comment.isChannelAuthor
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: _buildAvatar(comment.avatarUrl, comment.displayName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: comment.isChannelAuthor
                          ? () => CommentActionHandler.navigateToChannel(
                                comment.channelId,
                                channelHandle: comment.displayName,
                              )
                          : null,
                      child: MouseRegion(
                        cursor: comment.isChannelAuthor
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        child: Text(
                          comment.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      FormatUtils.formatDate(comment.createdAt.toDate()),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStancePill(comment.stance),
              if (isOwner) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  tooltip: 'Delete Note',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ],
          ),

          // If rendered in the video-wide overview, display the claim statement context
          if (isEmbeddedInVideoView && comment.claimText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Claim #${comment.claimIndex + 1}: "${comment.claimText}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Note text
          ClickableUrlText(
            text: comment.text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),

          // Evidence source links (if any)
          if (comment.sourceUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: comment.sourceUrls.map((url) {
                final domain = SourceAvatarService.cleanDomain(url);
                return InkWell(
                  onTap: () => SourceUrlSanitizer.launchSourceUrl(
                    url: url,
                    title: comment.claimText,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          domain,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 8),

          // Bottom Bar: Helpful vs Unhelpful voting
          Row(
            children: [
              Text(
                'Was this note helpful?',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),
              // Helpful button
              InkWell(
                onTap: () => controller.toggleHelpful(comment, true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHelpful
                        ? const Color(0xFF052e16)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHelpful
                          ? const Color(0xFF059669)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHelpful
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 13,
                        color: isHelpful ? AppColors.success : Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${comment.helpfulCount}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isHelpful ? AppColors.success : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Unhelpful button
              InkWell(
                onTap: () => controller.toggleHelpful(comment, false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnhelpful
                        ? const Color(0xFF310B10)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUnhelpful
                          ? const Color(0xFFE11D48)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isUnhelpful
                            ? Icons.thumb_down_alt_rounded
                            : Icons.thumb_down_alt_outlined,
                        size: 13,
                        color: isUnhelpful ? AppColors.error : Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${comment.unhelpfulCount}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isUnhelpful ? AppColors.error : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, String name) {
    if (url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _buildFallbackAvatar(name),
        ),
      );
    }
    return _buildFallbackAvatar(name);
  }

  Widget _buildFallbackAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFF2B2B36),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStancePill(String stance) {
    final lower = stance.toLowerCase();
    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    if (lower == 'supports') {
      bg = const Color(0xFF052e16);
      border = const Color(0xFF059669).withValues(alpha: 0.4);
      text = AppColors.success;
      label = 'Supports';
      icon = Icons.check_circle_outline_rounded;
    } else if (lower == 'disputes') {
      bg = const Color(0xFF310B10);
      border = const Color(0xFFE11D48).withValues(alpha: 0.4);
      text = AppColors.error;
      label = 'Disputes';
      icon = Icons.cancel_outlined;
    } else {
      bg = const Color(0xFF261905);
      border = const Color(0xFFD97706).withValues(alpha: 0.4);
      text = AppColors.warning;
      label = 'Context';
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStanceBorderColor(String stance) {
    final lower = stance.toLowerCase();
    if (lower == 'supports') {
      return const Color(0xFF059669).withValues(alpha: 0.2);
    }
    if (lower == 'disputes') {
      return const Color(0xFFE11D48).withValues(alpha: 0.2);
    }
    return Colors.white.withValues(alpha: 0.08);
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Community Note',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to remove this deliberation note? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Get.back();
              controller.deleteComment(comment);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
