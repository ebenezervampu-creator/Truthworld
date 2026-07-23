import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';

/// Repository interface for channel operations.
abstract class ChannelRepository {
  /// Fetch a channel by ID.
  Future<Result<ChannelEntity>> getChannelById(String id);

  /// Fetch a channel by handle (e.g., @truthworld).
  Future<Result<ChannelEntity>> getChannelByHandle(String handle);

  /// Subscribe to a channel (toggle).
  Future<Result<void>> toggleSubscription(String channelId, String userId);

  /// Check if user is subscribed to a channel.
  Future<Result<bool>> isSubscribed(String channelId, String userId);

  /// Fetch channels the user is subscribed to.
  Future<Result<List<ChannelEntity>>> getSubscriptions(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Create a new channel.
  Future<Result<ChannelEntity>> createChannel({
    required String name,
    required String handle,
    required String ownerId,
    String? description,
  });

  /// Update channel details.
  Future<Result<void>> updateChannel(
    String channelId,
    Map<String, dynamic> updates,
  );
}
