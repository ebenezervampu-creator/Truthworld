import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Controller managing reactivity and Firestore mutations for an individual community reply.
class CommunityReplyItemController extends BaseController {
  CommunityReplyItemController({
    required this.postId,
    required this.commentId,
    required this.replyData,
    this.postOwnerId,
  });

  final String postId;
  final String commentId;
  final Map<String, dynamic> replyData;
  final String? postOwnerId;

  late final String replyId;
  late final RxBool isLiked;
  late final RxBool isDisliked;
  late final RxInt likeCount;
  late final RxInt dislikeCount;

  String? get currentUid =>
      AuthService.to.isAuthenticated.value ? AuthService.to.uid : null;

  bool get isOwner {
    final uid = currentUid;
    if (uid == null) return false;
    final authorId =
        replyData['userId'] as String? ?? replyData['channelId'] as String?;
    return uid == authorId || uid == postOwnerId;
  }

  DocumentReference<Map<String, dynamic>> get replyRef =>
      FirebaseFirestore.instance
          .collection('Community')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId);

  @override
  void onInit() {
    super.onInit();
    replyId = replyData['id'] as String? ?? '';
    final likedBy = List<String>.from(
      replyData['likedBy'] ?? replyData['likedby'] ?? [],
    );
    final dislikedBy = List<String>.from(
      replyData['dislikedBy'] ?? replyData['dislikedby'] ?? [],
    );

    likeCount =
        ((replyData['likeCount'] ?? replyData['likes'] ?? likedBy.length)
                as num)
            .toInt()
            .obs;
    dislikeCount =
        ((replyData['dislikeCount'] ??
                    replyData['dislikes'] ??
                    dislikedBy.length)
                as num)
            .toInt()
            .obs;

    final uid = currentUid;
    isLiked = (uid != null && likedBy.contains(uid)).obs;
    isDisliked = (uid != null && dislikedBy.contains(uid)).obs;
  }

  void _showSignInPrompt(String action) {
    AppSnackbar.warning(
      'Please sign in to $action.',
      actionLabel: 'SIGN IN',
      onAction: AuthService.to.signInWithGoogle,
    );
  }

  Future<void> toggleReplyLike() async {
    final uid = currentUid;
    if (uid == null || !AuthService.to.isAuthenticated.value) {
      _showSignInPrompt('react to replies');
      return;
    }

    final willLike = !isLiked.value;
    isLiked.value = willLike;
    if (willLike) {
      likeCount.value++;
      if (isDisliked.value) {
        isDisliked.value = false;
        dislikeCount.value = (dislikeCount.value - 1).clamp(0, 99999999);
      }
    } else {
      likeCount.value = (likeCount.value - 1).clamp(0, 99999999);
    }

    try {
      if (willLike) {
        await replyRef.update({
          'likes': FieldValue.increment(1),
          'likeCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([uid]),
          'dislikedBy': FieldValue.arrayRemove([uid]),
        });
        await replyRef.collection('likes').doc(uid).set({
          'likedAt': FieldValue.serverTimestamp(),
        });
        await replyRef
            .collection('dislikes')
            .doc(uid)
            .delete()
            .catchError((e, s) => ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'CommunityReplyItemController.replyLike.deleteDislikeDoc',
                ));
      } else {
        await replyRef.update({
          'likes': FieldValue.increment(-1),
          'likeCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
        });
        await replyRef
            .collection('likes')
            .doc(uid)
            .delete()
            .catchError((e, s) => ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'CommunityReplyItemController.replyLike.deleteLikeDoc',
                ));
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommunityReplyItemController.toggleReplyLike',
      );
    }
  }

  Future<void> toggleReplyDislike() async {
    final uid = currentUid;
    if (uid == null || !AuthService.to.isAuthenticated.value) {
      _showSignInPrompt('react to replies');
      return;
    }

    final willDislike = !isDisliked.value;
    isDisliked.value = willDislike;
    if (willDislike) {
      dislikeCount.value++;
      if (isLiked.value) {
        isLiked.value = false;
        likeCount.value = (likeCount.value - 1).clamp(0, 99999999);
      }
    } else {
      dislikeCount.value = (dislikeCount.value - 1).clamp(0, 99999999);
    }

    try {
      if (willDislike) {
        await replyRef.update({
          'dislikes': FieldValue.increment(1),
          'dislikeCount': FieldValue.increment(1),
          'dislikedBy': FieldValue.arrayUnion([uid]),
          'likedBy': FieldValue.arrayRemove([uid]),
        });
        await replyRef.collection('dislikes').doc(uid).set({
          'dislikedAt': FieldValue.serverTimestamp(),
        });
        await replyRef
            .collection('likes')
            .doc(uid)
            .delete()
            .catchError((e, s) => ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'CommunityReplyItemController.replyDislike.deleteLikeDoc',
                ));
      } else {
        await replyRef.update({
          'dislikes': FieldValue.increment(-1),
          'dislikeCount': FieldValue.increment(-1),
          'dislikedBy': FieldValue.arrayRemove([uid]),
        });
        await replyRef
            .collection('dislikes')
            .doc(uid)
            .delete()
            .catchError((e, s) => ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'CommunityReplyItemController.replyDislike.deleteDislikeDoc',
                ));
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommunityReplyItemController.toggleReplyDislike',
      );
    }
  }

  Future<void> saveReply() async {
    final uid = currentUid;
    if (uid == null) return;
    final text = replyData['text']?.toString() ?? '';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedComments')
          .doc(replyId)
          .set({
            'text': text,
            'userName': replyData['userName'] ?? 'User',
            'userImage': replyData['userImage'] ?? '',
            'sourceType': 'community_post_reply',
            'sourceId': postId,
            'sourceTitle': 'Community Post Reply',
            'savedAt': FieldValue.serverTimestamp(),
          });
      AppSnackbar.success('Reply saved to Saved Comments');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'CommunityReplyItemController.saveReply',
      );
      AppSnackbar.error('Unable to save reply. Please try again.');
    }
  }

  Future<void> deleteReply() async {
    try {
      await replyRef.delete();
      await FirebaseFirestore.instance
          .collection('Community')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({'replyCount': FieldValue.increment(-1)});
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'CommunityReplyItemController.deleteReply',
      );
      AppSnackbar.error('Unable to delete reply. Please try again.');
    }
  }
}
