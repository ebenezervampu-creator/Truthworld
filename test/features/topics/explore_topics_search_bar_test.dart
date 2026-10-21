import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_search_bar.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<ExploreTopicsController>(ExploreTopicsController());
  });

  tearDown(Get.reset);

  group('ExploreTopicsSearchBar Professional TextField Tests', () {
    testWidgets('Renders professional overview search bar on Mobile with non-clipping hint',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ExploreTopicsSearchBar(isMobile: true),
          ),
        ),
      );

      // Verify prefix AI sparkle icon
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      // Verify mobile-optimized concise hint
      expect(find.text('Ask AI or explore topics...'), findsOneWidget);

      // Verify voice search mic icon
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Verify clear button is hidden when query is empty
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('Renders professional overview search bar on Desktop with rich hint',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ExploreTopicsSearchBar(isDesktop: true),
          ),
        ),
      );

      // Verify desktop rich semantic hint
      expect(
        find.text(
          'Ask AI or explore topics (e.g. "Peace of mind", "Bible study", "Science & faith")...',
        ),
        findsOneWidget,
      );

      // Verify prefix icon
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('Renders category detail search bar with category title and search icon',
        (tester) async {
      const businessCategory = TopicCategory(
        id: 'business',
        title: 'Business',
        imageUrl: 'https://images.unsplash.com/photo-business',
        description: 'Entrepreneurship and corporate strategies.',
        icon: Icons.business_center_rounded,
        searchHintExamples: '"leadership", "finance", "startup"',
      );

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ExploreTopicsSearchBar(
              isCategoryView: true,
              category: businessCategory,
              isMobile: true,
            ),
          ),
        ),
      );

      // Verify search icon is used for category detail view
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Verify category-specific hint
      expect(find.text('Search topics in Business...'), findsOneWidget);

      // Voice search is present
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('Clear button appears when query is typed and clears on tap',
        (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ExploreTopicsSearchBar(isMobile: true),
          ),
        ),
      );

      final controller = Get.find<ExploreTopicsController>();

      // Initially empty -> no clear button
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Leadership');
      await tester.pumpAndSettle();

      // Clear button is now visible
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Text is cleared and clear button disappears
      expect(controller.searchController.text, isEmpty);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}
