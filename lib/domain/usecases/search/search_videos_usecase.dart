import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/search_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

class SearchVideosParams {
  final String query;
  final int limit;
  final dynamic cursor;

  const SearchVideosParams({
    required this.query,
    this.limit = 20,
    this.cursor,
  });
}

/// Clean architecture usecase for querying videos matching a search term.
class SearchVideosUseCase
    implements UseCase<List<VideoEntity>, SearchVideosParams> {
  final SearchRepository _repository;

  const SearchVideosUseCase(this._repository);

  @override
  Future<Result<List<VideoEntity>>> call(SearchVideosParams params) {
    return _repository.searchVideos(
      params.query,
      limit: params.limit,
      cursor: params.cursor,
    );
  }
}
