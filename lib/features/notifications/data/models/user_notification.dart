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
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.priority = NotificationPriority.low,
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
    this.targetApp = 'app',
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
          .map(
            (a) => NotificationActionItem.fromJson(
              Map<String, dynamic>.from(a as Map),
            ),
          )
          .toList();
    }

    AnalyticsSnapshotData? snapData;
    if (json['analyticsSnapshot'] is Map) {
      snapData = AnalyticsSnapshotData.fromJson(
        Map<String, dynamic>.from(json['analyticsSnapshot'] as Map),
      );
    }

    final isRead = json['read'] as bool? ?? (json['status'] == 'read');

    final meta = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : null;
    final parsedSeverity = NotificationSeverity.fromString(
      json['severity'] as String? ?? json['priority'] as String?,
    );
    final rawPriority = json['priority'] as String? ??
        (meta?['priority'] as String?) ??
        (parsedSeverity == NotificationSeverity.priority
            ? 'critical'
            : (parsedSeverity == NotificationSeverity.warning ? 'high' : null));
    final rawCategory = json['category'] as String? ??
        (meta?['category'] as String?) ??
        'system';
    final rawThumb = json['thumbnailUrl'] as String? ??
        (meta?['thumbnailUrl'] as String?);
    final rawTargetApp = (json['targetApp'] as String?) ??
        (meta?['targetApp'] as String?) ??
        (meta?['app'] as String?) ??
        'app';

    return UserNotification(
      id: docId.isNotEmpty ? docId : (json['id'] as String? ?? ''),
      userId: json['userId'] as String? ?? json['creatorId'] as String? ?? '',
      type: json['type'] as String? ?? 'system_announcement',
      severity: parsedSeverity,
      priority: NotificationPriority.fromString(rawPriority),
      status: NotificationLifecycle.fromString(json['status'] as String?),
      category: rawCategory,
      rankingScore: (json['rankingScore'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      thumbnailUrl: rawThumb,
      actionUrl: json['actionUrl'] as String?,
      verificationReportId: json['verificationReportId'] as String?,
      actions: actionItems,
      analyticsSnapshot: snapData,
      metadata: meta,
      read: isRead,
      createdAt: parsedTime,
      expiresAt: expTime,
      targetApp: rawTargetApp,
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
  final String targetApp;

  /// Returns true if this notification is intended for Truthworld Creator Studio
  bool get isStudioNotification {
    final app = targetApp.toLowerCase().trim();
    final metaApp = (metadata?['targetApp'] as String? ?? metadata?['app'] as String? ?? '').toLowerCase().trim();
    if (app == 'studio' || metaApp == 'studio') return true;
    if (app == 'admin' || app == 'advertiser' || metaApp == 'admin' || metaApp == 'advertiser') return false;

    final t = type.toLowerCase().trim();
    if (t == 'fact_check_pending' ||
        t == 'fact_check_ready' ||
        t == 'fact_check_completed' ||
        t == 'verification_result' ||
        t == 'batch_verification_result' ||
        t == 'copyright_claim' ||
        t == 'claim_dispute' ||
        t == 'sub_milestone' ||
        t == 'subscribers_milestone' ||
        t == 'subscribers_milestone_v1' ||
        t == 'new_subscriber' ||
        t == 'new_follower' ||
        t == 'subscriber' ||
        t == 'subscription' ||
        t == 'view_milestone' ||
        t == 'membership_milestone' ||
        t == 'milestone_achieved' ||
        t == 'performance_insight' ||
        t == 'retention_spike' ||
        t == 'ranking_change' ||
        t == 'trust_score_change' ||
        t == 'tier_promotion' ||
        t == 'tier_downgrade' ||
        t == 'inactivity_warning' ||
        t == 'performance_warning' ||
        t == 'weekly_digest' ||
        t == 'creator_coach_insight' ||
        t == 'creator_motivation' ||
        t == 'coach_growth_tip' ||
        t == 'coach_growth_tip_v1' ||
        t == 'analytics_alert' ||
        t == 'monetization' ||
        t == 'monetization_revenue' ||
        t == 'monetization_payout' ||
        t == 'channel_notifications' ||
        t == 'studio_notifications' ||
        t.contains('studio') ||
        t.contains('fact_check') ||
        t.contains('verification') ||
        t.contains('milestone') ||
        t.contains('monetization') ||
        t.contains('coach')) {
      return true;
    }

    final cat = (category.isNotEmpty ? category : (metadata?['category'] as String? ?? '')).toLowerCase().trim();
    if (cat == 'verification' ||
        cat == 'monetization' ||
        cat == 'analytics' ||
        cat == 'growth' ||
        cat == 'education') {
      return true;
    }

    final action = (actionUrl ?? '').toLowerCase().trim();
    if (action.contains('studio') ||
        action.startsWith('/subscribers') ||
        action.startsWith('/views') ||
        action.startsWith('/watchtime') ||
        action.startsWith('/analytics') ||
        action.startsWith('/copyright') ||
        action.startsWith('/monetization') ||
        action.startsWith('/revenue') ||
        action.startsWith('/payout') ||
        action.startsWith('/saved-community-posts')) {
      return true;
    }

    final titleLower = title.toLowerCase().trim();
    final messageLower = message.toLowerCase().trim();

    final isStudioTitle = titleLower.contains('truth verification') ||
        titleLower.contains('fact-checking') ||
        titleLower.contains('fact check') ||
        titleLower.contains('video moderation') ||
        titleLower.contains('thumbnail verification') ||
        titleLower.contains('video not accepted') ||
        titleLower.contains('video under manual review') ||
        titleLower.contains('video processing') ||
        titleLower.contains('video approved & published') ||
        titleLower.contains('new subscriber') ||
        titleLower.contains('creator studio') ||
        titleLower.contains('channel policy') ||
        titleLower.contains('copyright claim') ||
        titleLower.contains('claim dispute');

    final isStudioMessage = messageLower.contains('studio notifications') ||
        messageLower.contains('creator studio') ||
        messageLower.contains('fact-checking for') ||
        messageLower.contains('held in studio') ||
        messageLower.contains('subscribed to your channel');

    return isStudioTitle || isStudioMessage;
  }

  /// Returns true if this notification is intended for the Consumer App
  bool get isConsumerNotification {
    final app = targetApp.toLowerCase().trim();
    final metaApp = (metadata?['targetApp'] as String? ?? metadata?['app'] as String? ?? '').toLowerCase().trim();
    if (app == 'studio' || app == 'admin' || app == 'advertiser' ||
        metaApp == 'studio' || metaApp == 'admin' || metaApp == 'advertiser') {
      return false;
    }
    if (isStudioNotification) return false;
    final action = (actionUrl ?? '').toLowerCase().trim();
    if (action.contains('studio') ||
        action.startsWith('/admin') ||
        action.startsWith('/advertiser') ||
        action.startsWith('/ads')) {
      return false;
    }
    return true;
  }

  String get typeCategory => category;

  String get channelId => (metadata?['channelId'] as String?) ?? '';

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
      'targetApp': targetApp,
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
    String? targetApp,
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
      targetApp: targetApp ?? this.targetApp,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return createdAt.year == yesterday.year &&
        createdAt.month == yesterday.month &&
        createdAt.day == yesterday.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays <= 7 && !isToday && !isYesterday;
  }
}
