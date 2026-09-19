import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';

/// Repository interface for comment operations.
abstract class CommentRepository {
  /// Fetch comments for a video with pagination.
  Future<Result<List<CommentEntity>>> getComments(
    String videoId, {
    int page = 1,
    int limit = 20,
    String sortBy = 'newest', // newest, top
    dynamic startAfter,
  });

  /// Fetch replies for a comment.
  Future<Result<List<CommentEntity>>> getReplies(
    String videoId,
    String commentId, {
    int page = 1,
    int limit = 10,
    dynamic startAfter,
  });

  /// Post a new comment.
  Future<Result<CommentEntity>> postComment({
    required String videoId,
    required String userId,
    required String text,
    String? parentId,
  });

  /// Like a comment (toggle).
  Future<Result<void>> toggleCommentLike(
    String videoId,
    String commentId,
    String userId,
  );

  /// Delete a comment (owner or video owner).
  Future<Result<void>> deleteComment(
    String videoId,
    String commentId,
  );

  /// Pin/unpin a comment (video owner only).
  Future<Result<void>> togglePinComment(
    String videoId,
    String commentId,
  );
}
