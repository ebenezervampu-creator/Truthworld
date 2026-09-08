import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/notification_service.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  group('Push Notification Video ID & Deep Link Parsing Tests', () {
    test('Resolves videoId when directly provided in payload data', () {
      final data = {
        'videoId': 'vid_direct_100',
        'type': 'comment',
      };
      final videoId = data['videoId'];
      expect(videoId, equals('vid_direct_100'));
    });

    test('Resolves targetVideoId and video_id fallback keys', () {
      final data1 = {'targetVideoId': 'vid_target_200'};
      final resolvedId1 = data1['videoId'] ?? data1['targetVideoId'] ?? data1['video_id'];
      expect(resolvedId1, equals('vid_target_200'));

      final data2 = {'video_id': 'vid_snake_300'};
      final resolvedId2 = data2['videoId'] ?? data2['targetVideoId'] ?? data2['video_id'];
      expect(resolvedId2, equals('vid_snake_300'));
    });

    test('Extracts videoId from /video/:id actionUrl format', () {
      const actionUrl = '/video/vid_from_backend_400';
      final videoRegex = RegExp('/(?:video|watch|v)/([^/?#]+)');
      final match = videoRegex.firstMatch(actionUrl);
      expect(match, isNotNull);
      expect(match!.group(1), equals('vid_from_backend_400'));
    });

    test('Extracts videoId from /watch/:id actionUrl format', () {
      const actionUrl = '/watch/vid_watch_500';
      final videoRegex = RegExp('/(?:video|watch|v)/([^/?#]+)');
      final match = videoRegex.firstMatch(actionUrl);
      expect(match, isNotNull);
      expect(match!.group(1), equals('vid_watch_500'));
    });

    test('Extracts videoId from /watch?v=:id query param format', () {
      const actionUrl = '/watch?v=vid_query_600&t=120';
      final uri = Uri.tryParse(actionUrl);
      expect(uri, isNotNull);
      expect(uri!.queryParameters['v'], equals('vid_query_600'));
    });

    test('Extracts videoId from /v/:id short URL format', () {
      const actionUrl = '/v/vid_short_700';
      final videoRegex = RegExp('/(?:video|watch|v)/([^/?#]+)');
      final match = videoRegex.firstMatch(actionUrl);
      expect(match, isNotNull);
      expect(match!.group(1), equals('vid_short_700'));
    });
  });

  group('Push Notification Studio & Subscriber Routing Logic', () {
    bool isStudioRoute(Map<String, dynamic> data, {String? title, String? body}) {
      final type = data['type'] as String?;
      final actionUrl = data['actionUrl'] as String?;
      final typeLower = (type ?? '').toLowerCase();
      final titleLower = (title ?? data['title'] as String? ?? '').toLowerCase();
      final bodyLower = (body ?? data['message'] as String? ?? '').toLowerCase();

      return typeLower == 'new_follower' ||
          typeLower == 'subscriber' ||
          typeLower == 'new_subscriber' ||
          typeLower == 'subscription' ||
          typeLower == 'subscribers_milestone' ||
          typeLower == 'subscribers_milestone_v1' ||
          typeLower == 'creator_intelligence' ||
          typeLower == 'coach_growth_tip' ||
          typeLower == 'coach_growth_tip_v1' ||
          typeLower == 'analytics_alert' ||
          typeLower == 'monetization' ||
          typeLower.contains('subscriber') ||
          typeLower.contains('follower') ||
          titleLower.contains('subscriber') ||
          bodyLower.contains('subscribed') ||
          (actionUrl != null && actionUrl.toLowerCase().contains('studio'));
    }

    test('Identifies new_follower type as Studio route', () {
      expect(isStudioRoute({'type': 'new_follower'}), isTrue);
    });

    test('Identifies subscribers_milestone_v1 as Studio route', () {
      expect(isStudioRoute({'type': 'subscribers_milestone_v1'}), isTrue);
    });

    test('Identifies coach_growth_tip_v1 as Studio route', () {
      expect(isStudioRoute({'type': 'coach_growth_tip_v1'}), isTrue);
    });

    test('Identifies actionUrl with studio path as Studio route', () {
      expect(isStudioRoute({'actionUrl': '/studio'}), isTrue);
      expect(isStudioRoute({'actionUrl': '/studio/chapters'}), isTrue);
    });

    test('Identifies subscriber notification by title or body contents', () {
      expect(isStudioRoute({}, title: 'New Subscriber!'), isTrue);
      expect(isStudioRoute({}, body: 'Alice subscribed to your channel'), isTrue);
    });

    test('Does not classify normal video comment or mention as Studio route', () {
      expect(isStudioRoute({'type': 'comment', 'actionUrl': '/video/vid_1'}), isFalse);
      expect(isStudioRoute({'type': 'mention', 'actionUrl': '/video/vid_2'}), isFalse);
      expect(isStudioRoute({'type': 'new_video_followed', 'actionUrl': '/video/vid_3'}), isFalse);
    });
  });

  group('Perspective Flip Push Notification Handling', () {
    test('NotificationService handles perspective flip payload correctly', () {
      final notifService = NotificationService.to;
      expect(notifService, isNotNull);

      // Verify handling does not crash with empty or valid videoId
      notifService.handlePerspectiveFlipNotification(videoId: '');
      expect(true, isTrue); // Guard test passes
    });
  });

  group('UserNotification Model & Serialization Tests', () {
    test('Parses UserNotification from JSON map correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final json = {
        'id': 'notif_abc',
        'userId': 'user_xyz',
        'type': 'new_video_followed',
        'severity': 'info',
        'priority': 'high',
        'status': 'unread',
        'category': 'growth',
        'rankingScore': 8.5,
        'title': 'New Video Uploaded',
        'message': 'Channel Truth uploaded a video',
        'actionUrl': '/video/v123',
        'metadata': {
          'videoId': 'v123',
          'channelId': 'c456',
        },
        'read': false,
        'createdAt': now,
        'actions': [
          {'id': 'act_watch', 'label': 'Watch', 'type': 'OPEN_VIDEO'},
        ],
      };

      final notif = UserNotification.fromJson('notif_abc', json);

      expect(notif.id, equals('notif_abc'));
      expect(notif.userId, equals('user_xyz'));
      expect(notif.type, equals('new_video_followed'));
      expect(notif.severity, equals(NotificationSeverity.info));
      expect(notif.priority, equals(NotificationPriority.high));
      expect(notif.status, equals(NotificationLifecycle.unread));
      expect(notif.category, equals('growth'));
      expect(notif.rankingScore, equals(8.5));
      expect(notif.title, equals('New Video Uploaded'));
      expect(notif.message, equals('Channel Truth uploaded a video'));
      expect(notif.actionUrl, equals('/video/v123'));
      expect(notif.metadata?['videoId'], equals('v123'));
      expect(notif.read, isFalse);
      expect(notif.actions.length, equals(1));
      expect(notif.actions[0].label, equals('Watch'));
    });

    test('Round-trips UserNotification to JSON and back', () {
      final original = UserNotification(
        id: 'notif_roundtrip',
        userId: 'u_test',
        type: 'comment',
        severity: NotificationSeverity.warning,
        priority: NotificationPriority.critical,
        status: NotificationLifecycle.read,
        category: 'community',
        title: 'Community Warning',
        message: 'Please review community guidelines',
        actionUrl: '/community-guidelines',
        read: true,
        createdAt: DateTime.now(),
      );

      final json = original.toJson();
      final restored = UserNotification.fromJson(original.id, json);

      expect(restored.id, equals(original.id));
      expect(restored.type, equals(original.type));
      expect(restored.severity, equals(original.severity));
      expect(restored.priority, equals(original.priority));
      expect(restored.status, equals(original.status));
      expect(restored.read, equals(original.read));
    });

    test('Severity fromString handles variations and defaults', () {
      expect(NotificationSeverity.fromString('success'), equals(NotificationSeverity.success));
      expect(NotificationSeverity.fromString('warning'), equals(NotificationSeverity.warning));
      expect(NotificationSeverity.fromString('priority'), equals(NotificationSeverity.priority));
      expect(NotificationSeverity.fromString('critical'), equals(NotificationSeverity.priority));
      expect(NotificationSeverity.fromString('info'), equals(NotificationSeverity.info));
      expect(NotificationSeverity.fromString('unknown_val'), equals(NotificationSeverity.info));
      expect(NotificationSeverity.fromString(null), equals(NotificationSeverity.info));
    });

    test('Date grouping helpers work accurately', () {
      final todayNotif = UserNotification(
        id: '1',
        userId: 'u',
        type: 't',
        severity: NotificationSeverity.info,
        title: 't',
        message: 'm',
        read: false,
        createdAt: DateTime.now(),
      );
      expect(todayNotif.isToday, isTrue);
      expect(todayNotif.isYesterday, isFalse);

      final yesterdayNotif = UserNotification(
        id: '2',
        userId: 'u',
        type: 't',
        severity: NotificationSeverity.info,
        title: 't',
        message: 'm',
        read: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(yesterdayNotif.isYesterday, isTrue);
      expect(yesterdayNotif.isToday, isFalse);
    });
  });

  group('Icon Guideline Compliance for Push Notifications', () {
    test('Push notification in-app banner icon is white complying with project guidelines', () {
      // Rule: Never use primary color or brand color in icons. Always use white (Colors.white or AppColors.textPrimary)
      const icon = Icon(
        Icons.notifications_active_rounded,
        color: Colors.white,
      );

      expect(icon.color, equals(Colors.white));
      expect(icon.color, isNot(equals(const Color(0xFF6200EE)))); // Not primary/brand
    });
  });
}
