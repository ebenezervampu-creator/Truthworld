import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/services/storyboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoryboardService WebVTT Parsing Tests', () {
    const vttSample = '''
WEBVTT

00:00:00.000 --> 00:00:02.000
thumbnails_0.jpg#xywh=0,0,160,90

00:00:02.000 --> 00:00:04.000
thumbnails_0.jpg#xywh=160,0,160,90

00:00:04.000 --> 00:00:06.000
thumbnails_0.jpg#xywh=320,0,160,90

00:00:06.000 --> 00:00:08.000
thumbnails_1.jpg#xywh=0,90,160,90
''';

    test('parses WebVTT sprite coordinates and timestamps accurately', () {
      final track = StoryboardService.parseWebVtt(
        vttSample,
        baseUrl: 'https://cdn.truthworld.com/storyboards/',
      );

      expect(track.length, 4);

      // Cue 0
      final cue0 = track.cues[0];
      expect(cue0.start, Duration.zero);
      expect(cue0.end, const Duration(seconds: 2));
      expect(cue0.imageUrl, 'https://cdn.truthworld.com/storyboards/thumbnails_0.jpg');
      expect(cue0.cropRect, const Rect.fromLTWH(0, 0, 160, 90));

      // Cue 1
      final cue1 = track.cues[1];
      expect(cue1.start, const Duration(seconds: 2));
      expect(cue1.end, const Duration(seconds: 4));
      expect(cue1.cropRect, const Rect.fromLTWH(160, 0, 160, 90));

      // Cue 3 (different image, y-offset)
      final cue3 = track.cues[3];
      expect(cue3.start, const Duration(seconds: 6));
      expect(cue3.end, const Duration(seconds: 8));
      expect(cue3.imageUrl, 'https://cdn.truthworld.com/storyboards/thumbnails_1.jpg');
      expect(cue3.cropRect, const Rect.fromLTWH(0, 90, 160, 90));
    });

    test('getCueAt performs precise binary search retrieval', () {
      final track = StoryboardService.parseWebVtt(vttSample);

      // Position in middle of cue 1
      final cue = track.getCueAt(const Duration(milliseconds: 3200));
      expect(cue, isNotNull);
      expect(cue!.start, const Duration(seconds: 2));
      expect(cue.end, const Duration(seconds: 4));

      // Position before start -> returns first cue
      final beforeCue = track.getCueAt(Duration.zero);
      expect(beforeCue!.start, Duration.zero);

      // Position beyond end -> returns last cue
      final afterCue = track.getCueAt(const Duration(seconds: 100));
      expect(afterCue!.start, const Duration(seconds: 6));
    });
  });

  group('StoryboardService fromThumbnailVariants Tests', () {
    test('equidistantly distributes thumbnail variants across duration', () {
      final variants = [
        'https://cdn.example.com/thumb_1.jpg',
        'https://cdn.example.com/thumb_2.jpg',
        'https://cdn.example.com/thumb_3.jpg',
        'https://cdn.example.com/thumb_4.jpg',
      ];
      const duration = Duration(seconds: 40);

      final track = StoryboardService.fromThumbnailVariants(variants, duration);
      expect(track.length, 4);

      // Each slot is 10 seconds
      expect(track.cues[0].start, Duration.zero);
      expect(track.cues[0].end, const Duration(seconds: 10));
      expect(track.cues[0].imageUrl, variants[0]);
      expect(track.cues[0].cropRect, isNull);

      expect(track.cues[2].start, const Duration(seconds: 20));
      expect(track.cues[2].end, const Duration(seconds: 30));
      expect(track.cues[2].imageUrl, variants[2]);

      // Lookup test
      final cue = track.getCueAt(const Duration(seconds: 25));
      expect(cue!.imageUrl, variants[2]);
    });

    test('returns empty track on empty variants or zero duration', () {
      final empty1 = StoryboardService.fromThumbnailVariants([], const Duration(seconds: 30));
      expect(empty1.isEmpty, isTrue);

      final empty2 = StoryboardService.fromThumbnailVariants(['url'], Duration.zero);
      expect(empty2.isEmpty, isTrue);
    });
  });

  group('StoryboardService fromGrid Tests', () {
    test('generates accurate sprite sheet coordinates for M×N grid', () {
      final track = StoryboardService.fromGrid(
        spriteUrl: 'https://cdn.example.com/grid.jpg',
        columns: 5,
        rows: 4,
        frameWidth: 160,
        frameHeight: 90,
        totalDuration: const Duration(seconds: 40),
        interval: const Duration(seconds: 2),
      );

      // 5 cols * 4 rows = 20 frames; each 2s -> 40s total
      expect(track.length, 20);

      // Cell (0, 0): col 0, row 0
      expect(track.cues[0].cropRect, const Rect.fromLTWH(0, 0, 160, 90));

      // Cell 6: col 1, row 1 (6 % 5 = 1, 6 ~/ 5 = 1) -> x=160, y=90
      expect(track.cues[6].cropRect, const Rect.fromLTWH(160, 90, 160, 90));
      expect(track.cues[6].start, const Duration(seconds: 12));
      expect(track.cues[6].end, const Duration(seconds: 14));
    });
  });

  group('StoryboardService fromMultiSheetGrid Tests', () {
    test('generates 1-second density cues across multiple sheets for long-form content', () {
      final sheets = [
        'https://cdn.truthworld.com/storyboards/sheet_000.jpg',
        'https://cdn.truthworld.com/storyboards/sheet_001.jpg',
        'https://cdn.truthworld.com/storyboards/sheet_002.jpg',
      ];
      // 3 sheets * 100 frames = 300 seconds (5 minutes)
      const duration = Duration(seconds: 250);

      final track = StoryboardService.fromMultiSheetGrid(
        spriteUrls: sheets,
        columns: 10,
        rows: 10,
        frameWidth: 160,
        frameHeight: 90,
        totalDuration: duration,
      );

      // Should stop at totalDuration (250 cues)
      expect(track.length, 250);

      // Frame 0 on sheet 0
      final cue0 = track.cues[0];
      expect(cue0.imageUrl, sheets[0]);
      expect(cue0.start, Duration.zero);
      expect(cue0.end, const Duration(seconds: 1));
      expect(cue0.cropRect, const Rect.fromLTWH(0, 0, 160, 90));

      // Frame 99 on sheet 0 (last frame of first sheet)
      final cue99 = track.cues[99];
      expect(cue99.imageUrl, sheets[0]);
      expect(cue99.start, const Duration(seconds: 99));
      expect(cue99.end, const Duration(seconds: 100));
      expect(cue99.cropRect, const Rect.fromLTWH(9 * 160, 9 * 90, 160, 90));

      // Frame 100 on sheet 1 (first frame of second sheet)
      final cue100 = track.cues[100];
      expect(cue100.imageUrl, sheets[1]);
      expect(cue100.start, const Duration(seconds: 100));
      expect(cue100.end, const Duration(seconds: 101));
      expect(cue100.cropRect, const Rect.fromLTWH(0, 0, 160, 90));

      // Frame 200 on sheet 2
      final cue200 = track.cues[200];
      expect(cue200.imageUrl, sheets[2]);
      expect(cue200.start, const Duration(seconds: 200));

      // Last frame (249) capped to duration (250s)
      final cue249 = track.cues[249];
      expect(cue249.end, const Duration(seconds: 250));
    });

    test('handles multi-hour simulation (2 hours = 7200 cues) without error', () {
      final sheets = List.generate(72, (i) => 'https://cdn.truthworld.com/storyboards/sheet_${i.toString().padLeft(3, '0')}.jpg');
      const duration = Duration(hours: 2);

      final track = StoryboardService.fromMultiSheetGrid(
        spriteUrls: sheets,
        columns: 10,
        rows: 10,
        frameWidth: 160,
        frameHeight: 90,
        totalDuration: duration,
      );

      expect(track.length, 7200);

      // Random access at 1 hour, 23 minutes, 45 seconds (5025 seconds)
      final cue = track.getCueAt(const Duration(seconds: 5025));
      expect(cue, isNotNull);
      expect(cue!.start, const Duration(seconds: 5025));
      expect(cue.end, const Duration(seconds: 5026));
      // 5025 ~/ 100 = sheet 50
      expect(cue.imageUrl, 'https://cdn.truthworld.com/storyboards/sheet_050.jpg');
    });

    test('returns empty track on invalid parameters', () {
      final empty = StoryboardService.fromMultiSheetGrid(
        spriteUrls: [],
        columns: 10,
        rows: 10,
        frameWidth: 160,
        frameHeight: 90,
        totalDuration: const Duration(minutes: 10),
      );
      expect(empty.isEmpty, isTrue);
    });
  });

  group('StoryboardService generateHighDensityTrack Tests', () {
    test('interpolates thumbnail variants into continuous 1-second cues', () {
      final variants = [
        'https://cdn.example.com/thumb_1.jpg',
        'https://cdn.example.com/thumb_2.jpg',
        'https://cdn.example.com/thumb_3.jpg',
        'https://cdn.example.com/thumb_4.jpg',
      ];
      const duration = Duration(seconds: 20);

      final track = StoryboardService.generateHighDensityTrack(
        totalDuration: duration,
        thumbnailVariants: variants,
      );

      expect(track.length, 20);
      expect(track.cues[0].start, Duration.zero);
      expect(track.cues[0].end, const Duration(seconds: 1));
      expect(track.cues[0].imageUrl, variants[0]);

      // Lookups at any second return a cue without dead zones
      final cue15 = track.getCueAt(const Duration(seconds: 15));
      expect(cue15, isNotNull);
      expect(cue15!.imageUrl, variants[3]);
    });

    test('prioritizes multiSheetUrls over singleSheetUrl and thumbnailVariants', () {
      final track = StoryboardService.generateHighDensityTrack(
        totalDuration: const Duration(seconds: 100),
        multiSheetUrls: ['https://cdn.truthworld.com/sheet_0.jpg'],
        singleSheetUrl: 'https://cdn.truthworld.com/single.jpg',
        thumbnailVariants: ['https://cdn.truthworld.com/variant.jpg'],
      );

      expect(track.cues[0].imageUrl, 'https://cdn.truthworld.com/sheet_0.jpg');
    });
  });

  group('StoryboardTrack getImageUrlsAround Tests', () {
    test('returns distinct URLs within time window around scrub position', () {
      final sheets = [
        'https://cdn.truthworld.com/sheet_0.jpg',
        'https://cdn.truthworld.com/sheet_1.jpg',
        'https://cdn.truthworld.com/sheet_2.jpg',
      ];
      final track = StoryboardService.fromMultiSheetGrid(
        spriteUrls: sheets,
        columns: 10,
        rows: 10,
        frameWidth: 160,
        frameHeight: 90,
        totalDuration: const Duration(seconds: 300),
      );

      // At position 95s with 10s window (85s..105s): crosses boundary between sheet 0 and sheet 1
      final urls = track.getImageUrlsAround(
        const Duration(seconds: 95),
        window: const Duration(seconds: 10),
      );

      expect(urls.length, 2);
      expect(urls.contains(sheets[0]), isTrue);
      expect(urls.contains(sheets[1]), isTrue);
      expect(urls.contains(sheets[2]), isFalse);
    });
  });
}
