import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('Video Channel Visibility & Not Interested Tests', () {
    late Video testVideo;
    late UserPreferencesService userPrefs;

    setUp(() {
      Get.reset();
      userPrefs = Get.put(UserPreferencesService(), permanent: true);
      userPrefs.hiddenVideoIds.clear();
      userPrefs.blockedChannelIds.clear();
      userPrefs.blockedChannelNames.clear();

      testVideo = Video(
        id: 'test_vid_123',
        title: 'Our First Video Production',
        description: 'Welcome to Truthworld',
        ownerId: 'test_creator_uid_456',
        channelId: 'test_channel_id_789',
        channelName: 'Truthworld Channel',
        category: 'General',
        tags: const [],
        channelAvatarUrl: 'https://example.com/avatar.png',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        videoUrl: 'https://example.com/video.mp4',
        duration: '10:00',
        views: 120,
        likes: 10,
        status: VideoStatus.ready,
        visibility: 'Public',
        uploadedAt: Timestamp.now(),
        createdAt: Timestamp.now(),
      );
    });

    tearDown(Get.reset);

    testWidgets('VideoCard is hidden in feed context when isVideoBlocked is true', (tester) async {
      userPrefs.hiddenVideoIds.add(testVideo.id);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: testVideo,
              disableHoverPreview: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In feed context with video hidden, it should collapse to SizedBox.shrink()
      expect(find.text('Our First Video Production'), findsNothing);
    });

    testWidgets('VideoCard remains VISIBLE in channel/subscriptions context even if marked not interested in feed', (tester) async {
      userPrefs.hiddenVideoIds.add(testVideo.id);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: testVideo,
              isChannelContext: true,
              disableHoverPreview: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In channel or subscriptions context (isChannelContext: true), the video is never collapsed
      expect(find.text('Our First Video Production'), findsOneWidget);
    });

    testWidgets('VideoOptionsSheet in feed context shows "Not interested" and "Don\'t recommend channel"', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VideoOptionsSheet.show(
                  context,
                  testVideo,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Not interested'), findsOneWidget);
      expect(find.text("Don't recommend channel"), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('VideoOptionsSheet in channel context shows "Restore video recommendation" when hidden', (tester) async {
      userPrefs.hiddenVideoIds.add(testVideo.id);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VideoOptionsSheet.show(
                  context,
                  testVideo,
                  isChannelContext: true,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Not interested'), findsNothing);
      expect(find.text("Don't recommend channel"), findsNothing);
      expect(find.text('Restore video recommendation'), findsOneWidget);
    });

    testWidgets('VideoOptionsSheet in channel context shows "Turn on recommendations from this channel" when channel blocked', (tester) async {
      userPrefs.blockedChannelIds.add(testVideo.channelId);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VideoOptionsSheet.show(
                  context,
                  testVideo,
                  isChannelContext: true,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Not interested'), findsNothing);
      expect(find.text("Don't recommend channel"), findsNothing);
      expect(find.text('Turn on recommendations from this channel'), findsOneWidget);
    });
  });
}
