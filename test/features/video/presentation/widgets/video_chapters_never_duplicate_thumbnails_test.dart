import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/widgets/video_chapters_bottom_sheet.dart';

import '../../../../test_helpers/mock_firebase.dart';

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
  });

  tearDown(Get.reset);

  group('Video Chapters Never Duplicate Thumbnails Regression Guard', () {
    final baseVideo = Video(
      id: 'test_video_123',
      title: 'Jio Platforms IPO: Hype vs. Reality',
      description: 'Comprehensive analysis of the Jio IPO and financial structure.',
      channelId: 'channel_123',
      channelName: 'TruthWorld Finance',
      ownerId: 'owner_123',
      category: 'Finance',
      tags: const ['jio', 'ipo', 'telecom'],
      thumbnailUrl: 'https://storage.googleapis.com/truthworld/videos/test_video_123/main_thumbnail.jpg',
      videoUrl: 'https://storage.googleapis.com/truthworld/videos/test_video_123/master.m3u8',
      duration: 300,
      createdAt: DateTime.now(),
      status: 'published',
    );

    testWidgets('Chapter 0 may show video cover, but subsequent chapters NEVER duplicate it when thumbnails are missing', (tester) async {
      final ch0 = VideoChapter(
        title: 'Jio Platforms IPO: Hype vs. Reality',
        startTime: Duration.zero,
      );
      final ch1 = VideoChapter(
        title: 'Mega IPO Details & Funding Structure',
        startTime: const Duration(seconds: 32),
      );
      final ch2 = VideoChapter(
        title: 'Business Beyond Connectivity: Telecom',
        startTime: const Duration(seconds: 95),
      );

      // ── Test Chapter 0 ──────────────────────────────────────────
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterTile(
              chapter: ch0,
              video: baseVideo,
              index: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      // Chapter 0 uses video cover as introductory card
      final ch0Images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(ch0Images.any((img) => img.imageUrl == baseVideo.thumbnailUrl), isTrue,
          reason: 'Chapter 0 is permitted to display main cover as introductory frame');

      // ── Test Chapter 1 (MUST NOT duplicate main cover) ──────────
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterTile(
              chapter: ch1,
              video: baseVideo,
              index: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      // Subsequent chapter MUST NEVER render baseVideo.thumbnailUrl!
      final ch1Images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(ch1Images.any((img) => img.imageUrl == baseVideo.thumbnailUrl), isFalse,
          reason: 'Chapter 1 MUST NEVER duplicate the main video cover!');

      // Instead, it must display the high-contrast informative chapter badge
      expect(find.text('Ch 2'), findsOneWidget);
      expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);

      // ── Test Chapter 2 (MUST NOT duplicate main cover) ──────────
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterTile(
              chapter: ch2,
              video: baseVideo,
              index: 2,
            ),
          ),
        ),
      );
      await tester.pump();

      final ch2Images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(ch2Images.any((img) => img.imageUrl == baseVideo.thumbnailUrl), isFalse,
          reason: 'Chapter 2 MUST NEVER duplicate the main video cover!');
      expect(find.text('Ch 3'), findsOneWidget);
    });

    testWidgets('Subsequent chapters strictly reject thumbnailUrl if identical to main video cover', (tester) async {
      // Simulate backend bug or stale cache where chapter was mistakenly populated with main cover URL
      final corruptedCh1 = VideoChapter(
        title: 'Financial Health & Debt Strategy',
        startTime: const Duration(seconds: 140),
        thumbnailUrl: baseVideo.thumbnailUrl, // Identical to video.thumbnailUrl!
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterTile(
              chapter: corruptedCh1,
              video: baseVideo,
              index: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(images.any((img) => img.imageUrl == baseVideo.thumbnailUrl), isFalse,
          reason: 'ChapterTile must strictly reject duplicate identical thumbnails on index > 0');
      expect(find.text('Ch 2'), findsOneWidget);
    });

    testWidgets('Renders discrete dedicated chapter thumbnail when authentic URL is provided', (tester) async {
      const discreteThumbnailUrl = 'https://firebasestorage.googleapis.com/v0/b/truthworld-1/o/thumbnails%2Ftest_video_123%2Fchapters%2Fchapter_1_32000.jpg?alt=media&token=tok_123';
      final authenticCh1 = VideoChapter(
        title: 'Valuation & Competitor Comparison',
        startTime: const Duration(seconds: 194),
        thumbnailUrl: discreteThumbnailUrl,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterTile(
              chapter: authenticCh1,
              video: baseVideo,
              index: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(images.any((img) => img.imageUrl == discreteThumbnailUrl), isTrue,
          reason: 'ChapterTile must render dedicated chapter thumbnail when present and distinct');
    });

    test('VideoChapterParser.resolveChapters enriches description chapters with AI extracted thumbnails', () {
      const description = '''
0:00 - Introduction & Overview
0:32 Mega IPO Details
1:35 Telecom & Cloud
2:20 Debt & Valuation
''';

      final aiGeneratedAutoChapters = [
        {
          'title': 'AI Segment 1',
          'startTimeMs': 0,
          'thumbnailUrl': 'https://storage/ch_0.jpg',
        },
        {
          'title': 'AI Segment 2',
          'startTimeMs': 32000,
          'thumbnailUrl': 'https://storage/ch_1_discrete.jpg',
        },
        {
          'title': 'AI Segment 3',
          'startTimeMs': 95000,
          'thumbnailUrl': 'https://storage/ch_2_discrete.jpg',
        },
        {
          'title': 'AI Segment 4',
          'startTimeMs': 140000,
          'thumbnailUrl': 'https://storage/ch_3_discrete.jpg',
        },
      ];

      final resolved = VideoChapterParser.resolveChapters(
        explicitChapters: null,
        description: description,
        rawAutoChapters: aiGeneratedAutoChapters,
        autoChaptersEnabled: true,
      );

      expect(resolved.length, 4);
      expect(resolved[0].title, 'Introduction & Overview');
      expect(resolved[0].thumbnailUrl, 'https://storage/ch_0.jpg');

      expect(resolved[1].title, 'Mega IPO Details');
      expect(resolved[1].thumbnailUrl, 'https://storage/ch_1_discrete.jpg');

      expect(resolved[2].title, 'Telecom & Cloud');
      expect(resolved[2].thumbnailUrl, 'https://storage/ch_2_discrete.jpg');

      expect(resolved[3].title, 'Debt & Valuation');
      expect(resolved[3].thumbnailUrl, 'https://storage/ch_3_discrete.jpg');
    });
  });
}
