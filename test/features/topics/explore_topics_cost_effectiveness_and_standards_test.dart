import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_search_results.dart';
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

/// Test Spy Repository to accurately measure and assert network query efficiency
class SpyTopicRepository extends TopicRepository {
  int fetchTopicsCalls = 0;
  int getVideosByTopicCalls = 0;
  int searchTopicsCalls = 0;
  int fetchFeaturedTopicsCalls = 0;

  List<Topic> stubTopics = [];
  List<Video> stubVideos = [];

  @override
  Future<List<Topic>> fetchTopics({
    DocumentSnapshot? lastDoc,
    String category = 'all',
    int limit = 20,
  }) async {
    fetchTopicsCalls++;
    return stubTopics;
  }

  @override
  Future<List<Video>> getVideosByTopic(
    String topicSlug, {
    int limit = 12,
    DocumentSnapshot? lastDoc,
    String orderBy = 'uploadedAt',
    bool descending = true,
  }) async {
    getVideosByTopicCalls++;
    return stubVideos;
  }

  @override
  Future<List<Topic>> searchTopics(String query, {int limit = 20}) async {
    searchTopicsCalls++;
    return stubTopics;
  }

  @override
  Future<TopicPageResult> fetchTopicsPage({
    DocumentSnapshot? lastDoc,
    String category = 'all',
    int limit = 20,
  }) async {
    fetchTopicsCalls++;
    return TopicPageResult(topics: stubTopics, lastDoc: null);
  }

