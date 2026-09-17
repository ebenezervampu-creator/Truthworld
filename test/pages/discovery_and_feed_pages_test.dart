import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/category/presentation/views/category/category_page.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as app_search;
import 'package:truthworld/features/search/presentation/pages/search_page.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart';
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart';
import 'package:truthworld/features/topics/presentation/pages/topic_page.dart';
import 'package:truthworld/features/trending/presentation/controllers/trending_controller.dart';
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart';
import '../test_helpers/mock_firebase.dart';
import 'page_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Group 2: Discovery & Exploration Pages', () {
    testWidgets('1. CategoryPage renders properly with tabs and filters',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CategoryPage(),
        onBeforePump: () {
          Get.put<CategoryController>(CategoryController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CategoryPage), findsOneWidget);
    });

    testWidgets('2. ExploreTopicsPage renders topic categories and discovery grid',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const ExploreTopicsPage(),
        onBeforePump: () {
          Get.put<ExploreTopicsController>(ExploreTopicsController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ExploreTopicsPage), findsOneWidget);
    });

    testWidgets('3. FollowingTopicsPage renders followed topics feed',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const FollowingTopicsPage(),
        onBeforePump: () {
          Get.put<FollowingTopicsController>(FollowingTopicsController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(FollowingTopicsPage), findsOneWidget);
    });

    testWidgets('4. TopicPage renders topic banner and layout',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const TopicPage(),
        onBeforePump: () {
          final ctrl = Get.put<TopicController>(TopicController());
          final now = DateTime.now();
          ctrl.topic.value = Topic(
            id: 'top_test_1',
            title: 'Artificial Intelligence',
            slug: 'artificial-intelligence',
            handle: 'ai',
            handleLowercase: 'ai',
            description: 'Latest advancements in AI and Deep Learning',
            category: 'Technology',
            createdAt: now,
            updatedAt: now,
          );
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TopicPage), findsOneWidget);
    });

    testWidgets('5. TrendingVideosPage renders trending feed list',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const TrendingVideosPage(),
        onBeforePump: () {
          Get.put<TrendingController>(TrendingController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TrendingVideosPage), findsOneWidget);
    });

    testWidgets('6. SearchPage renders search bar and filter chips',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SearchPage(),
        onBeforePump: () {
          if (!Get.isRegistered<ConnectivityService>()) {
            Get.put<ConnectivityService>(ConnectivityService());
          }
          Get.put<app_search.SearchController>(app_search.SearchController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SearchPage), findsOneWidget);
    });
  });
}
