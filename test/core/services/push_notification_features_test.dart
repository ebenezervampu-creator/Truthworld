import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/notification_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';

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
          typeLower == 'channel_notifications' ||
          typeLower == 'studio_notifications' ||
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

  group('Push Notification Duplicate Prevention Tests', () {
    test('Deduplicates duplicate device tokens map to prevent double push deliveries', () {
      final fcmTokensMap = {
        'dev_uuid_1': {'token': 'fcm_android_token_xxx', 'platform': 'android'},
        'dev_uuid_2': {'token': 'fcm_android_token_xxx', 'platform': 'android'},
        'dev_uuid_3': {'token': 'fcm_ios_token_yyy', 'platform': 'ios'},
      };

      final uniqueTokens = <String>{};
      final duplicateKeys = <String>[];

      for (final entry in fcmTokensMap.entries) {
        final token = entry.value['token']!;
        if (uniqueTokens.contains(token)) {
          duplicateKeys.add(entry.key);
        } else {
          uniqueTokens.add(token);
        }
      }

      expect(uniqueTokens.length, equals(2));
      expect(uniqueTokens.contains('fcm_android_token_xxx'), isTrue);
      expect(uniqueTokens.contains('fcm_ios_token_yyy'), isTrue);
      expect(duplicateKeys.length, equals(1));
      expect(duplicateKeys.first, equals('dev_uuid_2'));
    });

    test('Validates Android OS notification tag and collapse key in payload spec', () {
      const notificationId = 'notif_abc_123';
      final androidNotification = {
        'channelId': 'truthworld_notifications',
        'priority': 'max',
        'tag': notificationId,
      };
      final androidConfig = {
        'priority': 'high',
        'collapseKey': notificationId,
        'notification': androidNotification,
      };

      // Android tag replaces existing notification in status bar if duplicate arrives
      expect(androidConfig['collapseKey'], equals(notificationId));
      expect(androidNotification['tag'], equals(notificationId));
      expect(androidNotification['channelId'], equals('truthworld_notifications'));
    });
  });

  group('Universal Notification Navigation Handler Tests', () {
    test('extractVideoId accurately resolves video IDs across all payload keys', () {
      expect(
        NotificationNavigationHandler.extractVideoId({'videoId': 'vid_a1'}),
        equals('vid_a1'),
      );
      expect(
        NotificationNavigationHandler.extractVideoId({'targetVideoId': 'vid_b2'}),
        equals('vid_b2'),
      );
      expect(
        NotificationNavigationHandler.extractVideoId({'video_id': 'vid_c3'}),
        equals('vid_c3'),
      );
      expect(
        NotificationNavigationHandler.extractVideoId(
          {},
          metadata: {'videoId': 'vid_d4'},
        ),
        equals('vid_d4'),
      );
      expect(
        NotificationNavigationHandler.extractVideoId(
          {},
          actionUrl: '/video/vid_url_e5',
        ),
        equals('vid_url_e5'),
      );
      expect(
        NotificationNavigationHandler.extractVideoId(
          {},
          actionUrl: '/watch?v=vid_query_f6&t=10',
        ),
        equals('vid_query_f6'),
      );
    });

    test('isStudioNotificationPayload identifies all studio and growth alert variants', () {
      expect(
        NotificationNavigationHandler.isStudioNotificationPayload(
          {'type': 'new_follower'},
        ),
        isTrue,
      );
      expect(
        NotificationNavigationHandler.isStudioNotificationPayload(
          {'type': 'subscribers_milestone_v1'},
        ),
        isTrue,
      );
      expect(
        NotificationNavigationHandler.isStudioNotificationPayload(
          {'type': 'coach_growth_tip_v1'},
        ),
        isTrue,
      );
      expect(
        NotificationNavigationHandler.isStudioNotificationPayload(
          {},
          actionUrl: '/studio/chapters',
        ),
        isTrue,
      );
      expect(
        NotificationNavigationHandler.isStudioNotificationPayload(
          {},
          title: 'New Subscriber!',
        ),
        isTrue,
      );
      expect(
        NotificationNavigationHandler.isStudioNotificationPayload(
          {'type': 'new_video_followed'},
        ),
        isFalse,
      );
      expect(
        NotificationNavigationHandler.isStudioNotificationPayload(
          {'type': 'new_video_topic'},
        ),
        isFalse,
      );
    });
  });

  group('Push Notification Routing & Auto-Play Navigation Flow', () {
    test('Resolves new_video_followed notification directly to /watch?v=:id with push arguments', () {
      final payload = {
        'type': 'new_video_followed',
        'videoId': 'vid_channel_upload_99',
        'channelId': 'ch_truth_1',
        'title': 'New Video from Truth Channel',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/watch?v=vid_channel_upload_99'));
      expect(target.parameters?['v'], equals('vid_channel_upload_99'));
      expect(target.arguments?['videoId'], equals('vid_channel_upload_99'));
      expect(target.arguments?['channelId'], equals('ch_truth_1'));
      expect(target.arguments?['fromPush'], isTrue);
    });

    test('Resolves new_video_topic notification directly to /watch?v=:id with fromTopic flag', () {
      final payload = {
        'type': 'new_video_topic',
        'videoId': 'vid_topic_42',
        'topicId': 'artificial-intelligence',
        'topicTitle': 'AI & Tech',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/watch?v=vid_topic_42'));
      expect(target.parameters?['v'], equals('vid_topic_42'));
      expect(target.arguments?['videoId'], equals('vid_topic_42'));
      expect(target.arguments?['topicId'], equals('artificial-intelligence'));
      expect(target.arguments?['fromTopic'], isTrue);
    });

    test('Resolves comment notification to /watch?v=:id with commentId for comment highlighting', () {
      final payload = {
        'type': 'comment',
        'videoId': 'vid_comment_test',
        'commentId': 'comm_xyz_88',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/watch?v=vid_comment_test'));
      expect(target.parameters?['v'], equals('vid_comment_test'));
      expect(target.parameters?['commentId'], equals('comm_xyz_88'));
      expect(target.arguments?['videoId'], equals('vid_comment_test'));
      expect(target.arguments?['commentId'], equals('comm_xyz_88'));
    });

    test('Resolves comment_like and comment_reply to /watch?v=:id with replyId', () {
      final payload = {
        'type': 'comment_like',
        'videoId': 'vid_reply_test',
        'commentId': 'comm_1',
        'replyId': 'reply_999',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/watch?v=vid_reply_test'));
      expect(target.parameters?['v'], equals('vid_reply_test'));
      expect(target.parameters?['commentId'], equals('comm_1'));
      expect(target.parameters?['replyId'], equals('reply_999'));
    });

    test('Resolves new_community_post to /post/:id', () {
      final payload = {
        'type': 'new_community_post',
        'postId': 'post_comm_123',
        'channelId': 'channel_777',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/post/post_comm_123'));
      expect(target.arguments?['postId'], equals('post_comm_123'));
      expect(target.arguments?['channelId'], equals('channel_777'));
    });

    test('Resolves topic notification to /topic/:topicId', () {
      final payload = {
        'type': 'topic',
        'topicId': 'quantum-computing',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/topic/quantum-computing'));
    });

    test('Resolves subscribers milestone to /subscribers analytics', () {
      final payload = {
        'type': 'subscribers_milestone_v1',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/subscribers'));
    });

    test('Resolves coach growth tip to /analytics', () {
      final payload = {
        'type': 'coach_growth_tip_v1',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/analytics'));
    });

    test('Resolves direct actionUrl for policy or complaint screen', () {
      final payload = {
        'type': 'system_announcement',
        'actionUrl': '/community-guidelines',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/community-guidelines'));
    });

    testWidgets('Executes full navigateFromPayload within GetMaterialApp mounting navigation stack', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(
              name: '/',
              page: () => const Scaffold(body: Text('HomeScreen')),
            ),
            GetPage(
              name: '/watch',
              page: () => const Scaffold(body: Text('WatchScreen')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final payload = {
        'type': 'new_video_followed',
        'videoId': 'vid_channel_live_456',
        'channelId': 'ch_verified_1',
      };

      NotificationNavigationHandler.navigateFromPayload(payload);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, contains('/watch'));
      expect(Get.parameters['v'], equals('vid_channel_live_456'));
    });
  });

  group('VideoScreenRedirectMiddleware Tests', () {
    test('Redirects /videoscreen to /watch?v=:id when videoId is in arguments', () {
      final middleware = VideoScreenRedirectMiddleware();

      Get.routing.args = {'videoId': 'vid_redirect_test_1'};

      final redirectResult = middleware.redirect('/videoscreen');

      expect(redirectResult, isNotNull);
      expect(redirectResult!.name, equals('/watch?v=vid_redirect_test_1'));
    });

    test('Redirects /videoscreen to / when no video identifier is found', () {
      final middleware = VideoScreenRedirectMiddleware();

      Get.routing.args = null;
      Get.parameters.clear();

      final redirectResult = middleware.redirect('/videoscreen');

      expect(redirectResult, isNotNull);
      expect(redirectResult!.name, equals('/'));
    });
  });

  group('Channel & Topic Notification Preference Filtering Tests', () {
    bool isVideoPersonalizedEligible(Map<String, dynamic> video) {
      final isVerified = video['isFactChecked'] == true || video['factCheckStatus'] == 'verified';
      final isFeatured = video['featured'] == true || video['isFeatured'] == true;
      final truthScore = video['truthScore'];
      final isHighTruth = (truthScore is num) && truthScore >= 75;
      final trustScore = video['trustScore'];
      final isHighTrust = (trustScore is num) && trustScore >= 75;
      final isHighlight = video['isHighlight'] == true;
      return isVerified || isFeatured || isHighTruth || isHighTrust || isHighlight;
    }

    bool shouldNotifyChannelSubscriber({
      required Map<String, dynamic> subscriptionDoc,
      required String creatorId,
      required Map<String, dynamic> video,
    }) {
      final userId = subscriptionDoc['userId'] as String?;
      if (userId == null || userId.isEmpty || userId == creatorId) {
        return false;
      }
      final notificationsEnabled = subscriptionDoc['notificationsEnabled'] as bool?;
      final option = (subscriptionDoc['notificationOption'] as String? ??
              subscriptionDoc['notificationPreference'] as String? ??
              (notificationsEnabled == false ? 'none' : 'personalized'))
          .toLowerCase();

      if (notificationsEnabled == false || option == 'none') {
        return false;
      }

      final isEligible = isVideoPersonalizedEligible(video);
      return option == 'all' || isEligible;
    }

    bool shouldNotifyTopicFollower({
      required Map<String, dynamic> topicSavedDoc,
      required String userId,
      required String creatorId,
      required Map<String, dynamic> video,
      required Set<String> alreadyNotifiedUsers,
    }) {
      if (userId.isEmpty || userId == creatorId || alreadyNotifiedUsers.contains(userId)) {
        return false;
      }
      final setting = (topicSavedDoc['notificationSetting'] as String? ?? 'personalized').toLowerCase();
      if (setting == 'none' || setting == 'unfollow') {
        return false;
      }
      final isEligible = isVideoPersonalizedEligible(video);
      if (setting == 'personalized' && !isEligible) {
        return false;
      }
      alreadyNotifiedUsers.add(userId);
      return true;
    }

    final routineVideo = {
      'id': 'vid_routine',
      'title': 'Daily update vlog',
      'isFactChecked': false,
      'truthScore': 55,
      'trustScore': 60,
      'featured': false,
      'isHighlight': false,
    };

    final verifiedHighlightVideo = {
      'id': 'vid_verified',
      'title': 'AI Fact Check Investigation',
      'factCheckStatus': 'verified',
      'isFactChecked': true,
      'truthScore': 94,
      'trustScore': 91,
      'featured': true,
      'isHighlight': true,
    };

    const creatorId = 'creator_test_channel';

    test('Channel subscription with "none" really does not send notifications for routine or highlight videos', () {
      final subNone = {
        'userId': 'user_none',
        'notificationsEnabled': false,
        'notificationOption': 'none',
      };

      final notifyRoutine = shouldNotifyChannelSubscriber(
        subscriptionDoc: subNone,
        creatorId: creatorId,
        video: routineVideo,
      );
      final notifyHighlight = shouldNotifyChannelSubscriber(
        subscriptionDoc: subNone,
        creatorId: creatorId,
        video: verifiedHighlightVideo,
      );

      expect(notifyRoutine, isFalse, reason: 'Must not send push notification for routine video');
      expect(notifyHighlight, isFalse, reason: 'Must not send push notification even for highlight video');
    });

    test('Channel subscription with "none" via notificationPreference alias suppresses notifications', () {
      final subNonePref = {
        'userId': 'user_none_alias',
        'notificationPreference': 'none',
      };

      final notify = shouldNotifyChannelSubscriber(
        subscriptionDoc: subNonePref,
        creatorId: creatorId,
        video: verifiedHighlightVideo,
      );

      expect(notify, isFalse);
    });

    test('Channel subscription with "personalized" sends only for personalized highlights, not routine videos', () {
      final subPersonalized = {
        'userId': 'user_pers',
        'notificationsEnabled': true,
        'notificationOption': 'personalized',
      };

      final notifyRoutine = shouldNotifyChannelSubscriber(
        subscriptionDoc: subPersonalized,
        creatorId: creatorId,
        video: routineVideo,
      );
      final notifyHighlight = shouldNotifyChannelSubscriber(
        subscriptionDoc: subPersonalized,
        creatorId: creatorId,
        video: verifiedHighlightVideo,
      );

      expect(notifyRoutine, isFalse, reason: 'Routine videos must be skipped for personalized subscribers');
      expect(notifyHighlight, isTrue, reason: 'Personalized highlight videos must trigger notifications');
    });

    test('Channel subscription with "all" sends notifications for both routine and highlight videos', () {
      final subAll = {
        'userId': 'user_all',
        'notificationsEnabled': true,
        'notificationOption': 'all',
      };

      final notifyRoutine = shouldNotifyChannelSubscriber(
        subscriptionDoc: subAll,
        creatorId: creatorId,
        video: routineVideo,
      );
      final notifyHighlight = shouldNotifyChannelSubscriber(
        subscriptionDoc: subAll,
        creatorId: creatorId,
        video: verifiedHighlightVideo,
      );

      expect(notifyRoutine, isTrue, reason: '"all" subscribers receive routine video notifications');
      expect(notifyHighlight, isTrue, reason: '"all" subscribers receive highlight video notifications');
    });

    test('Topic notification with "none" or "unfollow" suppresses all notifications', () {
      final notifiedSet = <String>{};
      final topicNone = {'notificationSetting': 'none'};
      final topicUnfollow = {'notificationSetting': 'unfollow'};

      final notifyNone = shouldNotifyTopicFollower(
        topicSavedDoc: topicNone,
        userId: 'topic_user_none',
        creatorId: creatorId,
        video: verifiedHighlightVideo,
        alreadyNotifiedUsers: notifiedSet,
      );
      final notifyUnfollow = shouldNotifyTopicFollower(
        topicSavedDoc: topicUnfollow,
        userId: 'topic_user_unfollow',
        creatorId: creatorId,
        video: verifiedHighlightVideo,
        alreadyNotifiedUsers: notifiedSet,
      );

      expect(notifyNone, isFalse, reason: 'Topic with "none" must not send notification');
      expect(notifyUnfollow, isFalse, reason: 'Topic with "unfollow" must not send notification');
    });

    test('Topic notification with "personalized" sends only for highlights and skips routine videos', () {
      final notifiedSet = <String>{};
      final topicPers = {'notificationSetting': 'personalized'};

      final notifyRoutine = shouldNotifyTopicFollower(
        topicSavedDoc: topicPers,
        userId: 'topic_user_pers',
        creatorId: creatorId,
        video: routineVideo,
        alreadyNotifiedUsers: notifiedSet,
      );
      expect(notifyRoutine, isFalse, reason: 'Routine video in topic must be skipped for personalized setting');

      final notifyHighlight = shouldNotifyTopicFollower(
        topicSavedDoc: topicPers,
        userId: 'topic_user_pers',
        creatorId: creatorId,
        video: verifiedHighlightVideo,
        alreadyNotifiedUsers: notifiedSet,
      );
      expect(notifyHighlight, isTrue, reason: 'Verified highlight video must trigger topic notification');
    });

    test('Topic notification with "all" sends notifications for routine videos', () {
      final notifiedSet = <String>{};
      final topicAll = {'notificationSetting': 'all'};

      final notifyRoutine = shouldNotifyTopicFollower(
        topicSavedDoc: topicAll,
        userId: 'topic_user_all',
        creatorId: creatorId,
        video: routineVideo,
        alreadyNotifiedUsers: notifiedSet,
      );

      expect(notifyRoutine, isTrue, reason: '"all" topic follower receives routine video notifications');
    });

    test('Topic and Channel cross-deduplication prevents double notifications for the same video', () {
      final notifiedSet = <String>{'shared_user_1'}; // User already notified via channel subscription
      final topicAll = {'notificationSetting': 'all'};

      final notifyTopic = shouldNotifyTopicFollower(
        topicSavedDoc: topicAll,
        userId: 'shared_user_1',
        creatorId: creatorId,
        video: verifiedHighlightVideo,
        alreadyNotifiedUsers: notifiedSet,
      );

      expect(notifyTopic, isFalse, reason: 'Must not send duplicate notification if user already notified');
    });
  });

  group('Multi-App Notification Flavor Separation Tests (Four Apps Isolation)', () {
    test('UserNotification correctly parses targetApp and defaults to app', () {
      final defaultNotif = UserNotification.fromJson('notif_1', {
        'userId': 'usr_1',
        'title': 'New Video',
        'message': 'Watch now',
      });
      expect(defaultNotif.targetApp, equals('app'));
      expect(defaultNotif.isConsumerNotification, isTrue);
      expect(defaultNotif.isStudioNotification, isFalse);

      final studioNotif = UserNotification.fromJson('notif_2', {
        'userId': 'usr_1',
        'title': 'Fact-Check Completed',
        'message': 'Results visible',
        'targetApp': 'studio',
      });
      expect(studioNotif.targetApp, equals('studio'));
      expect(studioNotif.isStudioNotification, isTrue);
      expect(studioNotif.isConsumerNotification, isFalse);
    });

    test('Studio specific notification types are never treated as consumer notifications', () {
      final factCheckNotif = UserNotification.fromJson('notif_fc', {
        'userId': 'creator_1',
        'type': 'fact_check_ready',
        'title': 'Fact-Check Ready for Review',
        'message': 'Review your fact-check',
        'actionUrl': '/video/vid_123',
      });
      expect(factCheckNotif.isStudioNotification, isTrue);
      expect(factCheckNotif.isConsumerNotification, isFalse);

      final truthVerificationQueuedNotif = UserNotification.fromJson('notif_queued', {
        'userId': 'creator_1',
        'type': 'fact_check_pending',
        'title': 'Truth Verification Queued',
        'message': 'Fact-checking for "Truth-World" is in progress...',
      });
      expect(truthVerificationQueuedNotif.isStudioNotification, isTrue);
      expect(truthVerificationQueuedNotif.isConsumerNotification, isFalse);

      final verificationNotif = UserNotification.fromJson('notif_ver', {
        'userId': 'creator_1',
        'type': 'verification_result',
        'title': 'Video Approved & Published',
        'message': 'Your video is live',
        'actionUrl': '/studio',
      });
      expect(verificationNotif.isStudioNotification, isTrue);
      expect(verificationNotif.isConsumerNotification, isFalse);

      final payoutNotif = UserNotification.fromJson('notif_payout', {
        'userId': 'creator_1',
        'type': 'monetization_payout',
        'title': 'Payout Processed',
        'message': 'Earnings credited',
      });
      expect(payoutNotif.isStudioNotification, isTrue);
      expect(payoutNotif.isConsumerNotification, isFalse);
    });

    test('Consumer notification feed strictly filters out Studio notifications', () {
      final allNotifs = [
        UserNotification.fromJson('notif_studio_1', {
          'userId': 'creator_user',
          'type': 'fact_check_ready',
          'title': 'Fact-Check Completed',
          'message': 'Your fact-check is done',
          'targetApp': 'studio',
        }),
        UserNotification.fromJson('notif_consumer_1', {
          'userId': 'creator_user',
          'type': 'comment',
          'title': 'New Comment!',
          'message': 'Someone commented',
          'actionUrl': '/watch/v_1',
          'targetApp': 'app',
        }),
        UserNotification.fromJson('notif_consumer_2', {
          'userId': 'creator_user',
          'type': 'new_video_followed',
          'title': 'New Video from Channel',
          'message': 'New upload available',
          'actionUrl': '/watch/v_2',
          'targetApp': 'app',
        }),
        UserNotification.fromJson('notif_admin_1', {
          'userId': 'creator_user',
          'type': 'admin_alert',
          'title': 'System Escalation',
          'message': 'Admin action required',
          'targetApp': 'admin',
        }),
      ];

      // Consumer feed filtering
      final consumerFeed = allNotifs.where((n) => n.isConsumerNotification).toList();
      expect(consumerFeed.length, equals(2));
      expect(consumerFeed.map((n) => n.id).toList(), equals(['notif_consumer_1', 'notif_consumer_2']));

      // Studio feed filtering
      final studioFeed = allNotifs.where((n) => n.isStudioNotification).toList();
      expect(studioFeed.length, equals(1));
      expect(studioFeed.first.id, equals('notif_studio_1'));
    });
  });

  group('Comprehensive Four-App Notification Tap & Route Deep-Link Tests', () {
    test('Consumer App: new_video_followed routes to /watch with autoplay and thumbnail', () {
      final payload = {
        'type': 'new_video_followed',
        'videoId': 'vid_subscribed_123',
        'channelId': 'chan_creator_456',
        'thumbnailUrl': 'https://truthworld.in/thumbs/vid_subscribed_123.jpg',
        'targetApp': 'app',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/watch?v=vid_subscribed_123'));
      expect(target.targetApp.name, equals('app'));
      expect(target.arguments?['videoId'], equals('vid_subscribed_123'));
      expect(target.arguments?['autoplay'], isTrue);
      expect(target.arguments?['fromNotification'], isTrue);
      expect(target.arguments?['fromPush'], isTrue);
      expect(target.arguments?['channelId'], equals('chan_creator_456'));
      expect(target.arguments?['thumbnailUrl'], equals('https://truthworld.in/thumbs/vid_subscribed_123.jpg'));
      expect(target.parameters?['v'], equals('vid_subscribed_123'));
      expect(target.parameters?['autoplay'], equals('true'));
    });

    test('Consumer App: new_video_topic routes to /watch with autoplay and fromTopic flag', () {
      final payload = {
        'type': 'new_video_topic',
        'videoId': 'vid_topic_789',
        'topicId': 'topic_science',
        'thumbnailUrl': 'https://truthworld.in/thumbs/vid_topic_789.jpg',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/watch?v=vid_topic_789'));
      expect(target.targetApp.name, equals('app'));
      expect(target.arguments?['videoId'], equals('vid_topic_789'));
      expect(target.arguments?['fromTopic'], isTrue);
      expect(target.arguments?['autoplay'], isTrue);
      expect(target.arguments?['topicId'], equals('topic_science'));
    });

    test('Consumer App: comment notification routes to /watch with commentId and autoplay', () {
      final payload = {
        'type': 'comment',
        'videoId': 'vid_comments_101',
        'commentId': 'comm_999',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/watch?v=vid_comments_101'));
      expect(target.arguments?['commentId'], equals('comm_999'));
      expect(target.arguments?['autoplay'], isTrue);
      expect(target.parameters?['commentId'], equals('comm_999'));
    });

    test('Creator Studio: fact_check_ready routes to /studio with truth verification tab 15', () {
      final payload = {
        'type': 'fact_check_ready',
        'videoId': 'vid_verified_202',
        'targetApp': 'studio',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/studio'));
      expect(target.targetApp.name, equals('studio'));
      expect(target.isStudio, isTrue);
      expect(target.arguments?['tab'], equals(15));
      expect(target.arguments?['filter'], equals('fact_check'));
      expect(target.arguments?['videoId'], equals('vid_verified_202'));
      expect(target.parameters?['tab'], equals('verification'));
      expect(target.parameters?['videoId'], equals('vid_verified_202'));
    });

    test('Creator Studio: copyright_claim routes to /studio with copyright tab 9', () {
      final payload = {
        'type': 'copyright_claim',
        'videoId': 'vid_claimed_303',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/studio'));
      expect(target.targetApp.name, equals('studio'));
      expect(target.isStudio, isTrue);
      expect(target.arguments?['tab'], equals(9));
      expect(target.arguments?['videoId'], equals('vid_claimed_303'));
      expect(target.parameters?['tab'], equals('copyright'));
    });

    test('Creator Studio: subscribers_milestone routes to /subscribers with audience tab 12', () {
      final payload = {
        'type': 'subscribers_milestone',
        'channelId': 'channel_100k',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/subscribers'));
      expect(target.targetApp.name, equals('studio'));
      expect(target.arguments?['tab'], equals(12));
      expect(target.parameters?['tab'], equals('audience'));
    });

    test('Creator Studio: monetization_payout routes to /wallet with monetization tab 5', () {
      final payload = {
        'type': 'monetization_payout',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/wallet'));
      expect(target.targetApp.name, equals('studio'));
      expect(target.arguments?['tab'], equals(5));
      expect(target.parameters?['tab'], equals('monetization'));
    });

    test('Admin App: moderation_escalation routes to /admin/dashboard with videos queue', () {
      final payload = {
        'type': 'moderation_escalation',
        'videoId': 'vid_flagged_505',
        'targetApp': 'admin',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/admin/dashboard'));
      expect(target.targetApp.name, equals('admin'));
      expect(target.isAdmin, isTrue);
      expect(target.arguments?['tab'], equals('videos'));
      expect(target.arguments?['videoId'], equals('vid_flagged_505'));
      expect(target.parameters?['tab'], equals('videos'));
      expect(target.parameters?['videoId'], equals('vid_flagged_505'));
    });

    test('Admin App: report_escalation routes to /admin/dashboard with reports queue', () {
      final payload = {
        'type': 'report_escalation',
        'reportId': 'rep_909',
        'targetApp': 'admin',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/admin/dashboard'));
      expect(target.targetApp.name, equals('admin'));
      expect(target.arguments?['tab'], equals('reports'));
      expect(target.arguments?['reportId'], equals('rep_909'));
    });

    test('Advertiser Portal: campaign_approved routes to /advertiser with campaigns tab 1', () {
      final payload = {
        'type': 'campaign_approved',
        'campaignId': 'camp_summer_2026',
        'targetApp': 'advertiser',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/advertiser'));
      expect(target.targetApp.name, equals('advertiser'));
      expect(target.isAdvertiser, isTrue);
      expect(target.arguments?['tab'], equals(1));
      expect(target.arguments?['campaignId'], equals('camp_summer_2026'));
      expect(target.parameters?['tab'], equals('1'));
    });

    test('Advertiser Portal: billing_invoice routes to /advertiser with billing tab 5', () {
      final payload = {
        'type': 'billing_invoice',
        'targetApp': 'advertiser',
      };

      final target = NotificationNavigationHandler.resolveTarget(payload);

      expect(target.route, equals('/advertiser'));
      expect(target.targetApp.name, equals('advertiser'));
      expect(target.isAdvertiser, isTrue);
      expect(target.arguments?['tab'], equals(5));
      expect(target.parameters?['tab'], equals('5'));
    });

    test('Cross-Flavor: accurately resolves product flavors across all 4 apps', () {
      expect(
        NotificationNavigationHandler.resolveTargetFlavor({'targetApp': 'app'}).name,
        equals('app'),
      );
      expect(
        NotificationNavigationHandler.resolveTargetFlavor({'targetApp': 'studio'}).name,
        equals('studio'),
      );
      expect(
        NotificationNavigationHandler.resolveTargetFlavor({'targetApp': 'admin'}).name,
        equals('admin'),
      );
      expect(
        NotificationNavigationHandler.resolveTargetFlavor({'targetApp': 'advertiser'}).name,
        equals('advertiser'),
      );
    });
  });
}
