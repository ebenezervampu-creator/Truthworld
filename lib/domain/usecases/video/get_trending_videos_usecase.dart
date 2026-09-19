import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/trending_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

class GetTrendingVideosParams {
  final int page;
  final int limit;
  final String? country;
  final String? category;

  const GetTrendingVideosParams({
    this.page = 1,
    this.limit = 20,
    this.country,
    this.category,
  });
}

/// Use case to retrieve trending videos from the repository according to clean architecture principles.
class GetTrendingVideosUseCase
    implements UseCase<List<VideoEntity>, GetTrendingVideosParams> {
  final TrendingRepository _repository;

  const GetTrendingVideosUseCase(this._repository);

  @override
  Future<Result<List<VideoEntity>>> call(
    GetTrendingVideosParams params,
  ) {
    return _repository.getTrendingVideos(
      page: params.page,
      limit: params.limit,
      country: params.country,
      category: params.category,
    );
  }
}
