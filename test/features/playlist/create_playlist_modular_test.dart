import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/playlist/presentation/controllers/create_playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/create_playlist/create_playlist_widgets.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../pages/page_test_harness.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

  final sampleVideo = Video.fromMap({
    'title': 'Test Playlist Video',
    'channelId': 'chan_test_1',
    'channelName': 'TruthWorld Studio',
    'videoUrl': 'https://example.com/video.mp4',
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'duration': '05:32',
    'durationMs': 332000,
    'views': 120,
  }, 'vid_001');

  group('Create Playlist Modular Components Tests', () {
    testWidgets('1. PlaylistFormHeader renders title and back button',
        (tester) async {
      await pumpPageInHarness(
        tester,
        const Scaffold(
          body: PlaylistFormHeader(isDesktop: true),
        ),
      );

      expect(find.text('Create Playlist'), findsOneWidget);
      expect(
        find.text(
            'Organize videos into a playlist and share with your audience.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('2. PlaylistNameSection and DescriptionSection update counters',
        (tester) async {
      final controller = Get.put(CreatePlaylistController());

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PlaylistNameSection(controller: controller),
                PlaylistDescriptionSection(controller: controller),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1. Playlist Name'), findsOneWidget);
      expect(find.text('0/100'), findsOneWidget);
      expect(find.text('2. Description (Optional)'), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);

      // Enter name
      controller.nameController.text = 'Truth Investigation Series';
      await tester.pump();
      expect(find.text('${controller.nameLength.value}/100'), findsOneWidget);
      expect(controller.nameLength.value, equals(26));

      // Enter description
      controller.descController.text = 'A deep dive into facts and reports';
      await tester.pump();
      expect(find.text('${controller.descLength.value}/500'), findsOneWidget);
      expect(controller.descLength.value, equals(34));
    });

    testWidgets('3. PlaylistVisibilitySection toggles public and private states',
        (tester) async {
      final controller = Get.put(CreatePlaylistController());

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: PlaylistVisibilitySection(controller: controller),
          ),
        ),
      );

      expect(find.text('3. Playlist Type'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(controller.isPublic.value, isTrue);

      // Tap Private
      await tester.tap(find.text('Private'));
      await tester.pump();
      expect(controller.isPublic.value, isFalse);

      // Tap Public
      await tester.tap(find.text('Public'));
      await tester.pump();
      expect(controller.isPublic.value, isTrue);
    });

    testWidgets('4. PlaylistVideosSection renders empty state and list items',
        (tester) async {
      final controller = Get.put(CreatePlaylistController());
      var addVideosClicked = false;

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: PlaylistVideosSection(
              controller: controller,
              onAddVideos: () => addVideosClicked = true,
              isDesktop: true,
            ),
          ),
        ),
      );

      expect(find.text('4. Add Videos'), findsOneWidget);
      expect(find.text('0 videos selected'), findsOneWidget);
      expect(find.text('No videos selected yet'), findsOneWidget);

      // Click select videos button
      await tester.tap(find.text('Select videos'));
      expect(addVideosClicked, isTrue);

      // Add video to controller
      controller.selectedVideos.add(sampleVideo);
      await tester.pump();

      expect(find.text('1 videos selected'), findsOneWidget);
      expect(find.text('Test Playlist Video'), findsOneWidget);
      expect(find.text('05:32'), findsOneWidget);

      // Clear all
      await tester.tap(find.text('Clear all'));
      await tester.pump();
      expect(controller.selectedVideos.isEmpty, isTrue);
    });

    testWidgets('5. PlaylistThumbnailSection toggles video and custom options',
        (tester) async {
      final controller = Get.put(CreatePlaylistController());
      controller.selectedVideos.add(sampleVideo);

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: PlaylistThumbnailSection(
              controller: controller,
              isDesktop: true,
            ),
          ),
        ),
      );

      expect(find.text('5. Playlist Thumbnail'), findsOneWidget);
      expect(find.text('Use thumbnail from selected video'), findsOneWidget);
      expect(find.text('Upload custom image'), findsOneWidget);
      expect(controller.useCustomThumbnail.value, isFalse);

      // Select custom thumbnail
      await tester.tap(find.text('Upload custom image'));
      await tester.pump();
      expect(controller.useCustomThumbnail.value, isTrue);

      // Select video thumbnail
      await tester.tap(find.text('Use thumbnail from selected video'));
      await tester.pump();
      expect(controller.useCustomThumbnail.value, isFalse);
    });

    testWidgets('6. PlaylistFormActions renders desktop and mobile footer states',
        (tester) async {
      final controller = Get.put(CreatePlaylistController());
      var submitCount = 0;

      await pumpPageInHarness(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PlaylistDesktopFooterActions(
                  controller: controller,
                  onSubmit: () => submitCount++,
                ),
                PlaylistMobileStickyFooter(
                  controller: controller,
                  onSubmit: () => submitCount++,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Playlist'), findsNWidgets(2));

      // Tap submit
      await tester.tap(find.text('Create Playlist').first);
      expect(submitCount, equals(1));
    });

    testWidgets('7. CreatePlaylistScreen renders full responsive layout',
        (tester) async {
      await pumpPageInHarness(
        tester,
        const CreatePlaylistScreen(),
      );

      expect(find.byType(CreatePlaylistScreen), findsOneWidget);
      expect(find.byType(PlaylistFormHeader), findsOneWidget);
      expect(find.byType(PlaylistNameSection), findsOneWidget);
      expect(find.byType(PlaylistDescriptionSection), findsOneWidget);
      expect(find.byType(PlaylistVisibilitySection), findsOneWidget);
      expect(find.byType(PlaylistVideosSection), findsOneWidget);
      expect(find.byType(PlaylistThumbnailSection), findsOneWidget);
      expect(find.byType(PlaylistDesktopFooterActions), findsOneWidget);
    });
  });
}
