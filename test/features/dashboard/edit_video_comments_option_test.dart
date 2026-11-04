import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_content_details_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    ChannelMemoryCache.clear();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(() {
    ChannelMemoryCache.clear();
    Get.reset();
  });

  Video createSampleVideo({
    required String id,
    bool enableComments = true,
  }) {
    return Video.empty().copyWith(
      id: id,
      title: 'Zomato Strategy Case Study',
      description: 'Zomato food delivery transformation',
      channelId: 'ch_zomato',
      channelName: 'Business Insights',
      ownerId: 'owner_123',
      enableComments: enableComments,
      allowComments: enableComments,
      visibility: 'public',
      createdAt: Timestamp.now(),
      uploadedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  group('EditVideo Comments Toggle Option Tests', () {
    test('1. Video model parses and serializes allowComments properly', () {
      final videoTrue = createSampleVideo(id: 'v1');
      expect(videoTrue.allowComments, isTrue);
      expect(videoTrue.enableComments, isTrue);

      final videoFalse = videoTrue.copyWith(allowComments: false);
      expect(videoFalse.allowComments, isFalse);
      expect(videoFalse.enableComments, isFalse);

      final map = videoFalse.toMap();
      expect(map['allowComments'], isFalse);
      expect(map['enableComments'], isFalse);

      final parsed = Video.fromMap(map, 'v1');
      expect(parsed.allowComments, isFalse);
      expect(parsed.enableComments, isFalse);
    });

    test('2. EditVideoController initializes allowComments from video', () {
      final video = createSampleVideo(id: 'v2');
      final controller = EditVideoController(video: video);
      controller.onInit();

      expect(controller.allowComments.value, isTrue);
      expect(controller.enableComments.value, isTrue);

      controller.allowComments.value = false;
      expect(controller.allowComments.value, isFalse);
      expect(controller.enableComments.value, isFalse);
    });

    test('3. EditVideoController initializes with false when comments are disabled', () {
      final video = createSampleVideo(id: 'v3', enableComments: false);
      final controller = EditVideoController(video: video);
      controller.onInit();

      expect(controller.allowComments.value, isFalse);
      expect(controller.enableComments.value, isFalse);
    });

    testWidgets('4. EditVideoScreen renders "Allow comments for the video" switch list tile', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final video = createSampleVideo(id: 'v4');
      final vmController = Get.put(VideoManagementController());
      vmController.channelVideos.assignAll([video]);

      await tester.pumpWidget(
        GetMaterialApp(
          home: EditVideoScreen(video: video),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the new comments toggle is rendered with title & subtitle
      expect(find.text('Allow comments for the video'), findsOneWidget);
      expect(find.text('Turn comments on or off for this video'), findsOneWidget);

      // Verify existing switch options are also present
      expect(find.text('Is this video "Made for Kids"?'), findsOneWidget);
      expect(find.text('Show Like Count'), findsOneWidget);
      expect(find.text('Show Dislike Count'), findsOneWidget);
      expect(find.text('Allow automatic chapters'), findsOneWidget);

      // Verify the comments switch tile is active
      final switchFinder = find.widgetWithText(SwitchListTile, 'Allow comments for the video');
      expect(switchFinder, findsOneWidget);
      final switchTile = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isTrue);

      // Toggle off comments
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final updatedTile = tester.widget<SwitchListTile>(switchFinder);
      expect(updatedTile.value, isFalse);
    });

    testWidgets('5. VideoContentDetailsScreen shows Community Comments and navigates to EditVideoScreen', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final video = createSampleVideo(id: 'v5');
      final vmController = Get.put(VideoManagementController());
      vmController.channelVideos.assignAll([video]);

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoContentDetailsScreen(
            video: video,
            isDarkMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the technical details card to view Community Comments
      final expansionTileFinder = find.text('Complete Video Details (A - Z Technical Inventory)');
      await tester.scrollUntilVisible(expansionTileFinder, 300);
      await tester.pumpAndSettle();
      await tester.tap(expansionTileFinder);
      await tester.pumpAndSettle();

      final commentsFinder = find.text('Community Comments');
      await tester.scrollUntilVisible(commentsFinder, 300);
      await tester.pumpAndSettle();

      // Technical Details Card shows Community Comments
      expect(commentsFinder, findsOneWidget);
      expect(find.text('Enabled (Open Discussion)'), findsOneWidget);

      // Edit button is present in the action row
      final editBtn = find.widgetWithText(OutlinedButton, 'Edit');
      await tester.scrollUntilVisible(editBtn, -300);
      await tester.pumpAndSettle();
      expect(editBtn, findsOneWidget);

      // Tap Edit
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Opens EditVideoScreen with the comments option
      expect(find.text('Edit Video'), findsOneWidget);
      expect(find.text('Allow comments for the video'), findsOneWidget);
    });
  });
}
