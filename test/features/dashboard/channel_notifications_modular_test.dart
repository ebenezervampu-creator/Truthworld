import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/channel_notifications_page.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget wrapWithMaterial(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  final sampleNotification = UserNotification(
    id: 'notif_001',
    userId: 'creator_123',
    type: 'performance_spike',
    severity: NotificationSeverity.info,
    title: 'Views Surging on Latest Video',
    message: 'Your latest upload gained 1,000 views in the past hour.',
    read: false,
    createdAt: DateTime.now(),
    priority: NotificationPriority.high,
    analyticsSnapshot: AnalyticsSnapshotData(
      views: 15400,
      subscribers: 1200,
      likes: 850,
      comments: 64,
      shares: 32,
      watchHours: 124.5,
      ctr: 0.08,
      avd: 4.5,
      subscriberDelta: 45,
      snapshotAt: DateTime.now(),
    ),
  );

  final sampleCriticalNotification = UserNotification(
    id: 'notif_crit_001',
    userId: 'creator_123',
    type: 'verification_failed',
    severity: NotificationSeverity.warning,
    priority: NotificationPriority.critical,
    title: 'Verification Flag Detected',
    message: 'Fact-checking algorithms flagged unverified claims in section 2.',
    read: false,
    createdAt: DateTime.now(),
  );

  group('ChannelNotificationsPage Modular Architecture Tests', () {
    testWidgets('1. ChannelNotificationsHeaderBanner renders title, description and unread badge',
        (tester) async {
      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_101',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_101',
      );
      controller.unreadCount.value = 3;

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsHeaderBanner(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Channel Notifications'), findsOneWidget);
      expect(find.text('3 UNREAD'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    });

    testWidgets('2. ChannelNotificationsFilterChips renders categories and handles tap',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_102',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_102',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsFilterChips(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Notifications'), findsOneWidget);
      expect(find.text('Critical & Policy'), findsOneWidget);
      expect(find.text('Milestones & Growth'), findsOneWidget);
      expect(find.text('Fact Verification'), findsOneWidget);

      await tester.tap(find.text('Critical & Policy'));
      await tester.pumpAndSettle();

      expect(controller.selectedCategory.value, equals('critical'));
    });

    testWidgets('3. ChannelNotificationsEmptyState renders illustration and guidance',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsEmptyState(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Notifications Yet'), findsOneWidget);
      expect(
        find.textContaining('Channel milestones, updates, video verification audit reports'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    testWidgets('4. ChannelNotificationsIssueCard renders badge, message and action buttons',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsIssueCard(
            title: 'Avatar Image Flagged',
            description: 'Image flagged for potential guidelines violation.',
            statusType: 'FLAGGED',
            icon: Icons.warning_amber_rounded,
            actions: [
              ElevatedButton(
                onPressed: () {},
                child: const Text('Resolve Now'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avatar Image Flagged'), findsOneWidget);
      expect(
        find.text('Image flagged for potential guidelines violation.'),
        findsOneWidget,
      );
      expect(find.text('Resolve Now'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('5. ChannelNotificationsCriticalSection renders urgent notices',
        (tester) async {
      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_103',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_103',
      );
      controller.notifications.assignAll([sampleCriticalNotification]);

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsCriticalSection(
            controller: controller,
            channelId: 'chan_test_103',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTION REQUIRED'), findsOneWidget);
      expect(find.text('Verification Flag Detected'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('6. ChannelNotificationsNotificationCard renders analytics pill and content',
        (tester) async {
      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_104',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_104',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsNotificationCard(
            controller: controller,
            notification: sampleNotification,
            channelId: 'chan_test_104',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Views Surging on Latest Video'), findsOneWidget);
      expect(
        find.text('Your latest upload gained 1,000 views in the past hour.'),
        findsOneWidget,
      );
      expect(find.textContaining('15.4K views'), findsOneWidget);
      expect(find.textContaining('1.2K subs'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('7. ChannelNotificationsNotificationCard renders category tag, status tag and clarity notice',
        (tester) async {
      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_105',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_105',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsNotificationCard(
            controller: controller,
            notification: sampleNotification,
            channelId: 'chan_test_105',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PERFORMANCE INSIGHT'), findsOneWidget);
      expect(find.text('Audience Surge'), findsOneWidget);
      expect(find.text('Understand Notice'), findsOneWidget);
      expect(find.textContaining('Engagement surge detected'), findsOneWidget);
    });

    testWidgets('8. Tapping Understand Notice opens ChannelNotificationsDetailModal with standing impact',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_106',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_106',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsNotificationCard(
            controller: controller,
            notification: sampleNotification,
            channelId: 'chan_test_106',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Understand Notice'));
      await tester.pumpAndSettle();

      expect(find.text('CHANNEL STANDING & SAFETY'), findsOneWidget);
      expect(find.textContaining('In Good Standing (0 Strikes)'), findsOneWidget);
      expect(find.text('RECOMMENDED NEXT STEPS'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('9. Tapping How it works in HeaderBanner opens ChannelNotificationsGuideModal',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_107',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_107',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsHeaderBanner(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('How it works'), findsOneWidget);
      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();

      expect(find.text('Channel Notifications Guide'), findsOneWidget);
      expect(find.textContaining('Creator Review First'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('10. Comment notification renders clean card without noisy standing box, raw UUIDs, or understand notice',
        (tester) async {
      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_comment',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_comment',
      );
      controller.videoTitlesCache['video_uuid_1234'] = 'How TruthWorld Works';

      final commentNotification = UserNotification(
        id: 'notif_comment_1',
        userId: 'creator_123',
        type: 'comment',
        severity: NotificationSeverity.info,
        title: 'New Comment!',
        message: 'Jyothi Yerrola commented: "Nice video anna..."',
        read: false,
        createdAt: DateTime.now(),
        metadata: {
          'videoId': 'video_uuid_1234',
          'videoTitle': 'How TruthWorld Works',
          'commenterName': 'Jyothi Yerrola',
        },
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsNotificationCard(
            controller: controller,
            notification: commentNotification,
            channelId: 'chan_test_comment',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Comment author and quote rendered
      expect(find.text('Jyothi Yerrola'), findsOneWidget);
      expect(find.text('"Nice video anna..."'), findsOneWidget);

      // Verified: Real video title rendered, NO raw UUID
      expect(find.text('How TruthWorld Works'), findsOneWidget);
      expect(find.textContaining('video_uuid_1234'), findsNothing);

      // Verified: Tag is COMMENT, NOT CHANNEL NOTICE
      expect(find.text('COMMENT'), findsOneWidget);
      expect(find.text('CHANNEL NOTICE'), findsNothing);

      // Verified: Clean Reply button exists
      expect(find.text('Reply'), findsOneWidget);

      // Verified: No noisy All Good or Understand Notice on comments!
      expect(find.textContaining('All Good: Your channel is in Good Standing'), findsNothing);
      expect(find.text('Understand Notice'), findsNothing);
    });

    testWidgets('11. Subscriber notification renders clean card without Manage in Videos or noisy standing box',
        (tester) async {
      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_sub',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_sub',
      );

      final subNotification = UserNotification(
        id: 'notif_sub_1',
        userId: 'creator_123',
        type: 'new_follower',
        severity: NotificationSeverity.info,
        title: 'New Subscriber!',
        message: 'Jyothi Yerrola subscribed to your channel.',
        read: false,
        createdAt: DateTime.now(),
        metadata: {
          'subscriberId': 'user_jyothi_1',
        },
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          ChannelNotificationsNotificationCard(
            controller: controller,
            notification: subNotification,
            channelId: 'chan_test_sub',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Content rendered
      expect(find.text('New Subscriber!'), findsOneWidget);
      expect(find.text('Jyothi Yerrola subscribed to your channel.'), findsOneWidget);

      // Verified: Tag is SUBSCRIBER
      expect(find.text('SUBSCRIBER'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);

      // Verified: No noisy Manage in Videos, All Good or Understand Notice on subscribers!
      expect(find.text('Manage in Videos'), findsNothing);
      expect(find.textContaining('All Good: Your channel is in Good Standing'), findsNothing);
      expect(find.text('Understand Notice'), findsNothing);
    });

    testWidgets('12. Category filter chips and video title resolution guarantee zero raw UUID leaks',
        (tester) async {
      final controller = Get.put(
        ChannelNotificationsController(
          channelId: 'chan_test_filters',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_filters',
      );

      final commentNotif = UserNotification(
        id: 'c1',
        userId: 'creator_123',
        type: 'comment',
        severity: NotificationSeverity.info,
        title: 'New Comment!',
        message: 'Someone commented: "Great info!"',
        read: false,
        createdAt: DateTime.now(),
      );

      final subNotif = UserNotification(
        id: 's1',
        userId: 'creator_123',
        type: 'new_follower',
        severity: NotificationSeverity.info,
        title: 'New Subscriber!',
        message: 'John subscribed to your channel.',
        read: false,
        createdAt: DateTime.now(),
      );

      controller.notifications.assignAll([commentNotif, subNotif]);

      // Filter by comments
      controller.selectedCategory.value = 'comments';
      expect(controller.filteredNotifications.length, equals(1));
      expect(controller.filteredNotifications.first.id, equals('c1'));

      // Filter by subscribers
      controller.selectedCategory.value = 'subscribers';
      expect(controller.filteredNotifications.length, equals(1));
      expect(controller.filteredNotifications.first.id, equals('s1'));

      // Test video title resolution with raw UUID string
      const rawUuid = '1f2a001f-c96b-4e12-8822-abcdef123456';
      // Raw UUID is intercepted and returns friendly fallback 'Video' or cached title
      final resolved = controller.getVideoTitle(rawUuid, initialTitle: rawUuid);
      expect(resolved.contains(rawUuid), isFalse);
    });
  });
}
