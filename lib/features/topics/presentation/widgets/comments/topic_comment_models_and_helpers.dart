import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';

/// Shows standard prompt to sign in with Google when attempting an authenticated action.
void showTopicSignInPrompt(String action) {
  AppSnackbar.signInRequired(
    message: 'Please sign in with your Google account to $action.',
    title: 'Sign In Required',
    duration: const Duration(seconds: 4),
    onAction: () {
      if (Get.isRegistered<AuthService>()) {
        AuthService.to.triggerPlatformSignIn();
      }
    },
  );
}

/// Copies text to clipboard and shows feedback snackbar.
void copyCommentTextToClipboard(String text) {
  Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.lightImpact();
  AppSnackbar.info(
    'Comment text copied to clipboard',
    title: 'Copied',
  );
}

/// Navigates to a channel profile route with loading indicator.
Future<void> navigateToTopicChannel(String? channelId, {String? channelHandle}) async {
  await CommentActionHandler.navigateToChannel(channelId, channelHandle: channelHandle);
}

/// Saves or unsaves a topic comment to user's savedComments collection.
Future<void> toggleSaveTopicComment({
  required Comment comment,
  required String topicId,
}) async {
  if (!AuthService.to.isAuthenticated.value) {
    showTopicSignInPrompt('save comments');
    return;
  }
  final uid = AuthService.to.uid;
  final docRef = FirebaseFirestore.instance
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection('savedComments')
      .doc(comment.id);

  try {
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      await docRef.delete();
      AppSnackbar.info('Comment removed from Saved Comments');
    } else {
      await docRef.set({
        'text': comment.text,
        'userName': comment.displayName,
        'userImage': comment.avatarUrl,
        'sourceType': 'topic',
        'sourceId': topicId,
        'sourceTitle': 'Topic',
        'savedAt': FieldValue.serverTimestamp(),
      });

      AppSnackbar.success(
        'Comment saved to Saved Comments',
        title: 'Saved',
        actionLabel: 'VIEW',
        onAction: () => Get.toNamed('/saved-comments'),
      );
    }
  } catch (e) {
    ErrorHandler.log(e, context: 'TopicCommentsSection.toggleSaveTopicComment');
    AppSnackbar.error('Unable to save comment. Please try again.');
  }
}

/// Saves or unsaves a topic reply to user's savedComments collection.
Future<void> toggleSaveTopicReply({
  required Reply reply,
  required String topicId,
}) async {
  if (!AuthService.to.isAuthenticated.value) {
    showTopicSignInPrompt('save comments');
    return;
  }
  final uid = AuthService.to.uid;
  final docRef = FirebaseFirestore.instance
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection('savedComments')
      .doc(reply.id);

  try {
    final docSnap = await docRef.get();
    if (docSnap.exists) {
      await docRef.delete();
      AppSnackbar.info('Reply removed from Saved Comments', title: 'Removed');
    } else {
      await docRef.set({
        'text': reply.text,
        'userName': reply.displayName,
        'userImage': reply.avatarUrl,
        'sourceType': 'topic',
        'sourceId': topicId,
        'sourceTitle': 'Topic',
        'savedAt': FieldValue.serverTimestamp(),
      });

      AppSnackbar.success(
        'Reply saved to Saved Comments',
        title: 'Saved',
        actionLabel: 'VIEW',
        onAction: () => Get.toNamed('/saved-comments'),
      );
    }
  } catch (e) {
    ErrorHandler.log(e, context: 'TopicCommentsSection.toggleSaveReply');
    AppSnackbar.error('Unable to save reply. Please try again.');
  }
}

/// CustomPainter drawing the visual thread line connecting parent comment to child replies.
class ReplyThreadLinePainter extends CustomPainter {
  ReplyThreadLinePainter({
    required this.color,
    required this.isLast,
    required this.branchY,
  });

  final Color color;
  final bool isLast;
  final double branchY;

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
