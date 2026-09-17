import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explore Topics Constants & Theme Tests', () {
    test('Breakpoints have expected responsive values', () {
      expect(kMobileBreakpoint, equals(600));
      expect(kTabletBreakpoint, equals(1024));
      expect(kDesktopBreakpoint, equals(1440));
    });

    test('ExploreTopicsTheme provides consistent dark-mode styling tokens', () {
      expect(ExploreTopicsTheme.bgColor, equals(const Color(0xFF0F0F0F)));
      expect(ExploreTopicsTheme.surfaceColor, equals(const Color(0xFF1E1E1E)));
      expect(ExploreTopicsTheme.cardColor, equals(const Color(0xFF1E1E1E)));
      expect(ExploreTopicsTheme.buttonBg, equals(const Color(0xFF272727)));
      expect(ExploreTopicsTheme.primaryText, equals(Colors.white));
      expect(ExploreTopicsTheme.secondaryText, equals(const Color(0xFFAAAAAA)));
      expect(ExploreTopicsTheme.ytRed, equals(const Color(0xFFFF0000)));

      // Top-level aliases match
      expect(bgColor, equals(ExploreTopicsTheme.bgColor));
      expect(surfaceColor, equals(ExploreTopicsTheme.surfaceColor));
      expect(cardColor, equals(ExploreTopicsTheme.cardColor));
      expect(buttonBg, equals(ExploreTopicsTheme.buttonBg));
      expect(primaryText, equals(ExploreTopicsTheme.primaryText));
      expect(secondaryText, equals(ExploreTopicsTheme.secondaryText));
    });
  });

  group('Explore Topics Empty & Shimmer Widgets Tests', () {
    testWidgets('TopicPageViewShimmerWidget renders shimmer placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicPageViewShimmerWidget(),
          ),
        ),
      );

      expect(find.byType(TopicPageViewShimmerWidget), findsOneWidget);
    });

    testWidgets('TopicNavButton renders navigation icon and handles tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TopicNavButton(
                  isLeft: true,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TopicNavButton), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

      await tester.tap(find.byType(TopicNavButton));
      expect(tapped, isTrue);
    });

    testWidgets('TopicNavButton right orientation renders forward chevron', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TopicNavButton(
                  isLeft: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });

  group('ExploreTopicsCategoryCard Tests', () {
    testWidgets('Renders category title and image container', (tester) async {
      const category = TopicCategory(
        id: 'cat_tech',
        title: 'Technology & AI',
        imageUrl: 'https://example.com/tech.jpg',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 120,
              child: ExploreTopicsCategoryCard(category: category),
            ),
          ),
        ),
      );

      expect(find.text('Technology & AI'), findsOneWidget);
      expect(find.byType(ExploreTopicsCategoryCard), findsOneWidget);
    });

    test('TopicCategoriesConfig provides valid default categories', () {
      expect(TopicCategoriesConfig.categories, isNotEmpty);
      expect(TopicCategoriesConfig.categories.first.id, equals('all'));
      expect(TopicCategoriesConfig.categories.first.title, equals('All'));
    });
  });

  group('ExploreTopicVideoItemCard Skeleton Tests', () {
    testWidgets('HorizontalVideoSkeleton renders skeleton shimmer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 300,
              child: HorizontalVideoSkeleton(),
            ),
          ),
        ),
      );

      expect(find.byType(HorizontalVideoSkeleton), findsOneWidget);
    });
  });
}
