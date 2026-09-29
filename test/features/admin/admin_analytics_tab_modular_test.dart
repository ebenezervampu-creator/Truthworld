import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/analytics_tab.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
  });
  tearDown(Get.reset);

  group('Admin Analytics Tab Modular Components Tests', () {
    testWidgets('AdminAnalyticsHeader renders title and dropdown time ranges',
        (tester) async {
      final controller = Get.put(AdminController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AdminAnalyticsHeader(controller: controller),
          ),
        ),
      );

      expect(find.text('Platform Safety & Moderation Analytics'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('AdminAnalyticsMetricsCards renders 4 metric cards with proper values',
        (tester) async {
      final sampleData = {
        'safetyScore': 92,
        'totalModerated': 1420,
        'autoApprovalRate': 88,
        'activeViolations': 3,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnalyticsMetricsCards(
              constraints: const BoxConstraints(maxWidth: 1200),
              data: sampleData,
            ),
          ),
        ),
      );

      expect(find.text('Platform Safety Score'), findsOneWidget);
      expect(find.text('92/100'), findsOneWidget);
      expect(find.text('Optimal Platform Health'), findsOneWidget);

      expect(find.text('Total Content Moderated'), findsOneWidget);
      expect(find.text('1420'), findsOneWidget);

      expect(find.text('Auto-Approved Rate'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);

      expect(find.text('Active Violations'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('AdminAnalyticsPlatformOverviewBar renders platform statistics chips',
        (tester) async {
      final sampleData = {
        'platformTotals': {
          'totalUsers': 5400,
          'totalVideos': 1200,
          'totalChannels': 350,
          'totalReports': 85,
          'totalAppeals': 12,
          'bannedUsers': 4,
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnalyticsPlatformOverviewBar(data: sampleData),
          ),
        ),
      );

      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('5400'), findsOneWidget);
      expect(find.text('Total Videos'), findsOneWidget);
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('Total Channels'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(find.text('Total Reports'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
      expect(find.text('Content Appeals'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Banned Accounts'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('AdminAnalyticsContentFunnel renders queue funnel breakdown',
        (tester) async {
      final sampleData = {
        'breakdown': {
          'videos': {'total': 150, 'approved': 140, 'rejected': 5, 'pending': 5},
          'media': {'total': 80, 'approved': 75, 'rejected': 3, 'pending': 2},
          'channels': {'total': 30, 'approved': 28, 'rejected': 1, 'pending': 1},
          'reports': {'total': 45, 'resolved': 40, 'dismissed': 3, 'pending': 2},
          'appeals': {'total': 10, 'overturned': 7, 'upheld': 2, 'pending': 1},
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnalyticsContentFunnel(
              constraints: const BoxConstraints(maxWidth: 1200),
              data: sampleData,
            ),
          ),
        ),
      );

      expect(find.text('Content Moderation Funnel'), findsOneWidget);
      expect(find.text('Videos Queue'), findsOneWidget);
      expect(find.text('Media & Posts'), findsOneWidget);
      expect(find.text('Channels Queue'), findsOneWidget);
      expect(find.text('User Reports'), findsOneWidget);
      expect(find.text('Appeals'), findsOneWidget);
    });

    testWidgets('AdminAnalyticsViolationChart renders zero violations state when empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminAnalyticsViolationChart(data: {}),
          ),
        ),
      );

      expect(find.text('Zero Violations Recorded'), findsOneWidget);
    });

    testWidgets('AdminAnalyticsViolationChart renders horizontal bars when data is present',
        (tester) async {
      final sampleData = {
        'violationCategories': {
          'Misinformation': 15,
          'Harassment': 10,
          'Copyright': 5,
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnalyticsViolationChart(data: sampleData),
          ),
        ),
      );

      expect(find.text('3 Categories'), findsOneWidget);
      expect(find.text('Misinformation'), findsOneWidget);
      expect(find.text('Harassment'), findsOneWidget);
      expect(find.text('Copyright'), findsOneWidget);
    });

    testWidgets('AdminAnalyticsTopOffenders renders repeat offenders list',
        (tester) async {
      final sampleData = {
        'topOffenders': [
          {
            'user': 'spammer_99',
            'email': 'spam@bad.com',
            'violationsCount': 8,
            'strikes': 3,
            'isBanned': true,
          },
        ]
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnalyticsTopOffenders(data: sampleData),
          ),
        ),
      );

      expect(find.text('Top Repeat Offenders'), findsOneWidget);
      expect(find.text('1 Accounts'), findsOneWidget);
      expect(find.text('spammer_99'), findsOneWidget);
      expect(find.text('BANNED'), findsOneWidget);
      expect(find.text('8 violations'), findsOneWidget);
      expect(find.text('3 strikes'), findsOneWidget);
    });

    testWidgets('AnalyticsTab coordinator renders seamlessly',
        (tester) async {
      final controller = Get.put(AdminController());
      controller.analyticsData.assignAll({
        'safetyScore': 95,
        'totalModerated': 500,
        'autoApprovalRate': 90,
        'activeViolations': 0,
      });

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AnalyticsTab(controller: controller),
          ),
        ),
      );

      expect(find.byType(AnalyticsTab), findsOneWidget);
      expect(find.text('Platform Safety & Moderation Analytics'), findsOneWidget);
      expect(find.text('95/100'), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}
