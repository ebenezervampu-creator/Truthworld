import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_selection_components.dart';

class _FakeUploadController implements TopicSelectionHost {
  @override
  final TextEditingController titleController =
      TextEditingController(text: 'Quantum Physics and Cosmos');
  @override
  final RxString selectedCategory = 'Science'.obs;
  @override
  final RxString selectedTopicId = ''.obs;
  @override
  final RxString topicSearchQuery = ''.obs;
  @override
  final RxBool isTopicsLoading = false.obs;
  @override
  final RxMap<String, dynamic> newTopicData = <String, dynamic>{}.obs;
  @override
  final RxList<Topic> availableTopics = <Topic>[].obs;
  @override
  final RxList<String> selectedTopicIds = <String>[].obs;

  @override
  int get selectedOwnTopicsCount => 0;
  @override
  int get selectedPublicTopicsCount => 0;

  @override
  void selectTopic(String id) {
    selectedTopicId.value = id;
  }

  @override
  void toggleTopicSelection(Topic topic) {
    final key = topic.slug.isNotEmpty ? topic.slug : topic.id;
    if (selectedTopicIds.contains(key)) {
      selectedTopicIds.remove(key);
      if (selectedTopicId.value == key) selectedTopicId.value = '';
    } else {
      selectedTopicIds.add(key);
      selectedTopicId.value = key;
    }
  }

  @override
  bool isTopicSelected(String key) =>
      selectedTopicIds.contains(key) || selectedTopicId.value == key;

  @override
  bool isOwnTopic(Topic topic) => false;

  @override
  List<dynamic>? getRankedTopicsForCurrentVideo() => null;

  @override
  Future<void> fetchAvailableTopics() async {}
}

