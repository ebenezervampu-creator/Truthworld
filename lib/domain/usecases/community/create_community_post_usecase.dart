import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/community_post_entity.dart';
import 'package:truthworld/domain/repositories/community_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

/// Clean Architecture use case for publishing a community post.
class CreateCommunityPostUseCase
    implements UseCase<CommunityPostEntity, CommunityPostEntity> {
  final CommunityRepository _repository;

  const CreateCommunityPostUseCase(this._repository);

  @override
  Future<Result<CommunityPostEntity>> call(CommunityPostEntity post) {
    return _repository.createPost(post);
  }
}
