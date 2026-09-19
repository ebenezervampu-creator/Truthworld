import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
import 'package:truthworld/domain/entities/community_post_entity.dart';

abstract class CommunityRepository {
  Future<Result<List<CommunityPostEntity>>> getCommunityPosts(
    String channelId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  });

  Future<Result<CommunityPostEntity>> createPost(CommunityPostEntity post);

  Future<Result<void>> deletePost(String postId);

  Future<Result<void>> toggleLike(String postId, String userId);

  Future<Result<void>> toggleDislike(String postId, String userId);

  Future<Result<CommentEntity>> addComment(
    String postId,
    CommentEntity comment,
  );

  Future<Result<List<CommentEntity>>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  });

  Future<Result<void>> bookmarkPost(String postId, String userId);

  Future<Result<void>> reportPost(String postId, String userId, String reason);
}
