import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Helper methods for comment actions: saving, copying, reporting, and channel navigation.
class CommentActionHandler {
  const CommentActionHandler._();

  static void showSignInPrompt() {
    AppSnackbar.warning(
      'Please sign in to proceed',
      title: 'Sign In Required',
      actionLabel: 'SIGN IN',
      onAction: () => AuthService.to.signInWithGoogle(),
    );
  }

  static void copyCommentText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    AppSnackbar.info(
      'Comment text copied to clipboard',
      title: 'Copied',
    );
  }

  static Future<void> toggleSaveVideoComment(
    Comment comment,
    String videoId,
  ) async {
    if (!AuthService.to.isAuthenticated.value) {
      showSignInPrompt();
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

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
          'sourceType': 'video',
          'sourceId': videoId,
          'sourceTitle': 'Video',
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
      ErrorHandler.log(e, context: 'VideoScreen.saveComment');
      AppSnackbar.error('Unable to save comment. Please try again.');
    }
  }

  static Future<void> toggleSaveReply(Reply reply, String videoId) async {
    if (!AuthService.to.isAuthenticated.value) {
      showSignInPrompt();
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection('savedComments')
        .doc(reply.id);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        AppSnackbar.info(
          'Reply removed from Saved Comments',
          title: 'Removed',
        );
      } else {
        await docRef.set({
          'text': reply.text,
          'userName': reply.displayName,
          'userImage': reply.avatarUrl,
          'sourceType': 'video',
          'sourceId': videoId,
          'sourceTitle': 'Video',
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
      ErrorHandler.log(e, context: 'VideoScreen.saveReply');
      AppSnackbar.error('Unable to save reply. Please try again.');
    }
  }

  static Future<void> navigateToChannel(String? channelId) async {
    if (channelId == null || channelId.isEmpty) return;
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        barrierDismissible: false,
      );
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .get();
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        Get.offAndToNamed(
          channel.channelRoute,
          arguments: {'channel': channel},
        );
      } else {
        AppSnackbar.warning('Channel not found');
      }
    } catch (e, stackTrace) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentActionHandler.navigateToChannel',
      );
      AppSnackbar.warning('Unable to open channel at this time.');
    }
  }
}