  @override
  Future<TopicPageResult> fetchTrendingTopicsPage({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    return TopicPageResult(topics: stubTopics, lastDoc: null);
  }

  @override
  Future<TopicPageResult> fetchNewestTopicsPage({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    return TopicPageResult(topics: stubTopics, lastDoc: null);
  }

  @override
  Future<TopicPageResult> fetchPopularTopicsPage({
    required String category,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    return TopicPageResult(topics: stubTopics, lastDoc: null);
  }

  @override
  Future<List<Topic>> fetchFeaturedTopics({int limit = 5}) async {
    fetchFeaturedTopicsCalls++;
    return stubTopics;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  late SpyTopicRepository spyRepo;
  late ExploreTopicsController controller;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    Get.put<FollowingTopicsController>(FollowingTopicsController());
    spyRepo = SpyTopicRepository();
    controller = Get.put<ExploreTopicsController>(
      ExploreTopicsController(repository: spyRepo),
    );
  });

  tearDown(() {
    Get.reset();
  });

  Topic buildTestTopic({
    required String id,
    required String title,
    required String category,
    int videoCount = 3,
  }) {
    return Topic(
      id: id,
      title: title,
      slug: id,
      category: category,
      description: 'Test topic description for $title',
      videoCount: videoCount,
      followerCount: 50,
      handle: 'T/$id',
      handleLowercase: 't/$id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('Cost-Effectiveness & Read Quota Optimization Tests', () {
    test('fetchAvailableCategories skips redundant 800-doc scans when cached in memory', () async {
      controller.isLoadingCategories.value = false;
      // Simulate that categories have already been populated in the current session
      controller.availableCategories.assignAll([
        const TopicCategory(id: 'technology', title: 'Technology', imageUrl: ''),
        const TopicCategory(id: 'faith', title: 'Faith', imageUrl: ''),
      ]);

      // Calling fetchAvailableCategories without force flag MUST skip re-querying Firestore
      await controller.fetchAvailableCategories(force: false);

      expect(controller.isLoadingCategories.value, isFalse);
      expect(controller.availableCategories.length, equals(2));
    });

    test('fetchVideosForTopic caches results in topicVideosMap and avoids duplicate queries', () async {
      final topic = buildTestTopic(id: 'tech_ai', title: 'AI & Robotics', category: 'Technology');

      expect(spyRepo.getVideosByTopicCalls, equals(0));

      // First fetch: should invoke repository
      await controller.fetchVideosForTopic(topic);
      expect(spyRepo.getVideosByTopicCalls, equals(1));
      expect(controller.topicVideosMap.containsKey('tech_ai'), isTrue);

      // Second fetch for the exact same topic: MUST hit in-memory cache and NOT re-query repository
      await controller.fetchVideosForTopic(topic);
      expect(spyRepo.getVideosByTopicCalls, equals(1),
          reason: 'Duplicate call for cached topic should not fire network query');
    });

    test('loadTopics limits eager video fetches to top active topics (bounded queries)', () async {
      // Provide a list of 10 topics
      spyRepo.stubTopics = List.generate(
        10,
        (i) => buildTestTopic(id: 'topic_$i', title: 'Topic $i', category: 'General'),
      );

      await controller.loadTopics(reset: true);

      // Verify that eager video queries were bounded to max 4 (not all 10 topics at once)
      expect(spyRepo.getVideosByTopicCalls, lessThanOrEqualTo(4),
          reason: 'Must not eagerly query videos for all 10 topics; should bound to top 4');
    });

    test('activeTopicsForVideoTrays prioritizes topics with videos', () {
      final topicWithoutVideos = buildTestTopic(
        id: 'no_vids',
        title: 'Empty Topic',
        category: 'Tech',
        videoCount: 0,
      );
      final topicWithVideos1 = buildTestTopic(
        id: 'has_vids_1',
        title: 'Active Topic 1',
        category: 'Tech',
        videoCount: 5,
      );
      final topicWithVideos2 = buildTestTopic(
        id: 'has_vids_2',
        title: 'Active Topic 2',
        category: 'Science',
        videoCount: 2,
      );

      controller.topics.assignAll([
        topicWithoutVideos,
        topicWithVideos1,
        topicWithVideos2,
      ]);

      final trays = controller.activeTopicsForVideoTrays;

      expect(trays.length, equals(2));
      expect(trays.first.id, equals('has_vids_1'));
      expect(trays.last.id, equals('has_vids_2'));
    });
  });

  group('Industry Standards - Responsive Breakpoint Tests', () {
    testWidgets('ExploreTopicsPage renders cleanly on compact Mobile screen (360x800) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ExploreTopicsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Explore Topics'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget); // Create Topic button
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExploreTopicsPage renders cleanly on Tablet screen (768x1024) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ExploreTopicsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Explore Topics'), findsOneWidget);
      expect(find.text('Create Topic'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExploreTopicsPage renders cleanly on Desktop screen (1440x900) with constrained container',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ExploreTopicsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Explore Topics'), findsOneWidget);
      expect(find.text('Create Topic'), findsOneWidget);
      expect(find.text('Featured Topics'), findsOneWidget);
      expect(find.text('All Topics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Industry Standards - Live Search Mode Integration Tests', () {
    testWidgets('Switches seamlessly between Category Directory and Live Search Results',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ExploreTopicsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Initially in Category Overview Mode
      expect(find.text('Featured Topics'), findsOneWidget);
      expect(find.text('All Topics'), findsOneWidget);
      expect(find.byType(ExploreTopicsSearchResults), findsNothing);

      // 2. User searches for a topic
      controller.searchQuery.value = 'Artificial Intelligence';
      await tester.pump(const Duration(milliseconds: 500));

      // Supply matching search result topic
      final aiTopic = buildTestTopic(
        id: 'ai_topic',
        title: 'Artificial Intelligence',
        category: 'Technology',
        videoCount: 12,
      );
      controller.topics.assignAll([aiTopic]);
      controller.rxIsLoading.value = false;
      controller.isAiSearching.value = false;
      await tester.pump();

      // 3. Search Results component is now visible
      expect(find.byType(ExploreTopicsSearchResults), findsOneWidget);
      expect(find.text('Search Results'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExploreTopicsSearchResults),
          matching: find.text('Artificial Intelligence'),
        ),
        findsOneWidget,
      );

      // 4. Clear search restores Category Overview Mode
      controller.clearSearch();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ExploreTopicsSearchResults), findsNothing);
      expect(find.text('Featured Topics'), findsOneWidget);
      expect(find.text('All Topics'), findsOneWidget);
    });
  });
}
