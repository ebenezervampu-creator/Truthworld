import 'package:flutter/material.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';

/// Modal bottom sheets for comment and reply actions.
class CommentActionsSheet {
  const CommentActionsSheet._();

  static void showCommentOptions(
    BuildContext context,
    Comment comment,
    CommentsController commentsController,
  ) {
    final isOwner = AuthService.to.isAuthenticated.value &&
        AuthService.to.uid == comment.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Material(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SafeArea(
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
                    CommentActionHandler.copyCommentText(comment.text);
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
                    CommentActionHandler.toggleSaveVideoComment(
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
                      AppSnackbar.success(
                        'Thank you for your report.',
                        title: 'Reported',
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showReplyOptions(
    BuildContext context,
    Reply reply,
    String commentId,
    CommentsController commentsController,
  ) {
    final isOwner = AuthService.to.isAuthenticated.value &&
        AuthService.to.uid == reply.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Material(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SafeArea(
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
                    CommentActionHandler.copyCommentText(reply.text);
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
                    CommentActionHandler.toggleSaveReply(
                      reply,
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
                      AppSnackbar.success(
                        'Thank you for your report.',
                        title: 'Reported',
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
