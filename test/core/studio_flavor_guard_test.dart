import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  tearDown(() {
    AppFlavor.current = AppFlavor.app;
    Get.reset();
  });

  group('AppFlavor State & Detection Tests', () {
    test('defaults to AppFlavor.app and isConsumer == true', () {
      AppFlavor.current = AppFlavor.app;
      expect(AppFlavor.current, equals(AppFlavor.app));
      expect(AppFlavor.isConsumer, isTrue);
      expect(AppFlavor.isStudio, isFalse);
      expect(AppFlavor.isAdmin, isFalse);
      expect(AppFlavor.isAdvertiser, isFalse);
    });

    test('setting AppFlavor.studio correctly activates isStudio', () {
      AppFlavor.current = AppFlavor.studio;
      expect(AppFlavor.isStudio, isTrue);
      expect(AppFlavor.isConsumer, isFalse);
      expect(AppFlavor.isAdmin, isFalse);
      expect(AppFlavor.isAdvertiser, isFalse);
      expect(AppFlavor.current.initialRoute, equals('/studio'));
      expect(AppFlavor.current.appTitle, equals('Truthworld Studio'));
    });

    test('setting AppFlavor.admin correctly activates isAdmin', () {
      AppFlavor.current = AppFlavor.admin;
      expect(AppFlavor.isAdmin, isTrue);
      expect(AppFlavor.isStudio, isFalse);
      expect(AppFlavor.isConsumer, isFalse);
      expect(AppFlavor.current.initialRoute, equals('/admin/login'));
      expect(AppFlavor.current.appTitle, equals('Truthworld Admin'));
    });

    test('setting AppFlavor.advertiser correctly activates isAdvertiser', () {
      AppFlavor.current = AppFlavor.advertiser;
      expect(AppFlavor.isAdvertiser, isTrue);
      expect(AppFlavor.isStudio, isFalse);
      expect(AppFlavor.isConsumer, isFalse);
      expect(AppFlavor.current.initialRoute, equals('/advertiser'));
      expect(AppFlavor.current.appTitle, equals('Truthworld Advertiser'));
    });
  });

  group('StudioAccessGuard in Studio Flavor', () {
    test('never redirects out of studio in Studio mode even when unauthenticated', () {
      AppFlavor.current = AppFlavor.studio;
      final guard = StudioAccessGuard();
      final result = guard.redirect('/studio');
      // In Studio mode, it must return null so DashboardScreen can mount and render DashboardFallbackLogin
      expect(result, isNull);
    });

    test('redirects to consumer home when in consumer mode and unauthenticated', () {
      AppFlavor.current = AppFlavor.app;
      final guard = StudioAccessGuard();
      final result = guard.redirect('/studio');
      expect(result, isNotNull);
      expect(result!.name, equals('/'));
    });
  });

  group('ConsumerRouteGuard in Studio Flavor', () {
    test('redirects all consumer routes to /studio when in Studio flavor', () {
      AppFlavor.current = AppFlavor.studio;
      final guard = ConsumerRouteGuard();

      final routesToTest = [
        '/home',
        '/trending',
        '/clips',
        '/discover',
        '/history',
        '/likedvideos',
        '/watchlater',
        '/search',
        '/category',
        '/watch',
        '/watch/test-video-123',
      ];

      for (final route in routesToTest) {
        final result = guard.redirect(route);
        expect(result, isNotNull, reason: 'Route $route should be blocked in Studio');
        expect(result!.name, equals('/studio'), reason: 'Route $route must redirect to /studio');
      }
    });

    test('allows consumer routes when in consumer app flavor', () {
      AppFlavor.current = AppFlavor.app;
      final guard = ConsumerRouteGuard();

      final routesToTest = [
        '/home',
        '/trending',
        '/clips',
        '/discover',
        '/history',
        '/likedvideos',
        '/watchlater',
        '/search',
        '/category',
        '/watch',
      ];

      for (final route in routesToTest) {
        final result = guard.redirect(route);
        expect(result, isNull, reason: 'Route $route should be allowed in consumer mode');
      }
    });
  });

  group('HomeRedirectMiddleware in Studio Flavor', () {
    test('redirects /home to /studio in Studio mode', () {
      AppFlavor.current = AppFlavor.studio;
      final middleware = HomeRedirectMiddleware();
      final result = middleware.redirect('/home');
      expect(result, isNotNull);
      expect(result!.name, equals('/studio'));
    });

    test('redirects /home to / in Consumer mode', () {
      AppFlavor.current = AppFlavor.app;
      final middleware = HomeRedirectMiddleware();
      final result = middleware.redirect('/home');
      expect(result, isNotNull);
      expect(result!.name, equals('/'));
    });
  });

  group('FirebaseOptions Flavor Resolution Tests', () {
    test('resolves dedicated Android options matching each flavor package', () {
      final studioOptions = DefaultFirebaseOptions.forFlavor(AppFlavor.studio);
      expect(studioOptions.appId, equals(DefaultFirebaseOptions.androidStudio.appId));

      final advertiserOptions = DefaultFirebaseOptions.forFlavor(AppFlavor.advertiser);
      expect(advertiserOptions.appId, equals(DefaultFirebaseOptions.androidAdvertiser.appId));

      final adminOptions = DefaultFirebaseOptions.forFlavor(AppFlavor.admin);
      expect(adminOptions.appId, equals(DefaultFirebaseOptions.androidAdmin.appId));

      final consumerOptions = DefaultFirebaseOptions.forFlavor(AppFlavor.app);
      expect(consumerOptions.appId, equals(DefaultFirebaseOptions.android.appId));
    });

    test('currentPlatform dynamically adapts to AppFlavor.current', () {
      AppFlavor.current = AppFlavor.studio;
      expect(DefaultFirebaseOptions.currentPlatform.appId, equals(DefaultFirebaseOptions.androidStudio.appId));

      AppFlavor.current = AppFlavor.advertiser;
      expect(DefaultFirebaseOptions.currentPlatform.appId, equals(DefaultFirebaseOptions.androidAdvertiser.appId));

      AppFlavor.current = AppFlavor.app;
      expect(DefaultFirebaseOptions.currentPlatform.appId, equals(DefaultFirebaseOptions.android.appId));
    });
  });
}
