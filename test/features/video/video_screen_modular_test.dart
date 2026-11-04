import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_screen_widgets.dart';
import 'package:video_player/video_player.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  Widget wrapWithMaterial(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  final sampleVideo = Video.fromMap({
    'title': 'Modular Video Screen Test',
    'channelId': 'chan_mod_1',
    'channelName': 'TruthWorld Studio',
    'videoUrl': 'https://example.com/video.mp4',
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'durationMs': 120000,
    'chapters': [
      {'title': 'Chapter 1: Intro', 'startTime': 0},
      {'title': 'Chapter 2: Deep Dive', 'startTime': 60},
    ],
  }, 'vid_mod_101');

  final samplePlaylist = PlaylistModel(
    id: 'pl_101',
    ownerId: 'user_1',
    channelId: 'chan_1',
    playlistName: 'Refactoring Mastery',
    videoIds: ['vid_mod_101', 'vid_mod_102'],
    videoCount: 2,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleTopic = Topic(
    id: 'top_101',
    title: 'Clean Architecture',
    slug: 'clean-architecture',
    handle: 'clean-arch',
    handleLowercase: 'clean-arch',
    description: 'Guidelines on separation of concerns',
    category: 'Technology',
    videoCount: 8,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('VideoScreen Modular Architecture Tests', () {
    testWidgets('1. ResponsiveVideoAppBar hides in fullscreen and shows otherwise',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            appBar: ResponsiveVideoAppBar(
              controller: controller,
              appBarBuilder: () => AppBar(title: const Text('Custom AppBar')),
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom AppBar'), findsOneWidget);

      // Toggle fullscreen
      controller.isFullScreen.value = true;
      await tester.pumpAndSettle();

      expect(find.text('Custom AppBar'), findsNothing);

      // Exit fullscreen
      controller.isFullScreen.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Custom AppBar'), findsOneWidget);
    });

    testWidgets('2. VideoPlaylistBanner renders playlist info and progress',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);
      controller.video = sampleVideo;
      controller.currentPlaylist.value = samplePlaylist;

      await tester.pumpWidget(
        wrapWithMaterial(
          VideoPlaylistBanner(
            controller: controller,
            playlist: samplePlaylist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PLAYLIST'), findsOneWidget);
      expect(find.text('Refactoring Mastery'), findsOneWidget);
      expect(find.textContaining('Playing video 1 of 2'), findsOneWidget);
    });

    testWidgets('3. VideoTopicBanner renders topic name and video count',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);
      controller.video = sampleVideo;

      await tester.pumpWidget(
        wrapWithMaterial(
          VideoTopicBanner(
            controller: controller,
            topic: sampleTopic,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOPIC'), findsOneWidget);
      expect(find.text('Clean Architecture'), findsOneWidget);
      expect(find.textContaining('8 videos'), findsOneWidget);
    });

    testWidgets('4. VideoChaptersSection renders chapters list and expansion tile',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);
      controller.video = sampleVideo;

      await tester.pumpWidget(
        wrapWithMaterial(
          VideoChaptersSection(
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets(
        '4b. VideoChaptersSection renders active chapter with TowerPlayerController without performLayout errors',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);
      controller.video = sampleVideo;

      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/test.mp4'),
      );
      final towerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
      );
      Get.put(towerCtrl);
      towerCtrl.currentChapter.value = sampleVideo.chapters.first;

      await tester.pumpWidget(
        wrapWithMaterial(
          VideoChaptersSection(
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('Current: Chapter 1: Intro'), findsOneWidget);

      Get.delete<TowerPlayerController>();
    });

    testWidgets('5. VideoScreenRecommendationHeader toggles autoplay correctly',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);
      controller.isAutoplay.value = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          VideoScreenRecommendationHeader(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Autoplay'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(controller.isAutoplay.value, isTrue);
    });

    testWidgets(
        '5b. VideoScreenRecommendationHeader renders without overflow under tight width',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);

      await tester.pumpWidget(
        wrapWithMaterial(
          SizedBox(
            width: 214.0,
            child: VideoScreenRecommendationHeader(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Autoplay'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. VideoPlayerErrorView renders error state with retry button',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);
      controller.errorMessageRx.value = 'Network connection timed out';

      await tester.pumpWidget(
        wrapWithMaterial(
          VideoPlayerErrorView(
            controller: controller,
            thumbnailWidget: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network connection timed out'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('7. VideoPlaylistDrawer renders tracks and controls',
        (tester) async {
      final controller = VideoController();
      Get.put(controller);
      controller.video = sampleVideo;
      controller.currentPlaylist.value = samplePlaylist;
      controller.playlistVideos.assignAll([sampleVideo]);

      await tester.pumpWidget(
        wrapWithMaterial(
          VideoPlaylistDrawer(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refactoring Mastery'), findsOneWidget);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Modular Video Screen Test'), findsOneWidget);
    });
  });
}
