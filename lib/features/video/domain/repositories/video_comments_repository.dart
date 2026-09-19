import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';

/// Repository contract for video comment operations and thread management.
/// Domain pure: uses [CommentEntity], never data layer models.
abstract class VideoCommentsRepository {
  /// Stream comments for a video in real-time.
  Stream<List<CommentEntity>> streamComments(String videoId);

  /// Post a new comment to a video.
  Future<Result<CommentEntity>> postComment({
    required String videoId,
    required String text,
    required String userId,
    required String userName,
    String? userAvatar,
  });

  /// Delete a comment by ID.
  Future<Result<void>> deleteComment(String commentId);

  /// Toggle like/dislike reaction on a comment.
  Future<Result<void>> toggleCommentReaction({
    required String commentId,
    required String userId,
    required bool isLike,
  });
}
