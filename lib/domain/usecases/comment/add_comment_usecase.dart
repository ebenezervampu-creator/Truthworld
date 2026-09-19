import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
import 'package:truthworld/domain/repositories/comment_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

class AddCommentParams {
  final String videoId;
  final String userId;
  final String text;
  final String? parentId;

  const AddCommentParams({
    required this.videoId,
    required this.userId,
    required this.text,
    this.parentId,
  });
}

/// Clean Architecture use case for posting a comment or reply to a video.
class AddCommentUseCase implements UseCase<CommentEntity, AddCommentParams> {
  final CommentRepository _repository;

  const AddCommentUseCase(this._repository);

  @override
  Future<Result<CommentEntity>> call(AddCommentParams params) {
    return _repository.postComment(
      videoId: params.videoId,
      userId: params.userId,
      text: params.text,
      parentId: params.parentId,
    );
  }
}
