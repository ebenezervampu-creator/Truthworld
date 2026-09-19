import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';
import 'package:truthworld/domain/repositories/channel_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

/// Clean architecture usecase for retrieving channel metadata by channel ID.
class GetChannelByIdUseCase implements UseCase<ChannelEntity, String> {
  final ChannelRepository _repository;

  const GetChannelByIdUseCase(this._repository);

  @override
  Future<Result<ChannelEntity>> call(String channelId) {
    return _repository.getChannelById(channelId);
  }
}
