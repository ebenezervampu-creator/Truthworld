import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/creator_intelligence_page.dart';
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

  group('CreatorIntelligencePage Modular Architecture Tests', () {
    testWidgets('1. IntelligenceHeaderBanner renders title, description and unread badge',
        (tester) async {
      final controller = Get.put(
        CreatorIntelligenceController(
          channelId: 'chan_test_101',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_101',
      );
      controller.unreadCount.value = 3;

      await tester.pumpWidget(
        wrapWithMaterial(
          IntelligenceHeaderBanner(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Creator Intelligence'), findsOneWidget);
      expect(find.text('3 UNREAD'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);
      expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
    });

    testWidgets('2. IntelligenceFilterChips renders categories and handles tap',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(
        CreatorIntelligenceController(
          channelId: 'chan_test_102',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_102',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          IntelligenceFilterChips(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Insights'), findsOneWidget);
      expect(find.text('Critical & Policy'), findsOneWidget);
      expect(find.text('Milestones & Growth'), findsOneWidget);
      expect(find.text('Fact Verification'), findsOneWidget);

      await tester.tap(find.text('Critical & Policy'));
      await tester.pumpAndSettle();

      expect(controller.selectedCategory.value, equals('critical'));
    });

    testWidgets('3. IntelligenceEmptyState renders illustration and guidance',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const IntelligenceEmptyState(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Creator Insights Yet'), findsOneWidget);
      expect(
        find.textContaining('Milestones, video verification audit reports'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
    });

    testWidgets('4. IntelligenceIssueCard renders badge, message and action buttons',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          IntelligenceIssueCard(
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

    testWidgets('5. IntelligenceCriticalSection renders urgent notices',
        (tester) async {
      final controller = Get.put(
        CreatorIntelligenceController(
          channelId: 'chan_test_103',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_103',
      );
      controller.notifications.assignAll([sampleCriticalNotification]);

      await tester.pumpWidget(
        wrapWithMaterial(
          IntelligenceCriticalSection(
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

    testWidgets('6. IntelligenceNotificationCard renders analytics pill and content',
        (tester) async {
      final controller = Get.put(
        CreatorIntelligenceController(
          channelId: 'chan_test_104',
          creatorId: 'creator_123',
        ),
        tag: 'chan_test_104',
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          IntelligenceNotificationCard(
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
  });
}
