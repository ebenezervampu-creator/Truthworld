import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/data/models/notification_model.dart';

abstract class NotificationRepository {
  Future<Result<List<NotificationModel>>> getNotifications(
    String userId, {
    int limit = 20,
    dynamic cursor,
  });

  Future<Result<void>> markAsRead(String userId, String id);

  Future<Result<void>> markAllAsRead(String userId);

  Future<Result<void>> deleteNotification(String userId, String id);
}
