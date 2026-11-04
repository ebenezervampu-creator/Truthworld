import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  Video createTestVideo({
    String id = 'video_1',
    String title = 'Test Multi-Language Video',
    String videoUrl = 'https://example.com/video.mp4',
    String language = 'en',
    Map<String, String>? dubbedVideos,
  }) {
    return Video(
      id: id,
      title: title,
      description: 'Test description',
      videoUrl: videoUrl,
      language: language,
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'user_1',
      channelId: 'test_channel_123',
      channelName: 'Test Channel',
      category: 'Tech',
      tags: const ['test'],
      dubbedVideos: dubbedVideos,
      audioTracks: const {
        'en': 'https://example.com/en.mp3',
        'es': 'https://example.com/es.mp3',
      },
    );
  }

  group('Audio Tracks Extracted Components Tests', () {
    testWidgets('AudioTracksVideoSidebar renders search input and video items', (tester) async {
      final controller = Get.put(AudioTracksController());
      final searchCtrl = TextEditingController();
      final testVideo = createTestVideo();
      controller.videos.value = [testVideo];
      controller.filteredVideos.value = [testVideo];
      controller.selectedVideo.value = testVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 600,
              child: AudioTracksVideoSidebar(
                controller: controller,
                searchController: searchCtrl,
                surfaceColor: const Color(0xFF141414),
                textColor: Colors.white,
                textSecondaryColor: Colors.grey,
                borderColor: const Color(0xFF262626),
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select Video'), findsOneWidget);
      expect(find.text('Test Multi-Language Video'), findsOneWidget);
      expect(find.byIcon(Icons.video_library_rounded), findsOneWidget);
    });

    testWidgets('AudioTracksWorkspaceHeader renders title, badges, and action buttons', (tester) async {
      final controller = Get.put(AudioTracksController());
      final testVideo = createTestVideo();
      final previewPlayer = false.obs;
      var uploadCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksWorkspaceHeader(
              video: testVideo,
              controller: controller,
              showPreviewPlayer: previewPlayer,
              surfaceColor: const Color(0xFF141414),
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              borderColor: const Color(0xFF262626),
              isDarkMode: true,
              onUploadTrack: () => uploadCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Multi-Language Video'), findsOneWidget);
      expect(find.text('Upload Track'), findsOneWidget);
      expect(find.text('Preview Sync'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      await tester.tap(find.text('Upload Track'));
      await tester.pump();
      expect(uploadCalled, isTrue);

      await tester.tap(find.text('Preview Sync'));
      await tester.pump();
      expect(previewPlayer.value, isTrue);
    });

    testWidgets('AudioTracksMobileToolbar renders mobile action controls', (tester) async {
      final controller = Get.put(AudioTracksController());
      final testVideo = createTestVideo();
      final previewPlayer = false.obs;
      var uploadCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksMobileToolbar(
              video: testVideo,
              controller: controller,
              showPreviewPlayer: previewPlayer,
              surfaceColor: const Color(0xFF141414),
              borderColor: const Color(0xFF262626),
              onUploadTrack: () => uploadCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Upload Track'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Upload Track'));
      await tester.pump();
      expect(uploadCalled, isTrue);
    });

    testWidgets('AudioTracksTabBar and TabPills render and switch active tab', (tester) async {
      final controller = Get.put(AudioTracksController());
      var addLanguageCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksTabBar(
              controller: controller,
              surfaceColor: const Color(0xFF141414),
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              borderColor: const Color(0xFF262626),
              isDarkMode: true,
              isMobile: false,
              onAddLanguage: () => addLanguageCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Audio & Video Tracks'), findsOneWidget);
      expect(find.textContaining('Languages & Layers'), findsOneWidget);
      expect(find.text('Add Language'), findsOneWidget);

      await tester.tap(find.text('Add Language'));
      await tester.pump();
      expect(addLanguageCalled, isTrue);

      // Switch tab
      await tester.tap(find.textContaining('Languages & Layers'));
      await tester.pump();
      expect(controller.activeTab.value, equals('languages'));
    });

    testWidgets('AudioTracksUnderlineTabBar renders AudioTracks and VideoTracks and switches tabs', (tester) async {
      final controller = Get.put(AudioTracksController());
      controller.setActiveTab('tracks');

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksUnderlineTabBar(controller: controller),
          ),
        ),
      );

      expect(find.text('AudioTracks'), findsOneWidget);
      expect(find.text('VideoTracks'), findsOneWidget);

      await tester.tap(find.text('VideoTracks'));
      await tester.pump();
      expect(controller.activeTab.value, equals('languages'));

      await tester.tap(find.text('AudioTracks'));
      await tester.pump();
      expect(controller.activeTab.value, equals('tracks'));
    });

    testWidgets('AudioTracksListSection and AudioTrackCard render audio tracks', (tester) async {
      final controller = Get.put(AudioTracksController());
      final testVideo = createTestVideo();
      controller.currentTracks.value = [
        AudioTrackItem(
          id: 'track_en',
          languageCode: 'en',
          languageName: 'English',
          audioUrl: 'https://example.com/en.mp3',
          isBaseTrack: true,
        ),
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksListSection(
              video: testVideo,
              controller: controller,
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              surfaceColor: const Color(0xFF141414),
              borderColor: const Color(0xFF262626),
              isDarkMode: true,
              onAddDubTrack: () {},
              onAddCommentary: () {},
              onPickAndUploadSingleDub: (_) async {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Audio Dubbing & Voiceover Tracks'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Primary Base Audio'), findsOneWidget);
    });

    testWidgets('EmptyTrackCard renders fallback message correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyTrackCard(
              message: 'No tracks configured.',
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              surfaceColor: Color(0xFF141414),
              borderColor: Color(0xFF262626),
            ),
          ),
        ),
      );

      expect(find.text('No tracks configured.'), findsOneWidget);
    });

    testWidgets('AudioTracksLanguagesManager renders language catalog', (tester) async {
      final controller = Get.put(AudioTracksController());
      var addLanguageCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksLanguagesManager(
              controller: controller,
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              surfaceColor: const Color(0xFF141414),
              borderColor: const Color(0xFF262626),
              isDarkMode: true,
              onAddLanguage: () => addLanguageCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Configured Language Dub Layers'), findsOneWidget);
      expect(find.text('Add Language Layer'), findsOneWidget);

      await tester.tap(find.text('Add Language Layer'));
      await tester.pump();
      expect(addLanguageCalled, isTrue);
    });

    testWidgets('AudioTracksRequestsGrid renders community dub requests', (tester) async {
      final controller = Get.put(AudioTracksController());
      controller.languageRequests.value = [
        LanguageRequest(
          id: 'req_1',
          language: 'ja',
          count: 42,
          type: 'audio',
          createdAt: Timestamp.now(),
        ),
      ];
      String? requestedLang;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AudioTracksRequestsGrid(
              controller: controller,
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              surfaceColor: const Color(0xFF141414),
              borderColor: const Color(0xFF262626),
              onUploadDubForRequest: (lang) => requestedLang = lang,
            ),
          ),
        ),
      );

      expect(find.textContaining('Viewer Audio Dubbing Requests'), findsOneWidget);
      expect(find.text('Requested by 42 viewers'), findsOneWidget);

      await tester.tap(find.text('Add Dub'));
      await tester.pump();
      expect(requestedLang, equals('ja'));
    });

    testWidgets('AudioTracksPage full coordinator renders without errors', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final page = AudioTracksPage(
        channelId: 'test_channel_123',
        isDarkMode: true,
      );

      final testVideo = createTestVideo();
      controller.rxState.value = ViewState.idle;
      controller.videos.value = [testVideo];
      controller.filteredVideos.value = [testVideo];
      controller.selectedVideo.value = testVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: page,
        ),
      );
      await tester.pump();

      expect(find.byType(AudioTracksPage), findsOneWidget);
      expect(find.byType(AudioTracksVideoSidebar), findsOneWidget);
    });

    testWidgets('VideoTracksListSection renders available video tracks and action button', (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(AudioTracksController());
      final testVideo = createTestVideo(
        id: 'test_vid_video_tab',
        title: 'Video Tab Test Video',
        videoUrl: 'https://storage.googleapis.com/test_video.mp4',
        language: 'en',
      );
      controller.selectedVideo.value = testVideo;
      controller.currentVideoTracks.value = [
        VideoTrackItem(
          id: 'test_vid_video_tab_en_video',
          languageCode: 'en',
          languageName: 'English (Original)',
          videoUrl: 'https://storage.googleapis.com/test_video.mp4',
          isBaseTrack: true,
          status: 'Published',
          role: 'Original video',
        ),
        VideoTrackItem(
          id: 'test_vid_video_tab_zh_video',
          languageCode: 'zh',
          languageName: 'Chinese (中文 / Mandarin)',
          videoUrl: 'https://storage.googleapis.com/test_video_zh.mp4',
          isBaseTrack: false,
          status: 'Published',
          role: 'Dubbed video',
        ),
      ];

      var addVideoCalled = false;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: VideoTracksListSection(
              video: testVideo,
              controller: controller,
              textColor: Colors.white,
              textSecondaryColor: Colors.grey,
              surfaceColor: const Color(0xFF141414),
              borderColor: const Color(0xFF262626),
              isDarkMode: true,
              onAddVideoTrack: () => addVideoCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Available Video tracks'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.byType(AvailableVideoTrackCard), findsNWidgets(2));
      expect(find.text('English (Original)'), findsOneWidget);
      expect(find.text('Chinese (中文 / Mandarin)'), findsOneWidget);

      await tester.tap(find.text('Video'));
      await tester.pump();
      expect(addVideoCalled, isTrue);
    });

    testWidgets('AudioTrackDubbingOptionsPage renders title, tiers, and tabs without errors', (tester) async {
      final controller = Get.put(AudioTracksController());
      final testVideo = createTestVideo(
        id: 'test_vid_page',
        title: 'Dubbing Options Page Test Video',
      );
      controller.selectedVideo.value = testVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: AudioTrackDubbingOptionsPage(
            controller: controller,
            initialLangCode: 'te',
            isDarkMode: true,
            initialMediaType: 'audio',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Audio Track & Dubbing Options'), findsOneWidget);
      expect(find.text('AI Voice Dubbing'), findsOneWidget);
      expect(find.text('Direct Audio Track'), findsOneWidget);
      expect(find.text('Audio (3 Tiers)'), findsOneWidget);
      expect(find.text('Video (2 Tiers)'), findsOneWidget);
    });
  });
}
