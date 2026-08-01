import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
import 'package:truthworld/domain/repositories/community_repository.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';

class CommunityRepositoryImpl extends BaseRepository
    implements CommunityRepository {
  final FirebaseFirestore _firestore;

  DocumentSnapshot? _lastPostDoc;
  DocumentSnapshot? _lastCommentDoc;

  CommunityRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<CommunityPostModel>>> getCommunityPosts(
    String channelId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastPostDoc = null;

      var q = _firestore
          .collection(FirestoreCollections.community)
          .where('channelId', isEqualTo: channelId)
          .orderBy('uploadedAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastPostDoc != null) {
        q = q.startAfterDocument(_lastPostDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastPostDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => CommunityPostModel.fromMap(doc.data()))
          .toList();
    });
  }

  @override
  Future<Result<CommunityPostModel>> createPost(CommunityPostModel post) async {
    return safeFetch(() async {
      final docRef = _firestore
          .collection(FirestoreCollections.community)
          .doc();
      final data = post.toMap();
      data['id'] = docRef.id;

      await docRef.set(data);
      final doc = await docRef.get();
      return CommunityPostModel.fromMap(doc.data()!);
    });
  }

  @override
  Future<Result<void>> deletePost(String postId) async {
    return safeDelete(
      _firestore.collection(FirestoreCollections.community).doc(postId),
    );
  }

  @override
  Future<Result<void>> toggleLike(String postId, String userId) async {
    return safeTransaction((tx) async {
      final postRef = _firestore
          .collection(FirestoreCollections.community)
          .doc(postId);
      final likeRef = _firestore
          .collection(FirestoreCollections.communityLikes(postId))
          .doc(userId);

      final likeDoc = await tx.get(likeRef);
      if (likeDoc.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {
          'likes': FieldValue.increment(-1),
          'likedby': FieldValue.arrayRemove([userId]),
        });
      } else {
        tx.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {
          'likes': FieldValue.increment(1),
          'likedby': FieldValue.arrayUnion([userId]),
        });
      }
    });
  }

  @override
  Future<Result<void>> toggleDislike(String postId, String userId) async {
    return safeTransaction((tx) async {
      final postRef = _firestore
          .collection(FirestoreCollections.community)
          .doc(postId);
      final dislikeRef = _firestore
          .collection(FirestoreCollections.communityDislikes(postId))
          .doc(userId);

      final dislikeDoc = await tx.get(dislikeRef);
      if (dislikeDoc.exists) {
        tx.delete(dislikeRef);
        tx.update(postRef, {
          'dislikes': FieldValue.increment(-1),
          'dislikedby': FieldValue.arrayRemove([userId]),
        });
      } else {
        tx.set(dislikeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {
          'dislikes': FieldValue.increment(1),
          'dislikedby': FieldValue.arrayUnion([userId]),
        });
      }
    });
  }

  @override
  Future<Result<CommentEntity>> addComment(
    String postId,
    CommentEntity comment,
  ) async {
    return safeFetch(() async {
      final docRef = _firestore
          .collection(FirestoreCollections.communityComments(postId))
          .doc();
      final now = FieldValue.serverTimestamp();

      final data = {
        'id': docRef.id,
        'videoId': postId, // Assuming videoId conceptually means parent item ID
        'userId': comment.userId,
        'userName': comment.userName,
        'userAvatarUrl': comment.userAvatarUrl,
        'text': comment.text,
        'likeCount': 0,
        'replyCount': 0,
        'isPinned': false,
        'isEdited': false,
        'createdAt': now,
        'updatedAt': now,
      };

      await docRef.set(data);
      await _firestore
          .collection(FirestoreCollections.community)
          .doc(postId)
          .update({'commentCount': FieldValue.increment(1)});

      final doc = await docRef.get();
      return CommentEntity(
        id: docRef.id,
        videoId: postId,
        userId: comment.userId,
        userName: comment.userName,
        userAvatarUrl: comment.userAvatarUrl,
        text: comment.text,
        createdAt: DateTime.now(), // or from doc if parsed
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<Result<List<CommentEntity>>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastCommentDoc = null;

      var q = _firestore
          .collection(FirestoreCollections.communityComments(postId))
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastCommentDoc != null) {
        q = q.startAfterDocument(_lastCommentDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastCommentDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CommentEntity(
          id: doc.id,
          videoId: data['videoId'] ?? postId,
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? '',
          userAvatarUrl: data['userAvatarUrl'] ?? '',
          text: data['text'] ?? '',
          likeCount: data['likeCount'] ?? 0,
          replyCount: data['replyCount'] ?? 0,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isPinned: data['isPinned'] ?? false,
          isEdited: data['isEdited'] ?? false,
          parentId: data['parentId'],
        );
      }).toList();
    });
  }

  @override
  Future<Result<void>> bookmarkPost(String postId, String userId) async {
    return safeFetch(() async {
      final ref = _firestore
          .collection(FirestoreCollections.userBookmarks(userId))
          .doc(postId);
      await ref.set({
        'postId': postId,
        'type': 'community',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<Result<void>> reportPost(
    String postId,
    String userId,
    String reason,
  ) async {
    return safeFetch(() async {
      await _firestore.collection(FirestoreCollections.reports).add({
        'targetId': postId,
        'targetType': 'community_post',
        'reporterId': userId,
        'reason': reason,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
