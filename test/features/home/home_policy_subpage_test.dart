import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  testWidgets(
      'Home switches between Terms and Community Guidelines seamlessly via rail and AppBar actions',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Get.put(HomeController());

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Home(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Tap Terms & Conditions in the rail
    final railTerms = find.descendant(
      of: find.byType(ModernSideNavigationRail),
      matching: find.text('Terms & Conditions'),
    );
    expect(railTerms, findsOneWidget);
    await tester.tap(railTerms);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Terms and Conditions | Truthworld'), findsOneWidget);

    // 2. Now tap Community Guidelines in the rail
    final railGuidelines = find.descendant(
      of: find.byType(ModernSideNavigationRail),
      matching: find.text('Community Guidelines'),
    );
    expect(railGuidelines, findsOneWidget);
    await tester.tap(railGuidelines);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Community Guidelines | Truthworld'), findsOneWidget);

    // 3. From Community Guidelines, tap Terms in the AppBar action
    final appBarTerms = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Terms of Service'),
    );
    expect(appBarTerms, findsOneWidget);
    await tester.tap(appBarTerms);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Terms and Conditions | Truthworld'), findsOneWidget);

    // 4. From Terms, tap Community Guidelines in the AppBar action
    final appBarGuidelines = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Community Guidelines'),
    );
    expect(appBarGuidelines, findsOneWidget);
    await tester.tap(appBarGuidelines);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Community Guidelines | Truthworld'), findsOneWidget);
  });
}
