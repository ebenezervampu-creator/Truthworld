import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Controller managing reactivity, replies stream, and Firestore mutations for an individual community comment.
class CommunityCommentItemController extends BaseController
    with ContentValidationMixin {
  CommunityCommentItemController({
    required this.postId,
    required this.commentData,
    required this.currentUid,
    this.postOwnerId,
  });

  final String postId;
  final Map<String, dynamic> commentData;
  final String? currentUid;
  final String? postOwnerId;

  late final String commentId;
  late final RxBool isLiked;
  late final RxBool isDisliked;
  late final RxInt likeCount;
  late final RxInt dislikeCount;

  final RxBool isReplying = false.obs;
  final RxBool isRepliesExpanded = false.obs;
  late final TextEditingController replyController;

  Stream<QuerySnapshot<Map<String, dynamic>>>? repliesStream;

  bool get isOwner {
    final uid = currentUid;
    if (uid == null || !AuthService.to.isAuthenticated.value) return false;
    final authorId = commentData['userId'] as String?;
    return uid == authorId || uid == postOwnerId;
  }

  DocumentReference<Map<String, dynamic>> get commentDoc =>
      FirebaseFirestore.instance
          .collection('Community')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

  @override
  void onInit() {
    super.onInit();
    commentId = commentData['id'] as String? ?? '';
    replyController = trackTextController(TextEditingController());

    _initRepliesStream();

    final likedBy = List<String>.from(
      commentData['likedBy'] ?? commentData['likedby'] ?? [],
    );
    final dislikedBy = List<String>.from(
      commentData['dislikedBy'] ?? commentData['dislikedby'] ?? [],
    );

    final uid = currentUid ?? '';
    isLiked = likedBy.contains(uid).obs;
    isDisliked = dislikedBy.contains(uid).obs;

    likeCount =
        ((commentData['likeCount'] ??
                    commentData['likes'] ??
                    likedBy.length)
                as num)
            .toInt()
            .obs;
    dislikeCount =
        ((commentData['dislikeCount'] ??
                    commentData['dislikes'] ??
                    dislikedBy.length)
                as num)
            .toInt()
            .obs;
  }

  void _initRepliesStream() {
    if (commentId.isNotEmpty) {
      repliesStream = commentDoc
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .snapshots();
    }
  }

  void showSignInPrompt(String action) {
    AppSnackbar.warning(
      'Please sign in to $action.',
      actionLabel: 'SIGN IN',
      onAction: AuthService.to.signInWithGoogle,
    );
  }

  Future<void> toggleCommentLike() async {
    final uid = currentUid;
    if (uid == null || !AuthService.to.isAuthenticated.value) {
      showSignInPrompt('like comments');
      return;
    }

    if (isLiked.value) {
      isLiked.value = false;
      likeCount.value = (likeCount.value - 1).clamp(0, 999999);
      await commentDoc.update({
        'likeCount': FieldValue.increment(-1),
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([uid]),
        'likedby': FieldValue.arrayRemove([uid]),
      });
    } else {
      if (isDisliked.value) {
        isDisliked.value = false;
        dislikeCount.value = (dislikeCount.value - 1).clamp(0, 999999);
        await commentDoc.update({
          'dislikeCount': FieldValue.increment(-1),
          'dislikes': FieldValue.increment(-1),
          'dislikedBy': FieldValue.arrayRemove([uid]),
          'dislikedby': FieldValue.arrayRemove([uid]),
        });
      }
      isLiked.value = true;
      likeCount.value += 1;
      await commentDoc.update({
        'likeCount': FieldValue.increment(1),
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([uid]),
        'likedby': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> toggleCommentDislike() async {
    final uid = currentUid;
    if (uid == null || !AuthService.to.isAuthenticated.value) {
      showSignInPrompt('dislike comments');
      return;
    }

    if (isDisliked.value) {
      isDisliked.value = false;
      dislikeCount.value = (dislikeCount.value - 1).clamp(0, 999999);
      await commentDoc.update({
        'dislikeCount': FieldValue.increment(-1),
        'dislikes': FieldValue.increment(-1),
        'dislikedBy': FieldValue.arrayRemove([uid]),
        'dislikedby': FieldValue.arrayRemove([uid]),
      });
    } else {
      if (isLiked.value) {
        isLiked.value = false;
        likeCount.value = (likeCount.value - 1).clamp(0, 999999);
        await commentDoc.update({
          'likeCount': FieldValue.increment(-1),
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
          'likedby': FieldValue.arrayRemove([uid]),
        });
      }
      isDisliked.value = true;
      dislikeCount.value += 1;
      await commentDoc.update({
        'dislikeCount': FieldValue.increment(1),
        'dislikes': FieldValue.increment(1),
        'dislikedBy': FieldValue.arrayUnion([uid]),
        'dislikedby': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> submitReply() async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;
    if (!AuthService.to.isAuthenticated.value) {
      showSignInPrompt('reply');
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;
    final validation = await validateContent(text, fieldName: 'Reply');
    if (!validation.isValid) {
      AppSnackbar.warning(
        validation.message,
        title: 'Inappropriate Content',
      );
      return;
    }
    replyController.clear();
    isReplying.value = false;

    try {
      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final channelId = hasChannel ? channel?.id : null;
      final channelName = hasChannel
          ? (channel?.handle.isNotEmpty ?? false
                ? channel?.handle
                : channel?.name)
          : null;
      final channelAvatar = hasChannel ? channel?.avatarUrl : null;
      final userAvatar = authService.activePhotoUrl;
      final userName = authService.activeDisplayName;

      await commentDoc.collection('replies').add({
        'text': text,
        'userId': uid,
        'userName': userName,
        'userImage': userAvatar,
        'userProfilePicUrl': userAvatar,
        'channelId': channelId,
        'channelName': channelName,
        'channelProfilePicUrl': channelAvatar,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'dislikeCount': 0,
        'likedBy': [],
        'dislikedBy': [],
      });

      await commentDoc.update({
        'replyCount': FieldValue.increment(1),
      });

      isRepliesExpanded.value = true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'CommunityCommentItemController.submitReply',
      );
      AppSnackbar.error(
        'Unable to post reply. Please check your connection and try again.',
      );
    }
  }

  Future<void> toggleSaveComment() async {
    if (!AuthService.to.isAuthenticated.value) {
      showSignInPrompt('save comments');
      return;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty || commentId.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedComments')
        .doc(commentId);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        AppSnackbar.info('Comment removed from Saved Comments');
      } else {
        final userName =
            commentData['channelName']?.toString().isNotEmpty ?? false
                ? commentData['channelName'].toString()
                : (commentData['userName']?.toString() ?? 'User');
        final userImage =
            commentData['channelProfilePicUrl']?.toString().isNotEmpty ?? false
                ? commentData['channelProfilePicUrl'].toString()
                : (commentData['userImage']?.toString() ??
                    commentData['userProfilePicUrl']?.toString() ??
                    '');
        final text = commentData['text']?.toString() ?? '';

        await docRef.set({
          'text': text,
          'userName': userName,
          'userImage': userImage,
          'sourceType': 'community_post',
          'sourceId': postId,
          'sourceTitle': 'Community Post',
          'savedAt': FieldValue.serverTimestamp(),
        });

        AppSnackbar.success(
          'Comment saved to Saved Comments',
          actionLabel: 'VIEW',
          onAction: () => Get.toNamed('/saved-comments'),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'CommunityCommentItemController.toggleSaveComment',
      );
      AppSnackbar.error('Unable to save comment. Please try again.');
    }
  }

  Future<void> deleteComment() async {
    try {
      await commentDoc.delete();
      await FirebaseFirestore.instance
          .collection('Community')
          .doc(postId)
          .update({'commentCount': FieldValue.increment(-1)});
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'CommunityCommentItemController.deleteComment',
      );
      AppSnackbar.error('Unable to delete comment. Please try again.');
    }
  }

  void prepareReplyToUser(String targetUser) {
    replyController.text = '@$targetUser ';
    replyController.selection = TextSelection.fromPosition(
      TextPosition(offset: replyController.text.length),
    );
    isReplying.value = true;
  }
}
