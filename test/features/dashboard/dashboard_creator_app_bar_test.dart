import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/channel_notifications_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_creator_app_bar.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/modules/studio_routes.dart';
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
    id: 'test_channel_123',
    name: 'Truth Creator Studio Channel',
    nameLowercase: 'truth creator studio channel',
    handle: '@truthstudio',
    handleLowercase: '@truthstudio',
    description: 'Test channel description for dashboard testing',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'test_owner_123',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  testWidgets(
      'DashboardCreatorAppBar has no refresh icon and shows red notification count badge',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    AuthService.to.isAuthenticated.value = true;
    AuthService.to.setUserChannel(testChannel);

    final dashboardCtrl =
        Get.put(DashboardController(channelId: 'test_channel_123'));
    final viewCtrl = Get.put(DashboardViewController());
    final notifCtrl = Get.put(
      ChannelNotificationsController(
        channelId: 'test_channel_123',
        creatorId: 'test_owner_123',
      ),
    );

    // Initial state: unreadCount = 0
    notifCtrl.unreadCount.value = 0;

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => Scaffold(
              appBar: DashboardCreatorAppBar(
                viewController: viewCtrl,
                dashboardController: dashboardCtrl,
                isDarkMode: true,
                isDesktop: true,
                isMobile: false,
              ),
            ),
          ),
          ...StudioRoutes.routes,
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // 1. Verify refresh icon before notifications icon is removed
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byTooltip('Refresh Studio Data'), findsNothing);

    // 2. Verify notifications icon is present
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    // No red badge number when count is 0
    expect(find.text('5'), findsNothing);

    // 3. Update unreadCount to 5 and verify red badge count appears
    notifCtrl.unreadCount.value = 5;
    await tester.pump();

    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);

    // 4. Update unreadCount to 120 and verify '99+' appears
    notifCtrl.unreadCount.value = 120;
    await tester.pump();

    expect(find.text('99+'), findsOneWidget);

    // 5. Tapping notification button opens Channel Notifications as a separate page
    await tester.tap(find.byIcon(Icons.notifications_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(ChannelNotificationsPage), findsOneWidget);
    expect(Get.currentRoute, equals(AppRoutes.studioNotifications));
  });
}
