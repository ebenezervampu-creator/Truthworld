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
      case 'critical':
        return NotificationSeverity.priority;
      case 'info':
      default:
        return NotificationSeverity.info;
    }
  }
}

enum NotificationPriority {
  critical,
  high,
  medium,
  low;

  static NotificationPriority fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'critical':
        return NotificationPriority.critical;
      case 'high':
        return NotificationPriority.high;
      case 'medium':
        return NotificationPriority.medium;
      case 'low':
      default:
        return NotificationPriority.low;
    }
  }
}

enum NotificationLifecycle {
  newStatus,
  delivered,
  unread,
  read,
  archived,
  dismissed,
  expired;

  static NotificationLifecycle fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'new':
        return NotificationLifecycle.newStatus;
      case 'delivered':
        return NotificationLifecycle.delivered;
      case 'read':
        return NotificationLifecycle.read;
      case 'archived':
        return NotificationLifecycle.archived;
      case 'dismissed':
        return NotificationLifecycle.dismissed;
      case 'expired':
        return NotificationLifecycle.expired;
      case 'unread':
      default:
        return NotificationLifecycle.unread;
    }
  }
}

class NotificationActionItem {

  NotificationActionItem({
    required this.id,
    required this.label,
    required this.type,
    this.payload,
  });

  factory NotificationActionItem.fromJson(Map<String, dynamic> json) {
    return NotificationActionItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Action',
      type: json['type'] as String? ?? 'OPEN_ANALYTICS',
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }
  final String id;
  final String label;
  final String type;
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'payload': payload,
      };
}

class AnalyticsSnapshotData {

  AnalyticsSnapshotData({
    required this.views,
    required this.subscribers,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.watchHours,
    required this.ctr,
    required this.avd,
    required this.subscriberDelta,
    required this.snapshotAt,
  });

  factory AnalyticsSnapshotData.fromJson(Map<String, dynamic> json) {
    var time = DateTime.now();
    final val = json['snapshotAt'];
    if (val is int) {
      time = DateTime.fromMillisecondsSinceEpoch(val);
    } else if (val is Timestamp) {
      time = val.toDate();
    }
    return AnalyticsSnapshotData(
      views: (json['views'] as num?)?.toInt() ?? 0,
      subscribers: (json['subscribers'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      watchHours: (json['watchHours'] as num?)?.toDouble() ?? 0.0,
      ctr: (json['ctr'] as num?)?.toDouble() ?? 0.0,
      avd: (json['avd'] as num?)?.toDouble() ?? 0.0,
      subscriberDelta: (json['subscriberDelta'] as num?)?.toInt() ?? 0,
      snapshotAt: time,
    );
  }
  final int views;
  final int subscribers;
  final int likes;
  final int comments;
  final int shares;
  final double watchHours;
  final double ctr;
  final double avd;
  final int subscriberDelta;
  final DateTime snapshotAt;

  Map<String, dynamic> toJson() => {
        'views': views,
        'subscribers': subscribers,
        'likes': likes,
        'comments': comments,
        'shares': shares,
        'watchHours': watchHours,
        'ctr': ctr,
        'avd': avd,
        'subscriberDelta': subscriberDelta,
        'snapshotAt': snapshotAt.millisecondsSinceEpoch,
      };
}

class UserNotification {

  UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.severity,
    required this.title, required this.message, required this.read, required this.createdAt, this.priority = NotificationPriority.low,
    this.status = NotificationLifecycle.unread,
    this.category = 'system',
    this.rankingScore = 0.0,
    this.thumbnailUrl,
    this.actionUrl,
    this.verificationReportId,
    this.actions = const [],
    this.analyticsSnapshot,
    this.metadata,
    this.expiresAt,
  });

