import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/community/data/models/saved_comment_model.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
import 'package:truthworld/features/community/presentation/views/saved_comments_screen.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createWidgetUnderTest(Widget child) {
    return GetMaterialApp(
      home: child,
    );
  }

  group('SavedCommentsScreen UI & Theme Tests (matching Notifications)', () {
    testWidgets('Renders empty state matching notification theme when no comments exist', (tester) async {
      final controller = Get.put<SavedCommentsController>(SavedCommentsController());
      controller.rxIsLoading.value = false;
      controller.comments.clear();

      await tester.pumpWidget(createWidgetUnderTest(const SavedCommentsScreen()));
      await tester.pump();

      expect(find.byType(SavedCommentsScreen), findsOneWidget);
      expect(find.byType(SavedCommentsAppBar), findsOneWidget);
      expect(find.byType(SavedCommentsPillTabs), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('No saved comments'), findsOneWidget);
      expect(
        find.text('Comments you save from Videos, Topics, or Community Posts will appear here'),
        findsOneWidget,
      );
    });

    testWidgets('Pill tabs display All, Videos, Topics, Community and react to selection', (tester) async {
      final controller = Get.put<SavedCommentsController>(SavedCommentsController());
      controller.rxIsLoading.value = false;
      controller.comments.clear();

      await tester.pumpWidget(createWidgetUnderTest(const SavedCommentsScreen()));
      await tester.pump();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Topics'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);

      // Tap 'Videos' tab
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();

      expect(controller.selectedCategory.value, equals('video'));
      expect(find.text('No saved video comments'), findsOneWidget);
    });

    testWidgets('Renders date-grouped list tiles when saved comments are present', (tester) async {
      final controller = Get.put<SavedCommentsController>(SavedCommentsController());
      controller.rxIsLoading.value = false;

      final now = DateTime.now();
      controller.comments.assignAll([
        SavedCommentModel(
          id: 'sc_1',
          text: 'This video provides exceptional insights.',
          userName: 'Dr. Jane Doe',
          userImage: '',
          sourceType: 'video',
          sourceId: 'vid_123',
          sourceTitle: 'Quantum Physics Explained',
          savedAt: now,
        ),
        SavedCommentModel(
          id: 'sc_2',
          text: 'Great point regarding AI alignment principles.',
          userName: 'Alan Turing',
          userImage: '',
          sourceType: 'topic',
          sourceId: 'topic_456',
          sourceTitle: 'Future of AI',
          savedAt: now.subtract(const Duration(days: 10)),
        ),
      ]);

      await tester.pumpWidget(createWidgetUnderTest(const SavedCommentsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(CompactSavedCommentTile), findsNWidgets(2));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Older'), findsOneWidget);
      expect(find.text('This video provides exceptional insights.'), findsOneWidget);
      expect(find.text('Great point regarding AI alignment principles.'), findsOneWidget);
    });

    testWidgets('Search bar toggles and filters comments interactively', (tester) async {
      final controller = Get.put<SavedCommentsController>(SavedCommentsController());
      controller.rxIsLoading.value = false;

      controller.comments.assignAll([
        SavedCommentModel(
          id: 'sc_1',
          text: 'First observation about economics',
          userName: 'Alice',
          userImage: '',
          sourceType: 'video',
          sourceId: 'vid_1',
          sourceTitle: 'Global Markets',
          savedAt: DateTime.now(),
        ),
        SavedCommentModel(
          id: 'sc_2',
          text: 'Second note on astrophysics',
          userName: 'Bob',
          userImage: '',
          sourceType: 'topic',
          sourceId: 'top_2',
          sourceTitle: 'Deep Space Exploration',
          savedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(createWidgetUnderTest(const SavedCommentsScreen()));
      await tester.pumpAndSettle();

      // Tap search icon in app bar
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(controller.isSearching.value, isTrue);
      expect(find.byType(SavedCommentsSearchBar), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'astrophysics');
      await tester.pumpAndSettle();

      expect(find.text('Second note on astrophysics'), findsOneWidget);
      expect(find.text('First observation about economics'), findsNothing);
    });
  });
}
