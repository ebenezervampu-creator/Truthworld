import 'package:truthworld/features/video/presentation/controllers/comments/comments_barrel.dart';

export 'package:truthworld/features/video/presentation/controllers/comments/comments_barrel.dart';

/// Premium Comments Controller with GetX - handles all comment-related logic.
///
/// Composed of:
/// - [CommentsStateBase]: Reactive observables, dependencies, and lifecycle management.
/// - [CommentsQueryAndSortMixin]: Repository comment streams, newest/popular/counter-argument sorting.
/// - [CommentsCrudMixin]: Comment submission, donation tracking, mentions, and deletion.
/// - [CommentInteractionsMixin]: Comment like/dislike optimistic updates, creator hearts, and notifications.
/// - [ReplyOperationsMixin]: Reply thread creation, likes, dislikes, mentions, and notifications.
class CommentsController extends CommentsStateBase
    with
        CommentsQueryAndSortMixin,
        CommentsCrudMixin,
        CommentInteractionsMixin,
        ReplyOperationsMixin {
  CommentsController({
    super.video,
    super.isOffline = false,
    super.commentsRepository,
    super.commentService,
  });
}
