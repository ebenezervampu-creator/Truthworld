import 'package:truthworld/core/network/result.dart';

/// Repository interface for subscription/follow operations.
///
/// Handles channel subscriptions, subscription feed,
/// and notification preferences.
abstract class SubscriptionRepository {
  /// Fetch all subscribed channels for a user.
  Future<Result<List<Map<String, dynamic>>>> getSubscriptions(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Subscribe to a channel.
  Future<Result<void>> subscribe(String userId, String channelId);

  /// Unsubscribe from a channel.
  Future<Result<void>> unsubscribe(String userId, String channelId);

  /// Check if user is subscribed to a channel.
  Future<Result<bool>> isSubscribed(String userId, String channelId);

  /// Fetch subscription feed (latest videos from subscribed channels).
  Future<Result<List<Map<String, dynamic>>>> getSubscriptionFeed(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Update notification preference for a subscription.
  Future<Result<void>> updateNotificationPreference(
    String userId,
    String channelId, {
    required String preference,
  });
}
