import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/services/comments/comment_service_base.dart';

/// Mixin providing CRUD and stream operations for comment replies.
mixin ReplyCrudMixin on CommentServiceBase {
  /// Add reply securely via backend Callable Cloud Function,
  /// falling back to direct Firestore write if the function call fails.
  Future<String> addReply({
    required String videoId,
    required String commentId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String channelId,
    required String text,
    String? channelName,
    String? channelProfilePicUrl,
  }) async {
    try {
      final callable = functions.httpsCallable('addReplyNested');
      final result = await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'userName': userName,
        'userProfilePicUrl': userProfilePicUrl,
        'channelId': channelId,
        'channelName': channelName,
        'channelProfilePicUrl': channelProfilePicUrl,
        'text': text,
      });

      final data = result.data as Map<String, dynamic>;
      return data['replyId'] as String;
    } catch (e) {
      logger.warning(
        'Failed to add reply via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final docRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId)
            .collection(repliesCollection)
            .doc();

        final newReply = Reply(
          id: docRef.id,
          commentId: commentId,
          videoId: videoId,
          userId: userId,
          userName: userName,
          userProfilePicUrl: userProfilePicUrl,
          channelId: channelId,
          channelName: channelName,
          channelProfilePicUrl: channelProfilePicUrl,
          text: text.trim(),
          likeCount: 0,
          dislikeCount: 0,
          reportCount: 0,
          createdAt: Timestamp.now(),
        );

        await docRef.set(newReply.toMap());
        return docRef.id;
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for addReply: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to add reply: $firestoreError');
      }
    }
  }

  /// Get replies for a comment
  Stream<List<Reply>> getRepliesStream({
    required String videoId,
    required String commentId,
  }) {
    return firestore
        .collection(videosCollection)
        .doc(videoId)
        .collection(commentsCollection)
        .doc(commentId)
        .collection(repliesCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Reply.fromDocumentSnapshot).toList(),
        );
  }

  /// Delete reply securely via backend Callable Cloud Function,
  /// falling back to direct Firestore deletion if unavailable.
  Future<void> deleteReply(
    String videoId,
    String commentId,
    String replyId,
  ) async {
    try {
      final callable = functions.httpsCallable('deleteReplyNested');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
      });
    } catch (e) {
      logger.warning(
        'Failed to delete reply via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        await firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId)
            .collection(repliesCollection)
            .doc(replyId)
            .delete();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for deleteReply: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to delete reply: $firestoreError');
      }
    }
  }
}
