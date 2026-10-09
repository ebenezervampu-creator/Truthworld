import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('VideoChapterParser Unit Tests', () {
    test('extracts valid YouTube description timestamps correctly', () {
      const description = '''
Check out our latest investigative report!

Timestamps:
0:00 - Introduction & Overview
01:30 Fact Check Methodology
04:15 Source Verification
12:00 Expert Conclusion
''';

      final chapters = VideoChapterParser.extractDescriptionChapters(
        description,
      );

      expect(chapters.length, 4);
      expect(chapters[0].title, 'Introduction & Overview');
      expect(chapters[0].startTime, Duration.zero);
      expect(chapters[1].title, 'Fact Check Methodology');
      expect(chapters[1].startTime, const Duration(minutes: 1, seconds: 30));
      expect(chapters[2].title, 'Source Verification');
      expect(chapters[2].startTime, const Duration(minutes: 4, seconds: 15));
      expect(chapters[3].title, 'Expert Conclusion');
      expect(chapters[3].startTime, const Duration(minutes: 12));
    });

    test('rejects description if first timestamp does not start at 0:00', () {
      const description = '''
01:00 Background
03:00 Investigation
05:00 Verdict
''';

      final chapters = VideoChapterParser.extractDescriptionChapters(
        description,
      );
      expect(chapters, isEmpty);
    });

    test('rejects description if fewer than 3 timestamps are provided', () {
      const description = '''
0:00 Opening
02:00 Ending
''';

      final chapters = VideoChapterParser.extractDescriptionChapters(
        description,
      );
      expect(chapters, isEmpty);
    });

    test('rejects description if any chapter is shorter than 10 seconds', () {
      const description = '''
0:00 Intro
0:05 Too Short
02:00 Main Section
''';

      final chapters = VideoChapterParser.extractDescriptionChapters(
        description,
      );
      expect(chapters, isEmpty);
    });

    test('handles hours, minutes, and seconds formatted timestamps', () {
      const description = '''
00:00:00 Opening
01:15:30 Long Form Deep Dive
02:00:00 Wrap Up
''';

      final chapters = VideoChapterParser.extractDescriptionChapters(
        description,
      );
      expect(chapters.length, 3);
      expect(chapters[0].startTime, Duration.zero);
      expect(
        chapters[1].startTime,
        const Duration(hours: 1, minutes: 15, seconds: 30),
      );
      expect(chapters[2].startTime, const Duration(hours: 2));
    });
  });

  group('YouTube Chapter Resolution & Auto-Chapters Override Tests', () {
    const validDescription = '''
0:00 Intro
01:00 Middle
02:00 Outro
''';

    final dummyAutoChapters = [
      {'title': 'AI Segment 1', 'startMs': 0},
      {'title': 'AI Segment 2', 'startMs': 60000},
    ];

    test(
      'Manual description chapters override auto-chapters when auto-chapters is ON',
      () {
        final chapters = VideoChapterParser.resolveChapters(
          explicitChapters: null,
          description: validDescription,
          rawAutoChapters: dummyAutoChapters,
          autoChaptersEnabled: true,
        );

        expect(chapters.length, 3);
        expect(chapters[0].title, 'Intro');
        expect(chapters[1].title, 'Middle');
        expect(chapters[2].title, 'Outro');
      },
    );

    test(
      'Manual description chapters still show when channel turns OFF auto-chapters',
      () {
        final chapters = VideoChapterParser.resolveChapters(
          explicitChapters: null,
          description: validDescription,
          rawAutoChapters: dummyAutoChapters,
          autoChaptersEnabled: false,
        );

        // Manual chapters must still be returned!
        expect(chapters.length, 3);
        expect(chapters[0].title, 'Intro');
      },
    );

    test(
      'Auto-chapters are SUPPRESSED when channel turns OFF auto-chapters and no manual chapters exist',
      () {
        final chapters = VideoChapterParser.resolveChapters(
          explicitChapters: null,
          description: 'Just a normal description with no timestamps.',
          rawAutoChapters: dummyAutoChapters,
          autoChaptersEnabled: false,
        );

        // Must be empty because auto-chapters was turned off and no manual chapters provided
        expect(chapters, isEmpty);
      },
    );

    test(
      'Auto-chapters are used as fallback when auto-chapters is ON and no manual chapters exist',
      () {
        final chapters = VideoChapterParser.resolveChapters(
          explicitChapters: null,
          description: 'Description without timestamps.',
          rawAutoChapters: dummyAutoChapters,
          autoChaptersEnabled: true,
        );

        expect(chapters.length, 2);
        expect(chapters[0].title, 'AI Segment 1');
        expect(chapters[1].title, 'AI Segment 2');
      },
    );

    test(
      'Explicit chapters take top priority over description and auto-chapters',
      () {
        final explicit = [
          {'title': 'Custom Milestone', 'startTimeMs': 0},
        ];

        final chapters = VideoChapterParser.resolveChapters(
          explicitChapters: explicit,
          description: validDescription,
          rawAutoChapters: dummyAutoChapters,
          autoChaptersEnabled: true,
        );

        expect(chapters.length, 1);
        expect(chapters[0].title, 'Custom Milestone');
      },
    );
  });

  group(
    'VideoMapParser Integration Tests for Auto-Chapters and Description Upload',
    () {
      test('parses manual description timestamps on Video.fromMap', () {
        final video = Video.fromMap({
          'id': 'vid_desc_test',
          'title': 'Test Video',
          'videoUrl': 'https://example.com/v.mp4',
          'description': '''
00:00 Welcome
02:00 In Depth Discussion
05:30 Final Thoughts
''',
          'autoChapters': [
            {'title': 'AI Segment', 'startMs': 0},
          ],
          'autoChaptersEnabled': true,
        });

        expect(video.chapters.length, 3);
        expect(video.chapters[0].title, 'Welcome');
        expect(video.chapters[1].title, 'In Depth Discussion');
        expect(video.chapters[2].title, 'Final Thoughts');
      });

      test(
        'suppresses AI auto-chapters when autoChaptersEnabled is false in Firestore map',
        () {
          final video = Video.fromMap({
            'id': 'vid_suppress_test',
            'title': 'Auto Off Video',
            'videoUrl': 'https://example.com/v.mp4',
            'description': 'No timestamps here.',
            'autoChapters': [
              {'title': 'Should Be Hidden', 'startMs': 0},
              {'title': 'Hidden 2', 'startMs': 60000},
            ],
            'autoChaptersEnabled': false,
          });

          expect(video.autoChaptersEnabled, isFalse);
          expect(video.chapters, isEmpty);
        },
      );

      test(
        'displays manual description chapters even when autoChaptersEnabled is false',
        () {
          final video = Video.fromMap({
            'id': 'vid_manual_when_off_test',
            'title': 'Manual Chapters with Auto Off',
            'videoUrl': 'https://example.com/v.mp4',
            'description': '''
0:00 Opening
01:10 Core Concept
02:40 Conclusion
''',
            'autoChapters': [
              {'title': 'AI Should Be Overridden', 'startMs': 0},
            ],
            'autoChaptersEnabled': false,
          });

          expect(video.autoChaptersEnabled, isFalse);
          expect(video.chapters.length, 3);
          expect(video.chapters[0].title, 'Opening');
          expect(video.chapters[1].title, 'Core Concept');
        },
      );

      test(
        'extractDescriptionChapters filters out chapters exceeding maxDuration',
        () {
          const desc = '''
0:00 Intro
02:00 Discussion
04:00 Key Takeaways
06:30 Out of bounds
''';
          final chapters = VideoChapterParser.extractDescriptionChapters(
            desc,
            maxDuration: const Duration(minutes: 5, seconds: 30),
          );
          expect(chapters.length, 3);
          expect(chapters.last.title, 'Key Takeaways');
        },
      );

      test(
        'Video.fromMap excludes explicit chapters exceeding video duration',
        () {
          final video = Video.fromMap({
            'id': 'vid_short_chapters_test',
            'title': 'Video Under 6 Minutes',
            'videoUrl': 'https://example.com/v.mp4',
            'duration': '05:30',
            'durationMs': (5 * 60 + 30) * 1000,
            'chapters': [
              {'title': 'Intro', 'startTime': 0},
              {'title': 'Deep Dive', 'startTime': 120},
              {'title': 'Beyond End', 'startTime': 400}, // 400s = 6m40s > 5m30s
            ],
          });

          expect(video.chapters.length, 2);
          expect(video.chapters[0].title, 'Intro');
          expect(video.chapters[1].title, 'Deep Dive');
        },
      );
    },
  );
}
