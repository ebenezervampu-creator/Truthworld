import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/following/following_topics_barrel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  final now = Timestamp.now();
  final sampleTopic = Topic(
    id: 'topic_science_01',
    title: 'Space & Astronomy',
    slug: 'space-astronomy',
    handle: '@space-astronomy',
    handleLowercase: '@space-astronomy',
    description: 'Explore the cosmos',
    category: 'science',
    tags: ['space', 'astronomy'],
    videoCount: 12,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleVideo = Video(
    id: 'vid_01',
    title: 'James Webb Telescope Discoveries',
    description: 'Latest deep space imagery',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    duration: '12:34',
    ownerId: 'u_nasa',
    channelId: 'ch_nasa',
    channelName: 'NASA Space Science',
    views: 45000,
    likes: 1200,
    dislikeCount: 10,
    uploadedAt: now,
    tags: ['space', 'science'],
    category: 'science',
    isFactChecked: true,
  );

  group('FollowingTopicsHeader', () {
    testWidgets('renders search field, search icon and back button', (tester) async {
      Get.testMode = true;
      final controller = FollowingTopicsController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FollowingTopicsHeader(
              controller: controller,
              isMobile: true,
              isDashboard: false,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.text('Search followed topics...'), findsOneWidget);
    });
  });

  group('FollowingTopicsPills', () {
    testWidgets('renders All Topics and followed topic chips', (tester) async {
      Get.testMode = true;
      final controller = FollowingTopicsController();
      controller.followedTopics.assignAll([sampleTopic]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FollowingTopicsPills(controller: controller),
          ),
        ),
      );

      expect(find.text('All Topics'), findsOneWidget);
      expect(find.text('Space & Astronomy'), findsOneWidget);
    });
  });

  group('FollowingTopicVideoCard', () {
    testWidgets('renders video title, channel name, badges and options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FollowingTopicVideoCard(
              topic: sampleTopic,
              video: sampleVideo,
              isMobile: true,
              cardWidth: 280,
            ),
          ),
        ),
      );

      expect(find.text('James Webb Telescope Discoveries'), findsOneWidget);
      expect(find.text('NASA Space Science'), findsOneWidget);
      expect(find.text('Space & Astronomy'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.text('12:34'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('FollowingTopicsEmptyStates', () {
    testWidgets('FollowingTopicsAuthRequiredState renders lock icon and sign-in message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FollowingTopicsAuthRequiredState(),
          ),
        ),
      );

      expect(find.text('Sign In Required'), findsOneWidget);
      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);
    });

    testWidgets('FollowingTopicsErrorState renders error message and retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FollowingTopicsErrorState(
              errorMessage: 'Network timeout occurred',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Network timeout occurred'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('FollowingTopicsEmptyState renders bookmark icon and explore button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FollowingTopicsEmptyState(),
          ),
        ),
      );

      expect(find.text('No followed topics yet'), findsOneWidget);
      expect(find.text('Explore Topics'), findsOneWidget);
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    });

    testWidgets('FollowingTopicsNoResultsState renders no topics found', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FollowingTopicsNoResultsState(),
          ),
        ),
      );

      expect(find.text('No topics found'), findsOneWidget);
      expect(find.text('Try adjusting your search terms'), findsOneWidget);
    });

    testWidgets('FollowingTopicsLoadingState renders shimmer skeletons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FollowingTopicsLoadingState(isMobile: true, isTablet: false),
          ),
        ),
      );

      expect(find.byType(FollowingTopicsVideoSkeleton), findsNWidgets(2));
    });
  });

  group('FollowingTopicSection', () {
    testWidgets('renders topic header title and fallback when no videos loaded', (tester) async {
      Get.testMode = true;
      final controller = FollowingTopicsController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FollowingTopicSection(
              topic: sampleTopic,
              controller: controller,
              isMobile: true,
            ),
          ),
        ),
      );

      expect(find.text('Space & Astronomy'), findsWidgets);
      expect(find.text('Tap to view topic details page'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });
}
