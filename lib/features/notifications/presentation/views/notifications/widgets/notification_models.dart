import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Unified model representing either a video upload notification or a user alert notification.
class UnifiedNotificationItem {
  const UnifiedNotificationItem({
    required this.timestamp,
    required this.isSeen,
    this.video,
    this.alert,
  });

  final Video? video;
  final UserNotification? alert;
  final DateTime timestamp;
  final bool isSeen;
}
