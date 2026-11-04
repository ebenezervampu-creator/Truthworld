import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_widgets.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

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

    test('TopicCategoriesConfig provides Music category without mock subtopics or mock counts', () {
      final music = TopicCategoriesConfig.getCategory('Music');
      expect(music.title, equals('Music'));
      expect(music.featuredSubtitle, equals('Worship, praise, and faith through music.'));
      expect(music.topicCountText, isEmpty);
      expect(music.curatedSubtopics, isEmpty);
    });

    test('TopicCategoriesConfig has ZERO mock subtopics and ZERO mock topic counts across all categories', () {
      for (final cat in TopicCategoriesConfig.categories) {
        expect(cat.topicCountText, isEmpty,
            reason: '${cat.title} should not have mock topicCountText');
        expect(cat.curatedSubtopics, isEmpty,
            reason: '${cat.title} should not have mock curatedSubtopics');
      }
    });

    test('TopicCategoriesConfig provides Spirituality and Technology categories without mock subtopics', () {
      final spirit = TopicCategoriesConfig.getCategory('Spirituality');
      expect(spirit.title, equals('Spirituality'));
      expect(spirit.featuredSubtitle, equals('Inner peace, prayer, and spiritual growth.'));
      expect(spirit.curatedSubtopics, isEmpty);

      final tech = TopicCategoriesConfig.getCategory('Technology');
      expect(tech.title, equals('Technology'));
      expect(tech.featuredSubtitle, equals('Innovation, AI, and the wonders of creation.'));
      expect(tech.curatedSubtopics, isEmpty);
    });

    test('TopicCategoriesConfig contains all 31 unified categories', () {
      final titles = TopicCategoriesConfig.categories.map((c) => c.title).toSet();
      for (final cat in AppCategories.allCategories) {
        expect(titles.contains(cat), isTrue, reason: '$cat should be present');
      }
    });
  });

  group('ExploreTopicsFeaturedSection Responsive Tests', () {
    setUp(() {
      Get.reset();
      Get.put<ExploreTopicsController>(ExploreTopicsController());
    });

    tearDown(Get.reset);

    testWidgets(
        'Renders without overflow on narrow mobile screen (352px width)',
        (tester) async {
      tester.view.physicalSize = const Size(352, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 352,
              child: ExploreTopicsFeaturedSection(isMobile: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Featured Topics'), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      expect(find.text('Popular topics you may like'), findsNothing);
      expect(find.text('Discover'), findsNothing);
      expect(find.text('Trending'), findsNothing);
      expect(find.text('Newest'), findsNothing);
      expect(find.text('Popular'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders without overflow on desktop screen (1200px width)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: ExploreTopicsFeaturedSection(isDesktop: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Featured Topics'), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      expect(find.text('Popular topics you may like'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Zero Mock Topics Count Verification Tests', () {
    setUp(() {
      Get.reset();
      Get.put<ExploreTopicsController>(ExploreTopicsController());
    });

    tearDown(Get.reset);

    testWidgets('ExploreTopicsAllCategoriesGrid never displays mock topics count',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreTopicsAllCategoriesGrid(isDesktop: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that mock numbers from previous implementation are NEVER displayed
      expect(find.text('8.4K topics'), findsNothing);
      expect(find.text('7.1K topics'), findsNothing);
      expect(find.text('9.3K topics'), findsNothing);
      expect(find.text('12.4K topics'), findsNothing);
      expect(find.text('14.2K topics'), findsNothing);
      expect(find.text('15.1K topics'), findsNothing);
      expect(find.text('18.9K topics'), findsNothing);

      // Verify that clean category cards are rendered
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExploreCategoryDetailView never displays mock 12.4K topics fallback',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreCategoryDetailView(
                categoryName: 'Business',
                isDesktop: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no mock 12.4K topics in hero banner
      expect(find.text('12.4K topics'), findsNothing);
      expect(find.text('8.4K topics'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExploreCategoryDetailView does not render follow button or icon in category hero banner',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExploreCategoryDetailView(
                categoryName: 'News',
                isMobile: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no Follow button / follow icon in category hero banner
      expect(find.text('Follow'), findsNothing);
      expect(find.text('Following'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(find.text('News'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Topic Deduplication & Deterministic Counting Tests', () {
    test('Topic.canonicalKey strips trailing random UUID suffixes and normalizes slug', () {
      final topicA = Topic(
        id: 'doc_1',
        title: 'Worship Music',
        slug: 'worship-music',
        handle: 'T/worship-music',
        handleLowercase: 't/worship-music',
        description: 'Worship music for community and contemplation.',
        category: 'Music',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final topicB = Topic(
        id: 'doc_2',
        title: 'Worship Music',
        slug: 'worship-music-a1b2c3',
        handle: 'T/worship-music-a1b2c3',
        handleLowercase: 't/worship-music-a1b2c3',
        description: 'Worship music for community and contemplation.',
        category: 'Music',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final topicC = Topic(
        id: 'doc_3',
        title: 'Worship Music',
        slug: 'worship-music-12345678',
        handle: 'T/worship-music-12345678',
        handleLowercase: 't/worship-music-12345678',
        description: 'Worship music for community and contemplation.',
        category: 'Music',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(topicA.canonicalKey, equals('worship-music'));
      expect(topicB.canonicalKey, equals('worship-music'));
      expect(topicC.canonicalKey, equals('worship-music'));
    });

    test('ExploreTopicsController deterministically counts topics without doubling or drift', () {
      final controller = Get.isRegistered<ExploreTopicsController>()
          ? Get.find<ExploreTopicsController>()
          : Get.put(ExploreTopicsController());

      // Set authentic count for Music category to 1
      controller.authenticCategoryTopicCounts['music'] = 1;

      expect(controller.getAuthenticTopicCount('Music'), equals(1));
      expect(controller.getAuthenticTopicCount('music'), equals(1));

      const musicCat = TopicCategory(
        id: 'music',
        title: 'Music',
        imageUrl: '',
      );

      expect(controller.getAuthenticTopicCountText(musicCat), equals('1 topic'));

      // Verify that calling multiple times does not increase the count
      expect(controller.getAuthenticTopicCount('Music'), equals(1));
      expect(controller.getAuthenticTopicCountText(musicCat), equals('1 topic'));
    });

    test('ExploreTopicsController fallback deduplicates topics by canonicalKey', () {
      final controller = Get.isRegistered<ExploreTopicsController>()
          ? Get.find<ExploreTopicsController>()
          : Get.put(ExploreTopicsController());

      controller.authenticCategoryTopicCounts.clear();

      final doc1 = Topic(
        id: 'doc_1',
        title: 'Gospel Praise',
        slug: 'gospel-praise',
        handle: 'T/gospel-praise',
        handleLowercase: 't/gospel-praise',
        description: 'Praise and devotion songs.',
        category: 'Music',
        videoCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final doc2 = Topic(
        id: 'doc_2',
        title: 'Gospel Praise',
        slug: 'gospel-praise-f9c3b1',
        handle: 'T/gospel-praise-f9c3b1',
        handleLowercase: 't/gospel-praise-f9c3b1',
        description: 'Praise and devotion songs.',
        category: 'Music',
        videoCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.topics.assignAll([doc1, doc2]);

      // Even though there are 2 documents in topics list for the same topic,
      // fallback counting deduplicates by canonicalKey and returns 1!
      expect(controller.getAuthenticTopicCount('Music'), equals(1));

      const musicCat = TopicCategory(
        id: 'music',
        title: 'Music',
        imageUrl: '',
      );
      expect(controller.getAuthenticTopicCountText(musicCat), equals('1 topic'));
    });
  });

  group('Zero Mock Subtopics in Category Detail Verification Tests', () {
    setUp(() {
      Get.reset();
      Get.put<ExploreTopicsController>(ExploreTopicsController());
    });

    tearDown(Get.reset);

    test('getSubtopicsForCategory returns ONLY authentic Firestore topics and ZERO mock topics', () {
      final controller = Get.find<ExploreTopicsController>();

      final christianSongs = Topic(
        id: 'real_doc_music_1',
        title: 'Christian songs 2026',
        slug: 'christian-songs-2026',
        handle: 'T/christian-songs-2026',
        handleLowercase: 't/christian-songs-2026',
        description: 'Verified Christian songs collection.',
        category: 'Music',
        videoCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Suppose the database has only 1 topic in the Music category
      controller.topics.assignAll([christianSongs]);

      final subtopics = controller.getSubtopicsForCategory('Music');

      // MUST strictly return only the 1 authentic topic!
      expect(subtopics.length, equals(1));
      expect(subtopics.first.title, equals('Christian songs 2026'));
      expect(subtopics.first.id, equals('real_doc_music_1'));

      // MUST NEVER contain any synthetic or curated mock topics
      for (final topic in subtopics) {
        expect(topic.id.startsWith('curated_'), isFalse);
        expect(topic.effectiveVideoCount, greaterThan(0));
      }
    });

    test('getSubtopicsForCategory returns empty list when category has no authentic topics in database', () {
      final controller = Get.find<ExploreTopicsController>();

      // Controller has topics for other categories, but none for Music
      final techTopic = Topic(
        id: 'real_doc_tech_1',
        title: 'Artificial Intelligence',
        slug: 'artificial-intelligence',
        handle: 'T/artificial-intelligence',
        handleLowercase: 't/artificial-intelligence',
        description: 'AI innovations and analysis.',
        category: 'Technology',
        videoCount: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.topics.assignAll([techTopic]);

      final musicSubtopics = controller.getSubtopicsForCategory('Music');

      // MUST be completely empty, never injecting mock curated subtopics like Worship Music or Piano Covers
      expect(musicSubtopics, isEmpty);
    });

    test('getSubtopicsForCategory deduplicates multiple documents with same canonicalKey', () {
      final controller = Get.find<ExploreTopicsController>();

      final doc1 = Topic(
        id: 'doc_1',
        title: 'Christian songs 2026',
        slug: 'christian-songs-2026',
        handle: 'T/christian-songs-2026',
        handleLowercase: 't/christian-songs-2026',
        description: 'Christian songs 2026',
        category: 'Music',
        videoCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final doc2 = Topic(
        id: 'doc_2',
        title: 'Christian songs 2026',
        slug: 'christian-songs-2026-abc123',
        handle: 'T/christian-songs-2026-abc123',
        handleLowercase: 't/christian-songs-2026-abc123',
        description: 'Christian songs 2026 duplicate',
        category: 'Music',
        videoCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.topics.assignAll([doc1, doc2]);

      final subtopics = controller.getSubtopicsForCategory('Music');

      expect(subtopics.length, equals(1));
      expect(subtopics.first.canonicalKey, equals('christian-songs-2026'));
    });
  });
}


