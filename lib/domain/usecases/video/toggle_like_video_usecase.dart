import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

class ToggleLikeVideoParams {
  final String videoId;
  final String userId;

  const ToggleLikeVideoParams({
    required this.videoId,
    required this.userId,
  });
}

/// Clean Architecture use case for toggling like engagement on a video.
class ToggleLikeVideoUseCase implements UseCase<void, ToggleLikeVideoParams> {
  final VideoRepository _repository;

  const ToggleLikeVideoUseCase(this._repository);

  @override
  Future<Result<void>> call(ToggleLikeVideoParams params) {
    return _repository.toggleLike(params.videoId, params.userId);
  }
}
