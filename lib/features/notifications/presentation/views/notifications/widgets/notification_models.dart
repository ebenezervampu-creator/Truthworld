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

/// Category tab descriptor representing notification filtering segments.
class NotificationTab {
  const NotificationTab({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;

  static const all = NotificationTab(id: 'all', title: 'All');
  static const verifications = NotificationTab(id: 'verifications', title: 'Verifications');
  static const studioAlerts = NotificationTab(id: 'studio_alerts', title: 'Studio Alerts');
  static const topics = NotificationTab(id: 'topics', title: 'Topics');
  static const comments = NotificationTab(id: 'comments', title: 'Comments');
  static const mentions = NotificationTab(id: 'mentions', title: 'Mentions');
}
