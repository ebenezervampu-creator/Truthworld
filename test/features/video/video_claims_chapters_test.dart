import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/storyboard_thumbnail_widget.dart';
import 'package:truthworld/features/video/presentation/widgets/video_claims_bottom_sheet.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    VideoMediaService().clearAllCaches();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('AI Credibility Claims Chapters Tests', () {
    test('ClaimResult timestamp duration and formatted string calculations', () {
      final claim1 = ClaimResult(
        text: 'The moon landing was in 1969',
        verdict: 'verified',
        start: 75.0, // 01:15
      );

      final claim2 = ClaimResult(
        text: 'The moon is made of cheese',
        verdict: 'false',
        start: 145.5, // 02:25
      );

      expect(claim1.startDuration.inSeconds, 75);
      expect(claim1.formattedStartTime, '01:15');

      expect(claim2.startDuration.inSeconds, 145);
      expect(claim2.formattedStartTime, '02:25');
    });

    test('ClaimResult chronological sorting for Chapter mode', () {
      final claimA = ClaimResult(text: 'Claim at 3 mins', verdict: 'verified', start: 180.0);
      final claimB = ClaimResult(text: 'Claim at 15 secs', verdict: 'false', start: 15.0);
      final claimC = ClaimResult(text: 'Claim at 1 min', verdict: 'caution', start: 60.0);

      final list = [claimA, claimB, claimC];
      list.sort((a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0));

      expect(list[0].text, 'Claim at 15 secs');
      expect(list[1].text, 'Claim at 1 min');
      expect(list[2].text, 'Claim at 3 mins');
    });

    testWidgets('ClaimChapterTile renders statement, verdict pill, and timestamp',
        (tester) async {
      final testVideo = Video(
        id: 'test_vid_1',
        title: 'Test Video',
        description: 'Test description',
        videoUrl: 'https://example.com/test.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        duration: 300,
        ownerId: 'owner_1',
        channelId: 'chan_1',
        channelName: 'Channel One',
        category: 'Education',
        tags: const ['news'],
        createdAt: DateTime.now(),
      );

      final claim = ClaimResult(
        text: 'Autonomous EV adoption increased by 40%',
        verdict: 'verified',
        start: 45.0,
        classificationConfidence: 0.95,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ClaimChapterTile(
              claim: claim,
              video: testVideo,
            ),
          ),
        ),
      );

      expect(find.text('Autonomous EV adoption increased by 40%'), findsOneWidget);
      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('95% AI Conf.'), findsOneWidget);
    });

    test('ClaimResult serializes and deserializes dedicated thumbnailUrl', () {
      final claimFromMap = ClaimResult.fromMap({
        'text': 'Solar energy is growing',
        'verdict': 'verified',
        'start': 120.0,
        'thumbnailUrl': 'https://example.com/solar_claim_thumb.jpg',
      });

      expect(claimFromMap.thumbnailUrl, 'https://example.com/solar_claim_thumb.jpg');
      final mapped = claimFromMap.toMap();
      expect(mapped['thumbnailUrl'], 'https://example.com/solar_claim_thumb.jpg');

      // Test alternative key fallback in map
      final claimFromAltKey = ClaimResult.fromMap({
        'text': 'Wind energy expansion',
        'verdict': 'verified',
        'start': 60.0,
        'frameUrl': 'https://example.com/frame_60.jpg',
      });
      expect(claimFromAltKey.thumbnailUrl, 'https://example.com/frame_60.jpg');
    });

    testWidgets('ClaimChapterTile renders dedicated claim thumbnailUrl when present',
        (tester) async {
      final testVideo = Video(
        id: 'test_vid_dedicated',
        title: 'Test Video',
        description: 'Test description',
        videoUrl: 'https://example.com/test.mp4',
        thumbnailUrl: 'https://example.com/cover.jpg',
        duration: 300,
        ownerId: 'owner_1',
        channelId: 'chan_1',
        channelName: 'Channel One',
        category: 'Education',
        tags: const ['news'],
        createdAt: DateTime.now(),
      );

      final claimWithThumb = ClaimResult(
        text: 'Autonomous EV adoption increased by 40%',
        verdict: 'verified',
        start: 45.0,
        thumbnailUrl: 'https://example.com/dedicated_claim_thumb.jpg',
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ClaimChapterTile(
              claim: claimWithThumb,
              video: testVideo,
            ),
          ),
        ),
      );

      final cachedImages = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      final hasDedicatedImage = cachedImages.any(
        (img) => img.imageUrl == 'https://example.com/dedicated_claim_thumb.jpg',
      );
      expect(hasDedicatedImage, isTrue);
    });

    testWidgets('ClaimChapterTile resolves matching VideoChapter thumbnail when available',
        (tester) async {
      final testVideo = Video(
        id: 'test_vid_chapter',
        title: 'Test Video',
        description: 'Test description',
        videoUrl: 'https://example.com/test.mp4',
        thumbnailUrl: 'https://example.com/cover.jpg',
        duration: 300,
        ownerId: 'owner_1',
        channelId: 'chan_1',
        channelName: 'Channel One',
        category: 'Education',
        tags: const ['news'],
        createdAt: DateTime.now(),
        chapters: [
          VideoChapter(
            title: 'Intro',
            startTime: Duration.zero,
            thumbnailUrl: 'https://example.com/chapter_intro.jpg',
          ),
          VideoChapter(
            title: 'EV Market Growth',
            startTime: const Duration(seconds: 40),
            thumbnailUrl: 'https://example.com/chapter_ev_growth.jpg',
          ),
        ],
      );

      // Claim at 45 seconds falls into Chapter 2 (EV Market Growth at 40s)
      final claim = ClaimResult(
        text: 'Autonomous EV adoption increased by 40%',
        verdict: 'verified',
        start: 45.0,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ClaimChapterTile(
              claim: claim,
              video: testVideo,
            ),
          ),
        ),
      );

      final cachedImages = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      final hasMatchedChapterImage = cachedImages.any(
        (img) => img.imageUrl == 'https://example.com/chapter_ev_growth.jpg',
      );
      expect(hasMatchedChapterImage, isTrue);
    });

    testWidgets('ClaimChapterTile renders StoryboardThumbnailWidget when storyboard track is present',
        (tester) async {
      final testVideo = Video(
        id: 'test_vid_storyboard',
        title: 'Test Video',
        description: 'Test description',
        videoUrl: 'https://example.com/test.mp4',
        thumbnailUrl: 'https://example.com/cover.jpg',
        duration: 300,
        ownerId: 'owner_1',
        channelId: 'chan_1',
        channelName: 'Channel One',
        category: 'Education',
        tags: const ['news'],
        createdAt: DateTime.now(),
        storyboardUrl: 'https://example.com/storyboard.vtt',
      );

      final claim = ClaimResult(
        text: 'Autonomous EV adoption increased by 40%',
        verdict: 'verified',
        start: 45.0,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ClaimChapterTile(
              claim: claim,
              video: testVideo,
            ),
          ),
        ),
      );

      expect(find.byType(StoryboardThumbnailWidget), findsOneWidget);
      final storyboardWidget = tester.widget<StoryboardThumbnailWidget>(
        find.byType(StoryboardThumbnailWidget),
      );
      expect(storyboardWidget.position, const Duration(seconds: 45));
    });

    testWidgets('ClaimChapterTile falls back to video.thumbnailUrl when no dedicated frame is available',
        (tester) async {
      final testVideo = Video(
        id: 'test_vid_fallback_only',
        title: 'Test Video',
        description: 'Test description',
        videoUrl: 'https://example.com/test.mp4',
        thumbnailUrl: 'https://example.com/cover.jpg',
        duration: 300,
        ownerId: 'owner_1',
        channelId: 'chan_1',
        channelName: 'Channel One',
        category: 'Education',
        tags: const ['news'],
        createdAt: DateTime.now(),
      );

      final claim = ClaimResult(
        text: 'General statement',
        verdict: 'verified',
        start: 45.0,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ClaimChapterTile(
              claim: claim,
              video: testVideo,
            ),
          ),
        ),
      );

      final cachedImages = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      final hasCoverFallback = cachedImages.any(
        (img) => img.imageUrl == 'https://example.com/cover.jpg',
      );
      expect(hasCoverFallback, isTrue);
    });
  });
}
