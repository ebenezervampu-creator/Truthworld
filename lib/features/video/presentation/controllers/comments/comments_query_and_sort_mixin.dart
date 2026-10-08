import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/controllers/comments/comments_state_base.dart';

/// Mixin handling comment streaming, repository access, sorting, and user interaction caching.
mixin CommentsQueryAndSortMixin on CommentsStateBase {
  Stream<List<Comment>> streamCommentsRepo(String videoId) {
    return commentsRepository
        .streamComments(videoId)
        .map((entities) => entities.map(Comment.fromEntity).toList());
  }

  @override
  void sortComments(bool newest) {
    isSortNewest.value = newest;
    isCounterArgumentFlipped.value = false;
    if (newest) {
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      comments.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }
  }

  void toggleCounterArgumentSort() {
    isCounterArgumentFlipped.value = !isCounterArgumentFlipped.value;
    if (isCounterArgumentFlipped.value) {
      const contrastKeywords = [
        'however',
        'disagree',
        'perspective',
        'contrary',
        'evidence',
      ];

      // O(N) precomputation pass: memoize contrast match per comment to avoid
      // repeated string lowercasing and substring search inside O(N log N) comparator.
      final contrastMap = <String, bool>{};
      for (final comment in comments) {
        final text = comment.text.toLowerCase();
        var hasContrast = false;
        for (final kw in contrastKeywords) {
          if (text.contains(kw)) {
            hasContrast = true;
            break;
          }
        }
        contrastMap[comment.id] = hasContrast;
      }

      comments.sort((a, b) {
        final contrastA = contrastMap[a.id] ?? false;
        final contrastB = contrastMap[b.id] ?? false;

        if (contrastA && !contrastB) return -1;
        if (!contrastA && contrastB) return 1;
        return b.likeCount.compareTo(a.likeCount);
      });
    } else {
      sortComments(isSortNewest.value);
    }
  }

  Future<void> loadUserInteractions() async {
    if (currentUserId.isEmpty || video == null) return;

    try {
      final commentInteractSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('comment_interactions')
          .where('videoId', isEqualTo: video!.id)
          .get();

      for (final doc in commentInteractSnap.docs) {
        final data = doc.data();
        final type = data['type'];
        final commentId = doc.id;
        userCommentInteractions[commentId] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }

      final replyInteractSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('reply_interactions')
          .where('videoId', isEqualTo: video!.id)
          .get();

      for (final doc in replyInteractSnap.docs) {
        final data = doc.data();
        final type = data['type'];
        final replyId = doc.id;
        userCommentInteractions[replyId] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentsController.loadUserInteractions',
      );
    }
  }

  @override
  void initializeComments() {
    if (video == null || video!.id.isEmpty) return;

    // Load user interactions in background
    loadUserInteractions();

    isLoadingComments.value = true;
    hasMoreComments.value = true;
    lastCommentDoc = null;

    // Stream initial 25 comments
    trackSubscription(commentService
        .getCommentsQuerySnapshotStream(
          videoId: video!.id,
        )
        .listen(
          (snapshot) async {
            if (snapshot.docs.isNotEmpty) {
              lastCommentDoc = snapshot.docs.last;
            }
            final loadedComments =
                snapshot.docs.map(Comment.fromDocumentSnapshot).toList();

            final targetId = targetCommentId.value;
            if (targetId != null && targetId.isNotEmpty) {
              final containsTarget = loadedComments.any(
                (c) => c.id == targetId,
              );
              if (!containsTarget) {
                try {
                  final targetComment = await commentService.getComment(
                    video!.id,
                    targetId,
                  );
                  if (targetComment != null) {
                    loadedComments.insert(0, targetComment);
                  }
                } catch (e, stackTrace) {
                  ErrorHandler.log(
                    e,
                    stackTrace: stackTrace,
                    tag: 'CommentsController.initializeComments.deepLink',
                  );
                }
              }
            }

            final seenIds = <String>{};
            final deduplicated =
                loadedComments.where((c) => seenIds.add(c.id)).toList();

            // Preserve loaded paged comments if more than first page is already loaded
            if (comments.length > CommentsStateBase.commentsPerPage) {
              final firstPageIds = deduplicated.map((c) => c.id).toSet();
              final tail =
                  comments.where((c) => !firstPageIds.contains(c.id)).toList();
              comments.value = [...deduplicated, ...tail];
            } else {
              comments.value = deduplicated;
            }

            sortComments(isSortNewest.value);
            isLoadingComments.value = false;
            hasMoreComments.value =
                snapshot.docs.length >= CommentsStateBase.commentsPerPage;
            commentsError.value = null;
          },
          onError: (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'CommentsController.initializeComments',
            );
            commentsError.value =
                AppException.from(e, stackTrace).displayMessage;
            isLoadingComments.value = false;
          },
        ));
  }

  @override
  Future<void> loadMoreComments() async {
    if (video == null ||
        isLoadingMoreComments.value ||
        !hasMoreComments.value ||
        lastCommentDoc == null) {
      return;
    }

    try {
      isLoadingMoreComments.value = true;
      final nextSnap = await commentService.getCommentsPageSnapshot(
        videoId: video!.id,
        startAfter: lastCommentDoc,
      );

      if (nextSnap.docs.isNotEmpty) {
        lastCommentDoc = nextSnap.docs.last;
        final nextComments =
            nextSnap.docs.map(Comment.fromDocumentSnapshot).toList();

        final currentIds = comments.map((c) => c.id).toSet();
        for (final c in nextComments) {
          if (currentIds.add(c.id)) {
            comments.add(c);
          }
        }
        sortComments(isSortNewest.value);
      }

      hasMoreComments.value =
          nextSnap.docs.length >= CommentsStateBase.commentsPerPage;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentsController.loadMoreComments',
      );
    } finally {
      isLoadingMoreComments.value = false;
    }
  }
}
