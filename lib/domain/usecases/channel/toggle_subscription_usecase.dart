import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/channel_repository.dart';
import 'package:truthworld/domain/usecases/usecase.dart';

class ToggleSubscriptionParams {
  final String channelId;
  final String userId;

  const ToggleSubscriptionParams({
    required this.channelId,
    required this.userId,
  });
}

/// Clean architecture usecase for subscribing or unsubscribing from a channel.
class ToggleSubscriptionUseCase
    implements UseCase<void, ToggleSubscriptionParams> {
  final ChannelRepository _repository;

  const ToggleSubscriptionUseCase(this._repository);

  @override
  Future<Result<void>> call(ToggleSubscriptionParams params) {
    return _repository.toggleSubscription(params.channelId, params.userId);
  }
}
