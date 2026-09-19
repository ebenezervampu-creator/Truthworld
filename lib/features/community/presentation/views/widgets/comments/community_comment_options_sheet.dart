import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Presentation helper for comment and reply context action bottom sheets.
class CommunityCommentOptionsSheet {
  /// Displays the options sheet for an individual community comment.
  static void showCommentOptions({
    required BuildContext context,
    required String text,
    required bool isOwner,
    required VoidCallback onSave,
    required Future<void> Function() onDelete,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  Navigator.pop(sheetContext);
                  onSave();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white),
                title: const Text(
                  'Copy comment text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(sheetContext);
                  AppSnackbar.info('Comment copied to clipboard');
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Delete comment',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await onDelete();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report comment',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    AppSnackbar.info(
                      'Thank you for reporting inappropriate content',
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Displays the options sheet for an individual community reply.
  static void showReplyOptions({
    required BuildContext context,
    required String text,
    required bool isOwner,
    required Future<void> Function() onSave,
    required Future<void> Function() onDelete,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save reply',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await onSave();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white),
                title: const Text(
                  'Copy reply text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(sheetContext);
                  AppSnackbar.info('Reply copied to clipboard');
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Delete reply',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await onDelete();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report reply',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    AppSnackbar.info(
                      'Thank you for reporting inappropriate content',
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
