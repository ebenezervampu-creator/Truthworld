import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_language.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_language_card.dart';

void main() {
  group('DubbingLanguageCard', () {
    testWidgets('renders live language card with flag and LIVE indicator', (tester) async {
      final telugu = DubbingLanguage.findByCode('te');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                height: 82,
                child: DubbingLanguageCard(
                  language: telugu,
                  isAvailable: true,
                  isNotPlanned: false,
                  isSelected: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Telugu'), findsOneWidget);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Available now'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders upcoming language card with SOON indicator', (tester) async {
      final spanish = DubbingLanguage.findByCode('es');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                height: 82,
                child: DubbingLanguageCard(
                  language: spanish,
                  isAvailable: false,
                  isNotPlanned: false,
                  isSelected: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Spanish'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('SOON'), findsOneWidget);
      expect(find.text('Available soon'), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    test('only English is available as source language', () {
      final availableSources = DubbingLanguage.source32Languages
          .where((l) => l.isAvailableAsSource)
          .map((l) => l.code)
          .toList();
      expect(availableSources, ['en']);
    });
  });
}
