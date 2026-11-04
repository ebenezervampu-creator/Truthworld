import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
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

  group('Studio Alerts Tab Audit & Channel Notifications Guarantee Tests', () {
    testWidgets('1. Brand-new channel with 0 videos/claims ALWAYS receives at least one Studio Alert (Channel Health: Good Standing)',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.setChannelContext(
        channelId: 'chan_fresh_001',
        creatorId: 'creator_fresh_001',
      );
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      // Select Studio Alerts tab
      controller.selectTabById('studio_alerts');
      final items = controller.getUnifiedNotificationsForTab();

      // Guarantee: A channel has NEVER seen 0 notifications now!
      expect(items.isNotEmpty, isTrue);
      expect(items.first.alert?.title, contains('Channel Health: Good Standing'));
      expect(items.first.alert?.message, contains('All systems operational'));
      expect(items.first.alert?.category, equals('channel'));
    });

    testWidgets('2. Studio Alerts tab displays Video Processing In Progress and Video Processing Issue notifications',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.setChannelContext(
        channelId: 'chan_proc_001',
        creatorId: 'creator_proc_001',
      );
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      final procStarted = UserNotification(
        id: 'proc_start_1',
        userId: 'creator_proc_001',
        channelId: 'chan_proc_001',
        type: 'video_processing_started',
        severity: NotificationSeverity.info,
        priority: NotificationPriority.medium,
        title: 'Video Processing Started: "Climate Evidence"',
        message: 'Your video "Climate Evidence" is now undergoing AI processing.',
        targetApp: 'studio',
        category: 'pipeline',
        read: false,
        createdAt: DateTime.now(),
      );

      final procIssue = UserNotification(
        id: 'proc_issue_1',
        userId: 'creator_proc_001',
        channelId: 'chan_proc_001',
        type: 'video_processing_failed',
        severity: NotificationSeverity.warning,
        priority: NotificationPriority.high,
        title: 'Video Processing Issue: "Raw Footage"',
        message: 'Video encountered an issue during processing.',
        targetApp: 'studio',
        category: 'pipeline',
        read: false,
        createdAt: DateTime.now(),
      );

      controller.userNotificationController.notifications.assignAll([
        procStarted,
        procIssue,
      ]);

      controller.selectTabById('studio_alerts');
      final items = controller.getUnifiedNotificationsForTab();

      expect(items.any((i) => i.alert?.id == 'proc_start_1'), isTrue);
      expect(items.any((i) => i.alert?.id == 'proc_issue_1'), isTrue);
    });

    testWidgets('3. Video Moderation Rejected and Policy alerts enter Studio Alerts tab even with legacy verification tags',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.setChannelContext(
        channelId: 'chan_policy_001',
        creatorId: 'creator_policy_001',
      );
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      // Legacy notification that had type: verification_result but was actually a policy alert
      final policyRejection = UserNotification(
        id: 'legacy_policy_1',
        userId: 'creator_policy_001',
        channelId: 'chan_policy_001',
        type: 'verification_result',
        severity: NotificationSeverity.priority,
        priority: NotificationPriority.critical,
        title: 'Video Moderation Rejected: "Unverified Leaks"',
        message: 'Your video was not accepted due to Community Guidelines violations.',
        targetApp: 'studio',
        category: 'verification',
        read: false,
        createdAt: DateTime.now(),
      );

      controller.userNotificationController.notifications.assignAll([policyRejection]);

      controller.selectTabById('studio_alerts');
      final items = controller.getUnifiedNotificationsForTab();

      expect(items.any((i) => i.alert?.id == 'legacy_policy_1'), isTrue);
    });

    testWidgets('4. Fact-check results go strictly to Verifications tab while Studio Alerts receives operational alerts',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.setChannelContext(
        channelId: 'chan_split_001',
        creatorId: 'creator_split_001',
      );
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      final factCheckNotif = UserNotification(
        id: 'fc_report_1',
        userId: 'creator_split_001',
        channelId: 'chan_split_001',
        type: 'fact_check_completed',
        severity: NotificationSeverity.success,
        priority: NotificationPriority.medium,
        title: 'Fact-Check Completed',
        message: 'Truth verification analysis is complete: 94% verified claims.',
        targetApp: 'studio',
        category: 'verification',
        verificationReportId: 'rep_101',
        read: false,
        createdAt: DateTime.now(),
      );

      final copyrightAlert = UserNotification(
        id: 'cr_alert_1',
        userId: 'creator_split_001',
        channelId: 'chan_split_001',
        type: 'copyright_claim',
        severity: NotificationSeverity.warning,
        priority: NotificationPriority.high,
        title: 'Copyright Claim Notice',
        message: 'Audio match found on soundtrack.',
        targetApp: 'studio',
        category: 'copyright',
        read: false,
        createdAt: DateTime.now(),
      );

      controller.userNotificationController.notifications.assignAll([
        factCheckNotif,
        copyrightAlert,
      ]);

      // Check Verifications tab
      controller.selectTabById('verifications');
      var items = controller.getUnifiedNotificationsForTab();
      expect(items.any((i) => i.alert?.id == 'fc_report_1'), isTrue);
      expect(items.any((i) => i.alert?.id == 'cr_alert_1'), isFalse);

      // Check Studio Alerts tab
      controller.selectTabById('studio_alerts');
      items = controller.getUnifiedNotificationsForTab();
      expect(items.any((i) => i.alert?.id == 'cr_alert_1'), isTrue);
      expect(items.any((i) => i.alert?.id == 'fc_report_1'), isFalse);
    });

    testWidgets('5. Welcome to Creator Studio alert is classified and rendered in Studio Alerts',
        (tester) async {
      final controller = Get.put(NotificationViewController());
      controller.setChannelContext(
        channelId: 'chan_welcome_001',
        creatorId: 'creator_welcome_001',
      );
      controller.feedController.rxIsLoading.value = false;
      controller.userNotificationController.rxIsLoading.value = false;

      final welcomeNotif = UserNotification(
        id: 'welcome_chan_welcome_001',
        userId: 'creator_welcome_001',
        channelId: 'chan_welcome_001',
        type: 'channel_notifications',
        severity: NotificationSeverity.info,
        priority: NotificationPriority.medium,
        title: 'Welcome to Creator Studio: Veritas',
        message: 'Your channel @veritas is registered and ready. Channel health is in good standing.',
        targetApp: 'studio',
        category: 'channel',
        read: false,
        createdAt: DateTime.now(),
      );

      controller.userNotificationController.notifications.assignAll([welcomeNotif]);

      controller.selectTabById('studio_alerts');
      final items = controller.getUnifiedNotificationsForTab();

      expect(items.any((i) => i.alert?.id == 'welcome_chan_welcome_001'), isTrue);
    });

    testWidgets('6. ChannelNotificationsPage seamlessly resolves channel context from AuthService when opened without arguments',
        (tester) async {
      final testChannel = Channel.fromMap({
        'name': 'Auth Studio',
        'ownerId': 'creator_001',
      }, 'chan_auth_001');
      AuthService.to.setUserChannel(testChannel);

      await tester.pumpWidget(
        wrapWithMaterial(
          const ChannelNotificationsPage(),
        ),
      );
      await tester.pumpAndSettle();

      final controller = Get.find<NotificationViewController>();
      expect(controller.activeTabs.length, equals(6));
      expect(controller.activeTabs.any((t) => t.id == 'studio_alerts'), isTrue);
    });
  });
}
