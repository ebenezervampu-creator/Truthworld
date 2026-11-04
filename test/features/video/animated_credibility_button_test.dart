import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/presentation/widgets/animated_credibility_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AnimatedCredibilityButton Tests', () {
    testWidgets('1. Renders verified icon, label, and tooltip properly',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedCredibilityButton(
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify label and icon exist
      expect(find.text('AI Check'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      // Tap the button
      await tester.tap(find.text('AI Check'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('2. Animates smoothly through sweep cycle without exception',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedCredibilityButton(
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Initial frame
      await tester.pump();

      // Pump 500ms into the sweep (active holographic shimmer phase)
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('AI Check'), findsOneWidget);

      // Pump 1500ms into the cycle (transition to resting phase)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('AI Check'), findsOneWidget);

      // Pump full 3600ms cycle
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.text('AI Check'), findsOneWidget);
    });

    testWidgets('3. Renders icon-only mode when label is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedCredibilityButton(
                label: '',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.text('AI Check'), findsNothing);
    });
  });
}