Topic _makeTopic({
  required String id,
  required String title,
  required String category,
  int videoCount = 10,
  int followerCount = 100,
}) {
  return Topic(
    id: id,
    title: title,
    slug: id,
    handle: '@$id',
    handleLowercase: '@${id.toLowerCase()}',
    description: 'Topic description for $title',
    category: category,
    createdAt: DateTime(2026, 8, 14),
    updatedAt: DateTime(2026, 8, 14),
    videoCount: videoCount,
    followerCount: followerCount,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  group('TopicMatchInfo & RecommendationEngine Tests', () {
    test('1. TopicMatchInfo stores metadata and top recommendation status', () {
      final topic = _makeTopic(id: 'physics', title: 'Modern Physics', category: 'Science');
      final match = TopicMatchInfo(
        topic: topic,
        matchPercentage: 95,
        reason: 'Category match (Science)',
        isTopRecommendation: true,
      );

      expect(match.topic.id, 'physics');
      expect(match.matchPercentage, 95);
      expect(match.reason, 'Category match (Science)');
      expect(match.isTopRecommendation, isTrue);
    });

    test('2. computeRankedTopicMatches ranks by category and title keyword match', () {
      final controller = _FakeUploadController();
      final topic1 = _makeTopic(id: 'cooking', title: 'Cooking 101', category: 'Food');
      final topic2 = _makeTopic(id: 'quantum', title: 'Quantum Discoveries', category: 'Science');
      final topic3 = _makeTopic(id: 'nature', title: 'Wild Nature', category: 'Outdoors');

      final matches = TopicRecommendationEngine.computeRankedTopicMatches(
        controller,
        [topic1, topic2, topic3],
      );

      expect(matches.length, 3);
      // topic2 matches both Category ('Science') and Title Keyword ('Quantum')
      expect(matches.first.topic.id, 'quantum');
      expect(matches.first.isTopRecommendation, isTrue);
      expect(matches.first.matchPercentage, greaterThan(matches[1].matchPercentage));
    });

    test('3. formatTopicDate formats date correctly', () {
      final date = DateTime(2026, 8, 14);
      final formatted = TopicRecommendationEngine.formatTopicDate(date);
      expect(formatted, 'Aug 14, 2026');
    });

    testWidgets('4. handleTopicSelection updates selectedTopicId and pops context', (tester) async {
      final controller = _FakeUploadController();
      final topic = _makeTopic(id: 'astronomy', title: 'Astronomy', category: 'Science');
      Topic? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  TopicRecommendationEngine.handleTopicSelection(
                    context,
                    controller,
                    topic,
                    (t) => selectedResult = t,
                  );
                },
                child: const Text('Select'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(controller.selectedTopicId.value, 'astronomy');
      expect(selectedResult?.id, 'astronomy');
    });

    testWidgets('5. handleNoneTopicSelection resets topic ID to empty string', (tester) async {
      final controller = _FakeUploadController();
      controller.selectedTopicId.value = 'initial_topic';
      var noneSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  TopicRecommendationEngine.handleNoneTopicSelection(
                    context,
                    controller,
                    (t) {
                      if (t == null) noneSelected = true;
                    },
                  );
                },
                child: const Text('None'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      expect(controller.selectedTopicId.value, '');
      expect(noneSelected, isTrue);
    });
  });

  group('Topic Selection UI Widgets Tests', () {
    testWidgets('6. TopicNoneOptionChip renders none option text and block icon', (tester) async {
      final controller = _FakeUploadController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicNoneOptionChip(
              isDark: true,
              textColor: Colors.white,
              subtextColor: Colors.grey,
              borderColor: Colors.white24,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text("None (Don't save video to any topic)"), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('7. TopicDraftOptionCard renders draft title and NEW DRAFT badge', (tester) async {
      final controller = _FakeUploadController();
      controller.newTopicData.value = {'title': 'My Experimental Lab'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicDraftOptionCard(
              isDark: true,
              borderColor: Colors.purple,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Draft: My Experimental Lab'), findsOneWidget);
      expect(find.text('NEW DRAFT'), findsOneWidget);
      expect(find.byIcon(Icons.edit_document), findsOneWidget);
    });

    testWidgets('8. TopicSelectionEmptyState renders search off icon and query text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicSelectionEmptyState(
              query: 'Superconductivity',
              textColor: Colors.white,
              subtextColor: Colors.grey,
              isDark: true,
              borderColor: Colors.white12,
            ),
          ),
        ),
      );

      expect(find.text('No matching topics for "Superconductivity"'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('9. TopicHeroCard renders top recommendation header, title, and action', (tester) async {
      final controller = _FakeUploadController();
      final topic = _makeTopic(
        id: 'quantum_ai',
        title: 'Quantum Computing Hub',
        category: 'Technology',
        videoCount: 42,
        followerCount: 1530,
      );
      final match = TopicMatchInfo(
        topic: topic,
        matchPercentage: 98,
        reason: 'Category match',
        isTopRecommendation: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicHeroCard(
              match: match,
              isSelected: false,
              isDark: true,
              textColor: Colors.white,
              subtextColor: Colors.grey,
              borderColor: Colors.white24,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('BEST MATCH FOR YOUR VIDEO'), findsOneWidget);
      expect(find.text('Quantum Computing Hub'), findsOneWidget);
      expect(find.text('Add video to this topic'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Channels'), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
    });

    testWidgets('10. TopicListItemCard displays Followers, Channels, and Videos counts', (tester) async {
      final controller = _FakeUploadController();
      final topic = _makeTopic(
        id: 'quantum_tech',
        title: 'Quantum Technology Hub',
        category: 'Technology',
        videoCount: 15,
        followerCount: 200,
      );
      final match = TopicMatchInfo(
        topic: topic,
        matchPercentage: 90,
        reason: 'Recommended for you',
        isTopRecommendation: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicListItemCard(
              match: match,
              isSelected: false,
              isDark: true,
              textColor: Colors.white,
              subtextColor: Colors.grey,
              borderColor: Colors.white24,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Quantum Technology Hub'), findsOneWidget);
      expect(find.textContaining('followers'), findsWidgets);
      expect(find.textContaining('channels'), findsWidgets);
      expect(find.textContaining('videos'), findsWidgets);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}
