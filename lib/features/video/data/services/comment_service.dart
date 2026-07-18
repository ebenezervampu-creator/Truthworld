import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/models/comment_report.dart';
import 'package:truthworld/core/services/logger_service.dart';


class CommentService {
  static final CommentService _instance = CommentService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection paths
  static const String _videosPath = 'videos';
  static const String _commentsPath = 'comments';
  static const String _repliesPath = 'replies';
  static const String _reportsPath = 'reports';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-south1');


  CommentService._internal();

  factory CommentService() {
    return _instance;
  }

  // ============================================================================
  // COMMENTS - CREATE, READ, UPDATE, DELETE
  // ============================================================================

  /// Add a new comment securely via backend Callable Cloud Function
  Future<String> addComment({
    required String videoId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String channelId,
    String? channelName,
    String? channelProfilePicUrl,
    required String text,
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
      final callable = _functions.httpsCallable('addCommentNested');
      final result = await callable.call({
        'videoId': videoId,
        'userName': userName,
        'userProfilePicUrl': userProfilePicUrl,
        'channelId': channelId,
        'channelName': channelName,
        'channelProfilePicUrl': channelProfilePicUrl,
        'text': text,
      });

      final data = result.data as Map<String, dynamic>;
      return data['commentId'] as String;
    } catch (e) {
      logger.warning('Failed to add comment via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final docRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
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
          hasCreatorReply: false,
        );

        await docRef.set(newComment.toMap());
        return docRef.id;
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for addComment: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to add comment: $firestoreError');
      }
    }
  }

  /// Get comments for a video with pagination
  Stream<List<Comment>> getCommentsStream({
    required String videoId,
    int limit = 20,
  }) {
    return _firestore
        .collection(_videosPath)
        .doc(videoId)
        .collection(_commentsPath)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Get single comment
  Future<Comment?> getComment(String videoId, String commentId) async {
    try {
      final doc = await _firestore
          .collection(_videosPath)
          .doc(videoId)
          .collection(_commentsPath)
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
      await _firestore
          .collection(_videosPath)
          .doc(videoId)
          .collection(_commentsPath)
          .doc(commentId)
          .update({'text': newText});
    } catch (e) {
      throw Exception('Failed to update comment: $e');
    }
  }

  /// Delete comment securely via backend Callable Cloud Function
  Future<void> deleteComment(String videoId, String commentId) async {
    try {
      final callable = _functions.httpsCallable('deleteCommentNested');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
      });
    } catch (e) {
      logger.warning('Failed to delete comment via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final repliesSnapshot = await _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId)
            .collection(_repliesPath)
            .get();

        final batch = _firestore.batch();
        for (var doc in repliesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        final commentRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId);
        batch.delete(commentRef);

        await batch.commit();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for deleteComment: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to delete comment: $firestoreError');
      }
    }
  }

  // ============================================================================
  // REPLIES - CREATE, READ, UPDATE, DELETE
  // ============================================================================

  /// Add reply securely via backend Callable Cloud Function
  Future<String> addReply({
    required String videoId,
    required String commentId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String channelId,
    String? channelName,
    String? channelProfilePicUrl,
    required String text,
  }) async {
    try {
      final callable = _functions.httpsCallable('addReplyNested');
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
      logger.warning('Failed to add reply via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final docRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId)
            .collection(_repliesPath)
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
        logger.error('Direct Firestore fallback failed for addReply: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to add reply: $firestoreError');
      }
    }
  }

  /// Get replies for a comment
  Stream<List<Reply>> getRepliesStream({
    required String videoId,
    required String commentId,
  }) {
    return _firestore
        .collection(_videosPath)
        .doc(videoId)
        .collection(_commentsPath)
        .doc(commentId)
        .collection(_repliesPath)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Reply.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Delete reply securely via backend Callable Cloud Function
  Future<void> deleteReply(
      String videoId, String commentId, String replyId) async {
    try {
      final callable = _functions.httpsCallable('deleteReplyNested');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
      });
    } catch (e) {
      logger.warning('Failed to delete reply via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        await _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId)
            .collection(_repliesPath)
            .doc(replyId)
            .delete();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for deleteReply: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to delete reply: $firestoreError');
      }
    }
  }

  // ============================================================================
  // LIKES & DISLIKES
  // ============================================================================

  /// Like comment securely via backend Callable Cloud Function
  Future<void> likeComment({
    required String videoId,
    required String commentId,
    required String userId,
    required bool asChannel,
    bool isVideoCreator = false,
    String? creatorName,
  }) async {
    try {
      final callable = _functions.httpsCallable('toggleCommentInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'interactionType': 'like',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning('Failed to like comment via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final commentRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId);

        final likeRef = commentRef.collection('likes').doc(userId);
        final dislikeRef = commentRef.collection('dislikes').doc(userId);
        
        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = _firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(commentRef, {
            'likeCount': FieldValue.increment(-1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': false,
              'creatorHeartName': FieldValue.delete(),
            }
          });
        } else {
          batch.set(likeRef, {'userId': userId, 'likedAt': FieldValue.serverTimestamp()});
          batch.update(commentRef, {
            'likeCount': FieldValue.increment(1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': true,
              'creatorHeartName': creatorName,
            }
          });
          
          if (dislikeDoc.exists) {
            batch.delete(dislikeRef);
            batch.update(commentRef, {'dislikeCount': FieldValue.increment(-1)});
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for likeComment: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to like comment: $firestoreError');
      }
    }
  }

  /// Dislike comment securely via backend Callable Cloud Function
  Future<void> dislikeComment({
    required String videoId,
    required String commentId,
    required String userId,
    required bool asChannel,
    bool isVideoCreator = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('toggleCommentInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'interactionType': 'dislike',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning('Failed to dislike comment via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final commentRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId);

        final likeRef = commentRef.collection('likes').doc(userId);
        final dislikeRef = commentRef.collection('dislikes').doc(userId);
        
        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = _firestore.batch();

        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(commentRef, {'dislikeCount': FieldValue.increment(-1)});
        } else {
          batch.set(dislikeRef, {'userId': userId, 'dislikedAt': FieldValue.serverTimestamp()});
          batch.update(commentRef, {
            'dislikeCount': FieldValue.increment(1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': false,
              'creatorHeartName': FieldValue.delete(),
            }
          });
          
          if (likeDoc.exists) {
            batch.delete(likeRef);
            batch.update(commentRef, {
              'likeCount': FieldValue.increment(-1),
              if (isVideoCreator) ...{
                'isHeartedByCreator': false,
                'creatorHeartName': FieldValue.delete(),
              }
            });
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for dislikeComment: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to dislike comment: $firestoreError');
      }
    }
  }

  /// Remove like/dislike from comment securely via backend Callable Cloud Function
  Future<void> removeCommentInteraction({
    required String videoId,
    required String commentId,
    required String userId,
    bool isVideoCreator = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('toggleCommentInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'interactionType': 'remove',
        'asChannel': false,
      });
    } catch (e) {
      logger.warning('Failed to remove comment interaction via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final commentRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId);

        final likeRef = commentRef.collection('likes').doc(userId);
        final dislikeRef = commentRef.collection('dislikes').doc(userId);
        
        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = _firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(commentRef, {
            'likeCount': FieldValue.increment(-1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': false,
              'creatorHeartName': FieldValue.delete(),
            }
          });
        }
        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(commentRef, {'dislikeCount': FieldValue.increment(-1)});
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for removeCommentInteraction: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to remove interaction: $firestoreError');
      }
    }
  }

  /// Toggle Creator Heart on a comment (Studio only)
  Future<void> heartComment({
    required String videoId,
    required String commentId,
    required bool isHearted,
    String? creatorName,
  }) async {
    try {
      await _firestore
          .collection(_videosPath)
          .doc(videoId)
          .collection(_commentsPath)
          .doc(commentId)
          .update({
        'isHeartedByCreator': isHearted,
        'creatorHeartName': isHearted ? creatorName : null,
      });
    } catch (e) {
      logger.error('Failed to heart comment: $e', tag: 'COMMENTS');
      throw Exception('Failed to heart comment: $e');
    }
  }

  /// Same methods for replies via Callable Functions
  Future<void> likeReply({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
    required bool asChannel,
  }) async {
    try {
      final callable = _functions.httpsCallable('toggleReplyInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
        'interactionType': 'like',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning('Failed to like reply via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final replyRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId)
            .collection(_repliesPath)
            .doc(replyId);

        final likeRef = replyRef.collection('likes').doc(userId);
        final dislikeRef = replyRef.collection('dislikes').doc(userId);
        
        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = _firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(replyRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          batch.set(likeRef, {'userId': userId, 'likedAt': FieldValue.serverTimestamp()});
          batch.update(replyRef, {'likeCount': FieldValue.increment(1)});
          
          if (dislikeDoc.exists) {
            batch.delete(dislikeRef);
            batch.update(replyRef, {'dislikeCount': FieldValue.increment(-1)});
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for likeReply: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to like reply: $firestoreError');
      }
    }
  }

  Future<void> dislikeReply({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
    required bool asChannel,
  }) async {
    try {
      final callable = _functions.httpsCallable('toggleReplyInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
        'interactionType': 'dislike',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning('Failed to dislike reply via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final replyRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId)
            .collection(_repliesPath)
            .doc(replyId);

        final likeRef = replyRef.collection('likes').doc(userId);
        final dislikeRef = replyRef.collection('dislikes').doc(userId);
        
        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = _firestore.batch();

        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(replyRef, {'dislikeCount': FieldValue.increment(-1)});
        } else {
          batch.set(dislikeRef, {'userId': userId, 'dislikedAt': FieldValue.serverTimestamp()});
          batch.update(replyRef, {'dislikeCount': FieldValue.increment(1)});
          
          if (likeDoc.exists) {
            batch.delete(likeRef);
            batch.update(replyRef, {'likeCount': FieldValue.increment(-1)});
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for dislikeReply: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to dislike reply: $firestoreError');
      }
    }
  }

  /// Remove like/dislike from reply via Callable Function
  Future<void> removeReplyInteraction({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('toggleReplyInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
        'interactionType': 'remove',
        'asChannel': false,
      });
    } catch (e) {
      logger.warning('Failed to remove reply interaction via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        final replyRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId)
            .collection(_repliesPath)
            .doc(replyId);

        final likeRef = replyRef.collection('likes').doc(userId);
        final dislikeRef = replyRef.collection('dislikes').doc(userId);
        
        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = _firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(replyRef, {'likeCount': FieldValue.increment(-1)});
        }
        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(replyRef, {'dislikeCount': FieldValue.increment(-1)});
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for removeReplyInteraction: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to remove reply interaction: $firestoreError');
      }
    }
  }

  // ============================================================================
  // REPORTS
  // ============================================================================

  /// Report a comment or reply securely via backend Callable Cloud Function
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
      final callable = _functions.httpsCallable('reportCommentNested');
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
      logger.warning('Failed to report comment via cloud function, falling back to direct Firestore: $e', tag: 'COMMENTS');
      try {
        await _firestore.collection(_reportsPath).add({
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

        final commentRef = _firestore
            .collection(_videosPath)
            .doc(videoId)
            .collection(_commentsPath)
            .doc(commentId);
        final targetRef = replyId != null
            ? commentRef.collection(_repliesPath).doc(replyId)
            : commentRef;

        await targetRef.update({
          'reportCount': FieldValue.increment(1),
        });

        return commentId;
      } catch (firestoreError) {
        logger.error('Direct Firestore fallback failed for reportComment: $firestoreError', tag: 'COMMENTS');
        throw Exception('Failed to report comment: $firestoreError');
      }
    }
  }

  /// Get reports for a comment
  Stream<List<CommentReport>> getReportsStream(String commentId) {
    return _firestore
        .collection(_reportsPath)
        .where('commentId', isEqualTo: commentId)
        .where('isResolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentReport.fromDocumentSnapshot(doc))
            .toList());
  }

  // ============================================================================
  // STUDIO/CREATOR QUERIES - Optimized for low latency
  // ============================================================================

  /// Get all videos with comment counts (for studio)
  Stream<List<Map<String, dynamic>>> getCreatorVideosWithCommentCounts(
      String channelId) {
    return _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((videoSnapshot) async {
      final videos = <Map<String, dynamic>>[];

      for (var videoDoc in videoSnapshot.docs) {
        final videoData = videoDoc.data();
        
        final commentsSnapshot = await videoDoc.reference
            .collection(_commentsPath)
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

  /// Get all comments for a video (studio view)
  Stream<List<Comment>> getVideoCommentsForStudio(String videoId) {
    return _firestore
        .collection(_videosPath)
        .doc(videoId)
        .collection(_commentsPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Get comment count for a video
  Future<int> getCommentCount(String videoId) async {
    try {
      final snapshot = await _firestore
          .collection(_videosPath)
          .doc(videoId)
          .collection(_commentsPath)
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
    return _firestore
        .collection(_videosPath)
        .doc(videoId)
        .collection(_commentsPath)
        .where('hasCreatorReply', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Get unanswered comments (no creator replies)
  Stream<List<Comment>> getUnansweredComments(String videoId) {
    return _firestore
        .collection(_videosPath)
        .doc(videoId)
        .collection(_commentsPath)
        .where('hasCreatorReply', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Get comments with sorting by likes
  Stream<List<Comment>> getCommentsSortedByLikes(String videoId) {
    return _firestore
        .collection(_videosPath)
        .doc(videoId)
        .collection(_commentsPath)
        .orderBy('likeCount', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Mark comment as having creator reply
  Future<void> markCommentAsAnswered(String videoId, String commentId) async {
    try {
      await _firestore
          .collection(_videosPath)
          .doc(videoId)
          .collection(_commentsPath)
          .doc(commentId)
          .update({'hasCreatorReply': true});
    } catch (e) {
      logger.error('Failed to mark comment as answered: $e', tag: 'COMMENTS');
      rethrow;
    }
  }

  /// Get all video comment counts for creator dashboard
  Future<Map<String, int>> getMultipleVideoCommentCounts(
      List<String> videoIds) async {
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




