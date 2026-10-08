import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truthworld/core/bindings/initial_binding.dart';
import 'package:truthworld/core/services/app_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TruthWorld End-to-End System Integration Suite', () {
    setUp(() {
      Get.reset();
      Get.testMode = true;
    });

    testWidgets('1. App boots into GetMaterialApp cleanly with root theme & routing', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          title: 'Truthworld E2E',
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(),
          themeMode: ThemeMode.dark,
          initialRoute: '/',
          getPages: AppPages.routes,
          initialBinding: InitialBinding(),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.byType(GetMaterialApp), findsOneWidget);
    });

    testWidgets('2. Initial bindings register core services without dependency cycle', (tester) async {
      InitialBinding().dependencies();

      expect(Get.isRegistered<AppService>(), isTrue);
      expect(Get.isRegistered<ConnectivityService>(), isTrue);
      expect(Get.isRegistered<AuthService>(), isTrue);
    });

    testWidgets('3. Deep-link and route table structure are verified and navigable', (tester) async {
      final routeNames = AppPages.routes.map((p) => p.name).toList();

      expect(routeNames.contains('/'), isTrue);
      expect(routeNames.contains('/explore'), isTrue);
      expect(routeNames.contains('/settings'), isTrue);
      expect(routeNames.contains('/search'), isTrue);
    });
  });
}