  factory UserNotification.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserNotification.fromJson(doc.id, data);
  }

  factory UserNotification.fromJson(String docId, Map<String, dynamic> json) {
    var parsedTime = DateTime.now();
    final timeVal = json['createdAt'];
    if (timeVal is Timestamp) {
      parsedTime = timeVal.toDate();
    } else if (timeVal is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(timeVal);
    } else if (timeVal is String) {
      parsedTime = DateTime.tryParse(timeVal) ?? DateTime.now();
    }

    DateTime? expTime;
    final expVal = json['expiresAt'];
    if (expVal is Timestamp) {
      expTime = expVal.toDate();
    } else if (expVal is int) {
      expTime = DateTime.fromMillisecondsSinceEpoch(expVal);
    }

    var actionItems = <NotificationActionItem>[];
    if (json['actions'] is List) {
      actionItems = (json['actions'] as List)
          .map((a) => NotificationActionItem.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList();
    }

    AnalyticsSnapshotData? snapData;
    if (json['analyticsSnapshot'] is Map) {
      snapData = AnalyticsSnapshotData.fromJson(Map<String, dynamic>.from(json['analyticsSnapshot'] as Map));
    }

    final isRead = json['read'] as bool? ?? (json['status'] == 'read');

    return UserNotification(
      id: docId.isNotEmpty ? docId : (json['id'] as String? ?? ''),
      userId: json['userId'] as String? ?? json['creatorId'] as String? ?? '',
      type: json['type'] as String? ?? 'system_announcement',
      severity: NotificationSeverity.fromString(json['severity'] as String? ?? json['priority'] as String?),
      priority: NotificationPriority.fromString(json['priority'] as String?),
      status: NotificationLifecycle.fromString(json['status'] as String?),
      category: json['category'] as String? ?? 'system',
      rankingScore: (json['rankingScore'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      actionUrl: json['actionUrl'] as String?,
      verificationReportId: json['verificationReportId'] as String?,
      actions: actionItems,
      analyticsSnapshot: snapData,
      metadata: json['metadata'] as Map<String, dynamic>?,
      read: isRead,
      createdAt: parsedTime,
      expiresAt: expTime,
    );
  }
  final String id;
  final String userId;
  final String type;
  final NotificationSeverity severity;
  final NotificationPriority priority;
  final NotificationLifecycle status;
  final String category;
  final double rankingScore;
  final String title;
  final String message;
  final String? thumbnailUrl;
  final String? actionUrl;
  final String? verificationReportId;
  final List<NotificationActionItem> actions;
  final AnalyticsSnapshotData? analyticsSnapshot;
  final Map<String, dynamic>? metadata;
  bool read;
  final DateTime createdAt;
  final DateTime? expiresAt;

  String get typeCategory => category;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'severity': severity.name,
      'priority': priority.name,
      'status': status.name,
      'category': category,
      'rankingScore': rankingScore,
      'title': title,
      'message': message,
      'thumbnailUrl': thumbnailUrl,
      'actionUrl': actionUrl,
      'verificationReportId': verificationReportId,
      'actions': actions.map((a) => a.toJson()).toList(),
      'analyticsSnapshot': analyticsSnapshot?.toJson(),
      'metadata': metadata,
      'read': read,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
    };
  }

  UserNotification copyWith({
    String? id,
    String? userId,
    String? type,
    NotificationSeverity? severity,
    NotificationPriority? priority,
    NotificationLifecycle? status,
    String? category,
    double? rankingScore,
    String? title,
    String? message,
    String? thumbnailUrl,
    String? actionUrl,
    String? verificationReportId,
    List<NotificationActionItem>? actions,
    AnalyticsSnapshotData? analyticsSnapshot,
    Map<String, dynamic>? metadata,
    bool? read,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return UserNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      rankingScore: rankingScore ?? this.rankingScore,
      title: title ?? this.title,
      message: message ?? this.message,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      verificationReportId: verificationReportId ?? this.verificationReportId,
      actions: actions ?? this.actions,
      analyticsSnapshot: analyticsSnapshot ?? this.analyticsSnapshot,
      metadata: metadata ?? this.metadata,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return createdAt.year == yesterday.year && createdAt.month == yesterday.month && createdAt.day == yesterday.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays <= 7 && !isToday && !isYesterday;
  }
}
