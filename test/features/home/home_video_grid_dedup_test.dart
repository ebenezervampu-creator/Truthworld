import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_video_grid_section.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_video_grid.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  final sampleVideo1 = Video(
    id: '1f3cffb1-48c5-4aff-806a-52e500c4256c',
    title: 'TruthWorld Video 1',
    description: 'First video description',
    thumbnailUrl: 'https://cdn.truthworld.in/thumb1.jpg',
    videoUrl: 'https://cdn.truthworld.in/video1.mp4',
    ownerId: 'user_01',
    channelId: 'ch_01',
    channelName: 'Channel One',
    category: 'General',
    tags: ['truth', 'news'],
  );

  final sampleVideoDuplicate = Video(
    id: '1f3cffb1-48c5-4aff-806a-52e500c4256c',
    title: 'TruthWorld Video 1 Duplicate',
    description: 'Duplicate entry in raw feed',
    thumbnailUrl: 'https://cdn.truthworld.in/thumb1.jpg',
    videoUrl: 'https://cdn.truthworld.in/video1.mp4',
    ownerId: 'user_01',
    channelId: 'ch_01',
    channelName: 'Channel One',
    category: 'General',
    tags: ['truth', 'news'],
  );

  final sampleVideo2 = Video(
    id: '2a4d00c2-59d6-5bff-917b-63f611d5367d',
    title: 'TruthWorld Video 2',
    description: 'Second video description',
    thumbnailUrl: 'https://cdn.truthworld.in/thumb2.jpg',
    videoUrl: 'https://cdn.truthworld.in/video2.mp4',
    ownerId: 'user_02',
    channelId: 'ch_02',
    channelName: 'Channel Two',
    category: 'General',
    tags: ['truth', 'news'],
  );

  group('Video Grid Deduplication and Hero Tag Safety Tests', () {
    testWidgets('HomeVideoGridSection deduplicates duplicate video IDs to prevent Hero tag collision', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                HomeVideoGridSection(
                  isMobile: true,
                  isTablet: false,
                  isDesktop: false,
                  videos: [sampleVideo1, sampleVideoDuplicate, sampleVideo2],
                  heroPrefix: 'main_grid',
                  isLoading: false,
                  horizontalPadding: 16.0,
                  formatViews: (v) => '$v views',
                  formatTimestamp: (t) => 'just now',
                ),
              ],
            ),
          ),
        ),
      );

      // Verify that exactly 2 VideoCard widgets are rendered (the duplicate is filtered out)
      expect(find.byType(VideoCard), findsNWidgets(2));

      // Verify no multiple heroes assertion exception occurred
      expect(tester.takeException(), isNull);

      // Verify that the Hero tags in the tree are unique
      final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
      final heroTags = heroes.map((h) => h.tag).toList();
      expect(heroTags.toSet().length, equals(heroTags.length));
      expect(heroTags, contains('main_grid_1f3cffb1-48c5-4aff-806a-52e500c4256c'));
      expect(heroTags, contains('main_grid_2a4d00c2-59d6-5bff-917b-63f611d5367d'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('TopicVideoGrid deduplicates duplicate video IDs to prevent Hero tag collision', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TopicVideoGrid(
                videos: [sampleVideo1, sampleVideoDuplicate, sampleVideo2],
                isLoadingMore: false,
                hasMore: false,
                isDesktop: false,
                isTablet: false,
                heroPrefix: 'topic_kerala',
                onLoadMore: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Exactly 2 VideoCard widgets should be rendered
      expect(find.byType(VideoCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
      final heroTags = heroes.map((h) => h.tag).toList();
      expect(heroTags.toSet().length, equals(heroTags.length));
      expect(heroTags, contains('topic_kerala_1f3cffb1-48c5-4aff-806a-52e500c4256c'));
      expect(heroTags, contains('topic_kerala_2a4d00c2-59d6-5bff-917b-63f611d5367d'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Route navigation with Hero animation does not throw multiple heroes error', (
      tester,
    ) async {
      final key = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                HomeVideoGridSection(
                  isMobile: true,
                  isTablet: false,
                  isDesktop: false,
                  videos: [sampleVideo1, sampleVideoDuplicate],
                  heroPrefix: 'main_grid',
                  isLoading: false,
                  horizontalPadding: 16.0,
                  formatViews: (v) => '$v views',
                  formatTimestamp: (t) => 'just now',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Push watch route with the exact hero tag
      key.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: Hero(
              tag: 'main_grid_1f3cffb1-48c5-4aff-806a-52e500c4256c',
              child: Container(
                width: 200,
                height: 200,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Pump animation frames through transition
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 350));

      // Zero exceptions thrown during route transition
      expect(tester.takeException(), isNull);

      // Pop back to home
      key.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 350));

      // Zero exceptions thrown on pop
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
