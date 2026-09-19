import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

/// Clean architecture usecase for retrieving a single video by its unique ID.
class GetVideoByIdUseCase implements UseCase<VideoEntity, String> {
  final VideoRepository _repository;

  const GetVideoByIdUseCase(this._repository);

  @override
  Future<Result<VideoEntity>> call(String id) {
    return _repository.getVideoById(id);
  }
}
