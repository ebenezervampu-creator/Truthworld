import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
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
      theme: ThemeData(
        splashFactory: NoSplash.splashFactory,
        useMaterial3: false,
      ),
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
  );

  final sampleTopicNotification = UserNotification(
    id: 'notif_topic_001',
    userId: 'creator_123',
    type: 'new_video_topic',
    severity: NotificationSeverity.info,
    title: 'New Topic Discussion',
    message: 'A new video was posted in Economy topic.',
    read: true,
    createdAt: DateTime.now(),
  );

  final sampleCommentNotification = UserNotification(
    id: 'notif_comment_001',
    userId: 'creator_123',
    type: 'comment',
    severity: NotificationSeverity.info,
    title: 'New Comment',
    message: 'Jyothi commented on your video.',
    read: false,
    createdAt: DateTime.now(),
  );

  final sampleMentionNotification = UserNotification(
    id: 'notif_mention_001',
    userId: 'creator_123',
    type: 'mention',
    severity: NotificationSeverity.info,
    title: 'You were mentioned',
    message: 'Alice mentioned you in a comment.',
    read: false,
    createdAt: DateTime.now(),
  );

  group('ChannelNotificationsPage Consumer Architecture & UI Theme Tests', () {
    testWidgets('1. ChannelNotificationsPage renders Notifications title and AppBar from consumerapp',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsPage(
            channelId: 'chan_test_101',
            creatorId: 'creator_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('2. NotificationPillTabs renders All, Topics, Comments, Mentions and handles tap',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          NotificationPillTabs(viewController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Topics'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Mentions'), findsOneWidget);

      await tester.tap(find.text('Comments'));
      await tester.pumpAndSettle();

      expect(controller.selectedTabIndex.value, equals(2));
    });

    testWidgets('3. NotificationSearchBar toggles and renders Search notifications...',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          CustomScrollView(
            slivers: [
              NotificationAppBar(viewController: controller),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap search icon to toggle search bar
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Search notifications...'), findsOneWidget);
    });

    testWidgets('4. PopupMenuButton renders Mark all as read',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          CustomScrollView(
            slivers: [
              NotificationAppBar(viewController: controller),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Mark all as read'), findsOneWidget);
    });

    testWidgets('5. NotificationEmptyGeneralState renders No notifications and subtext',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const CustomScrollView(
            slivers: [
              NotificationEmptyGeneralState(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications'), findsOneWidget);
      expect(
        find.text('You have no notifications in this section.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    });

    testWidgets('6. NotificationEmptyTopicsState and NotificationEmptyMentionsState render exact text',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const CustomScrollView(
            slivers: [
              NotificationEmptyTopicsState(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No topic updates yet'), findsOneWidget);
      expect(find.byIcon(Icons.topic_rounded), findsOneWidget);

      await tester.pumpWidget(
        wrapWithMaterial(
          const CustomScrollView(
            slivers: [
              NotificationEmptyMentionsState(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No mentions yet'), findsOneWidget);
      expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);
    });

    testWidgets('7. Channel notifications render in Today section using CompactNotificationTile',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.userNotificationController.notifications.assignAll([
        sampleNotification,
      ]);

      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsPage(
            channelId: 'chan_test_today',
            creatorId: 'creator_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Views Surging on Latest Video'), findsOneWidget);
      expect(
        find.text('Your latest upload gained 1,000 views in the past hour.'),
        findsOneWidget,
      );
      expect(find.byType(CompactNotificationTile), findsOneWidget);
    });

    testWidgets('8. NotificationActionMenu renders Mark as read and Delete notification',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      final item = UnifiedNotificationItem(
        alert: sampleNotification,
        timestamp: sampleNotification.createdAt,
        isSeen: sampleNotification.read,
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          NotificationActionMenu(
            item: item,
            viewController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Mark as read'), findsOneWidget);
      expect(find.text('Delete notification'), findsOneWidget);
    });

    testWidgets('9. NotificationFloatingActions renders Mark All Read when unread notifications exist',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.userNotificationController.notifications.assignAll([
        sampleNotification,
      ]);

      await tester.pumpWidget(
        wrapWithMaterial(
          NotificationFloatingActions(viewController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mark All Read'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    });

    testWidgets('10. Notifications filter correctly across Topics, Comments, and Mentions tabs',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.userNotificationController.notifications.assignAll([
        sampleNotification,
        sampleTopicNotification,
        sampleCommentNotification,
        sampleMentionNotification,
      ]);

      // Tab 0: All
      controller.selectedTabIndex.value = 0;
      var items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(4));

      // Tab 1: Topics
      controller.selectedTabIndex.value = 1;
      items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(1));
      expect(items.first.alert?.id, equals('notif_topic_001'));

      // Tab 2: Comments
      controller.selectedTabIndex.value = 2;
      items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(1));
      expect(items.first.alert?.id, equals('notif_comment_001'));

      // Tab 3: Mentions
      controller.selectedTabIndex.value = 3;
      items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(1));
      expect(items.first.alert?.id, equals('notif_mention_001'));
    });

    testWidgets('11. Channel video issues (rejection, manual review) synthesize and render with exact UI',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.setChannelContext(channelId: 'chan_test_101', creatorId: 'creator_123');

      final rejectedIssue = UserNotification(
        id: 'issue_video_rejected_vid_99',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'verification_result',
        severity: NotificationSeverity.priority,
        priority: NotificationPriority.critical,
        title: 'Truth Verification Action Required',
        message: 'Your video "Deepfake Probe" was not accepted: Content violated accuracy policies.',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        actionUrl: '/studio',
        category: 'verification',
        metadata: {'videoId': 'vid_99', 'videoTitle': 'Deepfake Probe', 'tab': 15},
        read: false,
        createdAt: DateTime.now(),
        targetApp: 'studio',
      );

      final manualReviewIssue = UserNotification(
        id: 'issue_video_manual_review_vid_100',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'fact_check_pending',
        severity: NotificationSeverity.warning,
        priority: NotificationPriority.high,
        title: 'Video Under Manual Review',
        message: 'Your video "Climate Summary" is held for manual human review.',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
        actionUrl: '/studio',
        category: 'verification',
        metadata: {'videoId': 'vid_100', 'videoTitle': 'Climate Summary', 'tab': 15},
        read: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        targetApp: 'studio',
      );

      controller.channelIssues.assignAll([manualReviewIssue, rejectedIssue]);

      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsPage(
            channelId: 'chan_test_101',
            creatorId: 'creator_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify exact titles and messages appear in the CompactNotificationTile layout
      expect(find.text('Truth Verification Action Required'), findsOneWidget);
      expect(find.textContaining('Content violated accuracy policies'), findsOneWidget);
      expect(find.text('Video Under Manual Review'), findsOneWidget);
      expect(find.textContaining('Climate Summary'), findsOneWidget);

      // Verify critical priority item is ranked first in the unified list
      final items = controller.getUnifiedNotificationsForTab();
      expect(items.first.alert?.id, equals('issue_video_rejected_vid_99'));
    });

    testWidgets('12. Copyright claims and branding issues render seamlessly with action routing',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.setChannelContext(channelId: 'chan_test_101', creatorId: 'creator_123');

      final copyrightIssue = UserNotification(
        id: 'issue_copyright_claim_55',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'copyright_claim',
        severity: NotificationSeverity.priority,
        priority: NotificationPriority.critical,
        title: 'Copyright Claim Notice',
        message: 'A copyright claim was submitted for your video "Soundtrack Song".',
        actionUrl: '/studio',
        category: 'copyright',
        metadata: {'claimId': 'claim_55', 'videoId': 'vid_song', 'tab': 9},
        read: false,
        createdAt: DateTime.now(),
        targetApp: 'studio',
      );

      final avatarIssue = UserNotification(
        id: 'issue_channel_avatar_chan_test_101',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'channel_policy',
        severity: NotificationSeverity.warning,
        priority: NotificationPriority.high,
        title: 'Channel Profile Picture Notice',
        message: 'Your channel profile picture requires attention (Low resolution flagged).',
        actionUrl: '/studio',
        category: 'channel',
        metadata: {'channelId': 'chan_test_101', 'tab': 6},
        read: false,
        createdAt: DateTime.now(),
        targetApp: 'studio',
      );

      controller.channelIssues.assignAll([copyrightIssue, avatarIssue]);

      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsPage(
            channelId: 'chan_test_101',
            creatorId: 'creator_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copyright Claim Notice'), findsOneWidget);
      expect(find.textContaining('A copyright claim was submitted'), findsOneWidget);
      expect(find.text('Channel Profile Picture Notice'), findsOneWidget);
      expect(find.textContaining('Low resolution flagged'), findsOneWidget);
    });

    testWidgets('13. Audience tab alerts (subscribers milestone & new follower) render in exact style',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.setChannelContext(channelId: 'chan_test_101', creatorId: 'creator_123');

      final milestoneAlert = UserNotification(
        id: 'sub_milestone_10k',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'subscribers_milestone_v1',
        severity: NotificationSeverity.success,
        priority: NotificationPriority.high,
        title: '🎉 Milestone Achieved: 10,000 Subscribers!',
        message: 'Congratulations! Your channel reached 10,000 subscribers (+250 this week).',
        actionUrl: '/subscribers',
        category: 'growth',
        metadata: {'channelId': 'chan_test_101', 'tab': 12},
        read: false,
        createdAt: DateTime.now(),
      );

      final newSubscriberAlert = UserNotification(
        id: 'sub_new_alice',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'new_follower',
        severity: NotificationSeverity.info,
        title: 'New Subscriber!',
        message: 'Alice subscribed to your channel.',
        actionUrl: '/studio',
        category: 'growth',
        metadata: {'channelId': 'chan_test_101', 'subscriberId': 'user_alice'},
        read: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );

      controller.userNotificationController.notifications.assignAll([
        milestoneAlert,
        newSubscriberAlert,
      ]);

      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsPage(
            channelId: 'chan_test_101',
            creatorId: 'creator_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🎉 Milestone Achieved: 10,000 Subscribers!'), findsOneWidget);
      expect(find.textContaining('Congratulations! Your channel reached 10,000 subscribers'), findsOneWidget);
      expect(find.text('New Subscriber!'), findsOneWidget);
      expect(find.text('Alice subscribed to your channel.'), findsOneWidget);
    });

    testWidgets('14. Analytics page alerts (AI Coach & performance insight) render in exact style',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.setChannelContext(channelId: 'chan_test_101', creatorId: 'creator_123');

      final coachAlert = UserNotification(
        id: 'coach_tip_01',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'coach_growth_tip_v1',
        severity: NotificationSeverity.info,
        priority: NotificationPriority.medium,
        title: '💡 AI Creator Coach: High Engagement Window',
        message: 'Posting on Fridays at 6 PM resulted in 40% more comments on this channel.',
        actionUrl: '/analytics',
        category: 'education',
        metadata: {'channelId': 'chan_test_101', 'tab': 3},
        read: false,
        createdAt: DateTime.now(),
      );

      final retentionAlert = UserNotification(
        id: 'retention_spike_01',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'retention_spike',
        severity: NotificationSeverity.info,
        priority: NotificationPriority.high,
        title: 'Audience Retention Spike',
        message: 'Viewer retention peaked at 2:30 in your recent video.',
        actionUrl: '/analytics',
        category: 'analytics',
        metadata: {'channelId': 'chan_test_101', 'tab': 3},
        read: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      controller.userNotificationController.notifications.assignAll([
        coachAlert,
        retentionAlert,
      ]);

      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsPage(
            channelId: 'chan_test_101',
            creatorId: 'creator_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('💡 AI Creator Coach: High Engagement Window'), findsOneWidget);
      expect(find.textContaining('Posting on Fridays at 6 PM'), findsOneWidget);
      expect(find.text('Audience Retention Spike'), findsOneWidget);
      expect(find.textContaining('Viewer retention peaked at 2:30'), findsOneWidget);
    });

    testWidgets('15. Dismissing and marking issue notifications as read updates list reactively',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;
      controller.setChannelContext(channelId: 'chan_test_101', creatorId: 'creator_123');

      final testIssue = UserNotification(
        id: 'issue_video_failed_vid_err',
        userId: 'creator_123',
        channelId: 'chan_test_101',
        type: 'video_processing_failed',
        severity: NotificationSeverity.warning,
        title: 'Video Processing Issue',
        message: 'Video "Test Upload" failed to process.',
        read: false,
        createdAt: DateTime.now(),
      );

      controller.channelIssues.assignAll([testIssue]);

      var items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(1));
      expect(items.first.isSeen, isFalse);

      // Mark as read
      controller.markIssueAsRead('issue_video_failed_vid_err');
      items = controller.getUnifiedNotificationsForTab();
      expect(items.first.isSeen, isTrue);

      // Dismiss / delete issue
      controller.dismissIssue('issue_video_failed_vid_err');
      items = controller.getUnifiedNotificationsForTab();
      expect(items.isEmpty, isTrue);
    });

    testWidgets('16. NotificationPillTabs in Creator Studio renders 6 tabs (All, Verifications, Studio Alerts, Topics, Comments, Mentions)',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(NotificationViewController());
      controller.setChannelContext(channelId: 'channel_studio_test_001', creatorId: 'creator_001');
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          NotificationPillTabs(viewController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Verifications'), findsOneWidget);
      expect(find.text('Studio Alerts'), findsOneWidget);
      expect(find.text('Topics'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Mentions'), findsOneWidget);

      // Tap Verifications tab (index 1)
      await tester.tap(find.text('Verifications'));
      await tester.pumpAndSettle();
      expect(controller.selectedTabIndex.value, equals(1));
      expect(controller.activeTabId, equals('verifications'));

      // Tap Studio Alerts tab (index 2)
      await tester.tap(find.text('Studio Alerts'));
      await tester.pumpAndSettle();
      expect(controller.selectedTabIndex.value, equals(2));
      expect(controller.activeTabId, equals('studio_alerts'));

      // Tap Topics tab (index 3)
      await tester.tap(find.text('Topics'));
      await tester.pumpAndSettle();
      expect(controller.selectedTabIndex.value, equals(3));
      expect(controller.activeTabId, equals('topics'));
    });

    testWidgets('17. Creator Studio Verifications and Studio Alerts tabs filter notifications and render empty states',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.setChannelContext(channelId: 'channel_studio_test_002', creatorId: 'creator_002');
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      final verifAlert = UserNotification(
        id: 'verif_001',
        userId: 'creator_002',
        channelId: 'channel_studio_test_002',
        type: 'verification_result',
        severity: NotificationSeverity.priority,
        title: 'Truth Verification Passed',
        message: 'Your video truth claims are fully verified with 100% accuracy.',
        read: false,
        createdAt: DateTime.now(),
      );

      final studioAlert = UserNotification(
        id: 'copyright_001',
        userId: 'creator_002',
        channelId: 'channel_studio_test_002',
        type: 'copyright_claim',
        severity: NotificationSeverity.warning,
        title: 'Copyright Claim Notice',
        message: 'A copyright match was found on track 1.',
        read: false,
        createdAt: DateTime.now(),
      );

      controller.userNotificationController.notifications.assignAll([verifAlert, studioAlert]);

      // All tab
      controller.selectTabById('all');
      var items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(2));

      // Verifications tab
      controller.selectTabById('verifications');
      items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(1));
      expect(items.first.alert?.id, equals('verif_001'));

      // Studio Alerts tab
      controller.selectTabById('studio_alerts');
      items = controller.getUnifiedNotificationsForTab();
      expect(items.length, equals(1));
      expect(items.first.alert?.id, equals('copyright_001'));

      // Verify empty states
      await tester.pumpWidget(
        wrapWithMaterial(
          const CustomScrollView(
            slivers: [
              NotificationEmptyVerificationsState(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No verification notices'), findsOneWidget);

      await tester.pumpWidget(
        wrapWithMaterial(
          const CustomScrollView(
            slivers: [
              NotificationEmptyStudioAlertsState(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No studio alerts'), findsOneWidget);

      await tester.pumpWidget(
        wrapWithMaterial(
          const CustomScrollView(
            slivers: [
              NotificationEmptyCommentsState(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No comments yet'), findsOneWidget);
    });
  });
}
