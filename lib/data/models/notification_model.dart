import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;

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
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      timestamp: TimestampUtils.parseToDateTime(data['timestamp']) ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
      metadata: data['metadata'],
    );
  }
}





