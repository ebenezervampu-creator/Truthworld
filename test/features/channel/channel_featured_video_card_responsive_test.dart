import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_home_tab_view.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

class MockChannelSubscriptionController extends ChannelSubscriptionController {
  @override
  void listenSubscription(String channelId) {}

  @override
  void listenMembership(String channelId) {}

  @override
  void listenMembershipTiers(String channelId) {}

  @override
  void fetchSubscriberCount(String channelId) {}
}

class TestChannelController extends ChannelController {
  TestChannelController(MockChannelSubscriptionController mockSub) {
    subController = mockSub;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('ChannelFeaturedVideoCard Responsive Tests', () {
    late MockChannelSubscriptionController mockSub;
    late TestChannelController testController;

    setUp(Get.reset);
    tearDown(Get.reset);

    Video createSampleVideo({
      String id = 'vid_1',
      String title = '10 Facts about India',
      String description = 'Fascinating business insights and historical facts.',
      String duration = '03:19',
    }) {
      return Video(
        id: id,
        title: title,
        description: description,
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoUrl: 'https://example.com/video.mp4',
        duration: duration,
        views: 1250,
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'Test Channel',
        category: 'Education',
        tags: const ['business', 'facts'],
        createdAt: Timestamp.now(),
        uploadedAt: Timestamp.now(),
        geminiApproved: true,
        isApproved: true,
      );
    }

    void setupController() {
      Get.reset();
      mockSub = MockChannelSubscriptionController();
      Get.put<ChannelSubscriptionController>(mockSub, permanent: true);
      testController = TestChannelController(mockSub);
      Get.put<ChannelController>(testController, permanent: true);
    }

    testWidgets('Renders horizontal layout with bounded 424px thumbnail on desktop',
        (tester) async {
      setupController();
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testController.videos.assignAll([createSampleVideo()]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelFeaturedVideoCard(
              isDesktop: true,
              controller: testController,
            ),
          ),
        ),
      );
      await tester.pump();

      // On desktop, it should render a Row with thumbnail and metadata
      expect(find.text('10 Facts about India'), findsOneWidget);
      expect(find.text('03:19'), findsOneWidget);
      expect(
        find.text('Fascinating business insights and historical facts.'),
        findsOneWidget,
      );

      // Verify cached network image has 424px width on desktop
      final imageFinder = find.byType(CachedNetworkImage);
      expect(imageFinder, findsOneWidget);
      final cachedImage = tester.widget<CachedNetworkImage>(imageFinder);
      expect(cachedImage.width, 424.0);
      expect(cachedImage.height, 424.0 * 9 / 16);

      // On desktop, it must NOT use full-width AspectRatio
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('Renders vertical column layout with AspectRatio on mobile',
        (tester) async {
      setupController();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testController.videos.assignAll([createSampleVideo()]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelFeaturedVideoCard(
              controller: testController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('10 Facts about India'), findsOneWidget);
      expect(find.text('03:19'), findsOneWidget);

      // On mobile, it uses AspectRatio(16/9)
      expect(find.byType(AspectRatio), findsOneWidget);
      final aspectRatioWidget = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatioWidget.aspectRatio, 16 / 9);
    });

    testWidgets('Renders horizontal layout with 280px thumbnail on tablet',
        (tester) async {
      setupController();
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testController.videos.assignAll([createSampleVideo()]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelFeaturedVideoCard(
              isTablet: true,
              controller: testController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('10 Facts about India'), findsOneWidget);

      final imageFinder = find.byType(CachedNetworkImage);
      expect(imageFinder, findsOneWidget);
      final cachedImage = tester.widget<CachedNetworkImage>(imageFinder);
      expect(cachedImage.width, 280.0);
      expect(cachedImage.height, 280.0 * 9 / 16);
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('Returns SizedBox.shrink when videos list is empty',
        (tester) async {
      setupController();
      testController.videos.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelFeaturedVideoCard(
              isDesktop: true,
              controller: testController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('10 Facts about India'), findsNothing);
    });
  });
}

