import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_metrics_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_view_body.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_sidebar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/topics_widgets.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_view_router.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
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

  final testChannel = Channel(
    id: 'test_channel_playlists_topics',
    name: 'Truth Creator',
    nameLowercase: 'truth creator',
    handle: '@truthcreator',
    handleLowercase: '@truthcreator',
    description: 'Creator channel for playlists and topics test',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'test_owner_123',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  group('Studio ContentScreen Playlists & Topics Tabs Integration Tests', () {
    testWidgets('ContentScreen has 7 tabs including Playlists and Topics',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      Get.put(VideoManagementController());
      Get.put(PlaylistsManagementController());
      Get.put(TopicManagementController());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ContentScreen(
              channelId: 'test_channel_playlists_topics',
              isDarkMode: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify all 7 tab texts exist
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Topics'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);

      final tabBars = tester.widgetList<TabBar>(find.byType(TabBar));
      expect(tabBars.first.tabs.length, equals(7));

      // Tap on Playlists tab
      await tester.tap(find.text('Playlists'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Playlists cards view is rendered without the entire page / metrics bar
      expect(find.byType(PlaylistsViewBody), findsOneWidget);
      expect(find.byType(PlaylistsMetricsBar), findsNothing);
      expect(find.text('New Playlist'), findsOneWidget);

      // Tap on Topics tab
      await tester.tap(find.text('Topics'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Topics cards view is rendered without the entire page / metrics bar
      expect(find.byType(TopicsTab), findsOneWidget);
      expect(find.byType(TopicMetricsBar), findsNothing);
      expect(find.byType(TopicManagementSearchBar), findsNothing);
      expect(find.text('New Topic'), findsOneWidget);
    });

    testWidgets('Studio DashboardSidebar does NOT contain separate Playlists or Topic Management tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dashCtrl =
          Get.put(DashboardController(channelId: 'test_channel_playlists_topics'));

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DashboardSidebarMenu(
              controller: dashCtrl,
              isDarkMode: true,
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Standalone Playlists and Topic Management must NOT exist in the Studio sidebar
      expect(find.widgetWithText(DashboardSidebarItem, 'Playlists'), findsNothing);
      expect(find.widgetWithText(DashboardSidebarItem, 'Topic Management'), findsNothing);
      expect(find.widgetWithText(DashboardSidebarItem, 'Content'), findsOneWidget);

      dashCtrl.onClose();
    });

    testWidgets('DashboardViewRouter routes index 17 (Playlists) and 14 (Topics) to ContentScreen with correct initialIndex',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AuthService.to.isAuthenticated.value = true;
      AuthService.to.setUserChannel(testChannel);

      final dashCtrl =
          Get.put(DashboardController(channelId: 'test_channel_playlists_topics'));
      final viewCtrl = Get.put(DashboardViewController());
      Get.put(VideoManagementController());
      Get.put(PlaylistsManagementController());
      Get.put(TopicManagementController());

      dashCtrl.selectedIndex.value = 17; // Playlists

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
              horizontalPadding: 24,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ContentScreen), findsOneWidget);
      expect(find.byType(PlaylistsViewBody), findsOneWidget);
      expect(find.byType(PlaylistsMetricsBar), findsNothing);

      // Now route to Topics (index 14)
      dashCtrl.selectedIndex.value = 14;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ContentScreen), findsOneWidget);
      expect(find.byType(TopicsTab), findsOneWidget);
      expect(find.byType(TopicMetricsBar), findsNothing);

      dashCtrl.onClose();
      viewCtrl.onClose();
    });
  });
}
