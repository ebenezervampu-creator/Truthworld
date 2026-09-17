import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/topics_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TopicMetricSummaryCard Tests', () {
    testWidgets('renders title, value, and icon with onTap support', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicMetricSummaryCard(
              title: 'Total Topics',
              value: '15',
              icon: Icons.topic_rounded,
              onTap: () => tapped = true,
              isSelected: true,
            ),
          ),
        ),
      );

      expect(find.text('Total Topics'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.byIcon(Icons.topic_rounded), findsOneWidget);

      await tester.tap(find.byType(TopicMetricSummaryCard));
      expect(tapped, isTrue);
    });
  });

  group('Topic State Widgets Tests', () {
    testWidgets('TopicEmptyState renders informative empty state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicEmptyState(),
          ),
        ),
      );

      expect(find.text('No Topics Yet'), findsOneWidget);
      expect(find.byIcon(Icons.folder_special_rounded), findsOneWidget);
    });

    testWidgets('TopicSearchEmptyState renders empty search notice and triggers clear', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicSearchEmptyState(onClear: () => cleared = true),
          ),
        ),
      );

      expect(find.text('No matching topics found'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);

      await tester.tap(find.text('Clear Search'));
      expect(cleared, isTrue);
    });

    testWidgets('TopicErrorState renders error text and triggers onRetry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicErrorState(
              error: 'Connection timeout',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to Load Topics'), findsOneWidget);
      expect(find.text('Connection timeout'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('TopicShimmerGrid renders placeholder elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicShimmerGrid(),
          ),
        ),
      );

      expect(find.byType(TopicShimmerGrid), findsOneWidget);
    });
  });

  group('EditTopicFieldLabel Tests', () {
    testWidgets('renders label without asterisk when not required', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTopicFieldLabel(label: 'Optional Notes'),
          ),
        ),
      );

      expect(find.text('Optional Notes'), findsOneWidget);
      expect(find.text(' *'), findsNothing);
    });

    testWidgets('renders red asterisk when required', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditTopicFieldLabel(label: 'Required Title', isRequired: true),
          ),
        ),
      );

      expect(find.text('Required Title'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
    });
  });
}
