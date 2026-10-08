import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
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
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  final sampleVideo = Video(
    id: 'vid_001',
    title: 'Christian songs Redx Media',
    description: 'An inspirational gospel music collection.',
    thumbnailUrl: 'https://truthworld.app/thumb1.jpg',
    videoUrl: 'https://truthworld.app/video.mp4',
    ownerId: 'creator_01',
    channelId: 'chan_01',
    channelName: 'Ebenezer Vampu',
    category: 'music',
    tags: ['christian', 'gospel'],
    views: 1200,
    duration: '07:35',
    status: VideoStatus.ready,
    visibility: 'public',
    geminiApproved: true,
    isApproved: true,
  );

  group('TopicVideoGrid Responsive Layout Tests', () {
    testWidgets('renders single-column ListView on mobile screen with isGrid true VideoCards', (tester) async {
      // Set mobile phone viewport size (390 x 844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TopicVideoGrid(
                videos: [sampleVideo],
                isLoadingMore: false,
                hasMore: false,
                isDesktop: false,
                isTablet: false,
                heroPrefix: 'topic_test',
                onLoadMore: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that ListView is used on mobile
      expect(find.byType(ListView), findsOneWidget);

      // Verify VideoCard is rendered with isGrid: true (not the old horizontal row)
      final videoCardFinder = find.byType(VideoCard);
      expect(videoCardFinder, findsOneWidget);
      final videoCard = tester.widget<VideoCard>(videoCardFinder);
      expect(videoCard.isGrid, isTrue);

      // Verify VideoCardGridInfo is rendered, not VideoCardListInfo
      expect(find.byType(VideoCardGridInfo), findsOneWidget);
      expect(find.byType(VideoCardListInfo), findsNothing);

      // Verify end-of-list message
      expect(find.text('No more videos'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders MasonryGridView on desktop screen with isGrid true VideoCards', (tester) async {
      // Set desktop viewport size (1440 x 900)
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TopicVideoGrid(
                videos: [sampleVideo],
                isLoadingMore: false,
                hasMore: false,
                isDesktop: true,
                isTablet: false,
                heroPrefix: 'topic_test',
                onLoadMore: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that MasonryGridView is used on desktop
      expect(find.byType(MasonryGridView), findsOneWidget);

      // Verify VideoCard is rendered with isGrid: true
      final videoCardFinder = find.byType(VideoCard);
      expect(videoCardFinder, findsOneWidget);
      final videoCard = tester.widget<VideoCard>(videoCardFinder);
      expect(videoCard.isGrid, isTrue);

      // Verify VideoCardGridInfo is rendered
      expect(find.byType(VideoCardGridInfo), findsOneWidget);
      expect(find.byType(VideoCardListInfo), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('renders empty state when videos list is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicVideoGrid(
              videos: const [],
              isLoadingMore: false,
              hasMore: false,
              isDesktop: false,
              isTablet: false,
              heroPrefix: 'topic_test',
              onLoadMore: () {},
              emptyTitle: 'No videos yet',
              emptySubtitle: 'Videos related to this topic will appear here',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No videos yet'), findsOneWidget);
      expect(find.text('Videos related to this topic will appear here'), findsOneWidget);
    });

    testWidgets('renders loading more indicator when isLoadingMore is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TopicVideoGrid(
                videos: [sampleVideo],
                isLoadingMore: true,
                hasMore: true,
                isDesktop: false,
                isTablet: false,
                heroPrefix: 'topic_test',
                onLoadMore: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  group('TopicVideoGridSkeleton Tests', () {
    testWidgets('renders ListView skeleton on mobile screen', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicVideoGridSkeleton(
              isDesktop: false,
              isTablet: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders MasonryGridView skeleton on desktop screen', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopicVideoGridSkeleton(
              isDesktop: true,
              isTablet: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MasonryGridView), findsOneWidget);
    });
  });
}
