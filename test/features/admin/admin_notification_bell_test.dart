import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/dashboard_components/admin_notification_bell.dart';
import 'package:truthworld/features/admin/presentation/views/dashboard_components/admin_notifications_modal.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import '../../test_helpers/mock_firebase.dart';

class TestAdminController extends AdminController {
  @override
  // ignore: must_call_super
  void onInit() {
    // Avoid starting live Firestore streams in widget tests
  }

  @override
  void ensureSubscriptionsStarted() {
    // Avoid starting live Firestore streams in widget tests
  }
}

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
  });

  tearDown(Get.reset);

  group('AdminNotificationBell and Modal Tests', () {
    testWidgets('renders AdminNotificationBell with zero unread badge', (tester) async {
      Get.put(UserNotificationController(), permanent: true);
      final adminCtrl = Get.put<AdminController>(TestAdminController());
      adminCtrl.isAdmin.value = true;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                AdminNotificationBell(controller: adminCtrl),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AdminNotificationBell), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    testWidgets('renders AdminNotificationBell with active badge when unread notifications exist', (tester) async {
      final notifCtrl = Get.put(UserNotificationController(), permanent: true);
      final adminCtrl = Get.put<AdminController>(TestAdminController());
      adminCtrl.isAdmin.value = true;

      notifCtrl.notifications.assignAll([
        UserNotification(
          id: 'notif_admin_1',
          userId: 'admin_user',
          type: 'moderation_escalation',
          title: 'Urgent Video Escalation',
          message: 'Video vid_esc_1 requires immediate review.',
          targetApp: 'admin',
          severity: NotificationSeverity.priority,
          read: false,
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                AdminNotificationBell(controller: adminCtrl),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AdminNotificationBell), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('renders AdminNotificationsModal and displays moderation alert item', (tester) async {
      final notifCtrl = Get.put(UserNotificationController(), permanent: true);
      final adminCtrl = Get.put<AdminController>(TestAdminController());
      adminCtrl.isAdmin.value = true;

      notifCtrl.notifications.assignAll([
        UserNotification(
          id: 'notif_admin_2',
          userId: 'admin_user',
          type: 'kyc_submitted',
          title: 'KYC Document Submitted',
          message: 'Creator channel_100 submitted KYC verification documents.',
          targetApp: 'admin',
          severity: NotificationSeverity.info,
          read: false,
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AdminNotificationsModal(controller: adminCtrl),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Admin Moderation Alerts'), findsOneWidget);
      expect(find.text('KYC Document Submitted'), findsOneWidget);
      expect(find.text('Creator channel_100 submitted KYC verification documents.'), findsOneWidget);
      expect(find.text('Queues'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Appeals'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
    });

    test('applyRouteTargetIfPresent updates currentTab and selects entities', () {
      final adminCtrl = Get.put<AdminController>(TestAdminController());
      adminCtrl.isAdmin.value = true;
      adminCtrl.currentAdminEmail.value = 'hello@truthworld.in';

      // 1. Videos queue
      adminCtrl.videos.assignAll([
        {'id': 'v_target_1', 'title': 'Flagged Video'},
      ]);
      adminCtrl.applyRouteTargetIfPresent('videos', {'videoId': 'v_target_1'});
      expect(adminCtrl.currentTab.value, equals('videos'));
      expect(adminCtrl.selectedVideo.value?['id'], equals('v_target_1'));

      // 2. Reports queue
      adminCtrl.reports.assignAll([
        {'id': 'r_target_2', 'reason': 'Hate speech'},
      ]);
      adminCtrl.applyRouteTargetIfPresent('reports', {'reportId': 'r_target_2'});
      expect(adminCtrl.currentTab.value, equals('reports'));
      expect(adminCtrl.selectedReport.value?['id'], equals('r_target_2'));

      // 3. Channels queue
      adminCtrl.channels.assignAll([
        {'id': 'c_target_3', 'name': 'New Creator'},
      ]);
      adminCtrl.applyRouteTargetIfPresent('channels', {'channelId': 'c_target_3'});
      expect(adminCtrl.currentTab.value, equals('channels'));
      expect(adminCtrl.selectedChannel.value?['id'], equals('c_target_3'));

      // 4. Appeals queue
      adminCtrl.applyRouteTargetIfPresent('appeals');
      expect(adminCtrl.currentTab.value, equals('appeals'));

      // 5. Security & Alerts queue
      adminCtrl.applyRouteTargetIfPresent('alerts');
      expect(adminCtrl.currentTab.value, equals('alerts'));
    });
  });
}
