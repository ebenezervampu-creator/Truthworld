import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Compact list tile rendering a saved comment item with avatar,
/// author header, comment body, relative timestamp, and options menu.
class CompactSavedCommentTile extends StatelessWidget {
  const CompactSavedCommentTile({
    required this.comment,
    required this.controller,
    required this.onTap,
    required this.onCopyText,
    required this.onUnsave,
    super.key,
  });

  final SavedCommentModel comment;
  final SavedCommentsController controller;
  final VoidCallback onTap;
  final VoidCallback onCopyText;
  final VoidCallback onUnsave;

  static IconData getSourceIcon(String sourceType) {
    switch (sourceType) {
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'topic':
        return Icons.tag_rounded;
      case 'community_post':
        return Icons.article_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  static String getSourceLabel(String sourceType) {
    switch (sourceType) {
      case 'video':
        return 'Video Comment';
      case 'topic':
        return 'Topic Comment';
      case 'community_post':
        return 'Community Post';
      default:
        return 'Comment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.lightImpact();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SavedCommentAvatar(
                displayName: comment.userName,
                photoUrl: comment.userImage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: comment.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: ' • ${getSourceLabel(comment.sourceType)}',
                            style: const TextStyle(
                              color: Color(0xFF8E8E8E),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClickableUrlText(
                      text: comment.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (comment.sourceTitle.isNotEmpty) ...[
                          Icon(
                            getSourceIcon(comment.sourceType),
                            size: 13,
                            color: const Color(0xFF8E8E8E),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              comment.sourceTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8E8E8E),
                              ),
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E8E),
                            ),
                          ),
                        ],
                        Text(
                          NotificationNavigationHandler.formatNotificationTimestamp(
                            comment.savedAt,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E8E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SavedCommentActionMenu(
                comment: comment,
                onTap: onTap,
                onCopyText: onCopyText,
                onUnsave: onUnsave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic user avatar matching DynamicNotificationAvatar styling.
class SavedCommentAvatar extends StatelessWidget {
  const SavedCommentAvatar({
    required this.displayName,
    required this.photoUrl,
    super.key,
  });

  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF272727),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final cleanName = displayName.trim().replaceAll('@', '');
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '';
    final bgColor = NotificationNavigationHandler.getAvatarColor(cleanName);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.0,
              ),
            )
          : const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 22,
            ),
    );
  }
}

/// Three-dots popup menu providing actions to open source, copy text, or unsave comment.
class SavedCommentActionMenu extends StatelessWidget {
  const SavedCommentActionMenu({
    required this.comment,
    required this.onTap,
    required this.onCopyText,
    required this.onUnsave,
    super.key,
  });

  final SavedCommentModel comment;
  final VoidCallback onTap;
  final VoidCallback onCopyText;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF8E8E8E),
        size: 20,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: (action) {
        if (action == 'view') {
          onTap();
        } else if (action == 'copy') {
          onCopyText();
        } else if (action == 'unsave') {
          onUnsave();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: 12),
              Text('View source'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.copy_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: 12),
              Text('Copy text'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'unsave',
          child: Row(
            children: [
              Icon(
                Icons.bookmark_remove_rounded,
                size: 20,
                color: AppColors.error,
              ),
              SizedBox(width: 12),
              Text('Unsave', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}
