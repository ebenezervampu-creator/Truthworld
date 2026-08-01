import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';

abstract class CommunityRepository {
  Future<Result<List<CommunityPostModel>>> getCommunityPosts(
    String channelId, {
    int page = 1,
    int limit = 20,
  });

  Future<Result<CommunityPostModel>> createPost(CommunityPostModel post);

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
  });

  Future<Result<void>> bookmarkPost(String postId, String userId);

  Future<Result<void>> reportPost(String postId, String userId, String reason);
}
