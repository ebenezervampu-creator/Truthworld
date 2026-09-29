import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TruthLottieAnimation Unit and Widget Tests', () {
    testWidgets('TruthLottieAnimation.aiScanning initializes with correct asset and default dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthLottieAnimation.aiScanning(),
          ),
        ),
      );

      final widgetFinder = find.byType(TruthLottieAnimation);
      expect(widgetFinder, findsOneWidget);

      final anim = tester.widget<TruthLottieAnimation>(widgetFinder);
      expect(anim.assetPath, 'assets/lottie/ai_scanning.json');
      expect(anim.width, 40);
      expect(anim.height, 40);
    });

    testWidgets('TruthLottieAnimation.verifiedShield initializes with correct asset and custom size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthLottieAnimation.verifiedShield(size: 28),
          ),
        ),
      );

      final widgetFinder = find.byType(TruthLottieAnimation);
      expect(widgetFinder, findsOneWidget);

      final anim = tester.widget<TruthLottieAnimation>(widgetFinder);
      expect(anim.assetPath, 'assets/lottie/verified_shield.json');
      expect(anim.width, 28);
      expect(anim.height, 28);
    });

    testWidgets('TruthLottieAnimation.loader initializes with analyzing_loader asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthLottieAnimation.loader(size: 32),
          ),
        ),
      );

      final widgetFinder = find.byType(TruthLottieAnimation);
      expect(widgetFinder, findsOneWidget);

      final anim = tester.widget<TruthLottieAnimation>(widgetFinder);
      expect(anim.assetPath, 'assets/lottie/analyzing_loader.json');
      expect(anim.width, 32);
      expect(anim.height, 32);
    });

    testWidgets('TruthLottieAnimation.emptyClaims initializes with empty_claims asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthLottieAnimation.emptyClaims(size: 64),
          ),
        ),
      );

      final widgetFinder = find.byType(TruthLottieAnimation);
      expect(widgetFinder, findsOneWidget);

      final anim = tester.widget<TruthLottieAnimation>(widgetFinder);
      expect(anim.assetPath, 'assets/lottie/empty_claims.json');
      expect(anim.width, 64);
      expect(anim.height, 64);
    });
  });
}
