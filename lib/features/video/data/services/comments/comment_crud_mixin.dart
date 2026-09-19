import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/services/comments/comment_service_base.dart';

/// Mixin providing CRUD and stream operations for top-level video comments.
mixin CommentCrudMixin on CommentServiceBase {
  /// Add a new comment securely via backend Callable Cloud Function,
  /// falling back to direct Firestore write if the function call fails.
  Future<String> addComment({
    required String videoId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String channelId,
    required String text,
    String? channelName,
    String? channelProfilePicUrl,
    double donationAmount = 0.0,
    String donationCurrency = r'$',
    bool isDonatedComment = false,
    String? donationColorHex,
  }) async {
    // Input validation
    if (text.trim().isEmpty) {
      throw Exception('Comment cannot be empty');
    }
    if (text.trim().length > 5000) {
      throw Exception('Comment exceeds maximum length of 5000 characters');
    }
    if (userId.trim().isEmpty) {
      throw Exception('User ID is required');
    }
    if (videoId.trim().isEmpty) {
      throw Exception('Video ID is required');
    }

    try {
      final callable = functions.httpsCallable('addCommentNested');
      final result = await callable.call({
        'videoId': videoId,
        'userName': userName,
        'userProfilePicUrl': userProfilePicUrl,
        'channelId': channelId,
        'channelName': channelName,
        'channelProfilePicUrl': channelProfilePicUrl,
        'text': text,
        'donationAmount': donationAmount,
        'donationCurrency': donationCurrency,
        'isDonatedComment': isDonatedComment,
        'donationColorHex': donationColorHex,
      });

      final data = result.data as Map<String, dynamic>;
      return data['commentId'] as String;
    } catch (e) {
      logger.warning(
        'Failed to add comment via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final docRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc();

        final newComment = Comment(
          id: docRef.id,
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
          donationAmount: donationAmount,
          donationCurrency: donationCurrency,
          isDonatedComment: isDonatedComment,
          donationColorHex: donationColorHex,
        );

        await docRef.set(newComment.toMap());
        return docRef.id;
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for addComment: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to add comment: $firestoreError');
      }
    }
  }

  /// Get comments for a video with pagination
  Stream<List<Comment>> getCommentsStream({
    required String videoId,
    int limit = 20,
  }) {
    return firestore
        .collection(videosCollection)
        .doc(videoId)
        .collection(commentsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Comment.fromDocumentSnapshot).toList(),
        );
  }

  /// Get single comment
  Future<Comment?> getComment(String videoId, String commentId) async {
    try {
      final doc = await firestore
          .collection(videosCollection)
          .doc(videoId)
          .collection(commentsCollection)
          .doc(commentId)
          .get();
      if (doc.exists) {
        return Comment.fromDocumentSnapshot(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get comment: $e');
    }
  }

  /// Update comment text (for creator only)
  Future<void> updateComment({
    required String videoId,
    required String commentId,
    required String newText,
  }) async {
    try {
      await firestore
          .collection(videosCollection)
          .doc(videoId)
          .collection(commentsCollection)
          .doc(commentId)
          .update({'text': newText});
    } catch (e) {
      throw Exception('Failed to update comment: $e');
    }
  }

  /// Delete comment securely via backend Callable Cloud Function,
  /// falling back to direct Firestore batch deletion if unavailable.
  Future<void> deleteComment(String videoId, String commentId) async {
    try {
      final callable = functions.httpsCallable('deleteCommentNested');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
      });
    } catch (e) {
      logger.warning(
        'Failed to delete comment via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final repliesSnapshot = await firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId)
            .collection(repliesCollection)
            .get();

        final batch = firestore.batch();
        for (final doc in repliesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        final commentRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId);
        batch.delete(commentRef);

        await batch.commit();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for deleteComment: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to delete comment: $firestoreError');
      }
    }
  }
}
