import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/controllers/notification_view_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_components.dart';
import 'package:truthworld/features/video/data/models/video.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('UnifiedNotificationItem & NavigationHandler Tests', () {
    test('1. UnifiedNotificationItem stores video and alert correctly', () {
      final now = DateTime.now();
      final item = UnifiedNotificationItem(
        timestamp: now,
        isSeen: false,
      );

      expect(item.timestamp, now);
      expect(item.isSeen, isFalse);
      expect(item.video, isNull);
      expect(item.alert, isNull);
    });

    test('2. formatNotificationTimestamp formats relative time intervals correctly', () {
      final now = DateTime.now();

      final justNow = NotificationNavigationHandler.formatNotificationTimestamp(
        now.subtract(const Duration(seconds: 30)),
      );
      expect(justNow, 'Just now');

      final minutesAgo = NotificationNavigationHandler.formatNotificationTimestamp(
        now.subtract(const Duration(minutes: 15)),
      );
      expect(minutesAgo, '15m ago');

      final hoursAgo = NotificationNavigationHandler.formatNotificationTimestamp(
        now.subtract(const Duration(hours: 4)),
      );
      expect(hoursAgo, '4h ago');

      final daysAgo = NotificationNavigationHandler.formatNotificationTimestamp(
        now.subtract(const Duration(days: 3)),
      );
      expect(daysAgo, '3d ago');

      final weeksAgo = NotificationNavigationHandler.formatNotificationTimestamp(
        now.subtract(const Duration(days: 14)),
      );
      expect(weeksAgo, '2w ago');

      final monthsAgo = NotificationNavigationHandler.formatNotificationTimestamp(
        now.subtract(const Duration(days: 65)),
      );
      expect(monthsAgo, '2mo ago');
    });

    test('3. getDisplayName resolves channel, metadata, or parsed message authors', () {
      final video = Video(
        id: 'vid_1',
        title: 'Exploring Mars',
        description: 'Space documentary',
        thumbnailUrl: 'https://example.com/mars.jpg',
        videoUrl: 'https://example.com/mars.mp4',
        ownerId: 'user_nasa',
        channelId: 'channel_nasa',
        channelName: 'NASA Space Channel',
        category: 'Science',
        tags: const ['space', 'mars'],
        uploadedAt: Timestamp.now(),
      );

      final videoItem = UnifiedNotificationItem(
        timestamp: DateTime.now(),
        isSeen: false,
        video: video,
      );
      expect(
        NotificationNavigationHandler.getDisplayName(videoItem),
        'NASA Space Channel',
      );

      final alertSub = UserNotification(
        id: 'alt_1',
        userId: 'usr_me',
        type: 'subscription',
        severity: NotificationSeverity.info,
        title: 'New Subscriber',
        message: 'Alice Johnson subscribed to your channel',
        read: false,
        createdAt: DateTime.now(),
      );
      final alertItem1 = UnifiedNotificationItem(
        timestamp: DateTime.now(),
        isSeen: false,
        alert: alertSub,
      );
      expect(
        NotificationNavigationHandler.getDisplayName(alertItem1),
        'Alice Johnson',
      );

      final alertMention = UserNotification(
        id: 'alt_2',
        userId: 'usr_me',
        type: 'mention',
        severity: NotificationSeverity.info,
        title: 'Mention',
        message: 'Bob mentioned you: Check this out',
        read: true,
        createdAt: DateTime.now(),
      );
      final alertItem2 = UnifiedNotificationItem(
        timestamp: DateTime.now(),
        isSeen: true,
        alert: alertMention,
      );
      expect(
        NotificationNavigationHandler.getDisplayName(alertItem2),
        'Bob',
      );

      final alertAt = UserNotification(
        id: 'alt_3',
        userId: 'usr_me',
        type: 'social',
        severity: NotificationSeverity.info,
        title: '',
        message: '@charlie sent a reaction',
        read: true,
        createdAt: DateTime.now(),
      );
      final alertItem3 = UnifiedNotificationItem(
        timestamp: DateTime.now(),
        isSeen: true,
        alert: alertAt,
      );
      expect(
        NotificationNavigationHandler.getDisplayName(alertItem3),
        'charlie',
      );
    });

    test('4. getAvatarColor returns deterministic color based on string hash', () {
      final color1 = NotificationNavigationHandler.getAvatarColor('JohnDoe');
      final color2 = NotificationNavigationHandler.getAvatarColor('JohnDoe');
      expect(color1, equals(color2));

      final emptyColor = NotificationNavigationHandler.getAvatarColor('');
      expect(emptyColor, const Color(0xFF374151));
    });
  });

  group('NotificationViewController Tests', () {
    late NotificationViewController viewController;
    late VideoFeedNotificationController feedController;
    late UserNotificationController userNotificationController;

    setUp(() {
      feedController = Get.put(VideoFeedNotificationController());
      userNotificationController = Get.put(UserNotificationController());
      viewController = Get.put(NotificationViewController());
    });

    test('5. Tab selection updates selectedTabIndex and triggers haptics', () {
      expect(viewController.selectedTabIndex.value, 0);

      viewController.selectTab(1);
      expect(viewController.selectedTabIndex.value, 1);

      viewController.selectTab(2);
      expect(viewController.selectedTabIndex.value, 2);

      viewController.selectTab(3);
      expect(viewController.selectedTabIndex.value, 3);
    });

    test('6. getUnifiedNotificationsForTab filters items by tab and query', () {
      final now = DateTime.now();

      final video = Video(
        id: 'v_101',
        title: 'Flutter Architecture Masterclass',
        description: 'Clean coding rules',
        thumbnailUrl: 'https://example.com/flutter.jpg',
        videoUrl: 'https://example.com/flutter.mp4',
        ownerId: 'owner_dev',
        channelId: 'ch_dev',
        channelName: 'Dev Academy',
        category: 'Technology',
        tags: const ['flutter', 'code'],
        uploadedAt: Timestamp.fromDate(now),
      );
      feedController.notifications.value = [video];

      final topicAlert = UserNotification(
        id: 'alt_topic',
        userId: 'usr_1',
        type: 'new_video_topic',
        severity: NotificationSeverity.info,
        title: 'New Topic Video',
        message: 'A new video in Science was posted',
        read: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      final commentAlert = UserNotification(
        id: 'alt_comment',
        userId: 'usr_1',
        type: 'comment',
        severity: NotificationSeverity.info,
        title: 'New Comment',
        message: 'Someone commented: Great work!',
        read: false,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      final mentionAlert = UserNotification(
        id: 'alt_mention',
        userId: 'usr_1',
        type: 'mention',
        severity: NotificationSeverity.info,
        title: 'Mention',
        message: 'Dev mentioned you: Take a look',
        read: false,
        createdAt: now.subtract(const Duration(minutes: 15)),
      );

      userNotificationController.notifications.value = [
        topicAlert,
        commentAlert,
        mentionAlert,
      ];

      // Tab 0: All (should include video + all 3 alerts = 4 items)
      viewController.selectTab(0);
      var items = viewController.getUnifiedNotificationsForTab();
      expect(items.length, 4);

      // Tab 1: Topics
      viewController.selectTab(1);
      items = viewController.getUnifiedNotificationsForTab();
      expect(items.length, 1);
      expect(items.first.alert?.id, 'alt_topic');

      // Tab 2: Comments
      viewController.selectTab(2);
      items = viewController.getUnifiedNotificationsForTab();
      expect(items.length, 1);
      expect(items.first.alert?.id, 'alt_comment');

      // Tab 3: Mentions
      viewController.selectTab(3);
      items = viewController.getUnifiedNotificationsForTab();
      expect(items.length, 1);
      expect(items.first.alert?.id, 'alt_mention');

      // Search query filtering
      viewController.selectTab(0);
      viewController.onSearchChanged('Architecture');
      items = viewController.getUnifiedNotificationsForTab();
      expect(items.length, 1);
      expect(items.first.video?.id, 'v_101');
    });
  });

  group('Notification Widgets Tests', () {
    testWidgets('7. NotificationEmptyTopicsState renders cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomScrollView(
            slivers: [
              NotificationEmptyTopicsState(),
            ],
          ),
        ),
      );

      expect(find.text('No topic updates yet'), findsOneWidget);
      expect(find.byIcon(Icons.topic_rounded), findsOneWidget);
    });

    testWidgets('8. NotificationEmptyMentionsState renders cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomScrollView(
            slivers: [
              NotificationEmptyMentionsState(),
            ],
          ),
        ),
      );

      expect(find.text('No mentions yet'), findsOneWidget);
      expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);
    });

    testWidgets('9. NotificationEmptyGeneralState renders cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomScrollView(
            slivers: [
              NotificationEmptyGeneralState(),
            ],
          ),
        ),
      );

      expect(find.text('No notifications'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    });
  });

  group('Consumer vs Studio Notification Isolation Tests', () {
    late NotificationViewController viewController;
    late VideoFeedNotificationController feedController;
    late UserNotificationController userNotificationController;

    setUp(() {
      feedController = Get.put(VideoFeedNotificationController());
      userNotificationController = Get.put(UserNotificationController());
      viewController = Get.put(NotificationViewController());
    });

    test('10. Consumer mode strictly excludes Fact-Check Completed, Video Processing, and New Subscriber', () {
      final now = DateTime.now();

      final factCheckNotif = UserNotification(
        id: 'fc_1',
        userId: 'usr_creator',
        type: 'fact_check_ready',
        severity: NotificationSeverity.success,
        title: 'Fact-Check Completed',
        message: 'Fact-checking analysis is complete for "My Video"',
        targetApp: 'studio',
        read: false,
        createdAt: now,
      );

      final videoProcessingNotif = UserNotification(
        id: 'vp_1',
        userId: 'usr_creator',
        type: 'verification_result',
        severity: NotificationSeverity.info,
        title: 'Video Processing Started: "My Video"',
        message: 'Your video is now undergoing AI processing',
        targetApp: 'studio',
        read: false,
        createdAt: now,
      );

      final newSubscriberNotif = UserNotification(
        id: 'sub_1',
        userId: 'usr_creator',
        type: 'new_follower',
        severity: NotificationSeverity.info,
        title: 'New Subscriber!',
        message: 'Alice subscribed to your channel.',
        targetApp: 'studio',
        read: false,
        createdAt: now,
      );

      final consumerComment = UserNotification(
        id: 'comment_1',
        userId: 'usr_creator',
        type: 'comment',
        severity: NotificationSeverity.info,
        title: 'New Comment!',
        message: 'Great video!',
        targetApp: 'app',
        read: false,
        createdAt: now,
      );

      userNotificationController.notifications.value = [
        factCheckNotif,
        videoProcessingNotif,
        newSubscriberNotif,
        consumerComment,
      ];

      // In Consumer mode (channelId is empty)
      viewController.currentChannelId.value = '';
      viewController.selectTab(0); // All tab

      final items = viewController.getUnifiedNotificationsForTab();
      expect(items.length, 1);
      expect(items.first.alert?.id, 'comment_1');
      expect(items.any((i) => i.alert?.id == 'fc_1'), isFalse);
      expect(items.any((i) => i.alert?.id == 'vp_1'), isFalse);
      expect(items.any((i) => i.alert?.id == 'sub_1'), isFalse);
    });

    test('11. Studio channel context correctly includes Fact-Check and Video Processing notifications', () {
      final now = DateTime.now();

      final factCheckNotif = UserNotification(
        id: 'fc_studio',
        userId: 'usr_creator',
        channelId: 'chan_main',
        type: 'fact_check_ready',
        severity: NotificationSeverity.success,
        title: 'Fact-Check Completed',
        message: 'Fact-checking analysis is complete for "My Video"',
        targetApp: 'studio',
        read: false,
        createdAt: now,
      );

      final videoProcessingNotif = UserNotification(
        id: 'vp_studio',
        userId: 'usr_creator',
        channelId: 'chan_main',
        type: 'verification_result',
        severity: NotificationSeverity.info,
        title: 'Video Processing Started: "My Video"',
        message: 'Your video is undergoing AI processing',
        targetApp: 'studio',
        read: false,
        createdAt: now,
      );

      userNotificationController.notifications.value = [
        factCheckNotif,
        videoProcessingNotif,
      ];

      // Enter studio channel context
      viewController.currentChannelId.value = 'chan_main';
      viewController.currentCreatorId.value = 'usr_creator';
      viewController.selectTab(0); // All tab in studio

      final items = viewController.getUnifiedNotificationsForTab();
      expect(items.length, 2);
      expect(items.any((i) => i.alert?.id == 'fc_studio'), isTrue);
      expect(items.any((i) => i.alert?.id == 'vp_studio'), isTrue);
    });

    test('12. UserNotificationController unreadCount ignores studio notifications in consumer mode', () {
      final now = DateTime.now();

      userNotificationController.notifications.value = [
        UserNotification(
          id: 'fc_unread',
          userId: 'usr_creator',
          type: 'fact_check_ready',
          severity: NotificationSeverity.success,
          title: 'Fact-Check Completed',
          message: 'Analysis complete',
          targetApp: 'studio',
          read: false,
          createdAt: now,
        ),
        UserNotification(
          id: 'comm_unread',
          userId: 'usr_creator',
          type: 'comment',
          severity: NotificationSeverity.info,
          title: 'New Comment',
          message: 'Nice video!',
          targetApp: 'app',
          read: false,
          createdAt: now,
        ),
      ];

      // In consumer mode, unreadCount should only count the 1 consumer notification
      expect(userNotificationController.unreadCount, equals(1));
    });
  });
}
