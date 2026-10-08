import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/comment_report.dart';
import 'package:truthworld/features/video/data/services/comments/comment_service_base.dart';

/// Mixin providing comment reporting and studio/creator query operations.
mixin CommentStudioQueriesMixin on CommentServiceBase {
  /// Report a comment or reply securely via backend Callable Cloud Function,
  /// falling back to direct Firestore write if unavailable.
  Future<String> reportComment({
    required String commentId,
    required String? replyId,
    required String videoId,
    required String reporterId,
    required String reporterName,
    required ReportReason reason,
    String? description,
  }) async {
    try {
      final callable = functions.httpsCallable('reportCommentNested');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
        'reporterName': reporterName,
        'reason': reason.name,
        'description': description,
      });

      return commentId;
    } catch (e) {
      logger.warning(
        'Failed to report comment via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        await firestore.collection(reportsCollection).add({
          'commentId': commentId,
          'replyId': replyId,
          'videoId': videoId,
          'reporterId': reporterId,
          'reporterName': reporterName,
          'reason': reason.name,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'isResolved': false,
        });

        final commentRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId);
        final targetRef = replyId != null
            ? commentRef.collection(repliesCollection).doc(replyId)
            : commentRef;

        await targetRef.update({
          'reportCount': FieldValue.increment(1),
        });

        return commentId;
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for reportComment: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to report comment: $firestoreError');
      }
    }
  }

  /// Get reports for a comment
  Stream<List<CommentReport>> getReportsStream(String commentId) {
    return firestore
        .collection(reportsCollection)
        .where('commentId', isEqualTo: commentId)
        .where('isResolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(CommentReport.fromDocumentSnapshot).toList(),
        );
  }

  /// Get all videos with comment counts (for studio)
  Stream<List<Map<String, dynamic>>> getCreatorVideosWithCommentCounts(
    String channelId,
  ) {
    return firestore
        .collection(FirestoreCollections.videos)
        .where('channelId', isEqualTo: channelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((videoSnapshot) async {
          final videos = <Map<String, dynamic>>[];

          for (final videoDoc in videoSnapshot.docs) {
            final videoData = videoDoc.data();

            final commentsSnapshot = await videoDoc.reference
                .collection(commentsCollection)
                .count()
                .get();

            videos.add({
              'videoId': videoDoc.id,
              'title': videoData['title'] ?? '',
              'thumbnail': videoData['thumbnail'] ?? '',
              'duration': videoData['duration'] ?? 0,
              'commentCount': commentsSnapshot.count,
              'createdAt': videoData['createdAt'],
            });
          }

          return videos;
        });
  }

  /// Get comments for a video with limit (studio view)
  Stream<List<Comment>> getVideoCommentsForStudio(
    String videoId, {
    int limit = 25,
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

  /// Get initial stream of comment query snapshots for studio video comments cursor tracking
  Stream<QuerySnapshot<Map<String, dynamic>>>
      getVideoCommentsQuerySnapshotStreamForStudio(
    String videoId, {
    int limit = 25,
  }) {
    return firestore
        .collection(videosCollection)
        .doc(videoId)
        .collection(commentsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get cursor-paginated comments snapshot for studio video comments (25 per page)
  Future<QuerySnapshot<Map<String, dynamic>>>
      getVideoCommentsPageSnapshotForStudio({
    required String videoId,
    DocumentSnapshot? startAfter,
    int limit = 25,
  }) async {
    var query = firestore
        .collection(videosCollection)
        .doc(videoId)
        .collection(commentsCollection)
        .orderBy('createdAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.limit(limit).get();
  }

  /// Get comment count for a video
  Future<int> getCommentCount(String videoId) async {
    try {
      final snapshot = await firestore
          .collection(videosCollection)
          .doc(videoId)
          .collection(commentsCollection)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      logger.error('Failed to get comment count: $e', tag: 'COMMENTS');
      return 0;
    }
  }

  /// Get answered comments (comments with creator replies)
  Stream<List<Comment>> getAnsweredComments(String videoId) {
    return firestore
        .collection(videosCollection)
        .doc(videoId)
        .collection(commentsCollection)
        .where('hasCreatorReply', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Comment.fromDocumentSnapshot).toList(),
        );
  }

  /// Get unanswered comments (no creator replies)
  Stream<List<Comment>> getUnansweredComments(String videoId) {
    return firestore
        .collection(videosCollection)
        .doc(videoId)
        .collection(commentsCollection)
        .where('hasCreatorReply', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Comment.fromDocumentSnapshot).toList(),
        );
  }

  /// Get comments with sorting by likes
  Stream<List<Comment>> getCommentsSortedByLikes(String videoId) {
    return firestore
        .collection(videosCollection)
        .doc(videoId)
        .collection(commentsCollection)
        .orderBy('likeCount', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Comment.fromDocumentSnapshot).toList(),
        );
  }

  /// Mark comment as having creator reply
  Future<void> markCommentAsAnswered(String videoId, String commentId) async {
    try {
      final commentRef = firestore
          .collection(videosCollection)
          .doc(videoId)
          .collection(commentsCollection)
          .doc(commentId);
      final doc = await commentRef.get();
      if (doc.exists) {
        await commentRef.update({'hasCreatorReply': true});
      } else {
        logger.warning(
          'Cannot mark non-existent comment $commentId on video $videoId as answered',
          tag: 'COMMENTS',
        );
      }
    } catch (e) {
      logger.error('Failed to mark comment as answered: $e', tag: 'COMMENTS');
      rethrow;
    }
  }

  /// Get all video comment counts for creator dashboard
  Future<Map<String, int>> getMultipleVideoCommentCounts(
    List<String> videoIds,
  ) async {
    try {
      final counts = <String, int>{};
      await Future.wait(
        videoIds.map((videoId) async {
          final count = await getCommentCount(videoId);
          counts[videoId] = count;
        }),
      );
      return counts;
    } catch (e) {
      logger.error('Failed to get multiple video counts: $e', tag: 'COMMENTS');
      return {};
    }
  }
}
