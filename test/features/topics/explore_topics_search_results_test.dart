import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_search_results.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<FollowingTopicsController>(FollowingTopicsController());
    Get.put<ExploreTopicsController>(ExploreTopicsController());
  });

  tearDown(() {
    Get.reset();
  });

  final sampleTopic = Topic(
    id: 'topic_search_1',
    title: 'Generative AI & LLMs',
    slug: 'generative-ai-llms',
    category: 'Technology',
    description: 'Deep dive into generative artificial intelligence and neural networks.',
    videoCount: 8,
    followerCount: 140,
    handle: 'T/generative-ai-llms',
    handleLowercase: 't/generative-ai-llms',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('ExploreTopicsSearchResults Widget Tests', () {
    testWidgets('Renders search results grid when topics match query', (tester) async {
      final controller = Get.find<ExploreTopicsController>();
      controller.searchQuery.value = 'Generative AI';
      await tester.pump(const Duration(milliseconds: 500));

      controller.topics.assignAll([sampleTopic]);
      controller.rxIsLoading.value = false;
      controller.isAiSearching.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreTopicsSearchResults(isDesktop: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Search Results'), findsOneWidget);
      expect(find.text('1 topic matching "Generative AI"'), findsOneWidget);
      expect(find.text('Generative AI & LLMs'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('8 videos'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Renders friendly empty state when no topics match query', (tester) async {
      final controller = Get.find<ExploreTopicsController>();
      controller.searchQuery.value = 'xyznonexistent123';
      await tester.pump(const Duration(milliseconds: 500));

      controller.topics.clear();
      controller.rxIsLoading.value = false;
      controller.isAiSearching.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreTopicsSearchResults(isDesktop: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No topics found for "xyznonexistent123"'), findsOneWidget);
      expect(find.text('Clear Search & Explore All'), findsOneWidget);
      expect(find.text('Faith'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Clearing search resets search query in controller', (tester) async {
      final controller = Get.find<ExploreTopicsController>();
      controller.searchQuery.value = 'Quantum';
      await tester.pump(const Duration(milliseconds: 500));

      controller.topics.assignAll([sampleTopic]);
      controller.rxIsLoading.value = false;
      controller.isAiSearching.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreTopicsSearchResults(isDesktop: true),
            ),
          ),
        ),
      );
      await tester.pump();

      final clearBtn = find.text('Clear Search');
      expect(clearBtn, findsOneWidget);

      await tester.tap(clearBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.searchQuery.value, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
