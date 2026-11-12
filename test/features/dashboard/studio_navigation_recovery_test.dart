import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/bindings/dashboard_binding.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = false;
    AppFlavor.current = AppFlavor.app;
    RouteStackObserver.routeStack.clear();

    Get.put<AuthService>(AuthService(), permanent: true);
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
  });

  tearDown(() {
    RouteStackObserver.routeStack.clear();
    AppFlavor.current = AppFlavor.app;
    Get.reset();
    Get.testMode = true;
  });

  final testChannel = Channel(
    id: 'test_studio_channel',
    name: 'Truth Studio',
    nameLowercase: 'truth studio',
    handle: '@truthstudio',
    handleLowercase: '@truthstudio',
    description: 'Studio channel for navigation recovery testing',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'test_owner_1',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('RouteStackObserver.isStudioDashboardPath', () {
    test('recognizes Studio dashboard routes and excludes child sub-pages', () {
      AppFlavor.current = AppFlavor.app;
      expect(RouteStackObserver.isStudioDashboardPath('/studio'), isTrue);
      expect(
        RouteStackObserver.isStudioDashboardPath('/studio?tab=content'),
        isTrue,
      );
      expect(RouteStackObserver.isStudioDashboardPath('/dashboard'), isTrue);
      expect(
        RouteStackObserver.isStudioDashboardPath('/studio/chapters'),
        isTrue,
      );
      expect(RouteStackObserver.isStudioDashboardPath('/studio/trash'), isTrue);
      expect(
        RouteStackObserver.isStudioDashboardPath('/studio/drafts'),
        isTrue,
      );
      expect(
        RouteStackObserver.isStudioDashboardPath('/studio/community'),
        isTrue,
      );

      expect(RouteStackObserver.isStudioDashboardPath('/'), isFalse);
      expect(RouteStackObserver.isStudioDashboardPath('/home'), isFalse);
      expect(RouteStackObserver.isStudioDashboardPath('/upload'), isFalse);
      expect(
        RouteStackObserver.isStudioDashboardPath('/upload/video'),
        isFalse,
      );
      expect(
        RouteStackObserver.isStudioDashboardPath('/studio/notifications'),
        isFalse,
      );
      expect(
        RouteStackObserver.isStudioDashboardPath('/studio/memberships/create'),
        isFalse,
      );
    });

    test('recognizes root and /home in Studio flavor', () {
      AppFlavor.current = AppFlavor.studio;
      expect(RouteStackObserver.isStudioDashboardPath('/'), isTrue);
      expect(RouteStackObserver.isStudioDashboardPath('/home'), isTrue);
    });
  });

  group('RouteStackObserver.navigateToStudio', () {
    testWidgets(
      'pops child upload routes back to existing /studio without recreating controllers',
      (tester) async {
        setDesktopSize(tester);
        AuthService.to.isAuthenticated.value = true;
        AuthService.to.setUserChannel(testChannel);

        final dashCtrl = DashboardController(
          channelId: testChannel.id,
          autoInitialize: false,
        );
        dashCtrl.currentChannel.value = testChannel;
        Get.put<DashboardController>(dashCtrl);

        await tester.pumpWidget(
          GetMaterialApp(
            navigatorObservers: [RouteStackObserver()],
            initialRoute: '/studio',
            getPages: [
              GetPage<void>(
                name: '/studio',
                page: () => const DashboardScreen(),
                binding: DashboardBinding(),
                transition: Transition.noTransition,
                transitionDuration: Duration.zero,
              ),
              GetPage<void>(
                name: '/upload',
                page: () => const Scaffold(body: Text('Upload Selection')),
                transition: Transition.noTransition,
                transitionDuration: Duration.zero,
              ),
              GetPage<void>(
                name: '/upload/video',
                page: () => const Scaffold(body: Text('Upload Video')),
                transition: Transition.noTransition,
                transitionDuration: Duration.zero,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byType(DashboardOverviewContent), findsOneWidget);
        final initialViewCtrl = Get.find<DashboardViewController>();
        expect(initialViewCtrl.isDisposed, isFalse);

        // Simulate Studio -> /upload -> /upload/video
        unawaited(Get.toNamed<void>('/upload'));
        await tester.pump();
        unawaited(Get.toNamed<void>('/upload/video'));
        await tester.pump();

        expect(
          RouteStackObserver.routeStack.map((r) => r.settings.name).toList(),
          equals(['/studio', '/upload', '/upload/video']),
        );

        // Repeated calls simulate UploadSubmissionMixin + CreateContentController
        RouteStackObserver.navigateToStudio();
        RouteStackObserver.navigateToStudio();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(
          RouteStackObserver.routeStack.map((r) => r.settings.name).toList(),
          equals(['/studio']),
        );
        expect(identical(Get.find<DashboardViewController>(), initialViewCtrl), isTrue);
        expect(initialViewCtrl.isDisposed, isFalse);
        expect(find.byType(DashboardOverviewContent), findsOneWidget);

        final routerFade = tester.widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(DashboardViewRouter),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(routerFade.opacity.value, equals(1.0));
      },
    );

    testWidgets(
      'navigates cleanly to /studio when /studio is not yet in the stack',
      (tester) async {
        setDesktopSize(tester);
        AuthService.to.isAuthenticated.value = true;
        AuthService.to.setUserChannel(testChannel);

        final dashCtrl = DashboardController(
          channelId: testChannel.id,
          autoInitialize: false,
        );
        dashCtrl.currentChannel.value = testChannel;
        Get.put<DashboardController>(dashCtrl);

        await tester.pumpWidget(
          GetMaterialApp(
            navigatorObservers: [RouteStackObserver()],
            initialRoute: '/upload/video',
            getPages: [
              GetPage<void>(
                name: '/upload/video',
                page: () => const Scaffold(body: Text('Upload Video')),
                transition: Transition.noTransition,
                transitionDuration: Duration.zero,
              ),
              GetPage<void>(
                name: '/studio',
                page: () => const DashboardScreen(),
                binding: DashboardBinding(),
                transition: Transition.noTransition,
                transitionDuration: Duration.zero,
              ),
            ],
          ),
        );
        await tester.pump();

        expect(
          RouteStackObserver.routeStack.map((r) => r.settings.name).toList(),
          equals(['/upload/video']),
        );

        RouteStackObserver.navigateToStudio();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(
          RouteStackObserver.routeStack.map((r) => r.settings.name).toList(),
          equals(['/studio']),
        );
        expect(find.byType(DashboardOverviewContent), findsOneWidget);
      },
    );
  });

  group('DashboardScreen and DashboardViewRouter disposal recovery', () {
    testWidgets(
      'DashboardScreen recovers live controller when DashboardViewController is deleted mid-frame',
      (tester) async {
        setDesktopSize(tester);
        AuthService.to.isAuthenticated.value = true;
        AuthService.to.setUserChannel(testChannel);

        final dashCtrl = DashboardController(
          channelId: testChannel.id,
          autoInitialize: false,
        );
        dashCtrl.currentChannel.value = testChannel;
        Get.put<DashboardController>(dashCtrl);

        await tester.pumpWidget(
          GetMaterialApp(
            navigatorObservers: [RouteStackObserver()],
            initialRoute: '/studio',
            getPages: [
              GetPage<void>(
                name: '/studio',
                page: () => const DashboardScreen(),
                binding: DashboardBinding(),
                transition: Transition.noTransition,
                transitionDuration: Duration.zero,
              ),
            ],
          ),
        );
        await tester.pump();
        final firstCtrl = Get.find<DashboardViewController>();
        firstCtrl.isSelectingDefault.value = false;
        await tester.pump();

        // Simulate GetX old-route disposal race deleting the active controller
        // immediately before the reveal animation advances past 0.0.
        Get.delete<DashboardViewController>();
        expect(firstCtrl.isDisposed, isTrue);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        final recoveredCtrl = Get.find<DashboardViewController>();
        expect(identical(recoveredCtrl, firstCtrl), isFalse);
        expect(recoveredCtrl.isDisposed, isFalse);
        expect(find.byType(DashboardOverviewContent), findsOneWidget);

        final routerFade = tester.widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(DashboardViewRouter),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(routerFade.opacity.value, equals(1.0));
      },
    );

    testWidgets(
      'DashboardViewRouter bypasses dead FadeTransition when passed a disposed controller',
      (tester) async {
        setDesktopSize(tester);
        AuthService.to.isAuthenticated.value = true;
        AuthService.to.setUserChannel(testChannel);

        final dashCtrl = DashboardController(
          channelId: testChannel.id,
          autoInitialize: false,
        );
        dashCtrl.currentChannel.value = testChannel;
        Get.put<DashboardController>(dashCtrl);

        final viewCtrl = Get.put(DashboardViewController());
        viewCtrl.isSelectingDefault.value = false;
        Get.delete<DashboardViewController>();
        expect(viewCtrl.isDisposed, isTrue);

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
                horizontalPadding: 32,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DashboardOverviewContent), findsOneWidget);
      },
    );
  });
}
