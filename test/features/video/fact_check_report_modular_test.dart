import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_report_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testVideo = Video(
    id: 'test_video_123',
    ownerId: 'owner_123',
    title: 'Fact Check Test Video',
    description: 'Video used for verifying FactCheckReportWidget',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    channelId: 'channel_123',
    channelName: 'Truth Channel',
    channelAvatarUrl: '',
    duration: 300,
    viewCount: 1500,
    likeCount: 120,
    dislikeCount: 5,
    commentCount: 30,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    tags: const ['news', 'factcheck'],
    category: 'News',
    visibility: 'public',
  );

  final testData = <String, dynamic>{
    'trustScore': 85.0,
    'truthScore': 90.0,
    'confidence': 0.92,
    'factCheckStats': {
      'totalClaims': 5,
      'correct': 4,
    },
    'uiReport': {
      'narrative': 'This video was verified across authoritative academic and scientific repositories.',
      'conclusion': 'The video exhibits high integrity with multi-sourced evidence.',
      'sources': [
        {
          'sourceType': 'book',
          'author': 'Dr. Carl Sagan',
          'bookTitle': 'The Demon-Haunted World',
          'chapter': 'Chapter 12',
          'pageNumbers': 'pp. 200-215',
          'yearPublished': 1995,
          'trustLevel': 'High',
          'snippet': 'Science is more than a body of knowledge; it is a way of thinking.',
        },
        {
          'sourceType': 'journal',
          'author': 'Nature Editorial',
          'journalName': 'Nature Science',
          'volume': 'Vol. 450',
          'pageNumbers': 'pp. 12-18',
          'yearPublished': 2021,
          'trustLevel': 'High',
          'url': 'https://nature.com/articles/12345',
        },
        {
          'sourceType': 'website',
          'title': 'World Health Organization',
          'domain': 'who.int',
          'trustLevel': 'Medium',
          'directUrl': 'https://who.int/report',
        },
      ],
    },
    'claims': [
      {
        'claim': 'Global temperatures have risen steadily over the last century.',
        'verdict': 'verified',
        'confidence': 0.95,
        'explanation': 'Confirmed by meteorological datasets from NASA and NOAA.',
      },
      {
        'claim': 'Vaccines cause widespread magnetic interference.',
        'verdict': 'false',
        'confidence': 0.99,
        'explanation': 'Debunked by global health organizations and clinical trials.',
      },
    ],
    'diagnostics': [
      'Multi-engine synthesis latency: 420ms',
      'Cross-lingual alignment checked for EN/ES/FR',
    ],
  };

  tearDown(Get.reset);

  group('FactCheckReportWidget Modular Tests', () {
    testWidgets('renders full disclosure sheet with all sections', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FactCheckReportWidget(
              data: testData,
              video: testVideo,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      // Verify header
      expect(find.text('AI FULL DISCLOSURE'), findsOneWidget);
      expect(find.text('CRYPTO-VERIFIED ANALYSIS'), findsOneWidget);

      // Verify subjective pseudo-metrics are removed
      expect(find.text('TRUTH'), findsNothing);
      expect(find.text('HONESTY'), findsNothing);
      expect(find.text('LOGIC'), findsNothing);

      // Verify confidence bar
      expect(find.text('ANALYSIS CONFIDENCE'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);

      // Verify stats
      expect(find.text('Total Claims'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // Verify narrative
      expect(find.text('SUMMARY ANALYSIS'), findsOneWidget);
      expect(
        find.text('This video was verified across authoritative academic and scientific repositories.'),
        findsOneWidget,
      );

      // Verify claims
      expect(find.text('CLAIM VERIFICATION'), findsOneWidget);
      expect(find.text('Provide Evidence'), findsOneWidget);
      expect(
        find.text('Global temperatures have risen steadily over the last century.'),
        findsOneWidget,
      );
      expect(
        find.text('Vaccines cause widespread magnetic interference.'),
        findsOneWidget,
      );

      // Verify sources
      expect(find.text('VERIFIED SOURCES'), findsOneWidget);
      expect(find.text('Dr. Carl Sagan'), findsOneWidget);
      expect(find.text('Nature Editorial'), findsOneWidget);
      expect(find.text('World Health Organization'), findsOneWidget);

      // Verify conclusion
      expect(find.text('CONCLUSION'), findsOneWidget);
      expect(
        find.text('The video exhibits high integrity with multi-sourced evidence.'),
        findsOneWidget,
      );

      // Verify diagnostics
      expect(find.text('ANALYSIS DIAGNOSTICS'), findsOneWidget);
      expect(find.textContaining('Multi-engine synthesis latency'), findsOneWidget);

      // Verify footer
      expect(find.textContaining('TruthWorld employs multi-stage AI verification'), findsOneWidget);
      expect(find.text('Report Incorrect? Dispute & Provide Sources'), findsOneWidget);
    });

    testWidgets('renders empty placeholders when claims and diagnostics are empty', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyData = <String, dynamic>{
        'trustScore': 50.0,
        'factCheckStats': {},
        'claims': <dynamic>[],
        'diagnostics': <dynamic>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FactCheckReportWidget(
              data: emptyData,
              video: testVideo,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('No specific claims extracted for this analysis.'), findsOneWidget);
      expect(find.text('No additional diagnostic data recorded.'), findsOneWidget);
    });


    testWidgets('FactCheckConfidenceBar normalizes >1.0 and displays percent', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FactCheckConfidenceBar(confidence: 78.0),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('ANALYSIS CONFIDENCE'), findsOneWidget);
      expect(find.text('78%'), findsOneWidget);
    });

    testWidgets('FactCheckSourcesSection renders citations for book, journal, and web', (tester) async {
      final sources = [
        {
          'sourceType': 'book',
          'author': 'Yuval Noah Harari',
          'bookTitle': 'Sapiens',
          'chapter': 'Part 1',
          'yearPublished': 2014,
          'trustLevel': 'High',
        },
        {
          'sourceType': 'website',
          'title': 'BBC News Report',
          'domain': 'bbc.com',
          'trustLevel': 'Medium',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FactCheckSourcesSection(sources: sources),
          ),
        ),
      );

      expect(find.text('VERIFIED SOURCES'), findsOneWidget);
      expect(find.text('Yuval Noah Harari'), findsOneWidget);
      expect(find.textContaining('📖 Sapiens, Part 1, 2014'), findsOneWidget);
      expect(find.text('BBC News Report'), findsOneWidget);
      expect(find.text('bbc.com'), findsAtLeast(1));
    });

    testWidgets('FactCheckConclusionSection renders conclusion text and supporting sources when present', (tester) async {
      final conclusionSources = [
        {
          'sourceType': 'website',
          'title': 'Intergovernmental Panel on Climate Change',
          'domain': 'ipcc.ch',
          'trustLevel': 'High',
          'url': 'https://ipcc.ch/report/ar6',
        },
        {
          'sourceType': 'journal',
          'author': 'Science Research Group',
          'journalName': 'Science Advances',
          'yearPublished': 2024,
          'trustLevel': 'High',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FactCheckConclusionSection(
              conclusion: 'Human-induced climate change is confirmed with multi-observational data.',
              sources: conclusionSources,
            ),
          ),
        ),
      );

      expect(find.text('CONCLUSION'), findsOneWidget);
      expect(find.text('Human-induced climate change is confirmed with multi-observational data.'), findsOneWidget);
      expect(find.text('SUPPORTING SOURCES & CITATIONS (2)'), findsOneWidget);
      expect(find.text('Intergovernmental Panel on Climate Change'), findsOneWidget);
      expect(find.text('ipcc.ch'), findsAtLeast(1));
      expect(find.text('Science Research Group'), findsOneWidget);
    });

    testWidgets('FactCheckConclusionSection renders conclusion text without sources section when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FactCheckConclusionSection(
              conclusion: 'Overall high credibility based on consensus analysis.',
            ),
          ),
        ),
      );

      expect(find.text('CONCLUSION'), findsOneWidget);
      expect(find.text('Overall high credibility based on consensus analysis.'), findsOneWidget);
      expect(find.textContaining('SUPPORTING SOURCES & CITATIONS'), findsNothing);
    });

    test('getFactCheckRatingLabel maps scores to correct labels', () {
      expect(getFactCheckRatingLabel(95), 'EXCEPTIONAL');
      expect(getFactCheckRatingLabel(80), 'HIGH INTEGRITY');
      expect(getFactCheckRatingLabel(65), 'TRUSTWORTHY');
      expect(getFactCheckRatingLabel(50), 'CAUTION ADVISED');
      expect(getFactCheckRatingLabel(35), 'LOW INTEGRITY');
      expect(getFactCheckRatingLabel(20), 'UNRELIABLE');
    });

    test('getFactCheckScoreColor returns appropriate status colors', () {
      expect(getFactCheckScoreColor(95), isNotNull);
      expect(getFactCheckScoreColor(80), isNotNull);
      expect(getFactCheckScoreColor(65), isNotNull);
      expect(getFactCheckScoreColor(50), isNotNull);
      expect(getFactCheckScoreColor(35), isNotNull);
      expect(getFactCheckScoreColor(10), isNotNull);
    });
  });
}
