import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/following/following_topics_barrel.dart';
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    AuthService.to.setAuthenticatedForTesting(isAuthenticated: true, uid: 'usr_test_101');
  });

  tearDown(Get.reset);

  final now = Timestamp.now();
  final sampleTopic = Topic(
    id: 'topic_kerala_01',
    title: 'Kerala',
    slug: 'kerala',
    handle: '@kerala',
    handleLowercase: '@kerala',
    description: 'Kerala tourism',
    category: 'travel',
    tags: ['kerala', 'tourism', 'india'],
    videoCount: 2,
    followerCount: 1,
    commentCount: 1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleVideo1 = Video(
    id: 'vid_01',
    title: 'Athirappilly Waterfalls Kerala 1/2 | The Niagara of India | B...',
    description: 'Athirappilly falls tour',
    videoUrl: 'https://example.com/video1.mp4',
    thumbnailUrl: 'https://example.com/thumb1.jpg',
    duration: '22:03',
    ownerId: 'u_travel',
    channelId: 'ch_travel',
    channelName: 'Travel Kerala',
    views: 12000,
    likes: 540,
    uploadedAt: now,
    tags: ['kerala', 'waterfalls'],
    category: 'travel',
    isFactChecked: false,
  );

  final sampleVideo2 = Video(
    id: 'vid_02',
    title: 'Munnar Kerala | Beautiful Tea Gardens, Misty Mountai...',
    description: 'Munnar hill station',
    videoUrl: 'https://example.com/video2.mp4',
    thumbnailUrl: 'https://example.com/thumb2.jpg',
    duration: '17:01',
    ownerId: 'u_travel',
    channelId: 'ch_travel',
    channelName: 'Travel Kerala',
    views: 9800,
    likes: 430,
    uploadedAt: now,
    tags: ['kerala', 'munnar'],
    category: 'travel',
    isFactChecked: false,
  );

  group('Following Topics Desktop Layout & Zero Overflow Tests', () {
    testWidgets('FollowingTopicHeroBanner expands full width on desktop screen and does not shrink-wrap', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Get.testMode = true;
      final controller = FollowingTopicsController();
      controller.followedTopics.assignAll([sampleTopic]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FollowingTopicHeroBanner(
              topic: sampleTopic,
              controller: controller,
              isMobile: false,
              totalVideosCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('Kerala'), findsOneWidget);
      expect(find.text('Kerala tourism'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);

      final bannerFinder = find.byType(FollowingTopicHeroBanner);
      final bannerSize = tester.getSize(bannerFinder);
      // Verify banner expands across desktop width (> 1000px) instead of collapsing into a 350px card
      expect(bannerSize.width, greaterThan(1000.0));
      expect(bannerSize.height, greaterThanOrEqualTo(150.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('FollowingTopicVideoCard renders without bottom RenderFlex overflow in exact desktop column width', (tester) async {
      // Test at the exact constraints (w=289.8) that previously threw the 14-pixel overflow exception
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 289.8,
                child: FollowingTopicVideoCard(
                  topic: sampleTopic,
                  video: sampleVideo1,
                  isMobile: false,
                  index: 0,
                  totalCount: 2,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Athirappilly Waterfalls Kerala 1/2 | The Niagara of India | B...'), findsOneWidget);
      expect(find.text('Travel Kerala'), findsOneWidget);
      expect(find.text('22:03'), findsOneWidget);
    });

    testWidgets('FollowingTopicsGridSkeleton renders with Masonry layout without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FollowingTopicsGridSkeleton(
              isMobile: false,
              crossAxisCount: 3,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FollowingTopicsGridSkeleton), findsOneWidget);
    });

    testWidgets('FollowingTopicsPage renders cleanly on desktop resolution without any RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Get.testMode = true;
      final controller = FollowingTopicsController();
      Get.put<FollowingTopicsController>(controller);
      controller.followedTopics.assignAll([sampleTopic]);
      controller.selectTopic(sampleTopic);
      controller.topicVideosMap[sampleTopic.id] = [sampleVideo1, sampleVideo2];

      await tester.pumpWidget(
        const MaterialApp(
          home: FollowingTopicsPage(isDashboard: true),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Kerala'), findsWidgets);
      expect(find.text('Athirappilly Waterfalls Kerala 1/2 | The Niagara of India | B...'), findsOneWidget);
      expect(find.text('Munnar Kerala | Beautiful Tea Gardens, Misty Mountai...'), findsOneWidget);
    });
  });
}
