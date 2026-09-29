import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/category_page.dart';
import 'package:truthworld/features/category/presentation/views/category/widgets/category_page_widgets.dart';
import '../../pages/page_test_harness.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('CategoryPage Modular Components Unit & Widget Tests', () {
    testWidgets('1. CategoryThemeHelper provides proper colors, icons, and formatting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final musicColor = CategoryThemeHelper.getCategoryColor('music', context);
              expect(musicColor, isNotNull);

              final defaultColor = CategoryThemeHelper.getCategoryColor('other', context);
              expect(defaultColor, isNotNull);

              final padding = CategoryThemeHelper.getResponsiveHorizontalPadding(context);
              expect(padding, isPositive);

              return const SizedBox();
            },
          ),
        ),
      );

      // Icons
      expect(CategoryThemeHelper.getCategoryIcon('music'), equals(Icons.music_note));
      expect(CategoryThemeHelper.getCategoryIcon('education'), equals(Icons.school));
      expect(CategoryThemeHelper.getCategoryIcon('unknown_xyz'), equals(Icons.category));

      // View formatting
      expect(CategoryThemeHelper.formatViews(500), equals('500'));
      expect(CategoryThemeHelper.formatViews(1500), equals('1.5K'));
      expect(CategoryThemeHelper.formatViews(2500000), equals('2.5M'));
    });

    testWidgets('2. CategoryHeroSection renders title, subtitle, and white icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: CategoryHeroSection(
                category: 'Music',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Discover the best music content'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('3. CategorySearchBar updates controller and clears text', (tester) async {
      final controller = Get.put<CategoryController>(CategoryController());
      final textController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategorySearchBar(
              controller: controller,
              searchController: textController,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Classical Piano');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(controller.searchQuery.value, equals('Classical Piano'));
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(textController.text, isEmpty);
      expect(controller.searchQuery.value, isEmpty);
    });

    testWidgets('4. CategoryFilterChips displays genres and allows selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put<CategoryController>(CategoryController());
      controller.genres.assignAll(['All', 'Rock', 'Jazz', 'Classical']);
      controller.selectedGenre.value = 'All';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryFilterChips(
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Rock'), findsOneWidget);
      expect(find.text('Jazz'), findsOneWidget);

      await tester.tap(find.text('Jazz'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(controller.selectedGenre.value, equals('Jazz'));
    });

    testWidgets('5. CategorySectionHeader renders title correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategorySectionHeader(
              title: 'Top Music Videos',
              category: 'Music',
            ),
          ),
        ),
      );

      expect(find.text('Top Music Videos'), findsOneWidget);
    });

    testWidgets('6. CategoryErrorWidget and CategoryEmptyWidget render gracefully', (tester) async {
      var retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CategoryErrorWidget(
                  message: 'Connection timed out',
                  onRetry: () => retryTapped = true,
                ),
                const CategoryEmptyWidget(
                  message: 'No items found in this section',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Connection timed out'), findsOneWidget);
      expect(find.text('No items found in this section'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retryTapped, isTrue);
    });

    testWidgets('7. CategoryPage full screen renders properly', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpPageInHarness(
        tester,
        const CategoryPage(),
        onBeforePump: () {
          Get.put<CategoryController>(CategoryController());
        },
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(CategoryPage), findsOneWidget);
      expect(find.byType(CategoryAppBar), findsOneWidget);
      expect(find.byType(CategoryFilterChips), findsOneWidget);
    });
  });
}
