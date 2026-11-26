import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_workspace_top_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  testWidgets('SubtitlesWorkspaceTopBar layout at 864px width (1224x661 window)', (tester) async {
    final video = Video(
      id: 'test_vid_1',
      title: 'Zomato’s Big Transformation: From Food Delivery to a Consumer Empire',
      description: 'Test description',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'user_1',
      channelId: 'test_channel_123',
      channelName: 'Test Channel',
      category: 'Tech',
      tags: ['zomato', 'business'],
      mediaSubtitles: {'en': 'https://example.com/en.vtt'},
    );

    final controller = Get.put(SubtitlesController());
    controller.selectedVideo.value = video;

    tester.view.physicalSize = const Size(1224, 661);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.dark(),
        home: const SubtitlesPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
      ),
    );

    // Set selected video after page init
    controller.rxState.value = ViewState.success;
    controller.videos.assignAll([video]);
    controller.filteredVideos.assignAll([video]);
    controller.selectedVideo.value = video;
    await tester.pump();

    for (final element in find.byType(SubtitlesWorkspaceTopBar).evaluate()) {
      final renderBox = element.renderObject as RenderBox?;
      expect(renderBox?.size.height, lessThan(100.0));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('SubtitlesWorkspaceTopBar layout at narrow tablet width (800x600)', (tester) async {
    final video = Video(
      id: 'test_vid_2',
      title: 'Zomato’s Big Transformation: From Food Delivery to a Consumer Empire',
      description: 'Test description',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'user_1',
      channelId: 'test_channel_123',
      channelName: 'Test Channel',
      category: 'Tech',
      tags: ['zomato', 'business'],
      mediaSubtitles: {'en': 'https://example.com/en.vtt'},
    );

    final controller = Get.put(SubtitlesController());
    controller.selectedVideo.value = video;

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.dark(),
        home: const SubtitlesPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
      ),
    );

    controller.rxState.value = ViewState.success;
    controller.videos.assignAll([video]);
    controller.filteredVideos.assignAll([video]);
    controller.selectedVideo.value = video;
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('SubtitlesWorkspaceTopBar layout at mobile width (390x844)', (tester) async {
    final video = Video(
      id: 'test_vid_3',
      title: 'Zomato’s Big Transformation: From Food Delivery to a Consumer Empire',
      description: 'Test description',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'user_1',
      channelId: 'test_channel_123',
      channelName: 'Test Channel',
      category: 'Tech',
      tags: ['zomato', 'business'],
      mediaSubtitles: {'en': 'https://example.com/en.vtt'},
    );

    final controller = Get.put(SubtitlesController());
    controller.selectedVideo.value = video;

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.dark(),
        home: const SubtitlesPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
      ),
    );

    controller.rxState.value = ViewState.success;
    controller.videos.assignAll([video]);
    controller.filteredVideos.assignAll([video]);
    controller.selectedVideo.value = video;
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
