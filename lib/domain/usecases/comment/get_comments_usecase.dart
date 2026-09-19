import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
import 'package:truthworld/domain/repositories/comment_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

class GetCommentsParams {
  final String videoId;
  final int page;
  final int limit;
  final String sortBy;
  final dynamic startAfter;

  const GetCommentsParams({
    required this.videoId,
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'newest',
    this.startAfter,
  });
}

/// Clean Architecture use case for retrieving paginated comments for a video.
class GetCommentsUseCase implements UseCase<List<CommentEntity>, GetCommentsParams> {
  final CommentRepository _repository;

  const GetCommentsUseCase(this._repository);

  @override
  Future<Result<List<CommentEntity>>> call(GetCommentsParams params) {
    return _repository.getComments(
      params.videoId,
      page: params.page,
      limit: params.limit,
      sortBy: params.sortBy,
      startAfter: params.startAfter,
    );
  }
}
