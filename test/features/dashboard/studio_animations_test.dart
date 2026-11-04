import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_animated_counter.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_interactive_card.dart';

void main() {
  group('StudioInteractiveCard Tests', () {
    testWidgets('renders child content and handles tap callback with haptics',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioInteractiveCard(
              onTap: () => tapped = true,
              child: const Text('Test Studio Card'),
            ),
          ),
        ),
      );

      expect(find.text('Test Studio Card'), findsOneWidget);

      await tester.tap(find.text('Test Studio Card'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('handles pointer hover and press state transitions cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudioInteractiveCard(
                onTap: () {},
                child: const SizedBox(
                  width: 100,
                  height: 100,
                  child: Text('Hover Card'),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      // Move inside the card
      await gesture.moveTo(tester.getCenter(find.text('Hover Card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Move outside
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Hover Card'), findsOneWidget);
    });
  });

  group('StudioAnimatedMetricValue Tests', () {
    testWidgets('animates integer number roll-up to target value',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioAnimatedMetricValue(
              value: '12,450',
            ),
          ),
        ),
      );

      // Initially starting roll-up
      await tester.pump();
      // Fast forward past duration
      await tester.pumpAndSettle();

      expect(find.text('12,450'), findsOneWidget);
    });

    testWidgets('animates currency prefix and abbreviations correctly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StudioAnimatedMetricValue(value: '\$1,250'),
                StudioAnimatedMetricValue(value: '45.2K'),
                StudioAnimatedMetricValue(value: '104.5 hrs'),
                StudioAnimatedMetricValue(value: '+5.4%'),
                StudioAnimatedMetricValue(value: 'N/A'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('\$1,250'), findsOneWidget);
      expect(find.text('45.2K'), findsOneWidget);
      expect(find.text('104.5 hrs'), findsOneWidget);
      expect(find.text('+5.4%'), findsOneWidget);
      expect(find.text('N/A'), findsOneWidget);
    });
  });
}
