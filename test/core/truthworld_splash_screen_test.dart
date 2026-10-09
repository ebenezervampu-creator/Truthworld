import 'package:flutter/foundation.dart';
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

  testWidgets('TruthworldSplashScreen is bypassed entirely on Desktops (Windows/macOS/Linux)',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      TruthworldSplashScreen.reset();
      var onCompletedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TruthworldSplashScreen(
            duration: const Duration(milliseconds: 500),
            onCompleted: () => onCompletedCalled = true,
            child: const Scaffold(body: Text('Desktop Home View')),
          ),
        ),
      );

      // Initial frame
      await tester.pump();

      // The child UI should be immediately rendered
      expect(find.text('Desktop Home View'), findsOneWidget);

      // Splash screen logo and text should NOT be present on Desktops
      expect(find.byType(AppLogo), findsNothing);
      expect(find.text('Truthworld'), findsNothing);
      expect(find.text('Love everyone Trust no one'), findsNothing);
      expect(onCompletedCalled, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('TruthworldSplashScreen is bypassed when screen is desktop width (>= 1024px)',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TruthworldSplashScreen.reset();

    await tester.pumpWidget(
      const MaterialApp(
        home: TruthworldSplashScreen(
          duration: Duration(milliseconds: 500),
          child: Scaffold(body: Text('Wide Screen Content')),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Wide Screen Content'), findsOneWidget);
    expect(find.byType(AppLogo), findsNothing);
    expect(find.text('Truthworld'), findsNothing);
  });

  testWidgets('TruthworldSplashScreen renders on iOS mobile devices',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      TruthworldSplashScreen.reset();

      await tester.pumpWidget(
        const MaterialApp(
          home: TruthworldSplashScreen(
            duration: Duration(milliseconds: 500),
            child: Scaffold(body: Text('iOS Home Content')),
          ),
        ),
      );

      await tester.pump();

      // AppLogo must be present on iOS mobile
      expect(find.byType(AppLogo), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Truthworld'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
