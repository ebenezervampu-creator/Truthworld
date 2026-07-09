import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationSeverity {
  info,
  success,
  warning,
  priority;

  static NotificationSeverity fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'success':
        return NotificationSeverity.success;
      case 'warning':
        return NotificationSeverity.warning;
      case 'priority':
        return NotificationSeverity.priority;
      case 'info':
      default:
        return NotificationSeverity.info;
    }
  }
}

class UserNotification {
  final String id;
  final String userId;
  final String type;
  final NotificationSeverity severity;
  final String title;
  final String message;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;
  bool read;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.actionUrl,
    this.metadata,
    required this.read,
    required this.createdAt,
  });

  factory UserNotification.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserNotification.fromJson(doc.id, data);
  }

  factory UserNotification.fromJson(String docId, Map<String, dynamic> json) {
    // Safely parse timestamp/integer time representation
    DateTime parsedTime = DateTime.now();
    final timeVal = json['createdAt'];
    if (timeVal is Timestamp) {
      parsedTime = timeVal.toDate();
    } else if (timeVal is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(timeVal);
    } else if (timeVal is String) {
      parsedTime = DateTime.tryParse(timeVal) ?? DateTime.now();
    }

    return UserNotification(
      id: docId.isNotEmpty ? docId : (json['id'] as String? ?? ''),
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? 'system_announcement',
      severity: NotificationSeverity.fromString(json['severity'] as String?),
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      actionUrl: json['actionUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      createdAt: parsedTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'severity': severity.name,
      'title': title,
      'message': message,
      'actionUrl': actionUrl,
      'metadata': metadata,
      'read': read,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// CopyWith helper for responsive GetX list manipulation
  UserNotification copyWith({
    String? id,
    String? userId,
    String? type,
    NotificationSeverity? severity,
    String? title,
    String? message,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    bool? read,
    DateTime? createdAt,
  }) {
    return UserNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get typeCategory {
    final typeLower = type.toLowerCase();
    switch (typeLower) {
      case 'system_announcement':
      case 'system':
      case 'maintenance':
      case 'security':
      case 'admin':
        return 'system';
      case 'new_video':
      case 'new_video_followed':
      case 'new_community_post':
      case 'new_video_topic':
      case 'video':
      case 'upload':
      case 'channel_update':
      case 'channel':
        return 'content';
      case 'comment':
      case 'comment_like':
      case 'comment_reply':
      case 'reply':
      case 'like':
      case 'dislike':
      case 'mention':
      case 'follow':
      case 'subscribe':
      case 'new_follower':
        return 'social';
      default:
        if (typeLower.contains('comment') ||
            typeLower.contains('reply') ||
            typeLower.contains('like') ||
            typeLower.contains('follow') ||
            typeLower.contains('subscribe') ||
            typeLower.contains('social')) {
          return 'social';
        }
        return 'other';
    }
  }
}





