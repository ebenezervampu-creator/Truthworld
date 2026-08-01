import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
import 'package:truthworld/domain/repositories/comment_repository.dart';

class CommentRepositoryImpl extends BaseRepository
    implements CommentRepository {
  final FirebaseFirestore _firestore;

  DocumentSnapshot? _lastCommentDoc;
  DocumentSnapshot? _lastReplyDoc;

  CommentRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CommentEntity _mapToEntity(Map<String, dynamic> data, String id) {
    return CommentEntity(
      id: id,
      videoId: data['videoId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatarUrl: data['userAvatarUrl'] ?? '',
      text: data['text'] ?? '',
      likeCount: data['likeCount'] ?? 0,
      replyCount: data['replyCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPinned: data['isPinned'] ?? false,
      isEdited: data['isEdited'] ?? false,
      parentId: data['parentId'],
    );
  }

  @override
  Future<Result<List<CommentEntity>>> getComments(
    String videoId, {
    int page = 1,
    int limit = 20,
    String sortBy = 'newest',
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastCommentDoc = null;

      var q = _firestore
          .collection(FirestoreCollections.videoComments(videoId))
          .where('parentId', isNull: true);

      if (sortBy == 'top') {
        q = q
            .orderBy('likeCount', descending: true)
            .orderBy('createdAt', descending: true);
      } else {
        q = q.orderBy('createdAt', descending: true);
      }
      q = q.limit(limit);

      if (page > 1 && _lastCommentDoc != null) {
        q = q.startAfterDocument(_lastCommentDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastCommentDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => _mapToEntity(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<Result<List<CommentEntity>>> getReplies(
    String videoId,
    String commentId, {
    int page = 1,
    int limit = 10,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastReplyDoc = null;

      var q = _firestore
          .collection(FirestoreCollections.videoComments(videoId))
          .where('parentId', isEqualTo: commentId)
          .orderBy('createdAt', descending: false)
          .limit(limit);

      if (page > 1 && _lastReplyDoc != null) {
        q = q.startAfterDocument(_lastReplyDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastReplyDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => _mapToEntity(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<Result<CommentEntity>> postComment({
    required String videoId,
    required String userId,
    required String text,
    String? parentId,
  }) async {
    return safeFetch(() async {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get();
      final userData = userDoc.data() ?? {};

      final ref = _firestore
          .collection(FirestoreCollections.videoComments(videoId))
          .doc();
      final now = FieldValue.serverTimestamp();

      final data = {
        'videoId': videoId,
        'userId': userId,
        'userName': userData['displayName'] ?? userData['name'] ?? 'User',
        'userAvatarUrl': userData['photoUrl'] ?? userData['avatarUrl'] ?? '',
        'text': text,
        'parentId': parentId,
        'likeCount': 0,
        'replyCount': 0,
        'isPinned': false,
        'isEdited': false,
        'createdAt': now,
        'updatedAt': now,
      };

      await ref.set(data);

      // Update counters
      if (parentId != null) {
        await _firestore
            .collection(FirestoreCollections.videoComments(videoId))
            .doc(parentId)
            .update({'replyCount': FieldValue.increment(1)});
      }
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'commentCount': FieldValue.increment(1)});

      final doc = await ref.get();
      return _mapToEntity(doc.data()!, doc.id);
    });
  }

  @override
  Future<Result<void>> toggleCommentLike(
    String videoId,
    String commentId,
    String userId,
  ) async {
    return safeTransaction((tx) async {
      final likeRef = _firestore
          .collection(
            '${FirestoreCollections.videoComments(videoId)}/$commentId/likes',
          )
          .doc(userId);
      final commentRef = _firestore
          .collection(FirestoreCollections.videoComments(videoId))
          .doc(commentId);

      final likeDoc = await tx.get(likeRef);
      if (likeDoc.exists) {
        tx.delete(likeRef);
        tx.update(commentRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(commentRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  @override
  Future<Result<void>> deleteComment(String videoId, String commentId) async {
    return safeFetch(() async {
      final ref = _firestore
          .collection(FirestoreCollections.videoComments(videoId))
          .doc(commentId);
      final doc = await ref.get();
      final data = doc.data();

      await ref.delete();

      // Update counters
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'commentCount': FieldValue.increment(-1)});

      if (data != null && data['parentId'] != null) {
        await _firestore
            .collection(FirestoreCollections.videoComments(videoId))
            .doc(data['parentId'])
            .update({'replyCount': FieldValue.increment(-1)});
      }
    });
  }

  @override
  Future<Result<void>> togglePinComment(
    String videoId,
    String commentId,
  ) async {
    return safeFetch(() async {
      final ref = _firestore
          .collection(FirestoreCollections.videoComments(videoId))
          .doc(commentId);
      final doc = await ref.get();
      final isPinned = doc.data()?['isPinned'] ?? false;

      await ref.update({'isPinned': !isPinned});
    });
  }
}
