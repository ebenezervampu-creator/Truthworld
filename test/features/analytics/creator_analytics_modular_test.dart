import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/theme/app_theme.dart';
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
  });

  tearDown(Get.reset);

  Widget createHarness(Widget child) {
    return GetMaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('Creator Analytics Modular Components Tests', () {
    test('formatAnalyticsNumber formats integers accurately into human-readable strings', () {
      expect(formatAnalyticsNumber(0), '0');
      expect(formatAnalyticsNumber(999), '999');
      expect(formatAnalyticsNumber(1000), '1.0K');
      expect(formatAnalyticsNumber(2500), '2.5K');
      expect(formatAnalyticsNumber(1000000), '1.0M');
      expect(formatAnalyticsNumber(12500000), '12.5M');
    });

    testWidgets('CreatorSectionHeader renders section title and accent line', (tester) async {
      await tester.pumpWidget(
        createHarness(const CreatorSectionHeader(title: 'Key Metrics')),
      );

      expect(find.text('Key Metrics'), findsOneWidget);
    });

    testWidgets('CreatorGlassCard wraps children with surface decoration', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const CreatorGlassCard(
            child: Text('Glass Card Content'),
          ),
        ),
      );

      expect(find.text('Glass Card Content'), findsOneWidget);
    });

    testWidgets('CreatorLegendItem renders color indicator, label, and value', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const CreatorLegendItem(
            color: Colors.blue,
            label: 'Search',
            value: '500 (50.0%)',
          ),
        ),
      );

      expect(find.text('Search: 500 (50.0%)'), findsOneWidget);
    });

    testWidgets('CreatorPulsingDot renders live indicator dot', (tester) async {
      await tester.pumpWidget(
        createHarness(const CreatorPulsingDot()),
      );

      expect(find.byType(CreatorPulsingDot), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(createHarness(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CreatorDateRangeFilterPills renders date range options and responds to tap', (tester) async {
      final ctrl = Get.put(CreatorAnalyticsController());

      await tester.pumpWidget(
        createHarness(CreatorDateRangeFilterPills(controller: ctrl)),
      );

      expect(find.text(AnalyticsDateRange.last7Days.label), findsOneWidget);
      expect(find.text(AnalyticsDateRange.last28Days.label), findsOneWidget);

      await tester.tap(find.text(AnalyticsDateRange.last7Days.label));
      await tester.pump(const Duration(milliseconds: 250));

      expect(ctrl.selectedDateRange.value, AnalyticsDateRange.last7Days);
    });

    testWidgets('CreatorMetricCard renders title, value, and subtitle', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const CreatorMetricCard(
            icon: Icons.visibility_rounded,
            title: 'Views',
            value: '12.4K',
            subtitle: 'Past 28 days',
          ),
        ),
      );

      expect(find.text('Views'), findsOneWidget);
      expect(find.text('12.4K'), findsOneWidget);
      expect(find.text('Past 28 days'), findsOneWidget);
    });

    testWidgets('CreatorSummaryCardsGrid renders all 6 key performance cards', (tester) async {
      final ctrl = Get.put(CreatorAnalyticsController());
      ctrl.totalWatchTime.value = '45h 12m';
      ctrl.averageWatchTime.value = '4m 30s';
      ctrl.engagementScore.value = 82.5;
      ctrl.ctrValue.value = 7.8;
      ctrl.returningViewerCount.value = 340;
      ctrl.subscriberConversionRate.value = 4.25;

      await tester.pumpWidget(
        createHarness(CreatorSummaryCardsGrid(controller: ctrl)),
      );

      expect(find.text('Total Views'), findsOneWidget);
      expect(find.text('Watch Time'), findsOneWidget);
      expect(find.text('Engagement'), findsOneWidget);
      expect(find.text('CTR'), findsOneWidget);
      expect(find.text('Returning'), findsOneWidget);
      expect(find.text('Sub Conv.'), findsOneWidget);
      expect(find.text('45h 12m'), findsOneWidget);
      expect(find.text('82.5%'), findsOneWidget);
    });

    testWidgets('CreatorWatchtimeRetentionCard renders empty and populated retention views', (tester) async {
      final ctrl = Get.put(CreatorAnalyticsController());

      await tester.pumpWidget(
        createHarness(CreatorWatchtimeRetentionCard(controller: ctrl)),
      );
      expect(find.text('No retention data'), findsOneWidget);

      ctrl.watchtimeChartData.assignAll([
        PieChartDataModel(title: '0-25%', percentage: 60.0, value: 60, color: 0xFF00FF00),
        PieChartDataModel(title: '25-50%', percentage: 40.0, value: 40, color: 0xFF0000FF),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('0-25%: 60 (60.0%)'), findsOneWidget);
      expect(find.text('25-50%: 40 (40.0%)'), findsOneWidget);
    });

    testWidgets('CreatorTrafficSourceCard renders source breakdown and tests icon mapper', (tester) async {
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('search'), Icons.search_rounded);
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('suggested'), Icons.auto_awesome_rounded);
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('direct'), Icons.link_rounded);
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('external'), Icons.open_in_new_rounded);
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('channel_page'), Icons.person_rounded);
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('shorts_feed'), Icons.video_library_rounded);
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('trending'), Icons.trending_up_rounded);
      expect(CreatorTrafficSourceCard.getTrafficSourceIcon('unknown'), Icons.public_rounded);

      final ctrl = Get.put(CreatorAnalyticsController());

      await tester.pumpWidget(
        createHarness(CreatorTrafficSourceCard(controller: ctrl)),
      );
      expect(find.text('No traffic data'), findsOneWidget);

      ctrl.trafficSourceChartData.assignAll([
        PieChartDataModel(title: 'Search', percentage: 75.0, value: 75, color: 0xFF00FF00),
      ]);
      ctrl.trafficSourceStats.assignAll([
        TrafficSourceStat(source: 'Search', count: 120, percentage: 75.0, sourceKey: 'search'),
        TrafficSourceStat(source: 'Suggested', count: 40, percentage: 25.0, sourceKey: 'suggested'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Search'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
    });

    testWidgets('CreatorGeographicBreakdownCard renders regional data and rankings', (tester) async {
      final ctrl = Get.put(CreatorAnalyticsController());

      ctrl.topStates.assignAll([
        StateTrafficStat(stateName: 'California', viewCount: 1500, percentage: 65.0),
        StateTrafficStat(stateName: 'New York', viewCount: 800, percentage: 35.0),
      ]);

      await tester.pumpWidget(
        createHarness(CreatorGeographicBreakdownCard(controller: ctrl)),
      );

      expect(find.text('Top Region Performance'), findsOneWidget);
      expect(find.text('California'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
      expect(find.text('New York'), findsOneWidget);
      expect(find.text('800'), findsOneWidget);
    });

    testWidgets('CreatorTopCitiesCard renders city views rankings', (tester) async {
      final ctrl = Get.put(CreatorAnalyticsController());

      ctrl.cityTrafficChartData.assignAll([
        BarChartDataModel(label: 'Los Angeles', value: 500, percentage: 60.0, color: 0xFF00FF00),
        BarChartDataModel(label: 'San Francisco', value: 300, percentage: 40.0, color: 0xFF0000FF),
      ]);
      ctrl.topCities.assignAll([
        CityTrafficStat(cityName: 'Los Angeles', viewCount: 500, percentage: 60.0),
        CityTrafficStat(cityName: 'San Francisco', viewCount: 300, percentage: 40.0),
      ]);

      await tester.pumpWidget(
        createHarness(CreatorTopCitiesCard(controller: ctrl)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Los Angeles'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('San Francisco'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
    });

    testWidgets('CreatorAreaTypeCard renders urban and rural viewer distribution', (tester) async {
      final ctrl = Get.put(CreatorAnalyticsController());
      ctrl.urbanPercentage.value = 72.5;
      ctrl.ruralPercentage.value = 27.5;

      await tester.pumpWidget(
        createHarness(CreatorAreaTypeCard(controller: ctrl)),
      );

      expect(find.text('Urban Viewers'), findsOneWidget);
      expect(find.text('72.5%'), findsOneWidget);
      expect(find.text('Rural Viewers'), findsOneWidget);
      expect(find.text('27.5%'), findsOneWidget);
    });

    testWidgets('CreatorDeviceBreakdownCard renders device type distribution and tests device icon mapper', (tester) async {
      expect(CreatorDeviceBreakdownCard.getDeviceIcon('mobile'), Icons.phone_android_rounded);
      expect(CreatorDeviceBreakdownCard.getDeviceIcon('desktop'), Icons.desktop_windows_rounded);
      expect(CreatorDeviceBreakdownCard.getDeviceIcon('tablet'), Icons.tablet_android_rounded);
      expect(CreatorDeviceBreakdownCard.getDeviceIcon('other'), Icons.devices_rounded);

      final ctrl = Get.put(CreatorAnalyticsController());
      ctrl.deviceBreakdownStats.assignAll([
        DeviceStatStat(deviceType: 'mobile', count: 70, percentage: 70.0),
        DeviceStatStat(deviceType: 'desktop', count: 30, percentage: 30.0),
      ]);

      await tester.pumpWidget(
        createHarness(CreatorDeviceBreakdownCard(controller: ctrl)),
      );

      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('70.0%'), findsOneWidget);
      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('30.0%'), findsOneWidget);
    });

    testWidgets('CreatorLiveSubscribersBanner renders interactive banner', (tester) async {
      final ctrl = Get.put(CreatorAnalyticsController());

      await tester.pumpWidget(
        createHarness(
          CreatorLiveSubscribersBanner(
            channelId: 'channel_123',
            controller: ctrl,
          ),
        ),
      );

      expect(find.text('Live Subscribers of channel'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('See live count'), findsOneWidget);
    });

    testWidgets('CreatorAnalyticsDashboard full coordinator pumps and renders components', (tester) async {
      Get.put(CreatorAnalyticsController());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: CreatorAnalyticsDashboard(),
        ),
      );

      expect(find.byType(CreatorAnalyticsDashboard), findsOneWidget);
      expect(find.text('Channel Analytics'), findsOneWidget);
      expect(find.byType(CreatorSummaryCardsGrid), findsOneWidget);
      expect(find.byType(CreatorLiveSubscribersBanner), findsNothing);
      expect(find.text('Live Subscribers of channel'), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
