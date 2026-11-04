import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Helper methods for comment actions: saving, copying, reporting, and channel navigation.
class CommentActionHandler {
  const CommentActionHandler._();

  static void showSignInPrompt() {
    AppSnackbar.signInRequired(
      message: 'Please sign in to proceed',
      title: 'Sign In Required',
      onAction: () => AuthService.to.triggerPlatformSignIn(),
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

  static Future<void> navigateToChannel(
    String? channelId, {
    String? channelHandle,
  }) async {
    final cleanId = channelId?.trim() ?? '';
    final cleanHandle = channelHandle?.trim() ?? '';
    if (cleanId.isEmpty && cleanHandle.isEmpty) return;

    try {
      // 1. Instant 0ms navigation if already cached in memory
      Channel? cached;
      if (cleanId.isNotEmpty) {
        cached = ChannelMemoryCache.get(cleanId);
      }
      if (cached == null && cleanHandle.isNotEmpty) {
        cached = ChannelMemoryCache.get(cleanHandle);
      }
      if (cached != null) {
        Get.toNamed(
          cached.channelRoute,
          arguments: {'channel': cached},
        );
        return;
      }

      // 2. Query Firestore with loading indicator
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        barrierDismissible: false,
      );

      DocumentSnapshot? doc;
      if (cleanId.isNotEmpty) {
        doc = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .doc(cleanId)
            .get();
      }

      // Fallback query by handle if doc ID not matched
      if ((doc == null || !doc.exists) && cleanHandle.isNotEmpty) {
        final normalizedHandle =
            cleanHandle.replaceAll(RegExp('^@'), '').toLowerCase();
        final query = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('handleLowercase', isEqualTo: normalizedHandle)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          doc = query.docs.first;
        }
      }

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (doc != null && doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        ChannelMemoryCache.set(channel.id, channel);
        Get.toNamed(
          channel.channelRoute,
          arguments: {'channel': channel},
        );
      } else if (cleanHandle.isNotEmpty) {
        AppNavigator.toChannelHandle(cleanHandle);
      } else if (cleanId.isNotEmpty) {
        AppNavigator.toChannel(cleanId);
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
