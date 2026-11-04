import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_screen.dart';
import 'package:truthworld/features/video/data/models/video.dart';
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

  testWidgets('AnalyticsScreen shimmer loading state has zero RenderFlex overflows on 360x720 phone', (tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = Get.put(
      AnalyticsController(channelId: 'test_channel_id'),
      tag: 'test_channel_id',
    );
    controller.rxIsLoading.value = true;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AnalyticsScreen(
          channelId: 'test_channel_id',
          isDarkMode: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AnalyticsScreen), findsOneWidget);
    final exception = tester.takeException();
    if (exception != null) {
      debugPrint('TEST 2 EXCEPTION: $exception');
    }
    expect(exception, isNull);
  });

  testWidgets('AnalyticsScreen loaded state has zero RenderFlex overflows on 360x720 phone', (tester) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = Get.put(
      AnalyticsController(channelId: 'test_channel_id'),
      tag: 'test_channel_id',
    );
    controller.rxIsLoading.value = false;
    controller.topVideos.value = [
      Video(
        id: 'vid_1',
        title: 'Top Performing Analysis of Real World Truth Metrics in Digital Networks',
        description: 'Test description',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        channelId: 'test_channel_id',
        channelName: 'Test Channel',
        category: 'Education',
        tags: const ['truth', 'analytics'],
        views: 125000,
        uploadedAt: Timestamp.now(),
      ),
      Video(
        id: 'vid_2',
        title: 'Second Best Performing Video',
        description: 'Test description 2',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        channelId: 'test_channel_id',
        channelName: 'Test Channel',
        category: 'News',
        tags: const ['news'],
        views: 45000,
        uploadedAt: Timestamp.now(),
      ),
    ];

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AnalyticsScreen(
          channelId: 'test_channel_id',
          isDarkMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnalyticsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnalyticsScreen loaded state has zero RenderFlex overflows on ultra narrow 320x640 screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = Get.put(
      AnalyticsController(channelId: 'test_channel_id_narrow'),
      tag: 'test_channel_id_narrow',
    );
    controller.rxIsLoading.value = false;
    controller.topVideos.value = [
      Video(
        id: 'vid_narrow',
        title: 'Super Long Title That Would Cause Overflow In Unconstrained Widgets Across Devices',
        description: 'Description',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        channelId: 'test_channel_id_narrow',
        channelName: 'Channel',
        category: 'Tech',
        tags: const ['tech'],
        views: 89000,
        uploadedAt: Timestamp.now(),
      ),
    ];

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AnalyticsScreen(
          channelId: 'test_channel_id_narrow',
          isDarkMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnalyticsScreen), findsOneWidget);
    final exception = tester.takeException();
    if (exception != null) {
      debugPrint('TEST 2 EXCEPTION: $exception');
    }
    expect(exception, isNull);
  });

  testWidgets('AnalyticsScreen does not show Live Subscribers button (handled in Audience tab)', (tester) async {
    final controller = Get.put(
      AnalyticsController(channelId: 'test_channel_id_no_live_subs'),
      tag: 'test_channel_id_no_live_subs',
    );
    controller.rxIsLoading.value = false;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AnalyticsScreen(
          channelId: 'test_channel_id_no_live_subs',
          isDarkMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnalyticsScreen), findsOneWidget);
    expect(find.text('Live Subscribers'), findsNothing);
    expect(find.text('Full Dashboard'), findsOneWidget);
  });
}
