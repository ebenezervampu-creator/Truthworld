import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_recommendations_section.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_sidebar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_overview_content.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_view_router.dart';
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

  final unmonetizedChannel = Channel(
    id: 'ch_unmonetized',
    name: 'Unmonetized Channel',
    nameLowercase: 'unmonetized channel',
    handle: '@unmonetized',
    handleLowercase: '@unmonetized',
    description: 'Unmonetized channel description',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_unmonetized',
    isMonetized: false,
    monetizationTier: MonetizationTier.none,
    subscriberCount: 100,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final monetizedChannel = Channel(
    id: 'ch_monetized',
    name: 'Monetized Channel',
    nameLowercase: 'monetized channel',
    handle: '@monetized',
    handleLowercase: '@monetized',
    description: 'Monetized channel description',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_monetized',
    isMonetized: true,
    monetizationTier: MonetizationTier.standard,
    subscriberCount: 100,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  group('Studio Memberships Tab Visibility Tests', () {
    testWidgets('Sidebar does NOT render Memberships tab for unmonetized channel',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = DashboardController(
        channelId: 'ch_unmonetized',
        autoInitialize: false,
      );
      controller.currentChannel.value = unmonetizedChannel;
      Get.put<DashboardController>(controller);

      expect(controller.isChannelMonetizationActive, isFalse);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DashboardSidebarMenu(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Memberships label should NOT be rendered in the sidebar menu
      expect(find.text('Memberships'), findsNothing);
      // Other standard tabs must still be present
      expect(find.text('Studio Home'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
    });

    testWidgets('Sidebar DOES render Memberships tab for monetized channel',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = DashboardController(
        channelId: 'ch_monetized',
        autoInitialize: false,
      );
      controller.currentChannel.value = monetizedChannel;
      Get.put<DashboardController>(controller);

      expect(controller.isChannelMonetizationActive, isTrue);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DashboardSidebarMenu(
              controller: controller,
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Memberships label must be rendered in the sidebar menu
      expect(find.text('Memberships'), findsOneWidget);
      expect(find.text('Studio Home'), findsOneWidget);
    });

    test('DashboardController setSelectedIndex ignores 18 when not monetized',
        () {
      final controller = DashboardController(
        channelId: 'ch_unmonetized',
        autoInitialize: false,
      );
      controller.currentChannel.value = unmonetizedChannel;

      controller.selectedIndex.value = 1;
      controller.setSelectedIndex(18);
      // Should remain 1 because channel is not monetized
      expect(controller.selectedIndex.value, equals(1));

      // For monetized channel, switching to 18 succeeds
      controller.currentChannel.value = monetizedChannel;
      controller.setSelectedIndex(18);
      expect(controller.selectedIndex.value, equals(18));
    });

    test('DashboardController applyRouteTargetIfPresent redirects memberships to 1 for unmonetized channel',
        () {
      final controller = DashboardController(
        channelId: 'ch_unmonetized',
        autoInitialize: false,
      );
      controller.currentChannel.value = unmonetizedChannel;

      // Passing 'memberships' as tab parameter
      Get.parameters['tab'] = 'memberships';
      controller.applyRouteTargetIfPresent();
      expect(controller.selectedIndex.value, equals(1));

      // Passing '18' as int-parsable tab parameter
      Get.parameters['tab'] = '18';
      controller.applyRouteTargetIfPresent();
      expect(controller.selectedIndex.value, equals(1));

      // For monetized channel, parameter selects 18
      controller.currentChannel.value = monetizedChannel;
      controller.applyRouteTargetIfPresent();
      expect(controller.selectedIndex.value, equals(18));

      Get.parameters.clear();
    });

    testWidgets('DashboardViewRouter returns OverviewContent instead of MembershipsScreen for unmonetized channel',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(unmonetizedChannel);

      final dashCtrl = DashboardController(
        channelId: 'ch_unmonetized',
        autoInitialize: false,
      );
      dashCtrl.currentChannel.value = unmonetizedChannel;
      dashCtrl.selectedIndex.value = 18;
      Get.put<DashboardController>(dashCtrl);

      final viewCtrl = Get.put(DashboardViewController());
      viewCtrl.isSelectingDefault.value = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DashboardViewRouter(
              viewController: viewCtrl,
              dashboardController: dashCtrl,
              isDarkMode: true,
              isMobile: false,
              isDesktop: true,
              isTablet: false,
              horizontalPadding: 16.0,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Should render DashboardOverviewContent, never MembershipsScreen
      expect(find.byType(MembershipsScreen), findsNothing);
      expect(find.byType(DashboardOverviewContent), findsOneWidget);
    });

    test('DashboardRecommendationsSection does not recommend memberships for unmonetized channel',
        () {
      final controller = DashboardController(
        channelId: 'ch_unmonetized',
        autoInitialize: false,
      );
      controller.currentChannel.value = unmonetizedChannel;

      final recsUnmonetized = DashboardRecommendationsSection.generateRecommendations(
        unmonetizedChannel,
        [],
        {},
        controller,
      );
      final membershipsRecUnmonetized = recsUnmonetized.firstWhereOrNull(
        (r) => r['title'] == 'Explore Channel Memberships',
      );
      expect(membershipsRecUnmonetized, isNull);

      // Now for monetized channel with >= 50 subscribers:
      controller.currentChannel.value = monetizedChannel;
      final recsMonetized = DashboardRecommendationsSection.generateRecommendations(
        monetizedChannel,
        [],
        {},
        controller,
      );
      final membershipsRecMonetized = recsMonetized.firstWhereOrNull(
        (r) => r['title'] == 'Explore Channel Memberships',
      );
      expect(membershipsRecMonetized, isNotNull);
    });

    test('RevenueAnalyticsController navigateToMemberships redirects to Monetization tab when unmonetized',
        () {
      final dashCtrl = DashboardController(
        channelId: 'ch_unmonetized',
        autoInitialize: false,
      );
      dashCtrl.currentChannel.value = unmonetizedChannel;
      dashCtrl.selectedIndex.value = 1;
      Get.put<DashboardController>(dashCtrl);

      final revCtrl = Get.put(RevenueAnalyticsController());
      revCtrl.channelId.value = 'ch_unmonetized';

      revCtrl.navigateToMemberships();
      // Should redirect to tab 5 (Earnings / Monetization) because channel is unmonetized
      expect(dashCtrl.selectedIndex.value, equals(5));

      // When monetized, it navigates to tab 18
      dashCtrl.currentChannel.value = monetizedChannel;
      revCtrl.navigateToMemberships();
      expect(dashCtrl.selectedIndex.value, equals(18));
    });
  });
}
