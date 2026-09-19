import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/domain/entities/notification_entity.dart';

class NotificationModel {
  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.actionUrl,
    this.metadata,
  });

  factory NotificationModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final rawTitle = (data['title'] as String?)?.trim() ?? '';
    final rawMessage = (data['message'] as String?)?.trim() ?? '';

    return NotificationModel(
      id: doc.id,
      title: rawTitle.isNotEmpty ? rawTitle : 'Truthworld Notification',
      message: rawMessage.isNotEmpty ? rawMessage : 'You have a new update.',
      type: data['type'] ?? 'general',
      timestamp:
          TimestampUtils.parseToDateTime(data['timestamp']) ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
      metadata: data['metadata'],
    );
  }
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;

  /// Converts this data model to a pure domain [NotificationEntity].
  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      title: title,
      message: message,
      type: type,
      timestamp: timestamp,
      isRead: isRead,
      imageUrl: imageUrl,
      actionUrl: actionUrl,
      metadata: metadata,
    );
  }

  /// Creates a [NotificationModel] data model from a pure domain [NotificationEntity].
  static NotificationModel fromEntity(NotificationEntity entity) {
    return NotificationModel(
      id: entity.id,
      title: entity.title,
      message: entity.message,
      type: entity.type,
      timestamp: entity.timestamp,
      isRead: entity.isRead,
      imageUrl: entity.imageUrl,
      actionUrl: entity.actionUrl,
      metadata: entity.metadata,
    );
  }
}
