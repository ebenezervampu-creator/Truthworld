import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/core/widgets/truthworld_splash_screen.dart';

void main() {
  testWidgets('TruthworldSplashScreen renders increased logo and white text when space fits',
      (tester) async {
    // Normal mobile screen size: 390 x 844
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TruthworldSplashScreen.reset();

    await tester.pumpWidget(
      const MaterialApp(
        home: TruthworldSplashScreen(
          duration: Duration(milliseconds: 500),
          child: Scaffold(body: Text('Home Content')),
        ),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify AppLogo is present and its size is increased (>= 130px)
    final logoFinder = find.byType(AppLogo);
    expect(logoFinder, findsOneWidget);
    final appLogo = tester.widget<AppLogo>(logoFinder);
    expect(appLogo.size, greaterThanOrEqualTo(130.0));

    // Fast-forward animation partially so text fade is visible
    await tester.pump(const Duration(milliseconds: 250));

    // Verify white "Truthworld" text is present
    final textFinder = find.text('Truthworld');
    expect(textFinder, findsOneWidget);
    final textWidget = tester.widget<Text>(textFinder);
    expect(textWidget.style?.color, equals(Colors.white));

    // Verify "Love everyone Trust no one" message is present
    final messageFinder = find.text('Love everyone Trust no one');
    expect(messageFinder, findsOneWidget);
  });

  testWidgets('TruthworldSplashScreen hides text and message and shows only logo when height is restricted',
      (tester) async {
    // Ultra-compact height where text does not fit comfortably: 400 x 180
    tester.view.physicalSize = const Size(400, 180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TruthworldSplashScreen.reset();

    await tester.pumpWidget(
      const MaterialApp(
        home: TruthworldSplashScreen(
          duration: Duration(milliseconds: 500),
          child: Scaffold(body: Text('Home Content')),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    // Logo should be present
    expect(find.byType(AppLogo), findsOneWidget);

    // "Truthworld" and message should NOT be rendered when they do not fit
    expect(find.text('Truthworld'), findsNothing);
    expect(find.text('Love everyone Trust no one'), findsNothing);
  });
}
